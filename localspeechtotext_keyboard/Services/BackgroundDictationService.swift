//
//  BackgroundDictationService.swift
//  localspeechtotext_keyboard
//
//  Monitors App Group storage for commands from the keyboard extension
//  and executes recording/processing tasks in the host app.
//

import Foundation
import AVFoundation

@available(iOS 26.0, *)
@MainActor
class BackgroundDictationService: ObservableObject {
    private let storage = SharedStorageService()
    private let speechService = SpeechRecognitionService()
    private let cleanupService = TextCleanupService()

    private var pollingTimer: Timer?
    private var currentSessionId: UUID?
    private var transcriptionTask: Task<Void, Never>?

    @Published var isMonitoring = false

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Poll App Group every 0.5 seconds for commands
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForCommands()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        pollingTimer?.invalidate()
        pollingTimer = nil

        // Clean up active transcription if any
        transcriptionTask?.cancel()
        transcriptionTask = nil
        speechService.stopTranscription()
    }

    // MARK: - Command Processing

    private func checkForCommands() async {
        guard let session = storage.loadCurrentSession() else { return }

        // Ignore stale sessions or sessions from a different ID
        guard currentSessionId == nil || session.sessionId == currentSessionId else {
            return
        }

        switch session.command {
        case .armMic:
            await handleArmMic(session)
        case .startRecording:
            await handleStartRecording(session)
        case .stopRecording:
            await handleStopRecording(session)
        default:
            // Ignore other commands (micReady, processing, textReady, error)
            break
        }
    }

    // MARK: - Command Handlers

    private func handleArmMic(_ session: DictationSession) async {
        currentSessionId = session.sessionId

        // Request all required permissions
        let speechGranted = await speechService.requestPermissions()
        let micGranted = await speechService.requestMicrophonePermission()

        guard speechGranted && micGranted else {
            // Write error back to App Group
            var errorSession = session
            errorSession.command = .error
            errorSession.error = "Microphone or speech recognition permission denied"
            storage.saveCurrentSession(errorSession)
            return
        }

        // Write ready state back to App Group
        var updatedSession = session
        updatedSession.command = .micReady
        updatedSession.timestamp = Date()
        storage.saveCurrentSession(updatedSession)
    }

    private func handleStartRecording(_ session: DictationSession) async {
        guard currentSessionId == session.sessionId else { return }

        do {
            // Start transcription and consume results
            let transcriptStream = try await speechService.startTranscription()

            // Consume the stream and update shared storage with latest transcript
            transcriptionTask = Task {
                for await transcript in transcriptStream {
                    // Save raw transcript as it arrives for real-time feedback
                    storage.saveRawTranscript(transcript)
                }
            }
        } catch {
            // Write error back to App Group
            var errorSession = session
            errorSession.command = .error
            errorSession.error = "Failed to start recording: \(error.localizedDescription)"
            storage.saveCurrentSession(errorSession)
        }
    }

    private func handleStopRecording(_ session: DictationSession) async {
        guard currentSessionId == session.sessionId else { return }

        // Stop the transcription
        speechService.stopTranscription()

        // Cancel the transcription task
        transcriptionTask?.cancel()
        transcriptionTask = nil

        // Get the final transcript from the speech service
        let transcript = speechService.currentTranscript

        // Save raw transcript
        storage.saveRawTranscript(transcript)

        // Update state to processing
        var processingSession = session
        processingSession.command = .processing
        processingSession.timestamp = Date()
        storage.saveCurrentSession(processingSession)

        // Clean up text with LLM
        do {
            let cleanedText = try await cleanupService.cleanupText(transcript)

            // Write final result
            storage.saveCleanedText(cleanedText)

            var completeSession = session
            completeSession.command = .textReady
            completeSession.timestamp = Date()
            storage.saveCurrentSession(completeSession)

            currentSessionId = nil  // Reset for next session
        } catch {
            // Write error back to App Group
            var errorSession = session
            errorSession.command = .error
            errorSession.error = "Failed to clean up text: \(error.localizedDescription)"
            storage.saveCurrentSession(errorSession)

            currentSessionId = nil  // Reset for next session
        }
    }
}
