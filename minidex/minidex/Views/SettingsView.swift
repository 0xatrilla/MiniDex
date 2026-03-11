// FILE: SettingsView.swift
// Purpose: Settings for the Mac companion link, runtime defaults, and local alerts.
// Layer: View
// Exports: SettingsView

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(CodexService.self) private var codex

    @AppStorage("codex.useJetBrainsMono") private var useJetBrainsMono = false

    private let runtimeAutoValue = "__AUTO__"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsArchivedChatsCard()
                SettingsAppearanceCard(useJetBrainsMono: $useJetBrainsMono)
                SettingsNotificationsCard()
                SettingsTailscaleDiscoveryCard()
                runtimeDefaultsSection
                connectionSection
                SettingsAboutCard()
            }
            .padding()
        }
        .font(AppFont.body())
        .navigationTitle("Settings")
    }

    // MARK: - Runtime defaults

    @ViewBuilder private var runtimeDefaultsSection: some View {
        SettingsCard(title: "Runtime defaults") {
            HStack {
                Text("Model")
                Spacer()
                Picker("Model", selection: runtimeModelSelection) {
                    Text("Auto").tag(runtimeAutoValue)
                    ForEach(runtimeModelOptions, id: \.id) { model in
                        Text(TurnComposerMetaMapper.modelTitle(for: model))
                            .tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(CodexBrand.accent)
            }

            HStack {
                Text("Reasoning")
                Spacer()
                Picker("Reasoning", selection: runtimeReasoningSelection) {
                    Text("Auto").tag(runtimeAutoValue)
                    ForEach(runtimeReasoningOptions, id: \.id) { option in
                        Text(option.title).tag(option.effort)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(CodexBrand.accent)
                .disabled(runtimeReasoningOptions.isEmpty)
            }

            HStack {
                Text("Access")
                Spacer()
                Picker("Access", selection: runtimeAccessSelection) {
                    ForEach(CodexAccessMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(CodexBrand.accent)
            }
        }
    }

    // MARK: - Connection

    @ViewBuilder private var connectionSection: some View {
        SettingsCard(title: "Companion link") {
            Text(codex.isConnected ? "Status: connected" : "Status: disconnected")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)

            if codex.isConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting to your Mac...")
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                }
            }

            if case .retrying(_, let message) = codex.connectionRecoveryState,
               !message.isEmpty {
                Text(message)
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }

            if let error = codex.lastErrorMessage, !error.isEmpty {
                Text(error)
                    .font(AppFont.caption())
                    .foregroundStyle(.red)
            }

            if codex.isConnected {
                SettingsButton("Disconnect", role: .destructive) {
                    HapticFeedback.shared.triggerImpactFeedback()
                    disconnectBridge()
                }
            }
        }
    }

    // MARK: - Actions

    private func disconnectBridge() {
        Task { @MainActor in
            await codex.disconnect()
            codex.clearSavedServerConnection()
        }
    }

    // MARK: - Runtime bindings

    private var runtimeModelOptions: [CodexModelOption] {
        TurnComposerMetaMapper.orderedModels(from: codex.availableModels)
    }

    private var runtimeReasoningOptions: [TurnComposerReasoningDisplayOption] {
        TurnComposerMetaMapper.reasoningDisplayOptions(
            from: codex.supportedReasoningEffortsForSelectedModel().map(\.reasoningEffort)
        )
    }

    private var runtimeModelSelection: Binding<String> {
        Binding(
            get: { codex.selectedModelOption()?.id ?? runtimeAutoValue },
            set: { selection in
                codex.setSelectedModelId(selection == runtimeAutoValue ? nil : selection)
            }
        )
    }

    private var runtimeReasoningSelection: Binding<String> {
        Binding(
            get: { codex.selectedReasoningEffort ?? runtimeAutoValue },
            set: { selection in
                codex.setSelectedReasoningEffort(selection == runtimeAutoValue ? nil : selection)
            }
        )
    }

    private var runtimeAccessSelection: Binding<CodexAccessMode> {
        Binding(
            get: { codex.selectedAccessMode },
            set: { codex.setSelectedAccessMode($0) }
        )
    }
}

// MARK: - Reusable card / button components

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(AppFont.caption(weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct SettingsButton: View {
    let title: String
    var role: ButtonRole?
    var isLoading: Bool = false
    let action: () -> Void

    init(_ title: String, role: ButtonRole? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Text(title)
                }
            }
            .font(AppFont.subheadline(weight: .medium))
            .foregroundStyle(role == .destructive ? .red : (role == .cancel ? .secondary : .primary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                (role == .destructive ? Color.red : Color.primary).opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extracted independent section views

private struct SettingsAppearanceCard: View {
    @Binding var useJetBrainsMono: Bool
    @AppStorage("codex.useLiquidGlass") private var useLiquidGlass = true

    var body: some View {
        SettingsCard(title: "Appearance") {
            Toggle("Use JetBrains Mono", isOn: $useJetBrainsMono)
                .tint(CodexBrand.accent)

            Text(useJetBrainsMono
                 ? "JetBrains Mono is the default font."
                 : "Using the system font.")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)

            if GlassPreference.isSupported {
                Divider()

                Toggle("Liquid Glass", isOn: $useLiquidGlass)
                    .tint(CodexBrand.accent)

                Text(useLiquidGlass
                     ? "Liquid Glass effects are enabled."
                     : "Using solid material fallback.")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsNotificationsCard: View {
    @Environment(CodexService.self) private var codex
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SettingsCard(title: "Notifications") {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.primary)
                Text("Status")
                Spacer()
                Text(statusLabel)
                    .foregroundStyle(.secondary)
            }

            Text("Used for local alerts when a run finishes while the app is in background.")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)

            if codex.notificationAuthorizationStatus == .notDetermined {
                SettingsButton("Allow notifications") {
                    HapticFeedback.shared.triggerImpactFeedback()
                    Task {
                        await codex.requestNotificationPermission()
                    }
                }
            }

            if codex.notificationAuthorizationStatus == .denied {
                SettingsButton("Open iOS Settings") {
                    HapticFeedback.shared.triggerImpactFeedback()
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .task {
            await codex.refreshNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }
            Task {
                await codex.refreshNotificationAuthorizationStatus()
            }
        }
    }

    private var statusLabel: String {
        switch codex.notificationAuthorizationStatus {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }
}

private struct SettingsArchivedChatsCard: View {
    @Environment(CodexService.self) private var codex

    private var archivedCount: Int {
        codex.threads.filter { $0.syncState == .archivedLocal }.count
    }

    var body: some View {
        SettingsCard(title: "Archived Chats") {
            NavigationLink {
                ArchivedChatsView()
            } label: {
                HStack {
                    Label("Archived Chats", systemImage: "archivebox")
                        .font(AppFont.subheadline(weight: .medium))
                    Spacer()
                    if archivedCount > 0 {
                        Text("\(archivedCount)")
                            .font(AppFont.caption(weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(AppFont.caption(weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SettingsTailscaleDiscoveryCard: View {
    @State private var tailnetDNSName = ""
    @State private var codexPort = "4200"
    @State private var statusMessage: String? = nil
    @State private var hasLoadedSettings = false

    var body: some View {
        SettingsCard(title: "Tailscale Discovery") {
            Text("MiniDex asks the local Tailscale client on this iPhone for peers, then probes likely Macs for Codex automatically. If both devices are connected to Tailscale, there is usually nothing to configure.")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("MagicDNS suffix (optional)")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("example.ts.net", text: $tailnetDNSName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(AppFont.mono(.caption))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Preferred Codex port")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("4200", text: $codexPort)
                    .keyboardType(.numberPad)
                    .font(AppFont.mono(.caption))
            }

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            } else {
                Text(hasCustomOverrides
                     ? "Saved. MiniDex will use your custom suffix and port while it probes Tailscale peers."
                     : "Using defaults. MiniDex will try Tailscale discovery on launch, then fall back to manual host entry if nothing answers.")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }

            SettingsButton("Save Discovery Defaults") {
                save()
            }

            if hasCustomOverrides {
                SettingsButton("Reset Discovery Defaults", role: .destructive) {
                    clear()
                }
            }
        }
        .task {
            guard !hasLoadedSettings else {
                return
            }
            hasLoadedSettings = true
            load()
        }
    }

    private var hasCustomOverrides: Bool {
        AppEnvironment.tailscaleDiscoveryStoredSettings.hasCustomOverrides
    }

    private func load() {
        let settings = AppEnvironment.tailscaleDiscoveryStoredSettings
        tailnetDNSName = settings.tailnetDNSName
        codexPort = String(settings.codexPort)
        statusMessage = nil
    }

    private func save() {
        let normalizedPort = Int(codexPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 4200
        let settings = TailscaleDiscoveryStoredSettings(
            tailnetDNSName: tailnetDNSName,
            codexPort: max(1, normalizedPort)
        )
        AppEnvironment.saveTailscaleDiscoveryStoredSettings(settings)
        codexPort = String(max(1, normalizedPort))
        statusMessage = settings.hasCustomOverrides
            ? "Tailscale discovery defaults saved."
            : "Defaults restored. MiniDex will use the built-in Tailscale discovery flow."
    }

    private func clear() {
        AppEnvironment.clearTailscaleDiscoveryStoredSettings()
        tailnetDNSName = ""
        codexPort = "4200"
        statusMessage = "Tailscale discovery defaults reset."
    }
}

private struct SettingsAboutCard: View {
    var body: some View {
        SettingsCard(title: "About") {
            Text("MiniDex is a mobile companion for Codex on your Mac. Pair once, keep your session history on your hardware, and drive approvals or thread checks without outsourcing the experience to third-party branding.")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(CodexService())
    }
}
