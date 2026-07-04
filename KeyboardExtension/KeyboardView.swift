import SwiftUI

/// Light, native-looking keyboard styled after the iOS system keyboard:
/// light-grey ground, white rounded "keys" with a hard 1pt bottom shadow, black
/// text, and a WhatsApp-green primary action. Fills the standard keyboard height.
///
/// Three states, switched on `model.expanded` / `model.showKeyboard`:
/// - options open → `optionsCard`
/// - `showKeyboard == true` → `inputBox` (type here, big font, blinking cursor,
///   Wklej/Odbierz) + `QwertyKeyboardView`
/// - `showKeyboard == false` → `resultCard` alone, filling the whole area like
///   the keyboard did — the blue translation, Kopiuj/Wstaw
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
                } else if model.showKeyboard {
                    VStack(spacing: 6) {
                        inputBox
                        if let status = model.status {
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(pal.dim)
                                .lineLimit(2)
                        }
                        QwertyKeyboardView(model: model, pal: pal)
                    }
                    .overlay(alignment: .topTrailing) {
                        if model.showLangBadge, let f = model.detectedForeign {
                            Text("\(f.flag) \(f.badge) wykryto")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(pal.keyText)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(pal.key.opacity(0.55))
                                .clipShape(Capsule())
                                .offset(y: -13)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: model.showLangBadge)
                } else {
                    resultCard
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pal.bg)
        // Neon "flag rim": the panel looks laid on top of the target language's
        // flag, only the horizontal bands peeking at the edges (PL = white/red).
        .neonFlagRim(for: model.outputLang)
    }

    // MARK: - Top strip
    //
    // A transparent strip (no solid bar) with two circular, ~50%-frosted CTA
    // buttons "punched" into it: options (hamburger) on the left, the keyboard
    // show/hide toggle on the right. The mandatory next-keyboard globe tucks in
    // beside the hamburger only when the system requires it.

    private var topStrip: some View {
        HStack(spacing: 8) {
            circleControl(
                icon: model.expanded ? "chevron.down" : "slider.horizontal.3",
                tint: pal.dim,
                fill: pal.key.opacity(0.5),
                glow: false,
                action: model.toggleExpand
            )
            .accessibilityLabel("Więcej opcji")

            if model.needsNextKeyboardButton {
                circleControl(
                    icon: "globe",
                    tint: pal.dim,
                    fill: pal.key.opacity(0.5),
                    glow: false,
                    action: model.advanceKeyboard
                )
                .accessibilityLabel("Następna klawiatura")
            }

            Spacer()
            if model.busy { ProgressView().scaleEffect(0.7).tint(pal.accent) }
            keyboardToggleButton
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }

    /// Chowa klawiaturę / wysuwa ją z powrotem — patrz `KeyboardViewModel.collapseKeyboard()`
    /// i `.expandKeyboard()`. Same "keyboard" glyph both ways; only the highlight
    /// changes — a muted frosted circle while the QWERTY is showing, a soft green
    /// glow once collapsed (there's a translation waiting behind it).
    private var keyboardToggleButton: some View {
        let collapsed = !model.showKeyboard
        let disabled = model.showKeyboard && model.output.isEmpty
        return circleControl(
            icon: "keyboard",
            tint: collapsed ? pal.accent : pal.dim.opacity(disabled ? 0.4 : 0.9),
            fill: collapsed ? pal.accent.opacity(0.5) : pal.key.opacity(0.5),
            glow: collapsed,
            action: { if model.showKeyboard { model.collapseKeyboard() } else { model.expandKeyboard() } }
        )
        .disabled(disabled)
        .accessibilityLabel(collapsed ? "Wysuń klawiaturę" : "Schowaj klawiaturę, pokaż tłumaczenie")
    }

    /// A round, semi-transparent control button — the frosted "cut-out" look for
    /// the top strip.
    private func circleControl(icon: String, tint: Color, fill: Color, glow: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(fill)
                .clipShape(Circle())
                .overlay(Circle().stroke(pal.hairline, lineWidth: 0.5))
                .shadow(color: glow ? pal.accent.opacity(0.4) : .clear, radius: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Typing mode (big input box above the QWERTY)

    /// Where you compose: multi-line, blinking cursor. Odbierz/Wklej now live
    /// as keys in the QWERTY's bottom row, so this box is full-width text only
    /// (plus the mic-limitation badge in the corner). Typing on
    /// `QwertyKeyboardView` below writes straight into `model.input` — there's
    /// no system-keyboard-editable field here, so this is display-only.
    private var inputBox: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 3) {
                Text(model.input.isEmpty ? "Pisz wiadomość…" : model.input)
                    .font(.system(size: 17))
                    .foregroundStyle(model.input.isEmpty ? pal.dim : pal.fieldText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.input.isEmpty {
                    BlinkingCursor(color: pal.fieldText)
                }
            }
            .padding(.trailing, 22)
        }
        .frame(height: 56)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(pal.field)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.hairline, lineWidth: 0.5))
        .overlay(alignment: .topTrailing) {
            Button(action: model.explainMicLimitation) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(pal.dim)
                    .padding(5)
                    .background(pal.bg.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    // MARK: - Result mode (fills the whole area, same footprint as the QWERTY)

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tłumaczenie")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pal.dim)
                Spacer()
                Button(action: model.copyResult) {
                    Label("Kopiuj", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(pal.keyText)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(pal.bg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(action: model.insertResult) {
                    Label("Wstaw", systemImage: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(pal.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(model.output)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(pal.translated)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            if let status = model.status {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(status.hasPrefix("Wstawiono") || status.hasPrefix("Skopiowano") ? pal.accent : pal.danger)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pal.key)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Opcje").font(.system(size: 11, weight: .semibold)).foregroundStyle(pal.dim)

            HStack {
                Text("Język rozmowy").font(.system(size: 11, weight: .semibold)).foregroundStyle(pal.dim)
                Spacer()
                if let f = model.detectedForeign {
                    Text("\(f.flag) \(f.name) ⇄ 🇵🇱 polski")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(pal.fieldText)
                } else {
                    Text("zostanie wykryty automatycznie")
                        .font(.system(size: 12)).foregroundStyle(pal.dim)
                }
            }

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
    /// Translated result text is always this blue, regardless of scheme.
    let translated: Color

    static func forScheme(_ scheme: ColorScheme) -> KBPalette {
        if scheme == .dark {
            return KBPalette(
                bg: Color(hex: 0x1C1C1E), key: Color(hex: 0x3A3A3C), keyText: .white,
                accent: Color(hex: 0x25D366), accentText: .white,
                field: Color(hex: 0x2C2C2E), fieldText: .white,
                dim: Color(hex: 0x9AA0A8), hairline: .white.opacity(0.12), danger: Color(hex: 0xFF6B81),
                translated: Color(hex: 0x0A84FF)
            )
        }
        return KBPalette(
            bg: Color(hex: 0xD1D4DB), key: .white, keyText: Color(hex: 0x1C1C1E),
            accent: Color(hex: 0x25D366), accentText: .white,
            field: .white, fieldText: Color(hex: 0x1C1C1E),
            dim: Color(hex: 0x6B7280), hairline: .black.opacity(0.10), danger: Color(hex: 0xE0245E),
            translated: Color(hex: 0x007AFF)
        )
    }
}

/// A simple caret that blinks like the system text cursor, placed after the
/// composed text in `inputBox` while there's something typed.
private struct BlinkingCursor: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 20)
            .opacity(visible ? 1 : 0)
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                visible.toggle()
            }
    }
}
