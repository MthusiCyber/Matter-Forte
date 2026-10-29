import Foundation

nonisolated enum AppLaunchStage {
    case splash, welcome, authentication
}

nonisolated enum SignedInDestination: Equatable {
    case administrator, employer, pendingAdministrator, restrictedAccount, account

    static func resolve(serverRole: String?, requestedRole: String?) -> Self {
        switch serverRole {
        case "admin": return .administrator
        case "student": return .restrictedAccount
        case "employer": return .employer
        case "pending_admin", "admin_rejected": return .pendingAdministrator
        default:
            if requestedRole == "student" { return .restrictedAccount }
            return requestedRole == "admin" ? .pendingAdministrator : .account
        }
    }
}
