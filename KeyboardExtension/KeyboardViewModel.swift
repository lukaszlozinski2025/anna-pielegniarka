import Foundation
import Combine

/// Drives the keyboard panel. All host-app interactions (clipboard, inserting
/// text, switching keyboards, full-access check) are injected by
/// `KeyboardViewController` so this stays testable and UIKit-free.
@MainActor
final class KeyboardViewModel: ObservableObject {
    @Published var incoming = ""          // text pasted from the clipboard / to translate
    @Published var translated = ""        // Polish translation of the incoming message
    @Published var reply = ""             // Polish reply typed by the user
    @Published var translatedReply = ""   // ready English answer to insert
    @Published var status: String?        // short status / error line
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

    var defaultDirection: TranslationDirection { settings.defaultDirection }

    // MARK: - Receive workflow

    /// Read the clipboard (only on explicit tap — never automatically).
    func pasteFromClipboard() {
        status = nil
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription
            return
        }
        guard let text = readClipboard()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            status = TranslationError.emptyClipboard.errorDescription
            return
        }
        incoming = text
        translated = ""
    }

    func translateIncoming(direction: TranslationDirection) {
        let text = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = TranslationError.emptyClipboard.errorDescription
            return
        }
        run { [service] in
            switch direction {
            case .enToPl: return try await service.detectAndTranslateToPolish(text: text)
            case .plToEn: return try await service.translatePolishReplyToEnglish(text: text)
            case .auto:   return try await service.autoDetectAndTranslate(text: text)
            }
        } onSuccess: { [weak self] result in
            self?.translated = result
            self?.record(source: text, result: result, direction: direction)
        }
    }

    // MARK: - Reply workflow

    func translateReply() {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = TranslationError.emptyInput.errorDescription
            return
        }
        run { [service] in
            try await service.translatePolishReplyToEnglish(text: text)
        } onSuccess: { [weak self] result in
            self?.translatedReply = result
            self?.record(source: text, result: result, direction: .plToEn)
        }
    }

    /// Insert the ready answer into the active WhatsApp field. Falls back to the
    /// incoming translation if the user only used the receive workflow.
    func insertResult() {
        let text = translatedReply.isEmpty ? translated : translatedReply
        guard !text.isEmpty else {
            status = "Najpierw przetłumacz tekst"
            return
        }
        insert(text)
        status = "Wstawiono do pola wiadomości"
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> String,
                     onSuccess: @escaping (String) -> Void) {
        guard settings.useMockService || hasFullAccess() else {
            status = TranslationError.noFullAccess.errorDescription
            return
        }
        guard settings.isConfigured else {
            status = TranslationError.missingAPIKey.errorDescription
            return
        }
        status = nil
        busy = true
        Task {
            do {
                let result = try await work()
                busy = false
                onSuccess(result)
            } catch {
                busy = false
                status = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func record(source: String, result: String, direction: TranslationDirection) {
        settings.addToHistory(TranslationRecord(source: source, result: result, direction: direction))
    }
}
