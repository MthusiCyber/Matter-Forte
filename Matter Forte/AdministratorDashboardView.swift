import SwiftUI
import Auth
#if canImport(_Helpers)
import _Helpers
#elseif canImport(Helpers)
import Helpers
#endif

/// Admin-only entry point. Authorize the same role on every backend operation.
/// Use server-managed app_metadata.role; never authorize from requested_role.
/// Supply live loading and destination views when connecting this screen to the app.
struct AdministratorDashboardView: View {
    let session: Auth.Session?
    let loadDashboard: () async throws -> AdministratorDashboardSnapshot
    let destination: (AdministratorDashboardDestination) -> AnyView

    var body: some View {
        Group {
            if let session,
               (session.expiresAt ?? 0) > Date().timeIntervalSince1970,
               session.user.appMetadata["role"] == .string("admin") {
                AdministratorDashboardContent(
                    loadDashboard: loadDashboard,
                    destination: destination
                )
                // Discard loaded data and navigation when the signed-in identity changes.
                .id(session.user.id)
            } else {
                ContentUnavailableView(
                    "Administrator access required",
                    systemImage: "lock.shield",
                    description: Text("Sign in with an authorized administrator account to view this dashboard.")
                )
            }
        }
    }
}

nonisolated struct AdministratorDashboardSnapshot: Decodable, Sendable {
    let totalStudents: Int
    let activeInternships: Int
    let pendingApprovals: Int
    let reportedIssues: Int
    let unreadNotifications: Int
    let recentActivity: [AdministratorActivity]

    var isEmpty: Bool {
        totalStudents == 0 && activeInternships == 0 && pendingApprovals == 0
            && reportedIssues == 0 && recentActivity.isEmpty
    }
}

nonisolated struct AdministratorActivity: Decodable, Identifiable, Sendable {
    let id: UUID
    let userName: String
    let action: String
    let timestamp: Date

    init(id: UUID = UUID(), userName: String, action: String, timestamp: Date) {
        self.id = id
        self.userName = userName
        self.action = action
        self.timestamp = timestamp
    }

    var initials: String {
        userName.split(separator: " ").prefix(2).compactMap(\.first)
            .map(String.init).joined().uppercased()
    }
}

enum AdministratorDashboardDestination: String, Hashable {
    case students, approvals, adminRequests, reportedIssues, addStudent, notifications, settings

    var title: String {
        switch self {
        case .students: "Manage Students"
        case .approvals: "Pending Approvals"
        case .adminRequests: "Admin Requests"
        case .reportedIssues: "Reported Issues"
        case .addStudent: "Add Student"
        case .notifications: "Notifications"
        case .settings: "Settings"
        }
    }
}

private enum AdministratorDashboardStyle {
    static let orange = Color(red: 240 / 255, green: 105 / 255, blue: 44 / 255)
    static let charcoal = Color(red: 0.22, green: 0.22, blue: 0.22)
    static let surface = Color(uiColor: .secondarySystemBackground)
}

private struct AdministratorDashboardContent: View {
    let loadDashboard: () async throws -> AdministratorDashboardSnapshot
    let destination: (AdministratorDashboardDestination) -> AnyView

