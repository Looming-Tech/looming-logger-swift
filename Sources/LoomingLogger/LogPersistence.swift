import Foundation

/// Handles offline persistence using UserDefaults
/// Matches Flutter SDK's SharedPreferences approach
actor LogPersistence {
    private let storageKey = "looming_logger_queue"
    private nonisolated(unsafe) let userDefaults: UserDefaults

    init() {
        self.userDefaults = UserDefaults.standard
    }

    /// Save log entries to UserDefaults
    func save(_ entries: [LogEntry]) {
        guard !entries.isEmpty else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("[LoomingLogger] Failed to save queue: \(error)")
            #endif
        }
    }

    /// Load log entries from UserDefaults and clear storage
    func loadAndClear() -> [LogEntry] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        userDefaults.removeObject(forKey: storageKey)

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([LogEntry].self, from: data)
        } catch {
            #if DEBUG
            print("[LoomingLogger] Failed to load queue: \(error)")
            #endif
            return []
        }
    }

    /// Clear persisted data
    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
