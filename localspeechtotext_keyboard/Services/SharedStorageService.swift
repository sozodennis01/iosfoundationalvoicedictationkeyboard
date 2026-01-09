import Foundation

class SharedStorageService {
    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = nil) {
        // Use provided userDefaults for testing, or create one for the app group
        if let userDefaults = userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
        }
    }

    // MARK: - State Management

    func saveState(_ state: DictationState) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(state) {
            userDefaults.set(encoded, forKey: AppConstants.statusKey)
            userDefaults.synchronize()
        }
    }

    func getState() -> DictationState? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        guard let data = userDefaults.data(forKey: AppConstants.statusKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(DictationState.self, from: data)
    }

    // MARK: - Text Management

    func saveText(_ text: String) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        userDefaults.set(text, forKey: AppConstants.sharedTextKey)
        userDefaults.synchronize()
    }

    func getText() -> String? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        return userDefaults.string(forKey: AppConstants.sharedTextKey)
    }

    // MARK: - Session Management

    func saveCurrentSession(_ session: DictationSession) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(session) {
            userDefaults.set(encoded, forKey: AppConstants.currentSession)
            userDefaults.synchronize()
        }
    }

    func loadCurrentSession() -> DictationSession? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        guard let data = userDefaults.data(forKey: AppConstants.currentSession) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(DictationSession.self, from: data)
    }

    func clearCurrentSession() {
        guard let userDefaults = userDefaults else {
            return
        }

        userDefaults.removeObject(forKey: AppConstants.currentSession)
        userDefaults.synchronize()
    }

    // MARK: - Enhanced Text Management

    func saveCleanedText(_ text: String) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        userDefaults.set(text, forKey: AppConstants.cleanedText)
        userDefaults.synchronize()
    }

    func loadCleanedText() -> String? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        return userDefaults.string(forKey: AppConstants.cleanedText)
    }

    func saveRawTranscript(_ text: String) {
        guard let userDefaults = userDefaults else {
            print("Error: UserDefaults not available")
            return
        }

        userDefaults.set(text, forKey: AppConstants.rawTranscript)
        userDefaults.synchronize()
    }

    func loadRawTranscript() -> String? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        return userDefaults.string(forKey: AppConstants.rawTranscript)
    }

    // MARK: - Clear Data

    func clearAll() {
        guard let userDefaults = userDefaults else {
            return
        }

        userDefaults.removeObject(forKey: AppConstants.statusKey)
        userDefaults.removeObject(forKey: AppConstants.sharedTextKey)
        userDefaults.removeObject(forKey: AppConstants.currentSession)
        userDefaults.removeObject(forKey: AppConstants.cleanedText)
        userDefaults.removeObject(forKey: AppConstants.rawTranscript)
        userDefaults.synchronize()
    }
}
