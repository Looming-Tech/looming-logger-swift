import Foundation

/// Remote logging service for sending logs to a self-hosted Loki backend
///
/// Features:
/// - Automatic device info collection (platform, OS version, model, etc.)
/// - Batched log sending with configurable flush interval
/// - Offline persistence using UserDefaults
/// - Immediate flush for error-level logs
/// - Thread-safe concurrent access using Swift actors
///
/// Usage:
/// ```swift
/// await LoomingLogger.initialize(
///     baseUrl: "https://logs.example.com",
///     apiKey: "your-api-key",
///     appId: "your-app-id"
/// )
///
/// LoomingLogger.info("User logged in", ["userId": "123"])
/// LoomingLogger.error("Payment failed", ["orderId": "456"])
/// ```
public final class LoomingLogger: @unchecked Sendable {

    // MARK: - Singleton

    private static var _shared: LoomingLogger?
    private static let lock = NSLock()

    /// Access the shared logger instance (nil if not initialized)
    public static var shared: LoomingLogger? {
        lock.withLock { _shared }
    }

    /// Check if the logger has been initialized
    public static var isInitialized: Bool {
        shared != nil
    }

    // Set the shared instance atomically
    private static func setShared(_ instance: LoomingLogger?) -> LoomingLogger? {
        lock.withLock {
            let previous = _shared
            _shared = instance
            return previous
        }
    }

    // Check and set shared instance atomically (returns true if set successfully)
    private static func setSharedIfNil(_ instance: LoomingLogger) -> Bool {
        lock.withLock {
            if _shared == nil {
                _shared = instance
                return true
            }
            return false
        }
    }

    // MARK: - Instance Properties

    private let appId: String
    private let config: LoggerConfig
    private let queue: LogQueue
    private let persistence: LogPersistence
    private let transport: LogTransport
    private let deviceInfoCollector: DeviceInfoCollector

    private var deviceInfo: DeviceInfoCollector.DeviceInfo?
    private var flushTask: Task<Void, Never>?
    private var isDisposed = false
    private let instanceLock = NSLock()

    // MARK: - Initialization

    private init(
        baseUrl: String,
        apiKey: String,
        appId: String,
        config: LoggerConfig
    ) {
        self.appId = appId
        self.config = config
        self.queue = LogQueue(maxSize: config.maxQueueSize)
        self.persistence = LogPersistence()
        self.transport = LogTransport(
            baseUrl: baseUrl,
            apiKey: apiKey,
            timeoutSeconds: config.httpTimeoutSeconds
        )
        self.deviceInfoCollector = DeviceInfoCollector()
    }

    /// Initialize the logger. Call once at app startup.
    ///
    /// - Parameters:
    ///   - baseUrl: The base URL of your logging server (e.g., "https://logs.example.com")
    ///   - apiKey: API key for authentication
    ///   - appId: Identifier for this app (e.g., "my-app-ios")
    ///   - config: Optional configuration options
    @MainActor
    public static func initialize(
        baseUrl: String,
        apiKey: String,
        appId: String,
        config: LoggerConfig = LoggerConfig()
    ) async {
        let instance = LoomingLogger(
            baseUrl: baseUrl,
            apiKey: apiKey,
            appId: appId,
            config: config
        )

        // Prevent re-initialization
        guard setSharedIfNil(instance) else {
            #if DEBUG
            print("[LoomingLogger] Already initialized. Call dispose() first to reinitialize.")
            #endif
            return
        }

        await instance.performInitialization()
    }

    private func performInitialization() async {
        // Collect device info
        deviceInfo = await deviceInfoCollector.collect()

        // Load any persisted logs from previous session
        let persistedLogs = await persistence.loadAndClear()
        if !persistedLogs.isEmpty {
            await queue.setQueue(persistedLogs)
            #if DEBUG
            if config.printToConsole {
                print("[LoomingLogger] Recovered \(persistedLogs.count) logs from previous session")
            }
            #endif
        }

        // Start auto-flush timer
        startFlushTimer()

        #if DEBUG
        if config.printToConsole {
            print("[LoomingLogger] Initialized successfully")
        }
        #endif
    }

