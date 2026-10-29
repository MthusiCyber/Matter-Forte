import Foundation
import OSLog
import Combine
import Supabase
import Auth
#if canImport(_Helpers)
import _Helpers
#elseif canImport(Helpers)
import Helpers
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var fullName = ""
    @Published var confirmation = ""
    @Published var role: AccountRole = .admin
    @Published private(set) var isRegistering = false
    @Published private(set) var isLoading = false
    @Published private(set) var isRestoringSession = true
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var message: String?
    @Published private(set) var notice: String?
    @Published private(set) var authenticatedSession: Auth.Session?

    var profileName: String {
        authenticatedSession?.user.userMetadata["full_name"]?.stringValue ?? ""
    }

    @Published private(set) var termsAcceptance: TermsAcceptance?
    private let client: SupabaseClient
    private let agreementStore: TermsAgreementStore
    private var registrationDraftID = UUID()
    private var isObserving = false
    private let logger = Logger(subsystem: "MatterForte", category: "Authentication")

    init(client: SupabaseClient, agreementStore: TermsAgreementStore? = nil) {
        self.client = client
        self.agreementStore = agreementStore ?? TermsAgreementStore()
    }

    var hasAcceptedCurrentTerms: Bool {
        termsAcceptance?.matches(document: LegalCopy.terms, draftID: registrationDraftID) == true
    }

    /// Save first, then mark the draft accepted. A failed write leaves the legal page open.
    func acceptTerms(_ document: LegalDocument) throws {
        guard document.version == LegalCopy.terms.version else {
            throw TermsAgreementError.outdatedDocument
        }
        let receipt = TermsAcceptance(draftID: registrationDraftID,
                                      termsVersion: document.version, acceptedAt: Date())
        try agreementStore.save(receipt)
        termsAcceptance = receipt
        errors["terms"] = nil
    }

    func observeAuthChanges() async {
        guard !isObserving else { return }
        isObserving = true
        defer { isObserving = false }

        for await (event, session) in await client.auth.authStateChanges {
            guard !Task.isCancelled else { return }
            switch event {
            case .initialSession:
                if session != nil {
                    // Let the SDK retrieve and refresh the cached session if needed.
                    do {
                        authenticatedSession = try await client.auth.session
                    } catch {
                        authenticatedSession = nil
                        message = "We couldn’t restore your session. Check your connection or log in again."
                    }
                } else {
                    authenticatedSession = session
                }
                isRestoringSession = false
            case .signedIn, .tokenRefreshed, .userUpdated:
                authenticatedSession = session
                isRestoringSession = false
            case .signedOut:
                authenticatedSession = nil
                isRestoringSession = false
                password = ""
                confirmation = ""
            default:
                break
            }
        }
    }

    func switchMode() {
        guard !isLoading else { return }
        isRegistering.toggle()
        termsAcceptance = nil
        registrationDraftID = UUID()
        password = ""
        confirmation = ""
        errors = [:]
        message = nil
        notice = nil
    }

    func submit() async {
        // MainActor serializes entry. Set this before the first await.
        guard !isLoading else { return }
        message = nil
        notice = nil
        guard validate() else {
            message = ["fullName", "email", "password", "confirmation", "terms"]
                .compactMap { errors[$0] }
                .joined(separator: "\n")
            logger.info("Authentication stopped by form validation.")
            return
        }
        isLoading = true
        logger.info("Authentication request started. Registration: \(self.isRegistering)")
        defer {
            isLoading = false
            logger.info("Authentication request finished.")
        }

        do {
            if isRegistering {
                guard let agreement = termsAcceptance, hasAcceptedCurrentTerms else {
                    errors["terms"] = "Read the Terms of Service and select I Agree before creating your account."
                    return
                }
                let result = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: [
                        "full_name": .string(fullName.trimmingCharacters(in: .whitespacesAndNewlines)),
                        // User-editable preference only; never use this to authorize admin access.
                        "requested_role": .string(role.rawValue),
                        "terms_version": .string(agreement.termsVersion),
                        "terms_accepted_at": .string(ISO8601DateFormatter().string(from: agreement.acceptedAt)),
                        "terms_draft_id": .string(agreement.draftID.uuidString)
                    ],
                    redirectTo: SupabaseConfig.redirectURL
                )
                password = ""
                confirmation = ""
                termsAcceptance = nil
                registrationDraftID = UUID()
                if let session = result.session {
                    authenticatedSession = session
                } else {
                    isRegistering = false
                    notice = "Check your inbox and spam folder for a confirmation link. Confirm your email before logging in. If you already have an account, use Login instead."
                    logger.info("Signup response requires email confirmation; no session returned.")
                }
            } else {
                authenticatedSession = try await client.auth.signIn(email: email, password: password)
                password = ""
            }
        } catch is CancellationError {
            message = "The request was cancelled. Please try again."
        } catch {
            // Log diagnostic codes only, never credentials, tokens, or request bodies.
            if case let AuthError.api(api) = error {
                logger.error("Authentication rejected. HTTP status: \(api.code ?? 0)")
            } else if let network = error as? URLError {
                logger.error("Authentication network failure. Code: \(network.code.rawValue)")
            }
            message = friendlyMessage(for: error)
        }
    }

    func updateProfile(name: String, email: String) async throws -> String {
        let currentEmail = authenticatedSession?.user.email
        let changedEmail = email != currentEmail
        let user = try await client.auth.update(user: UserAttributes(
            email: changedEmail ? email : nil,
            data: ["full_name": .string(name)]
        ))
        authenticatedSession?.user = user
        return changedEmail
            ? "Your profile was saved. Check your inbox for any email-change confirmation instructions."
            : "Your profile was saved."
    }

    func updatePassword(_ password: String) async throws -> String {
        _ = try await client.auth.update(user: UserAttributes(password: password))
        return "Your password was changed."
    }

    func signOut() async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        notice = nil
        defer { isLoading = false }
        do {
            try await client.auth.signOut()
            authenticatedSession = nil
            isRegistering = false
            errors = [:]
            password = ""
            confirmation = ""
        } catch {
            message = friendlyMessage(for: error)
        }
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme?.lowercased() == "matterforte",
              url.host?.lowercased() == "auth", url.path == "/callback" else { return }
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            authenticatedSession = try await client.auth.session(from: url)
            notice = nil
            password = ""
            confirmation = ""
        } catch {
            message = "This confirmation link could not be opened. It may have expired or already been used. Try logging in if you already confirmed your email."
        }
    }

    private func validate() -> Bool {
        errors = [:]
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty {
            errors["email"] = "Enter your email address."
        } else if email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            errors["email"] = "Enter a valid email address, such as name@example.com."
        }
        // Never trim a password or silently change what the user entered.
        if password.isEmpty { errors["password"] = "Enter your password." }
        if isRegistering {
            if !hasAcceptedCurrentTerms {
                errors["terms"] = "Read the Terms of Service and select I Agree before creating your account."
            }
            if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors["fullName"] = "Enter your full name."
            }
            if confirmation.isEmpty { errors["confirmation"] = "Confirm your password." }
            else if confirmation != password { errors["confirmation"] = "Passwords do not match." }
        }
        return errors.isEmpty
    }

    private func friendlyMessage(for error: Error) -> String {
        if let network = error as? URLError {
            if network.code == .timedOut {
                return "The request timed out. Check your connection. If you were signing up, check your inbox before trying again—the account may already have been created."
            }
            if network.code == .cancelled { return "The request was cancelled. Please try again." }
            return "We couldn’t connect. Check your connection and try again. Your email is still here."
        }
        // Preserve actionable server feedback instead of treating every rejection as a connection failure.
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let text = description.lowercased()
        if text.contains("invalid login credentials") || text.contains("invalid credentials")
            || text.contains("invalid_credentials") {
            return "The email or password is incorrect. Please try again."
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return "Confirm your email using the link in your inbox, then log in."
        }
        if text.contains("already registered") || text.contains("already exists") {
            return "An account with this email already exists. Try logging in."
        }
        if text.contains("rate limit") || text.contains("too many")
            || text.contains("over_request_rate_limit") || text.contains("over_email_send_rate_limit") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if text.contains("password") && (text.contains("weak") || text.contains("at least")
            || text.contains("should contain") || text.contains("strength")) {
            return "Your password does not meet this app’s password requirements. Please choose a stronger password."
        }
        if text.contains("signup is disabled") || text.contains("signups not allowed") {
            return "Registration is not available right now. Please contact support."
        }

        if text.contains("email") && (text.contains("sending") || text.contains("send")
            || text.contains("not authorized") || text.contains("not allowed")) {
            return "The sign-in service could not send the confirmation email. Please contact the app team to check email delivery settings."
        }
        if text.contains("database") {
            return "The sign-in service could not save your account. Please contact the app team."
        }
        if case let AuthError.api(api) = error {
            if let code = api.code, code >= 500 {
                return "The sign-in service is temporarily unavailable. Please try again later."
            }
            if !description.isEmpty {
                return description
            }
        }
        return "We couldn’t complete your request. Please try again. Your email is still here."
    }
}

