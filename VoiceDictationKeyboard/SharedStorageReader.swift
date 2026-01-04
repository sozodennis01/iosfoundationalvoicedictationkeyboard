import Foundation

class SharedStorageReader {
    private let userDefaults: UserDefaults?

    init() {
        userDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    }

    // MARK: - Read Methods

    func getText() -> String? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        return userDefaults.string(forKey: AppConstants.sharedTextKey)
    }

    func getStatus() -> DictationStatus {
        guard let userDefaults = userDefaults else {
            return .idle
        }

        guard let data = userDefaults.data(forKey: AppConstants.statusKey) else {
            return .idle
        }

        let decoder = JSONDecoder()
        guard let state = try? decoder.decode(DictationState.self, from: data) else {
            return .idle
        }

        return state.status
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

    // MARK: - Clear Methods (optional)

    func clearText() {
        guard let userDefaults = userDefaults else {
            return
        }

        userDefaults.removeObject(forKey: AppConstants.sharedTextKey)
        userDefaults.synchronize()
    }
}
