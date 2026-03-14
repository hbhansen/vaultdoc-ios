import SwiftUI

enum BrandTheme {
    static let backgroundTop = Color(red: 0.09, green: 0.05, blue: 0.10)
    static let backgroundBottom = Color(red: 0.02, green: 0.03, blue: 0.05)
    static let surface = Color.white.opacity(0.08)
    static let elevatedSurface = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.14)
    static let textPrimary = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let textSecondary = Color(red: 0.83, green: 0.78, blue: 0.74)
    static let accent = Color(red: 0.86, green: 0.69, blue: 0.43)
    static let accentBright = Color(red: 0.95, green: 0.82, blue: 0.58)
    static let accentMuted = Color(red: 0.55, green: 0.40, blue: 0.27)
    static let alert = Color(red: 0.86, green: 0.36, blue: 0.35)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentBright, accent, accentMuted],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = RadialGradient(
        colors: [
            accentBright.opacity(0.42),
            accent.opacity(0.18),
            .clear
        ],
        center: .topTrailing,
        startRadius: 12,
        endRadius: 320
    )
}

struct BrandBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BrandTheme.backgroundGradient.ignoresSafeArea()
                    BrandTheme.heroGradient
                        .ignoresSafeArea()
                    Circle()
                        .fill(BrandTheme.accent.opacity(0.12))
                        .frame(width: 280, height: 280)
                        .blur(radius: 40)
                        .offset(x: -140, y: 220)
                }
            }
    }
}

struct BrandCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    )
            )
    }
}

struct BrandInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    )
            )
            .foregroundStyle(BrandTheme.textPrimary)
    }
}

extension View {
    func brandBackground() -> some View {
        modifier(BrandBackground())
    }

    func brandCard() -> some View {
        modifier(BrandCard())
    }

    func brandInputField() -> some View {
        modifier(BrandInputField())
    }
}
