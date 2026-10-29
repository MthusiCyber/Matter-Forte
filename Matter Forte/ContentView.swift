import SwiftUI
import Auth

@MainActor
struct ContentView: View {
    @ObservedObject var model: AuthViewModel
    @State private var accountDestination: SettingsAccountDestination?

    var body: some View {
        Group {
            if model.isRestoringSession {
                ProgressView("Restoring session…")
            } else if let session = model.authenticatedSession {
                SettingsView(
                    isSigningOut: model.isLoading,
                    signOutError: model.message,
                    onEditProfile: { accountDestination = .profile },
                    onChangePassword: { accountDestination = .password },
                    onSignOut: { Task { await model.signOut() } }
                )
                .sheet(item: $accountDestination) { destination in
                    SettingsAccountForm(
                        destination: destination,
                        initialName: model.profileName,
                        initialEmail: session.user.email ?? "",
                        saveProfile: { name, email in
                            try await model.updateProfile(name: name, email: email)
                        },
                        savePassword: { password in
                            try await model.updatePassword(password)
                        }
                    )
                }
            } else {
                AuthView(model: model)
            }
        }
    }
}

// Render the authentication design directly without session-restoration work.
#Preview("Authentication") {
    AuthView(model: AuthViewModel(client: SupabaseConfig.client))
}
