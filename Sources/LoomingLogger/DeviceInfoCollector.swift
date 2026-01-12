import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects iOS device information
/// Matches the iOS-specific fields from Flutter's device_info_plus
actor DeviceInfoCollector {

    struct DeviceInfo: Sendable {
        let appName: String
        let appVersion: String
        let buildNumber: String
        let packageId: String
        let deviceId: String
        let platform: String
        let osVersion: String
        let model: String
        let isPhysicalDevice: Bool
        let deviceName: String
        let localizedModel: String
        let machine: String
        let systemName: String
    }

    private var cachedInfo: DeviceInfo?

    /// Collect device info (cached after first call)
    func collect() async -> DeviceInfo {
        if let cached = cachedInfo {
            return cached
        }

        let info = await collectDeviceInfo()
        cachedInfo = info
        return info
    }

    @MainActor
    private func collectDeviceInfo() -> DeviceInfo {
        let bundle = Bundle.main

        // App info from Bundle (equivalent to package_info_plus)
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Unknown"
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let packageId = bundle.bundleIdentifier ?? "unknown"

        // Machine identifier (e.g., "iPhone14,2")
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }

        // Check if physical device or simulator
        #if targetEnvironment(simulator)
        let isPhysicalDevice = false
        #else
        let isPhysicalDevice = true
        #endif

        #if canImport(UIKit)
        let device = UIDevice.current

        // Device ID (identifierForVendor equivalent)
        let deviceId = device.identifierForVendor?.uuidString ?? "unknown"

        return DeviceInfo(
            appName: appName,
            appVersion: appVersion,
            buildNumber: buildNumber,
            packageId: packageId,
            deviceId: deviceId,
            platform: "ios",
            osVersion: device.systemVersion,
            model: device.model,
            isPhysicalDevice: isPhysicalDevice,
            deviceName: device.name,
            localizedModel: device.localizedModel,
            machine: machine,
            systemName: device.systemName
        )
        #else
        // Fallback for non-UIKit platforms (macOS, etc.)
        return DeviceInfo(
            appName: appName,
            appVersion: appVersion,
            buildNumber: buildNumber,
            packageId: packageId,
            deviceId: UUID().uuidString,
            platform: "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            model: "unknown",
            isPhysicalDevice: isPhysicalDevice,
            deviceName: Host.current().localizedName ?? "unknown",
            localizedModel: "unknown",
            machine: machine,
            systemName: "unknown"
        )
        #endif
    }
}
