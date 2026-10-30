import SwiftUI

struct SettingsSupportView: View {
    var contactURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                BrandLogo(scale: 0.58)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Help & Support")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.appOrange)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 12)
                    List {
                        Section("Edit your profile") {
                            Text("Open Settings → Edit Profile to update your name or email address. An email change may require confirmation from your inbox.")
                        }
                        Section("Change your password") {
                            Text("Open Settings → Change Password, enter your new password twice, then select Save Changes.")
                        }
                        Section("Trouble saving changes?") {
                            Text("Check your internet connection and try again. Read any message shown on the form before retrying.")
                        }
                        Section("Policies") {
                            Text("You can read the Terms of Service and Privacy Policy from Settings → Support & Legal.")
                        }
                        if let contactURL {
                            Section("Contact") {
                                Link("Contact Support", destination: contactURL)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Color.appOrange)
    }
}
