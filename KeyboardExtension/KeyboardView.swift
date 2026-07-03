import SwiftUI

/// Compact keyboard panel. One input, three CTAs in a row (Wklej / Przetłumacz /
/// mode chip), and contextual output + insert. Extra options live behind "więcej".
struct KeyboardView: View {
    @ObservedObject var model: KeyboardViewModel

    var body: some View {
        VStack(spacing: 7) {
            topBar

            // Single input — paste into it or type your reply.
            TextField("Wpisz lub wklej tekst…", text: $model.input, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Three CTAs in one row.
            HStack(spacing: 7) {
                cta("Wklej", icon: "doc.on.clipboard", filled: false, weight: 3) { model.pasteFromClipboard() }
                cta("Przetłumacz", icon: "sparkles", filled: true, weight: 4) { model.translate() }
                modeChip
            }

            // Only show the result + insert when there is one.
            if !model.output.isEmpty {
                HStack(spacing: 7) {
                    Text(model.output)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button(action: model.insertResult) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 46, height: 40)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Wstaw do WhatsApp")
                }
            }

            if let status = model.status {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(status.hasPrefix("Wstawiono") ? Theme.accent : Theme.danger)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.expanded { moreOptions }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.bg)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            if model.needsNextKeyboardButton {
                Button(action: model.advanceKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 28, height: 26)
                }
                .accessibilityLabel("Następna klawiatura")
            }
            Text("AI Translate")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)

            if let indicator = model.langIndicator {
                Text(indicator)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.card)
                    .clipShape(Capsule())
            }

            Spacer()
            if model.busy { ProgressView().scaleEffect(0.7).tint(Theme.accent) }

            Button(action: model.toggleExpand) {
                Image(systemName: model.expanded ? "chevron.up" : "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 28, height: 26)
            }
            .accessibilityLabel("Więcej opcji")
        }
    }

    // MARK: - Mode chip (Auto ⇄ manual switch)

    private var modeChip: some View {
        let manual = model.mode == .manual
        return Text(model.modeLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(manual ? Theme.bg : Theme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 76, height: 40)
            .background(manual ? Theme.accent : Theme.accent.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.accent.opacity(manual ? 0 : 0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { model.tapMode() }
            .onLongPressGesture(minimumDuration: 1.0) { model.toggleMode() }
    }

    // MARK: - Expanded options

    private var moreOptions: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Kierunek")
                    .font(.caption).foregroundStyle(Theme.textDim)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.mode == .auto },
                    set: { model.mode = $0 ? .auto : .manual }
                )) {
                    Text("Auto").tag(true)
                    Text("Ręczny").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            if model.mode == .manual {
                Toggle("Tłumacz na polski", isOn: $model.manualToPolish)
                    .font(.caption)
                    .tint(Theme.accent)
            }
            HStack {
                Text("Model: \(model.settings.model.badge)")
                    .font(.caption2).foregroundStyle(Theme.textDim)
                Spacer()
                Button("Wyczyść", role: .destructive, action: model.clearAll)
                    .font(.caption.weight(.semibold))
                    .tint(Theme.danger)
            }
        }
        .padding(10)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - CTA builder

    private func cta(_ title: String, icon: String, filled: Bool, weight: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .foregroundStyle(filled ? Theme.bg : Theme.accent)
            .background(filled ? Theme.accent : Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .layoutPriority(weight)
    }
}
