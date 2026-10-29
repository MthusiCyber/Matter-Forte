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
                case .students: return AnyView(InstituteStudentsView())
                case .addStudent: return AnyView(AddCohortStudentView(
                    cohorts: [StudentCohort(name: "MCRI", students: [])],
                    usesNavigationStack: false,
                    onSave: { _, student in try await InstituteDashboardService.inviteStudent(student) }
                ))
                case .approvals, .adminRequests: return AnyView(AdministratorRequestsView(client: SupabaseConfig.client))
                case .notifications: return AnyView(AdministratorNotificationsView())
                case .settings: return AnyView(AccountSettingsView(model: model))
                case .reportedIssues:
                    return AnyView(ContentUnavailableView("Reported Issues", systemImage: "shield",
                        description: Text("Issue reporting is not yet available for this platform.")))
                }
            }
        case .student:
            NavigationStack {
                CohortStudentProfileView(student: ownStudentProfile(session),
                    cohortName: metadataString(session.user.userMetadata["cohort"]) ?? "MCRI")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { AccountSettingsView(model: model) } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } }
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
        case .employer, .account:
            NavigationStack { AccountSettingsView(model: model) }
        }
    }

    private func ownStudentProfile(_ session: Auth.Session) -> CohortStudent {
        let data = session.user.userMetadata
        return CohortStudent(id: session.user.id,
            fullName: metadataString(data["full_name"]) ?? "Student",
            email: session.user.email ?? "",
            university: metadataString(data["institute"]) ?? "MCRI",
            fieldOfStudy: metadataString(data["programme"]) ?? "",
            biography: metadataString(data["biography"]) ?? "",
            skills: metadataStrings(data["skills"]),
            essentialSkills: metadataStrings(data["essential_skills"]))
    }
}

private func metadataString(_ value: AnyJSON?) -> String? {
    guard case let .string(string) = value else { return nil }
    return string
}

private func metadataStrings(_ value: AnyJSON?) -> [String] {
    guard case let .array(values) = value else { return [] }
    return values.compactMap { metadataString($0) }
}
