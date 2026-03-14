import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Branding header
                VStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.teal)
                    Text("VaultDoc")
                        .font(.largeTitle).bold()
                    Text("Secure your valuables documentation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                // Error message
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Primary action button
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
                                .tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                .padding(.horizontal)

                // Toggle sign in / sign up
                Button {
                    isSignUp.toggle()
                    auth.errorMessage = nil
                } label: {
                    Text(isSignUp
                        ? "Already have an account? Sign In"
                        : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }

                Spacer()
            }
        }
    }
}
