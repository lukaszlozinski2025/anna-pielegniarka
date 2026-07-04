import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var settings: AppGroupSettings
    @State private var records: [TranslationRecord] = []

    var body: some View {
        List {
            if records.isEmpty {
                Text("Brak zapisanych tłumaczeń.")
                    .foregroundStyle(Theme.textDim)
            }
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.direction.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(record.source)
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(2)
                    Text(record.result)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(3)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Historia")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Wyczyść") {
                    settings.clearHistory()
                    records = []
                }
                .disabled(records.isEmpty)
            }
        }
        .onAppear { records = settings.history() }
    }
}

#Preview {
    NavigationStack { HistoryView() }.environmentObject(AppGroupSettings.shared)
}
