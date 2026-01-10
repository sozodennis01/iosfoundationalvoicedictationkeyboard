import Foundation
import Combine
import UIKit
import Speech
import AVFoundation
import FoundationModels
import os

@MainActor
class KeyboardDictationService: ObservableObject {
    @Published var status: DictationStatus = .idle
    @Published var lastError: String? = nil
    @Published var isHostAppReady: Bool = false

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var audioEngine: AVAudioEngine?
    private var currentTranscript = ""
    private let storage = UserDefaults(suiteName: AppConstants.appGroupID)
    private let logger = Logger(subsystem: "com.localspeechtotext.keyboard", category: "dictation")
    private let storageService = SharedStorageService()
    private let appOpenURL = URL(string: "voicedictation://start")
    var urlOpener: ((URL, @escaping (Bool) -> Void) -> Void)? = nil
    var fullAccessErrorHandler: ((String) -> Void)? = nil
    var textDocumentProxy: UITextDocumentProxy?
    private var darwinObserver: DarwinNotificationObservation?
    private var recordingStartedObserver: DarwinNotificationObservation?
    private var hostAppStateObserver: DarwinNotificationObservation?
    private var pongObserver: DarwinNotificationObservation?
    private var lastCommandTimestamp: Date?
    private var commandTimeout: Double = 3.0  // 3 seconds timeout

    var hasPermissions: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    // Full access status passed from UIInputViewController
    var hasFullAccess: Bool = false

    var hasFullAccessComputed: Bool {
        // Alternative computed implementation - unused now since we pass from view controller
        guard let extensionBundleID = Bundle.main.bundleIdentifier else { return false }
        let userDefaults = UserDefaults.standard
        let key = "KeyboardExtensionRequiresFullAccess\(extensionBundleID)"
        return userDefaults.bool(forKey: key)
    }

    init() {
        // Set up Darwin notification observers
        setupDarwinNotificationObserver()
        setupRecordingStartedObserver()
        setupHostAppStateObserver()
        setupPongObserver()

        // Check if host app is alive via ping-pong
        checkHostAppAlive()
    }

    deinit {
        // Darwin notification observers are automatically cleaned up
        // when the DarwinNotificationObservation objects are deallocated
    }

    // MARK: - Ping-Pong (instant alive check)

