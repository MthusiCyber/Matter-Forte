import SwiftUI
import Supabase

struct AdministratorNotificationsView: View {
    @State private var requests: [AdministratorRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading notifications…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                Button("Try Again") { Task { await load() } }
            } else if requests.isEmpty {
                ContentUnavailableView("No new notifications", systemImage: "bell",
                    description: Text("New administrator access requests will appear here."))
            } else {
                ForEach(requests) { request in
                    NavigationLink {
                        AdministratorRequestsView(client: SupabaseConfig.client)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Administrator access requested").font(.headline)
                            Text(request.fullName).font(.subheadline)
                            Text(request.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result: [AdministratorRequest] = try await SupabaseConfig.client.database
                .from("matter_forte_admin_requests").select("user_id,full_name,email,created_at")
                .eq("status", value: "pending").order("created_at", ascending: false).execute().value
            try Task.checkCancellation()
            requests = result
        } catch is CancellationError { return }
        catch { errorMessage = "Unable to load notifications. Check your connection and try again." }
    }
}
