//
//  LibraryVersion.swift
//  StarkAccessibilityIOS
//

import Foundation

/// Contains version information for the StarkAccessibilityIOS library
@available(iOS 17.0, macOS 14.0, *)
public struct LibraryVersion {
    /// The current semantic version of the library
    public static let current = "0.0.1"
    
    /// Build number, incremented with each build
    public static let build = "1"
    
    /// Full version string combining version and build
    public static let fullVersion: String = "\(current)+\(build)"
    
    /// User-Agent string for network requests
    public static let userAgent: String = "StarkAccessibilityIOS/\(current)"
}
