//
// ContentView.swift
// Matter Forte
//
// Created by Mthusi on 29/10/2026.
//

import SwiftUI

struct InternshipRole: Identifiable, Codable, Hashable {
  var id = UUID()
  var title: String
  var organisation: String
  var about: String
  var responsibilities: [String]
  var skills: [String]
  var isOpen = true

  static let samples: [InternshipRole] = [
    .init(
      title: "Full Stack Developer Intern",
      organisation: "Matter",
      about: "Join our software development team and gain hands-on experience working on real-world projects. Learn from experienced developers, write clean code, and contribute to building innovative solutions.",
      responsibilities: [
        "Assist in developing and maintaining software applications",
        "Collaborate with the development team",
        "Write and test code under supervision",
        "Participate in code reviews and team meetings"
      ],
      skills: ["Swift language", "Git and GitHub", "Collaboration", "Problem solving"]
    ),
    .init(
      title: "UI/UX Designer Intern",
      organisation: "Matter",
      about: "Help create clear, accessible digital experiences. Work with designers and developers to turn user needs into useful interfaces.",
      responsibilities: [
        "Create wireframes and interactive prototypes",
        "Support user interviews and usability testing",
        "Design accessible layouts and components",
        "Collaborate with developers on implementation"
      ],
      skills: ["Figma", "Prototyping", "User research", "Collaboration"]
    ),
    .init(
      title: "Quality Assurance Intern",
      organisation: "Matter",
      about: "Help the team deliver reliable software by testing features, documenting issues, and checking fixes before release.",
      responsibilities: [
        "Write and run test cases",
        "Document bugs with clear reproduction steps",
        "Verify fixes and perform regression testing",
        "Share testing results with the development team"
      ],
      skills: ["Attention to detail", "Software testing", "Communication", "Problem solving"]
    ),
    .init(
      title: "Business Analyst Intern",
      organisation: "Matter",
      about: "Work with stakeholders to understand business needs and help translate them into clear requirements for the product team.",
      responsibilities: [
        "Gather and document business requirements",
        "Map processes and identify improvements",
        "Assist with data analysis and reporting",
        "Communicate findings to stakeholders"
      ],
      skills: ["Analysis", "Documentation", "Communication", "Spreadsheets"]
    )
  ]
}

private enum MatterStyle {
  static let orange = Color(red: 0.98, green: 0.40, blue: 0.16)
  static let peach = Color(red: 1, green: 0.61, blue: 0.46)
}

struct InternshipView: View {
  @AppStorage("matter.internships.v1") private var savedRoles = Data()
  @State private var roles = InternshipRole.samples
  @State private var search = ""
  @State private var showAdd = false
  @State private var openOnly = false
  @State private var showResetConfirmation = false
  @State private var storageError: String?

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
          if filteredRoles.isEmpty {
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
          Button("Delete", role: .destructive) {
            showResetConfirmation = true
          }
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
        roles.insert(newRole, at: 0)
        search = ""
        openOnly = false
        persistRoles()
      }
    }
    .confirmationDialog("Replace all internships with the sample list?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
      Button("Reset internships", role: .destructive) {
        roles = InternshipRole.samples
        search = ""
        openOnly = false
        persistRoles()
      }
    }
    .alert("Could not load internships", isPresented: Binding(
      get: { storageError != nil },
      set: { if !$0 { storageError = nil } }
    )) {
      Button("OK") { storageError = nil }
    } message: {
      Text(storageError ?? "")
    }
    .onAppear {
      guard !savedRoles.isEmpty else { return }
      do {
        roles = try JSONDecoder().decode([InternshipRole].self, from: savedRoles)
      } catch {
        storageError = "Your saved data could not be read. Samples are shown; saved data has not been replaced."
      }
    }
    .tint(MatterStyle.orange)
  }

  private func persistRoles() {
    do {
      savedRoles = try JSONEncoder().encode(roles)
    } catch {
      storageError = "The internships could not be saved. Please try again."
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
  let onSave: (InternshipRole) -> Void

  private func clean(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    !clean(title).isEmpty && !clean(organisation).isEmpty &&
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
      .navigationTitle("Add Internship")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(InternshipRole(
              title: clean(title),
              organisation: clean(organisation),
              about: clean(about),
              responsibilities: lines(responsibilities),
              skills: skillList,
              isOpen: isOpen
            ))
            dismiss()
          }
          .disabled(!canSave)
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
