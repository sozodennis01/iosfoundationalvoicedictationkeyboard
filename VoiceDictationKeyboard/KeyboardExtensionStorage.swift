import Foundation

// Use shared DictationState directly (file included in target)
internal typealias DictationSession = DictationState

/// Minimal storage service for the keyboard extension target.
/// Provides only the APIs used by KeyboardState.
final class KeyboardSharedStorageService {
    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = nil) {
        if let userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
        }
    }

    // MARK: - Session Management

    func saveCurrentSession(_ session: DictationSession) {
        guard let userDefaults = userDefaults else { return }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(session) {
            userDefaults.set(encoded, forKey: AppConstants.currentSession)
            userDefaults.synchronize()
        }
    }

    func loadCurrentSession() -> DictationSession? {
        guard let userDefaults = userDefaults else { return nil }
        guard let data = userDefaults.data(forKey: AppConstants.currentSession) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(DictationSession.self, from: data)
    }

    func clearCurrentSession() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.removeObject(forKey: AppConstants.currentSession)
        userDefaults.synchronize()
    }

    // MARK: - Text Management

    func loadCleanedText() -> String? {
        guard let userDefaults = userDefaults else { return nil }
        return userDefaults.string(forKey: AppConstants.cleanedText)
    }
    
    func saveCleanedText(_ text: String) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        userDefaults.set(text, forKey: AppConstants.cleanedText)
        userDefaults.synchronize()
    }
}

// Expose the same type name used elsewhere, mapped to the extension-safe implementation
typealias SharedStorageService = KeyboardSharedStorageService
