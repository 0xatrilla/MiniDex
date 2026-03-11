// FILE: ContentView.swift
// Purpose: Root layout orchestrator — navigation shell, sidebar drawer, and top-level state wiring.
// Layer: View
// Exports: ContentView
// Depends on: SidebarView, TurnView, SettingsView, CodexService, ContentViewModel

import SwiftUI

struct ContentView: View {
    @Environment(CodexService.self) private var codex
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = ContentViewModel()
    @State private var isSidebarOpen = false
    @State private var sidebarDragOffset: CGFloat = 0
    @State private var selectedThread: CodexThread?
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false
    @State private var isShowingConnectionSetup = false
    @State private var isShowingPairingScanner = false
    @State private var isSearchActive = false
    @AppStorage("codex.hasSeenOnboarding") private var hasSeenOnboarding = false

    private let sidebarWidth: CGFloat = 330
    private static let sidebarSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        rootContent
            // Keep launch/foreground reconnect observers alive even while the QR scanner is visible.
            .task {
                await viewModel.attemptAutoConnectOnLaunchIfNeeded(codex: codex)
            }
            .onChange(of: showSettings) { _, show in
                if show {
                    navigationPath.append("settings")
                    showSettings = false
                }
            }
            .onChange(of: isSidebarOpen) { wasOpen, isOpen in
                guard !wasOpen, isOpen else {
                    return
                }
                if viewModel.shouldRequestSidebarFreshSync(isConnected: codex.isConnected) {
                    codex.requestImmediateSync(threadId: codex.activeThreadId)
                }
            }
            .onChange(of: navigationPath) { _, _ in
                if isSidebarOpen {
                    closeSidebar()
                }
            }
            .onChange(of: selectedThread) { previousThread, thread in
                codex.handleDisplayedThreadChange(
                    from: previousThread?.id,
                    to: thread?.id
                )
                codex.activeThreadId = thread?.id
            }
            .onChange(of: codex.activeThreadId) { _, activeThreadId in
                guard let activeThreadId,
                      let matchingThread = codex.threads.first(where: { $0.id == activeThreadId }),
                      selectedThread?.id != matchingThread.id else {
                    return
                }
                selectedThread = matchingThread
            }
            .onChange(of: codex.threads) { _, threads in
                syncSelectedThread(with: threads)
            }
            .onChange(of: scenePhase) { _, phase in
                codex.setForegroundState(phase != .background)
                if phase == .active {
                    Task {
                        await viewModel.attemptAutoReconnectOnForegroundIfNeeded(codex: codex)
                    }
                }
            }
            .onChange(of: codex.shouldAutoReconnectOnForeground) { _, shouldReconnect in
                guard shouldReconnect, scenePhase == .active else {
                    return
                }
                Task {
                    await viewModel.attemptAutoReconnectOnForegroundIfNeeded(codex: codex)
                }
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                withAnimation { hasSeenOnboarding = true }
            }
        } else if codex.isConnected || viewModel.isAttemptingAutoReconnect || shouldShowReconnectShell {
            mainAppBody
        } else {
            connectionSetupBody
        }
    }

    private var connectionSetupBody: some View {
        ConnectionSetupView(
            isConnecting: codex.isConnecting || viewModel.isAttemptingAutoReconnect,
            lastErrorMessage: codex.lastErrorMessage,
            suggestedServerURL: viewModel.suggestedServerURL ?? AppEnvironment.serverURL,
            canReturnToReconnectShell: codex.hasSavedServerConnection,
            tailscaleDiscoveryStatus: viewModel.tailscaleDiscoveryStatus,
            isSearchingTailscale: viewModel.isDiscoveringTailscaleServer,
            onConnect: { serverURL in
                Task {
                    await viewModel.connect(serverURL: serverURL, codex: codex)
                }
            },
            onRetryTailscaleDiscovery: {
                Task {
                    await viewModel.retryTailscaleDiscovery(codex: codex)
                }
            },
            onScanQRCode: {
                isShowingPairingScanner = true
            },
            onCancel: {
                withAnimation { isShowingConnectionSetup = false }
            }
        )
        .task {
            await viewModel.attemptTailscaleDiscoveryIfNeeded(codex: codex, force: false)
        }
        .fullScreenCover(isPresented: $isShowingPairingScanner) {
            QRScannerView { target in
                Task {
                    isShowingPairingScanner = false
                    await viewModel.connect(serverURL: target, codex: codex)
                }
            }
        }
    }

    private var directConnectButton: some View {
        Button("Connect to Another Server") {
            withAnimation { isShowingConnectionSetup = true }
        }
        .buttonStyle(.bordered)
        .disabled(codex.isConnecting || viewModel.isAttemptingAutoReconnect)
    }

    private var qrScanButton: some View {
        Button("Scan Server QR") {
            isShowingPairingScanner = true
        }
        .buttonStyle(.bordered)
        .disabled(codex.isConnecting || viewModel.isAttemptingAutoReconnect)
        .fullScreenCover(isPresented: $isShowingPairingScanner) {
            QRScannerView { target in
                Task {
                    isShowingPairingScanner = false
                    await viewModel.connect(serverURL: target, codex: codex)
                }
            }
        }
    }

    private var effectiveSidebarWidth: CGFloat {
        isSearchActive ? UIScreen.main.bounds.width : sidebarWidth
    }

    private var mainAppBody: some View {
        ZStack(alignment: .leading) {
            if sidebarVisible {
                SidebarView(
                    selectedThread: $selectedThread,
                    showSettings: $showSettings,
                    isSearchActive: $isSearchActive,
                    onClose: { closeSidebar() }
                )
                .frame(width: effectiveSidebarWidth)
                .animation(.easeInOut(duration: 0.25), value: isSearchActive)
            }

            mainNavigationLayer
                .offset(x: contentOffset)

            if sidebarVisible {
                (colorScheme == .dark ? Color.white : Color.black)
                    .opacity(contentDimOpacity)
                    .ignoresSafeArea()
                    .offset(x: contentOffset)
                    .allowsHitTesting(isSidebarOpen)
                    .onTapGesture { closeSidebar() }
            }
        }
        .gesture(edgeDragGesture)
    }

    // MARK: - Layers

    private var mainNavigationLayer: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .adaptiveNavigationBar()
                .navigationDestination(for: String.self) { destination in
                    if destination == "settings" {
                        SettingsView()
                            .adaptiveNavigationBar()
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var mainContent: some View {
        if let thread = selectedThread {
            TurnView(thread: thread)
                .id(thread.id)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        hamburgerButton
                    }
                }
        } else {
            HomeEmptyStateView(
                isConnected: codex.isConnected,
                isConnecting: codex.isConnecting || viewModel.isAttemptingAutoReconnect,
                onToggleConnection: {
                    Task {
                        await viewModel.toggleConnection(codex: codex)
                    }
                }
            ) {
                if codex.hasSavedServerConnection && !codex.isConnected {
                    directConnectButton
                    qrScanButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    hamburgerButton
                }
            }
        }
    }

    private var hamburgerButton: some View {
        Button {
            HapticFeedback.shared.triggerImpactFeedback(style: .light)
            toggleSidebar()
        } label: {
            TwoLineHamburgerIcon()
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                .padding(8)
                .contentShape(Circle())
                .adaptiveToolbarItem(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
    }

    // MARK: - Sidebar Geometry

    private var sidebarVisible: Bool {
        isSidebarOpen || sidebarDragOffset > 0
    }

    private var contentOffset: CGFloat {
        if isSidebarOpen {
            return max(0, effectiveSidebarWidth + sidebarDragOffset)
        } else {
            return max(0, sidebarDragOffset)
        }
    }

    private var contentDimOpacity: Double {
        let progress = min(1, contentOffset / effectiveSidebarWidth)
        return 0.08 * progress
    }

    // MARK: - Gestures

    private var edgeDragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard navigationPath.isEmpty else { return }

                if !isSidebarOpen {
                    guard value.startLocation.x < 30 else { return }
                    sidebarDragOffset = max(0, value.translation.width)
                } else {
                    sidebarDragOffset = min(0, value.translation.width)
                }
            }
            .onEnded { value in
                guard navigationPath.isEmpty else { return }

                let currentWidth = effectiveSidebarWidth
                let threshold = currentWidth * 0.4

                if !isSidebarOpen {
                    guard value.startLocation.x < 30 else {
                        sidebarDragOffset = 0
                        return
                    }
                    let shouldOpen = value.translation.width > threshold
                        || value.predictedEndTranslation.width > currentWidth * 0.5
                    finishGesture(open: shouldOpen)
                } else {
                    let shouldClose = -value.translation.width > threshold
                        || -value.predictedEndTranslation.width > currentWidth * 0.5
                    finishGesture(open: !shouldClose)
                }
            }
    }

    // MARK: - Sidebar Actions

    private func toggleSidebar() {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        withAnimation(Self.sidebarSpring) {
            isSidebarOpen.toggle()
            sidebarDragOffset = 0
        }
    }

    private func closeSidebar() {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        withAnimation(Self.sidebarSpring) {
            isSidebarOpen = false
            sidebarDragOffset = 0
        }
    }

    // Shows the remembered pairing shell after app relaunch so the user can reconnect without rescanning.
    private var shouldShowReconnectShell: Bool {
        codex.hasSavedServerConnection && !isShowingConnectionSetup
    }

    private func finishGesture(open: Bool) {
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        withAnimation(Self.sidebarSpring) {
            isSidebarOpen = open
            sidebarDragOffset = 0
        }
    }

    // Keeps selected thread coherent with server list updates.
    private func syncSelectedThread(with threads: [CodexThread]) {
        if let selected = selectedThread,
           !threads.contains(where: { $0.id == selected.id }) {
            if codex.activeThreadId == selected.id {
                return
            }
            selectedThread = codex.pendingNotificationOpenThreadID == nil ? threads.first : nil
            return
        }

        if let selected = selectedThread,
           let refreshed = threads.first(where: { $0.id == selected.id }) {
            selectedThread = refreshed
            return
        }

        if selectedThread == nil,
           codex.activeThreadId == nil,
           codex.pendingNotificationOpenThreadID == nil,
           let first = threads.first {
            selectedThread = first
        }
    }
}

