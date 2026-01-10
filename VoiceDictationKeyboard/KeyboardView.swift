//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI
import UIKit

/// Main SwiftUI keyboard view - Full iOS-style QWERTY keyboard with Claude design
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let urlOpener: ((URL, @escaping (Bool) -> Void) -> Void)?
    let hasFullAccess: Bool
    let keyboardSwitcher: (() -> Void)?

    @State private var keyboardMode: KeyboardMode = .letters
    @State private var isUppercase = false
    @State private var isCapsLocked = false
    @StateObject private var dictationService: KeyboardDictationService

    // Claude color theme
    private let claudeOrange = Color(red: 218/255, green: 119/255, blue: 86/255)  // #DA7756
    private let claudeCream = Color(red: 250/255, green: 249/255, blue: 246/255)  // #FAF9F6
    private let claudeTan = Color(red: 232/255, green: 221/255, blue: 212/255)    // #E8DDD4

    enum KeyboardMode {
        case letters
        case numbers
        case symbols
    }

    init(textDocumentProxy: UITextDocumentProxy, urlOpener: ((URL, @escaping (Bool) -> Void) -> Void)? = nil, hasFullAccess: Bool = false, keyboardSwitcher: (() -> Void)? = nil) {
        self.textDocumentProxy = textDocumentProxy
        self.urlOpener = urlOpener
        self.hasFullAccess = hasFullAccess
        self.keyboardSwitcher = keyboardSwitcher
        self._dictationService = StateObject(wrappedValue: {
            let service = KeyboardDictationService()
            service.urlOpener = urlOpener
            service.textDocumentProxy = textDocumentProxy
            service.hasFullAccess = hasFullAccess
            return service
        }())
    }

    // QWERTY keyboard layout
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    // Numbers keyboard layout
    private let numbersTopRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let numbersMiddleRow = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    private let numbersBottomRow = [".", ",", "?", "!", "'", "\""]

    // Symbols keyboard layout
    private let symbolsTopRow = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
    private let symbolsMiddleRow = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    private let symbolsBottomRow = [".", ",", "?", "!", "'", "\""]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with mic and paste buttons and status - Claude themed
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
                            .foregroundColor(claudeOrange)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                }

                // Mic button or Recording controls
                if dictationService.status == .recording {
                    // Recording mode: X (cancel) and ✓ (confirm) buttons
                    HStack(spacing: 8) {
                        // Cancel button (X)
                        Button(action: {
                            dictationService.cancelRecording()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red)
                                .cornerRadius(22)
                        }

                        // Confirm button (✓)
                        Button(action: {
                            dictationService.confirmRecording()
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.green)
                                .cornerRadius(22)
                        }
                    }
                } else {
                    // Normal mode: Mic button
                    HStack(spacing: 8) {
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
                                .background(claudeCream)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(claudeTan.opacity(0.3))

            // Keyboard layout or recording placeholder
            if dictationService.status == .recording {
                // Recording mode: Show minimal UI, hide keyboard
                VStack {
                    Text("Recording in progress...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
                .background(claudeCream)
            } else {
                // Normal keyboard layout - Claude themed
                mainKeyboardView
            }
        }
        .background(claudeCream)
    }

    // Main keyboard view that switches between modes
    private var mainKeyboardView: some View {
        VStack(spacing: 0) {
            // Main letter/symbol rows
            Group {
                switch keyboardMode {
                case .letters:
                    lettersKeyboardView
                case .numbers:
                    numbersKeyboardView
                case .symbols:
                    symbolsKeyboardView
                }
            }

            // Bottom control row (iOS standard layout)
            HStack(spacing: 4) {
                // Mode switch key
                Button(action: cycleKeyboardMode) {
                    Text(modeButtonText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                // Globe key (keyboard switcher)
                Button(action: switchKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                // Emoji key
                Button(action: openEmojiKeyboard) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                // Space bar
                Button(action: { insertKey(" ") }) {
                    Text("space")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(claudeCream)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                // Period key
                KeyButton(
                    key: ".",
                    keyType: .letter,
                    claudeOrange: claudeOrange,
                    claudeCream: claudeCream,
                    action: { insertKey($0) },
                    fixedWidth: 45
                )

                // Return key
                Button(action: { insertKey("\n") }) {
                    Image(systemName: "return")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 55, height: 38)
                        .background(claudeOrange)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .padding(.vertical, 8)
    }

    private var lettersKeyboardView: some View {
        VStack(spacing: 6) {
            // Top row
            HStack(spacing: 4) {
                ForEach(topRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        isUppercase: isUppercase,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Middle row
            HStack(spacing: 4) {
                ForEach(middleRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        isUppercase: isUppercase,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Bottom row with shift and backspace
            HStack(spacing: 4) {
                // Shift key
                Button(action: toggleShift) {
                    Image(systemName: isCapsLocked ? "shift.fill" : "shift")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isUppercase ? .white : Color.primary)
                        .frame(width: 45, height: 38)
                        .background(isUppercase ? claudeOrange : claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                ForEach(bottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        isUppercase: isUppercase,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }

                // Backspace key
                Button(action: { textDocumentProxy.deleteBackward() }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var numbersKeyboardView: some View {
        VStack(spacing: 6) {
            // Numbers row
            HStack(spacing: 4) {
                ForEach(numbersTopRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Numbers middle row
            HStack(spacing: 4) {
                ForEach(numbersMiddleRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Numbers bottom row
            HStack(spacing: 4) {
                // Symbols key
                Button(action: { keyboardMode = .symbols }) {
                    Text("#+=")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                ForEach(numbersBottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }

                // Backspace key
                Button(action: { textDocumentProxy.deleteBackward() }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var symbolsKeyboardView: some View {
        VStack(spacing: 6) {
            // Symbols top row
            HStack(spacing: 4) {
                ForEach(symbolsTopRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Symbols middle row
            HStack(spacing: 4) {
                ForEach(symbolsMiddleRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }
            }

            // Symbols bottom row
            HStack(spacing: 4) {
                // Numbers key
                Button(action: { keyboardMode = .numbers }) {
                    Text("123")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }

                ForEach(symbolsBottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        claudeOrange: claudeOrange,
                        claudeCream: claudeCream,
                        action: { insertKey($0) }
                    )
                }

                // Backspace key
                Button(action: { textDocumentProxy.deleteBackward() }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private func cycleKeyboardMode() {
        switch keyboardMode {
        case .letters:
            keyboardMode = .numbers
        case .numbers:
            keyboardMode = .symbols
        case .symbols:
            keyboardMode = .letters
        }
    }

    private var modeButtonText: String {
        switch keyboardMode {
        case .letters: return "123"
        case .numbers: return "#+="
        case .symbols: return "ABC"
        }
    }

    private func toggleShift() {
        if isCapsLocked {
            // Turn off caps lock
            isUppercase = false
            isCapsLocked = false
        } else if isUppercase {
            // Enable caps lock (double tap)
            isCapsLocked = true
        } else {
            // Just enable shift
            isUppercase = true
        }
    }

    private func switchKeyboard() {
        // Advance to next keyboard input mode via callback from KeyboardViewController
        keyboardSwitcher?()
    }

    private func openEmojiKeyboard() {
        // iOS doesn't provide a public API to switch directly to emoji keyboard.
        // Use the keyboard switcher to cycle to the next keyboard (which may include emoji).
        keyboardSwitcher?()
    }

    private func insertKey(_ key: String) {
        let textToInsert = isUppercase ? key.uppercased() : key.lowercased()
        textDocumentProxy.insertText(textToInsert)

        // Auto-disable shift after one character (unless caps locked)
        if isUppercase && !isCapsLocked {
            isUppercase = false
        }

        // Auto-switch back to letters mode after inserting symbols/numbers (like iOS)
        if keyboardMode != .letters && key.count == 1 && !(key.first?.isLetter ?? false) {
            // Don't switch back if it's a symbol key that should stay in symbol mode
        } else if keyboardMode != .letters {
            // Could add logic here to switch back after inserting punctuation
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
        case .recording: claudeOrange
        case .error: .red
        default: .gray
        }
    }

    /// Modern Claude-themed key button component
    struct KeyButton: View {
        let key: String
        var isUppercase: Bool = false
        let keyType: KeyType
        let claudeOrange: Color
        let claudeCream: Color
        let action: (String) -> Void
        var fixedWidth: CGFloat? = nil

        enum KeyType {
            case letter
            case special
        }

        var body: some View {
            Button(action: {
                let finalKey = isUppercase ? key.uppercased() : key.lowercased()
                action(finalKey)
                // Add haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Text(displayKey)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: fixedWidth ?? 34, height: 38)
                    .background(claudeCream)
                    .cornerRadius(keyType == .letter ? 6 : 8)
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                    .scaleEffect(0.95) // Slightly smaller for material design feel
            }
        }

        private var displayKey: String {
            if isUppercase {
                return key.uppercased()
            } else {
                return key.lowercased()
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
}
