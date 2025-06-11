# Stark Accessibility for iOS

A Swift package for performing accessibility audits in iOS applications.

[![Version](https://img.shields.io/badge/Version-0.0.1-blue.svg)](https://github.com/stark-contrast/stark-ios)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/stark-contrast/stark-ios.git", from: "0.0.1")
]
```

Or add it directly in Xcode:

1. File > Swift Packages > Add Package Dependency
2. Enter the repository URL: `https://github.com/stark-contrast/stark-ios.git`

## Usage

### Basic Usage

```swift
import XCTest
import StarkAccessibilityIOS

class MyUITests: XCTestCase {
    func testAccessibility() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to the screen you want to test
        app.tabBars.buttons["Home"].tap()

        // Create a checker and audit the screen
        let checker = AccessibilityChecker(starkProjectToken: "your-stark-project-token")
        try checker.auditScreen(application: app, scanName: "HomeScreen")
    }
}
```

### Suppressing Test Failures

If you want to collect and report accessibility issues but not fail the test:

```swift
try checker.auditScreen(
    application: app,
    scanName: "HomeScreen",
    failTestOnAccessibilityIssues: false
)
```

## License

This project is licensed under a custom license - see the [LICENSE](LICENSE) file included in this repository for details.
