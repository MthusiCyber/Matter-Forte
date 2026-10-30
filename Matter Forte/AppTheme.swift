import SwiftUI
import UIKit

extension Color {
    /// Readable orange text in both appearances while keeping the institute palette.
    static let appTextOrange = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark { return .systemOrange }
        return UIColor(red: 0.66, green: 0.23, blue: 0.09, alpha: 1)
    })
}
