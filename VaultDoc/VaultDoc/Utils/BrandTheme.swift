import SwiftUI

enum BrandTheme {
    static let backgroundTop = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let backgroundMiddle = Color(red: 0.90, green: 0.94, blue: 0.99)
    static let backgroundBottom = Color(red: 0.84, green: 0.89, blue: 0.97)
    static let surface = Color.white.opacity(0.72)
    static let elevatedSurface = Color.white.opacity(0.90)
    static let border = Color(red: 0.33, green: 0.46, blue: 0.72).opacity(0.20)
    static let textPrimary = Color(red: 0.09, green: 0.14, blue: 0.28)
    static let textSecondary = Color(red: 0.31, green: 0.40, blue: 0.58)
    static let accent = Color(red: 0.14, green: 0.23, blue: 0.60)
    static let accentBright = Color(red: 0.32, green: 0.60, blue: 0.88)
    static let accentCool = Color(red: 0.21, green: 0.73, blue: 0.76)
    static let accentMuted = Color(red: 0.56, green: 0.67, blue: 0.85)
    static let actionForeground = Color.white
    static let alert = Color(red: 0.86, green: 0.15, blue: 0.15)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accentBright, accentCool],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coolAccentGradient = LinearGradient(
        colors: [accentBright.opacity(0.95), accentCool],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunburstGradient = LinearGradient(
        colors: [accentMuted, accentBright, accentCool],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let heroGradient = RadialGradient(
        colors: [
            accentBright.opacity(0.28),
            accent.opacity(0.16),
            .clear
        ],
        center: .topLeading,
        startRadius: 12,
        endRadius: 360
    )

    static let secondaryGlow = RadialGradient(
        colors: [
            accentCool.opacity(0.16),
            accentMuted.opacity(0.14),
            .clear
        ],
        center: .bottomTrailing,
        startRadius: 10,
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
                    BrandTheme.secondaryGlow
                        .ignoresSafeArea()
                    Circle()
                        .fill(BrandTheme.accentBright.opacity(0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 56)
                        .offset(x: -160, y: 250)
                    Circle()
                        .fill(BrandTheme.accentCool.opacity(0.14))
                        .frame(width: 240, height: 240)
                        .blur(radius: 48)
                        .offset(x: 150, y: 270)
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
            .shadow(color: BrandTheme.accent.opacity(0.10), radius: 22, y: 12)
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

struct BrandMark: View {
    let size: CGFloat

    private var documentWidth: CGFloat { size * 0.58 }
    private var documentHeight: CGFloat { size * 0.72 }
    private var shieldSize: CGFloat { size * 0.40 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            documentGlyph
                .offset(x: -size * 0.06, y: -size * 0.02)

            shieldGlyph
                .offset(x: size * 0.02, y: size * 0.03)
        }
        .frame(width: size, height: size)
    }

    private var documentGlyph: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(BrandTheme.accent)
                .frame(width: documentWidth, height: documentHeight)

            Path { path in
                let fold = documentWidth * 0.22
                path.move(to: CGPoint(x: documentWidth - fold, y: 0))
                path.addLine(to: CGPoint(x: documentWidth, y: fold))
                path.addLine(to: CGPoint(x: documentWidth - fold, y: fold))
                path.closeSubpath()
            }
            .fill(BrandTheme.accentBright)
            .frame(width: documentWidth, height: documentHeight, alignment: .topLeading)

            VStack(alignment: .leading, spacing: size * 0.05) {
                Capsule()
                    .fill(BrandTheme.accentMuted.opacity(0.95))
                    .frame(width: documentWidth * 0.62, height: size * 0.03)
                Capsule()
                    .fill(BrandTheme.accentMuted.opacity(0.88))
                    .frame(width: documentWidth * 0.54, height: size * 0.028)
                Capsule()
                    .fill(BrandTheme.accentMuted.opacity(0.82))
                    .frame(width: documentWidth * 0.46, height: size * 0.028)
                Capsule()
                    .fill(BrandTheme.accentMuted.opacity(0.72))
                    .frame(width: documentWidth * 0.30, height: size * 0.026)
            }
            .padding(.top, documentHeight * 0.30)
            .padding(.leading, documentWidth * 0.14)
        }
    }

    private var shieldGlyph: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: shieldSize, height: shieldSize)
                .foregroundStyle(BrandTheme.coolAccentGradient)
                .shadow(color: BrandTheme.accentCool.opacity(0.18), radius: 12, y: 8)

            Image(systemName: "lock.fill")
                .font(.system(size: shieldSize * 0.34, weight: .bold))
                .foregroundStyle(BrandTheme.actionForeground)
                .offset(y: -shieldSize * 0.02)
        }
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
