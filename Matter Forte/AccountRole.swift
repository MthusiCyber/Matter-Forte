import Foundation

enum AccountRole: String, CaseIterable, Identifiable {
    case admin, employer
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
