import SwiftUI

/// Light, native-looking keyboard styled after the iOS system keyboard:
/// light-grey ground, white rounded "keys" with a hard 1pt bottom shadow, black
/// text, and a WhatsApp-green primary action. Fills the standard keyboard height.
///
/// Three states, switched purely on `model.expanded` / `model.output`:
/// - options open → `optionsCard`
/// - no translation yet → preview line + `QwertyKeyboardView` (type here)
/// - translated → `resultCard` (Kopiuj / Wstaw) + "Pisz nową wiadomość"
struct KeyboardView: View {
    @ObservedObject var model: KeyboardViewModel
    @Environment(\.colorScheme) private var scheme

    private var pal: KBPalette { KBPalette.forScheme(scheme) }

    var body: some View {
        VStack(spacing: 0) {
            topStrip
            Rectangle().fill(pal.hairline).frame(height: 0.5)

            Group {
                if model.expanded {
                    optionsCard
                } else if model.output.isEmpty {
                    VStack(spacing: 8) {
                        previewBar
                        QwertyKeyboardView(model: model, pal: pal)
                    }
                } else {
                    VStack(spacing: 8) {
                        resultCard
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        resultActions
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pal.bg)
    }

    // MARK: - Top strip (suggestion-bar style)

    private var topStrip: some View {
        HStack(spacing: 8) {
            if model.needsNextKeyboardButton {
                Button(action: model.advanceKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(pal.dim)
                        .frame(width: 30, height: 34)
                }
                .accessibilityLabel("Następna klawiatura")
            }
            Text("AI Translate")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pal.dim)
            if let indicator = model.langIndicator {
                Text(indicator)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pal.keyText)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(pal.key)
                    .clipShape(Capsule())
            }
            Spacer()
            if model.busy { ProgressView().scaleEffect(0.7).tint(pal.accent) }
            Button(action: model.toggleExpand) {
                Image(systemName: model.expanded ? "chevron.down" : "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(pal.dim)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Więcej opcji")
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }

    // MARK: - Typing mode (preview line above the QWERTY)

    /// Shows what's queued in `model.input` plus two shortcuts that skip typing
    /// entirely: paste a copied message, or pull in a WhatsApp draft (typed or
    /// dictated there) for cleanup. Typing on `QwertyKeyboardView` below writes
    /// straight into `model.input` — there's no on-screen field to tap into here.
    private var previewBar: some View {
        HStack(spacing: 8) {
            Text(model.input.isEmpty ? "Pisz wiadomość…" : model.input)
                .font(.system(size: 13))
                .foregroundStyle(model.input.isEmpty ? pal.dim : pal.fieldText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: model.pasteFromClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.dim)
            }
            .buttonStyle(.plain)
            Button(action: model.loadFromWhatsApp) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pal.dim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(pal.field)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(pal.hairline, lineWidth: 0.5))
    }

    // MARK: - Result mode

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tłumaczenie")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pal.dim)
                Spacer()
                Button(action: model.copyResult) {
                    Label("Kopiuj", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(pal.dim)
                }
                .buttonStyle(.plain)
                Button(action: model.insertResult) {
                    Label("Wstaw", systemImage: "paperplane.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(pal.accent)
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(model.output)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(pal.fieldText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            if let status = model.status {
                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(status.hasPrefix("Wstawiono") || status.hasPrefix("Skopiowano") ? pal.accent : pal.danger)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(pal.key)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    /// Copy the result, paste it into WhatsApp yourself (long-press → Wklej), then
    /// tap this to clear the result and go back to typing the next message.
    private var resultActions: some View {
        Button(action: model.clearAll) {
            Label("Pisz nową wiadomość", systemImage: "square.and.pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.keyText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(pal.key)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .keyShadow(pal)
        }
        .buttonStyle(.plain)
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Opcje").font(.system(size: 11, weight: .semibold)).foregroundStyle(pal.dim)

            HStack {
                Text("Kierunek").font(.system(size: 14)).foregroundStyle(pal.fieldText)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.mode == .auto },
                    set: { model.mode = $0 ? .auto : .manual }
                )) {
                    Text("Auto").tag(true)
                    Text("Ręczny").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            if model.mode == .manual {
                Toggle("Tłumacz na polski", isOn: $model.manualToPolish)
                    .font(.system(size: 14))
                    .tint(pal.accent)
                    .foregroundStyle(pal.fieldText)
            }
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Klucz Anthropic API").font(.system(size: 11, weight: .semibold)).foregroundStyle(pal.dim)
                if model.hasAPIKey {
                    HStack {
                        Label("Zapisany", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(pal.accent)
                        Spacer()
                        Button("Usuń", role: .destructive, action: model.clearAPIKey)
                            .font(.system(size: 13)).tint(pal.danger)
                    }
                } else {
                    Button(action: model.pasteAPIKey) {
                        Label("Wklej klucz ze schowka", systemImage: "key.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(pal.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(pal.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    Text("Skopiuj swój klucz sk-ant-… i dotknij powyżej. Wymaga włączonego Pełnego dostępu.")
                        .font(.system(size: 11)).foregroundStyle(pal.dim)
                }
            }

            HStack {
                Text("Model: \(model.settings.model.badge)")
                    .font(.system(size: 13)).foregroundStyle(pal.dim)
                Spacer()
                Button("Wyczyść tekst", role: .destructive, action: model.clearAll)
                    .font(.system(size: 13))
                    .tint(pal.danger)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pal.key)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Palette + key shadow

struct KBPalette {
    let bg: Color, key: Color, keyText: Color, accent: Color, accentText: Color
    let field: Color, fieldText: Color, dim: Color, hairline: Color, danger: Color

    static func forScheme(_ scheme: ColorScheme) -> KBPalette {
        if scheme == .dark {
            return KBPalette(
                bg: Color(hex: 0x1C1C1E), key: Color(hex: 0x3A3A3C), keyText: .white,
                accent: Color(hex: 0x25D366), accentText: .white,
                field: Color(hex: 0x2C2C2E), fieldText: .white,
                dim: Color(hex: 0x9AA0A8), hairline: .white.opacity(0.12), danger: Color(hex: 0xFF6B81)
            )
        }
        return KBPalette(
            bg: Color(hex: 0xD1D4DB), key: .white, keyText: Color(hex: 0x1C1C1E),
            accent: Color(hex: 0x25D366), accentText: .white,
            field: .white, fieldText: Color(hex: 0x1C1C1E),
            dim: Color(hex: 0x6B7280), hairline: .black.opacity(0.10), danger: Color(hex: 0xE0245E)
        )
    }
}

private extension View {
    /// The hard 1pt bottom shadow iOS keys have.
    func keyShadow(_ pal: KBPalette) -> some View {
        shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
    }
}
