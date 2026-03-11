// FILE: AppEnvironment.swift
// Purpose: Centralizes local runtime endpoint configuration for app fallbacks.
// Layer: Service
// Exports: AppEnvironment
// Depends on: Foundation

import Foundation

enum AppEnvironment {
    private static let defaultServerURLInfoPlistKey = "MINIDEX_DEFAULT_SERVER_URL"
    private static let legacyBridgeURLInfoPlistKey = "MINIDEX_DEFAULT_BRIDGE_URL"
    private static let tailscaleOAuthClientIDInfoPlistKey = "MINIDEX_TAILSCALE_OAUTH_CLIENT_ID"
    private static let tailscaleOAuthClientSecretInfoPlistKey = "MINIDEX_TAILSCALE_OAUTH_CLIENT_SECRET"
    private static let tailscaleDNSNameInfoPlistKey = "MINIDEX_TAILSCALE_DNS_NAME"
    private static let tailscaleCodexPortInfoPlistKey = "MINIDEX_TAILSCALE_CODEX_PORT"

    static var serverURL: String? {
        resolvedString(forInfoPlistKey: defaultServerURLInfoPlistKey)
            ?? resolvedString(forInfoPlistKey: legacyBridgeURLInfoPlistKey)
    }

    static var tailscaleDiscoveryConfiguration: TailscaleDiscoveryConfiguration? {
        guard let oauthClientID = resolvedString(forInfoPlistKey: tailscaleOAuthClientIDInfoPlistKey),
              let oauthClientSecret = resolvedString(forInfoPlistKey: tailscaleOAuthClientSecretInfoPlistKey) else {
            return nil
        }

        let configuredPort = resolvedInt(forInfoPlistKey: tailscaleCodexPortInfoPlistKey) ?? 4200

        return TailscaleDiscoveryConfiguration(
            oauthClientID: oauthClientID,
            oauthClientSecret: oauthClientSecret,
            tailnetDNSName: resolvedString(forInfoPlistKey: tailscaleDNSNameInfoPlistKey),
            codexPort: configuredPort
        )
    }
}

private extension AppEnvironment {
    static func resolvedString(forInfoPlistKey key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if trimmedValue.hasPrefix("$("), trimmedValue.hasSuffix(")") {
            return nil
        }

        return trimmedValue
    }

    static func resolvedInt(forInfoPlistKey key: String) -> Int? {
        if let number = Bundle.main.object(forInfoDictionaryKey: key) as? NSNumber {
            return number.intValue
        }

        guard let stringValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return Int(trimmedValue)
    }
}
