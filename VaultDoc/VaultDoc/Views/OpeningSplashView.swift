import SwiftUI

struct OpeningSplashView: View {
    var body: some View {
        ZStack {
            BrandTheme.backgroundGradient
                .ignoresSafeArea()

            BrandTheme.heroGradient
                .ignoresSafeArea()

            Circle()
                .fill(BrandTheme.accent.opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 44)
                .offset(x: 120, y: -220)

            Circle()
                .fill(BrandTheme.accentCool.opacity(0.26))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: -150, y: 260)

            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BrandTheme.elevatedSurface, BrandTheme.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 164, height: 164)
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(BrandTheme.border, lineWidth: 1)
                        )

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 66, weight: .bold))
                        .foregroundStyle(BrandTheme.sunburstGradient)
                }
                .shadow(color: .black.opacity(0.28), radius: 24, y: 12)

                VStack(spacing: 10) {
                    Text(L10n.tr("app.name"))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(BrandTheme.textPrimary)

                    Text("Protect what proves ownership")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .tracking(0.8)
                    
                    Text("The app you did not know you needed until it matters")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .tracking(0.8)
                        }
            }
            .padding(32)
        }
    }
}
