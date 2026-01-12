import XCTest
@testable import LoomingLogger

final class LoomingLoggerTests: XCTestCase {

    // MARK: - LogLevel Tests

    func testLogLevelPriority() {
        XCTAssertLessThan(LogLevel.debug.priority, LogLevel.info.priority)
        XCTAssertLessThan(LogLevel.info.priority, LogLevel.warn.priority)
        XCTAssertLessThan(LogLevel.warn.priority, LogLevel.error.priority)
    }

    func testLogLevelRawValues() {
        XCTAssertEqual(LogLevel.debug.rawValue, "debug")
        XCTAssertEqual(LogLevel.info.rawValue, "info")
        XCTAssertEqual(LogLevel.warn.rawValue, "warn")
        XCTAssertEqual(LogLevel.error.rawValue, "error")
    }

    // MARK: - LoggerConfig Tests

    func testLoggerConfigDefaults() {
        let config = LoggerConfig()

        XCTAssertEqual(config.maxQueueSize, 100)
        XCTAssertEqual(config.flushIntervalSeconds, 30)
        XCTAssertEqual(config.httpTimeoutSeconds, 10)
        XCTAssertTrue(config.printToConsole)
    }

    func testLoggerConfigCustomValues() {
        let config = LoggerConfig(
            maxQueueSize: 50,
            flushIntervalSeconds: 60,
            httpTimeoutSeconds: 20,
            printToConsole: false
        )

        XCTAssertEqual(config.maxQueueSize, 50)
        XCTAssertEqual(config.flushIntervalSeconds, 60)
        XCTAssertEqual(config.httpTimeoutSeconds, 20)
        XCTAssertFalse(config.printToConsole)
    }

    // MARK: - LogQueue Tests

    func testLogQueueEnqueue() async {
        let queue = LogQueue(maxSize: 10)
        let entry = createTestLogEntry()

        await queue.enqueue(entry)

        let count = await queue.count
        XCTAssertEqual(count, 1)
    }

    func testLogQueueDequeueAll() async {
        let queue = LogQueue(maxSize: 10)
        let entry1 = createTestLogEntry(message: "Test 1")
        let entry2 = createTestLogEntry(message: "Test 2")

        await queue.enqueue(entry1)
        await queue.enqueue(entry2)

        let entries = await queue.dequeueAll()

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].message, "Test 1")
        XCTAssertEqual(entries[1].message, "Test 2")

        let isEmpty = await queue.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func testLogQueueMaxSize() async {
        let queue = LogQueue(maxSize: 3)

        for i in 1...5 {
            await queue.enqueue(createTestLogEntry(message: "Message \(i)"))
        }

        let entries = await queue.dequeueAll()

        // Should only have last 3 entries (FIFO, oldest dropped)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].message, "Message 3")
        XCTAssertEqual(entries[1].message, "Message 4")
        XCTAssertEqual(entries[2].message, "Message 5")
    }

    func testLogQueueRequeue() async {
        let queue = LogQueue(maxSize: 10)
        let entry1 = createTestLogEntry(message: "New 1")
        let entry2 = createTestLogEntry(message: "New 2")

        await queue.enqueue(entry1)

        let requeued = [createTestLogEntry(message: "Requeued")]
        await queue.requeue(requeued)

        let entries = await queue.dequeueAll()

        // Requeued entries should be at front
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].message, "Requeued")
        XCTAssertEqual(entries[1].message, "New 1")
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableString() throws {
        let value = AnyCodable("test")
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)

        XCTAssertEqual(json, "\"test\"")
    }

    func testAnyCodableInt() throws {
        let value = AnyCodable(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)

        XCTAssertEqual(json, "42")
    }

    func testAnyCodableBool() throws {
        let value = AnyCodable(true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)

        XCTAssertEqual(json, "true")
    }

    func testAnyCodableDictionary() throws {
        let value = AnyCodable(["key": "value"])
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)

        XCTAssertEqual(json, "{\"key\":\"value\"}")
    }

    // MARK: - LogEntry Tests

    func testLogEntryCodingKeys() throws {
        let entry = createTestLogEntry()
        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify snake_case keys
        XCTAssertNotNil(json["app_id"])
        XCTAssertNotNil(json["app_name"])
        XCTAssertNotNil(json["app_version"])
        XCTAssertNotNil(json["build_number"])
        XCTAssertNotNil(json["package_id"])
        XCTAssertNotNil(json["device_id"])
        XCTAssertNotNil(json["os_version"])
        XCTAssertNotNil(json["is_physical_device"])
        XCTAssertNotNil(json["device_name"])
        XCTAssertNotNil(json["localized_model"])
        XCTAssertNotNil(json["system_name"])
    }

    // MARK: - Helper Methods

    private func createTestLogEntry(message: String = "Test message") -> LogEntry {
        return LogEntry(
            appId: "test-app",
            level: .info,
            message: message,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            metadata: nil,
            appName: "TestApp",
            appVersion: "1.0.0",
            buildNumber: "1",
            packageId: "com.test.app",
            deviceId: "test-device-id",
            platform: "ios",
            osVersion: "17.0",
            model: "iPhone",
            isPhysicalDevice: false,
            deviceName: "Test iPhone",
            localizedModel: "iPhone",
            machine: "iPhone14,2",
            systemName: "iOS"
        )
    }
}
