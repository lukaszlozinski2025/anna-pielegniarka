import SwiftUI

/// Shared dark "AI panel" look, reused by the app and the keyboard.
enum Theme {
    static let bg      = Color(hex: 0x0D1117)
    static let panel   = Color(hex: 0x111820)
    static let card    = Color(hex: 0x161E28)
    static let border  = Color(hex: 0x1E2D3D)
    static let accent  = Color(hex: 0x00C2A8)
    static let text    = Color(hex: 0xE8EDF3)
    static let textDim = Color(hex: 0x7A8FA8)
    static let danger  = Color(hex: 0xE05A6A)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
