import AppKit
import SwiftUI

/// The pen that marks the custom swatch as the editable one.
///
/// Lucide's `pen`, the same set the menu bar icon's outline comes from, so the
/// two hand-placed glyphs in this app belong to one family rather than two.
/// It is loaded as a template image and tinted at the call site, because the
/// ink has to flip with the colour underneath it.
enum PenIcon {
    private static let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/></svg>
    """

    /// Parsed once. `SkinSwatch.body` runs on every sample while the colour
    /// wheel is dragged, and an XML parse plus an image allocation per frame is
    /// work nobody sees.
    static let glyph = image(size: 12)

    static func image(size: CGFloat) -> NSImage? {
        guard let data = svg.data(using: .utf8), let image = NSImage(data: data) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: size, height: size)
        return image
    }

    /// Black or white, whichever the eye can actually read on `color`.
    ///
    /// Picked by WCAG contrast rather than a brightness threshold. A midtone is
    /// where a threshold guesses wrong, and the swatch row runs from Imperator
    /// Red through Classic White, so it spends most of its range near one.
    static func ink(on color: (red: Double, green: Double, blue: Double)) -> Color {
        let luminance = relativeLuminance(color)
        let blackOnIt = (luminance + 0.05) / 0.05
        let whiteOnIt = 1.05 / (luminance + 0.05)
        return blackOnIt >= whiteOnIt ? .black : .white
    }

    /// WCAG 2.1 relative luminance, sRGB.
    static func relativeLuminance(_ color: (red: Double, green: Double, blue: Double)) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red)
            + 0.7152 * linear(color.green)
            + 0.0722 * linear(color.blue)
    }
}
