import SwiftUI

enum BrandTheme {
    static let backgroundTop = Color(red: 0.04, green: 0.07, blue: 0.13)
    static let backgroundMiddle = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let backgroundBottom = Color(red: 0.09, green: 0.15, blue: 0.33)
    static let surface = Color.white.opacity(0.08)
    static let elevatedSurface = Color.white.opacity(0.14)
    static let border = Color(red: 0.37, green: 0.45, blue: 0.57).opacity(0.35)
    static let textPrimary = Color(red: 0.97, green: 0.98, blue: 0.99)
    static let textSecondary = Color(red: 0.80, green: 0.84, blue: 0.88)
    static let accent = Color(red: 0.11, green: 0.31, blue: 0.85)
    static let accentBright = Color(red: 0.38, green: 0.65, blue: 0.98)
    static let accentCool = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let accentMuted = Color(red: 0.20, green: 0.29, blue: 0.47)
    static let alert = Color(red: 0.86, green: 0.15, blue: 0.15)

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
        colors: [accentCool, accentBright.opacity(0.9)],
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
            accentBright.opacity(0.28),
            accent.opacity(0.18),
            .clear
        ],
        center: .topTrailing,
        startRadius: 12,
        endRadius: 320
    )

    static let secondaryGlow = RadialGradient(
        colors: [
            accentCool.opacity(0.18),
            accentMuted.opacity(0.12),
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
