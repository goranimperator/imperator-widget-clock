import AppKit

/// The menu bar icon, drawn rather than taken from SF Symbols.
///
/// `systemSymbolName: "clock"` is a hairline circle with two thin hands. On a
/// 1x display, an external 2560x1440 panel for instance, those strokes fall
/// between pixels and the glyph turns to mush. This is the clock's own face
/// reduced to its blockiest parts: a display outline with a lit colon, which
/// lands on whole pixels at any scale.
enum StatusItemIcon {
    static func make(height: CGFloat = 16) -> NSImage {
        let width = (height * 1.45).rounded()
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { rect in
            let line: CGFloat = 1.5
            let body = rect.insetBy(dx: line / 2 + 0.5, dy: line / 2 + 1.5)
            let outline = NSBezierPath(roundedRect: body,
                                       xRadius: line * 1.6,
                                       yRadius: line * 1.6)
            outline.lineWidth = line
            NSColor.black.setStroke()
            outline.stroke()

            // Colon, the one part of a seven-segment face that stays legible
            // once the digits are too small to read.
            let dot = (body.height * 0.17).rounded()
            let centerX = body.midX - dot / 2
            for fraction in [0.34, 0.66] {
                let y = (body.minY + body.height * fraction - dot / 2).rounded()
                let square = NSRect(x: centerX.rounded(), y: y, width: dot, height: dot)
                NSColor.black.setFill()
                NSBezierPath(rect: square).fill()
            }
            return true
        }
        // Template, so macOS inverts it for light and dark menu bars.
        image.isTemplate = true
        return image
    }
}
