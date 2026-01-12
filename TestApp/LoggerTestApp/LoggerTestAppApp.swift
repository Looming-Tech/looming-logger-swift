import SwiftUI
import LoomingLogger

@main
struct LoggerTestAppApp: App {
    init() {
        Task {
            await LoomingLogger.initialize(
                baseUrl: "https://your-server.com",
                apiKey: "YOUR_API_KEY_HERE",
                appId: "your-app-id",
                config: LoggerConfig(
                    maxQueueSize: 100,
                    flushIntervalSeconds: 10,
                    httpTimeoutSeconds: 10,
                    printToConsole: true
                )
            )
            print("LoomingLogger initialized!")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
