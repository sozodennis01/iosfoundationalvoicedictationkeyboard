import SwiftUI
import Speech

@available(iOS 26.0, *)
struct DictationView: View {
    @Binding var shouldAutoStart: Bool

    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var cleanupService = TextCleanupService()
    @State private var storageService = SharedStorageService()
    @State private var liveActivityService = LiveActivityService()

    @State private var currentTranscript = ""
    @State private var cleanedText = ""
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var startRecordingObserver: DarwinNotificationObservation?
    @State private var stopRecordingObserver: DarwinNotificationObservation?
    @State private var cancelRecordingObserver: DarwinNotificationObservation?

    var body: some View {
        VStack(spacing: 30) {
            // Microphone button
            microphoneButton
            
            // Status indicator
            statusView

            // Transcript display
            transcriptView

            Spacer()
        }
        .padding()
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .onChange(of: shouldAutoStart) { _, newValue in
            if newValue && !isRecording && !isProcessing {
                // Auto-start recording when triggered from keyboard
                startRecording()
                shouldAutoStart = false  // Reset flag
            }
        }
        .onAppear {
            setupNotificationObservers()

            // Mark host app as ready for keyboard extensions (WisprFlow pattern)
            SharedState.setHostAppReady(true)

            // Initialize audio session for immediate recording (keeps it "warm")
            Task {
                do {
                    try await speechService.initializeAudioSession()
                    print("Audio session initialized successfully")
                } catch {
                    print("Failed to initialize audio session: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setupNotificationObservers() {
        // Listen for start recording command from keyboard
        startRecordingObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.startRecordingNotification) {
            Task { @MainActor in
                if !isRecording && !isProcessing {
                    startRecording()
                } else {
                    print("Host app received startRecording command but already recording/processing")
                }
            }
        }

        // Listen for stop recording command from keyboard
        stopRecordingObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.stopRecordingNotification) {
            Task { @MainActor in
                if isRecording {
                    stopRecording()
                }
            }
        }

        // Listen for cancel recording command from keyboard
        cancelRecordingObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.cancelRecordingNotification) {
            Task { @MainActor in
                if isRecording {
                    cancelRecording()
                }
            }
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .opacity(isRecording ? 1 : 0.5)
                .scaleEffect(isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        if isRecording {
            return .red
        } else if isProcessing {
            return .orange
        } else if showSuccess {
            return .green
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if isRecording {
            return "Recording..."
        } else if isProcessing {
            return "Processing..."
        } else if showSuccess {
            return "Text copied to keyboard"
        } else {
            return "Ready"
        }
    }

    // MARK: - Microphone Button

    private var microphoneButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 120, height: 120)
                    .shadow(radius: 10)

                Image(systemName: "mic.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
        }
        .disabled(isProcessing)
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isRecording)
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !currentTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Raw Transcript:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(currentTranscript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            if !cleanedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cleaned Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(cleanedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Text copied to keyboard!")
                .font(.headline)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSuccess = false
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                // Request permissions if needed
                var hasPermission = speechService.hasPermission
                if !hasPermission {
                    hasPermission = await speechService.requestPermissions()
                }
                guard hasPermission else {
                    errorMessage = "Speech recognition permission is required"
                    return
                }

                isRecording = true
                currentTranscript = ""
                cleanedText = ""

                // Start Live Activity for Dynamic Island
                try await liveActivityService.startActivity()

                // Post Darwin notification to keyboard extension
                DarwinNotificationCenter.shared.post(name: AppConstants.recordingStartedNotification)

                // Start recording to file (no real-time transcription)
                try await speechService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
                isRecording = false
                await liveActivityService.endActivity()
            }
        }
    }

    private func stopRecording() {
        Task {
            do {
                isProcessing = true

                // Update Live Activity status
                await liveActivityService.updateStatus("Processing...", isRecording: false)

                // Stop recording and get the complete transcript
                let transcript = try await speechService.stopRecordingAndTranscribe()

                await MainActor.run {
                    isRecording = false
                    currentTranscript = transcript
                }

                // Process the transcript
                await processTranscript()
            } catch {
                errorMessage = error.localizedDescription
                isRecording = false
                await liveActivityService.endActivity()
                isProcessing = false
            }
        }
    }

    private func processTranscript() {
        guard !currentTranscript.isEmpty else {
            Task {
                await liveActivityService.endActivity()
            }
            return
        }

        Task {
            isProcessing = true

            do {
                // Clean up the text
                cleanedText = try await cleanupService.cleanupText(currentTranscript)

                // Save to App Group
                let state = DictationState(
                    rawText: currentTranscript,
                    cleanedText: cleanedText,
                    status: .ready,
                    timestamp: Date()
                )

                storageService.saveState(state)
                storageService.saveText(cleanedText)
                
                // Post Darwin notification to keyboard extension
                DarwinNotificationCenter.shared.post(name: "group.sozodennis.voicedictation.textReady")

                // End Live Activity
                await liveActivityService.endActivity()

                // Show success
                withAnimation {
                    showSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                await liveActivityService.endActivity()
            }

            isProcessing = false
        }
    }

    private func cancelRecording() {
        isRecording = false
        speechService.cancelRecording()
        currentTranscript = ""
        cleanedText = ""

        // End Live Activity
        Task {
            await liveActivityService.endActivity()
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    DictationView(shouldAutoStart: .constant(false))
}
