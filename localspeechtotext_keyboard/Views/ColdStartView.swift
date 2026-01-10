//
//  ColdStartView.swift
//  localspeechtotext_keyboard
//
//  Cold start view shown when keyboard extension opens the app via URL scheme.
//  Initializes audio session and instructs user to swipe back.
//

import SwiftUI

@available(iOS 26.0, *)
struct ColdStartView: View {
    @Binding var isColdStart: Bool
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var isInitialized = false
    @State private var initError: String?

    private let claudeOrange = Color(red: 218/255, green: 119/255, blue: 86/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(claudeOrange)
                    .frame(width: 120, height: 120)
                    .shadow(color: claudeOrange.opacity(0.3), radius: 20, x: 0, y: 10)

                Image(systemName: isInitialized ? "checkmark" : "mic.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isInitialized ? 1.0 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isInitialized)
            }

            // Title
            Text(isInitialized ? "Microphone Access Activated" : "Activating Microphone...")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Instruction
            if isInitialized {
                Text("Swipe back to start dictating.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }

            // Error message
            if let error = initError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Visual swipe hint at bottom
            if isInitialized {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Swipe from left edge")
                        .font(.footnote)
                }
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.3), value: isInitialized)
        .onAppear {
            initializeAudioSession()
        }
        .onDisappear {
            // Reset cold start flag when user leaves this view
            // (e.g., swipes back to keyboard or returns to app later)
            isColdStart = false
        }
    }

    private func initializeAudioSession() {
        Task {
            do {
                try await speechService.initializeAudioSession()

                await MainActor.run {
                    isInitialized = true
                    SharedState.setHostAppReady(true)
                }
            } catch {
                await MainActor.run {
                    initError = "Failed to initialize: \(error.localizedDescription)"
                    // Don't set hostAppReady on failure - keyboard will show "Start App" again
                    isInitialized = true
                }
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    ColdStartView(isColdStart: .constant(true))
}
