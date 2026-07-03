import UIKit
import SwiftUI

/// Custom keyboard host. Loads shared settings, hosts the SwiftUI panel, and
/// bridges the SwiftUI view model to UIKit APIs (clipboard, text proxy, next
/// keyboard, full-access check).
final class KeyboardViewController: UIInputViewController {

    private var model: KeyboardViewModel!
    private var hosting: UIHostingController<KeyboardView>!

    override func viewDidLoad() {
        super.viewDidLoad()

        let settings = AppGroupSettings()
        settings.load()

        model = KeyboardViewModel(settings: settings)
        wireModel()

        let root = KeyboardView(model: model)
        hosting = UIHostingController(rootView: root)
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

        // Give the panel a comfortable fixed height (a keyboard has no intrinsic one).
        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    private func wireModel() {
        // Only show the globe/next-keyboard button when the system asks for it.
        model.needsNextKeyboardButton = needsInputModeSwitchKey

        model.advanceKeyboard = { [weak self] in
            self?.advanceToNextInputKeyboard()
        }
        model.hasFullAccess = { [weak self] in
            self?.hasFullAccess ?? false
        }
        model.readClipboard = {
            // Read only when invoked (on button tap) — never on a timer.
            UIPasteboard.general.string
        }
        model.insert = { [weak self] text in
            self?.textDocumentProxy.insertText(text)
        }
    }
}
