import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardView>?
    private let storageReader = SharedStorageReader()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create SwiftUI view
        let keyboardView = KeyboardView(
            onMicTap: { [weak self] in
                self?.openHostApp()
            },
            onInsertTap: { [weak self] in
                self?.insertDictatedText()
            },
            getText: { [weak self] in
                self?.storageReader.getText() ?? ""
            },
            getStatus: { [weak self] in
                self?.storageReader.getStatus() ?? .idle
            }
        )

        // Wrap in UIHostingController
        let hosting = UIHostingController(rootView: keyboardView)
        hostingController = hosting

        // Add as child view controller
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // Setup constraints
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.heightAnchor.constraint(equalToConstant: 280)
        ])
    }

    // MARK: - Actions

    private func openHostApp() {
        guard let url = URL(string: "voicedictation://record") else {
            return
        }

        // Open the host app via URL scheme
        openURL(url)
    }

    private func insertDictatedText() {
        guard let text = storageReader.getText(), !text.isEmpty else {
            return
        }

        // Insert text into the text field
        textDocumentProxy.insertText(text)

        // Optional: Clear the stored text after insertion
        // storageReader.clearText()
    }

    // MARK: - URL Opening

    private func openURL(_ url: URL) {
        // Use responder chain to open URL from keyboard extension
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self

        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                currentResponder.perform(selector, with: url)
                return
            }
            responder = currentResponder.next
        }
    }
}
