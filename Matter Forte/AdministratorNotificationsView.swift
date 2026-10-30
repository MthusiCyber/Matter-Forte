import SwiftUI
import Supabase

/// Administrator inbox with platform updates and pending administrator requests.
struct AdministratorNotificationsView: View {
    @State private var notifications: [PlatformNotification] = []
    @State private var requests: [AdministratorRequest] = []
    @State private var isLoading = true
    @State private var requestError: String?
    @State private var platformError: String?

    var body: some View {
        List {
            if isLoading && notifications.isEmpty && requests.isEmpty {
                ProgressView("Loading notifications…")
            } else {
                if let platformError {
                    Section {
                        Text(platformError)
                            .foregroundStyle(.secondary)
                        Button("Try Again") { Task { await load() } }
                    }
                }
                if let requestError {
                    Section {
                        Text(requestError)
                            .foregroundStyle(.red)
                        Button("Try Again") { Task { await load() } }
                    }
                }
                if notifications.isEmpty && requests.isEmpty && platformError == nil && requestError == nil {
                    ContentUnavailableView(
                        "No new notifications",
                        systemImage: "bell",
                        description: Text("Internship posts, portfolio updates and administrator requests will appear here.")
                    )
                }
                if !notifications.isEmpty {
                    Section("Platform updates") {
                        ForEach(notifications) { notification in
                            platformRow(notification)
                        }
                    }
                }
                if !requests.isEmpty {
                    Section("Administrator requests (\(requests.count))") {
                        ForEach(requests) { request in
                            NavigationLink {
                                AdministratorRequestsView(client: SupabaseConfig.client)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Administrator access requested")
                                        .font(.headline)
                                    Text(request.fullName)
                                        .font(.subheadline)
                                    Text(request.createdAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task { await load() }
        .refreshable { await load() }
    }

    private func platformRow(_ notification: PlatformNotification) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(notification.title)
                .font(.headline)
            Text(notification.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(notification.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(.vertical, 5)
    }

    private func load() async {
        isLoading = true
        requestError = nil
        platformError = nil
        defer { isLoading = false }
        do {
            let pending = try await loadPendingRequests()
            try Task.checkCancellation()
            requests = pending
        } catch is CancellationError {
            return
        } catch {
            requestError = "Unable to load administrator requests. Check your connection and try again."
        }
        do {
            let updates = try await WorkflowService.loadNotifications()
            try Task.checkCancellation()
            notifications = updates
            try? await WorkflowService.markNotificationsRead()
        } catch is CancellationError {
            return
        } catch {
            platformError = "Unable to load platform updates. Check your connection and try again."
        }
    }

    private func loadPendingRequests() async throws -> [AdministratorRequest] {
        try await SupabaseConfig.client.database
            .from("matter_forte_admin_requests")
            .select("user_id,full_name,email,created_at")
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
