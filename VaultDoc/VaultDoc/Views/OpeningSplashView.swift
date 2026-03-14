import SwiftUI

struct OpeningSplashView: View {
    var body: some View {
        ZStack {
            BrandTheme.backgroundGradient
                .ignoresSafeArea()

            BrandTheme.heroGradient
                .ignoresSafeArea()

            Circle()
                .fill(BrandTheme.accent.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 120, y: -220)

            Circle()
                .fill(BrandTheme.accentMuted.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: -150, y: 260)

            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(BrandTheme.surface)
                        .frame(width: 152, height: 152)
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(BrandTheme.border, lineWidth: 1)
                        )

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundStyle(BrandTheme.accentGradient)
                }
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)

                VStack(spacing: 10) {
                    Text(L10n.tr("app.name"))
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(BrandTheme.textPrimary)

                    Text("Protect what proves ownership")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .tracking(0.4)
                }
            }
            .padding(32)
        }
    }
}
