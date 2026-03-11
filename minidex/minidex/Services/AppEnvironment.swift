// FILE: AppEnvironment.swift
// Purpose: Centralizes local runtime endpoint configuration for app fallbacks.
// Layer: Service
// Exports: AppEnvironment
// Depends on: Foundation

import Foundation

enum AppEnvironment {
    private static let defaultServerURLInfoPlistKey = "MINIDEX_DEFAULT_SERVER_URL"
    private static let legacyBridgeURLInfoPlistKey = "MINIDEX_DEFAULT_BRIDGE_URL"

    static var serverURL: String? {
        resolvedString(forInfoPlistKey: defaultServerURLInfoPlistKey)
            ?? resolvedString(forInfoPlistKey: legacyBridgeURLInfoPlistKey)
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
}
