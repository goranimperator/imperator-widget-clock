import AppKit

/// The menu bar icon: imperator-finder-terminal's own icon with its prompt
/// replaced by a colon.
///
/// `systemSymbolName: "clock"` is a hairline circle with two thin hands. On a
/// 1x display, an external 2560x1440 panel for instance, those strokes fall
/// between pixels and the glyph turns to mush. A seven-segment colon inside a
/// display frame lands on whole pixels at any scale and says clock at 18pt.
///
/// The frame is not redrawn from measurements. It is `apple.terminal`, the
/// symbol imperator-finder-terminal puts in its status item, drawn here and
/// then hollowed out: the two apps are then the same box with different
/// contents, and they stay that way when macOS changes the symbol.
///
/// Drawn at the symbol's natural size, centred, not stretched to fill the
/// canvas. `draw(in:)` into a larger rect scales a symbol up, and the menu bar
/// does not: it draws the symbol at its own point size. Matching a stretched
/// measurement is what made this icon a third too tall on screen once.
enum StatusItemIcon {
    private static var symbol: NSImage? {
        let base = NSImage(systemSymbolName: "apple.terminal", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        guard let image = base?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        return image
    }

    /// Brandbook 8.1: 18 x 18pt, template, in a `.squareLength` status item.
    static func make(size: CGFloat = 18) -> NSImage {
        // The terminal symbol's frame, measured off it at 16x: it inks
        // 15.8125 x 11.9375 pt with a 1.0625 pt stroke, and its corner profile
        // fits an outer radius of about 1.7.
        //
        // Drawn here rather than composited from the symbol, for one reason:
        // AppKit snaps that symbol to the pixel grid when the status bar draws
        // it, and a copy placed by hand lands on half pixels instead. Measured
        // on the menu bar, the symbol's columns read 233 across with 216 at the
        // edges, while the hand-placed copy read 127 167 ... 166 123: the same
        // shape, a pixel wider, and soft on both sides.
        //
        // So the ink is snapped to whole points here: 16 x 12 at (1, 3) on an
        // 18pt canvas. 16 rather than the symbol's 15.8125 because the width
        // has to be even for a 2pt colon to be both centred and crisp, which
        // leaves this frame a single pixel wider than the terminal's at 1x.
        let ink = NSRect(x: ((size - size * (16 / 18)) / 2).rounded(),
                         y: ((size - size * (12 / 18)) / 2).rounded(),
                         width: (size * (16 / 18)).rounded(),
                         height: (size * (12 / 18)).rounded())
        let line = size * (1.125 / 18)
        // A stroked path is drawn on its centreline, so the radius asked for is
        // half a stroke smaller than the outer one.
        let radius = size * (1.7 / 18) - line / 2

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: ink.insetBy(dx: line / 2, dy: line / 2),
                                       xRadius: radius, yRadius: radius)
            outline.lineWidth = line
            outline.lineJoinStyle = .round
            outline.stroke()

            // Colon, the one part of a seven-segment face that stays legible
            // once the digits are too small to read.
            //
            // 2pt dots on an even frame, so the pair is centred and every edge
            // lands on a whole pixel. The icon shipped 23pt wide with a 2pt dot
            // once, and that parity mismatch put the colon half a point right
            // of centre while `.rounded()` hid it. `--icon-check` measures the
            // finished pixels rather than trusting the arithmetic.
            let dot = (2 * size / 24).rounded(.toNearestOrEven)
            let gap = dot
            NSColor.black.setFill()
            let x = (ink.midX - dot / 2).rounded()
            let lowest = (ink.midY - (dot + gap / 2)).rounded()
            for step in [CGFloat(0), dot + gap] {
                NSBezierPath(rect: NSRect(x: x, y: lowest + step, width: dot, height: dot)).fill()
            }
            return true
        }
        // Template, so macOS inverts it for light and dark menu bars.
        image.isTemplate = true
        return image
    }
}
