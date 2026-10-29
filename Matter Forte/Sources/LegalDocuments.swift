import Foundation

enum LegalPage: String, Identifiable, Hashable {
    case terms, privacy
    var id: String { rawValue }
}

struct LegalSection: Identifiable, Sendable {
    let id: Int
    let title: String
    let text: String
}

struct LegalDocument: Sendable {
    let version: String
    let title: String
    let isSampleCopy: Bool
    let sections: [LegalSection]
}

/// Wireframe copy, not approved release content. Replace the text and bump the
/// version together whenever an approved document changes.
enum LegalCopy {
    static let terms = LegalDocument(
        version: "terms-wireframe-2026-10-29",
        title: "Terms of Service",
        isSampleCopy: true,
        sections: [
            LegalSection(id: 1, title: "Acceptance of terms", text: "Review and accept these terms before using Matter Forte."),
            LegalSection(id: 2, title: "Your account", text: "Provide accurate details and keep your password and account access secure."),
            LegalSection(id: 3, title: "Acceptable use", text: "Use the service lawfully. Do not upload harmful content or misuse other accounts."),
            LegalSection(id: 4, title: "Content and ownership", text: "Respect intellectual property and only share content you have permission to use."),
            LegalSection(id: 5, title: "Service availability", text: "Features and availability may change. Service interruptions may occur."),
            LegalSection(id: 6, title: "Account termination", text: "Accounts may be suspended or closed for breaches of these terms."),
            LegalSection(id: 7, title: "Updates and contact", text: "Review notices about changes to these terms. Use the support channel for questions.")
        ]
    )

    static let privacy = LegalDocument(
        version: "privacy-wireframe-2026-10-29",
        title: "Privacy Policy",
        isSampleCopy: true,
        sections: [
            LegalSection(id: 1, title: "Information we collect", text: "Account details and information you provide while using Matter Forte."),
            LegalSection(id: 2, title: "How information is used", text: "To operate your account, provide the service, improve features, and respond to requests."),
            LegalSection(id: 3, title: "Information sharing", text: "Service providers may process information to help operate and support the service."),
            LegalSection(id: 4, title: "Data security", text: "Safeguards help protect your information from unauthorised access and misuse."),
            LegalSection(id: 5, title: "Data retention", text: "The full policy explains how long information is kept and when it is deleted."),
            LegalSection(id: 6, title: "Your privacy choices", text: "Request access, correction, or deletion of your personal information through support."),
            LegalSection(id: 7, title: "Updates and contact", text: "Review privacy notices for policy changes. Contact support with privacy questions.")
        ]
    )
}
