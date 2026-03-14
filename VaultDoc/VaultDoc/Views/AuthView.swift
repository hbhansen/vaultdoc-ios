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
                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(BrandTheme.accent.opacity(0.16))
                                .frame(width: 104, height: 104)
                            Circle()
                                .stroke(BrandTheme.border, lineWidth: 1)
                                .frame(width: 116, height: 116)
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(BrandTheme.accentGradient)
                        }
                        Text(L10n.tr("app.name"))
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Text(L10n.tr("auth.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 16) {
                        TextField(L10n.tr("auth.email"), text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .brandInputField()

                        SecureField(L10n.tr("auth.password"), text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .brandInputField()

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
                            .background(BrandTheme.accentGradient)
                            .foregroundStyle(BrandTheme.backgroundBottom)
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

                    Spacer(minLength: 28)
                }
            }
            .brandBackground()
        }
    }
}
