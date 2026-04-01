import SwiftUI

struct VerificationView: View {
    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @State private var cooldownTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)

                    Text("Check your email")
                        .font(.title2.bold())

                    Text("We sent a 6-digit code to\n**\(email)**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                // OTP input
                OTPField(code: $code)
                    .padding(.horizontal, 24)

                // Error
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Verify button
                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify Email").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.count < 6 || isVerifying)
                .padding(.horizontal)

                // Resend
                Button {
                    Task { await resend() }
                } label: {
                    if resendCooldown > 0 {
                        Text("Resend in \(resendCooldown)s")
                    } else if isResending {
                        Text("Sending…")
                    } else {
                        Text("Resend code")
                    }
                }
                .font(.subheadline)
                .disabled(resendCooldown > 0 || isResending)

                // Escape hatch
                Button("Use a different account") {
                    AuthStore.shared.signOut()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.bottom, 32)
        }
    }

    private func verify() async {
        errorMessage = nil
        isVerifying = true
        defer { isVerifying = false }
        do {
            try await WavecrestAPI.shared.verifyEmail(code: code)
            AuthStore.shared.markVerified()
        } catch {
            errorMessage = error.localizedDescription
            code = ""
        }
    }

    private func resend() async {
        errorMessage = nil
        isResending = true
        defer { isResending = false }
        do {
            try await WavecrestAPI.shared.resendVerification()
            startCooldown()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = 60
        cooldownTask = Task {
            while resendCooldown > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}

// MARK: - OTP digit field

private struct OTPField: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // Invisible text field that captures input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0.001)
                .onChange(of: code) { _, new in
                    code = String(new.filter(\.isNumber).prefix(6))
                }

            // Visual digit boxes
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
    VerificationView(email: "user@example.com")
}
