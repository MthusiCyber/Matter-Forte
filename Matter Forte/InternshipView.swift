import SwiftUI

nonisolated struct InternshipRole: Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var organisation: String
    var about: String
    var responsibilities: [String]
    var skills: [String]
    var isOpen = true
}

private enum MatterStyle {
    static let orange = Color(red: 0.98, green: 0.40, blue: 0.16)
    static let peach = Color(red: 1, green: 0.61, blue: 0.46)
}

struct InternshipView: View {
    @State private var internships: [EmployerInternship] = []
    @State private var search = ""
    @State private var showAdd = false
    @State private var openOnly = false
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var didPresentAdd = false

    private let presentsAddOnAppear: Bool

    init(presentsAddOnAppear: Bool = false) {
        self.presentsAddOnAppear = presentsAddOnAppear
    }

    private var filteredInternships: [EmployerInternship] {
        internships.filter { internship in
            (!openOnly || internship.isOpen) &&
            (search.isEmpty ||
             internship.title.localizedCaseInsensitiveContains(search) ||
             internship.organisation.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                searchField
                listHeader

                if isLoading && internships.isEmpty {
                    ProgressView("Loading internships…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if let loadError {
                    errorCard(loadError)
                } else {
                    internshipList
                }
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add Internship", systemImage: "plus")
                    }
                    Toggle("Open internships only", isOn: $openOnly)
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Internship menu")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddInternshipView { draft in
                try await WorkflowService.saveInternship(draft)
                await load()
            }
        }
        .task { await load() }
        .onAppear {
            if presentsAddOnAppear && !didPresentAdd {
                didPresentAdd = true
                showAdd = true
            }
        }
        .refreshable { await load() }
        .tint(MatterStyle.orange)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Internships")
                .font(.title2.bold())
            Text("Manage opportunities and Student Placement")
                .frame(maxWidth: 280)
            Button {
                showAdd = true
            } label: {
                Label("Add Internship", systemImage: "plus")
                    .frame(maxWidth: 280)
                    .padding(.vertical, 8)
                    .background(MatterStyle.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search internships")
            TextField("Search Role or Organization", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(MatterStyle.orange, lineWidth: 1)
                }
        }
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Go to Internship Departments")
            Text("Tap a role below")
                .foregroundStyle(MatterStyle.orange)
            if openOnly {
                Text("Showing open internships")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
    }

    private var internshipList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredInternships) { internship in
                Divider()
                NavigationLink(destination: DepartmentInfoView(role: internship.role)) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(internship.title)
                                .foregroundStyle(.primary)
                            if !internship.organisation.isEmpty {
                                Text(internship.organisation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Text(internship.isOpen ? "Open" : "Closed")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(.white)
                            .background(internship.isOpen ? Color.orange.opacity(0.8) : Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .padding(.vertical, 22)
                    .frame(minHeight: 100, alignment: .top)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the internship information board")
            }
            if filteredInternships.isEmpty {
                Text(internships.isEmpty
                     ? "No internships yet. Tap Add Internship to publish your first opportunity."
                     : "No internships found. Try another search or add an internship.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 30)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Unable to load internships", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message).font(.subheadline)
            Button("Try Again") { Task { await load() } }
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MatterStyle.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let result = try await WorkflowService.loadInternships()
            try Task.checkCancellation()
            internships = result
        } catch is CancellationError {
            return
        } catch {
            loadError = "Check your connection and try again."
        }
    }
}

struct DepartmentInfoView: View {
    let role: InternshipRole
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text(role.title)
                    .font(.largeTitle)
                    .foregroundStyle(MatterStyle.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 145)
                    .padding(.horizontal, 20)
                    .background(Color(white: 0.22))

                Text("Information Board")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 34) {
                    VStack(spacing: 12) {
                        Text("About the Role")
                            .font(.title2)
                        Text(role.about)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 22) {
                        Text("Key Responsibilities")
                            .font(.title2)
                        ForEach(Array(role.responsibilities.enumerated()), id: \.offset) { _, responsibility in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(MatterStyle.orange)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)
                                Text(responsibility)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    VStack(spacing: 24) {
                        Text("Essential skills required")
                            .font(.title2)
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Array(role.skills.enumerated()), id: \.offset) { _, skill in
                                Text(skill)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(MatterStyle.peach)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Department Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AddInternshipView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var organisation = ""
    @State private var about = ""
    @State private var responsibilities = ""
    @State private var skills = ""
    @State private var isOpen = true
    @State private var isSaving = false
    @State private var saveError: String?
    let onSave: (InternshipRole) async throws -> Void

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func lines(_ value: String) -> [String] {
        value.components(separatedBy: .newlines).map { clean($0) }.filter { !$0.isEmpty }
    }

    private var skillList: [String] {
        skills.components(separatedBy: ",").map { clean($0) }.filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !clean(title).isEmpty && !clean(organisation).isEmpty &&
        !clean(about).isEmpty && !lines(responsibilities).isEmpty &&
        !skillList.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Internship") {
                    TextField("Role title", text: $title)
                    TextField("Organisation", text: $organisation)
                    Toggle("Open for interns", isOn: $isOpen)
                }
                Section("About the role") {
                    TextEditor(text: $about)
                        .frame(minHeight: 100)
                        .accessibilityLabel("About the role")
                }
                Section {
                    TextEditor(text: $responsibilities)
                        .frame(minHeight: 120)
                        .accessibilityLabel("Responsibilities, one per line")
                } header: {
                    Text("Key responsibilities")
                } footer: {
                    Text("Enter one responsibility on each line.")
                }
                Section {
                    TextField("Swift, Git, Collaboration", text: $skills, axis: .vertical)
                } header: {
                    Text("Essential skills")
                } footer: {
                    Text("Separate skills with commas. Complete all fields to save.")
                }
                if let saveError {
                    Section {
                        Text(saveError).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Internship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        save()
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .disabled(isSaving)
        }
        .tint(MatterStyle.orange)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        let draft = InternshipRole(
            title: clean(title),
            organisation: clean(organisation),
            about: clean(about),
            responsibilities: lines(responsibilities),
            skills: skillList,
            isOpen: isOpen
        )
        Task {
            defer { isSaving = false }
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                saveError = "The internship could not be saved. Check your connection and try again."
            }
        }
    }
}

#Preview {
    NavigationStack {
        InternshipView()
    }
}
