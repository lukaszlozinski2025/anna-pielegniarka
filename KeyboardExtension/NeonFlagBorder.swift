import SwiftUI

// MARK: - Flag band model

/// One horizontal band of a flag, ordered top → bottom. `weight` gives
/// unequal-height flags their true proportions (e.g. Spain's wide gold centre).
///
/// `Equatable` is load-bearing: it lets SwiftUI reuse the rasterised (blurred)
/// rim across the many `KeyboardView` re-renders that a keystroke triggers, so
/// the neon blur is never recomputed while the user types — cheap enough for a
/// memory-constrained keyboard extension.
struct FlagBand: Equatable {
    var color: Color
    var weight: CGFloat = 1
}

// MARK: - LanguageTag → bands catalog

/// Curated horizontal-band colours per language (emoji flags carry no sampleable
/// colours). Genuinely vertical / complex flags (FR, IT, EN/GB) get a faithful
/// *horizontal* reduction so the "top edge = top of flag / bottom edge = bottom
/// of flag" invariant always holds. Unknown language → no bands → the rim stays
/// hidden; any known-but-unmapped code → a brand green→blue neon so it still
/// looks intentional.
///
/// Colours verified against official flag specs.
enum FlagRim {
    static func bands(for lang: LanguageTag) -> [FlagBand] {
        func b(_ hex: UInt32, _ w: CGFloat = 1) -> FlagBand { .init(color: Color(hex: hex), weight: w) }
        switch lang.code.lowercased() {
        case "pl":       return [b(0xFFFFFF), b(0xD4213D)]                        // biały / czerwony
        case "en", "gb": return [b(0x012169), b(0xFFFFFF), b(0xC8102E)]           // granat / biały / czerwony (Union Jack → poziomo)
        case "de":       return [b(0x000000), b(0xDD0000), b(0xFFCE00)]           // czarny / czerwony / złoty
        case "uk", "ua": return [b(0x0057B7), b(0xFFDD00)]                        // niebieski / żółty
        case "ru":       return [b(0xFFFFFF), b(0x0039A6), b(0xD52B1E)]           // biały / niebieski / czerwony
        case "fr":       return [b(0x0055A4), b(0xFFFFFF), b(0xEF4135)]           // pionowa → pozioma redukcja
        case "es":       return [b(0xAA151B, 1), b(0xF1BF00, 2), b(0xAA151B, 1)]  // czerwony / szeroki żółty / czerwony
        case "it":       return [b(0x008C45), b(0xF4F5F0), b(0xCD212A)]           // pionowa → pozioma redukcja
        case "nl":       return [b(0xAE1C28), b(0xFFFFFF), b(0x21468B)]           // czerwony / biały / niebieski
        case "pt":       return [b(0x006600), b(0xDA291C)]                        // zielony / czerwony
        case "cs":       return [b(0xFFFFFF), b(0x11457E), b(0xD7141A)]           // biały / niebieski / czerwony
        case "sk":       return [b(0xFFFFFF), b(0x0B4EA2), b(0xEE1C25)]           // biały / niebieski / czerwony
        case "sv":       return [b(0x006AA7), b(0xFECC00), b(0x006AA7)]           // niebieski / żółty / niebieski
        case "no":       return [b(0xEF2B2D), b(0xFFFFFF), b(0x002868)]           // czerwony / biały / granat
        case "da":       return [b(0xC8102E), b(0xFFFFFF), b(0xC8102E)]           // czerwony / biały / czerwony
        case "fi":       return [b(0xFFFFFF), b(0x003580), b(0xFFFFFF)]           // biały / niebieski / biały
        case "tr":       return [b(0xE30A17), b(0xFFFFFF)]                        // czerwony / biały
        case "ro":       return [b(0x002B7F), b(0xFCD116), b(0xCE1126)]           // niebieski / żółty / czerwony
        case "hu":       return [b(0xCD2A3E), b(0xFFFFFF), b(0x436F4D)]           // czerwony / biały / zielony
        case "el":       return [b(0x0D5EAF), b(0xFFFFFF), b(0x0D5EAF)]           // niebieski / biały / niebieski
        case "lt":       return [b(0xFDB913), b(0x006A44), b(0xC1272D)]           // żółty / zielony / czerwony
        case "lv":       return [b(0x9E3039), b(0xFFFFFF), b(0x9E3039)]           // bordowy / biały / bordowy
        case "et":       return [b(0x0072CE), b(0x000000), b(0xFFFFFF)]           // niebieski / czarny / biały
        case "hr":       return [b(0xDA111F), b(0xFFFFFF), b(0x171796)]           // czerwony / biały / granat
        case "bg":       return [b(0xFFFFFF), b(0x00966E), b(0xD62612)]           // biały / zielony / czerwony
        case "":         return []                                               // nieznany → ukryty
        default:         return [b(0x25D366), b(0x007AFF)]                        // niezmapowany → neon marki
        }
    }
}