    @State private var snapshot: AdministratorDashboardSnapshot?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var path = NavigationPath()
    @State private var selectedTab: AdministratorDashboardDestination?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if isLoading && snapshot == nil {
                        ProgressView("Loading platform statistics…")
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .accessibilityIdentifier("admin.loading")
                    } else if let errorMessage {
                        errorState(errorMessage)
                    } else if let snapshot {
                        dashboard(snapshot)
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .refreshable { await refresh() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AdministratorDashboardDestination.self) { route in
                destination(route)
                    .navigationTitle(route.title)
                    .toolbar(.visible, for: .navigationBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
        .tint(AdministratorDashboardStyle.orange)
        .task { await refresh() }
        .onChange(of: path.count) { _, count in
            if count == 0 {
                selectedTab = nil
                Task { await refresh() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { open(.adminRequests) } label: {
                    Label("Admin Requests", systemImage: "person.badge.shield.checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                Spacer()
                Button { open(.notifications) } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 17))
                        .foregroundStyle(AdministratorDashboardStyle.charcoal)
                        .padding(8)
                        .background(Color(white: 0.9), in: Circle())
                        .overlay(alignment: .topTrailing) {
                            if let count = snapshot?.unreadNotifications, count > 0 {
                                Text(count > 99 ? "99+" : String(count))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(AdministratorDashboardStyle.orange, in: Capsule())
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Notifications")
                .accessibilityValue("\(snapshot?.unreadNotifications ?? 0) unread")
            }
            Text("Administrator Dashboard")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text("Manage your platform at a glance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dashboard(_ data: AdministratorDashboardSnapshot) -> some View {
        let activity = data.recentActivity.sorted { $0.timestamp > $1.timestamp }
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin DASHBOARD")
                .font(.caption.bold())
                .foregroundStyle(AdministratorDashboardStyle.orange)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                statistic(data.totalStudents, title: "Total Students")
                statistic(data.activeInternships, title: "Active internships")
            }
        }
        .padding(16)
        .background(AdministratorDashboardStyle.charcoal, in: RoundedRectangle(cornerRadius: 9))

        LazyVGrid(columns: columns, spacing: 12) {
            summaryLink(count: data.pendingApprovals, title: "Pending approvals", icon: "person.2.badge.gearshape", route: .approvals)
            summaryLink(count: data.reportedIssues, title: "Reported issues", icon: "shield.lefthalf.filled", route: .reportedIssues)
        }

        if data.isEmpty {
            ContentUnavailableView(
                "Your platform is ready",
                systemImage: "tray",
                description: Text("There are no platform records yet. Add a student to get started.")
            )
        }

        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quick Actions")
            Button { open(.addStudent) } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Spacer()
                    Text("Add Student").fontWeight(.semibold)
                    Spacer()
                }
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(AdministratorDashboardStyle.orange, in: RoundedRectangle(cornerRadius: 9))
            }
            Button { open(.students) } label: {
                HStack(spacing: 18) {
                    Text("Manage Students").fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(minHeight: 44)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recent activity")
            if data.recentActivity.isEmpty {
                Text("No recent activity. New platform events will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(AdministratorDashboardStyle.surface, in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 0) {
                    ForEach(activity) { item in
                        activityRow(item)
                        if item.id != activity.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(AdministratorDashboardStyle.surface, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func statistic(_ count: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(count, format: .number)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(title).font(.caption.bold())
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private func summaryLink(count: Int, title: String, icon: String, route: AdministratorDashboardDestination) -> some View {
        Button { open(route) } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .padding(8)
                    .background(Color(white: 0.88), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(count, format: .number).font(.subheadline.bold())
                    Text(title).font(.caption)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(AdministratorDashboardStyle.surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) \(title)")
        .accessibilityHint("Opens the corresponding list")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline.bold()).foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func activityRow(_ item: AdministratorActivity) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(item.initials.isEmpty ? "?" : item.initials)
                .font(.subheadline.bold())
                .foregroundStyle(AdministratorDashboardStyle.orange)
                .frame(width: 42, height: 42)
                .background(Color(white: 0.87), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userName).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(item.action).font(.caption).foregroundStyle(.secondary)
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(item.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            navigationItem("Home", icon: "house", route: nil)
            navigationItem("Students", icon: "person.2", route: .students)
            navigationItem("Approvals", icon: "briefcase", route: .approvals)
            navigationItem("Settings", icon: "gearshape", route: .settings)
        }
        .padding(.vertical, 8)
        .background(AdministratorDashboardStyle.surface)
    }

    private func navigationItem(_ title: String, icon: String, route: AdministratorDashboardDestination?) -> some View {
        let selected = selectedTab == route
        return Button {
            path = NavigationPath()
            selectedTab = route
            if let route { path.append(route) }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 23))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selected ? AdministratorDashboardStyle.orange : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AdministratorDashboardStyle.orange.opacity(0.15))
                        .padding(.horizontal, 5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func open(_ route: AdministratorDashboardDestination) {
        switch route {
        case .students, .addStudent: selectedTab = .students
        case .approvals, .adminRequests: selectedTab = .approvals
        case .settings: selectedTab = .settings
        case .notifications, .reportedIssues: selectedTab = nil
        }
        path.append(route)
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to load dashboard", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await refresh() } }
                .buttonStyle(.borderedProminent)
        }
    }

    @MainActor
    private func refresh() async {
        guard !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await loadDashboard()
            try Task.checkCancellation()
            snapshot = result
        } catch is CancellationError {
            return
        } catch {
            snapshot = nil
            errorMessage = "Check your connection and try again."
        }
    }
}
