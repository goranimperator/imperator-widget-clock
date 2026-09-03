import AppKit

/// The menu bar icon, drawn rather than taken from SF Symbols.
///
/// `systemSymbolName: "clock"` is a hairline circle with two thin hands. On a
/// 1x display, an external 2560x1440 panel for instance, those strokes fall
/// between pixels and the glyph turns to mush. This is the clock's own face
/// reduced to its blockiest parts: a display outline with a lit colon, which
/// lands on whole pixels at any scale.
///
/// The outline is the gamepad body from imperator-free-games, so the two apps
/// sit side by side in the menu bar without one looking bigger than the other.
/// That icon is Lucide's `gamepad` drawn at 18pt: a 24-unit viewBox holding
/// `rect x=2 y=6 width=20 height=12 rx=2` at `stroke-width=2`, stroked in black
/// as a template image. Every measurement below is one of those viewBox units
/// scaled to `size`, so the outline matches at any size. The colon is only
/// verified at the 18pt the app actually asks for: see the note on its parity.
enum StatusItemIcon {
    /// Brandbook 8.1: 18 x 18pt, template, in a `.squareLength` status item.
    static func make(size: CGFloat = 18) -> NSImage {
        let unit = size / 24
        let line = 2 * unit
        // SVG puts the rect's path on the centre of the stroke, so these are
        // centreline numbers and the stroke straddles them by `line / 2`.
        let body = NSRect(x: 2 * unit, y: 6 * unit, width: 20 * unit, height: 12 * unit)
        let radius = 2 * unit

        // The gamepad's own dots are 2 units across, and at 18pt that rounds to
        // a 2pt square: the smallest one that lands on whole pixels at 1x and
        // still reads as a colon rather than a smudge.
        //
        // A dot sits dead centre on whole pixels only when its width shares the
        // canvas's parity, and 2 against 18 does. The icon shipped 23pt wide
        // with a 2pt dot, and that mismatch is what put the colon half a point
        // right of the outline while `.rounded()` hid it. Nothing here enforces
        // the rule, because a guard that grows the dot overflows the body at
        // odd sizes; `--icon-check` measures the result instead.
        let dot = (2 * unit).rounded(.toNearestOrEven)
        // Two dots and one gap of the same size, so the colon reads as a colon
        // rather than as a dash, and the even total keeps the pair centred.
        let gap = dot

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
            outline.lineWidth = line
            outline.lineJoinStyle = .round
            outline.stroke()

            // Colon, the one part of a seven-segment face that stays legible
            // once the digits are too small to read.
            NSColor.black.setFill()
            let x = rect.midX - dot / 2
            let lowest = rect.midY - (dot + gap / 2)
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
