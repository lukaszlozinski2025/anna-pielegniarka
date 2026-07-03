import Foundation

/// Abstraction over the translation backend so the keyboard and the app don't
/// care whether it's Anthropic, a custom backend, or the dev mock.
///
/// The three semantic methods match the two WhatsApp workflows plus Auto:
///   • incoming message  -> `detectAndTranslateToPolish`
///   • your Polish reply  -> `translatePolishReplyToEnglish`
///   • Auto button        -> `autoDetectAndTranslate`
protocol TranslationService {
    func translate(text: String, from: String?, to: String) async throws -> String
    func detectAndTranslateToPolish(text: String) async throws -> String
    func translatePolishReplyToEnglish(text: String) async throws -> String
    func autoDetectAndTranslate(text: String) async throws -> String
}

// MARK: - Prompts

enum TranslationPrompt {
    /// Incoming foreign message -> Polish (with short slang/abbreviation notes).
    static let toPolish = """
    Przetłumacz poniższą wiadomość na język polski. Zachowaj sens, ton i kontekst \
    rozmowy. Jeśli są skróty, slang albo błędy, wyjaśnij krótko znaczenie po polsku. \
    Nie dodawaj zbędnych komentarzy.
    """

    /// Your Polish reply -> natural, casual English for WhatsApp.
    static let replyToEnglish = """
    Przetłumacz poniższą odpowiedź z polskiego na naturalny angielski do rozmowy na \
    WhatsAppie. Zachowaj swobodny, ludzki ton. Nie brzmi jak formalny mail. Nie dodawaj \
    nic od siebie.
    """

    /// Auto: detect the language and translate to the other one.
    static let auto = """
    Wykryj język poniższej wiadomości. Jeśli jest po polsku, przetłumacz ją na naturalny, \
    swobodny angielski do rozmowy na WhatsAppie. Jeśli jest w innym języku, przetłumacz ją \
    na język polski i — jeśli występują skróty lub slang — krótko wyjaśnij ich znaczenie po \
    polsku. Zwróć tylko tłumaczenie, bez zbędnych komentarzy.
    """

    static func generic(from: String?, to: String) -> String {
        if let from, !from.isEmpty {
            return "Przetłumacz poniższy tekst z języka \(from) na język \(to). Zachowaj naturalny, swobodny ton. Zwróć tylko tłumaczenie."
        }
        return "Przetłumacz poniższy tekst na język \(to). Zachowaj naturalny, swobodny ton. Zwróć tylko tłumaczenie."
    }
}

// MARK: - Anthropic implementation

/// Calls the Anthropic Messages API (`POST /v1/messages`) directly.
/// Optimised for the keyboard loop: default model Claude Haiku, temperature 0.2,
/// short max_tokens, short timeout.
final class AnthropicTranslationService: TranslationService {
    private let settings: AppGroupSettings
    private let session: URLSession

    private let anthropicVersion = "2023-06-01"
    private let maxTokens = 800
    private let temperature = 0.2

    init(settings: AppGroupSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12   // short timeout for a snappy keyboard
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    func detectAndTranslateToPolish(text: String) async throws -> String {
        try await complete(system: TranslationPrompt.toPolish, user: text)
    }

    func translatePolishReplyToEnglish(text: String) async throws -> String {
        try await complete(system: TranslationPrompt.replyToEnglish, user: text)
    }

    func autoDetectAndTranslate(text: String) async throws -> String {
        try await complete(system: TranslationPrompt.auto, user: text)
    }

    func translate(text: String, from: String?, to: String) async throws -> String {
        try await complete(system: TranslationPrompt.generic(from: from, to: to), user: text)
    }

    // MARK: - HTTP

    private func endpoint() -> URL? {
        let custom = settings.backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return URL(string: custom) }
        return URL(string: "https://api.anthropic.com/v1/messages")
    }

    private func complete(system: String, user: String) async throws -> String {
        let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        let usingCustomBackend = !settings.backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usingCustomBackend || !apiKey.isEmpty else { throw TranslationError.missingAPIKey }

        guard let url = endpoint() else { throw TranslationError.api("Nieprawidłowy adres API") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body: [String: Any] = [
            "model": settings.model.rawValue,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "system": system,
            "messages": [
                ["role": "user", "content": trimmed]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotConnectToHost:
                throw TranslationError.noInternet
            case .timedOut:
                throw TranslationError.api("Przekroczono czas oczekiwania — spróbuj ponownie")
            default:
                throw TranslationError.api(error.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw TranslationError.decoding }

        guard (200...299).contains(http.statusCode) else {
            // Surface a short, non-sensitive message; never log the message body.
            let apiMessage = Self.extractAPIErrorMessage(from: data)
            switch http.statusCode {
            case 401: throw TranslationError.api("Nieprawidłowy klucz API (401)")
            case 429: throw TranslationError.api("Za dużo zapytań — spróbuj za chwilę (429)")
            default:  throw TranslationError.api(apiMessage ?? "Błąd serwera (\(http.statusCode))")
            }
        }

        guard let text = Self.extractText(from: data) else { throw TranslationError.decoding }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pulls the concatenated text blocks out of an Anthropic Messages response.
    private static func extractText(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else { return nil }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        return text.isEmpty ? nil : text
    }

    private static func extractAPIErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else { return nil }
        return message
    }
}

// MARK: - Developer mock (NOT the production path)

/// Returns a fake translation without any network call. Useful for building UI
/// and for App Review demos when no key is configured. Enable via Settings.
final class MockTranslationService: TranslationService {
    func detectAndTranslateToPolish(text: String) async throws -> String {
        try await fake("[PL] \(text)")
    }
    func translatePolishReplyToEnglish(text: String) async throws -> String {
        try await fake("[EN] \(text)")
    }
    func autoDetectAndTranslate(text: String) async throws -> String {
        try await fake("[AUTO] \(text)")
    }
    func translate(text: String, from: String?, to: String) async throws -> String {
        try await fake("[\(to)] \(text)")
    }
    private func fake(_ s: String) async throws -> String {
        try? await Task.sleep(nanoseconds: 350_000_000)
        return s
    }
}

/// Factory that returns the configured service.
enum TranslationServiceFactory {
    static func make(settings: AppGroupSettings) -> TranslationService {
        settings.useMockService ? MockTranslationService() : AnthropicTranslationService(settings: settings)
    }
}
