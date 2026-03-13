// FILE: TailscaleDiscoveryCandidatesView.swift
// Purpose: Shows live Tailscale discovery candidates while MiniDex scans for a reachable Mac.
// Layer: View
// Exports: TailscaleDiscoveryCandidatesView

import SwiftUI

struct TailscaleDiscoveryCandidatesView: View {
    let candidates: [TailscaleDiscoveryCandidate]

    var body: some View {
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live candidates")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(CodexBrand.accentMuted)
                    .textCase(.uppercase)

                VStack(spacing: 8) {
                    ForEach(Array(candidates.prefix(4))) { candidate in
                        row(for: candidate)
                    }
                }
            }
        }
    }

    private func row(for candidate: TailscaleDiscoveryCandidate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: candidate.state))
                .foregroundStyle(iconColor(for: candidate.state))
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(candidate.displayName)
                        .font(AppFont.caption(weight: .semibold))
                        .foregroundStyle(CodexBrand.ink)
                        .lineLimit(1)

                    Text(labelText(for: candidate.state))
                        .font(AppFont.caption2(weight: .semibold))
                        .foregroundStyle(iconColor(for: candidate.state))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(iconColor(for: candidate.state).opacity(0.14), in: Capsule())
                }

                Text(candidate.serverURL)
                    .font(AppFont.mono(.caption2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(candidate.sourceLabel)
                    .font(AppFont.caption2())
                    .foregroundStyle(.secondary.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CodexBrand.cardSurfaceStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func iconName(for state: TailscaleDiscoveryCandidateState) -> String {
        switch state {
        case .queued:
            return "clock"
        case .probing:
            return "dot.radiowaves.left.and.right"
        case .reachable:
            return "checkmark.circle.fill"
        case .unreachable:
            return "xmark.circle.fill"
        }
    }

    private func iconColor(for state: TailscaleDiscoveryCandidateState) -> Color {
        switch state {
        case .queued:
            return .secondary
        case .probing:
            return CodexBrand.accent
        case .reachable:
            return CodexBrand.success
        case .unreachable:
            return .red
        }
    }

    private func labelText(for state: TailscaleDiscoveryCandidateState) -> String {
        switch state {
        case .queued:
            return "Queued"
        case .probing:
            return "Checking"
        case .reachable:
            return "Codex ready"
        case .unreachable:
            return "No reply"
        }
    }
}
