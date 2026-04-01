import SwiftUI
import UIKit

enum ThemeToken: CaseIterable {
    case backgroundPrimary
    case backgroundSecondary
    case surface
    case surfaceElevated
    case border
    case textPrimary
    case textSecondary
    case accentPrimary
    case accentBright
    case accentCool
    case accentMuted
    case actionForeground
    case alert
}

private struct ThemePalette {
    let gradientStops: [UIColor]
    let colors: [ThemeToken: UIColor]
    let shadow: UIColor
    let positive: UIColor
    let warning: UIColor

    func color(_ token: ThemeToken) -> UIColor {
        colors[token] ?? .clear
    }
}

enum BrandTheme {
    private static let lightPalette = ThemePalette(
        gradientStops: [
            UIColor(hex: 0xEDF2F7),
            UIColor(hex: 0xE5EBF2),
            UIColor(hex: 0xDCE3EC)
        ],
        colors: [
            .backgroundPrimary: UIColor(hex: 0xEDF2F7),
            .backgroundSecondary: UIColor(hex: 0xE5EBF2),
            .surface: UIColor(hex: 0xFFFFFF, alpha: 0.88),
            .surfaceElevated: UIColor(hex: 0xFFFFFF, alpha: 0.96),
            .border: UIColor(hex: 0x5E7391, alpha: 0.16),
            .textPrimary: UIColor(hex: 0x152033),
            .textSecondary: UIColor(hex: 0x556274),
            .accentPrimary: UIColor(hex: 0x1C4FD8),
            .accentBright: UIColor(hex: 0x63A6FA),
            .accentCool: UIColor(hex: 0x14B8A6),
            .accentMuted: UIColor(hex: 0x94A8C4),
            .actionForeground: UIColor(hex: 0xFFFFFF),
            .alert: UIColor(hex: 0xDB2626)
        ],
        shadow: UIColor(hex: 0x18263A, alpha: 0.05),
        positive: UIColor(hex: 0x14B8A6),
        warning: UIColor(hex: 0x1C4FD8)
    )

    private static let darkPalette = ThemePalette(
        gradientStops: [
            UIColor(hex: 0x0A1222),
            UIColor(hex: 0x0D1830),
            UIColor(hex: 0x172150)
        ],
        colors: [
            .backgroundPrimary: UIColor(hex: 0x0A1222),
            .backgroundSecondary: UIColor(hex: 0x0D1830),
            .surface: UIColor(hex: 0xFFFFFF, alpha: 0.08),
            .surfaceElevated: UIColor(hex: 0xFFFFFF, alpha: 0.14),
            .border: UIColor(hex: 0x5E7391, alpha: 0.24),
            .textPrimary: UIColor(hex: 0xF7FAFE),
            .textSecondary: UIColor(hex: 0xCDD6E0),
            .accentPrimary: UIColor(hex: 0x1C4FD8),
            .accentBright: UIColor(hex: 0x63A6FA),
            .accentCool: UIColor(hex: 0x14B8A6),
            .accentMuted: UIColor(hex: 0x7F94B5),
            .actionForeground: UIColor(hex: 0xFFFFFF),
            .alert: UIColor(hex: 0xDB2626)
        ],
        shadow: UIColor(hex: 0x020611, alpha: 0.12),
        positive: UIColor(hex: 0x14B8A6),
        warning: UIColor(hex: 0x63A6FA)
    )

    private static func palette(for colorScheme: ColorScheme) -> ThemePalette {
        colorScheme == .dark ? darkPalette : lightPalette
    }

    private static func palette(for traitCollection: UITraitCollection) -> ThemePalette {
        traitCollection.userInterfaceStyle == .dark ? darkPalette : lightPalette
    }

    static func color(_ token: ThemeToken) -> Color {
        Color(uiColor: uiColor(token))
    }

    static func uiColor(_ token: ThemeToken) -> UIColor {
        UIColor { traitCollection in
            palette(for: traitCollection).color(token)
        }
    }

    static func uiColor(_ token: ThemeToken, alpha: CGFloat) -> UIColor {
        UIColor { traitCollection in
            palette(for: traitCollection).color(token).withAlphaComponent(alpha)
        }
    }

