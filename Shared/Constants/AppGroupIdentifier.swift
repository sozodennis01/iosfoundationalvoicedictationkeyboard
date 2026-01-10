import Foundation

enum AppConstants {
    static let appGroupID = "group.sozodennis.voicedictation"
    static let sharedTextKey = "cleanedText"
    static let statusKey = "dictationStatus"
    static let currentSession = "currentSession"
    static let cleanedText = "cleanedText"
    static let rawTranscript = "rawTranscript"

    // Darwin notification names for dictation flow
    static let hostAppReadyNotification = "group.sozodennis.voicedictation.hostAppReady"
    static let textReadyNotification = "group.sozodennis.voicedictation.textReady"
    static let recordingStartedNotification = "group.sozodennis.voicedictation.recordingStarted"
    static let startRecordingNotification = "group.sozodennis.voicedictation.startRecording"
    static let stopRecordingNotification = "group.sozodennis.voicedictation.stopRecording"
    static let cancelRecordingNotification = "group.sozodennis.voicedictation.cancelRecording"

    // Darwin notification for state changes
    static let hostAppStateChangedNotification = "group.sozodennis.voicedictation.stateChanged"

    // Ping-pong for instant alive check
    static let pingNotification = "group.sozodennis.voicedictation.ping"
    static let pongNotification = "group.sozodennis.voicedictation.pong"
}

// MARK: - Shared State Helper (WisprFlow Pattern)

enum SharedState {
    static let appGroupID = AppConstants.appGroupID
    static let hostReadyKey = "hostAppReady"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func setHostAppReady(_ ready: Bool) {
        defaults?.set(ready, forKey: hostReadyKey)
        defaults?.synchronize()
        // Immediately notify running keyboard extensions
        SharedNotifier.postHostAppStateChanged()
    }

    static func isHostAppReady() -> Bool {
        defaults?.bool(forKey: hostReadyKey) ?? false
    }
}

// MARK: - Cross-Process Notifications (WisprFlow Pattern)

enum SharedNotifier {
    // Must be globally unique - matches AppConstants
    static let hostAppStateChanged = AppConstants.hostAppStateChangedNotification as CFString

    static func postHostAppStateChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(hostAppStateChanged),
            nil,
            nil,
            true
        )
    }
}
