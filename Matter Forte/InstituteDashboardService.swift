import SwiftUI
import Supabase

@MainActor
enum InstituteDashboardService {
    static func loadDashboard() async throws -> AdministratorDashboardSnapshot {
        try await SupabaseConfig.client.database.rpc("matter_forte_dashboard_snapshot").execute().value
    }

    static func loadStudents() async throws -> [InstituteStudent] {
        try await SupabaseConfig.client.database.rpc("matter_forte_list_students").execute().value
    }

    static func saveStudent(_ student: CohortStudent, cohortName: String = "MCRI", existing: Bool = false) async throws -> InstituteStudent {
        nonisolated struct StudentDetails: Encodable, Sendable {
            let id: UUID?
            let full_name: String
            let email: String
            let institute: String
            let programme: String
            let cohort: String
            let biography: String
            let skills: [String]
            let essential_skills: [String]
        }
        nonisolated struct Parameters: Encodable, Sendable { let details: StudentDetails }
        return try await SupabaseConfig.client.database.rpc("matter_forte_save_student", params: Parameters(details: StudentDetails(
            id: existing ? student.id : nil, full_name: student.fullName, email: student.email,
            institute: student.university.isEmpty ? "MCRI" : student.university,
            programme: student.fieldOfStudy, cohort: cohortName, biography: student.biography,
            skills: student.techSkills, essential_skills: student.essentialSkills
        ))).execute().value
    }
}

nonisolated struct InstituteStudent: Decodable, Identifiable, Sendable {
    let id: UUID
    let fullName: String
    let email: String
    let institute: String
    let programme: String
    let studentNumber: String
    let cohort: String?
    let biography: String?
    let skills: [String]?
    let essentialSkills: [String]?

    enum CodingKeys: String, CodingKey {
        case id, email, institute, programme, cohort, biography, skills
        case fullName = "full_name"
        case studentNumber = "student_number"
        case essentialSkills = "essential_skills"
    }

    var profile: CohortStudent {
        CohortStudent(id: id, fullName: fullName, email: email,
            university: institute, fieldOfStudy: programme, biography: biography ?? "",
            skills: skills ?? [], essentialSkills: essentialSkills ?? [])
    }
}

struct InstituteStudentsView: View {
    @State private var students: [InstituteStudent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var revision = UUID()
    @State private var cohorts: [StudentCohort] = []

    private func makeCohorts(_ students: [InstituteStudent]) -> [StudentCohort] {
        let groups = Dictionary(grouping: students) {
            ($0.cohort?.isEmpty == false ? $0.cohort! : ($0.programme.isEmpty ? $0.institute : $0.programme))
        }
        return groups.keys.sorted().map { name in
            StudentCohort(name: name, students: groups[name, default: []].map(\.profile))
        }
    }

    var body: some View {
        Group {
            if isLoading && students.isEmpty {
                ProgressView("Loading institute students…")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Unable to load students", systemImage: "wifi.exclamationmark")
                } description: { Text(errorMessage) } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            } else {
                StudentCohortListView(cohorts: cohorts,
                    onSaveStudent: { cohortID, student in
                        let name = cohorts.first(where: { $0.id == cohortID })?.name ?? "MCRI"
                        _ = try await InstituteDashboardService.saveStudent(student, cohortName: name)
                    },
                    onStudentAdded: { Task { await load() } })
                    .id(revision)
                    .refreshable { await load() }
            }
        }
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
            cohorts = makeCohorts(result)
            revision = UUID()
        } catch is CancellationError { return }
        catch {
            #if DEBUG
            debugPrint("Student directory load failed:", error)
            #endif
            errorMessage = "Check your connection and try again."
        }
    }
}
