import SwiftUI
import Foundation

private enum LegalStyle {
    static let orange = Color(red: 0.96, green: 0.39, blue: 0.14)
    static let textOrange = Color(red: 0.69, green: 0.23, blue: 0.05)
    static let buttonOrange = Color(red: 0.88, green: 0.35, blue: 0.08)
}

/// A single presentation keeps the registration model mounted underneath.
/// Both cross-links stay inside this presentation; either return action closes it.
struct LegalFlowView: View {
    @State private var page: LegalPage
    let onAgree: (LegalDocument) throws -> Void
    let onFinish: () -> Void

    init(startingPage: LegalPage,
         onAgree: @escaping (LegalDocument) throws -> Void,
         onFinish: @escaping () -> Void) {
        _page = State(initialValue: startingPage)
        self.onAgree = onAgree
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case .terms:
                    TermsOfServiceView(
                        document: LegalCopy.terms,
                        onAgree: { document in
                            try onAgree(document)
                            onFinish()
                        },
                        onReadPrivacy: { page = .privacy }
                    )
                case .privacy:
                    PrivacyPolicyView(
                        document: LegalCopy.privacy,
                        onBackToSignUp: onFinish,
                        onReadTerms: { page = .terms }
                    )
                }
            }
            .id(page)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onFinish) {
                        Label("Back to Sign Up", systemImage: "chevron.left")
                            .font(.subheadline)
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(LegalStyle.textOrange)
                }
            }
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}

struct TermsOfServiceView: View {
    let document: LegalDocument
    let onAgree: (LegalDocument) throws -> Void
    let onReadPrivacy: () -> Void
    @State private var saveError: String?
    @State private var isAccepting = false

    var body: some View {
        LegalDocumentPage(document: document) {
            if let saveError {
                Text(saveError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error. " + saveError)
            }
            Button {
                guard !isAccepting else { return }
                isAccepting = true
                saveError = nil
                do {
                    try onAgree(document)
                } catch {
                    isAccepting = false
                    saveError = "We couldn’t save your agreement. Please try again."
                }
            } label: {
                Text(isAccepting ? "Saving…" : "I Agree")
            }
            .buttonStyle(LegalPrimaryButtonStyle())
            .disabled(isAccepting)
            .accessibilityHint("Records agreement to version \(document.version) and returns to registration.")
            Button("Read our Privacy Policy", action: onReadPrivacy)
                .buttonStyle(LegalTextButtonStyle())
            Text("By continuing, you agree to these terms.")
                .font(.footnote)
                .foregroundStyle(LegalStyle.textOrange)
                .multilineTextAlignment(.center)
        }
    }
}

struct PrivacyPolicyView: View {
    let document: LegalDocument
    let onBackToSignUp: () -> Void
    let onReadTerms: () -> Void

    var body: some View {
        LegalDocumentPage(document: document) {
            Button("Back to Sign Up", action: onBackToSignUp)
                .buttonStyle(LegalPrimaryButtonStyle())
            Button("Read our Terms of Service", action: onReadTerms)
                .buttonStyle(LegalTextButtonStyle())
            Text("Review your choices before continuing.")
                .font(.footnote)
                .foregroundStyle(LegalStyle.textOrange)
                .multilineTextAlignment(.center)
        }
    }
}

private struct LegalDocumentPage<Actions: View>: View {
    let document: LegalDocument
    private let actions: () -> Actions

    init(document: LegalDocument, @ViewBuilder actions: @escaping () -> Actions) {
        self.document = document
        self.actions = actions
    }

    var body: some View {
        // Scroll the full page so larger Dynamic Type never traps the footer offscreen.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandLogo(scale: 0.58)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                Text(document.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(LegalStyle.orange)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Please read before creating your account.")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.32))
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String(format: "%02d  %@", section.id, section.title))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(LegalStyle.textOrange)
                                .accessibilityAddTraits(.isHeader)
                            Text(section.text)
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.30))
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 16)
                Text(document.isSampleCopy ? "Sample policy text · Wireframe" : "Version \(document.version)")
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.40))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                // Always expose the exact version that I Agree will record.
                if document.isSampleCopy {
                    Text("Version \(document.version)")
                        .font(.caption2)
                        .foregroundStyle(Color(white: 0.40))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }
                VStack(spacing: 8) { actions() }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 26)
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
        .tint(LegalStyle.orange)
    }
}

private struct LegalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LegalStyle.buttonOrange, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .padding(.horizontal, 26)
    }
}

private struct LegalTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(LegalStyle.textOrange)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct LegalViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LegalFlowView(startingPage: .terms, onAgree: { _ in }, onFinish: {})
                .previewDisplayName("Terms · 383 × 832")
            LegalFlowView(startingPage: .privacy, onAgree: { _ in }, onFinish: {})
                .previewDisplayName("Privacy · 383 × 832")
        }
        .previewLayout(.fixed(width: 383, height: 832))
    }
}
