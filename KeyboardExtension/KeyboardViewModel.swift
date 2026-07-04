import Foundation
import Combine

/// Drives the compact keyboard panel.
///
/// One input field feeds one "Przetłumacz" action. In **Auto** mode the model
/// detects the language: foreign text → Polish, your Polish → the conversation
/// language (remembered from the last detected foreign message). Long-pressing
/// the mode chip switches to a manual **switch** (→ PL / → other language).
@MainActor
final class KeyboardViewModel: ObservableObject {
    enum Mode { case auto, manual }

    @Published var input = ""
    @Published var output = ""
    @Published var outputLang: LanguageTag = .unknown
    @Published var detectedForeign: LanguageTag?      // remembered conversation language
    @Published var mode: Mode = .auto
    @Published var manualToPolish = true              // manual switch: true = → PL, false = → other
    @Published var expanded = false
    @Published var status: String?
    @Published var busy = false

    let settings: AppGroupSettings
    private let service: TranslationService

    // Injected by the controller.
    var hasFullAccess: () -> Bool = { false }
    var readClipboard: () -> String? = { nil }
    var insert: (String) -> Void = { _ in }
    var advanceKeyboard: () -> Void = {}
    var needsNextKeyboardButton = true

    init(settings: AppGroupSettings) {
        self.settings = settings
        self.service = TranslationServiceFactory.make(settings: settings)
    }

    // MARK: - Derived display

    var canInsert: Bool { !output.isEmpty }

    /// The language the manual switch currently targets.
    var manualTarget: LanguageTag { manualToPolish ? .polish : (detectedForeign ?? .english) }

    /// Small label on the mode chip.
    var modeLabel: String {
        switch mode {
        case .auto:   return "Auto"
        case .manual: return "→ \(manualTarget.badge)"
        }
    }

    /// Flags shown in the top bar once we know the languages.
    var langIndicator: String? {
        if !output.isEmpty {
            let from = detectedForeign?.flag ?? outputLang.flag
            return "\(from) → \(outputLang.flag)"
        }
        if let f = detectedForeign { return "\(f.flag) \(f.badge)" }
        return nil
    }

    // MARK: - Actions

    func pasteFromClipboard() {
        status = nil
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription; return
        }
        guard let text = readClipboard()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            status = TranslationError.emptyClipboard.errorDescription; return
        }
        input = text
        output = ""
        // The tap on "Wklej" is the user's explicit action, so translate right
        // away — one step instead of two. (Clipboard is still only read on tap.)
        translate()
    }

    func translate() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = TranslationError.emptyInput.errorDescription; return }
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription; return
        }
        guard settings.isConfigured else {
            status = TranslationError.missingAPIKey.errorDescription; return
        }

        status = nil
        busy = true
        let mode = self.mode
        let hint = detectedForeign?.code
        let manualTarget = self.manualTarget

        Task {
            do {
                if mode == .auto {
                    let r = try await self.service.smartTranslate(text: text, replyTargetHint: hint)
                    self.output = r.text
                    self.outputLang = r.targetLang
                    if !r.sourceLang.code.isEmpty && r.sourceLang.code != "pl" {
                        self.detectedForeign = r.sourceLang       // remember the conversation language
                    }
                } else {
                    let t = try await self.service.translate(text: text, from: nil, to: manualTarget.name)
                    self.output = t
                    self.outputLang = manualTarget
                }
                self.busy = false
                self.record(source: text, result: self.output)
                self.autoInsertIfReply()
            } catch {
                self.busy = false
                self.status = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func insertResult() {
        guard !output.isEmpty else { status = "Najpierw przetłumacz tekst"; return }
        insert(output)
        status = "Wstawiono do pola wiadomości"
    }

    /// When the result is an outgoing reply (translated into the conversation
    /// language, not Polish), drop it straight into the WhatsApp field and reset
    /// the panel for the next message. Polish results (incoming, for reading) are
    /// left in the panel and can still be inserted manually with "Wstaw".
    private func autoInsertIfReply() {
        guard !output.isEmpty, !outputLang.code.isEmpty, outputLang.code != "pl" else { return }
        insert(output)
        status = "Wstawiono do WhatsApp — wyślij sam"
        input = ""
        output = ""
    }

    /// Long-press on the chip: Auto ⇄ manual switch.
    func toggleMode() {
        mode = (mode == .auto) ? .manual : .auto
        status = mode == .manual ? "Ręczny kierunek — dotknij, aby przełączyć" : nil
    }

    /// Tap on the chip while in manual mode: flip the direction.
    func tapMode() {
        if mode == .manual { manualToPolish.toggle() }
    }

    func toggleExpand() { expanded.toggle() }

    func clearAll() {
        input = ""; output = ""; outputLang = .unknown; status = nil
    }

    // MARK: - API key (entered here because a free Apple ID can't share it via App Group)

    var hasAPIKey: Bool { !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Save the API key from the clipboard (copy your sk-ant-… key, then tap this).
    func pasteAPIKey() {
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription; return
        }
        guard let key = readClipboard()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            status = "Najpierw skopiuj swój klucz API"; return
        }
        settings.apiKey = key
        status = "Klucz API zapisany ✓"
    }

    func clearAPIKey() {
        settings.apiKey = ""
        status = "Klucz API usunięty"
    }

    private func record(source: String, result: String) {
        let dir: TranslationDirection = (outputLang.code == "pl") ? .enToPl : .plToEn
        settings.addToHistory(TranslationRecord(source: source, result: result, direction: dir))
    }
}
