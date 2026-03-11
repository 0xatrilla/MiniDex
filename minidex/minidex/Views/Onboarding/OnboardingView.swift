// FILE: OnboardingView.swift
// Purpose: One-time onboarding screen shown before the first QR scan.
// Layer: View
// Exports: OnboardingView
// Depends on: SwiftUI

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    @State private var selectedRoute: OnboardingPairingRoute = .tailscale
    @State private var isAutoContinuing = true
    @State private var hasTriggeredContinue = false

    var body: some View {
        ZStack {
            CodexBrandBackdrop()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center, spacing: 16) {
                                CodexBrandMark(size: 72)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("MiniDex")
                                        .font(AppFont.title2(weight: .bold))
                                        .foregroundStyle(CodexBrand.ink)

                                    Text("A mobile control room for the Codex session running on your Mac.")
                                        .font(AppFont.subheadline())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("Open the app while your iPhone and Mac are both connected to Tailscale and MiniDex should try to find Codex automatically. If you are off-tailnet, you can still connect with a host or IP.")
                                .font(AppFont.callout())
                                .foregroundStyle(CodexBrand.ink.opacity(0.82))

                            HStack(spacing: 10) {
                                OnboardingFeatureBadge(title: "Live threads")
                                OnboardingFeatureBadge(title: "Fast approvals")
                                OnboardingFeatureBadge(title: "Auto-discovery")
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(CodexBrand.cardStroke, lineWidth: 1)
                        )
                        .padding(.top, max(32, geo.safeAreaInsets.top + 8))

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick setup")
                                .font(AppFont.caption(weight: .semibold))
                                .foregroundStyle(CodexBrand.accentMuted)
                                .textCase(.uppercase)

                            if isAutoContinuing {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Starting connection setup automatically...")
                                        .font(AppFont.caption(weight: .medium))
                                        .foregroundStyle(CodexBrand.ink.opacity(0.82))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(CodexBrand.cardSurface, in: Capsule())
                            }

                            OnboardingRoutePicker(selection: $selectedRoute)

                            VStack(spacing: 14) {
                                ForEach(Array(selectedRoute.steps.enumerated()), id: \.offset) { index, step in
                                    OnboardingStepRow(
                                        number: "\(index + 1)",
                                        title: step.title,
                                        command: step.command,
                                        subtitle: step.subtitle
                                    )
                                }
                            }
                        }

                        Button(action: continueToSetup) {
                            HStack(spacing: 10) {
                                if isAutoContinuing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "network")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(isAutoContinuing ? "Opening Connection Setup..." : "Open Connection Setup")
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
                        .disabled(hasTriggeredContinue)

                        Text(selectedRoute.footerNote)
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .task {
            guard isAutoContinuing, !hasTriggeredContinue else {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            continueToSetup()
        }
    }

    private func continueToSetup() {
        guard !hasTriggeredContinue else {
            return
        }

        hasTriggeredContinue = true
        isAutoContinuing = false
        onContinue()
    }
}

private enum OnboardingPairingRoute: String, CaseIterable, Identifiable {
    case localNetwork
    case tailscale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localNetwork:
            return "Same network"
        case .tailscale:
            return "Tailscale"
        }
    }

    var subtitle: String {
        switch self {
        case .localNetwork:
            return "Use this when both devices can reach each other directly and you want to enter a host or IP yourself."
        case .tailscale:
            return "Best path when both devices are on the same tailnet. MiniDex checks the local Tailscale client first so discovery can just work."
        }
    }

    var steps: [OnboardingSetupStep] {
        switch self {
        case .localNetwork:
            return [
                OnboardingSetupStep(
                    title: "Start Codex app-server on your Mac",
                    command: "codex app-server --listen ws://0.0.0.0:4200"
                ),
                OnboardingSetupStep(
                    title: "Find your Mac's reachable local address",
                    command: "ipconfig getifaddr en0",
                    subtitle: "If you're on Ethernet or another interface, use that address instead."
                ),
                OnboardingSetupStep(
                    title: "Enter the host or IP in MiniDex",
                    subtitle: "Use `ws://<your-mac-ip>:4200`, or scan a QR code that contains that WebSocket URL."
                )
            ]
        case .tailscale:
            return [
                OnboardingSetupStep(
                    title: "Start Codex app-server on your Mac",
                    command: "codex app-server --listen ws://0.0.0.0:4200"
                ),
                OnboardingSetupStep(
                    title: "Keep both devices on the same tailnet",
                    subtitle: "MiniDex asks the Tailscale client on your iPhone for peers, then probes likely Macs for Codex when you open the app."
                ),
                OnboardingSetupStep(
                    title: "Fall back to a Tailscale host only if needed",
                    command: "tailscale ip -4",
                    subtitle: "If discovery does not connect right away, enter `ws://<tailscale-ip-or-name>:4200` manually. A MagicDNS hostname works too."
                ),
            ]
        }
    }

    var footerNote: String {
        switch self {
        case .localNetwork:
            return "Local network mode is the direct fallback: start Codex on your Mac, then type or scan a reachable WebSocket URL."
        case .tailscale:
            return "Tailscale mode is the preferred path: open the app and MiniDex should look for Codex on your Mac automatically before it asks for a host."
        }
    }
}

private struct OnboardingSetupStep {
    let title: String
    var command: String? = nil
    var subtitle: String? = nil
}

private struct OnboardingRoutePicker: View {
    @Binding var selection: OnboardingPairingRoute

    var body: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingPairingRoute.allCases) { route in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        selection = route
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.title)
                            .font(AppFont.subheadline(weight: .semibold))
                            .foregroundStyle(selection == route ? CodexBrand.ink : CodexBrand.ink.opacity(0.76))

                        Text(route.subtitle)
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selection == route ? CodexBrand.cardSurfaceStrong : CodexBrand.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selection == route ? CodexBrand.accent.opacity(0.6) : CodexBrand.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Step row

private struct OnboardingStepRow: View {
    let number: String
    let title: String
    var command: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.caption2(weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(CodexBrand.ink, in: Circle())
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFont.subheadline(weight: .medium))
                    .foregroundStyle(CodexBrand.ink)

                if let command {
                    OnboardingCommandRow(command: command)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption(weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(CodexBrand.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CodexBrand.cardStroke, lineWidth: 1)
        )
    }
}

private struct OnboardingFeatureBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.caption(weight: .medium))
            .foregroundStyle(CodexBrand.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CodexBrand.chipSurface, in: Capsule())
    }
}

// MARK: - Inline copy-able command

private struct OnboardingCommandRow: View {
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

// MARK: - Preview

#Preview {
    OnboardingView {
        print("Continue tapped")
    }
}