    static var backgroundPrimary: Color { color(.backgroundPrimary) }
    static var backgroundSecondary: Color { color(.backgroundSecondary) }
    static var surface: Color { color(.surface) }
    static var surfaceElevated: Color { color(.surfaceElevated) }
    static var border: Color { color(.border) }
    static var textPrimary: Color { color(.textPrimary) }
    static var textSecondary: Color { color(.textSecondary) }
    static var accentPrimary: Color { color(.accentPrimary) }
    static var accentBright: Color { color(.accentBright) }
    static var accentCool: Color { color(.accentCool) }
    static var accentMuted: Color { color(.accentMuted) }
    static var actionForeground: Color { color(.actionForeground) }
    static var alert: Color { color(.alert) }
    static var statusPositive: Color { Color(uiColor: statusPositiveUIColor) }
    static var statusWarning: Color { Color(uiColor: statusWarningUIColor) }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(uiColor: dynamicGradientStop(index: 0)),
                Color(uiColor: dynamicGradientStop(index: 1)),
                Color(uiColor: dynamicGradientStop(index: 2))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentPrimary, accentBright, accentCool],
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

    static var mutedAccentGradient: LinearGradient {
        LinearGradient(
            colors: [accentMuted, accentBright],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: RadialGradient {
        RadialGradient(
            colors: [
                accentBright.opacity(0.08),
                accentPrimary.opacity(0.05),
                .clear
            ],
            center: .topLeading,
            startRadius: 16,
            endRadius: 320
        )
    }

    static var secondaryGlow: RadialGradient {
        RadialGradient(
            colors: [
                accentCool.opacity(0.06),
                accentMuted.opacity(0.05),
                .clear
            ],
            center: .bottomTrailing,
            startRadius: 10,
            endRadius: 280
        )
    }

    static var glassFill: LinearGradient {
        LinearGradient(
            colors: [surfaceElevated, surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var chromeMaterial: Material {
        .ultraThinMaterial
    }

    static var shadowColor: Color {
        Color(uiColor: UIColor {
            palette(for: $0).shadow
        })
    }

    static var statusPositiveUIColor: UIColor {
        UIColor { palette(for: $0).positive }
    }

    static var statusWarningUIColor: UIColor {
        UIColor { palette(for: $0).warning }
    }

    static func applyUIKitAppearance() {
        let navigationChromeColor = UIColor { traitCollection in
            let currentPalette = palette(for: traitCollection)
            let alpha: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0.94 : 0.84
            return currentPalette.color(.backgroundSecondary).withAlphaComponent(alpha)
        }
        let toolbarChromeColor = UIColor { traitCollection in
            let currentPalette = palette(for: traitCollection)
            let alpha: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0.92 : 0.82
            return currentPalette.color(.backgroundSecondary).withAlphaComponent(alpha)
        }
        let tabChromeColor = UIColor { traitCollection in
            let currentPalette = palette(for: traitCollection)
            let alpha: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0.96 : 0.88
            return currentPalette.color(.backgroundSecondary).withAlphaComponent(alpha)
        }

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = nil
        navigationAppearance.backgroundColor = navigationChromeColor
        navigationAppearance.shadowColor = uiColor(.border)
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: uiColor(.textPrimary)
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: uiColor(.textPrimary)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigationAppearance
        navigationBar.scrollEdgeAppearance = navigationAppearance
        navigationBar.compactAppearance = navigationAppearance
        navigationBar.tintColor = uiColor(.accentPrimary)

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundEffect = nil
        toolbarAppearance.backgroundColor = toolbarChromeColor
        toolbarAppearance.shadowColor = uiColor(.border)

        let toolbar = UIToolbar.appearance()
        toolbar.standardAppearance = toolbarAppearance
        if #available(iOS 15.0, *) {
            toolbar.scrollEdgeAppearance = toolbarAppearance
        }
        toolbar.tintColor = uiColor(.accentPrimary)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = nil
        tabBarAppearance.backgroundColor = tabChromeColor
        tabBarAppearance.shadowColor = uiColor(.border)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = tabBarAppearance
        }
        tabBar.tintColor = uiColor(.accentPrimary)

        UISegmentedControl.appearance().selectedSegmentTintColor = uiColor(.accentPrimary)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: uiColor(.actionForeground)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: uiColor(.textSecondary)],
            for: .normal
        )

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        UISearchBar.appearance().tintColor = uiColor(.accentPrimary)
    }

    private static func dynamicGradientStop(index: Int) -> UIColor {
        UIColor { traitCollection in
            let stops = palette(for: traitCollection).gradientStops
            return stops[min(max(index, 0), stops.count - 1)]
        }
    }
}

struct ThemeAppearanceConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ThemeAppearanceViewController {
        ThemeAppearanceViewController()
    }

    func updateUIViewController(_ uiViewController: ThemeAppearanceViewController, context: Context) {
        uiViewController.applyThemeAppearance()
    }
}

final class ThemeAppearanceViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        applyThemeAppearance()
    }

    func applyThemeAppearance() {
        BrandTheme.applyUIKitAppearance()
        overrideUserInterfaceStyle = .unspecified
    }
}

struct BrandBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BrandTheme.backgroundGradient.ignoresSafeArea()
                    BrandTheme.heroGradient.ignoresSafeArea()
                    BrandTheme.secondaryGlow.ignoresSafeArea()
                    Circle()
                        .fill(BrandTheme.accentBright.opacity(0.03))
                        .frame(width: 260, height: 260)
                        .blur(radius: 50)
                        .offset(x: -180, y: 260)
                }
            }
            .background {
                ThemeAppearanceConfigurator()
                    .allowsHitTesting(false)
            }
    }
}

struct BrandCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandTheme.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    )
            )
            .shadow(color: BrandTheme.shadowColor, radius: 8, y: 3)
    }
}

struct BrandInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandTheme.surfaceElevated)
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
                .fill(BrandTheme.accentPrimary)
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

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
