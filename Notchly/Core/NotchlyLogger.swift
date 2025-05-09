//
//  NotchlyLogger.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import os.log
import Foundation

/// NotchlyLogger: A unified logging system for Notchly that wraps Apple's Logger API.
/// Provides consistent log formatting, categories, and log levels across the app.
struct NotchlyLogger {
    /// Log categories that organize Notchly's subsystems
    enum Category: String {
        case general
        case ui
        case mediaPlayer
        case calendar
        case permissions
        case animations
        case settings
        case lifecycle
    }
    
    /// The app's main subsystem identifier
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.apple.Notchly"
    
    /// Cache loggers to avoid recreating them
    private static var loggers: [Category: Logger] = [:]
    
    /// Get or create a logger for a specific category
    private static func logger(for category: Category) -> Logger {
        if let existingLogger = loggers[category] {
            return existingLogger
        }
        
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
    
    // MARK: - Logging Methods
    
    /// Log debug information (development only)
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        let metadata = extractMetadata(file: file, function: function, line: line).padding(toLength: 80, withPad: " ", startingAt: 0)
        logger.debug("[\(metadata)] \(message)")
    }
    
    /// Log general information
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        let metadata = extractMetadata(file: file, function: function, line: line).padding(toLength: 80, withPad: " ", startingAt: 0)
        logger.info("[\(metadata)] \(message)")
    }
    
    /// Log important events that don't represent errors
    static func notice(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        let metadata = extractMetadata(file: file, function: function, line: line).padding(toLength: 80, withPad: " ", startingAt: 0)
        logger.notice("[\(metadata)] \(message)")
    }
    
    /// Log errors that may be recoverable
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        let metadata = extractMetadata(file: file, function: function, line: line).padding(toLength: 80, withPad: " ", startingAt: 0)
        logger.error("[\(metadata)] \(message)")
    }
    
    /// Log critical system errors
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        let metadata = extractMetadata(file: file, function: function, line: line).padding(toLength: 80, withPad: " ", startingAt: 0)
        logger.critical("[\(metadata)] \(message)")
    }
    
    // MARK: - Helper Methods
    
    /// Extract readable metadata from file/function/line
    private static func extractMetadata(file: String, function: String, line: Int) -> String {
        let rawName = URL(fileURLWithPath: file).lastPathComponent
        let filename = rawName.replacingOccurrences(of: ".swift", with: "")
        let paddedFile = filename.padding(toLength: 22, withPad: " ", startingAt: 0)
        let paddedLine = String(format: "%3d", line)

        // Format timestamp with 12-hour clock and time zone
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        formatter.timeZone = TimeZone.current
        let timestamp = formatter.string(from: Date())

        return "\(timestamp) | \(paddedFile) | \(paddedLine) ▸ \(function)"
    }
}

// MARK: - Convenience Extensions

extension NotchlyLogger {
    /// Log media player related events
    static func media(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .mediaPlayer, file: file, function: function, line: line)
    }
    
    /// Log calendar related events
    static func calendar(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .calendar, file: file, function: function, line: line)
    }
    
    /// Log UI/animation related events
    static func ui(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .ui, file: file, function: function, line: line)
    }
    
    /// Log lifecycle events (app startup, shutdown, etc.)
    static func lifecycle(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        notice(message, category: .lifecycle, file: file, function: function, line: line)
    }
}
