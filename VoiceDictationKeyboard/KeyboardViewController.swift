//
//  KeyboardViewController.swift
//  VoiceDictationKeyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import UIKit
import SwiftUI

/// Main keyboard view controller that hosts the SwiftUI KeyboardView
class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create SwiftUI KeyboardView with access to textDocumentProxy
        let keyboardView = KeyboardView(
            textDocumentProxy: self.textDocumentProxy,
            openURLHandler: { [weak self] url in
                guard let self = self else { return }
                // Use openURL from the extension context to remain extension-safe
                self.extensionContext?.open(url, completionHandler: nil)
            }
        )
        hostingController = UIHostingController(rootView: keyboardView)

        // Add hosting controller as child and set up constraints
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)

            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            hostingController.didMove(toParent: self)
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents
        super.textWillChange(textInput)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents
        super.textDidChange(textInput)
    }
}

