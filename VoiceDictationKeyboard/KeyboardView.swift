import SwiftUI

struct KeyboardView: View {
    let onMicTap: () -> Void
    let onInsertTap: () -> Void
    let getText: () -> String
    let getStatus: () -> DictationStatus

    @State private var currentText: String = ""
    @State private var currentStatus: DictationStatus = .idle
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Text preview
            if !currentText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(currentText)
                        .font(.body)
                        .lineLimit(2)
                        .padding(.horizontal)
                }
                .frame(height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Button row
            HStack(spacing: 20) {
                // Microphone button
                Button(action: onMicTap) {
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.blue))

                        Text("Record")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }

                // Insert button
                if currentStatus == .ready && !currentText.isEmpty {
                    Button(action: onInsertTap) {
                        VStack(spacing: 4) {
                            Image(systemName: "text.insert")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.green))

                            Text("Insert")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.bottom, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Status

    private var statusColor: Color {
        switch currentStatus {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .processing:
            return .orange
        case .ready:
            return .green
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch currentStatus {
        case .idle:
            return "Tap mic to record"
        case .recording:
            return "Recording in app..."
        case .processing:
            return "Processing..."
        case .ready:
            return "Ready to insert"
        case .error:
            return "Error occurred"
        }
    }

    // MARK: - Polling

    private func startPolling() {
        // Poll for updates every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateState()
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updateState() {
        currentText = getText()
        currentStatus = getStatus()
    }
}

#Preview {
    KeyboardView(
        onMicTap: {},
        onInsertTap: {},
        getText: { "Sample dictated text" },
        getStatus: { .ready }
    )
    .frame(height: 280)
}
