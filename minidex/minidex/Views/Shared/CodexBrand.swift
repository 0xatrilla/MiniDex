import SwiftUI
import UIKit

enum CodexBrand {
    static let accent = Color(red: 0.86, green: 0.42, blue: 0.14)
    static let accentSoft = Color(red: 0.98, green: 0.78, blue: 0.58)
    static let accentMuted = dynamicColor(
        light: UIColor(red: 0.48, green: 0.28, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.83, green: 0.63, blue: 0.49, alpha: 1)
    )
    static let ink = dynamicColor(
        light: UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    )
    static let paper = dynamicColor(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    )
    static let mist = dynamicColor(
        light: UIColor(red: 0.89, green: 0.89, blue: 0.86, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
    )
    static let success = Color(red: 0.19, green: 0.63, blue: 0.42)
    static let cardSurface = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.68),
        dark: UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 0.84)
    )
    static let cardSurfaceStrong = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.84),
        dark: UIColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 0.92)
    )
    static let cardStroke = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.55),
        dark: UIColor(red: 1, green: 1, blue: 1, alpha: 0.12)
    )
    static let chipSurface = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.76),
        dark: UIColor(red: 0.18, green: 0.19, blue: 0.23, alpha: 0.88)
    )
    static let markNeutral = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.92),
        dark: UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 0.92)
    )
    static let markNeutralSoft = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.72),
        dark: UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 0.70)
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

struct CodexBrandBackdrop: View {
    var intensity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CodexBrand.paper,
                    CodexBrand.mist,
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
                .strokeBorder(CodexBrand.cardStroke.opacity(0.45), lineWidth: 1)
                .padding(size * 0.06)

            VStack(alignment: .leading, spacing: size * 0.08) {
                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(CodexBrand.accentSoft)
                    .frame(width: size * 0.44, height: size * 0.12)
                    .offset(x: size * 0.06)

                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(CodexBrand.markNeutral)
                    .frame(width: size * 0.62, height: size * 0.12)

                HStack(spacing: size * 0.08) {
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .fill(CodexBrand.accent)
                        .frame(width: size * 0.16, height: size * 0.16)

                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .fill(CodexBrand.markNeutralSoft)
                        .frame(width: size * 0.34, height: size * 0.16)
                }
            }
            .frame(width: size * 0.64, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .shadow(color: CodexBrand.accent.opacity(0.16), radius: size * 0.18, y: size * 0.08)
    }
}
