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
    /// true = QWERTY typing view is showing; false = the (bigger) translation view is
    /// showing instead. Toggled by the chevron in the top strip, or automatically once
    /// a translation lands.
    @Published var showKeyboard = true
    /// Briefly true right after Auto mode detects a language — drives a transient,
    /// fading badge above the input box rather than a permanent indicator.
    @Published var showLangBadge = false

    let settings: AppGroupSettings
    private let service: TranslationService

    /// Where the current `input` text came from — determines whether translating
    /// it should clear the WhatsApp field before inserting the result.
    private enum InputSource { case none, clipboard, whatsapp }
    private var inputSource: InputSource = .none

    // Injected by the controller.
    var hasFullAccess: () -> Bool = { false }
    var readClipboard: () -> String? = { nil }
    /// Reads the text currently typed/dictated in the host app's field (e.g. the
    /// WhatsApp compose box). Keyboards can't access the microphone directly, so
    /// voice input goes through the system keyboard's own dictation into that
    /// field first — this reads what landed there.
    var readHostText: () -> String? = { nil }
    /// Clears the host field's current text (used before inserting a polished
    /// translation, so it replaces the rough draft instead of appending to it).
    var clearHostText: () -> Void = {}
    var insert: (String) -> Void = { _ in }
    /// Writes text to the system clipboard, so the user can paste it themselves
    /// (e.g. into WhatsApp's field with a long-press → Paste).
    var copyToClipboard: (String) -> Void = { _ in }
    var advanceKeyboard: () -> Void = {}
    var needsNextKeyboardButton = true
    /// The standard iOS key-click sound, via `UIDevice.playInputClick()` — only
    /// audible if the user has "Keyboard Clicks" enabled in system Sound settings.
    var playClickSound: () -> Void = {}

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

    /// Shows the transient language badge for ~1.8s, then hides it again.
    private func flashLangBadge() {
        showLangBadge = true
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            self.showLangBadge = false
        }
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
        inputSource = .clipboard
        input = text
        output = ""
        // The tap on "Wklej" is the user's explicit action, so translate right
        // away — one step instead of two.
        translate()
    }

    /// Silent variant used by clipboard auto-detection — same as
    /// `pasteFromClipboard()` but doesn't complain if the clipboard is empty or
    /// unreadable (there's no explicit user tap to report an error against).
    private func autoTranslateFromClipboard(_ text: String) {
        inputSource = .clipboard
        input = text
        output = ""
        translate()
    }

    /// "Odbierz z WhatsApp": reads whatever is currently typed or dictated in the
    /// host app's own field (using the system keyboard's dictation mic, since our
    /// extension can't access the microphone directly), then cleans it up and
    /// translates it. Used to compose replies without a letter keyboard of our own.
    func loadFromWhatsApp() {
        status = nil
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription; return
        }
        guard let text = readHostText()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            status = "Napisz lub podyktuj odpowiedź w polu WhatsApp, potem dotknij tutaj"; return
        }
        inputSource = .whatsapp
        input = text
        output = ""
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
                var justDetectedLanguage = false
                if mode == .auto {
                    let r = try await self.service.smartTranslate(text: text, replyTargetHint: hint)
                    self.output = r.text
                    self.outputLang = r.targetLang
                    if !r.sourceLang.code.isEmpty && r.sourceLang.code != "pl" {
                        self.detectedForeign = r.sourceLang       // remember the conversation language
                        self.flashLangBadge()
                        justDetectedLanguage = true
                    }
                } else {
                    let t = try await self.service.translate(text: text, from: nil, to: manualTarget.name)
                    self.output = t
                    self.outputLang = manualTarget
                }
                self.busy = false
                self.record(source: text, result: self.output)
                self.autoInsertIfReply()
                // A translation just landed — reveal it (unless autoInsertIfReply
                // already consumed it and cleared the output above). Give the
                // "language detected" badge a beat on screen first, otherwise it'd
                // flash on a view that's collapsing away in the same instant.
                if !self.output.isEmpty {
                    if justDetectedLanguage {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    self.showKeyboard = false
                }
            } catch {
                self.busy = false
                self.status = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Inserts the result into WhatsApp's field and returns to the typing view.
    func insertResult() {
        guard !output.isEmpty else { status = "Najpierw przetłumacz tekst"; return }
        if inputSource == .whatsapp { clearHostText() }
        insert(output)
        status = "Wstawiono do WhatsApp — wyślij sam"
        input = ""; output = ""; inputSource = .none
        showKeyboard = true
    }

    /// Copies the result to the clipboard. Unlike `insertResult()` this does NOT
    /// clear the result — the user pastes it into WhatsApp themselves (long-press
    /// → Wklej) and can copy again or keep composing.
    func copyResult() {
        guard !output.isEmpty else { status = "Najpierw przetłumacz tekst"; return }
        copyToClipboard(output)
        status = "Skopiowano ✓ — wklej w WhatsApp"
    }

    /// Auto-insert applies only to the "Odbierz z WhatsApp" dictation-cleanup
    /// flow, where there's already a rough draft in WhatsApp's field to replace —
    /// that's the one case where silently swapping it in is clearly wanted.
    /// Messages composed on our own QWERTY are shown for review instead (Kopiuj /
    /// Wstaw), since the user hasn't seen a draft in WhatsApp to compare against.
    private func autoInsertIfReply() {
        guard inputSource == .whatsapp else { return }
        guard !output.isEmpty, !outputLang.code.isEmpty, outputLang.code != "pl" else { return }
        clearHostText()
        insert(output)
        status = "Wstawiono do WhatsApp — wyślij sam"
        input = ""
        output = ""
        inputSource = .none
    }

    // MARK: - Clipboard auto-detection

    private var lastSeenClipboardChangeCount: Int?

    /// Called by the controller whenever the keyboard becomes visible and on a
    /// light poll while it stays visible. If the clipboard changed since we last
    /// looked, auto-run the paste+translate flow — no tap needed. Reading only
    /// happens while this keyboard is the active one (the user deliberately
    /// switched to it), never in the background.
    func checkClipboardForAutoTranslate(changeCount: Int, contents: String?) {
        guard settings.useMockService || hasFullAccess() else { return }
        defer { lastSeenClipboardChangeCount = changeCount }
        guard lastSeenClipboardChangeCount != changeCount else { return }
        guard let text = contents?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        guard text != input else { return }
        autoTranslateFromClipboard(text)
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
        input = ""; output = ""; outputLang = .unknown; status = nil; inputSource = .none
        showKeyboard = true
    }

    // MARK: - Show/hide the QWERTY

    /// Chevron tap while typing: hide the keyboard, reveal the (already
    /// translated) result underneath.
    func collapseKeyboard() { showKeyboard = false }

    /// Chevron tap while viewing a result: bring the QWERTY back for the next
    /// message. The old draft is done with, so clear it — the translation
    /// itself stays put until overwritten by the next `translate()`.
    func expandKeyboard() {
        input = ""
        inputSource = .none
        showKeyboard = true
    }

    // MARK: - Own QWERTY (typing directly into the keyboard)

    /// A keyboard extension can't summon a system keyboard for a text field of
    /// its own, so composing a message here means our own on-screen QWERTY
    /// appends characters straight to `input`.
    func typeCharacter(_ c: String) {
        inputSource = .none
        input += c
        playClickSound()
    }

    func backspace() {
        inputSource = .none
        guard !input.isEmpty else { return }
        input.removeLast()
        playClickSound()
    }

    /// A keyboard extension can never get microphone access (hard iOS limit,
    /// true for every custom keyboard, not just ours) — tapping the mic-slash
    /// badge over the input box explains why, instead of silently doing nothing.
    func explainMicLimitation() {
        status = "Mikrofon niedostępny w klawiaturze (ograniczenie iOS) — podyktuj w WhatsApp, potem dotknij „Odbierz”."
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
