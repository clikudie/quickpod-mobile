import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = WavecrestAPI.shared.baseURL
    @State private var healthStatus: HealthStatus = .unknown
    @State private var isChecking = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private enum HealthStatus {
        case unknown, healthy, unhealthy(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.subheadline.weight(.medium))
                        TextField("http://localhost:8000", text: $serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("The base URL of your Quick Pod Highlights server")
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                switch healthStatus {
                                case .unknown:
                                    Image(systemName: "questionmark.circle")
                                        .foregroundStyle(.secondary)
                                case .healthy:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .unhealthy:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .disabled(isChecking)

                    if case .unhealthy(let msg) = healthStatus {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Text(isDeleting ? "Deleting…" : "Delete Account")
                            Spacer()
                            if isDeleting { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(isDeleting)

                    if let error = deleteError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently deletes your account and all associated data. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip trailing slash
        WavecrestAPI.shared.baseURL = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            try await WavecrestAPI.shared.deleteAccount()
            AuthStore.shared.signOut()
        } catch {
            deleteError = error.localizedDescription
            isDeleting = false
        }
    }

    private func testConnection() {
        save()
        isChecking = true
        healthStatus = .unknown

        Task {
            do {
                let response = try await WavecrestAPI.shared.healthCheck()
                healthStatus = response.status == "ok" ? .healthy : .unhealthy("Unexpected status: \(response.status)")
            } catch {
                healthStatus = .unhealthy(error.localizedDescription)
            }
            isChecking = false
        }
    }
}

#Preview {
    SettingsView()
}