    // MARK: - Public Logging Methods (Static)

    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    public static func debug(_ message: String, _ metadata: [String: Any]? = nil) {
        shared?.log(level: .debug, message: message, metadata: metadata)
    }

    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    public static func info(_ message: String, _ metadata: [String: Any]? = nil) {
        shared?.log(level: .info, message: message, metadata: metadata)
    }

    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    public static func warn(_ message: String, _ metadata: [String: Any]? = nil) {
        shared?.log(level: .warn, message: message, metadata: metadata)
    }

    /// Log an error message (triggers immediate flush)
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    public static func error(_ message: String, _ metadata: [String: Any]? = nil) {
        shared?.log(level: .error, message: message, metadata: metadata)
    }

    // MARK: - Instance Logging

    private func log(level: LogLevel, message: String, metadata: [String: Any]?) {
        let (disposed, info) = instanceLock.withLock { (isDisposed, deviceInfo) }

        guard !disposed, let deviceInfo = info else { return }

        // Print to console in debug mode
        #if DEBUG
        if config.printToConsole {
            let metaString = metadata.map { " \($0)" } ?? ""
            print("[\(level.rawValue.uppercased())] \(message)\(metaString)")
        }
        #endif

        // Create ISO8601 timestamp
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())

        // Create log entry
        let entry = LogEntry(
            appId: appId,
            level: level,
            message: message,
            timestamp: timestamp,
            metadata: metadata?.mapValues { AnyCodable($0) },
            appName: deviceInfo.appName,
            appVersion: deviceInfo.appVersion,
            buildNumber: deviceInfo.buildNumber,
            packageId: deviceInfo.packageId,
            deviceId: deviceInfo.deviceId,
            platform: deviceInfo.platform,
            osVersion: deviceInfo.osVersion,
            model: deviceInfo.model,
            isPhysicalDevice: deviceInfo.isPhysicalDevice,
            deviceName: deviceInfo.deviceName,
            localizedModel: deviceInfo.localizedModel,
            machine: deviceInfo.machine,
            systemName: deviceInfo.systemName
        )

        // Enqueue asynchronously
        Task {
            await queue.enqueue(entry)

            // Immediate flush for errors
            if level == .error {
                await performFlush()
            }
        }
    }

    // MARK: - Flush Management

    private func startFlushTimer() {
        flushTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                let disposed = self.instanceLock.withLock { self.isDisposed }
                if disposed { break }

                try? await Task.sleep(nanoseconds: UInt64(self.config.flushIntervalSeconds) * 1_000_000_000)

                let stillActive = self.instanceLock.withLock { !self.isDisposed }
                if stillActive && !Task.isCancelled {
                    await self.performFlush()
                }
            }
        }
    }

    private func performFlush() async {
        let entries = await queue.dequeueAll()
        guard !entries.isEmpty else { return }

        #if DEBUG
        if config.printToConsole {
            print("[LoomingLogger] Flushing \(entries.count) logs...")
        }
        #endif

        let result = await transport.send(entries)

        switch result {
        case .success:
            #if DEBUG
            if config.printToConsole {
                print("[LoomingLogger] Successfully sent \(entries.count) logs")
            }
            #endif
        case .failure(let error):
            #if DEBUG
            if config.printToConsole {
                print("[LoomingLogger] Failed to send logs: \(error). Re-queueing...")
            }
            #endif
            // Re-queue on failure and persist
            await queue.requeue(entries)
            await persistence.save(await queue.peekAll())
        }
    }

    // MARK: - Public Flush & Dispose

    /// Manually flush all pending logs
    public static func flush() async {
        await shared?.performFlush()
    }

    /// Flush all pending logs and stop the timer
    /// Call on app termination if needed
    public static func dispose() async {
        let instance = setShared(nil)
        await instance?.performDispose()
    }

    private func performDispose() async {
        instanceLock.withLock { isDisposed = true }

        flushTask?.cancel()
        flushTask = nil

        // Final flush attempt
        await performFlush()

        // Persist any remaining logs
        let remaining = await queue.peekAll()
        if !remaining.isEmpty {
            await persistence.save(remaining)
            #if DEBUG
            if config.printToConsole {
                print("[LoomingLogger] Persisted \(remaining.count) remaining logs")
            }
            #endif
        }

        #if DEBUG
        if config.printToConsole {
            print("[LoomingLogger] Disposed")
        }
        #endif
    }
}
