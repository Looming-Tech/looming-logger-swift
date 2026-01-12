import Foundation

/// Handles HTTP transport for sending logs
/// Uses modern async/await URLSession API
actor LogTransport {
    private let baseUrl: String
    private let apiKey: String
    private let timeoutSeconds: Int
    private let urlSession: URLSession

    init(baseUrl: String, apiKey: String, timeoutSeconds: Int) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(timeoutSeconds)
        config.timeoutIntervalForResource = TimeInterval(timeoutSeconds)
        self.urlSession = URLSession(configuration: config)
    }

    /// Batch payload matching Flutter SDK format
    struct BatchPayload: Encodable {
        let logs: [LogEntry]
    }

    /// Result of send operation
    enum SendResult {
        case success
        case failure(Error)
    }

    /// Send a batch of logs to the server
    func send(_ entries: [LogEntry]) async -> SendResult {
        guard !entries.isEmpty else { return .success }

        guard let url = URL(string: "\(baseUrl)/api/logs/batch") else {
            return .failure(LogTransportError.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            let encoder = JSONEncoder()
            let payload = BatchPayload(logs: entries)
            request.httpBody = try encoder.encode(payload)

            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(LogTransportError.invalidResponse)
            }

            // Flutter SDK expects 201, but accept 2xx as success
            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(LogTransportError.httpError(statusCode: httpResponse.statusCode))
            }

            return .success

        } catch {
            return .failure(error)
        }
    }
}

/// Transport-related errors
public enum LogTransportError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
}
