import Foundation

/// Log severity levels matching the Flutter SDK
public enum LogLevel: String, Codable, Sendable {
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"

    /// Priority for sorting/filtering (higher = more severe)
    public var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warn: return 2
        case .error: return 3
        }
    }
}
