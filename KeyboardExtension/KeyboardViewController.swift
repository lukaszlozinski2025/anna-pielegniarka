import UIKit
import SwiftUI

/// Custom keyboard host. Loads shared settings, hosts the SwiftUI panel, and
/// bridges the SwiftUI view model to UIKit APIs (clipboard, text proxy, next
/// keyboard, full-access check).
final class KeyboardViewController: UIInputViewController {

    private var model: KeyboardViewModel!
    private var hosting: UIHostingController<KeyboardView>!
    private var heightConstraint: NSLayoutConstraint!
    private var clipboardPollTimer: Timer?

    /// A touch taller than the stock keyboard: the top ~54pt strip is transparent
    /// (the glass CTA circles float over the host there), so we add that back to
    /// keep the actual key area at a comfortable, standard-feeling height.
    private let keyboardHeight: CGFloat = 356

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkClipboard()
        // Light poll while the keyboard is on screen, so copying a new message
        // mid-session (without switching keyboards) is picked up too. Stops the
        // moment the keyboard disappears.
        clipboardPollTimer?.invalidate()
        clipboardPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        clipboardPollTimer?.invalidate()
        clipboardPollTimer = nil
    }

    private func checkClipboard() {
        guard hasFullAccess else { return }   // reading the pasteboard requires Full Access anyway
        model.checkClipboardForAutoTranslate(
            changeCount: UIPasteboard.general.changeCount,
            contents: UIPasteboard.general.string
        )
    }

    private func wireModel() {
        model.needsNextKeyboardButton = needsInputModeSwitchKey
        model.advanceKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.hasFullAccess = { [weak self] in self?.hasFullAccess ?? false }
        model.readClipboard = { UIPasteboard.general.string }
        model.readHostText = { [weak self] in self?.textDocumentProxy.documentContextBeforeInput }
        model.clearHostText = { [weak self] in
            guard let proxy = self?.textDocumentProxy, let text = proxy.documentContextBeforeInput else { return }
            for _ in text { proxy.deleteBackward() }
        }
        model.insert = { [weak self] text in self?.textDocumentProxy.insertText(text) }
        model.copyToClipboard = { text in UIPasteboard.general.string = text }
        model.playClickSound = { UIDevice.current.playInputClick() }
    }
}

/// Opting in to key-click feedback: `UIDevice.playInputClick()` only makes a
/// sound when an object in the input responder chain conforms to
/// `UIInputViewAudioFeedback` and returns `true` here. It respects the user's
/// "Keyboard Clicks" system setting — no sound if they've turned it off.
extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
