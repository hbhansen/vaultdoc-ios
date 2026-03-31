import SwiftUI

struct BrandPalette {
    let backgroundTop: Color
    let backgroundMiddle: Color
    let backgroundBottom: Color
    let surface: Color
    let elevatedSurface: Color
    let border: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let accentBright: Color
    let accentCool: Color
    let accentMuted: Color
    let actionForeground: Color
    let alert: Color
}

enum BrandAppearance: String, CaseIterable, Identifiable, Codable {
    case classic
    case midnight
    case sunrise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .midnight:
            return "Midnight"
        case .sunrise:
            return "Sunrise"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:
            return "Cool blue and glass"
        case .midnight:
            return "Deep slate and neon"
        case .sunrise:
            return "Warm gold and coral"
        }
    }

    var appIconName: String? {
        switch self {
        case .classic:
            return nil
        case .midnight:
            return "AppIconMidnight"
        case .sunrise:
            return "AppIconSunrise"
        }
    }

    var palette: BrandPalette {
        switch self {
        case .classic:
            return BrandPalette(
                backgroundTop: Color(red: 0.95, green: 0.97, blue: 1.00),
                backgroundMiddle: Color(red: 0.90, green: 0.94, blue: 0.99),
                backgroundBottom: Color(red: 0.84, green: 0.89, blue: 0.97),
                surface: Color.white.opacity(0.72),
                elevatedSurface: Color.white.opacity(0.90),
                border: Color(red: 0.33, green: 0.46, blue: 0.72).opacity(0.20),
                textPrimary: Color(red: 0.09, green: 0.14, blue: 0.28),
                textSecondary: Color(red: 0.31, green: 0.40, blue: 0.58),
                accent: Color(red: 0.14, green: 0.23, blue: 0.60),
                accentBright: Color(red: 0.32, green: 0.60, blue: 0.88),
                accentCool: Color(red: 0.21, green: 0.73, blue: 0.76),
                accentMuted: Color(red: 0.56, green: 0.67, blue: 0.85),
                actionForeground: .white,
                alert: Color(red: 0.86, green: 0.15, blue: 0.15)
            )
        case .midnight:
            return BrandPalette(
                backgroundTop: Color(red: 0.06, green: 0.08, blue: 0.14),
                backgroundMiddle: Color(red: 0.09, green: 0.11, blue: 0.22),
                backgroundBottom: Color(red: 0.05, green: 0.17, blue: 0.26),
                surface: Color.white.opacity(0.10),
                elevatedSurface: Color.white.opacity(0.16),
                border: Color(red: 0.45, green: 0.67, blue: 0.95).opacity(0.26),
                textPrimary: Color(red: 0.92, green: 0.96, blue: 1.00),
                textSecondary: Color(red: 0.64, green: 0.76, blue: 0.90),
                accent: Color(red: 0.28, green: 0.49, blue: 0.95),
                accentBright: Color(red: 0.48, green: 0.78, blue: 1.00),
                accentCool: Color(red: 0.23, green: 0.89, blue: 0.80),
                accentMuted: Color(red: 0.45, green: 0.53, blue: 0.88),
                actionForeground: .white,
                alert: Color(red: 1.00, green: 0.47, blue: 0.47)
            )
        case .sunrise:
            return BrandPalette(
                backgroundTop: Color(red: 1.00, green: 0.96, blue: 0.91),
                backgroundMiddle: Color(red: 1.00, green: 0.90, blue: 0.82),
                backgroundBottom: Color(red: 0.98, green: 0.79, blue: 0.68),
                surface: Color.white.opacity(0.68),
                elevatedSurface: Color.white.opacity(0.84),
                border: Color(red: 0.78, green: 0.44, blue: 0.29).opacity(0.18),
                textPrimary: Color(red: 0.31, green: 0.16, blue: 0.10),
                textSecondary: Color(red: 0.54, green: 0.31, blue: 0.22),
                accent: Color(red: 0.79, green: 0.34, blue: 0.18),
                accentBright: Color(red: 0.98, green: 0.63, blue: 0.29),
                accentCool: Color(red: 0.91, green: 0.52, blue: 0.50),
                accentMuted: Color(red: 0.94, green: 0.74, blue: 0.43),
                actionForeground: .white,
                alert: Color(red: 0.72, green: 0.16, blue: 0.11)
            )
        }
    }
}

enum BrandTheme {
    static var currentAppearance: BrandAppearance { AppConfigStore.shared.brandAppearance }
    static var palette: BrandPalette { currentAppearance.palette }

    static var backgroundTop: Color { palette.backgroundTop }
    static var backgroundMiddle: Color { palette.backgroundMiddle }
    static var backgroundBottom: Color { palette.backgroundBottom }
    static var surface: Color { palette.surface }
    static var elevatedSurface: Color { palette.elevatedSurface }
    static var border: Color { palette.border }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var accent: Color { palette.accent }
    static var accentBright: Color { palette.accentBright }
    static var accentCool: Color { palette.accentCool }
    static var accentMuted: Color { palette.accentMuted }
    static var actionForeground: Color { palette.actionForeground }
    static var alert: Color { palette.alert }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundMiddle, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentBright, accentCool],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var coolAccentGradient: LinearGradient {
        LinearGradient(
            colors: [accentBright.opacity(0.95), accentCool],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var sunburstGradient: LinearGradient {
        LinearGradient(
            colors: [accentMuted, accentBright, accentCool],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var heroGradient: RadialGradient {
        RadialGradient(
            colors: [
                accentBright.opacity(0.28),
                accent.opacity(0.16),
                .clear
            ],
            center: .topLeading,
            startRadius: 12,
            endRadius: 360
        )
    }

    static var secondaryGlow: RadialGradient {
        RadialGradient(
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
