import XCTest

@testable import StarkAccessibilityIOS

// Unit tests for the Foundation-only fingerprint core (Fingerprint.swift). Mirrors the SwiftLint/React
// fingerprint coverage. These compile only into the test target and never ship in a consuming app.
@available(iOS 17.0, macOS 14.0, *)
final class FingerprintTests: XCTestCase {

    // MARK: - fnv1a

    func testFnv1aEmptyStringIsOffsetBasis() {
        // FNV-1a of the empty string is just the offset basis (0x811c9dc5).
        XCTAssertEqual(fnv1a(""), "811c9dc5")
    }

    func testFnv1aIsDeterministicAnd8CharHex() {
        let a = fnv1a("stark-accessibility")
        let b = fnv1a("stark-accessibility")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 8)
        XCTAssertNil(a.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdef").inverted))
    }

    func testFnv1aDistinctInputsDiffer() {
        XCTAssertNotEqual(fnv1a("foo"), fnv1a("bar"))
    }

    // MARK: - normalizeText

    func testNormalizeTextCollapsesWhitespaceAndTrims() {
        XCTAssertEqual(normalizeText("  Sign\n   In\t  "), "Sign In")
        XCTAssertEqual(normalizeText(nil), "")
        XCTAssertEqual(normalizeText("   "), "")
    }

    // MARK: - generateDefaultFingerprint

    func testDefaultFingerprintIsStable() {
        let a = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Sign In",
            compactDescription: "Contrast ratio too low")
        let b = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Sign In",
            compactDescription: "Contrast ratio too low")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 8)
    }

    func testDefaultFingerprintVariesByComponent() {
        let base = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Sign In",
            compactDescription: "x")
        XCTAssertNotEqual(
            base,
            generateDefaultFingerprint(
                auditType: "dynamicType", elementIdentifier: "loginButton", elementLabel: "Sign In",
                compactDescription: "x"))
        XCTAssertNotEqual(
            base,
            generateDefaultFingerprint(
                auditType: "contrast", elementIdentifier: "signupButton", elementLabel: "Sign In",
                compactDescription: "x"))
        XCTAssertNotEqual(
            base,
            generateDefaultFingerprint(
                auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Log In",
                compactDescription: "x"))
    }

    func testDefaultFingerprintIgnoresCompactDescriptionWhenLocatorsPresent() {
        // With an identifier and/or label present, the (potentially drifting) compactDescription is not
        // hashed — so a changed description does not change the fingerprint.
        let a = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Sign In",
            compactDescription: "ratio 4.23:1")
        let b = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: "loginButton", elementLabel: "Sign In",
            compactDescription: "ratio 4.51:1")
        XCTAssertEqual(a, b)
    }

    func testDefaultFingerprintIgnoresLabelWhitespace() {
        let a = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: nil, elementLabel: "Sign In",
            compactDescription: "x")
        let b = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: nil, elementLabel: "  Sign\n  In  ",
            compactDescription: "x")
        XCTAssertEqual(a, b)
    }

    func testDefaultFingerprintFallsBackToCompactDescription() {
        // No identifier and no label → compactDescription is the only distinguishing content.
        let a = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: nil, elementLabel: nil,
            compactDescription: "Contrast ratio too low")
        let b = generateDefaultFingerprint(
            auditType: "contrast", elementIdentifier: nil, elementLabel: nil,
            compactDescription: "Text is clipped")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.count, 8)
    }

    // MARK: - FingerprintBuilder order-insensitivity

    func testBuilderIsOrderInsensitive() {
        let fields = FingerprintBuilder.Fields(
            auditType: "contrast", elementIdentifier: "id", elementLabel: "label",
            compactDescription: "desc")
        let a = FingerprintBuilder(fields)
            .includeAuditType().includeElementIdentifier().includeElementLabel().build()
        let b = FingerprintBuilder(fields)
            .includeElementLabel().includeAuditType().includeElementIdentifier().build()
        XCTAssertEqual(a, b)
    }
}
