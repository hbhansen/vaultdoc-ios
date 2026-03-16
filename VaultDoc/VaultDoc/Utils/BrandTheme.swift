import SwiftUI

enum BrandTheme {
    static let backgroundTop = Color(red: 0.05, green: 0.07, blue: 0.20)
    static let backgroundMiddle = Color(red: 0.13, green: 0.06, blue: 0.25)
    static let backgroundBottom = Color(red: 0.03, green: 0.10, blue: 0.16)
    static let surface = Color.white.opacity(0.10)
    static let elevatedSurface = Color.white.opacity(0.16)
    static let border = Color.white.opacity(0.18)
    static let textPrimary = Color(red: 0.98, green: 0.97, blue: 0.99)
    static let textSecondary = Color(red: 0.76, green: 0.84, blue: 0.92)
    static let accent = Color(red: 1.00, green: 0.45, blue: 0.38)
    static let accentBright = Color(red: 1.00, green: 0.83, blue: 0.32)
    static let accentCool = Color(red: 0.23, green: 0.84, blue: 0.92)
    static let accentMuted = Color(red: 0.39, green: 0.28, blue: 0.84)
    static let alert = Color(red: 0.86, green: 0.36, blue: 0.35)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentBright, accent, accentMuted],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coolAccentGradient = LinearGradient(
        colors: [accentCool, Color.white.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunburstGradient = LinearGradient(
        colors: [accentBright, accent, accentCool],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let heroGradient = RadialGradient(
        colors: [
            accentBright.opacity(0.46),
            accent.opacity(0.22),
            .clear
        ],
        center: .topTrailing,
        startRadius: 12,
        endRadius: 320
    )

    static let secondaryGlow = RadialGradient(
        colors: [
            accentCool.opacity(0.35),
            accentMuted.opacity(0.16),
            .clear
        ],
        center: .bottomLeading,
        startRadius: 10,
        endRadius: 300
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
                    BrandTheme.secondaryGlow
                        .ignoresSafeArea()
                    Circle()
                        .fill(BrandTheme.accent.opacity(0.16))
                        .frame(width: 300, height: 300)
                        .blur(radius: 48)
                        .offset(x: -150, y: 240)
                    Circle()
                        .fill(BrandTheme.accentCool.opacity(0.18))
                        .frame(width: 220, height: 220)
                        .blur(radius: 44)
                        .offset(x: 140, y: 260)
                }
            }
    }
}

struct BrandCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BrandTheme.elevatedSurface, BrandTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
    }
}

struct BrandInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandTheme.elevatedSurface)
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
