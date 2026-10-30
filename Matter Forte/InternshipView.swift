//
//  InternshipView.swift
//  Matter Forte
//
//  Created by Mthusi on 29/10/2026.
//

import SwiftUI

nonisolated struct InternshipRole: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var organisation: String
    var about: String
    var responsibilities: [String]
    var skills: [String]
    var isOpen = true

    enum CodingKeys: String, CodingKey {
        case id, title, responsibilities, skills
        case organisation = "company_name"
        case about = "description"
        case isOpen = "is_open"
    }

}

private enum MatterStyle {
    static let orange = Color(red: 0.98, green: 0.40, blue: 0.16)
    static let peach = Color(red: 1, green: 0.61, blue: 0.46)
}

struct InternshipView: View {
    @State private var roles: [InternshipRole] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var showAdd = false
    @State private var openOnly = false
    @State private var storageError: String?
    @State private var didPresentAdd = false

    private let presentsAddOnAppear: Bool

    init(presentsAddOnAppear: Bool = false) {
        self.presentsAddOnAppear = presentsAddOnAppear
    }

    private var filteredRoles: [InternshipRole] {
        roles.filter { role in
            (!openOnly || role.isOpen) &&
            (search.isEmpty ||
              role.title.localizedCaseInsensitiveContains(search) ||
              role.organisation.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
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

                if isLoading {
                    ProgressView("Loading internships…")
                        .frame(maxWidth: .infinity)
                }
                if let storageError {
                    Text(storageError).foregroundStyle(.red)
                    Button("Try Again") { Task { await loadRoles() } }
                }
                LazyVStack(spacing: 0) {
                    ForEach(filteredRoles) { role in
                        Divider()
                        NavigationLink(destination: DepartmentInfoView(role: role)) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(role.title)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Text(role.isOpen ? "Open" : "Closed")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(.white)
                                    .background(role.isOpen ? Color.orange.opacity(0.8) : Color.gray.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .padding(.vertical, 22)
                            .frame(minHeight: 100, alignment: .top)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the internship information board")
                    }
                    if filteredRoles.isEmpty && !isLoading && storageError == nil {
                        Text("No internships found. Try another search or add an internship.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 30)
                    }
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
            AddInternshipView { newRole in
                let saved = try await InternshipService.save(newRole)
                roles.removeAll { $0.id == saved.id }
                roles.insert(saved, at: 0)
                storageError = nil
                search = ""
                openOnly = false
            }
        }
        .refreshable { await loadRoles() }
        .task {
            await loadRoles()
            if presentsAddOnAppear && !didPresentAdd && !Task.isCancelled {
                didPresentAdd = true
                showAdd = true
            }
        }
        .tint(MatterStyle.orange)
    }

    private func loadRoles() async {
        isLoading = true
        storageError = nil
        defer { isLoading = false }
        do {
            let loaded = try await InternshipService.load()
            try Task.checkCancellation()
            roles = loaded
        } catch is CancellationError { return }
        catch {
            storageError = "Could not load internships. Check your connection and try again."
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
    @State private var draftID = UUID()
    let onSave: (InternshipRole) async throws -> Void

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !clean(title).isEmpty && clean(title).count <= 255 &&
        !clean(organisation).isEmpty && clean(organisation).count <= 255 &&
        !clean(about).isEmpty && !lines(responsibilities).isEmpty &&
        !skillList.isEmpty
    }

    private func lines(_ value: String) -> [String] {
        value.components(separatedBy: .newlines).map { clean($0) }.filter { !$0.isEmpty }
    }

    private var skillList: [String] {
        skills.components(separatedBy: ",").map { clean($0) }.filter { !$0.isEmpty }
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
            }
            .disabled(isSaving)
            .interactiveDismissDisabled(isSaving)
            .safeAreaInset(edge: .bottom) {
                if let saveError {
                    Text(saveError).font(.callout).foregroundStyle(.red)
                        .padding().frame(maxWidth: .infinity).background(.background)
                }
            }
            .navigationTitle("Add Internship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        guard canSave, !isSaving else { return }
                        let role = InternshipRole(
                            id: draftID,
                            title: clean(title),
                            organisation: clean(organisation),
                            about: clean(about),
                            responsibilities: lines(responsibilities),
                            skills: skillList,
                            isOpen: isOpen
                        )
                        isSaving = true
                        saveError = nil
                        Task {
                            defer { isSaving = false }
                            do {
                                try await onSave(role)
                                dismiss()
                            } catch {
                                saveError = "Could not save the internship. Check your connection and try again. Your details are still here."
                            }
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .tint(MatterStyle.orange)
    }
}

#Preview {
    NavigationStack {
        InternshipView()
    }
}
