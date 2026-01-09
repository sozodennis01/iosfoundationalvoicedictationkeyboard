//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI

/// Main SwiftUI keyboard view - basic QWERTY layout
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let openURLHandler: (URL) -> Void

    @State private var isUppercase = false

    // Keyboard layouts
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
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
                            .background(Color(.systemGray5))
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
                            .background(Color(.systemGray5))
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
                            .background(Color(.systemGray5))
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
        .background(Color(.systemGray6))
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
                .background(Color(.systemBackground))
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
