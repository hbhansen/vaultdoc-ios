import SwiftUI

struct OpeningSplashView: View {
    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 760
            let iconSize = isCompactHeight ? 118.0 : 144.0
            let outerSize = isCompactHeight ? 180.0 : 216.0

            ZStack {
                BrandTheme.backgroundGradient
                    .ignoresSafeArea()

                BrandTheme.heroGradient
                    .ignoresSafeArea()

                BrandTheme.secondaryGlow
                    .ignoresSafeArea()

                Circle()
                    .fill(BrandTheme.accentPrimary.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 56)
                    .offset(x: geometry.size.width * 0.32, y: -geometry.size.height * 0.22)

                Circle()
                    .fill(BrandTheme.accentCool.opacity(0.12))
                    .frame(width: 240, height: 240)
                    .blur(radius: 54)
                    .offset(x: -geometry.size.width * 0.28, y: geometry.size.height * 0.24)

                VStack(spacing: isCompactHeight ? 24 : 32) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(BrandTheme.surfaceElevated.opacity(0.65))
                            .frame(width: outerSize, height: outerSize)
                            .overlay(
                                Circle()
                                    .stroke(BrandTheme.border, lineWidth: 1)
                            )

                        Circle()
                            .stroke(BrandTheme.coolAccentGradient, lineWidth: 12)
                            .frame(width: outerSize - 34, height: outerSize - 34)

                        BrandMark(size: iconSize)
                    }
                    .shadow(color: BrandTheme.accentPrimary.opacity(0.16), radius: 28, y: 16)

                    VStack(spacing: 12) {
                        Text(L10n.tr("app.name"))
                            .font(.system(size: isCompactHeight ? 34 : 40, weight: .black, design: .rounded))
                            .foregroundStyle(BrandTheme.textPrimary)

                        Text(L10n.tr("Secure records for the moments that matter."))
                            .font(.system(size: isCompactHeight ? 15 : 17, weight: .medium, design: .rounded))
                            .foregroundStyle(BrandTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Capsule()
                            .fill(.white.opacity(0.10))
                            .frame(width: 132, height: 5)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(BrandTheme.accentGradient)
                                    .frame(width: 74, height: 5)
                            }

                        Text(L10n.tr("Preparing your vault"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                            .tracking(0.3)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, isCompactHeight ? 36 : 52)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
