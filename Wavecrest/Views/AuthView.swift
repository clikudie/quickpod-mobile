import SwiftUI

struct AuthView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 8
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)

                    Text("Wavecrest")
                        .font(.largeTitle.bold())

                    Text("AI-powered podcast highlights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 48)

                // Toggle
                Picker("Mode", selection: $isLogin) {
                    Text("Sign In").tag(true)
                    Text("Create Account").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: isLogin) { _, _ in errorMessage = nil }

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        SecureField("At least 8 characters", text: $password)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)

                // Submit
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isLogin ? "Sign In" : "Create Account")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)

                if isLogin {
                    Button("Forgot password?") {
                        showForgotPassword = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response: TokenResponse
            if isLogin {
                response = try await WavecrestAPI.shared.login(email: email, password: password)
            } else {
                response = try await WavecrestAPI.shared.register(email: email, password: password)
            }
            AuthStore.shared.save(
                token: response.accessToken,
                userId: response.userId,
                isVerified: response.isVerified,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AuthView()
}
