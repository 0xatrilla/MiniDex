// FILE: MiniDexApp.swift
// Purpose: App entry point and root dependency wiring for CodexService.
// Layer: App
// Exports: MiniDexApp

import SwiftUI

@MainActor
@main
struct MiniDexApp: App {
    @State private var codexService: CodexService

    init() {
        let service = CodexService()
        service.configureNotifications()
        _codexService = State(initialValue: service)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(codexService)
                .task {
                    await codexService.requestNotificationPermissionOnFirstLaunchIfNeeded()
                }
        }
    }
}
