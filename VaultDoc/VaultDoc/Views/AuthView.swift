import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                        .padding(.top, 28)

                    VStack(spacing: 18) {
                        if auth.canUseBiometricLogin {
                            biometricButton
                        }

                        credentialsSection

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(BrandTheme.alert)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        primaryActionButton

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
                        .padding(.top, 4)
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
        VStack(spacing: 20) {
            splashMark(size: 128, ringSize: 188)
                .shadow(color: .black.opacity(0.24), radius: 24, y: 16)

            VStack(spacing: 10) {
                Text(L10n.tr("app.name"))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(BrandTheme.textPrimary)

                Text(isSignUp ? "Create a secure home for your records." : "Sign in to your secure document vault.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var credentialsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(L10n.tr("auth.email"))

                TextField("", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .brandInputField()
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(L10n.tr("auth.password"))

                SecureField("", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .brandInputField()
            }
        }
    }

    private var biometricButton: some View {
        Button {
            Task {
                await auth.signInWithBiometrics()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: biometricSymbolName)
                    .font(.headline)

                Text(auth.biometricButtonTitle)
                    .font(.headline)
            }
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

    private var primaryActionButton: some View {
        Button {
            Task {
                if isSignUp {
                    await auth.signUp(email: trimmedEmail, password: trimmedPassword)
                } else {
                    await auth.signIn(email: trimmedEmail, password: trimmedPassword)
                }
            }
        } label: {
            Group {
                if auth.isLoading {
                    ProgressView()
                        .tint(BrandTheme.textPrimary)
                } else {
                    Text(isSignUp ? L10n.tr("auth.create_account") : L10n.tr("auth.sign_in"))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BrandTheme.accentGradient)
            .foregroundStyle(BrandTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(trimmedEmail.isEmpty || trimmedPassword.isEmpty || auth.isLoading)
        .opacity(trimmedEmail.isEmpty || trimmedPassword.isEmpty || auth.isLoading ? 0.7 : 1)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandTheme.textSecondary)
    }

    private func splashMark(size: CGFloat, ringSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: ringSize, height: ringSize)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            Circle()
                .stroke(BrandTheme.accentGradient, lineWidth: 12)
                .frame(width: ringSize - 34, height: ringSize - 34)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BrandTheme.elevatedSurface, BrandTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )

            Image(systemName: "lock.document.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(BrandTheme.accentGradient)
        }
    }

    private var biometricSymbolName: String {
        if auth.biometricButtonTitle.contains("Face ID") {
            return "faceid"
        }
        if auth.biometricButtonTitle.contains("Touch ID") {
            return "touchid"
        }
        return "lock.fill"
    }
}
