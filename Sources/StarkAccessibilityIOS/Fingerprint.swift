//
//  Fingerprint.swift
//  StarkAccessibilityIOS
//

import Foundation

// Issue fingerprinting for the iOS instrumented-test accessibility scanner.
//
// Mirrors the SwiftLint (`stark-accessibility-rules`), React (`stark-accessibility-react`), and
// Flutter (`stark-accessibility-flutter`) fingerprint implementations: an FNV-1a hash fed by an
// order-insensitive, labeled-part builder. The hash gives the Stark backend a stable identity per
// finding so the same issue can be deduped/tracked across runs.
//
// Unlike SwiftLint — where rules and reporter run in separate processes and overrides travel through a
// JSONL side-channel file — everything here runs in one process and the audits come straight from
// Apple's `performAccessibilityAudit`, which we don't control. There is no override path: every issue's
// fingerprint is the computed default.
//
// We also have far less to hash than a linter. An `XCUIAccessibilityAuditIssue` carries no file path,
// line, or source snippet, so the default fingerprint is built from the issue's audit type plus the
// most stable element locators available (accessibility identifier and label), falling back to the
// compact description when the element exposes neither.

private let fnvOffsetBasis: UInt32 = 0x811c_9dc5
private let fnvPrime: UInt32 = 0x0100_0193

/// FNV-1a hash → 8-char zero-padded hex string. Matches the SwiftLint/React/Flutter implementations.
///
/// Hashes over UTF-16 code units to match JS `charCodeAt` / Dart `codeUnitAt`, and uses overflowing
/// 32-bit unsigned arithmetic to match JS `Math.imul(...) >>> 0` / Dart `(hash * prime) & 0xFFFFFFFF`.
func fnv1a(_ str: String) -> String {
    var hash = fnvOffsetBasis
    for unit in str.utf16 {
        hash ^= UInt32(unit)
        hash = hash &* fnvPrime
    }
    return String(format: "%08x", hash)
}

/// Collapse runs of whitespace and trim, so cosmetic formatting changes don't alter fingerprints.
func normalizeText(_ str: String?) -> String {
    guard let str else { return "" }
    let collapsed = str.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Part-composition + hashing engine.
///
/// Order-insensitive: each `include*()` pushes a part labeled with its component (the label keeps
/// distinct components from colliding once sorted), and `build()` sorts the parts before hashing.
@available(iOS 17.0, macOS 14.0, *)
struct FingerprintBuilder {
    struct Fields {
        var auditType: String = ""
        var elementIdentifier: String = ""
        var elementLabel: String = ""
        var compactDescription: String = ""

        init(
            auditType: String = "",
            elementIdentifier: String = "",
            elementLabel: String = "",
            compactDescription: String = ""
        ) {
            self.auditType = auditType
            self.elementIdentifier = elementIdentifier
            self.elementLabel = elementLabel
            self.compactDescription = compactDescription
        }
    }

    private let fields: Fields
    private var parts: [String] = []

    init(_ fields: Fields) {
        self.fields = fields
    }

    func includeAuditType() -> FingerprintBuilder { appending("rule:\(fields.auditType)") }
    func includeElementIdentifier() -> FingerprintBuilder { appending("id:\(fields.elementIdentifier)") }
    func includeElementLabel() -> FingerprintBuilder { appending("label:\(normalizeText(fields.elementLabel))") }
    func includeCompactDescription() -> FingerprintBuilder { appending("desc:\(normalizeText(fields.compactDescription))") }

    func build() -> String {
        fnv1a(parts.sorted().joined(separator: "|"))
    }

    private func appending(_ part: String) -> FingerprintBuilder {
        var copy = self
        copy.parts.append(part)
        return copy
    }
}

/// Default fingerprint computed from an audit issue. Structure/content-based (no coordinates or frame)
/// so it survives layout changes and device differences.
///
/// Always includes the audit type. Adds the accessibility identifier and/or label when present — these
/// are the most stable locators we have. When the element exposes neither, falls back to the compact
/// description so every issue still gets a fingerprint (weaker identity: distinct elements with the same
/// audit type and description will share a fingerprint).
@available(iOS 17.0, macOS 14.0, *)
func generateDefaultFingerprint(
    auditType: String,
    elementIdentifier: String?,
    elementLabel: String?,
    compactDescription: String
) -> String {
    var builder = FingerprintBuilder(
        .init(
            auditType: auditType,
            elementIdentifier: elementIdentifier ?? "",
            elementLabel: elementLabel ?? "",
            compactDescription: compactDescription)
    )
    .includeAuditType()

    if elementIdentifier != nil {
        builder = builder.includeElementIdentifier()
    }
    if elementLabel != nil {
        builder = builder.includeElementLabel()
    }
    if elementIdentifier == nil && elementLabel == nil {
        builder = builder.includeCompactDescription()
    }

    return builder.build()
}
