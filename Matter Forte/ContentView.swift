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
    @State private var launchStage: AppLaunchStage = .splash
    @AppStorage("settings.darkAppearance") private var darkAppearance = false

    var body: some View {
        Group {
            if launchStage == .splash {
                SplashView { launchStage = .welcome }
            } else if model.isRestoringSession {
                ProgressView("Restoring session…")
            } else if let session = model.authenticatedSession {
                authenticatedContent(session)
                    .id(session.user.id.uuidString + (metadataString(session.user.appMetadata["role"]) ?? ""))
            } else if launchStage == .welcome {
                WelcomeView { launchStage = .authentication }
            } else {
                NavigationStack { AuthView(model: model) }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .tint(.appOrange)
        .preferredColorScheme(model.authenticatedSession != nil && darkAppearance ? .dark : .light)
        .task { await model.observeAuthChanges() }
        .onChange(of: model.authenticatedSession?.user.id) { old, new in
            if old != nil && new == nil { launchStage = .authentication }
        }
        .onOpenURL { url in Task { await model.handleAuthCallback(url) } }
    }

    @ViewBuilder
    private func authenticatedContent(_ session: Auth.Session) -> some View {
        switch SignedInDestination.resolve(
            serverRole: metadataString(session.user.appMetadata["role"]),
            requestedRole: metadataString(session.user.userMetadata["requested_role"])
        ) {
        case .administrator:
            AdministratorDashboardView(session: session, loadDashboard: InstituteDashboardService.loadDashboard) { route in
                switch route {
                case .students: return AnyView(StudentView())
                case .addStudent: return AnyView(AddCohortStudentView(
                    cohorts: [StudentCohort(name: "MCRI", students: [])],
                    usesNavigationStack: false,
                    onSave: { _, student in _ = try await InstituteDashboardService.saveStudent(student) }
                ))
                case .approvals, .adminRequests: return AnyView(AdministratorRequestsView(client: SupabaseConfig.client))
                case .notifications: return AnyView(AdministratorNotificationsView())
                case .settings: return AnyView(AccountSettingsView(model: model))
                case .reportedIssues:
                    return AnyView(ContentUnavailableView("Reported Issues", systemImage: "shield",
                        description: Text("Issue reporting is not yet available for this platform.")))
                }
            }
        case .restrictedAccount:
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(Color.appOrange)
                    Text("Account access unavailable").font(.title2.bold())
                    Text("Student portfolios are managed by institute administrators. Students do not have app access.")
                    Button("Sign Out") { Task { await model.signOut() } }
                        .buttonStyle(.borderedProminent).disabled(model.isLoading)
                }
                .multilineTextAlignment(.center).padding()
            }
        case .pendingAdministrator:
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.clock").font(.largeTitle).foregroundStyle(Color.appOrange)
                    let rejected = metadataString(session.user.appMetadata["admin_request_status"]) == "rejected"
                    Text(rejected ? "Admin request declined" : "Administrator approval pending").font(.title2.bold())
                    Text(rejected ? "Contact your platform administrator for help."
                        : "An administrator will review your request. Refresh access after approval.")
                    Button(model.isLoading ? "Checking…" : "Refresh Access") {
                        Task { await model.refreshAdministratorAccess() }
                    }.buttonStyle(.borderedProminent).disabled(model.isLoading)
                    NavigationLink("Account Settings") { AccountSettingsView(model: model) }
                    if let message = model.message { Text(message).foregroundStyle(.red) }
                }
                .multilineTextAlignment(.center).padding()
                .navigationTitle("Admin Access")
            }
        case .employer:
            EmployerDashboardView {
                Task { await model.signOut() }
            }
        case .account:
            NavigationStack { AccountSettingsView(model: model) }
        }
    }

}

private func metadataString(_ value: AnyJSON?) -> String? {
    guard case let .string(string) = value else { return nil }
    return string
}
