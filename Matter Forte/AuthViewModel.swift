import Foundation
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

    private let client: SupabaseClient
    private var isObserving = false

    init(client: SupabaseClient) {
        self.client = client
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
        guard validate() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if isRegistering {
                let result = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: [
                        "full_name": .string(fullName.trimmingCharacters(in: .whitespacesAndNewlines)),
                        // User-editable preference only; never use this to authorize admin access.
                        "requested_role": .string(role.rawValue)
                    ],
                    redirectTo: SupabaseConfig.redirectURL
                )
                password = ""
                confirmation = ""
                if let session = result.session {
                    authenticatedSession = session
                } else {
                    isRegistering = false
                    notice = "Check your email for a confirmation link. After confirming, return here to log in. If you already have an account, try logging in."
                }
            } else {
                authenticatedSession = try await client.auth.signIn(email: email, password: password)
                password = ""
            }
        } catch is CancellationError {
            // Keep the form available if a caller cancels the operation.
        } catch {
            message = friendlyMessage(for: error)
        }
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
            if network.code == .cancelled { return "The request was cancelled. Please try again." }
            return "We couldn’t connect. Check your connection and try again. Your email is still here."
        }
        // SDK versions expose different AuthError properties. Use LocalizedError
        // as a compatibility fallback without depending on a local AuthError type.
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

        return "We couldn’t complete your request. Check your connection and try again. Your email is still here."
    }
}
