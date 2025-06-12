//
//  AccessibilityChecker.swift
//  StarkAccessibilityIOS
//

import XCTest

/// StarkAccessibilityIOS is a library for performing accessibility audits on iOS applications.
/// It provides a simple API for performing audits and reporting issues.
///
/// Basic usage:
/// ```swift
/// let checker = AccessibilityChecker(starkProjectToken: "your-stark-project-token")
/// try checker.auditScreen(application: app, scanName: "HomeScreen")
/// ```
///
/// For development/testing, the API endpoint can be configured using the `STARK_API_URL` environment variable.
///
/// Main class for checking accessibility issues in iOS applications
@available(iOS 17.0, macOS 14.0, *)
public class AccessibilityChecker {
    private let reportService: WebApiReportService
    
    /// Creates a new AccessibilityChecker with the WebApiReportService
    /// - Parameters:
    ///   - starkProjectToken: Authentication token for Stark project
    public init(starkProjectToken: String) {
        // Initialize with the web API report service
        self.reportService = WebApiReportService(
            starkProjectToken: starkProjectToken
        )
    }
    
    @MainActor
    public func auditScreen(application: XCUIApplication, scanName: String, failTestOnAccessibilityIssues: Bool = false) throws {
        var collectedScanResults: [StarkIssue] = []
        var scanResults: [XCUIAccessibilityAuditIssue] = []
        
        try application.performAccessibilityAudit { issue in
            scanResults.append(issue)
            let customIssue = StarkIssue(issue)
            collectedScanResults.append(customIssue)
            
            // Tell XCTest we'll handle the issue ourselves
            return true
        }
        
        self.reportService.send(results: collectedScanResults, scanName: scanName)
        
        if !collectedScanResults.isEmpty {            
            if failTestOnAccessibilityIssues {
                throw AccessibilityError.issuesFound(collectedScanResults)
            }
        }
    }
}
