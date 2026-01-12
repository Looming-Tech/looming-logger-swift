import Foundation

/// Thread-safe log queue using Swift actor
/// Handles FIFO queue management with size limits
actor LogQueue {
    private var queue: [LogEntry] = []
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    /// Add a log entry, dropping oldest if over capacity
    func enqueue(_ entry: LogEntry) {
        queue.append(entry)

        // FIFO: drop oldest entries if over capacity
        if queue.count > maxSize {
            let overflow = queue.count - maxSize
            queue.removeFirst(overflow)
        }
    }

    /// Get all entries and clear the queue atomically
    func dequeueAll() -> [LogEntry] {
        let entries = queue
        queue.removeAll()
        return entries
    }

    /// Re-add entries to front of queue (for retry on failure)
    func requeue(_ entries: [LogEntry]) {
        // Insert at beginning, then trim to maxSize from front if needed
        queue.insert(contentsOf: entries, at: 0)
        if queue.count > maxSize {
            queue = Array(queue.suffix(maxSize))
        }
    }

    /// Current queue count
    var count: Int {
        queue.count
    }

    /// Check if queue is empty
    var isEmpty: Bool {
        queue.isEmpty
    }

    /// Get all entries without clearing (for persistence)
    func peekAll() -> [LogEntry] {
        queue
    }

    /// Replace entire queue (for loading from persistence)
    func setQueue(_ entries: [LogEntry]) {
        queue = Array(entries.suffix(maxSize))
    }
}