// MARK: - Neon split-flag border

/// A modern neon rim that makes the keyboard panel look laid on top of the
/// target language's flag, with only the flag's horizontal bands peeking at the
/// edges. Poland = white (top) over red (bottom).
///
/// Insight: a horizontal-band flag's colour is a function of the vertical
/// coordinate only, `colour = f(y)`. So painting the rounded-rect rim with ONE
/// vertical hard-stop gradient reproduces exactly what "masking a full flag to
/// the rim" would give — top edge = top band, bottom edge = bottom band, both
/// side rails sweep the proportional stack with level seams — at a fraction of
/// the cost. Neon = the same gradient stroked at growing widths + blur, so every
/// band glows in its own hue instead of a flat monochrome shadow.
struct NeonFlagBorder: View {
    var bands: [FlagBand]
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 2
    var glow: CGFloat = 7                     // outer-halo blur radius; also sizes the inset

    /// Ordered `[Color]`, top → bottom, equal-height bands. The plain
    /// "[Color] band list → rim" entry point.
    init(colors: [Color], cornerRadius: CGFloat = 20, lineWidth: CGFloat = 2, glow: CGFloat = 7) {
        self.init(bands: colors.map { FlagBand(color: $0) },
                  cornerRadius: cornerRadius, lineWidth: lineWidth, glow: glow)
    }

    init(bands: [FlagBand], cornerRadius: CGFloat = 20, lineWidth: CGFloat = 2, glow: CGFloat = 7) {
        self.bands = bands
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.glow = glow
    }

    /// Two stops per band at shared boundary locations → hard flag seams (not a
    /// smooth blend); weights keep unequal bands proportional. An empty band list
    /// (unknown language) yields two clear stops so SwiftUI never builds a
    /// zero-stop gradient — the rim is hidden at opacity 0 in that case anyway.
    private var rim: LinearGradient {
        let total = bands.reduce(0) { $0 + $1.weight }
        guard total > 0 else {
            return LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
        }
        var stops: [Gradient.Stop] = []
        var acc: CGFloat = 0
        for band in bands {
            let start = acc / total
            acc += band.weight
            let end = acc / total
            stops.append(Gradient.Stop(color: band.color, location: start))
            stops.append(Gradient.Stop(color: band.color, location: end))
        }
        return LinearGradient(gradient: Gradient(stops: stops), startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // `strokeBorder` insets every stroke fully INSIDE the shape, so the crisp
        // core and all halos share one outer edge and bloom inward — a custom
        // keyboard clips anything past its bounds, so an inner rim is safe.
        // `.padding(glow + 1)` leaves the outward blur room to land on screen.
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Faint contrast hairline so white bands separate from a light-grey ground.
            shape.strokeBorder(Color.black.opacity(0.12), lineWidth: lineWidth + 1)
            // Colour-preserving neon: wide soft halo, tight halo, crisp core.
            shape.strokeBorder(rim, lineWidth: lineWidth * 3)
                .blur(radius: glow).opacity(0.55)
            shape.strokeBorder(rim, lineWidth: lineWidth * 1.6)
                .blur(radius: glow * 0.35).opacity(0.9)
            shape.strokeBorder(rim, lineWidth: lineWidth)
            // Lit-glass sheen along the very edge.
            shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
        }
        .compositingGroup()                       // flatten so opacity/blend read as one rim
        .opacity(bands.isEmpty ? 0 : 1)           // unknown language → hidden
        .padding(glow + 1)                        // keep the outward blur inside the host clip
        .allowsHitTesting(false)                  // never eat key taps
    }
}

// MARK: - Drop-in modifier for the whole keyboard panel

extension View {
    /// Wraps the panel in the neon split-flag rim for `lang` — the TARGET
    /// language, i.e. `model.outputLang`. Fades to nothing while the language is
    /// unknown and cross-dissolves when it changes (new `.id` per language, since
    /// gradient stop arrays are not natively tweenable).
    func neonFlagRim(for lang: LanguageTag,
                     cornerRadius: CGFloat = 20,
                     lineWidth: CGFloat = 2,
                     glow: CGFloat = 7) -> some View {
        overlay {
            NeonFlagBorder(bands: FlagRim.bands(for: lang),
                           cornerRadius: cornerRadius, lineWidth: lineWidth, glow: glow)
                .id(lang.code)                    // new identity per language…
                .transition(.opacity)             // …so flags cross-dissolve
        }
        .animation(.easeInOut(duration: 0.4), value: lang)
    }
}
