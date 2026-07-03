import UIKit
import SwiftUI
import Combine

/// Custom keyboard host. Loads shared settings, hosts the SwiftUI panel, and
/// bridges the SwiftUI view model to UIKit APIs (clipboard, text proxy, next
/// keyboard, full-access check). Keeps the panel as short as possible and grows
/// only when the user expands "więcej opcji".
final class KeyboardViewController: UIInputViewController {

    private var model: KeyboardViewModel!
    private var hosting: UIHostingController<KeyboardView>!
    private var heightConstraint: NSLayoutConstraint!
    private var cancellables = Set<AnyCancellable>()

    private func targetHeight(expanded: Bool, hasOutput: Bool) -> CGFloat {
        if expanded { return hasOutput ? 344 : 300 }
        return hasOutput ? 214 : 150
    }

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

        heightConstraint = view.heightAnchor.constraint(equalToConstant: targetHeight(expanded: false, hasOutput: false))
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        // Keep the panel as short as possible: grow only when a result is shown
        // or the options section is expanded.
        model.$expanded
            .combineLatest(model.$output.map { !$0.isEmpty })
            .map { [weak self] expanded, hasOutput in
                self?.targetHeight(expanded: expanded, hasOutput: hasOutput) ?? 150
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] height in
                guard let self else { return }
                self.heightConstraint.constant = height
                self.view.layoutIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func wireModel() {
        model.needsNextKeyboardButton = needsInputModeSwitchKey
        model.advanceKeyboard = { [weak self] in self?.advanceToNextInputKeyboard() }
        model.hasFullAccess = { [weak self] in self?.hasFullAccess ?? false }
        model.readClipboard = { UIPasteboard.general.string }   // only called on explicit tap
        model.insert = { [weak self] text in self?.textDocumentProxy.insertText(text) }
    }
}
