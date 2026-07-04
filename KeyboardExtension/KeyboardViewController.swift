import UIKit
import SwiftUI

/// Custom keyboard host. Loads shared settings, hosts the SwiftUI panel, and
/// bridges the SwiftUI view model to UIKit APIs (clipboard, text proxy, next
/// keyboard, full-access check).
final class KeyboardViewController: UIInputViewController {

    private var model: KeyboardViewModel!
    private var hosting: UIHostingController<KeyboardView>!
    private var heightConstraint: NSLayoutConstraint!

    /// Match the standard iOS keyboard footprint so we occupy the same space as
    /// the WhatsApp keyboard instead of a small floating panel.
    private let keyboardHeight: CGFloat = 300

    override func viewDidLoad() {
        super.viewDidLoad()

        let settings = AppGroupSettings()
        settings.load()

        model = KeyboardViewModel(settings: settings)
        wireModel()

        hosting = UIHostingController(rootView: KeyboardView(model: model))
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
    }

    private func wireModel() {
        model.needsNextKeyboardButton = needsInputModeSwitchKey
        model.advanceKeyboard = { [weak self] in self?.advanceToNextInputKeyboard() }
        model.hasFullAccess = { [weak self] in self?.hasFullAccess ?? false }
        model.readClipboard = { UIPasteboard.general.string }   // only called on explicit tap
        model.insert = { [weak self] text in self?.textDocumentProxy.insertText(text) }
    }
}
