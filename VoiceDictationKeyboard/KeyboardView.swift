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

    // Recording animation state
    @State private var isPulsing = false
    @State private var waveformPhase: Double = 0

    // Dark mode detection
    @Environment(\.colorScheme) var colorScheme

    // Claude color theme - adaptive for dark mode
    private var claudeOrange: Color {
        colorScheme == .dark
            ? Color(red: 217/255, green: 121/255, blue: 90/255)   // #D9795A - warmer in dark
            : Color(red: 218/255, green: 119/255, blue: 86/255)   // #DA7756
    }

    private var claudeCream: Color {
        colorScheme == .dark
            ? Color(red: 44/255, green: 42/255, blue: 40/255)     // #2C2A28 - warm charcoal
            : Color(red: 250/255, green: 249/255, blue: 246/255)  // #FAF9F6
    }

    private var claudeTan: Color {
        colorScheme == .dark
            ? Color(red: 62/255, green: 58/255, blue: 54/255)     // #3E3A36 - elevated surface
            : Color(red: 232/255, green: 221/255, blue: 212/255)  // #E8DDD4
    }

    private var keyBackground: Color {
        colorScheme == .dark
            ? Color(red: 72/255, green: 68/255, blue: 64/255)     // #484440 - key surface
            : claudeCream
    }

    private var keyShadowOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.08
    }

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
            // Top bar with mic button and status - Claude themed (hidden during recording)
            if dictationService.status != .recording {
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

                    // Mic button or Start App button (based on host app readiness)
                    if dictationService.isHostAppReady {
                        // Host app is ready - show mic button
                        Button(action: {
                            Task {
                                await dictationService.toggleRecording()
                            }
                        }) {
                            Image(systemName: micIcon)
                                .font(.system(size: 20))
                                .foregroundColor(micColor)
                                .frame(width: 44, height: 44)
                                .background(keyBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 2, x: 0, y: 2)
                        }
                    } else {
                        // Host app not ready - show Start App button
                        Button(action: {
                            dictationService.openHostApp()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Start App")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(claudeOrange)
                            .cornerRadius(12)
                            .shadow(color: claudeOrange.opacity(0.3), radius: 2, x: 0, y: 2)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(claudeTan.opacity(0.3))
            }

            // Keyboard layout or recording view
            if dictationService.status == .recording {
                // Recording mode: Show Claude-themed recording UI
                recordingView
            } else {
                // Normal keyboard layout - Claude themed
                mainKeyboardView
            }
        }
        .background(claudeCream)
        .onAppear {
            // Ping container app to verify it's actually alive
            dictationService.checkHostAppAlive()
        }
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
                // Globe key (keyboard switcher) - leftmost position
                Button(action: switchKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                // Mode switch key
                Button(action: cycleKeyboardMode) {
                    Text(modeButtonText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 45, height: 38)
                        .background(claudeTan)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                // Space bar
                Button(action: { insertKey(" ") }) {
                    Text("space")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(keyBackground)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                // Period key
                KeyButton(
                    key: ".",
                    keyType: .letter,
                    keyBackground: keyBackground,
                    keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity * 2), radius: 2, x: 0, y: 2)
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                ForEach(bottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        isUppercase: isUppercase,
                        keyType: .letter,
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                ForEach(numbersBottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }

                ForEach(symbolsBottomRow, id: \.self) { key in
                    KeyButton(
                        key: key,
                        keyType: .letter,
                        keyBackground: keyBackground,
                        keyShadowOpacity: keyShadowOpacity,
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
                        .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Claude-themed Recording View
    private var recordingView: some View {
        VStack(spacing: 16) {
            Spacer()

            // Pulsing recording indicator with waveform
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(claudeOrange.opacity(0.3), lineWidth: 3)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)

                // Inner circle with mic icon
                Circle()
                    .fill(claudeOrange)
                    .frame(width: 60, height: 60)
                    .shadow(color: claudeOrange.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }

            // Animated 5-bar waveform visualizer
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(claudeOrange)
                        .frame(width: 4, height: waveformHeight(for: index))
                        .animation(
                            .easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: waveformPhase
                        )
                }
            }
            .frame(height: 32)

            // Recording text with breathing animation
            Text("Recording...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(claudeOrange)
                .opacity(isPulsing ? 0.7 : 1.0)

            Spacer()

            // Control buttons
            HStack(spacing: 32) {
                // Cancel button
                Button(action: {
                    dictationService.cancelRecording()
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 56, height: 56)

                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: 56, height: 56)

                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Done button
                Button(action: {
                    dictationService.confirmRecording()
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(claudeOrange)
                                .frame(width: 56, height: 56)
                                .shadow(color: claudeOrange.opacity(0.4), radius: 6, x: 0, y: 3)

                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Done")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(claudeCream)
        .onAppear {
            startRecordingAnimations()
        }
        .onDisappear {
            stopRecordingAnimations()
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 12
        let variation: CGFloat = 18
        let phase = sin(waveformPhase + Double(index) * 0.8)
        return baseHeight + CGFloat(phase + 1) / 2 * variation
    }

    private func startRecordingAnimations() {
        // Start pulse animation
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
        // Start waveform animation
        withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
            waveformPhase = .pi * 2
        }
    }

    private func stopRecordingAnimations() {
        isPulsing = false
        waveformPhase = 0
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
        // Show different status when host app is not ready
        if !dictationService.isHostAppReady {
            return "Open app to enable voice"
        }

        switch dictationService.status {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .ready: return "Tap Paste"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        // Show orange when host app is not ready (matches Start App button)
        if !dictationService.isHostAppReady {
            return claudeOrange
        }

        switch dictationService.status {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        case .ready: return .green
        case .error: return .red
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
        let keyBackground: Color
        let keyShadowOpacity: Double
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
                    .background(keyBackground)
                    .cornerRadius(keyType == .letter ? 6 : 8)
                    .shadow(color: Color.black.opacity(keyShadowOpacity), radius: 1, x: 0, y: 1)
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
