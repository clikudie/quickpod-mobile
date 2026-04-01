import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var step: Step = .requestCode
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Step { case requestCode, resetPassword }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Icon + title
                    VStack(spacing: 12) {
                        Image(systemName: step == .requestCode ? "lock.rotation" : "lock.open.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)

                        Text(step == .requestCode ? "Reset Password" : "Set New Password")
                            .font(.title2.bold())

                        Text(step == .requestCode
                             ? "Enter your email and we'll send you a 6-digit reset code."
                             : "Enter the code we sent to **\(email)** and choose a new password.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    if step == .requestCode {
                        requestCodeForm
                    } else {
                        resetPasswordForm
                    }

                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step 1: request code

    private var requestCodeForm: some View {
        VStack(spacing: 16) {
            inputField("Email", placeholder: "you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await sendCode() }
            } label: {
                actionLabel("Send Reset Code", loading: isLoading)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    // MARK: - Step 2: enter code + new password

    private var resetPasswordForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reset Code")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                OTPField(code: $code)
            }

            inputField("New Password", placeholder: "At least 8 characters", text: $newPassword, secure: true)
            inputField("Confirm Password", placeholder: "Repeat new password", text: $confirmPassword, secure: true)

            Button {
                Task { await doReset() }
            } label: {
                actionLabel("Reset Password", loading: isLoading)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitReset || isLoading)

            Button("Resend code") {
                Task { await sendCode() }
            }
            .font(.subheadline)
            .disabled(isLoading)
        }
    }

    private var canSubmitReset: Bool {
        code.count == 6 && newPassword.count >= 8 && newPassword == confirmPassword
    }

    // MARK: - Actions

    private func sendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await WavecrestAPI.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            withAnimation { step = .resetPassword }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func doReset() async {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await WavecrestAPI.shared.resetPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                code: code,
                newPassword: newPassword
            )
            AuthStore.shared.save(
                token: response.accessToken,
                userId: response.userId,
                isVerified: response.isVerified,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func inputField(_ label: String, placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, loading: Bool) -> some View {
        Group {
            if loading {
                ProgressView().tint(.white)
            } else {
                Text(title).font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - OTP field (reused from VerificationView)

private struct OTPField: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0.001)
                .onChange(of: code) { _, new in
                    code = String(new.filter(\.isNumber).prefix(6))
                }

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(code)
                    let ch = chars.count > i ? String(chars[i]) : ""
                    let isActive = focused && chars.count == i

                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isActive ? Color.accentColor : Color(.separator),
                            lineWidth: isActive ? 2 : 1
                        )
                        .frame(width: 46, height: 56)
                        .overlay(Text(ch).font(.title2.bold()))
                }
            }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}

#Preview {
    ForgotPasswordView()
}