private struct ConnectionSetupView: View {
    let isConnecting: Bool
    let lastErrorMessage: String?
    let suggestedServerURL: String?
    let canReturnToReconnectShell: Bool
    let tailscaleDiscoveryStatus: TailscaleDiscoveryStatus
    let isSearchingTailscale: Bool
    let onConnect: (String) -> Void
    let onRetryTailscaleDiscovery: () -> Void
    let onScanQRCode: () -> Void
    let onCancel: () -> Void

    @State private var serverURL = ""

    private var trimmedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var commandExample: String {
        "codex app-server --listen ws://0.0.0.0:4200"
    }

    private var isConnectDisabled: Bool {
        trimmedServerURL.isEmpty || isConnecting
    }

    var body: some View {
        ZStack {
            CodexBrandBackdrop()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        CodexBrandMark(size: 68)

                        Text("Connect to Codex on your Mac")
                            .font(AppFont.title2(weight: .bold))
                            .foregroundStyle(CodexBrand.ink)

                        Text("Run Codex app-server on your Mac. If this iPhone is already on Tailscale, MiniDex will try to find it automatically. Otherwise, paste the WebSocket URL here or scan a QR code.")
                            .font(AppFont.callout())
                            .foregroundStyle(CodexBrand.ink.opacity(0.82))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(CodexBrand.cardStroke, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Low-friction setup")
                            .font(AppFont.caption(weight: .semibold))
                            .foregroundStyle(CodexBrand.accentMuted)
                            .textCase(.uppercase)

                        tailscaleDiscoveryCard

                        Text("Run this on your Mac:")
                            .font(AppFont.subheadline(weight: .medium))
                            .foregroundStyle(CodexBrand.ink)

                        ConnectionCommandRow(command: commandExample)

                        Text("Then connect with a reachable URL such as `ws://192.168.1.25:4200` on local Wi-Fi or `ws://100.x.y.z:4200` over Tailscale.")
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(AppFont.caption(weight: .semibold))
                                .foregroundStyle(CodexBrand.ink)

                            TextField("ws://your-mac:4200", text: $serverURL)
                                .font(AppFont.mono(.callout))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(CodexBrand.cardSurfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let lastErrorMessage, !lastErrorMessage.isEmpty {
                            Text(lastErrorMessage)
                                .font(AppFont.caption())
                                .foregroundStyle(.red)
                        }

                        Button {
                            onConnect(trimmedServerURL)
                        } label: {
                            HStack(spacing: 10) {
                                if isConnecting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bolt.horizontal.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                Text(isConnecting ? "Connecting..." : "Connect to Server")
                                    .font(AppFont.body(weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [CodexBrand.accent, CodexBrand.ink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isConnectDisabled)
                        .opacity(isConnectDisabled ? 0.7 : 1)
                    }
                    .padding(22)
                    .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(CodexBrand.cardStroke, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Other options")
                            .font(AppFont.caption(weight: .semibold))
                            .foregroundStyle(CodexBrand.accentMuted)
                            .textCase(.uppercase)

                        Button {
                            onScanQRCode()
                        } label: {
                            Label("Scan Server QR", systemImage: "qrcode.viewfinder")
                                .font(AppFont.subheadline(weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CodexBrand.ink)
                        .disabled(isConnecting)

                        if canReturnToReconnectShell {
                            Button("Back to saved connection") {
                                onCancel()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isConnecting)
                        }
                    }

                    Text("MiniDex connects straight to Codex app-server, so there is no extra Mac companion package to install.")
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .onAppear {
                    if serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        serverURL = suggestedServerURL ?? ""
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tailscaleDiscoveryCard: some View {
        if shouldShowTailscaleDiscoveryCard {
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

                if !isSearchingTailscale {
                    Button("Retry Tailscale Discovery") {
                        onRetryTailscaleDiscovery()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var shouldShowTailscaleDiscoveryCard: Bool {
        isSearchingTailscale || tailscaleDiscoveryStatus != .idle
    }

    private var tailscaleDiscoveryPrimaryText: String {
        switch tailscaleDiscoveryStatus {
        case .idle:
            return "If your phone is connected to Tailscale, MiniDex checks the local Tailscale client and probes your Macs automatically."
        case .searching:
            return "Reading peers from Tailscale on this iPhone and probing for a reachable Codex host..."
        case .found:
            return "Found a Codex host and trying to connect."
        case .unavailable:
            return "No reachable Codex host was found on Tailscale. Enter a host or IP manually."
        case .failed(let message):
            return message
        }
    }
}

private struct ConnectionCommandRow: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            Text(command)
                .font(AppFont.mono(.caption))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .padding(.leading, 10)
                .padding(.vertical, 8)

            Spacer(minLength: 4)

            Button {
                UIPasteboard.general.string = command
                HapticFeedback.shared.triggerImpactFeedback(style: .light)
                withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                }
            } label: {
                Group {
                    if copied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image("copy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CodexBrand.cardSurfaceStrong)
        )
    }
}

private struct TwoLineHamburgerIcon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 20, height: 2)

            RoundedRectangle(cornerRadius: 1)
                .frame(width: 10, height: 2)
        }
        .frame(width: 20, height: 14, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .environment(CodexService())
}
