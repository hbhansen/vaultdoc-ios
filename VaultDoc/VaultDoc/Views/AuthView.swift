import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroHeader
                        .padding(.top, 24)

                    VStack(spacing: 16) {
                        if auth.canUseBiometricLogin {
                            Button {
                                Task {
                                    await auth.signInWithBiometrics()
                                }
                            } label: {
                                Label(auth.biometricButtonTitle, systemImage: "faceid")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(BrandTheme.elevatedSurface)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(BrandTheme.border, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .disabled(auth.isLoading)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("auth.email"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.textSecondary)

                            TextField("", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .brandInputField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("auth.password"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.textSecondary)

                            SecureField("", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .brandInputField()
                        }

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(BrandTheme.alert)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                if isSignUp {
                                    await auth.signUp(email: email, password: password)
                                } else {
                                    await auth.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            Group {
                                if auth.isLoading {
                                    ProgressView()
                                        .tint(BrandTheme.backgroundBottom)
                                } else {
                                    Text(isSignUp ? L10n.tr("auth.create_account") : L10n.tr("auth.sign_in"))
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BrandTheme.sunburstGradient)
                            .foregroundStyle(BrandTheme.backgroundTop)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

                        Button {
                            isSignUp.toggle()
                            auth.errorMessage = nil
                        } label: {
                            Text(isSignUp
                                ? L10n.tr("auth.toggle.sign_in")
                                : L10n.tr("auth.toggle.sign_up"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.accentBright)
                        }
                    }
                    .padding(24)
                    .brandCard()
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 28)
            }
            .brandBackground()
            .onAppear {
                auth.refreshBiometricAvailability()
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(BrandTheme.sunburstGradient)
                        .frame(width: 92, height: 92)
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        .frame(width: 108, height: 108)
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(BrandTheme.backgroundTop)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(isSignUp ? "Create your vault" : "Private proof, brightly organized")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text("Insure valuables, receipts, and family inventory with a sharper view.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: 190, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("app.name"))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(BrandTheme.textPrimary)
                Text(L10n.tr("auth.subtitle"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandTheme.elevatedSurface,
                            BrandTheme.surface.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}
