
import SwiftUI

struct StudentView: View {
    var body: some View {
        NavigationStack {
            StudentCohortListView()
        }
        .tint(StudentDirectoryStyle.orange)
    }
}

private enum StudentDirectoryStyle {
    static let orange = Color(red: 1, green: 0.40, blue: 0.17)
    static let heading = Color(red: 0.76, green: 0.29, blue: 0.10)
}

struct CohortStudent: Identifiable, Hashable {
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

struct StudentCohort: Identifiable {
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
    @State private var cohorts: [StudentCohort]
    @State private var searchText = ""
    @State private var expandedCohorts: Set<UUID> = []
    @State private var collapsedSearchCohorts: Set<UUID> = []
    @State private var showingAddStudent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(cohorts: [StudentCohort] = StudentCohort.sampleData) {
        _cohorts = State(initialValue: cohorts)
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
                    if filteredCohorts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.largeTitle)
                            Text(cohorts.isEmpty ? "No cohorts yet" : "No matching students or cohorts")
                                .font(.headline)
                            Text(cohorts.isEmpty ? "Add cohorts to your data to get started." : "Try another name or clear your search.")
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
                .disabled(cohorts.isEmpty)
                .accessibilityLabel("Add a student")
            }
        }
        .navigationDestination(for: StudentProfileRoute.self) { route in
            CohortStudentProfileView(student: route.student, cohortName: route.cohortName)
        }
        .sheet(isPresented: $showingAddStudent) {
            AddCohortStudentView(cohorts: cohorts) { cohortID, student in
                guard let index = cohorts.firstIndex(where: { $0.id == cohortID }) else { return }
                cohorts[index].students.append(student)
                searchText = ""
                expandedCohorts.insert(cohortID)
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
    let student: CohortStudent
    let cohortName: String

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

private struct AddCohortStudentView: View {
    let cohorts: [StudentCohort]
    let onSave: (UUID, CohortStudent) -> Void
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

    init(cohorts: [StudentCohort], onSave: @escaping (UUID, CohortStudent) -> Void) {
        self.cohorts = cohorts
        self.onSave = onSave
        _cohortID = State(initialValue: cohorts.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
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
                    Text("New students are available for this session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(cohortID, CohortStudent(
                            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            university: university,
                            fieldOfStudy: fieldOfStudy,
                            techSkills: parsedSkills(techSkillsText),
                            essentialSkills: parsedSkills(essentialSkillsText)
                        ))
                        dismiss()
                    }
                    .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(StudentDirectoryStyle.orange)
    }
}

extension StudentCohort {
    // Fictional sample students. Replace with records from your data source.
    static let sampleData: [StudentCohort] = [
        StudentCohort(name: "Cohort 6", students: [
            CohortStudent(fullName: "Prosperity Ndou", email: "proe@example.com", university: "MCRI", fieldOfStudy: "Developer", biography: "Interested in building accessible mobile applications.", skills: ["Swift", "UI Design"], essentialSkills: ["Communication", "Teamwork"]),
            CohortStudent(fullName: "Wadzi Tanhuke", email: "wadzie@example.com", university: "MCRI", fieldOfStudy: "Documentation", biography: "Enjoys solving problems through technology.", skills: ["SQL", "Data Analysis"], essentialSkills: ["Problem Solving", "Time Management"])
        ]),
        StudentCohort(name: "Cohort 7", students: [
            CohortStudent(fullName: "Valerie Sangweni", email: "vale@example.com", university: "MCRI", fieldOfStudy: "Developer", biography: "Interested in entrepreneurship and project management.", essentialSkills: ["Research", "Project Planning", "Communication"]),
            CohortStudent(fullName: "Mthusi Ncube", email: "mthusi@example.com", university: "MCRI", fieldOfStudy: "Software Engineering", biography: "Learning to build useful web and mobile products.", skills: ["Python", "SwiftUI"], essentialSkills: ["Collaboration", "Adaptability"])
        ]),
        StudentCohort(name: "Cohort 8", students: [
            CohortStudent(fullName: "Hazel", email: "hazel@example.com", university: "Sample University", fieldOfStudy: "Design", biography: "Passionate about thoughtful, simple user experiences.", skills: ["Prototyping", "Visual Design"], essentialSkills: ["Creativity", "Presentation"]),
            CohortStudent(fullName: "Ashley", email: "ashley@example.com", university: "Sample University", fieldOfStudy: "Data Science", biography: "Interested in using data to answer practical questions.", skills: ["Statistics", "Python"], essentialSkills: ["Critical Thinking", "Teamwork"])
        ])
    ]
}

struct StudentView_Previews: PreviewProvider {
    static var previews: some View {
        StudentView()
    }
}
