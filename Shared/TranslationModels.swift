import Foundation

/// Direction of a translation request (used by the main app's manual test/settings).
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

    /// Short label for compact UI.
    var badge: String {
        switch self {
        case .haiku:  return "Haiku"
        case .sonnet: return "Sonnet"
        case .opus:   return "Opus"
        }
    }
}

/// A detected/target language, shown in the keyboard with a flag symbol.
struct LanguageTag: Equatable {
    /// ISO 639-1 code, lowercase. Empty = unknown / not yet detected.
    let code: String

    var flag: String { LanguageCatalog.flag(for: code) }
    /// Short badge text, e.g. "EN". Falls back to a globe glyph label when unknown.
    var badge: String { code.isEmpty ? "•" : code.uppercased() }
    /// Polish name of the language, for prompts and the expanded options.
    var name: String { LanguageCatalog.name(for: code) }

    static let unknown = LanguageTag(code: "")
    static let polish  = LanguageTag(code: "pl")
    static let english = LanguageTag(code: "en")
}

/// Result of a "smart" (auto-detect) translation.
struct TranslationResult {
    let text: String
    let sourceLang: LanguageTag
    let targetLang: LanguageTag
}

/// Flags and Polish names for the languages the keyboard is likely to meet.
enum LanguageCatalog {
    static let flags: [String: String] = [
        "pl": "🇵🇱", "en": "🇬🇧", "de": "🇩🇪", "es": "🇪🇸", "uk": "🇺🇦",
        "fr": "🇫🇷", "it": "🇮🇹", "ru": "🇷🇺", "pt": "🇵🇹", "nl": "🇳🇱",
        "cs": "🇨🇿", "sk": "🇸🇰", "tr": "🇹🇷", "sv": "🇸🇪", "no": "🇳🇴",
        "da": "🇩🇰", "ro": "🇷🇴", "hu": "🇭🇺", "ar": "🇸🇦", "zh": "🇨🇳",
        "ja": "🇯🇵", "ko": "🇰🇷"
    ]

    static let names: [String: String] = [
        "pl": "polski", "en": "angielski", "de": "niemiecki", "es": "hiszpański",
        "uk": "ukraiński", "fr": "francuski", "it": "włoski", "ru": "rosyjski",
        "pt": "portugalski", "nl": "niderlandzki", "cs": "czeski", "sk": "słowacki",
        "tr": "turecki", "sv": "szwedzki", "no": "norweski", "da": "duński",
        "ro": "rumuński", "hu": "węgierski", "ar": "arabski", "zh": "chiński",
        "ja": "japoński", "ko": "koreański"
    ]

    static func flag(for code: String) -> String { flags[code.lowercased()] ?? "🌐" }
    static func name(for code: String) -> String { names[code.lowercased()] ?? (code.isEmpty ? "wykryty" : code.uppercased()) }
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
