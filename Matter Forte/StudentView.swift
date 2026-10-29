
import SwiftUI

struct StudentView: View {
    var body: some View {
        InstituteStudentsView()
            .tint(StudentDirectoryStyle.orange)
    }
}

private enum StudentDirectoryStyle {
    static let orange = Color(red: 1, green: 0.40, blue: 0.17)
    static let heading = Color(red: 0.76, green: 0.29, blue: 0.10)
}

nonisolated struct CohortStudent: Identifiable, Hashable, Sendable {
    let id: UUID
    var fullName: String
    var email: String
    var university: String
    var fieldOfStudy: String
    var biography: String

    var skills: [String]
    var essentialSkills: [String]

    var techSkills: [String] {
        get { skills }
        set { skills = newValue }
    }

    init(
        id: UUID = UUID(),
        fullName: String,
        email: String,
        university: String = "",
        fieldOfStudy: String = "",
        biography: String = "",
        skills: [String] = [],
        techSkills: [String]? = nil,
        essentialSkills: [String] = []
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.university = university
        self.fieldOfStudy = fieldOfStudy
        self.biography = biography
        self.skills = techSkills ?? skills
        self.essentialSkills = essentialSkills
    }

    var initials: String {
        fullName.split(separator: " ").prefix(2)
            .map { String($0.prefix(1)) }.joined().uppercased()
    }
}

nonisolated struct StudentCohort: Identifiable, Sendable {
    let id: UUID
    var name: String
    var students: [CohortStudent]

    init(id: UUID = UUID(), name: String, students: [CohortStudent]) {
        self.id = id
        self.name = name
        self.students = students
    }
}

