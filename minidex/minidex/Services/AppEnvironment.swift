// FILE: AppEnvironment.swift
// Purpose: Centralizes local runtime endpoint configuration for app fallbacks.
// Layer: Service
// Exports: AppEnvironment
// Depends on: Foundation

import Foundation

struct TailscaleDiscoveryStoredSettings {
    var tailnetDNSName: String
    var codexPort: Int

    var hasCustomOverrides: Bool {
        !tailnetDNSName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || codexPort != 4200
    }
}

enum AppEnvironment {
    private static let defaultServerURLInfoPlistKey = "MINIDEX_DEFAULT_SERVER_URL"
    private static let legacyBridgeURLInfoPlistKey = "MINIDEX_DEFAULT_BRIDGE_URL"
    private static let tailscaleDNSNameInfoPlistKey = "MINIDEX_TAILSCALE_DNS_NAME"
    private static let tailscaleCodexPortInfoPlistKey = "MINIDEX_TAILSCALE_CODEX_PORT"
    private static let tailscaleDNSNameDefaultsKey = "codex.tailscale.dnsName"
    private static let tailscaleCodexPortDefaultsKey = "codex.tailscale.codexPort"

    static var serverURL: String? {
        resolvedString(forInfoPlistKey: defaultServerURLInfoPlistKey)
            ?? resolvedString(forInfoPlistKey: legacyBridgeURLInfoPlistKey)
    }

    static var tailscaleDiscoveryConfiguration: TailscaleDiscoveryConfiguration {
        let settings = tailscaleDiscoveryStoredSettings

        return TailscaleDiscoveryConfiguration(
            tailnetDNSName: settings.tailnetDNSName.nilIfEmpty,
            preferredCodexPort: settings.codexPort
        )
    }

    static var tailscaleDiscoveryStoredSettings: TailscaleDiscoveryStoredSettings {
        let tailnetDNSName = UserDefaults.standard.string(forKey: tailscaleDNSNameDefaultsKey)
            ?? resolvedString(forInfoPlistKey: tailscaleDNSNameInfoPlistKey)
            ?? ""
        let codexPort = UserDefaults.standard.integer(forKey: tailscaleCodexPortDefaultsKey)
        let fallbackPort = resolvedInt(forInfoPlistKey: tailscaleCodexPortInfoPlistKey) ?? 4200

        return TailscaleDiscoveryStoredSettings(
            tailnetDNSName: tailnetDNSName,
            codexPort: codexPort > 0 ? codexPort : fallbackPort
        )
    }

    static func saveTailscaleDiscoveryStoredSettings(_ settings: TailscaleDiscoveryStoredSettings) {
        let normalizedDNSName = settings.tailnetDNSName.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedDNSName.isEmpty {
            UserDefaults.standard.removeObject(forKey: tailscaleDNSNameDefaultsKey)
        } else {
            UserDefaults.standard.set(normalizedDNSName, forKey: tailscaleDNSNameDefaultsKey)
        }

        UserDefaults.standard.set(max(1, settings.codexPort), forKey: tailscaleCodexPortDefaultsKey)
    }

    static func clearTailscaleDiscoveryStoredSettings() {
        UserDefaults.standard.removeObject(forKey: tailscaleDNSNameDefaultsKey)
        UserDefaults.standard.removeObject(forKey: tailscaleCodexPortDefaultsKey)
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
