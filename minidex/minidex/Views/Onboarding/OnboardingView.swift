// FILE: OnboardingView.swift
// Purpose: One-time onboarding screen shown before the first QR scan.
// Layer: View
// Exports: OnboardingView
// Depends on: SwiftUI

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    @State private var selectedRoute: OnboardingPairingRoute = .localNetwork

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

                            Text("Connect once, then monitor runs, review approvals, and steer active work from your phone without inheriting somebody else's product shell.")
                                .font(AppFont.callout())
                                .foregroundStyle(CodexBrand.ink.opacity(0.82))

                            HStack(spacing: 10) {
                                OnboardingFeatureBadge(title: "Live threads")
                                OnboardingFeatureBadge(title: "Fast approvals")
                                OnboardingFeatureBadge(title: "Git aware")
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.top, max(32, geo.safeAreaInsets.top + 8))

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick setup")
                                .font(AppFont.caption(weight: .semibold))
                                .foregroundStyle(CodexBrand.accentMuted)
                                .textCase(.uppercase)

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

                        Button(action: onContinue) {
                            HStack(spacing: 10) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Open Connection Setup")
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
        .preferredColorScheme(.light)
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
            return "Fastest path when your phone and Mac can reach each other directly."
        case .tailscale:
            return "Use your tailnet when the Mac is away from the phone's local network."
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
                    title: "Find your Mac's local IP address",
                    command: "ipconfig getifaddr en0",
                    subtitle: "If you're on Ethernet or another interface, use that address instead."
                ),
                OnboardingSetupStep(
                    title: "Enter the server URL in MiniDex",
                    subtitle: "Use `ws://<your-mac-ip>:4200`, or scan any QR code that contains that WebSocket URL."
                )
            ]
        case .tailscale:
            return [
                OnboardingSetupStep(
                    title: "Start Codex app-server on your Mac",
                    command: "codex app-server --listen ws://0.0.0.0:4200"
                ),
                OnboardingSetupStep(
                    title: "Get your Mac's Tailscale address",
                    command: "tailscale ip -4",
                    subtitle: "A MagicDNS hostname works too, as long as both devices are signed into the same tailnet."
                ),
                OnboardingSetupStep(
                    title: "Enter the Tailscale server URL in MiniDex",
                    subtitle: "Use `ws://<tailscale-ip-or-name>:4200`, or scan a QR code containing that URL."
                ),
            ]
        }
    }

    var footerNote: String {
        switch self {
        case .localNetwork:
            return "MiniDex can talk directly to Codex app-server, so you can pair with just Codex running on your Mac and a reachable WebSocket URL."
        case .tailscale:
            return "Tailscale keeps the direct Codex app-server workflow intact while giving your phone a stable tailnet route back to your Mac."
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
                            .fill(selection == route ? Color.white.opacity(0.9) : Color.white.opacity(0.58))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selection == route ? CodexBrand.accent.opacity(0.6) : Color.white.opacity(0.5), lineWidth: 1)
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
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
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
            .background(Color.white.opacity(0.72), in: Capsule())
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
                .fill(Color.white.opacity(0.84))
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView {
        print("Continue tapped")
    }
}
