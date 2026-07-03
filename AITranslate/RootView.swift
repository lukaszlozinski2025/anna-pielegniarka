import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            OnboardingView()
                .tabItem { Label("Start", systemImage: "keyboard") }

            TestTranslateView()
                .tabItem { Label("Test", systemImage: "character.bubble") }

            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView().environmentObject(AppGroupSettings.shared)
}