struct StudentCohortListView: View {
    let cohorts: [StudentCohort]
    let isLoading: Bool
    let loadError: String?
    let onRetry: () -> Void
    let onSaveStudent: ((UUID, CohortStudent) async throws -> Void)?
    let onStudentAdded: () -> Void
    @State private var searchText = ""
    @State private var expandedCohorts: Set<UUID> = []
    @State private var collapsedSearchCohorts: Set<UUID> = []
    @State private var showingAddStudent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(cohorts: [StudentCohort] = [],
         isLoading: Bool = false,
         loadError: String? = nil,
         onRetry: @escaping () -> Void = {},
         onSaveStudent: ((UUID, CohortStudent) async throws -> Void)? = nil,
         onStudentAdded: @escaping () -> Void = {}) {
        self.cohorts = cohorts
        self.isLoading = isLoading
        self.loadError = loadError
        self.onRetry = onRetry
        self.onSaveStudent = onSaveStudent
        self.onStudentAdded = onStudentAdded
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(_ student: CohortStudent) -> Bool {
        student.fullName.localizedCaseInsensitiveContains(query)
            || student.email.localizedCaseInsensitiveContains(query)
    }

    private var filteredCohorts: [StudentCohort] {
        guard !query.isEmpty else { return cohorts }
        return cohorts.compactMap { cohort in
            if cohort.name.localizedCaseInsensitiveContains(query) {
                return cohort
            }
            let students = cohort.students.filter(matches)
            guard !students.isEmpty else { return nil }
            return StudentCohort(id: cohort.id, name: cohort.name, students: students)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                searchField
                    .padding(.top, 20)

                Text("Cohorts")
                    .font(.largeTitle.bold())
                    .foregroundStyle(StudentDirectoryStyle.heading)
                    .accessibilityAddTraits(.isHeader)

                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView("Loading institute students…")
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                    if let loadError {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Unable to refresh students", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text(loadError).font(.subheadline)
                            Button("Try Again", action: onRetry)
                                .buttonStyle(.bordered)
                        }
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(StudentDirectoryStyle.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if filteredCohorts.isEmpty && !isLoading && loadError == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.largeTitle)
                            Text(cohorts.isEmpty ? "No cohorts yet" : "No matching students or cohorts")
                                .font(.headline)
                            Text(cohorts.isEmpty ? "Add the first student to start your institute directory." : "Try another name or clear your search.")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }

                    ForEach(filteredCohorts) { cohort in
                        cohortSection(cohort)
                    }
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: searchText) {
            collapsedSearchCohorts.removeAll()
        }
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddStudent = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .disabled(onSaveStudent == nil)
                .accessibilityLabel("Add a student")
            }
        }
        .navigationDestination(for: StudentProfileRoute.self) { route in
            CohortStudentProfileView(student: route.student, cohortName: route.cohortName)
        }
        .sheet(isPresented: $showingAddStudent, onDismiss: onStudentAdded) {
            if let onSaveStudent {
                AddCohortStudentView(
                    cohorts: cohorts.isEmpty ? [StudentCohort(name: "MCRI", students: [])] : cohorts,
                    onSave: onSaveStudent
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .accessibilityHidden(true)
            TextField("Search student or cohort", text: $searchText)
                .font(.body.weight(.semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search students or cohorts")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(StudentDirectoryStyle.orange, lineWidth: 2.5)
        }
    }

    private func cohortSection(_ cohort: StudentCohort) -> some View {
        // Search temporarily expands matching cohorts without changing saved expansion state.
        let isExpanded = query.isEmpty
            ? expandedCohorts.contains(cohort.id)
            : !collapsedSearchCohorts.contains(cohort.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    if query.isEmpty {
                        if expandedCohorts.contains(cohort.id) {
                            expandedCohorts.remove(cohort.id)
                        } else {
                            expandedCohorts.insert(cohort.id)
                        }
                    } else if collapsedSearchCohorts.contains(cohort.id) {
                        collapsedSearchCohorts.remove(cohort.id)
                    } else {
                        collapsedSearchCohorts.insert(cohort.id)
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "star.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(cohort.name)
                        .font(.title3)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Show or hide students")

            if isExpanded {
                VStack(spacing: 0) {
                    if cohort.students.isEmpty {
                        Text("No students in this cohort yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    ForEach(cohort.students) { student in
                        NavigationLink(value: StudentProfileRoute(student: student, cohortName: cohort.name)) {
                            HStack(spacing: 12) {
                                StudentInitialsView(student: student, size: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(student.fullName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if !student.fieldOfStudy.isEmpty {
                                        Text(student.fieldOfStudy)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open student profile")
                    }
                }
                .background(StudentDirectoryStyle.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .padding(.leading, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct StudentProfileRoute: Hashable {
    let student: CohortStudent
    let cohortName: String
}

private struct StudentInitialsView: View {
    let student: CohortStudent
    var size: CGFloat = 88

    var body: some View {
        Text(student.initials)
            .font(.system(size: size * 0.34, weight: .bold))
            .foregroundStyle(StudentDirectoryStyle.heading)
            .frame(width: size, height: size)
            .background(StudentDirectoryStyle.orange.opacity(0.13), in: Circle())
            .accessibilityHidden(true)
    }
}

struct CohortStudentProfileView: View {
    @State private var student: CohortStudent
    @State private var showingEdit = false
    let cohortName: String

    init(student: CohortStudent, cohortName: String) {
        _student = State(initialValue: student)
        self.cohortName = cohortName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    StudentInitialsView(student: student)
                    Text(student.fullName)
                        .font(.title.bold())
                    Text(cohortName)
                        .font(.headline)
                        .foregroundStyle(StudentDirectoryStyle.heading)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 20) {
                    profileDetail("Email", value: student.email)
                    profileDetail("University", value: student.university)
                    profileDetail("Field of study", value: student.fieldOfStudy)
                    profileDetail("About", value: student.biography)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudentDirectoryStyle.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))

                NavigationLink {
                    StudentOverallProgressView(
                        techSkills: student.techSkills,
                        essentialSkills: student.essentialSkills
                    )
                } label: {
                    Text("Overall Progress")
                        .font(.headline)
                        .underline()
                        .foregroundStyle(StudentDirectoryStyle.heading)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("View all tech skills and essential skills for this student")
            }
            .frame(maxWidth: 560)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Student Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
                    .accessibilityLabel("Edit student portfolio")
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddCohortStudentView(cohorts: [StudentCohort(name: cohortName, students: [])],
                initialStudent: student,
                onSave: { _, updated in
                    let record = try await InstituteDashboardService.saveStudent(updated, cohortName: cohortName, existing: true)
                    student = record.profile
                })
        }
        .textSelection(.enabled)
    }

    private func profileDetail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not provided" : value)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Shows the selected student's assigned skills. No assessment scores are inferred.
struct StudentOverallProgressView: View {
    let techSkills: [String]
    let essentialSkills: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                skillSection("Tech Skills", icon: "laptopcomputer", skills: techSkills)
                skillSection("Essential Skills", icon: "person.2", skills: essentialSkills)
            }
            .frame(maxWidth: 560)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overall Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func skillSection(_ title: String, icon: String, skills: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.title3.bold())
                Spacer(minLength: 8)
                Text("\(skills.count)")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel("\(skills.count) skills")
            }
            .foregroundStyle(StudentDirectoryStyle.heading)
            .accessibilityAddTraits(.isHeader)

            if skills.isEmpty {
                Text("No skills recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Index identity preserves repeated names without duplicate ForEach IDs.
                ForEach(skills.indices, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(StudentDirectoryStyle.orange)
                            .padding(.top, 7)
                            .accessibilityHidden(true)
                        Text(skills[index])
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudentDirectoryStyle.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct AddCohortStudentView: View {
    let cohorts: [StudentCohort]
    let onSave: (UUID, CohortStudent) async throws -> Void
    let usesNavigationStack: Bool
    let initialStudent: CohortStudent?
    @State private var biography = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var didSave = false
    @Environment(\.dismiss) private var dismiss
    @State private var cohortID: UUID
    @State private var fullName = ""
    @State private var email = ""
    @State private var university = ""
    @State private var fieldOfStudy = ""
    @State private var techSkillsText = ""
    @State private var essentialSkillsText = ""

    private func parsedSkills(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    init(cohorts: [StudentCohort], usesNavigationStack: Bool = true,
         initialStudent: CohortStudent? = nil,
         onSave: @escaping (UUID, CohortStudent) async throws -> Void) {
        self.cohorts = cohorts
        self.usesNavigationStack = usesNavigationStack
        self.onSave = onSave
        self.initialStudent = initialStudent
        _fullName = State(initialValue: initialStudent?.fullName ?? "")
        _email = State(initialValue: initialStudent?.email ?? "")
        _university = State(initialValue: initialStudent?.university ?? "MCRI")
        _fieldOfStudy = State(initialValue: initialStudent?.fieldOfStudy ?? "")
        _biography = State(initialValue: initialStudent?.biography ?? "")
        _techSkillsText = State(initialValue: initialStudent?.techSkills.joined(separator: ", ") ?? "")
        _essentialSkillsText = State(initialValue: initialStudent?.essentialSkills.joined(separator: ", ") ?? "")
        _cohortID = State(initialValue: cohorts.first?.id ?? UUID())
    }

    var body: some View {
        Group {
            if usesNavigationStack {
                NavigationStack { form }
            } else {
                form
            }
        }
        .tint(StudentDirectoryStyle.orange)
        .alert("Student saved", isPresented: $didSave) {
            Button("Done") { dismiss() }
        } message: {
            Text("The student portfolio has been saved to Supabase.")
        }
    }

    private var form: some View {
            Form {
                Section("Student details") {
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("University", text: $university)
                    TextField("Field of study", text: $fieldOfStudy)
                    TextField("About the student", text: $biography, axis: .vertical)
                }
                Section {
                    TextField("Tech skills", text: $techSkillsText, axis: .vertical)
                    TextField("Essential skills", text: $essentialSkillsText, axis: .vertical)
                } header: {
                    Text("Skills")
                } footer: {
                    Text("Separate each skill with a comma.")
                }
                Section("Cohort") {
                    Picker("Cohort", selection: $cohortID) {
                        ForEach(cohorts) { cohort in
                            Text(cohort.name).tag(cohort.id)
                        }
                    }
                }
                Section {
                    Text("Administrators maintain this student portfolio. Creating a portfolio does not create an app login.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isSaving)
            .safeAreaInset(edge: .bottom) {
                if let saveError { Text(saveError).font(.caption).foregroundStyle(.red).padding().background(.background) }
            }
            .navigationTitle(initialStudent == nil ? "Add Student" : "Edit Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        saveError = nil
                        let student = CohortStudent(
                            id: initialStudent?.id ?? UUID(),
                            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            university: university,
                            fieldOfStudy: fieldOfStudy,
                            biography: biography,
                            techSkills: parsedSkills(techSkillsText),
                            essentialSkills: parsedSkills(essentialSkillsText)
                        )
                        Task {
                            defer { isSaving = false }
                            do { try await onSave(cohortID, student); didSave = true }
                            catch { saveError = "The student portfolio could not be saved. Check your connection and try again." }
                        }
                    }
                    .disabled(isSaving || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !SignUpValidation.email(email.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
    }
}

struct StudentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { StudentView() }
    }
}
