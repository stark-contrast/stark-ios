//
//  AccessibilityError.swift
//  StarkAccessibilityIOS
//

import Foundation

@available(iOS 17.0, macOS 14.0, *)
public enum AccessibilityError: Error, CustomStringConvertible {
    /// Accessibility issues were found during the audit
    case issuesFound([StarkIssue])
    
    /// A human-readable description of the error
    public var description: String {
        switch self {
        case .issuesFound(let issues):
            return "Accessibility audit found \(issues.count) issue(s)"
        }
    }
    
    /// Additional details about the error
    public var errorDetails: String {
        switch self {
        case .issuesFound(let issues):
            return issues.map { "- \($0.detailedDescription)" }.joined(separator: "\n")
        }
    }
}
