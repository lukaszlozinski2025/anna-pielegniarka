import SwiftUI

/// A compact, iOS-styled QWERTY that types into the keyboard's own local text
/// buffer (`model.input`) rather than directly into the host app. A keyboard
/// extension can't summon a system keyboard for a field of its own, so this is
/// how composing a message inside AI Translate itself becomes possible: type
/// your reply here, tap the green translate key, and the result is ready to
/// copy or insert into WhatsApp.
///
/// Long-press a letter for its Polish diacritic (a→ą, c→ć, e→ę, l→ł, n→ń, o→ó,
/// s→ś, z→ź/ż).
struct QwertyKeyboardView: View {
    @ObservedObject var model: KeyboardViewModel
    let pal: KBPalette

    @State private var shift = false
    @State private var symbolsPage = false
    @State private var diacritic: (key: String, options: [String])?

    private let row1Letters = ["q","w","e","r","t","y","u","i","o","p"]
    private let row2Letters = ["a","s","d","f","g","h","j","k","l"]
    private let row3Letters = ["z","x","c","v","b","n","m"]

    private let row1Symbols = ["1","2","3","4","5","6","7","8","9","0"]
    private let row2Symbols = ["-","/",":",";","(",")","zł","&","\""]
    private let row3Symbols = [".",",","?","!","'"]

    private let diacriticMap: [String: [String]] = [
        "a": ["ą"], "c": ["ć"], "e": ["ę"], "l": ["ł"],
        "n": ["ń"], "o": ["ó"], "s": ["ś"], "z": ["ź", "ż"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            keyRow(symbolsPage ? row1Symbols : row1Letters)
            HStack(spacing: 6) {
                Spacer(minLength: 12)
                keyRow(symbolsPage ? row2Symbols : row2Letters)
                Spacer(minLength: 12)
            }
            HStack(spacing: 6) {
                if !symbolsPage {
                    utilityKey(icon: shift ? "shift.fill" : "shift", width: 38) {
                        shift.toggle()
                        model.playClickSound()
                    }
                }
                keyRow(symbolsPage ? row3Symbols : row3Letters)
                utilityKey(icon: "delete.left.fill", width: 38) { model.backspace() }
            }
            HStack(spacing: 6) {
                textKey(symbolsPage ? "ABC" : "123", width: 48) {
                    symbolsPage.toggle()
                    model.playClickSound()
                }
                if model.needsNextKeyboardButton {
                    utilityKey(icon: "globe", width: 34) { model.advanceKeyboard() }
                }
                spaceKey
                translateKey
            }
        }
    }

    // MARK: - Rows

    private func keyRow(_ letters: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(letters, id: \.self) { letter in
                letterKey(letter)
            }
        }
    }

    private func letterKey(_ base: String) -> some View {
        let display = symbolsPage ? base : (shift ? base.uppercased() : base)
        let options = symbolsPage ? nil : diacriticMap[base]
        return ZStack(alignment: .top) {
            Text(display)
                .font(.system(size: base.count > 1 ? 14 : 20, weight: .regular))
                .foregroundStyle(pal.keyText)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(pal.key)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.typeCharacter(display)
                    if shift { shift = false }
                }
                .onLongPressGesture(minimumDuration: 0.35) {
                    if let opts = options { diacritic = (base, opts) }
                }

            if let d = diacritic, d.key == base {
                HStack(spacing: 4) {
                    ForEach(d.options, id: \.self) { opt in
                        let shown = shift ? opt.uppercased() : opt
                        Text(shown)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(pal.keyText)
                            .frame(width: 34, height: 34)
                            .background(pal.key)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.typeCharacter(shown)
                                diacritic = nil
                                if shift { shift = false }
                            }
                    }
                }
                .padding(4)
                .background(pal.field)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                .offset(y: -44)
                .zIndex(1)
            }
        }
    }

    // MARK: - Utility keys

    private func utilityKey(icon: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(pal.keyText)
            .frame(width: width, height: 40)
            .background(pal.key)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private func textKey(_ title: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(pal.keyText)
            .frame(width: width, height: 40)
            .background(pal.key)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var spaceKey: some View {
        Text("spacja")
            .font(.system(size: 14))
            .foregroundStyle(pal.keyText)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(pal.key)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
            .contentShape(Rectangle())
            .onTapGesture { model.typeCharacter(" ") }
    }

    private var translateKey: some View {
        Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(pal.accentText)
            .frame(width: 52, height: 40)
            .background(pal.accent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { model.translate() }
    }
}
