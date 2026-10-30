import SwiftUI
import Supabase

nonisolated struct AdministratorRequest: Decodable, Identifiable, Sendable {
    let userID: UUID
    let fullName: String
    let email: String
    let createdAt: Date

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case fullName = "full_name"
        case email
        case createdAt = "created_at"
    }
}

/// Supabase enforces both list visibility and approval authorization.
@MainActor
struct AdministratorRequestsView: View {
    let client: SupabaseClient
    @State private var requests: [AdministratorRequest] = []
    @State private var isLoading = true
    @State private var reviewingID: UUID?
    @State private var errorMessage: String?
    @State private var resultMessage: String?
    @State private var confirmation: ReviewAction?

    private struct ReviewAction: Identifiable {
        let request: AdministratorRequest
        let approve: Bool
        var id: UUID { request.id }
    }

    nonisolated private struct ReviewParameters: Encodable, Sendable {
        let target_user_id: UUID
        let decision: String
    }

    var body: some View {
        List {
            Section {
                Text("Approve requests to give other people access to the Administrator Dashboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let resultMessage {
                Text(resultMessage).foregroundStyle(.green)
                    .accessibilityIdentifier("adminRequests.result")
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Try Again") { Task { await load() } }
                }
            }
            if isLoading {
                ProgressView("Loading administrator requests…")
            } else if requests.isEmpty && errorMessage == nil {
                ContentUnavailableView("No pending admin requests", systemImage: "person.crop.circle.badge.checkmark",
                    description: Text("New administrator signup requests will appear here."))
            } else {
                Section("Pending requests (\(requests.count))") {
                    ForEach(requests) { request in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(request.fullName).font(.headline)
                            Text(request.email).font(.subheadline).textSelection(.enabled)
                            Text(request.createdAt, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Approve", systemImage: "checkmark.circle") {
                                    confirmation = ReviewAction(request: request, approve: true)
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityLabel("Approve \(request.fullName)")
                                Button("Decline", systemImage: "xmark.circle", role: .destructive) {
                                    confirmation = ReviewAction(request: request, approve: false)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Decline \(request.fullName)")
                                if reviewingID == request.id { ProgressView() }
                            }
                            .disabled(reviewingID != nil || isLoading)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Admin Requests")
        .tint(.appOrange)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog(
            confirmation?.approve == true ? "Grant administrator access?" : "Decline administrator request?",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            titleVisibility: .visible,
            presenting: confirmation
        ) { action in
            Button(action.approve ? "Approve Administrator" : "Decline Request",
                   role: action.approve ? nil : .destructive) {
                Task { await review(action) }
            }
        } message: { action in
            Text(action.approve
                ? "\(action.request.fullName) will be able to access the dashboard and approve other administrators."
                : "\(action.request.fullName) will not receive administrator access.")
        }
    }

    private func load() async {
        guard reviewingID == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result: [AdministratorRequest] = try await client.database
                .from("matter_forte_admin_requests")
                .select("user_id,full_name,email,created_at")
                .eq("status", value: "pending")
                .order("created_at", ascending: true)
                .execute().value
            try Task.checkCancellation()
            requests = result
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Unable to load admin requests. Check your connection and ensure the admin-approval database setup has been applied."
        }
    }

    private func review(_ action: ReviewAction) async {
        guard reviewingID == nil else { return }
        reviewingID = action.request.id
        errorMessage = nil
        resultMessage = nil
        defer { reviewingID = nil }
        do {
            try await client.database.rpc("matter_forte_review_admin_request", params: ReviewParameters(
                target_user_id: action.request.id, decision: action.approve ? "approved" : "rejected"
            )).execute()
            requests.removeAll { $0.id == action.request.id }
            resultMessage = action.approve
                ? "\(action.request.fullName) is now an administrator. They can refresh access or sign in again."
                : "\(action.request.fullName)’s request was declined."
        } catch {
            errorMessage = "The request could not be updated. Another admin may have reviewed it. Refresh the list and try again."
        }
    }
}