    private func setupPongObserver() {
        pongObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.pongNotification) { [weak self] in
            Task { @MainActor in
                self?.handlePongReceived()
            }
        }
        logger.info("Darwin notification observer set up for pong")
    }

    private func handlePongReceived() {
        logger.info("Received pong from host app - it's alive!")
        isHostAppReady = true
    }

    /// Sends a ping to check if container app is alive
    func checkHostAppAlive() {
        // First check the stored state
        let storedState = SharedState.isHostAppReady()

        if storedState {
            // State says ready, but verify with ping
            // Assume not ready until we get pong
            isHostAppReady = false
            logger.info("Sending ping to verify host app is alive")
            DarwinNotificationCenter.shared.post(name: AppConstants.pingNotification)
            // If container is alive, it will respond with pong and handlePongReceived will set isHostAppReady = true
        } else {
            // State says not ready
            isHostAppReady = false
        }
    }

    private func setupDarwinNotificationObserver() {
        darwinObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.textReadyNotification) { [weak self] in
            Task { @MainActor in
                self?.handleTextReadyNotification()
            }
        }
        logger.info("Darwin notification observer set up for textReady")
    }

    private func setupRecordingStartedObserver() {
        recordingStartedObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.recordingStartedNotification) { [weak self] in
            Task { @MainActor in
                self?.handleRecordingStartedNotification()
            }
        }
        logger.info("Darwin notification observer set up for recordingStarted")
    }

    private func setupHostAppStateObserver() {
        hostAppStateObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.hostAppStateChangedNotification) { [weak self] in
            Task { @MainActor in
                self?.handleHostAppStateChanged()
            }
        }
        logger.info("Darwin notification observer set up for hostAppStateChanged")
    }

    private func handleHostAppStateChanged() {
        let newState = SharedState.isHostAppReady()
        logger.info("Host app state changed notification received - isReady: \(newState)")
        isHostAppReady = newState
    }

    private func handleTextReadyNotification() {
        logger.info("Received textReady notification from host app")

        // Read cleaned text from App Group
        if let text = storageService.loadCleanedText(), !text.isEmpty {
            logger.info("Loaded cleaned text: \(text.prefix(50))...")

            // Auto-insert text into text field
            textDocumentProxy?.insertText(text)

            status = .idle
            lastError = nil

            // Clear cleaned text after use to avoid re-paste loops
            //storageService.saveCleanedText("")
            logger.info("Text auto-inserted successfully; status reset to idle")
        } else {
            logger.warning("No cleaned text available in App Group")
            lastError = "No text available"
            status = .idle
        }
    }

    private func handleRecordingStartedNotification() {
        logger.info("Received recordingStarted notification from host app - switching to recording mode")
        status = .recording
        lastError = nil
    }

    func requestPermissions() async -> Bool {
        logger.info("Requesting speech & mic permissions")
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechGranted else {
            logger.error("Speech permission denied")
            return false
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        if !micGranted {
            logger.error("Mic permission denied")
        }

        logger.info("Permissions result — speech: \(speechGranted), mic: \(micGranted)")
        return speechGranted && micGranted
    }

    func toggleRecording() async {
        logger.info("toggleRecording invoked — status: \(self.status.rawValue), hostAppReady: \(self.isHostAppReady)")

        // Only allow recording when host app is ready (UI should show "Start App" button otherwise)
        guard isHostAppReady else {
            logger.warning("toggleRecording called but host app not ready - UI should show Start App button")
            return
        }

        switch status {
        case .idle:
            // Host app is ready - show x/check buttons immediately and post start recording command
            logger.info("Host app ready - showing recording controls and posting start recording command")
            status = .recording
            DarwinNotificationCenter.shared.post(name: AppConstants.startRecordingNotification)
        case .recording, .processing:
            logger.debug("toggleRecording ignored for status: \(self.status.rawValue)")
        default:
            break
        }
    }

    func paste(into textDocumentProxy: UITextDocumentProxy?) {
        if let text = storage?.string(forKey: AppConstants.sharedTextKey) {
            textDocumentProxy?.insertText(text)
            // Optionally clear after paste
            // storage?.removeObject(forKey: AppConstants.sharedTextKey)
        }
    }

    /// Extension-friendly flow: open host app to record via URL scheme
    /// Text will be auto-inserted when Darwin notification is received
    private func triggerHost() async {
        logger.info("triggerHost invoked")
        lastError = nil
        status = .processing

        // Check Full Access first
        if !hasFullAccess {
            logger.error("Full Access not enabled - cannot open URLs")
            status = .error
            lastError = "Full Access Required - Enable in Settings > General > Keyboard > Keyboards > VoiceDictationKeyboard"
            return
        }

        // Open host app via URL scheme to start recording
        guard let url = appOpenURL else {
            logger.error("Failed to create URL from 'voicedictation://start'")
            status = .error
            lastError = "URL Scheme Error"
            return
        }

        logger.info("Opening host app for recording with background audio")

        // Use completion handler to detect URL opening failures
        urlOpener?(url, { [weak self] success in
            guard let self = self else { return }
            Task { @MainActor in
                if !success {
                    self.logger.error("URL opening failed - app may not be installed or available")
                    self.status = .error
                    self.lastError = "Cannot open dictation app - check if installed"
                }
                // If success=true, status remains .processing until Darwin notification arrives
            }
        })

        // Status will be updated when Darwin notification is received
        // See handleTextReadyNotification() for auto-insert logic
    }

    // MARK: - Host App Control

    /// Opens the container app via URL scheme for cold-start initialization
    func openHostApp() {
        logger.info("openHostApp invoked")
        lastError = nil

        // Check Full Access first
        if !hasFullAccess {
            logger.error("Full Access not enabled - cannot open URLs")
            lastError = "Full Access Required - Enable in Settings > General > Keyboard > Keyboards > VoiceDictationKeyboard"
            return
        }

        // Open host app via URL scheme
        guard let url = appOpenURL else {
            logger.error("Failed to create URL from 'voicedictation://start'")
            lastError = "URL Scheme Error"
            return
        }

        logger.info("Opening host app via URL scheme")

        urlOpener?(url, { [weak self] success in
            guard let self = self else { return }
            Task { @MainActor in
                if !success {
                    self.logger.error("URL opening failed - app may not be installed or available")
                    self.lastError = "Cannot open dictation app - check if installed"
                }
                // If success, user will manually return - isHostAppReady will update via Darwin notification
            }
        })
    }

    // MARK: - Recording Control Methods

    func confirmRecording() {
        logger.info("User confirmed recording - checking host app readiness")

        // Check if we need to ensure host app is ready
        if !SharedState.isHostAppReady() {
            logger.info("Host app not ready - will open host app first")
            status = .processing
            ensureHostAppReady { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.logger.info("Host app ready - posting stopRecording notification")
                    DarwinNotificationCenter.shared.post(name: AppConstants.stopRecordingNotification)
                    self.status = .processing  // Wait for processing to complete and text to arrive
                }
            }
        } else {
            // Host app is already ready, post command directly
            logger.info("Host app ready - posting stopRecording notification")
            DarwinNotificationCenter.shared.post(name: AppConstants.stopRecordingNotification)
            status = .processing  // Wait for processing to complete and text to arrive
        }
    }

    func cancelRecording() {
        logger.info("User cancelled recording - checking host app readiness")

        // For cancel, we want to ensure it always reaches the host app
        if !SharedState.isHostAppReady() {
            logger.info("Host app not ready - will open host app first for cancel")
            ensureHostAppReady { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.logger.info("Host app ready - posting cancelRecording notification")
                    DarwinNotificationCenter.shared.post(name: AppConstants.cancelRecordingNotification)
                    self.status = .idle  // Return to idle state
                    self.lastError = nil
                }
            }
        } else {
            // Host app is already ready, post command directly
            logger.info("Host app ready - posting cancelRecording notification")
            DarwinNotificationCenter.shared.post(name: AppConstants.cancelRecordingNotification)
            status = .idle  // Return to idle state
            lastError = nil
        }
    }

    private func ensureHostAppReady(completion: @escaping (Bool) -> Void) {
        // If host app is already ready, call completion immediately
        if SharedState.isHostAppReady() {
            completion(true)
            return
        }

        // Open host app via URL scheme to ensure it's ready
        guard let url = appOpenURL else {
            logger.error("Failed to create URL for host app")
            completion(false)
            return
        }

        logger.info("Attempting to open/ensure host app is ready")

        // Set a timeout to avoid waiting indefinitely
        DispatchQueue.main.asyncAfter(deadline: .now() + commandTimeout) { [weak self] in
            if !SharedState.isHostAppReady() {
                self?.logger.warning("Timeout waiting for host app to become ready")
                // Still proceed if timeout - URL opening will handle fallback
            }
        }

        // Open URL - this will bring host app to foreground and make it post ready notification
        urlOpener?(url, { [weak self] success in
            guard let self = self else { return }
            if !success {
                self.logger.error("Failed to open host app for command")
                completion(false)
                return
            }

            // Wait for host app to post ready notification
            if SharedState.isHostAppReady() {
                completion(true)
            } else {
                // Set up a one-time observer to wait for ready notification
                // Using underscore prefix to suppress "never read" warning for lifecycle management
                var _tempObserver: DarwinNotificationObservation?
                _tempObserver = DarwinNotificationCenter.shared.addObserver(name: AppConstants.hostAppReadyNotification) { [weak self] in
                    // Invalidate the temporary observer once triggered by setting to nil
                    _tempObserver = nil
                    self?.logger.info("Host app signaled ready via notification")
                    completion(true)
                }
            }
        })
    }
}
