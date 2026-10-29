import SwiftUI

enum SettingsAccountDestination: String, Identifiable {
    case profile, password
    var id: String { rawValue }
}

struct SettingsAccountForm: View {
    let destination: SettingsAccountDestination
    let initialName: String
    let initialEmail: String
    let saveProfile: (String, String) async throws -> String
    let savePassword: (String) async throws -> String

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var success: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                if destination == .profile {
                    Section("Profile") {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section {
                        Text("Changing your email may require confirmation from your inbox.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("New password") {
                        SecureField("New password", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Confirm new password", text: $confirmation)
                            .textContentType(.newPassword)
                    }
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Text(isSaving ? "Saving…" : "Save Changes")
                            Spacer()
                            if isSaving { ProgressView() }
                        }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle(destination == .profile ? "Edit Profile" : "Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .tint(Color.appOrange)
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            name = initialName
            email = initialEmail
        }
        .alert("Changes Saved", isPresented: $showingSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text(success ?? "")
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        error = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if destination == .profile {
            guard !trimmedName.isEmpty else {
                error = "Enter your full name."
                return
            }
            guard trimmedEmail.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
                error = "Enter a valid email address."
                return
            }
        } else {
            guard !password.isEmpty else {
                error = "Enter a new password."
                return
            }
            guard password == confirmation else {
                error = "Passwords do not match."
                return
            }
        }

        isSaving = true
        defer { isSaving = false }
        do {
            if destination == .profile {
                success = try await saveProfile(trimmedName, trimmedEmail)
            } else {
                success = try await savePassword(password)
                password = ""
                confirmation = ""
            }
            showingSuccess = true
        } catch is CancellationError {
            // Keep the form available when an operation is cancelled.
        } catch {
            self.error = error.localizedDescription
        }
    }
}
