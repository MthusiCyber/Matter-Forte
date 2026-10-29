import SwiftUI
import Auth
#if canImport(_Helpers)
import _Helpers
#elseif canImport(Helpers)
import Helpers
#endif

@MainActor
struct ContentView: View {
    @StateObject private var model = AuthViewModel(client: SupabaseConfig.client)

    // Inject the platform data service and management flows when implemented.
    var loadAdministratorDashboard: (() async throws -> AdministratorDashboardSnapshot)?
    var administratorDestination: ((AdministratorDashboardDestination) -> AnyView)?

    var body: some View {
        Group {
            if model.isRestoringSession {
                ProgressView("Restoring session…")
            } else if let session = model.authenticatedSession {
                if session.user.appMetadata["role"] == .string("admin") {
                    AdministratorDashboardView(
                        session: session,
                        loadDashboard: {
                            if let loadAdministratorDashboard {
                                return try await loadAdministratorDashboard()
                            }
                            return try await InstituteDashboardService.loadDashboard()
                        },
                        destination: { route in
                            if let administratorDestination {
                                return administratorDestination(route)
                            }
                            if route == .students {
                                return AnyView(InstituteStudentsView())
                            }
                            if route == .approvals || route == .adminRequests {
                                return AnyView(AdministratorRequestsView(client: SupabaseConfig.client))
                            }
                            if route == .settings {
                                return AnyView(accountSettings)
                            }
                            return AnyView(ContentUnavailableView(
                                route.title,
                                systemImage: "wrench.and.screwdriver",
                                description: Text("This management screen has not been connected yet.")
                            ))
                        }
                    )
                } else {
                    signedInHome(session)
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

    private func signedInHome(_ session: Auth.Session) -> some View {
        let requestedAdmin = session.user.userMetadata["requested_role"] == .string("admin")
        let rejected = session.user.appMetadata["admin_request_status"] == .string("rejected")
        return NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: requestedAdmin ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appOrange)
                Text(requestedAdmin ? (rejected ? "Admin request declined" : "Administrator approval pending") : "Welcome to Matter Forte")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(session.user.email ?? "Signed in")
                    .foregroundStyle(.secondary)
                if requestedAdmin {
                    Text(rejected
                        ? "An administrator declined your access request. Contact your platform administrator for help."
                        : "An existing administrator needs to approve your request. After approval, tap Refresh Access to open your dashboard.")
                        .multilineTextAlignment(.center)
                    Button("Refresh Access") {
                        Task { await model.refreshAdministratorAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
                }
                accountSettings
            }
            .padding()
            .navigationTitle(requestedAdmin ? "Admin Access" : "Home")
        }
        .tint(.appOrange)
    }

    private var accountSettings: some View {
        VStack(spacing: 16) {
            if let message = model.message {
                Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Button(model.isLoading ? "Please wait…" : "Sign Out") {
                Task { await model.signOut() }
            }
            .disabled(model.isLoading)
        }
        .padding()
    }
}

enum AdministratorDashboardConnectionError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "Administrator access is active. The dashboard data service has not been connected yet."
    }
}

#Preview("Authentication") {
    AuthView(model: AuthViewModel(client: SupabaseConfig.client))
}
