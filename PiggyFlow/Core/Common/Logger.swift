import Foundation
import os

/// Structured logging, replacing scattered `print("❌ ...")` calls.
///
/// Uses `OSLog`, so messages are viewable in Console.app with subsystem/category filtering
/// and — unlike `print` — are compiled out of the hot path in release builds rather than
/// writing to stdout on customers' devices.
enum Log {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.piggyflowlabs.PiggyFlow"

    /// Log channels, one per concern.
    enum Category: String {
        case database = "Database"
        case network = "Network"
        case sync = "Sync"
        case auth = "Auth"
        case ui = "UI"
        case general = "General"

        fileprivate var logger: os.Logger {
            os.Logger(subsystem: Log.subsystem, category: rawValue)
        }
    }

    static func debug(_ message: String, category: Category = .general) {
        category.logger.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: Category = .general) {
        category.logger.info("\(message, privacy: .public)")
    }

    static func warning(_ message: String, category: Category = .general) {
        category.logger.warning("⚠️ \(message, privacy: .public)")
    }

    static func error(_ message: String, category: Category = .general) {
        category.logger.error("❌ \(message, privacy: .public)")
    }

    static func error(_ error: Error, context: String? = nil, category: Category = .general) {
        let prefix = context.map { "\($0): " } ?? ""
        category.logger.error("❌ \(prefix, privacy: .public)\(error.localizedDescription, privacy: .public)")
    }
}
