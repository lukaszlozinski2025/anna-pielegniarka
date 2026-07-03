import Foundation

/// Central place for identifiers shared between the main app and the keyboard
/// extension. If you change the bundle identifiers or the App Group, update
/// them here AND in the target settings / entitlements files.
enum AppGroup {
    /// Must match the App Group capability enabled on BOTH targets.
    static let identifier = "group.com.redmal.aitranslate"

    /// Shared UserDefaults suite backed by the App Group container.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
