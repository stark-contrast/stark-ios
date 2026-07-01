import Foundation
import XCTest

@testable import StarkAccessibilityIOS

// Verifies that `WebApiReportService.send` blocks until the POST completes (so a short-lived UI-test
// runner can't exit and drop the report), and that the wait is bounded by `requestTimeout`.
@available(iOS 17.0, macOS 14.0, *)
final class WebApiReportServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Point the service at a harmless URL; StubURLProtocol intercepts the request regardless of host.
        setenv(WebApiReportService.apiUrlEnvVarName, "https://stark.test/scans/results", 1)
    }

    override func tearDown() {
        unsetenv(WebApiReportService.apiUrlEnvVarName)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testSendBlocksUntilRequestCompletes() {
        // The stub responds after a short delay and records when it ran. After `send` returns the
        // response must already have been delivered — i.e. `send` waited rather than firing and forgetting.
        StubURLProtocol.responder = { request in
            Thread.sleep(forTimeInterval: 0.3)
            // The completion handler runs off the main thread (no deadlock with a @MainActor caller).
            XCTAssertFalse(Thread.isMainThread)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = WebApiReportService(
            starkProjectToken: "test-token", session: makeSession(), requestTimeoutSeconds: 10)

        service.send(results: [], scanName: "Test")

        XCTAssertTrue(
            StubURLProtocol.didComplete,
            "send returned before the request finished — it is not waiting for delivery")
    }

    func testSendReturnsWithinBoundWhenRequestHangs() {
        // The stub never responds; `send` must give up after ~requestTimeout instead of hanging forever.
        StubURLProtocol.responder = { _ in
            Thread.sleep(forTimeInterval: 5)  // longer than the timeout below
            throw CancellationError()
        }

        let service = WebApiReportService(
            starkProjectToken: "test-token", session: makeSession(), requestTimeoutSeconds: 0.5)

        let start = Date()
        service.send(results: [], scanName: "Test")
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 3, "send did not respect the bounded requestTimeout")
    }
}

/// Minimal URLProtocol stub: routes every request through `responder`, with a flag recording completion.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var didComplete = false

    static func reset() {
        responder = nil
        didComplete = false
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = StubURLProtocol.responder else {
            // Set the flag before notifying the client: URLSession can fire the task completion
            // handler (unblocking WebApiReportService.send) the moment it receives this callback.
            StubURLProtocol.didComplete = true
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try responder(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            StubURLProtocol.didComplete = true
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            StubURLProtocol.didComplete = true
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
