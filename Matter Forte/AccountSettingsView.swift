import SwiftUI
import Auth

struct AccountSettingsView: View {
    @ObservedObject var model: AuthViewModel

    var body: some View {
        List {
            Section("Account") {
                if let session = model.authenticatedSession {
                    LabeledContent("Email", value: session.user.email ?? "Signed in")
                }
            }
            Section("Legal") {
                NavigationLink("Terms of Service") { LegalInformationView(document: LegalCopy.terms) }
                NavigationLink("Privacy Policy") { LegalInformationView(document: LegalCopy.privacy) }
            }
            Section {
                if let message = model.message { Text(message).foregroundStyle(.red) }
                Button(model.isLoading ? "Signing Out…" : "Sign Out", role: .destructive) {
                    Task { await model.signOut() }
                }
                .disabled(model.isLoading)
            }
        }
        .navigationTitle("Settings")
    }
}

private struct LegalInformationView: View {
    let document: LegalDocument
    var body: some View {
        List {
            if document.isSampleCopy {
                Text("Draft document for testing").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(document.sections) { section in
                Section(section.title) { Text(section.text).textSelection(.enabled) }
            }
            Text("Version: \(document.version)").font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
