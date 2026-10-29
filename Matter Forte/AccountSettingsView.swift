import SwiftUI
import Auth

/// Connects the settings feature branch to the single shared authentication model.
struct AccountSettingsView: View {
    @ObservedObject var model: AuthViewModel
    @State private var destination: SettingsAccountDestination?

    var body: some View {
        SettingsView(
            isSigningOut: model.isLoading,
            signOutError: model.message,
            onEditProfile: { destination = .profile },
            onChangePassword: { destination = .password },
            onSignOut: { Task { await model.signOut() } }
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $destination) { route in
            SettingsAccountForm(
                destination: route,
                initialName: model.profileName,
                initialEmail: model.authenticatedSession?.user.email ?? "",
                saveProfile: model.updateProfile,
                savePassword: model.updatePassword
            )
        }
    }
}
