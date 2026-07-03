import Foundation

/// Direction of a translation request.
enum TranslationDirection: String, CaseIterable, Codable {
    case enToPl   // English -> Polish  ("EN → PL")
    case plToEn   // Polish  -> English ("PL → EN")
    case auto     // Detect language, translate to the other one

    var label: String {
        switch self {
        case .enToPl: return "EN → PL"
        case .plToEn: return "PL → EN"
        case .auto:   return "Auto"
        }
    }
}

/// Selectable Claude model. Default is Haiku — fast and cheap, which is what a
/// keyboard translation loop needs. Heavier models can be selected later.
enum ClaudeModel: String, CaseIterable, Codable, Identifiable {
    case haiku  = "claude-haiku-4-5"
    case sonnet = "claude-sonnet-5"
    case opus   = "claude-opus-4-8"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku:  return "Claude Haiku (szybki, domyślny)"
        case .sonnet: return "Claude Sonnet (mocniejszy)"
        case .opus:   return "Claude Opus (najmocniejszy)"
        }
    }
}

/// Errors surfaced to the UI. Messages are user-facing Polish strings.
enum TranslationError: LocalizedError {
    case noInternet
    case noFullAccess
    case emptyClipboard
    case emptyInput
    case missingAPIKey
    case api(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .noInternet:    return "Brak połączenia"
        case .noFullAccess:  return "Włącz Pełny dostęp w ustawieniach iPhone, żeby używać tłumaczenia AI"
        case .emptyClipboard: return "Najpierw skopiuj wiadomość z WhatsAppa"
        case .emptyInput:    return "Najpierw wpisz lub wklej tekst"
        case .missingAPIKey: return "Dodaj klucz Anthropic API w aplikacji AI Translate"
        case .api(let msg):  return msg.isEmpty ? "Błąd tłumaczenia — spróbuj ponownie" : msg
        case .decoding:      return "Nie udało się odczytać odpowiedzi — spróbuj ponownie"
        }
    }
}

/// One saved translation (only stored when the user opts into history).
struct TranslationRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var source: String
    var result: String
    var direction: TranslationDirection
}
