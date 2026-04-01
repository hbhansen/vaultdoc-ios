import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var hasAutoStartedPasswordRecovery = false

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedConfirmation: String {
        confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                        .padding(.top, 28)

                    VStack(spacing: 18) {
                        if auth.authScreen == .signIn, auth.canUseBiometricLogin {
                            biometricButton
                        }

                        authCardContent

                        messageSection
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

    @ViewBuilder
    private var authCardContent: some View {
        switch auth.authScreen {
        case .signIn:
            signInCardContent
        case .forgotPassword:
            forgotPasswordCardContent
        case .resetPasswordLanding:
            resetPasswordLandingCardContent
        case .resetPassword:
            resetPasswordCardContent
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

                Text(heroSubtitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var signInCardContent: some View {
        VStack(spacing: 18) {
            credentialsSection(
                passwordTitle: L10n.tr("auth.password"),
                passwordContentType: isSignUp ? .newPassword : .password
            )

            Button {
                auth.showForgotPassword()
            } label: {
                Text(L10n.tr("Forgot password?"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.accentBright)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(auth.isLoading || isSignUp)
            .opacity(isSignUp ? 0.5 : 1)

            primaryActionButton

            Button {
                isSignUp.toggle()
                auth.errorMessage = nil
                auth.infoMessage = nil
            } label: {
                Text(isSignUp
                    ? L10n.tr("auth.toggle.sign_in")
                    : L10n.tr("auth.toggle.sign_up"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.accentBright)
            }
            .padding(.top, 4)
        }
    }

    private var forgotPasswordCardContent: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(L10n.tr("auth.email"))

                TextField("", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .brandInputField()
            }

            Button {
                Task {
                    await auth.requestPasswordReset(email: trimmedEmail)
                }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .tint(BrandTheme.textPrimary)
                    } else {
                        Text(L10n.tr("Send reset link"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BrandTheme.accentGradient)
                .foregroundStyle(BrandTheme.actionForeground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(trimmedEmail.isEmpty || auth.isLoading)
            .opacity(trimmedEmail.isEmpty || auth.isLoading ? 0.7 : 1)

            Button {
                auth.showSignIn()
            } label: {
                Text(L10n.tr("Back to sign in"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.accentBright)
            }
            .padding(.top, 4)
        }
    }

    private var resetPasswordLandingCardContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(BrandTheme.accentGradient)
                    .frame(width: 60, height: 60)
                    .background(BrandTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(L10n.tr("Continue your password reset in VaultDoc."))
                    .font(.headline)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }

            Text(L10n.tr("Tap continue to verify your recovery link and open the password change screen."))
                .font(.subheadline)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await auth.beginPasswordRecovery()
                }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .tint(BrandTheme.textPrimary)
                    } else {
                        Text(L10n.tr("Continue"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BrandTheme.accentGradient)
                .foregroundStyle(BrandTheme.actionForeground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(auth.isLoading)

            Button {
                auth.finishPasswordResetFlow()
            } label: {
                Text(L10n.tr("Cancel"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.accentBright)
            }
            .padding(.top, 4)
        }
        .onAppear {
            guard !hasAutoStartedPasswordRecovery else { return }
            hasAutoStartedPasswordRecovery = true

            Task {
                try? await Task.sleep(for: .seconds(1))
                guard auth.authScreen == .resetPasswordLanding else { return }
                await auth.beginPasswordRecovery()
            }
        }
        .onDisappear {
            hasAutoStartedPasswordRecovery = false
        }
    }

    @ViewBuilder
    private var resetPasswordCardContent: some View {
        if auth.didCompletePasswordReset {
            VStack(spacing: 18) {
                Text(L10n.tr("Your password has been updated."))
                    .font(.headline)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Button {
                    auth.finishPasswordResetFlow()
                } label: {
                    Text(L10n.tr("Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(BrandTheme.accentGradient)
                        .foregroundStyle(BrandTheme.actionForeground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        } else {
            VStack(spacing: 18) {
                credentialsSection(
                    passwordTitle: L10n.tr("New password"),
                    passwordContentType: .newPassword,
                    includesConfirmation: true
                )

                Text(L10n.format("Use at least %lld characters.", Int64(auth.minimumPasswordLength)))
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        await auth.updateRecoveredPassword(
                            newPassword: trimmedPassword,
                            confirmPassword: trimmedConfirmation
                        )
                    }
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView()
                                .tint(BrandTheme.textPrimary)
                        } else {
                            Text(L10n.tr("Update password"))
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BrandTheme.accentGradient)
                    .foregroundStyle(BrandTheme.actionForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(trimmedPassword.isEmpty || trimmedConfirmation.isEmpty || auth.isLoading)
                .opacity(trimmedPassword.isEmpty || trimmedConfirmation.isEmpty || auth.isLoading ? 0.7 : 1)
            }
        }
    }

    private func credentialsSection(
        passwordTitle: String,
        passwordContentType: UITextContentType,
        includesConfirmation: Bool = false
    ) -> some View {
        VStack(spacing: 14) {
            if auth.authScreen == .signIn {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(L10n.tr("auth.email"))

                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .brandInputField()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(passwordTitle)

                SecureField("", text: $password)
                    .textContentType(passwordContentType)
                    .brandInputField()
            }

            if includesConfirmation {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(L10n.tr("Confirm password"))

                    SecureField("", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .brandInputField()
                }
            }
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let error = auth.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(BrandTheme.alert)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let info = auth.infoMessage {
            Text(info)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let debug = auth.debugMessage {
            Text(debug)
                .font(.caption2)
                .foregroundStyle(BrandTheme.accentCool)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
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
                .background(BrandTheme.surfaceElevated)
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
            .foregroundStyle(BrandTheme.actionForeground)
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
                .fill(BrandTheme.surfaceElevated.opacity(0.65))
                .frame(width: ringSize, height: ringSize)
                .overlay(
                    Circle()
                        .stroke(BrandTheme.border, lineWidth: 1)
                )

            Circle()
                .stroke(BrandTheme.coolAccentGradient, lineWidth: 12)
                .frame(width: ringSize - 34, height: ringSize - 34)

            BrandMark(size: size)
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

    private var heroSubtitle: String {
        switch auth.authScreen {
        case .signIn:
            return isSignUp
                ? L10n.tr("Create a secure home for your records.")
                : L10n.tr("Sign in to your secure document vault.")
        case .forgotPassword:
            return L10n.tr("Request a secure password reset link.")
        case .resetPasswordLanding:
            return L10n.tr("Your password reset link has opened in VaultDoc.")
        case .resetPassword:
            return auth.didCompletePasswordReset
                ? L10n.tr("Your recovery session is complete.")
                : L10n.tr("Choose a new password for your account.")
        }
    }
}
