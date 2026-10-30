import Foundation

/// Shared rules for field feedback and submission eligibility.
enum SignUpValidation {
    static func fullName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func email(_ value: String) -> Bool {
        // Require a local part and a dotted domain with valid DNS labels.
        let pattern = #"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"#
        guard value.count <= 254,
              !value.contains(where: { $0.isWhitespace }),
              value.range(of: pattern, options: .regularExpression) != nil,
              let local = value.split(separator: "@").first,
              local.count <= 64 else { return false }
        return !local.hasPrefix(".") && !local.hasSuffix(".") && !local.contains("..")
    }

    static func password(_ value: String) -> Bool {
        value.count >= 8
            && value.rangeOfCharacter(from: .lowercaseLetters) != nil
            && value.rangeOfCharacter(from: .uppercaseLetters) != nil
            && value.rangeOfCharacter(from: .decimalDigits) != nil
            && value.rangeOfCharacter(from: .punctuationCharacters.union(.symbols)) != nil
    }

    static func confirmation(_ value: String, password: String) -> Bool {
        self.password(password) && value == password
    }
}
