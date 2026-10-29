import Foundation

nonisolated enum AppLaunchStage {
    case splash, welcome, authentication
}

nonisolated enum SignedInDestination: Equatable {
    case administrator, student, employer, pendingAdministrator, account

    static func resolve(serverRole: String?, requestedRole: String?) -> Self {
        switch serverRole {
        case "admin": return .administrator
        case "student": return .student
        case "employer": return .employer
        case "pending_admin", "admin_rejected": return .pendingAdministrator
        default: return requestedRole == "admin" ? .pendingAdministrator : .account
        }
    }
}
