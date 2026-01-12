import Foundation

/// Represents a single log entry with all metadata
/// Codable for JSON serialization and persistence
public struct LogEntry: Codable, Sendable {
    public let appId: String
    public let level: LogLevel
    public let message: String
    public let timestamp: String
    public let metadata: [String: AnyCodable]?

    // Device info fields (flattened like Flutter SDK)
    public let appName: String
    public let appVersion: String
    public let buildNumber: String
    public let packageId: String
    public let deviceId: String
    public let platform: String
    public let osVersion: String
    public let model: String
    public let isPhysicalDevice: Bool
    public let deviceName: String
    public let localizedModel: String
    public let machine: String
    public let systemName: String

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case level, message, timestamp, metadata
        case appName = "app_name"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case packageId = "package_id"
        case deviceId = "device_id"
        case platform
        case osVersion = "os_version"
        case model
        case isPhysicalDevice = "is_physical_device"
        case deviceName = "device_name"
        case localizedModel = "localized_model"
        case machine
        case systemName = "system_name"
    }

    public init(
        appId: String,
        level: LogLevel,
        message: String,
        timestamp: String,
        metadata: [String: AnyCodable]?,
        appName: String,
        appVersion: String,
        buildNumber: String,
        packageId: String,
        deviceId: String,
        platform: String,
        osVersion: String,
        model: String,
        isPhysicalDevice: Bool,
        deviceName: String,
        localizedModel: String,
        machine: String,
        systemName: String
    ) {
        self.appId = appId
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.packageId = packageId
        self.deviceId = deviceId
        self.platform = platform
        self.osVersion = osVersion
        self.model = model
        self.isPhysicalDevice = isPhysicalDevice
        self.deviceName = deviceName
        self.localizedModel = localizedModel
        self.machine = machine
        self.systemName = systemName
    }
}

/// Type-erased Codable wrapper for metadata values
/// Supports String, Int, Double, Bool, Array, Dictionary
/// Note: @unchecked Sendable because we only store immutable value types
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
