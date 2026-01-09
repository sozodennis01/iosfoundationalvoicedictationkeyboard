//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI
import UIKit

/// Main SwiftUI keyboard view - basic QWERTY layout
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let openURLHandler: (URL) -> Void

    @State private var isUppercase = false

    @StateObject private var speechService = KeyboardSpeechService()
    @StateObject private var cleanupService = KeyboardCleanupService()

    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // Keyboard layouts
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with mic button
            HStack {
                Spacer()

                Button(action: handleMicButtonTap) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isRecording ? .white : .gray)
                        .frame(width: 44, height: 44)
                        .background(isRecording ? Color.red : Color(uiColor: .systemGray5))
                        .cornerRadius(8)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGray6))

            // Error message banner
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .onTapGesture {
                        self.errorMessage = nil
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.errorMessage = nil
                        }
                    }
            }

            // Existing keyboard layout (only show when not recording/processing)
            if !isRecording && !isProcessing {
                VStack(spacing: 8) {
                    // Keyboard layout
                    VStack(spacing: 6) {
                        // Top row
                        HStack(spacing: 3) {
                            ForEach(topRow, id: \.self) { key in
                                KeyButton(letter: key, isUppercase: isUppercase) {
                                    insertKey(key)
                                }
                            }
                        }

                        // Middle row
                        HStack(spacing: 3) {
                            Spacer().frame(width: 20) // Offset for ergonomics
                            ForEach(middleRow, id: \.self) { key in
                                KeyButton(letter: key, isUppercase: isUppercase) {
                                    insertKey(key)
                                }
                            }
                            Spacer().frame(width: 20)
                        }

                        // Bottom row with shift and backspace
                        HStack(spacing: 3) {
                            // Shift key
                            Button(action: {
                                isUppercase.toggle()
                            }) {
                                Image(systemName: isUppercase ? "shift.fill" : "shift")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 42, height: 42)
                                    .background(Color(uiColor: .systemGray5))
                                    .cornerRadius(5)
                            }

                            ForEach(bottomRow, id: \.self) { key in
                                KeyButton(letter: key, isUppercase: isUppercase) {
                                    insertKey(key)
                                }
                            }

                            // Backspace key
                            Button(action: {
                                textDocumentProxy.deleteBackward()
                            }) {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 42, height: 42)
                                    .background(Color(uiColor: .systemGray5))
                                    .cornerRadius(5)
                            }
                        }

                        // Space bar row
                        HStack(spacing: 3) {
                            // Space bar
                            Button(action: {
                                textDocumentProxy.insertText(" ")
                            }) {
                                Text("space")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(Color(uiColor: .systemGray5))
                                    .cornerRadius(5)
                            }

                            // Return key
                            Button(action: {
                                textDocumentProxy.insertText("\n")
                            }) {
                                Text("return")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 42)
                                    .background(Color.blue)
                                    .cornerRadius(5)
                            }
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 8)
                }
            }

            // Recording UI (full screen overlay)
            if isRecording {
                VStack(spacing: 20) {
                    Spacer()

                    Circle()
                        .fill(Color.red)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)

                    Text("Recording...")
                        .font(.title2)
                        .foregroundColor(.primary)

                    Text("Tap to stop")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGray6))
                .onTapGesture {
                    handleMicButtonTap()
                }
            }

            // Processing UI (full screen overlay)
            if isProcessing {
                VStack(spacing: 20) {
                    Spacer()

                    ProgressView()
                        .scaleEffect(2)

                    Text("Processing...")
                        .font(.title2)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGray6))
            }
        }
        .background(Color(uiColor: .systemGray6))
    }

    private func handleMicButtonTap() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            // Check permissions
            var hasPermission = speechService.hasPermission
            if !hasPermission {
                hasPermission = await speechService.requestPermissions()
            }

            guard hasPermission else {
                await MainActor.run {
                    errorMessage = "Microphone and speech recognition access required - enable in Settings"
                }
                return
            }

            // Start recording
            do {
                try await speechService.startRecording()
                await MainActor.run {
                    isRecording = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stopRecording() {
        isRecording = false

        // Get final transcript
        let transcript = speechService.stopRecording()

        guard !transcript.isEmpty else {
            errorMessage = "No speech detected"
            return
        }

        // Process transcript
        processTranscript(transcript)
    }

    private func processTranscript(_ rawText: String) {
        Task {
            await MainActor.run {
                isProcessing = true
            }

            do {
                // Clean up text
                let cleanedText = try await cleanupService.cleanupText(rawText)

                await MainActor.run {
                    isProcessing = false

                    // Insert cleaned text
                    textDocumentProxy.insertText(cleanedText)
                }
            } catch {
                // Fall back to raw text on error
                await MainActor.run {
                    isProcessing = false

                    if error.localizedDescription.contains("unavailable") {
                        errorMessage = "Apple Intelligence unavailable - inserted raw text"
                        textDocumentProxy.insertText(rawText)
                    } else {
                        errorMessage = "Processing failed: \(error.localizedDescription)"
                        textDocumentProxy.insertText(rawText)
                    }
                }
            }
        }
    }

    private func insertKey(_ key: String) {
        let text = isUppercase ? key.uppercased() : key.lowercased()
        textDocumentProxy.insertText(text)

        // Auto-disable shift after one character
        if isUppercase {
            isUppercase = false
        }
    }
}

/// Simple key button component
struct KeyButton: View {
    let letter: String
    let isUppercase: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isUppercase ? letter.uppercased() : letter.lowercased())
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }
}

#Preview {
    // SwiftUI preview for development
    KeyboardView(
        textDocumentProxy: PreviewTextDocumentProxy(),
        openURLHandler: { _ in }
    )
}

/// Preview-only mock for UITextDocumentProxy
private class PreviewTextDocumentProxy: NSObject, UITextDocumentProxy {
    var documentContextBeforeInput: String? = ""
    var documentContextAfterInput: String? = ""
    var selectedText: String? = nil
    var documentInputMode: UITextInputMode? = nil
    var documentIdentifier: UUID = UUID()
    var hasText: Bool = false

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) {}
    func deleteBackward() {}
}
