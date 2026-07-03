import SwiftUI

/// A place to test translation without WhatsApp — type text, pick a direction,
/// see the result. Uses the exact same TranslationService as the keyboard.
struct TestTranslateView: View {
    @EnvironmentObject var settings: AppGroupSettings

    @State private var input = ""
    @State private var output = ""
    @State private var direction: TranslationDirection = .auto
    @State private var isBusy = false
    @State private var errorText: String?

    private var service: TranslationService {
        TranslationServiceFactory.make(settings: settings)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Kierunek", selection: $direction) {
                        ForEach(TranslationDirection.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    labeled("Tekst wejściowy") {
                        TextEditor(text: $input)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Theme.text)
                    }

                    Button(action: translate) {
                        HStack {
                            if isBusy { ProgressView().tint(Theme.bg) }
                            Text(isBusy ? "Tłumaczę…" : "Przetłumacz")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isBusy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }

                    if !output.isEmpty {
                        labeled("Wynik") {
                            Text(output)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.text)
                                .textSelection(.enabled)
                        }
                    }

                    if !settings.isConfigured {
                        Text("Dodaj klucz Anthropic API w zakładce Ustawienia, aby tłumaczyć.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Test tłumaczenia")
            .onAppear { direction = settings.defaultDirection }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.textDim)
            content()
        }
    }

    private func translate() {
        errorText = nil
        output = ""
        isBusy = true
        let text = input
        let dir = direction
        Task {
            do {
                let result: String
                switch dir {
                case .enToPl: result = try await service.detectAndTranslateToPolish(text: text)
                case .plToEn: result = try await service.translatePolishReplyToEnglish(text: text)
                case .auto:   result = try await service.autoDetectAndTranslate(text: text)
                }
                await MainActor.run {
                    output = result
                    isBusy = false
                    settings.addToHistory(TranslationRecord(source: text, result: result, direction: dir))
                }
            } catch {
                await MainActor.run {
                    errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
                    isBusy = false
                }
            }
        }
    }
}

#Preview {
    TestTranslateView().environmentObject(AppGroupSettings.shared)
}
