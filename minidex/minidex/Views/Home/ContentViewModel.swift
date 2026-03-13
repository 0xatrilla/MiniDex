// FILE: ContentViewModel.swift
// Purpose: Owns non-visual orchestration logic for the root screen (connection, companion pairing, sync throttling).
// Layer: ViewModel
// Exports: ContentViewModel
// Depends on: Foundation, Observation, CodexService, SecureStore

import Foundation
import Observation

@MainActor
@Observable
final class ContentViewModel {
    private var hasAttemptedInitialAutoConnect = false
    private var hasAttemptedInitialTailscaleDiscovery = false
    private var lastSidebarOpenSyncAt: Date = .distantPast
    private let autoReconnectBackoffNanoseconds: [UInt64] = [1_000_000_000, 3_000_000_000]
    private let tailscaleDiscoveryService = TailscaleDiscoveryService()
    private(set) var isRunningAutoReconnect = false
    private(set) var isDiscoveringTailscaleServer = false
    private(set) var tailscaleDiscoveryStatus: TailscaleDiscoveryStatus = .idle
    private(set) var suggestedServerURL: String? = nil

    var isAttemptingAutoReconnect: Bool {
        isRunningAutoReconnect
    }

    // Throttles sidebar-open sync requests to avoid redundant thread refresh churn.
    func shouldRequestSidebarFreshSync(isConnected: Bool) -> Bool {
        guard isConnected else {
            return false
        }

        let now = Date()
        guard now.timeIntervalSince(lastSidebarOpenSyncAt) >= 0.8 else {
            return false
        }

        lastSidebarOpenSyncAt = now
        return true
    }

    // Connects to a saved or newly entered Codex app-server endpoint.
    func connect(serverURL: String, codex: CodexService) async {
        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Persist for reconnection
        SecureStore.writeString(trimmedServerURL, for: CodexSecureKeys.serverURL)
        codex.serverURL = trimmedServerURL

        do {
            try await connectWithAutoRecovery(
                codex: codex,
                serverURL: trimmedServerURL,
                performAutoRetry: true
            )
        } catch {
            if codex.lastErrorMessage?.isEmpty ?? true {
                codex.lastErrorMessage = codex.userFacingConnectFailureMessage(error)
            }
        }
    }

    // Connects or disconnects the companion bridge.
    func toggleConnection(codex: CodexService) async {
        guard !codex.isConnecting, !isRunningAutoReconnect else {
            return
        }

        if codex.isConnected {
            await codex.disconnect()
            codex.clearSavedServerConnection()
            return
        }

        if await attemptTailscaleDiscoveryIfNeeded(codex: codex, force: true) {
            return
        }

        guard let serverURL = codex.normalizedSavedServerURL else {
            return
        }

        do {
            try await connectWithAutoRecovery(
                codex: codex,
                serverURL: serverURL,
                performAutoRetry: true
            )
        } catch {
            _ = await attemptTailscaleDiscoveryIfNeeded(codex: codex, force: true)

            if !codex.isConnected, codex.lastErrorMessage?.isEmpty ?? true {
                codex.lastErrorMessage = codex.userFacingConnectFailureMessage(error)
            }
        }
    }

        // Attempts one automatic connection on app launch using the saved server URL.
    func attemptAutoConnectOnLaunchIfNeeded(codex: CodexService) async {
        guard !hasAttemptedInitialAutoConnect else {
            return
        }
        hasAttemptedInitialAutoConnect = true

        guard !codex.isConnected, !codex.isConnecting else {
            return
        }

        if await attemptTailscaleDiscoveryIfNeeded(codex: codex, force: false) {
            return
        }

        guard let serverURL = codex.normalizedSavedServerURL else {
            return
        }

        do {
            try await connectWithAutoRecovery(
                codex: codex,
                serverURL: serverURL,
                performAutoRetry: false
            )
        } catch {
            return
        }
    }

    // Reconnects after benign background disconnects.
    func attemptAutoReconnectOnForegroundIfNeeded(codex: CodexService) async {
        guard codex.shouldAutoReconnectOnForeground, !isRunningAutoReconnect else {
            return
        }

        isRunningAutoReconnect = true
        defer { isRunningAutoReconnect = false }

        var attempt = 0
        let maxAttempts = 20

        // Keep trying while the saved server endpoint is still valid.
        // This lets network changes recover on their own instead of dropping back to a manual reconnect button.
        while codex.shouldAutoReconnectOnForeground, attempt < maxAttempts {
            guard let serverURL = codex.normalizedSavedServerURL else {
                codex.shouldAutoReconnectOnForeground = false
                codex.connectionRecoveryState = .idle
                return
            }

            if codex.isConnected {
                codex.shouldAutoReconnectOnForeground = false
                codex.connectionRecoveryState = .idle
                codex.lastErrorMessage = nil
                return
            }

            if codex.isConnecting {
                try? await Task.sleep(nanoseconds: 300_000_000)
                continue
            }

            do {
                codex.connectionRecoveryState = .retrying(
                    attempt: max(1, attempt + 1),
                    message: "Reconnecting..."
                )
                try await connect(codex: codex, serverURL: serverURL)
                codex.connectionRecoveryState = .idle
                codex.lastErrorMessage = nil
                codex.shouldAutoReconnectOnForeground = false
                return
            } catch {
                let isRetryable = codex.isRecoverableTransientConnectionError(error)
                    || codex.isBenignBackgroundDisconnect(error)

                guard isRetryable else {
                    codex.connectionRecoveryState = .idle
                    codex.shouldAutoReconnectOnForeground = false
                    codex.lastErrorMessage = codex.userFacingConnectFailureMessage(error)
                    return
                }

                codex.lastErrorMessage = nil
                codex.connectionRecoveryState = .retrying(
                    attempt: attempt + 1,
                    message: codex.recoveryStatusMessage(for: error)
                )

                let backoffIndex = min(attempt, autoReconnectBackoffNanoseconds.count - 1)
                let backoff = autoReconnectBackoffNanoseconds[backoffIndex]
                attempt += 1
                try? await Task.sleep(nanoseconds: backoff)
            }
        }

        // Exhausted all attempts — stop retrying but keep the saved pairing for next foreground cycle.
        if attempt >= maxAttempts {
            codex.shouldAutoReconnectOnForeground = false
            codex.connectionRecoveryState = .idle
            codex.lastErrorMessage = "Could not reconnect. Tap Reconnect to try again."
        }
    }

