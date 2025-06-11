//
//  StarkIssue.swift
//  StarkAccessibilityIOS
//

import XCTest

/// Represents an accessibility issue found during testing
@available(iOS 17.0, macOS 14.0, *)
public struct StarkIssue: Encodable, Sendable {
    public let compactDescription: String
    public let detailedDescription: String
    public let elementDescription: String?
    public let auditType: String
    public let elementIdentifier: String?
    public let elementLabel: String?
    
    /// Creates a new StarkIssue from an XCUIAccessibilityAuditIssue
    /// - Parameter issue: The XCUIAccessibilityAuditIssue to convert
    @MainActor
    public init(_ issue: XCUIAccessibilityAuditIssue) {
        self.compactDescription = issue.compactDescription
        self.detailedDescription = issue.detailedDescription
        self.auditType = StarkIssue.getAuditTypeString(issue.auditType)
        
        // Capture these values in the main actor context
        if let element = issue.element {
            self.elementDescription = element.description
            self.elementIdentifier = element.identifier.isEmpty ? nil : element.identifier
            self.elementLabel = element.label.isEmpty ? nil : element.label
        } else {
            self.elementDescription = nil
            self.elementIdentifier = nil
            self.elementLabel = nil
        }
    }
        
    public static func getAuditTypeString(_ auditType: XCUIAccessibilityAuditType) -> String {
        var descriptions: [String] = []
        
        if auditType.contains(.contrast) { descriptions.append("contrast") }
        if auditType.contains(.elementDetection) { descriptions.append("elementDetection") }
        if auditType.contains(.hitRegion) { descriptions.append("hitRegion") }
        if auditType.contains(.sufficientElementDescription) { descriptions.append("sufficientElementDescription") }
        
        // Platform-specific audit types
#if os(iOS) || os(tvOS) || os(watchOS)
        if auditType.contains(.dynamicType) { descriptions.append("dynamicType") }
        if auditType.contains(.textClipped) { descriptions.append("textClipped") }
        if auditType.contains(.trait) { descriptions.append("trait") }
#endif
        
#if os(macOS)
        if auditType.contains(.action) { descriptions.append("action") }
        if auditType.contains(.parentChild) { descriptions.append("parentChild") }
#endif
        
        // Handle cases where no specific type is found, or it's an empty set
        if descriptions.isEmpty {
            return "unknownType"
        } else {
            // Join multiple descriptions if it's a combination of audit types
            return descriptions.joined(separator: ", ")
        }
    }
    
}
