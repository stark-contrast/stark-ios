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
            print("  Element Identifier \(issue.elementIdentifier ?? "N/A")")  // Value can be any, so describe it
            print("---")
        }
        print("\n--- End of Accessibility Issues ---")
    }
}

/// A struct representing the report payload format
@available(iOS 17.0, macOS 14.0, *)
private struct ReportPayload: Encodable {
    let version: String
    let data: ReportData

    struct ReportData: Encodable {
        let name: String
        let results: [StarkIssue]
        let type: String
    }
}

/// A ReportService implementation that sends accessibility issues to a web API using a POST request
@available(iOS 17.0, macOS 14.0, *)
public class WebApiReportService: ReportService {
    private let url: URL
    private let session: URLSession
    private let starkProjectToken: String

    /// How long `send` blocks waiting for the request to complete before giving up.
    private let requestTimeoutSeconds: TimeInterval

    /// The production API endpoint URL
    private static let productionApiUrl = "https://results.getstark.co/scans/results"

    /// The environment variable name used to override the API URL
    internal static let apiUrlEnvVarName = "STARK_API_URL"

    /// Determines the base URL to use based on environment settings
    private static func determineBaseURL() -> URL {
        // Check if the environment variable is set
        if let overrideUrl = ProcessInfo.processInfo.environment[apiUrlEnvVarName],
            let url = URL(string: overrideUrl)
        {
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
    ///   - requestTimeoutSeconds: Maximum time `send` blocks waiting for the request to finish. Bounded so a
    ///     slow/hung network can never wedge a test; lower it in tests if needed.
    public init(
        starkProjectToken: String,
        session: URLSession = .shared,
        requestTimeoutSeconds: TimeInterval = 30
    ) {
        self.url = WebApiReportService.determineBaseURL()
        self.starkProjectToken = starkProjectToken
        self.session = session
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    /// Sends accessibility issues to the web API using a POST request.
    ///
    /// Blocks until the request completes (or `requestTimeoutSeconds` elapses) so a short-lived UI-test runner
    /// process can't exit and drop the report before it's delivered.
    /// - Parameter results: The accessibility issues to report
    /// - Parameter scanName: Name of the accessibility scan
    public func send(results: [StarkIssue], scanName: String = "Accessibility Scan") {
        do {
            // Create the payload using our structured format
            let reportPayload = ReportPayload(
                version: LibraryVersion.current,
                data: ReportPayload.ReportData(
                    name: scanName,
                    results: results,
                    type: "instrumentation"
                )
            )

            // Create a JSON encoder with pretty printing
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            // Encode the payload
            let jsonData = try encoder.encode(reportPayload)

            // Create POST request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(starkProjectToken)", forHTTPHeaderField: "Authorization")
            request.setValue(LibraryVersion.userAgent, forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData

            // Block until the request finishes so a short-lived test runner can't exit and drop the
            // report. The completion handler runs on URLSession's own (non-main) queue, so signaling it
            // releases the waiting caller without deadlocking even when `send` is reached on @MainActor.
            let semaphore = DispatchSemaphore(value: 0)

            // Send the request
            let task = session.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }

                if let error = error {
                    print("Error sending accessibility report: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if statusCode >= 200 && statusCode < 300 {
                        print(
                            "Successfully sent \(results.count) accessibility issues (Status code: \(statusCode))"
                        )
                    } else {
                        print("Failed to send accessibility report (Status code: \(statusCode))")
                    }
                }
            }

            task.resume()

            // Bounded wait: if the network hangs we stop waiting and return rather than wedge the test.
            if semaphore.wait(timeout: .now() + requestTimeoutSeconds) == .timedOut {
                task.cancel()
                print("Timed out waiting for accessibility report to send")
            }
        } catch {
            print("Error encoding accessibility report: \(error.localizedDescription)")
        }
    }
}
