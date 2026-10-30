import SwiftUI

/// Settings remains independent of authentication so it can be previewed and reused.
struct SettingsView: View {
    var isSigningOut = false
    var signOutError: String?
    var onEditProfile: () -> Void = {}
    var onChangePassword: () -> Void = {}
    var onSignOut: () -> Void = {}
    var supportURL: URL?

    @AppStorage("settings.darkAppearance") private var darkAppearance = false
    // Local preference only. Notification delivery must also honor this value.
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = false
    @State private var legalPage: LegalPage?
    @State private var showingSupport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .padding(.top, 32)
                    .foregroundStyle(Color.appOrange)
                    .accessibilityAddTraits(.isHeader)
                Text("Manage your account and preferences.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                Divider()

                SettingsSectionTitle(title: "Account")
                SettingsActionRow(title: "Edit Profile", subtitle: "Update your name and email address", action: onEditProfile)
                SettingsActionRow(title: "Change Password", subtitle: "Keep your account secure", action: onChangePassword)

                SettingsSectionTitle(title: "Preferences")
                SettingsPreferences(
                    notificationsEnabled: $notificationsEnabled,
                    darkAppearance: $darkAppearance
                )

                SettingsSectionTitle(title: "More Info & Support")
                SettingsActionRow(title: "Help & Support") { showingSupport = true }
                SettingsActionRow(title: "Terms of Service") { legalPage = .terms }
                SettingsActionRow(title: "Privacy Policy") { legalPage = .privacy }

                SettingsFooter(isSigningOut: isSigningOut, error: signOutError, onSignOut: onSignOut)
                    .padding(.top, 32)
                    .padding(.bottom, 36)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .tint(Color.appOrange)
        .preferredColorScheme(darkAppearance ? .dark : .light)
        .disabled(isSigningOut)
        .sheet(item: $legalPage) { page in
            SettingsLegalView(startingPage: page, onFinish: { legalPage = nil })
                .preferredColorScheme(darkAppearance ? .dark : .light)
        }
        .sheet(isPresented: $showingSupport) {
            SettingsSupportView(contactURL: supportURL)
        }
    }
}

private struct SettingsSectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.appOrange)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }
}

private struct SettingsActionRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title)
                            .font(.body.weight(subtitle == nil ? .regular : .semibold))
                            .foregroundStyle(.primary)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.appOrange)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.vertical, subtitle == nil ? 6 : 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
        }
    }
}

private struct SettingsPreferences: View {
    @Binding var notificationsEnabled: Bool
    @Binding var darkAppearance: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Notifications").font(.body.weight(.semibold))
                    Text("Receive account and activity updates")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Color.appOrange)
            .padding(.vertical, 20)
            Divider()
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(spacing: 20))
            layout {
                Text("Appearance")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SettingsAppearancePicker(isDark: $darkAppearance)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 190)
            }
            .padding(.vertical, 16)
            Divider()
        }
    }
}

private struct SettingsAppearancePicker: View {
    @Binding var isDark: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button { isDark = false } label: {
                Text("Light")
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(isDark ? Color.primary : .white)
                    .background(isDark ? Color.clear : Color.appOrange, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityAddTraits(isDark ? [] : .isSelected)
            Button { isDark = true } label: {
                Text("Dark")
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(isDark ? .white : Color.primary)
                    .background(isDark ? Color.appOrange : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityAddTraits(isDark ? .isSelected : [])
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.plain)
        .padding(3)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }
}

private struct SettingsFooter: View {
    let isSigningOut: Bool
    let error: String?
    let onSignOut: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 24) {
            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button(action: onSignOut) {
                HStack(spacing: 10) {
                    if isSigningOut { ProgressView().tint(.white) }
                    Text(isSigningOut ? "Logging Out…" : "Log Out")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 12)
                .foregroundStyle(.white)
                .background(Color.appOrange, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 340)
            .disabled(isSigningOut)
            Text("Matter Forte · Version \(version)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Settings") {
    SettingsView()
}
