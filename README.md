# Looming Logger - Swift SDK

A remote logging SDK for iOS applications that sends logs to a self-hosted Loki backend with automatic batching, offline persistence, and comprehensive device information collection.

## Features

- Automatic device information collection (platform, OS version, model, etc.)
- Batched log sending with configurable flush interval
- Offline persistence using UserDefaults
- Immediate flush for error-level logs
- Thread-safe concurrent access using Swift actors
- Zero external dependencies (Foundation/UIKit only)

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/looming-logger-swift.git", from: "1.0.0")
]
```

Or in Xcode:
1. Go to File > Add Package Dependencies
2. Enter the repository URL
3. Select the version and add to your target

## Usage

### Initialization

Initialize the logger once at app startup, before any logging calls:

```swift
import LoomingLogger

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Task {
            await LoomingLogger.initialize(
                baseUrl: "https://logs.example.com",
                apiKey: "your-api-key",
                appId: "my-ios-app"
            )
        }

        return true
    }
}
```

### Logging

```swift
// Basic logging at different levels
LoomingLogger.debug("User opened settings")
LoomingLogger.info("User logged in")
LoomingLogger.warn("API response slow")
LoomingLogger.error("Payment failed")

// With metadata
LoomingLogger.info("User action", ["userId": "123", "action": "purchase"])
LoomingLogger.error("Network error", ["endpoint": "/api/users", "statusCode": 500])
```

### Configuration

Customize the logger behavior with `LoggerConfig`:

```swift
let config = LoggerConfig(
    maxQueueSize: 100,        // Max logs to queue before dropping oldest
    flushIntervalSeconds: 30, // Auto-flush interval
    httpTimeoutSeconds: 10,   // HTTP request timeout
    printToConsole: true      // Print to console in DEBUG builds
)

await LoomingLogger.initialize(
    baseUrl: "https://logs.example.com",
    apiKey: "your-api-key",
    appId: "my-ios-app",
    config: config
)
```

### Manual Flush

Force an immediate flush of all pending logs:

```swift
await LoomingLogger.flush()
```

### Cleanup

Call on app termination to flush remaining logs and persist any unsent:

```swift
func applicationWillTerminate(_ application: UIApplication) {
    Task {
        await LoomingLogger.dispose()
    }
}
```

## Log Entry Format

Each log entry includes:

| Field | Description |
|-------|-------------|
| `app_id` | Application identifier |
| `level` | Log level (debug, info, warn, error) |
| `message` | Log message |
| `timestamp` | ISO8601 UTC timestamp |
| `metadata` | Optional custom metadata |
| `app_name` | Application name |
| `app_version` | App version (e.g., "2.0.0") |
| `build_number` | Build number |
| `package_id` | Bundle identifier |
| `device_id` | Unique device identifier |
| `platform` | "ios" |
| `os_version` | iOS version |
| `model` | Device model |
| `is_physical_device` | true/false |
| `device_name` | User-set device name |
| `localized_model` | Localized model name |
| `machine` | Machine identifier (e.g., "iPhone14,2") |
| `system_name` | System name (e.g., "iOS") |

## API Reference

### LoomingLogger

| Method | Description |
|--------|-------------|
| `initialize(baseUrl:apiKey:appId:config:)` | Initialize the logger (async) |
| `debug(_:_:)` | Log debug message |
| `info(_:_:)` | Log info message |
| `warn(_:_:)` | Log warning message |
| `error(_:_:)` | Log error message (immediate flush) |
| `flush()` | Manually flush pending logs (async) |
| `dispose()` | Clean up and persist remaining logs (async) |
| `isInitialized` | Check if logger is initialized |

### LoggerConfig

| Property | Default | Description |
|----------|---------|-------------|
| `maxQueueSize` | 100 | Maximum logs to queue |
| `flushIntervalSeconds` | 30 | Auto-flush interval |
| `httpTimeoutSeconds` | 10 | HTTP timeout |
| `printToConsole` | true | Console output in DEBUG |

## Thread Safety

The SDK uses Swift actors for thread-safe concurrent access:

- `LogQueue` - manages the in-memory queue
- `LogPersistence` - handles UserDefaults access
- `LogTransport` - manages URLSession operations
- `DeviceInfoCollector` - caches device info

## Offline Support

When network requests fail:
1. Logs are re-queued for retry
2. Queue is persisted to UserDefaults
3. On next app launch, persisted logs are recovered
4. Automatic retry on next flush interval

## License

MIT License
