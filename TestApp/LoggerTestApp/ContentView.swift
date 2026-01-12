import SwiftUI
import LoomingLogger

struct ContentView: View {
    @State private var logCount = 0
    @State private var statusMessage = "Ready to test"
    @State private var isInitialized = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status
                VStack {
                    Circle()
                        .fill(isInitialized ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(isInitialized ? "Logger Ready" : "Initializing...")
                        .font(.caption)
                }

                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                    .multilineTextAlignment(.center)

                Text("Logs sent: \(logCount)")
                    .font(.title2)
                    .bold()

                Divider()

                // Log buttons
                VStack(spacing: 12) {
                    LogButton(title: "Debug Log", icon: "ant", color: .gray) {
                        sendLog(level: .debug)
                    }

                    LogButton(title: "Info Log", icon: "info.circle", color: .blue) {
                        sendLog(level: .info)
                    }

                    LogButton(title: "Warning Log", icon: "exclamationmark.triangle", color: .orange) {
                        sendLog(level: .warn)
                    }

                    LogButton(title: "Error Log (Immediate)", icon: "xmark.octagon", color: .red) {
                        sendLog(level: .error)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Batch & Flush
                HStack(spacing: 16) {
                    Button(action: sendBatchLogs) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.title2)
                            Text("Batch (10)")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(12)
                    }

                    Button(action: manualFlush) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.title2)
                            Text("Flush")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Text("Check Xcode console for output")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Logger Test")
            .onAppear {
                // Check if initialized after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isInitialized = LoomingLogger.isInitialized
                }
            }
        }
    }

    enum LogLevelChoice {
        case debug, info, warn, error
    }

    func sendLog(level: LogLevelChoice) {
        let metadata: [String: Any] = [
            "testId": logCount,
            "timestamp": Date().timeIntervalSince1970,
            "device": "test-device"
        ]

        switch level {
        case .debug:
            LoomingLogger.debug("Test debug message #\(logCount)", metadata)
            statusMessage = "✓ Debug log #\(logCount)"
        case .info:
            LoomingLogger.info("Test info message #\(logCount)", metadata)
            statusMessage = "✓ Info log #\(logCount)"
        case .warn:
            LoomingLogger.warn("Test warning message #\(logCount)", metadata)
            statusMessage = "✓ Warning log #\(logCount)"
        case .error:
            LoomingLogger.error("Test error message #\(logCount)", metadata)
            statusMessage = "✓ Error log #\(logCount) (flushed)"
        }

        logCount += 1
    }

    func sendBatchLogs() {
        for i in 0..<10 {
            let metadata: [String: Any] = ["batch": true, "index": i, "total": 10]
            switch i % 4 {
            case 0: LoomingLogger.debug("Batch debug \(i)", metadata)
            case 1: LoomingLogger.info("Batch info \(i)", metadata)
            case 2: LoomingLogger.warn("Batch warn \(i)", metadata)
            default: LoomingLogger.error("Batch error \(i)", metadata)
            }
        }
        logCount += 10
        statusMessage = "✓ Sent batch of 10 logs"
    }

    func manualFlush() {
        statusMessage = "Flushing..."
        Task {
            await LoomingLogger.flush()
            await MainActor.run {
                statusMessage = "✓ Flush completed"
            }
        }
    }
}

struct LogButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
