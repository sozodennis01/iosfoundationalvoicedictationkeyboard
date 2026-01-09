//
//  ContentView.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/3/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct ContentView: View {
    @Binding var shouldAutoStart: Bool
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DictationView(shouldAutoStart: $shouldAutoStart)
                .tabItem {
                    Label("Dictation", systemImage: "mic.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .onChange(of: shouldAutoStart) { _, newValue in
            if newValue {
                // Switch to dictation tab when auto-start is triggered
                selectedTab = 0
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    ContentView(shouldAutoStart: .constant(false))
}
