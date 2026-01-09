import Foundation
import Combine
import UIKit

@MainActor
class KeyboardState: ObservableObject {
    /// Handler provided by the hosting controller to open URLs from an extension-safe context
    var openURLHandler: ((URL) -> Void)?

    @Published var dictationState: DictationUIState = .idle
    @Published var showDictationOverlay: Bool = false

    private let storage = SharedStorageService()
    private var pollingTimer: Timer?
    private var currentSessionId: UUID?
    private var textDocumentProxy: UITextDocumentProxy?

    enum DictationUIState {
        case idle                          // Normal keyboard
        case arming                        // "Opening app..."
        case listening                     // "Listening..." with stop button
        case processing                    // "Processing..." spinner
        case error(String)                // Error message
    }

    func configure(textDocumentProxy: UITextDocumentProxy, openURLHandler: ((URL) -> Void)? = nil) {
        self.textDocumentProxy = textDocumentProxy
        self.openURLHandler = openURLHandler
    }

    func startDictation() {
        // Create new session
        let sessionId = UUID()
        currentSessionId = sessionId

        let session = DictationSession(
            sessionId: sessionId,
            command: .armMic,
            timestamp: Date()
        )

        storage.saveCurrentSession(session)

        // Open host app via handler provided by the hosting controller (extension-safe)
        if let url = URL(string: "voicedictation://start") {
            openURLHandler?(url)
        }

        // Update UI
        dictationState = .arming
        showDictationOverlay = true

        // Start polling for response
        startPolling()
    }

    func stopDictation() {
        guard let sessionId = currentSessionId else { return }

        let session = DictationSession(
            sessionId: sessionId,
            command: .stopRecording,
            timestamp: Date()
        )

        storage.saveCurrentSession(session)
        dictationState = .processing
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkState()
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkState() async {
        guard let session = storage.loadCurrentSession(),
              session.sessionId == currentSessionId else { return }

        switch session.command {
        case .micReady:
            // User has returned from host app
            dictationState = .listening

            // Auto-send start recording command
            var recordingSession = session
            recordingSession.command = DictationCommand.startRecording
            storage.saveCurrentSession(recordingSession)

        case .processing:
            dictationState = .processing

        case .textReady:
            if let text = storage.loadCleanedText() {
                insertText(text)
            }
            resetState()

        case .error:
            dictationState = .error(session.error ?? "Unknown error")
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    self.resetState()
                }
            }

        default:
            break
        }
    }

    private func insertText(_ text: String) {
        textDocumentProxy?.insertText(text)
    }

    private func resetState() {
        stopPolling()
        currentSessionId = nil
        dictationState = .idle
        showDictationOverlay = false

        // Clear App Group data
        storage.clearCurrentSession()
    }
}
