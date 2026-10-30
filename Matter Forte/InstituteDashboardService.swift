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

    static func saveStudent(_ student: CohortStudent, cohortName: String, existing: Bool = false) async throws -> InstituteStudent {
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

    var cohortDisplayName: String {
        let name = cohort?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, name.caseInsensitiveCompare("MCRI") != .orderedSame else {
            return "Unassigned cohort"
        }
        return StudentCohort.name(forNumber: name) ?? name
    }

    var profile: CohortStudent {
        CohortStudent(id: id, fullName: fullName, email: email,
            university: institute, fieldOfStudy: programme, biography: biography ?? "",
            skills: skills ?? [], essentialSkills: essentialSkills ?? [])
    }
}

struct InstituteStudentsView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cohorts: [StudentCohort] = []
    @State private var cohortIDs: [String: UUID] = [:]

    private func makeCohorts(_ students: [InstituteStudent]) -> [StudentCohort] {
        let groups = Dictionary(grouping: students, by: \.cohortDisplayName)
        return groups.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { name in
            let id = cohortIDs[name] ?? UUID()
            cohortIDs[name] = id
            return StudentCohort(id: id, name: name, students: groups[name, default: []].map(\.profile))
        }
    }

    var body: some View {
        StudentCohortListView(
            cohorts: cohorts,
            isLoading: isLoading,
            loadError: errorMessage,
            onRetry: { Task { await load() } },
            onSaveStudent: { cohortName, student in
                _ = try await InstituteDashboardService.saveStudent(student, cohortName: cohortName)
            },
            onStudentAdded: { Task { await load() } }
        )
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
            cohorts = makeCohorts(result)
        } catch is CancellationError { return }
        catch {
            #if DEBUG
            debugPrint("Student directory load failed:", error)
            #endif
            errorMessage = "Check your connection and try again."
        }
    }
}

struct InstituteAddStudentView: View {
    @State private var cohorts: [StudentCohort] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading cohorts…")
            } else if loadFailed {
                ContentUnavailableView {
                    Label("Could not load cohorts", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            } else {
                AddCohortStudentView(cohorts: cohorts, usesNavigationStack: false) { name, student in
                    _ = try await InstituteDashboardService.saveStudent(student, cohortName: name)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let students = try await InstituteDashboardService.loadStudents()
            try Task.checkCancellation()
            let names = Set(students.map(\.cohortDisplayName))
            cohorts = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map { StudentCohort(name: $0, students: []) }
        } catch is CancellationError { return }
        catch { loadFailed = true }
    }
}
