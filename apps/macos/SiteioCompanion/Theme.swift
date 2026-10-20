import AppKit
import SwiftUI

/// The admin page's tokens (siteio's brand.css, which are agentio's Mac values), light and dark,
/// so the app's own screen and the page read as one window.
enum Theme {
    static let bg = adaptive(light: 0xF5F5F7, dark: 0x232325)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let fg = adaptive(light: 0x1D1D1F, dark: 0xF5F5F7)
    static let muted = adaptive(light: 0x6E6E73, dark: 0x98989D)
    static let line = adaptive(light: 0xE0E0E5, dark: 0x3A3A3C)
    static let link = adaptive(light: 0x007AFF, dark: 0x0A84FF)
    static let bad = adaptive(light: 0xD70015, dark: 0xFF453A)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