    func attemptTailscaleDiscoveryIfNeeded(codex: CodexService, force: Bool) async -> Bool {
        if !force {
            guard !hasAttemptedInitialTailscaleDiscovery else {
                return false
            }
            hasAttemptedInitialTailscaleDiscovery = true
        }

        guard !codex.isConnected, !codex.isConnecting else {
            return false
        }

        guard !isRunningAutoReconnect, !isDiscoveringTailscaleServer else {
            return false
        }

        return await discoverTailscaleServerAndConnect(codex: codex)
    }

    func retryTailscaleDiscovery(codex: CodexService) async {
        _ = await attemptTailscaleDiscoveryIfNeeded(codex: codex, force: true)
    }
}

extension ContentViewModel {
    func connect(codex: CodexService, serverURL: String) async throws {
        try await codex.connect(serverURL: serverURL, token: "", role: "iphone")
    }

    func connectWithAutoRecovery(
        codex: CodexService,
        serverURL: String,
        performAutoRetry: Bool
    ) async throws {
        guard !isRunningAutoReconnect else {
            return
        }

        isRunningAutoReconnect = true
        defer { isRunningAutoReconnect = false }

        let maxAttemptIndex = performAutoRetry ? autoReconnectBackoffNanoseconds.count : 0
        var lastError: Error?

        for attemptIndex in 0...maxAttemptIndex {
            if attemptIndex > 0 {
                codex.connectionRecoveryState = .retrying(
                    attempt: attemptIndex,
                    message: "Connection timed out. Retrying..."
                )
            }

            do {
                try await connect(codex: codex, serverURL: serverURL)
                codex.connectionRecoveryState = .idle
                codex.lastErrorMessage = nil
                codex.shouldAutoReconnectOnForeground = false
                return
            } catch {
                lastError = error
                let isRetryable = codex.isRecoverableTransientConnectionError(error)
                    || codex.isBenignBackgroundDisconnect(error)

                guard performAutoRetry,
                      isRetryable,
                      attemptIndex < autoReconnectBackoffNanoseconds.count else {
                    codex.connectionRecoveryState = .idle
                    codex.shouldAutoReconnectOnForeground = false
                    codex.lastErrorMessage = codex.userFacingConnectFailureMessage(error)
                    throw error
                }

                codex.lastErrorMessage = nil
                codex.connectionRecoveryState = .retrying(
                    attempt: attemptIndex + 1,
                    message: codex.recoveryStatusMessage(for: error)
                )
                try? await Task.sleep(nanoseconds: autoReconnectBackoffNanoseconds[attemptIndex])
            }
        }

        if let lastError {
            codex.connectionRecoveryState = .idle
            codex.shouldAutoReconnectOnForeground = false
            codex.lastErrorMessage = codex.userFacingConnectFailureMessage(lastError)
            throw lastError
        }
    }

    private func discoverTailscaleServerAndConnect(codex: CodexService) async -> Bool {
        isDiscoveringTailscaleServer = true
        tailscaleDiscoveryStatus = .searching
        defer { isDiscoveringTailscaleServer = false }

        do {
            let result = try await tailscaleDiscoveryService.discoverCodexServer(
                configuration: AppEnvironment.tailscaleDiscoveryConfiguration
            )
            suggestedServerURL = result.serverURL
            tailscaleDiscoveryStatus = .found(result.serverURL)

            SecureStore.writeString(result.serverURL, for: CodexSecureKeys.serverURL)
            codex.serverURL = result.serverURL

            try await connectWithAutoRecovery(
                codex: codex,
                serverURL: result.serverURL,
                performAutoRetry: true
            )
            return codex.isConnected
        } catch TailscaleDiscoveryError.noReachableCodexServer {
            tailscaleDiscoveryStatus = .unavailable
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            tailscaleDiscoveryStatus = .failed(
                message.isEmpty ? "Tailscale discovery failed." : message
            )
        }

        return false
    }
}
