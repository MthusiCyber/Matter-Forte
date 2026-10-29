import Foundation

@main
struct CheckNavigation {
    static func main() {
        precondition(SignedInDestination.resolve(serverRole: "admin", requestedRole: "student") == .administrator)
        precondition(SignedInDestination.resolve(serverRole: "student", requestedRole: "admin") == .student)
        precondition(SignedInDestination.resolve(serverRole: "employer", requestedRole: "admin") == .employer)
        precondition(SignedInDestination.resolve(serverRole: "pending_admin", requestedRole: nil) == .pendingAdministrator)
        precondition(SignedInDestination.resolve(serverRole: "admin_rejected", requestedRole: "admin") == .pendingAdministrator)
        precondition(SignedInDestination.resolve(serverRole: nil, requestedRole: "admin") == .pendingAdministrator)
        precondition(SignedInDestination.resolve(serverRole: nil, requestedRole: "student") == .account)
        precondition(SignedInDestination.resolve(serverRole: nil, requestedRole: nil) == .account)
        print("All role-routing checks passed; requested roles cannot grant administrator access.")
    }
}
