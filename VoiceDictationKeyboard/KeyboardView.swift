//
//  KeyboardView.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import SwiftUI
import KeyboardKit

/// Main SwiftUI keyboard view that uses KeyboardKit's SystemKeyboard
struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy

    @StateObject private var keyboardContext = KeyboardContext()
    @StateObject private var autocompleteContext = AutocompleteContext()
    @StateObject private var calloutContext = KeyboardCalloutContext()
    @StateObject private var state = KeyboardState()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Placeholder toolbar with autocomplete area and mic button
                HStack {
                    Text("Autocomplete") // Placeholder for future autocomplete view
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    Spacer()
                    MicButton(action: state.startDictation)
                        .padding(.trailing, 8)
                }
                .frame(height: 40)
                .background(Color(.systemGray6))

                // KeyboardKit's system keyboard with standard QWERTY layout
                SystemKeyboard(
                    state: keyboardContext,
                    services: KeyboardServices(),
                    buttonContent: { $0.view },
                    buttonView: { $0.view },
                    emojiKeyboard: { $0.view },
                    toolbar: { EmptyView() }
                )
            }

            // Dictation overlay
            if state.showDictationOverlay {
                DictationStateView(
                    state: mapToDictationStateViewState(state.dictationState),
                    onStop: state.stopDictation
                )
            }
        }
        .onAppear {
            state.configure(textDocumentProxy: textDocumentProxy)
        }
    }

    // Map KeyboardState.DictationUIState to DictationStateView.State
    private func mapToDictationStateViewState(_ uiState: KeyboardState.DictationUIState) -> DictationStateView.State {
        switch uiState {
        case .idle:
            return .idle
        case .arming:
            return .arming
        case .listening:
            return .listening
        case .processing:
            return .processing
        case .error(let message):
            return .error(message)
        }
    }
}

#Preview {
    // SwiftUI preview for development
    KeyboardView(textDocumentProxy: PreviewTextDocumentProxy())
}

/// Preview-only mock for UITextDocumentProxy
private class PreviewTextDocumentProxy: NSObject, UITextDocumentProxy {
    var documentContextBeforeInput: String? = ""
    var documentContextAfterInput: String? = ""
    var selectedText: String? = nil
    var documentInputMode: UITextInputMode? = nil
    var documentIdentifier: UUID = UUID()

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) {}
    func deleteBackward() {}
}
