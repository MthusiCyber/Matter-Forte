import SwiftUI
import Supabase

@MainActor
enum InstituteDashboardService {
    static func loadDashboard() async throws -> AdministratorDashboardSnapshot {
        try await SupabaseConfig.client.database
            .rpc("matter_forte_dashboard_snapshot").execute().value
    }

    static func loadStudents() async throws -> [InstituteStudent] {
        try await SupabaseConfig.client.database
            .rpc("matter_forte_list_students").execute().value
    }
}

nonisolated struct InstituteStudent: Decodable, Identifiable, Sendable {
    let id: UUID
    let fullName: String
    let email: String
    let institute: String
    let programme: String
    let studentNumber: String

    enum CodingKeys: String, CodingKey {
        case id, email, institute, programme
        case fullName = "full_name"
        case studentNumber = "student_number"
    }
}

struct InstituteStudentsView: View {
    @State private var students: [InstituteStudent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredStudents: [InstituteStudent] {
        guard !searchText.isEmpty else { return students }
        return students.filter {
            "\($0.fullName) \($0.email) \($0.studentNumber)".localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading institute students…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                Button("Try Again") { Task { await load() } }
            } else if students.isEmpty {
                ContentUnavailableView("No students yet", systemImage: "graduationcap",
                    description: Text("Institute student accounts will appear here."))
            } else if filteredStudents.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                Section("\(filteredStudents.count) students") {
                    ForEach(filteredStudents) { student in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(student.fullName).font(.headline)
                            Text(student.email).font(.subheadline)
                            Text("\(student.institute) · \(student.programme)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(student.studentNumber).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Find a student")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await InstituteDashboardService.loadStudents()
            try Task.checkCancellation()
            students = result
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Unable to load students. Check your connection and ensure the institute dashboard database setup is installed."
        }
    }
}
