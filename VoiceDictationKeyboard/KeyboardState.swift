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
        // Set up Darwin notification observer for text ready notifications
        setupDarwinNotificationObserver()
    }

    deinit {
        // Darwin notification observer will be automatically cleaned up
        // when the DarwinNotificationObservation object is deallocated
    }

    private func setupDarwinNotificationObserver() {
        darwinObserver = DarwinNotificationCenter.shared.addObserver(name: "group.sozodennis.voicedictation.textReady") { [weak self] in
            Task { @MainActor in
                self?.handleTextReadyNotification()
            }
        }
        logger.info("Darwin notification observer set up for textReady")
    }

    private func handleTextReadyNotification() {
        logger.info("Received textReady notification from host app")

        // Read cleaned text from App Group
        if let text = storageService.loadCleanedText(), !text.isEmpty {
            logger.info("Loaded cleaned text: \(text.prefix(50))...")

            // Auto-insert text into text field
            textDocumentProxy?.insertText(text)

            status = .ready
            lastError = nil

            logger.info("Text auto-inserted successfully")
        } else {
            logger.warning("No cleaned text available in App Group")
            lastError = "No text available"
            status = .error
        }
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
        logger.info("toggleRecording invoked — status: \(self.status.rawValue)")
        switch status {
        case .idle:
            await triggerHost()
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
}
