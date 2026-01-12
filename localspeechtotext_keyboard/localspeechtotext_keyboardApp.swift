//
//  localspeechtotext_keyboardApp.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/3/26.
//

import SwiftUI

@main
@available(iOS 26.0, *)
struct localspeechtotext_keyboardApp: App {
    @State private var shouldAutoStart = false

    var body: some Scene {
        WindowGroup {
            ContentView(shouldAutoStart: $shouldAutoStart)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        // Handle voicedictation://start URL scheme from keyboard
        guard url.scheme == "voicedictation", url.host == "start" else {
            return
        }

        // Trigger auto-start in DictationView
        shouldAutoStart = true
    }
}
