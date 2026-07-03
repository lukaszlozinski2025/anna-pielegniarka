import SwiftUI

/// Explains how to enable and use the keyboard. This is the first thing the user
/// sees. Steps mirror the real iOS Settings path.
struct OnboardingView: View {
    private let enableSteps: [(String, String)] = [
        ("1", "Otwórz Ustawienia iPhone."),
        ("2", "Wejdź w Ogólne → Klawiatura → Klawiatury."),
        ("3", "Dotknij „Dodaj nową klawiaturę…”."),
        ("4", "Wybierz „AI Translate” z listy."),
        ("5", "Dotknij „AI Translate” ponownie i włącz „Zezwól na pełny dostęp”. Jest wymagany, bo tłumaczenie AI działa przez internet.")
    ]

    private let useSteps: [(String, String)] = [
        ("1", "Otwórz WhatsApp i wejdź w dowolną rozmowę."),
        ("2", "Dotknij pola pisania wiadomości."),
        ("3", "Przytrzymaj ikonę globusa 🌐 na klawiaturze i wybierz „AI Translate”."),
        ("4", "Skopiuj wiadomość rozmówcy, dotknij „Wklej ze schowka”, a potem „EN → PL” lub „Auto”."),
        ("5", "Wpisz odpowiedź po polsku, dotknij „PL → EN”, a potem „Wstaw do WhatsApp”.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    section(title: "1. Włącz klawiaturę", icon: "keyboard.badge.ellipsis", steps: enableSteps)
                    section(title: "2. Używaj w WhatsApp", icon: "bubble.left.and.text.bubble.right", steps: useSteps)

                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("Prywatność", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("AI Translate")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🌐 Klawiatura AI do tłumaczenia")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.text)
            Text("Tłumacz wiadomości w WhatsAppie, Messengerze, Mailu i innych aplikacjach — bezpośrednio z klawiatury, bez przełączania aplikacji.")
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func section(title: String, icon: String, steps: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Theme.text)

            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text(step.0)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 24, height: 24)
                        .background(Theme.accent)
                        .clipShape(Circle())
                    Text(step.1)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    OnboardingView().environmentObject(AppGroupSettings.shared)
}
