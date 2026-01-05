//
//  ContentView.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/3/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct ContentView: View {
    var body: some View {
        TabView {
            DictationView()
                .tabItem {
                    Label("Dictation", systemImage: "mic.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    ContentView()
}
