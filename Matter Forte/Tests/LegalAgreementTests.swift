import XCTest
import Supabase
@testable import Matter_Forte

@MainActor
final class LegalAgreementTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testReceiptPersistsExactVersionAndTimestamp() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let draftID = UUID()
        let receipt = TermsAcceptance(draftID: draftID, termsVersion: LegalCopy.terms.version,
                                      acceptedAt: Date(timeIntervalSince1970: 1_800_000_000))
        try TermsAgreementStore(directory: directory).save(receipt)
        // Read through a new store instance, not the instance that wrote it.
        let stored = try TermsAgreementStore(directory: directory).receipt(for: draftID)
        XCTAssertEqual(stored, receipt)
    }

    func testAcceptanceDoesNotApplyToAnotherDraftOrVersion() {
        let draftID = UUID()
        let receipt = TermsAcceptance(draftID: draftID, termsVersion: "old-version", acceptedAt: Date())
        XCTAssertFalse(receipt.matches(document: LegalCopy.terms, draftID: draftID))
        let current = TermsAcceptance(draftID: draftID, termsVersion: LegalCopy.terms.version, acceptedAt: Date())
        XCTAssertFalse(current.matches(document: LegalCopy.terms, draftID: UUID()))
        XCTAssertTrue(current.matches(document: LegalCopy.terms, draftID: draftID))
    }

    func testAcceptingTermsPreservesRegistrationDetails() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = makeModel(directory: directory)
        model.switchMode()
        model.fullName = "Test Person"
        model.email = "test@example.com"
        model.password = "Example-password-123"
        model.confirmation = model.password
        model.role = .employer

        try model.acceptTerms(LegalCopy.terms)

        XCTAssertTrue(model.isRegistering)
        XCTAssertTrue(model.hasAcceptedCurrentTerms)
        XCTAssertEqual(model.fullName, "Test Person")
        XCTAssertEqual(model.email, "test@example.com")
        XCTAssertEqual(model.password, "Example-password-123")
        XCTAssertEqual(model.confirmation, "Example-password-123")
        XCTAssertEqual(model.role, .employer)
        let receipt = try XCTUnwrap(model.termsAcceptance)
        XCTAssertEqual(try TermsAgreementStore(directory: directory).receipt(for: receipt.draftID)?.termsVersion,
                       LegalCopy.terms.version)
    }

    func testFailedSaveDoesNotMarkTermsAccepted() throws {
        let path = temporaryDirectory()
        try Data("not a directory".utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let model = makeModel(directory: path)
        model.switchMode()
        XCTAssertThrowsError(try model.acceptTerms(LegalCopy.terms))
        XCTAssertFalse(model.hasAcceptedCurrentTerms)
        XCTAssertNil(model.termsAcceptance)
    }

    func testOldDocumentCannotBeAccepted() {
        let model = makeModel(directory: temporaryDirectory())
        let old = LegalDocument(version: "old", title: "Terms of Service", isSampleCopy: true, sections: [])
        XCTAssertThrowsError(try model.acceptTerms(old))
        XCTAssertFalse(model.hasAcceptedCurrentTerms)
    }

    func testSignupRequiresCurrentAgreement() async {
        let model = makeModel(directory: temporaryDirectory())
        model.switchMode()
        model.fullName = "Test Person"
        model.email = "test@example.com"
        model.password = "Example-password-123"
        model.confirmation = model.password
        await model.submit()
        XCTAssertNotNil(model.errors["terms"])
        XCTAssertFalse(model.isLoading)
    }

    func testCheckboxCanAcceptAndWithdrawAgreement() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = makeModel(directory: directory)
        model.switchMode()
        model.fullName = "Test Person"
        model.email = "test@example.com"
        model.password = "Example-password-123"
        model.confirmation = model.password
        XCTAssertFalse(model.hasAcceptedCurrentTerms)

        model.setTermsAccepted(true)
        XCTAssertTrue(model.hasAcceptedCurrentTerms)
        XCTAssertNotNil(model.termsAcceptance)

        model.setTermsAccepted(false)
        XCTAssertFalse(model.hasAcceptedCurrentTerms)
        XCTAssertNil(model.termsAcceptance)
        await model.submit()
        XCTAssertNotNil(model.errors["terms"])
        XCTAssertFalse(model.isLoading)
    }

    func testCheckboxRemainsUncheckedIfReceiptCannotBeSaved() throws {
        let path = temporaryDirectory()
        try Data("not a directory".utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let model = makeModel(directory: path)
        model.switchMode()
        model.setTermsAccepted(true)
        XCTAssertFalse(model.hasAcceptedCurrentTerms)
        XCTAssertNotNil(model.errors["terms"])
    }

    private func makeModel(directory: URL) -> AuthViewModel {
        AuthViewModel(
            client: SupabaseClient(supabaseURL: URL(string: "https://legal-tests.supabase.co")!,
                                   supabaseKey: "test-publishable-key"),
            agreementStore: TermsAgreementStore(directory: directory)
        )
    }
}
