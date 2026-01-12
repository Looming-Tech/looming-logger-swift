import Foundation

/// Configuration options for the logger
/// Mirrors Flutter SDK's LoggerConfig with identical defaults
public struct LoggerConfig: Sendable {
    /// Maximum number of logs to queue before oldest are dropped (FIFO)
    public let maxQueueSize: Int

    /// Interval in seconds between automatic flushes
    public let flushIntervalSeconds: Int

    /// HTTP timeout in seconds for sending logs
    public let httpTimeoutSeconds: Int

    /// Whether to print logs to console in DEBUG builds
    public let printToConsole: Bool

    public init(
        maxQueueSize: Int = 100,
        flushIntervalSeconds: Int = 30,
        httpTimeoutSeconds: Int = 10,
        printToConsole: Bool = true
    ) {
        self.maxQueueSize = maxQueueSize
        self.flushIntervalSeconds = flushIntervalSeconds
        self.httpTimeoutSeconds = httpTimeoutSeconds
        self.printToConsole = printToConsole
    }
}
