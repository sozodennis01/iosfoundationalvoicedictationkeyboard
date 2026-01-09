//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI
import UIKit

/// Main SwiftUI keyboard view - basic QWERTY layout with dictation mic button
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy

    @State private var isUppercase = false
    @StateObject private var keyboardState: KeyboardState = KeyboardState()

    // Keyboard layouts
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with mic button (only show when idle)
            if case KeyboardState.DictationUIState.idle = keyboardState.dictationState {
                HStack {
                    Spacer()

                    Button(action: keyboardState.startDictation) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .systemGray5))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemGray6))
            }

            // Error message banner for idle state errors
            if case KeyboardState.DictationUIState.error(let message) = keyboardState.dictationState, !keyboardState.showDictationOverlay {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .onTapGesture {
                        keyboardState.dictationState = KeyboardState.DictationUIState.idle
                        keyboardState.showDictationOverlay = false
                    }
            }

            // Keyboard layout (only show when idle)
            if case KeyboardState.DictationUIState.idle = keyboardState.dictationState {
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

            // Dictation overlay (covers entire keyboard when active)
            if keyboardState.showDictationOverlay {
                VStack(spacing: 20) {
                    Spacer()

                    switch keyboardState.dictationState {
                    case KeyboardState.DictationUIState.arming:
                        Text("Opening app...")
                            .font(.title2)
                            .foregroundColor(.primary)

                    case KeyboardState.DictationUIState.listening:
                        Circle()
                            .fill(Color.red)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            )
                            .scaleEffect(true ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)

                        Text("Listening...")
                            .font(.title2)
                            .foregroundColor(.primary)

                        Text("Tap to stop")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                    case KeyboardState.DictationUIState.processing:
                        ProgressView()
                            .scaleEffect(2)

                        Text("Processing...")
                            .font(.title2)
                            .foregroundColor(.primary)

                    case KeyboardState.DictationUIState.error(let message):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("Error")
                            .font(.title2)
                            .foregroundColor(.primary)

                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                    case KeyboardState.DictationUIState.idle:
                        EmptyView()
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGray6))
                .onTapGesture {
                    switch keyboardState.dictationState {
                    case KeyboardState.DictationUIState.listening:
                        keyboardState.stopDictation()
                    case KeyboardState.DictationUIState.error:
                        keyboardState.dictationState = KeyboardState.DictationUIState.idle
                        keyboardState.showDictationOverlay = false
                    default:
                        break
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGray6))
        .onAppear {
            // Configure keyboard state with handlers for opening the host app
            keyboardState.configure(
                textDocumentProxy: textDocumentProxy,
                openURLHandler: { url in
                    // Find the keyboard view controller and use its extension context
                    var responder: UIResponder? = textDocumentProxy as? UIResponder
                    while let r = responder {
                        if let keyboardVC = r as? UIInputViewController {
                            // Use extension context to open URL (works from keyboard extensions)
                            keyboardVC.extensionContext?.open(url, completionHandler: nil)
                            return
                        }
                        responder = r.next
                    }
                    print("Failed to find UIInputViewController for openURL")
                }
            )
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
        textDocumentProxy: PreviewTextDocumentProxy()
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

