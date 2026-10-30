import Foundation

struct TermsAcceptance: Codable, Equatable, Sendable {
    let draftID: UUID
    let termsVersion: String
    let acceptedAt: Date

    func matches(document: LegalDocument, draftID: UUID) -> Bool {
        self.draftID == draftID && termsVersion == document.version
    }
}

/// Local receipts contain only a draft ID, terms version, and timestamp.
/// No registration passwords or other form fields are written to disk.
struct TermsAgreementStore {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("MatterForteLegal", isDirectory: true)
    }

    func save(_ receipt: TermsAcceptance) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // One atomic receipt per registration draft. Re-agreement replaces only that draft's receipt.
        let data = try encoder.encode(receipt)
        try data.write(to: fileURL(for: receipt.draftID), options: .atomic)
    }

    func receipt(for draftID: UUID) throws -> TermsAcceptance? {
        let file = fileURL(for: draftID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TermsAcceptance.self, from: Data(contentsOf: file))
    }

    private func fileURL(for draftID: UUID) -> URL {
        directory.appendingPathComponent(draftID.uuidString).appendingPathExtension("json")
    }
}

enum TermsAgreementError: LocalizedError {
    case outdatedDocument
    var errorDescription: String? { "The terms have changed. Please review the current version." }
}
