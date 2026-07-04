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
    /// Drives the gyroscope-tracked glint on the round top-strip buttons.
    @StateObject private var tilt = TiltMotion()

    private var pal: KBPalette { KBPalette.forScheme(scheme) }

    var body: some View {
        VStack(spacing: 5) {
            // The strip is transparent (no grey bar) — the two glass CTA circles
            // float over the host app above the keyboard body.
            topStrip
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }

    /// The grey keyboard body: options / typing / result. The neon flag rim and
    /// the solid ground live here (not on the transparent strip above).
    private var contentArea: some View {
        Group {
            if model.expanded {
                optionsCard
            } else if model.showKeyboard {
                typingArea
            } else {
                resultCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pal.bg)
        // Neon "flag rim": the panel looks laid on top of the target language's
        // flag, only the horizontal bands peeking at the edges (PL = white/red).
        .neonFlagRim(for: model.outputLang)
    }

    private var typingArea: some View {
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
    }

    // MARK: - Top strip
    //
    // Transparent (no grey bar): just two big glass circular CTAs floating over
    // the host — options (hamburger) on the left, the keyboard show/hide toggle
    // on the right. The mandatory next-keyboard globe lives in the QWERTY's
    // bottom row, so it isn't duplicated here.

    private var topStrip: some View {
        HStack(spacing: 8) {
            circleControl(
                icon: model.expanded ? "xmark" : "slider.horizontal.3",
                iconTint: model.expanded ? pal.accent : pal.keyText,
                glow: model.expanded,
                action: model.toggleExpand
            )
            .accessibilityLabel("Więcej opcji")

            Spacer()
            if model.busy { ProgressView().tint(pal.accent) }
            keyboardToggleButton
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
    }

    /// Chowa klawiaturę / wysuwa ją z powrotem. Always enabled: collapsing with
    /// no translation yet still works and reveals the result area's placeholder,
    /// so a tap never feels dead. Green glow once collapsed (a translation is on
    /// screen behind the keyboard).
    private var keyboardToggleButton: some View {
        let collapsed = !model.showKeyboard
        return circleControl(
            icon: "keyboard.chevron.compact.down",
            iconTint: collapsed ? pal.accent : pal.keyText,
            glow: collapsed,
            action: { if model.showKeyboard { model.collapseKeyboard() } else { model.expandKeyboard() } }
        )
        .accessibilityLabel(collapsed ? "Wysuń klawiaturę" : "Schowaj klawiaturę, pokaż tłumaczenie")
    }

    /// A big round glass control — frosted `thinMaterial` disc, a lit glass edge,
    /// a soft shadow, a specular glint that tracks the phone's tilt (gyroscope),
    /// a spring press animation and a key-click on tap. The latest-iOS
    /// "liquid glass" button, ~35% larger than a standard bar icon and ~70%
    /// see-through.
    private func circleControl(icon: String, iconTint: Color, glow: Bool,
                               action: @escaping () -> Void) -> some View {
        Button {
            model.playClickSound()
            action()
        } label: {
            ZStack {
                Circle().fill(.thinMaterial)                 // frosted glass (~70% see-through)
                Circle().fill(glow ? pal.accent.opacity(0.16) : Color.white.opacity(0.08))
                TiltGlint(motion: tilt)                      // gyroscope shine
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.9)
            )
            .shadow(color: glow ? pal.accent.opacity(0.45) : .black.opacity(0.14),
                    radius: glow ? 8 : 4, x: 0, y: 2)
        }
        .buttonStyle(PressableCircleStyle())
    }

    // MARK: - Typing mode (big input box above the QWERTY)

    /// Where you compose: multi-line, blinking cursor. Odbierz/Wklej now live
    /// as keys in the QWERTY's bottom row, so this box is full-width text only
    /// (plus the mic-limitation badge in the corner). Typing on
    /// `QwertyKeyboardView` below writes straight into `model.input` — there's
    /// no system-keyboard-editable field here, so this is display-only.
    private var inputBox: some View {
        ScrollView {
            // Text sizes to its content (no maxWidth), so the caret sits right
            // after the last character; the trailing Spacer pushes the whole line
            // to the left. Long text still wraps and grows downward.
            HStack(alignment: .top, spacing: 2) {
                Text(model.input.isEmpty ? "Pisz wiadomość…" : model.input)
                    .font(.system(size: 17))
                    .foregroundStyle(model.input.isEmpty ? pal.dim : pal.fieldText)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.input.isEmpty {
                    BlinkingCursor(color: pal.fieldText)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                if !model.output.isEmpty {
                    Button(action: model.copyResult) {
                        Label("Kopiuj", systemImage: "doc.on.doc.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(pal.keyText)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(pal.bg)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: model.insertResult) {
                        Label("Wstaw", systemImage: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(pal.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            if model.output.isEmpty {
                Spacer()
                Text("Tu pojawi się tłumaczenie.\nNapisz wiadomość i dotknij ➜ albo wklej tekst — potem schowaj klawiaturę.")
                    .font(.system(size: 14))
                    .foregroundStyle(pal.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    Text(model.output)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(pal.translated)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
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

// MARK: - Press feedback

/// Bouncy scale-down on press for the round glass CTAs.
struct PressableCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// A gentler scale-down for pill buttons (Kopiuj / Wstaw / API key).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A subtle press scale for the QWERTY keys, which are gesture-driven (not
/// Buttons, so they can keep tap-vs-long-press arbitration for diacritics). A
/// zero-distance drag runs *simultaneously* — it only tracks the press for the
/// scale and never swallows the tap or the long-press.
struct KeyPressScale: ViewModifier {
    @GestureState private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.11), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
            )
    }
}

extension View {
    func keyPressScale() -> some View { modifier(KeyPressScale()) }
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
