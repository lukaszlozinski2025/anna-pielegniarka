import Foundation

/// Identifiers shared between the main app and the keyboard extension.
///
/// NOTE: App Groups require a paid Apple Developer Program membership. To let
/// the app run on a **free** Apple ID (Personal Team), we do NOT use an App
/// Group container — each process (app / keyboard) keeps its own
/// `UserDefaults.standard`, and the keyboard gets its own API key (pasted into
/// the keyboard's options). When you move to a paid account you can re-add the
/// App Group capability on both targets and switch `defaults` back to
/// `UserDefaults(suiteName: identifier)` to share settings again.
enum AppGroup {
    static let identifier = "group.com.redmal.aitranslate"

    /// Per-process defaults (no App Group needed → works on a free Apple ID).
    static var defaults: UserDefaults { .standard }
}
