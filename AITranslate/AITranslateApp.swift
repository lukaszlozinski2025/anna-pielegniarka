import SwiftUI

@main
struct AITranslateApp: App {
    @StateObject private var settings = AppGroupSettings.shared

    init() {
        AppGroupSettings.shared.load()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
