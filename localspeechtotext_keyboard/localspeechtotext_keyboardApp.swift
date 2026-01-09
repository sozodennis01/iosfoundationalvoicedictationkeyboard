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
    @StateObject private var backgroundService = BackgroundDictationService()
    @State private var shouldAutoStartRecording = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
                .onAppear {
                    // Start background monitoring when app appears
                    backgroundService.startMonitoring()

                    if shouldAutoStartRecording {
                        // The DictationView will handle auto-start
                        shouldAutoStartRecording = false
                    }
                }
                .onDisappear {
                    // Stop monitoring when app disappears
                    backgroundService.stopMonitoring()
                }
        }
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        // Handle voicedictation://record URL scheme
        guard url.scheme == "voicedictation" else {
            return
        }

        if url.host == "record" {
            // Set flag to auto-start recording
            shouldAutoStartRecording = true
        }
    }
}
