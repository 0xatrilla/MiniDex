import SwiftUI

enum CodexBrand {
    static let accent = Color(red: 0.86, green: 0.42, blue: 0.14)
    static let accentSoft = Color(red: 0.98, green: 0.78, blue: 0.58)
    static let accentMuted = Color(red: 0.48, green: 0.28, blue: 0.20)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.92)
    static let mist = Color(red: 0.89, green: 0.89, blue: 0.86)
    static let success = Color(red: 0.19, green: 0.63, blue: 0.42)
}

struct CodexBrandBackdrop: View {
    var intensity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CodexBrand.paper,
                    Color.white,
                    CodexBrand.paper.opacity(0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(CodexBrand.accentSoft.opacity(0.22 * intensity))
                .frame(width: 320, height: 320)
                .blur(radius: 10)
                .offset(x: 120, y: -180)

            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CodexBrand.ink.opacity(0.08 * intensity),
                            CodexBrand.accent.opacity(0.14 * intensity),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 360, height: 240)
                .rotationEffect(.degrees(-18))
                .offset(x: -120, y: 260)
                .blur(radius: 1.5)
        }
        .ignoresSafeArea()
    }
}

struct CodexBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CodexBrand.ink, CodexBrand.accentMuted],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                .padding(size * 0.06)

            VStack(alignment: .leading, spacing: size * 0.08) {
                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(CodexBrand.accentSoft)
                    .frame(width: size * 0.44, height: size * 0.12)
                    .offset(x: size * 0.06)

                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.62, height: size * 0.12)

                HStack(spacing: size * 0.08) {
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .fill(CodexBrand.accent)
                        .frame(width: size * 0.16, height: size * 0.16)

                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .frame(width: size * 0.34, height: size * 0.16)
                }
            }
            .frame(width: size * 0.64, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .shadow(color: CodexBrand.accent.opacity(0.16), radius: size * 0.18, y: size * 0.08)
    }
}
