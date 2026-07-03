import SwiftUI

struct PrivacyView: View {
    private let points: [(String, String)] = [
        ("hand.tap", "Teksty są wysyłane do API tłumaczenia tylko wtedy, gdy sam dotkniesz przycisku tłumaczenia. Nic nie jest tłumaczone automatycznie."),
        ("doc.on.clipboard", "Schowek jest odczytywany dopiero po dotknięciu „Wklej ze schowka” — klawiatura nie czyta schowka w tle."),
        ("eye.slash", "Klawiatura nie odczytuje całej rozmowy z WhatsAppa. Widzi tylko tekst, który sam wkleisz lub wpiszesz."),
        ("clock.arrow.circlepath", "Historia tłumaczeń jest domyślnie wyłączona. Po włączeniu zapisujemy je tylko lokalnie na tym urządzeniu."),
        ("network", "Do tłumaczenia potrzebny jest internet (Pełny dostęp klawiatury). Zapytania trafiają do Anthropic API lub do Twojego własnego Backend URL."),
        ("paperplane", "Klawiatura tylko wkleja tekst do aktywnego pola. Nie wysyła wiadomości za Ciebie — przycisk wysyłania zawsze klikasz sam.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Jak dbamy o Twoją prywatność")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.text)

                ForEach(points, id: \.0) { point in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: point.0)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28)
                        Text(point.1)
                            .font(.subheadline)
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(Theme.bg)
        .navigationTitle("Prywatność")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
