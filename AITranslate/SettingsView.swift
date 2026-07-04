import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppGroupSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Anthropic API Key (sk-ant-…)", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Backend URL (opcjonalnie)", text: $settings.backendURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Klucz API")
                } footer: {
                    Text("Klucz jest zapisywany lokalnie i wysyłany tylko do Anthropic API. Uwaga: na darmowym koncie Apple klawiatura ma osobny klucz — wpisz/​wklej go też w samej klawiaturze (opcje „⚙”). Ten klucz tutaj działa dla ekranu Test.")
                }

                Section("Model") {
                    Picker("Model", selection: $settings.model) {
                        ForEach(ClaudeModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                }

                Section("Domyślny kierunek tłumaczenia") {
                    Picker("Kierunek", selection: $settings.defaultDirection) {
                        ForEach(TranslationDirection.allCases, id: \.self) { dir in
                            Text(dir.label).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Historia tłumaczeń", isOn: $settings.historyEnabled)
                    if settings.historyEnabled {
                        NavigationLink("Pokaż historię") { HistoryView() }
                    }
                } header: {
                    Text("Prywatność")
                } footer: {
                    Text("Historia jest domyślnie wyłączona. Po włączeniu ostatnie tłumaczenia są zapisywane tylko na tym urządzeniu.")
                }

                Section {
                    Toggle("Tryb deweloperski (mock, bez internetu)", isOn: $settings.useMockService)
                } footer: {
                    Text("Zwraca sztuczne tłumaczenie do testów UI. W normalnym użyciu pozostaw wyłączone — tłumaczenie idzie przez Anthropic API (Claude Haiku).")
                }

                Section {
                    NavigationLink { PrivacyView() } label: {
                        Label("Polityka prywatności", systemImage: "lock.shield")
                    }
                }
            }
            .navigationTitle("Ustawienia")
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
        }
    }
}

#Preview {
    SettingsView().environmentObject(AppGroupSettings.shared)
}
