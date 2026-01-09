//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI
import UIKit

/// Main SwiftUI keyboard view - basic QWERTY layout with mic and paste buttons
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let urlOpener: ((URL, @escaping (Bool) -> Void) -> Void)?
    let hasFullAccess: Bool

    @State private var isUppercase = false
    @StateObject private var dictationService: KeyboardDictationService

    init(textDocumentProxy: UITextDocumentProxy, urlOpener: ((URL, @escaping (Bool) -> Void) -> Void)? = nil, hasFullAccess: Bool = false) {
        self.textDocumentProxy = textDocumentProxy
        self.urlOpener = urlOpener
        self.hasFullAccess = hasFullAccess
        self._dictationService = StateObject(wrappedValue: {
            let service = KeyboardDictationService()
            service.urlOpener = urlOpener
            service.textDocumentProxy = textDocumentProxy
            service.hasFullAccess = hasFullAccess
            return service
        }())
    }

    // Keyboard layouts
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with mic and paste buttons and status
            HStack(spacing: 8) {
                Spacer()

                // Status text
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    if let lastError = dictationService.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }

                // Mic button
                Button(action: {
                    Task {
                        await dictationService.toggleRecording()
                    }
                }) {
                    Image(systemName: micIcon)
                        .font(.system(size: 20))
                        .foregroundColor(micColor)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(8)
                }

                // Paste button
                Button(action: {
                    dictationService.paste(into: textDocumentProxy)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray6))

            // Keyboard layout
            VStack(spacing: 8) {
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
                        Spacer().frame(width: 20)
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
                                .font(.system(size: 16))
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
                                .font(.system(size: 16))
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
                                .font(.system(size: 14))
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
                                .font(.system(size: 14))
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
        .background(Color(uiColor: .systemGray6))
    }

    private func insertKey(_ key: String) {
        let text = isUppercase ? key.uppercased() : key.lowercased()
        textDocumentProxy.insertText(text)

        // Auto-disable shift after one character
        if isUppercase {
            isUppercase = false
        }
    }

    private var statusText: String {
        switch dictationService.status {
        case .idle: "Ready"
        case .recording: "Recording..."
        case .processing: "Processing..."
        case .ready: "Tap Paste"
        case .error: "Error"
        }
    }

    private var statusColor: Color {
        switch dictationService.status {
        case .idle: .gray
        case .recording: .red
        case .processing: .orange
        case .ready: .green
        case .error: .red
        }
    }

    private var micIcon: String {
        switch dictationService.status {
        case .recording: "stop.fill"
        default: "mic.fill"
        }
    }

    private var micColor: Color {
        switch dictationService.status {
        case .recording: .red
        case .error: .red
        default: .gray
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
