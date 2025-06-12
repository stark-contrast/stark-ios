//
//  ReportService.swift
//  StarkAccessibilityIOS
//

import Foundation

/// Protocol for services that report accessibility issues
@available(iOS 17.0, macOS 14.0, *)
public protocol ReportService {
    /// Sends collected accessibility issues to the reporting system
    /// - Parameter results: The accessibility issues to report
    /// - Parameter scanName: Name of the accessibility scan
    func send(results: [StarkIssue], scanName: String)
}

/// A simple implementation that logs issues to the console
@available(iOS 17.0, macOS 14.0, *)
public class ConsoleReportService: ReportService {
    public init() {}
    
    public func send(results scanResults: [StarkIssue], scanName: String = "") {
            print("--- Found \(scanResults.count) Accessibility Issue(s) ---")
            for (index, issue) in scanResults.enumerated() {
                print("\nIssue #\(index + 1):")
                print("  Detailed Description: \(issue.detailedDescription)")
                print("  Compact Description: \(issue.compactDescription)")
                print("  Audit Type: \(issue.auditType)")
                
                // Details about the UI element with the issue
                print("  Element Description: \(issue.elementDescription ?? "N/A")")
                print("  Element Label: \(issue.elementLabel ?? "N/A")")
                print("  Element Identifier \(issue.elementIdentifier ?? "N/A")") // Value can be any, so describe it
                print("---")
            }
            print("\n--- End of Accessibility Issues ---")    }
}

/// A struct representing the report payload format
@available(iOS 17.0, macOS 14.0, *)
private struct ReportPayload: Encodable {
    let version: String
    let data: ReportData
    
    struct ReportData: Encodable {
        let name: String
        let results: [StarkIssue]
    }
}

/// A ReportService implementation that sends accessibility issues to a web API using a PUT request
@available(iOS 17.0, macOS 14.0, *)
public class WebApiReportService: ReportService {
    private let url: URL
    private let session: URLSession
    private let starkProjectToken: String
    
    /// The production API endpoint URL
    private static let productionApiUrl = "https://app.getstark.co/api/automated-scan/result/ios"
    
    /// The environment variable name used to override the API URL
    internal static let apiUrlEnvVarName = "STARK_API_URL"
    
    /// Determines the base URL to use based on environment settings
    private static func determineBaseURL() -> URL {
        // Check if the environment variable is set
        if let overrideUrl = ProcessInfo.processInfo.environment[apiUrlEnvVarName],
           let url = URL(string: overrideUrl) {
            return url
        }
        
        // Fall back to the production URL
        guard let url = URL(string: productionApiUrl) else {
            fatalError("Invalid URL format for production API URL")
        }
        return url
    }
    
    /// Initialize a WebApiReportService
    /// - Parameters:
    ///   - starkProjectToken: Authentication token for Stark project
    ///   - session: URLSession to use for network requests (useful for testing)
    public init(starkProjectToken: String,
                session: URLSession = .shared) {
        self.url = WebApiReportService.determineBaseURL()
        self.starkProjectToken = starkProjectToken
        self.session = session
    }
    
    /// Sends accessibility issues to the web API using a PUT request
    /// - Parameter results: The accessibility issues to report
    /// - Parameter scanName: Name of the accessibility scan
    public func send(results: [StarkIssue], scanName: String = "Accessibility Scan") {
        do {
            // Create the payload using our structured format
            let reportPayload = ReportPayload(
                version: LibraryVersion.current,
                data: ReportPayload.ReportData(
                    name: scanName,
                    results: results
                )
            )
            
            // Create a JSON encoder with pretty printing
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // Encode the payload
            let jsonData = try encoder.encode(reportPayload)
            
            // Create PUT request
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(starkProjectToken)", forHTTPHeaderField: "Authorization")
            request.setValue(LibraryVersion.userAgent, forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData
                        
            // Send the request
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending accessibility report: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if statusCode >= 200 && statusCode < 300 {
                        print("Successfully sent \(results.count) accessibility issues (Status code: \(statusCode))")
                    } else {
                        print("Failed to send accessibility report (Status code: \(statusCode))")
                    }
                }
            }
            
            task.resume()
        } catch {
            print("Error encoding accessibility report: \(error.localizedDescription)")
        }
    }
}
