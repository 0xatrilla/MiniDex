// FILE: HomeEmptyStateView.swift
// Purpose: Minimal splash screen with branding and live connection status.
// Layer: View
// Exports: HomeEmptyStateView
// Depends on: SwiftUI

import SwiftUI

struct HomeEmptyStateView: View {
    let isConnected: Bool
    let isConnecting: Bool
    let lastErrorMessage: String?
    let suggestedServerURL: String?
    let tailscaleDiscoveryStatus: TailscaleDiscoveryStatus
    let tailscaleDiscoveryCandidates: [TailscaleDiscoveryCandidate]
    let isSearchingTailscale: Bool
    let onToggleConnection: () -> Void
    let onConnect: (String) -> Void
    let onRetryTailscaleDiscovery: () -> Void
    let onScanQRCode: () -> Void

    @State private var dotPulse = false
    @State private var connectionAttemptStartedAt: Date?
    @State private var serverURL = ""
    @State private var isShowingManualEntry = false

    var body: some View {
        ZStack {
            CodexBrandBackdrop(intensity: 0.55)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    CodexBrandMark(size: 92)

                    VStack(spacing: 10) {
                        Text("Companion link")
                            .font(AppFont.caption(weight: .semibold))
                            .foregroundStyle(CodexBrand.accentMuted)
                            .textCase(.uppercase)

                        Text(isConnected ? "Your Mac is ready." : "Pair with your Mac and pick up where you left off.")
                            .font(AppFont.title2(weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CodexBrand.ink)

                        Text(statusDescription)
                            .font(AppFont.subheadline())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 6, height: 6)
                            .scaleEffect(dotPulse ? 1.4 : 1.0)
                            .opacity(dotPulse ? 0.6 : 1.0)
                            .animation(
                                (isSearchingTailscale || isConnecting)
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .default,
                                value: dotPulse
                            )

                        Text(statusLabel)
                            .font(AppFont.caption(weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CodexBrand.chipSurface, in: Capsule())

                    HStack(spacing: 12) {
                        StatusTile(title: "Link", value: isConnected ? "Live" : "Standby")
                        StatusTile(title: "Sync", value: (isSearchingTailscale || isConnecting) ? "Warm" : "Ready")
                        StatusTile(title: "Mode", value: "Private")
                    }

                    if shouldShowTailscaleDiscoveryCard {
                        tailscaleDiscoveryCard
                    }

                    if let lastErrorMessage, !lastErrorMessage.isEmpty {
                        Text(lastErrorMessage)
                            .font(AppFont.caption())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red)
                    }

                    Button(action: onToggleConnection) {
                        HStack(spacing: 10) {
                            if isSearchingTailscale || isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            }

                            Text(primaryButtonTitle)
                                .font(AppFont.body(weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .foregroundStyle(primaryButtonForeground)
                        .background(primaryButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSearchingTailscale || isConnecting)
                    .padding(.top, 6)

                    manualFallbackCard
                }
                .frame(maxWidth: 320)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(CodexBrand.cardStroke, lineWidth: 1)
                )

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("MiniDex")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isSearchingTailscale || isConnecting {
                connectionAttemptStartedAt = Date()
                dotPulse = true
            }

            if serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                serverURL = suggestedServerURL ?? ""
            }
        }
        .onChange(of: isConnecting) { _, connecting in
            connectionAttemptStartedAt = (connecting || isSearchingTailscale) ? Date() : nil
            dotPulse = connecting || isSearchingTailscale
        }
        .onChange(of: isSearchingTailscale) { _, searching in
            connectionAttemptStartedAt = (searching || isConnecting) ? Date() : nil
            dotPulse = searching || isConnecting
        }
        .onChange(of: suggestedServerURL) { _, suggestedURL in
            guard serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            serverURL = suggestedURL ?? ""
        }
        .onChange(of: tailscaleDiscoveryStatus) { _, status in
            switch status {
            case .unavailable, .failed:
                isShowingManualEntry = true
            case .idle, .searching, .found:
                break
            }
        }
    }

    // MARK: - Helpers

    private var statusDotColor: Color {
        if isSearchingTailscale || isConnecting { return CodexBrand.accent }
        return isConnected ? CodexBrand.success : Color(.tertiaryLabel)
    }

    private var statusLabel: String {
        if isSearchingTailscale {
            return "Finding your Mac"
        }
        if isConnecting {
            guard let connectionAttemptStartedAt else { return "Connecting" }
            let elapsed = Date().timeIntervalSince(connectionAttemptStartedAt)
            if elapsed >= 12 { return "Still connecting…" }
            return "Connecting"
        }
        return isConnected ? "Connected" : "Offline"
    }

    private var primaryButtonTitle: String {
        if isSearchingTailscale {
            return "Looking for your Mac..."
        }
        if isConnecting {
            return "Reconnecting..."
        }
        return isConnected ? "Disconnect Mac" : "Find My Mac Again"
    }

    private var primaryButtonBackground: some ShapeStyle {
        if isConnected {
            return AnyShapeStyle(CodexBrand.cardSurfaceStrong)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [CodexBrand.accent, CodexBrand.ink],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var primaryButtonForeground: Color {
        isConnected ? CodexBrand.ink : .white
    }

    private var statusDescription: String {
        if isSearchingTailscale {
            return "MiniDex is checking Tailscale peers on this iPhone and probing likely Codex hosts."
        }
        if isConnecting {
            return "MiniDex found a likely Codex host and is opening a live connection to your Mac."
        }
        if isConnected {
            return "Threads, approvals, and run state stay close at hand while Codex works on your Mac."
        }
        return "MiniDex opens straight into discovery, looks for Codex on your tailnet, and falls back to a manual host or IP only when needed."
    }

    private var shouldShowTailscaleDiscoveryCard: Bool {
        !isConnected && (isSearchingTailscale || tailscaleDiscoveryStatus != .idle)
    }

    @ViewBuilder
    private var tailscaleDiscoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundStyle(CodexBrand.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tailscale Discovery")
                        .font(AppFont.subheadline(weight: .semibold))
                        .foregroundStyle(CodexBrand.ink)

                    Text(tailscaleDiscoveryPrimaryText)
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSearchingTailscale {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .found(let discoveredURL) = tailscaleDiscoveryStatus {
                Text(discoveredURL)
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(CodexBrand.ink.opacity(0.84))
            }

            TailscaleDiscoveryCandidatesView(candidates: tailscaleDiscoveryCandidates)

            if !isSearchingTailscale {
                Button("Retry Tailscale Discovery") {
                    onRetryTailscaleDiscovery()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var manualFallbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingManualEntry.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(CodexBrand.ink)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manual fallback")
                            .font(AppFont.subheadline(weight: .semibold))
                            .foregroundStyle(CodexBrand.ink)

                        Text("Enter a host or IP if Tailscale discovery is unavailable.")
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isShowingManualEntry ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isShowingManualEntry {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("ws://your-mac:4200", text: $serverURL)
                        .font(AppFont.mono(.callout))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(CodexBrand.cardSurfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        onConnect(serverURL.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        Label("Connect with Host or IP", systemImage: "bolt.horizontal.circle")
                            .font(AppFont.subheadline(weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CodexBrand.ink)
                    .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)

                    Button {
                        onScanQRCode()
                    } label: {
                        Label("Scan Server QR", systemImage: "qrcode.viewfinder")
                            .font(AppFont.subheadline(weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isConnecting)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tailscaleDiscoveryPrimaryText: String {
        switch tailscaleDiscoveryStatus {
        case .idle:
            return "If your phone is connected to Tailscale, MiniDex checks the local Tailscale client and probes your Macs automatically."
        case .searching:
            return tailscaleDiscoveryCandidates.isEmpty
                ? "Reading peers from Tailscale on this iPhone and probing for a reachable Codex host..."
                : "MiniDex is checking the Macs it found on your tailnet and will auto-connect to the first live Codex host."
        case .found:
            return "Found a Codex host and trying to connect."
        case .unavailable:
            return "No reachable Codex host was found on Tailscale. Enter a host or IP manually."
        case .failed(let message):
            return message
        }
    }
}

private struct StatusTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.caption2(weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppFont.caption(weight: .semibold))
                .foregroundStyle(CodexBrand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
