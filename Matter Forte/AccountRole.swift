import Foundation

enum AccountRole: String, CaseIterable, Identifiable {
    case admin, employer, student
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
