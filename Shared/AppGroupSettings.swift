import Foundation
import Combine

/// Configuration shared between the main app and the keyboard extension via the
/// App Group's UserDefaults. The main app writes it on the Settings screen; the
/// keyboard reads it at launch.
///
/// Privacy: message history is OFF by default and only stored when the user
/// explicitly enables it. Nothing here logs full message bodies.
final class AppGroupSettings: ObservableObject {
    static let shared = AppGroupSettings()

    private let defaults: UserDefaults

    private enum Key {
        static let apiKey = "anthropicAPIKey"
        static let backendURL = "backendURL"
        static let model = "model"
        static let direction = "defaultDirection"
        static let devMock = "useMockService"
        static let historyEnabled = "historyEnabled"
        static let history = "history"
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    // MARK: - Stored configuration

    @Published var apiKey: String = "" { didSet { defaults.set(apiKey, forKey: Key.apiKey) } }

    /// Optional custom backend URL. When empty, the Anthropic API is called directly.
    @Published var backendURL: String = "" { didSet { defaults.set(backendURL, forKey: Key.backendURL) } }

    @Published var model: ClaudeModel = .haiku { didSet { defaults.set(model.rawValue, forKey: Key.model) } }

    @Published var defaultDirection: TranslationDirection = .auto {
        didSet { defaults.set(defaultDirection.rawValue, forKey: Key.direction) }
    }

    /// Developer-only mock mode (returns a fake translation, no network). Not the
    /// production path — the real path goes through the Anthropic API.
    @Published var useMockService: Bool = false { didSet { defaults.set(useMockService, forKey: Key.devMock) } }

    @Published var historyEnabled: Bool = false {
        didSet {
            defaults.set(historyEnabled, forKey: Key.historyEnabled)
            if !historyEnabled { clearHistory() }
        }
    }

    /// Loads persisted values. Call once on app / keyboard launch.
    func load() {
        apiKey = defaults.string(forKey: Key.apiKey) ?? ""
        backendURL = defaults.string(forKey: Key.backendURL) ?? ""
        if let raw = defaults.string(forKey: Key.model), let m = ClaudeModel(rawValue: raw) {
            model = m
        }
        if let raw = defaults.string(forKey: Key.direction), let d = TranslationDirection(rawValue: raw) {
            defaultDirection = d
        }
        useMockService = defaults.bool(forKey: Key.devMock)
        historyEnabled = defaults.bool(forKey: Key.historyEnabled)
    }

    // MARK: - Optional history

    func history() -> [TranslationRecord] {
        guard historyEnabled, let data = defaults.data(forKey: Key.history) else { return [] }
        return (try? JSONDecoder().decode([TranslationRecord].self, from: data)) ?? []
    }

    func addToHistory(_ record: TranslationRecord) {
        guard historyEnabled else { return }
        var items = history()
        items.insert(record, at: 0)
        if items.count > 50 { items = Array(items.prefix(50)) }
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Key.history)
        }
    }

    func clearHistory() {
        defaults.removeObject(forKey: Key.history)
    }

    /// Config valid enough to attempt a real translation?
    var isConfigured: Bool {
        useMockService || !apiKey.isEmpty || !backendURL.isEmpty
    }
}
