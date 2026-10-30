import SwiftUI
import Auth

@MainActor
struct ContentView: View {
    @StateObject private var model = AuthViewModel(client: SupabaseConfig.client)

    var body: some View {
        Group {
            if model.isRestoringSession {
                ProgressView("Restoring session…")
            } else if let session = model.authenticatedSession {
                if model.authenticatedRole == .employer {
                    EmployerDashboardView {
                        Task { await model.signOut() }
                    }
                } else {
                    NavigationStack {
                        VStack(spacing: 24) {
                            Text("Welcome to Matter Forte").font(.title2)
                            Text(session.user.email ?? "Signed in")
                                .foregroundStyle(.secondary)
                            if let message = model.message {
                                Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
                            }
                            Button(model.isLoading ? "Signing Out…" : "Sign Out") {
                                Task { await model.signOut() }
                            }
                            .disabled(model.isLoading)
                        }
                        .padding()
                        .navigationTitle("Home")
                    }
                }
            } else {
                AuthView(model: model)
            }
        }
        .task { await model.observeAuthChanges() }
        .onOpenURL { url in
            Task { await model.handleAuthCallback(url) }
        }
    }
}

// Render the authentication design directly without session-restoration work.
#Preview("Authentication") {
    AuthView(model: AuthViewModel(client: SupabaseConfig.client))
}
