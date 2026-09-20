import Foundation
import SwiftUI

/// Colour and glow for the face.
public struct ClockStyle: Equatable, Sendable {
    public var skin: ClockSkin
    /// Only read when `skin` is `.custom`.
    public var customHex: String
    /// Neon mode: near-white core with three coloured glow layers, mirroring
    /// `.neon` / `.neon-<colour>` in imperator-deals `src/styles.css`.
    public var neon: Bool
    /// Brightness of a segment that is off, relative to one that is on.
    ///
    /// Measured against macOS itself. `Dim widgets on desktop` composites the
    /// whole widget at about 0.75 and in greyscale, from outside: a desktop
    /// widget always renders in `.fullColor` and is never told. A probe that
    /// drew the face red whenever the mode was not `.fullColor` produced zero
    /// red pixels with Dim on. The app reads the setting from
    /// `com.apple.widgets` instead and publishes it, see `WidgetDimming`, but
    /// nothing in this process can detect the composite itself.
    ///
    /// The compositor is not linear about it either. Sourced at 0.30 the ghost
    /// segments disappeared outright; 0.37 came back at 0.188 and 0.45 at
    /// 0.251, so it drops anything below roughly 0.30. At the old 0.05 the
    /// ghosts were nowhere, and the face stopped reading as an LCD exactly when
    /// the desktop was covered, which is most of the time.
    ///
    /// 0.25 was settled by eye against the real dimmed desktop. Do not lower it
    /// without looking there: the popover preview is not dimmed and shows the
    /// ghosts at any value.
    public var dimOpacity: Double

    public init(skin: ClockSkin,
                neon: Bool,
                customHex: String = ClockSkin.defaultCustomHex,
                dimOpacity: Double = 0.25) {
        self.skin = skin
        self.customHex = customHex
        self.neon = neon
        self.dimOpacity = dimOpacity
    }

    /// The chosen colour, preset or custom, before any lighting is applied.
    public var baseComponents: (red: Double, green: Double, blue: Double) {
        skin == .custom ? ClockSkin.components(fromHex: customHex) : skin.components
    }

    public var baseColor: Color {
        let c = baseComponents
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    /// Brightness pushed to full, hue and saturation untouched.
    public var flatLitComponents: (red: Double, green: Double, blue: Double) {
        let (hue, saturation, brightness) = ClockSkin.hsb(from: baseComponents)
        return ClockSkin.rgb(hue: hue, saturation: saturation, brightness: max(brightness, 0.98))
    }

    public var flatLitColor: Color {
        let lit = flatLitComponents
        return Color(.sRGB, red: lit.red, green: lit.green, blue: lit.blue, opacity: 1)
    }

    /// The same colour whether or not the glow is on.
    ///
    /// Neon used to swap the core for the skin's hue at a third of its
    /// saturation and near-full brightness, which is the CSS `.neon` rule read
    /// literally. On a seven-segment glyph that washes the colour out: turning
    /// the glow on made the digits paler rather than brighter, and a saturated
    /// pink came back almost white. The glow is the effect; the digits keep
    /// their colour and gain a halo around them.
    public var litColor: Color { flatLitColor }
    /// An opaque colour, not the lit colour at low alpha.
    ///
    /// Over the near-black face the two look the same, and gate G3 measures the
    /// rendered pixels either way. They differ outside full colour: macOS keys
    /// its material on alpha there, so a ghost drawn at 0.05 alpha is dropped
    /// entirely and the face stops reading as an LCD. Scaling the components
    /// instead keeps the segment opaque and lets it through.
    public var offColor: Color {
        // Neutral grey, not the chosen colour dimmed down. A segment that is
        // off is off: a real LCD's dark bars do not take the tint of the lit
        // ones, and a magenta face with magenta ghosts read as a smudge rather
        // than as an unlit segment. This is what the ghosts have always looked
        // like under Classic White, now applied to every skin.
        Color(.sRGB, red: dimOpacity, green: dimOpacity, blue: dimOpacity, opacity: 1)
    }

    /// The `.neon` glow, ported from three stacked CSS drop-shadows. Radii are
    /// fractions of the digit height; a SwiftUI shadow radius is half a CSS
    /// blur radius. The widest layer is dialled back the way `sigilPulseRed`
    /// does it, because a seven-segment glyph is far denser than text and the
    /// literal 24px layer floods the whole face.
    public static let glowLayers: [(scale: CGFloat, opacity: Double)] = [
        (0.012, 0.60),
        (0.030, 0.32),
        (0.070, 0.16)
    ]

    /// The face background. Same near-black as imperator-retropong.
    public static let faceBackground = Color(.sRGB, red: 0.04, green: 0.04, blue: 0.04, opacity: 1)

    /// macOS widget chrome: continuous rounded corners, a hairline edge and a
    /// soft drop shadow.
    ///
    /// 30 is what macOS 27 draws, measured rather than assumed. The medium
    /// widget's own window was captured and the corner profile of the drawn
    /// pixels fitted: 30.0 pt across 345 x 164 drawn points, near-circular. The
    /// same measurement puts an NSPopover's content clip at 19.75 pt and a
    /// titled window at 17.25, and both of those are the system's to draw, so
    /// nothing here restates them. This constant is only for the shapes the app
    /// draws itself.
    ///
    /// The popover preview uses it too, so the card behind the preview is the
    /// shape the desktop shows. `--verify-corner` measures it in the rendered
    /// pixels against the literal 30 rather than against this constant, the way
    /// `--about-check` learned to.
    public static let containerCornerRadius: CGFloat = 30

    /// The panel's own corner: 17.5 pt.
    ///
    /// The preview card takes this rather than the widget's 30, because the
    /// card sits directly inside the panel's corner and the two are read
    /// against each other. The widget on the desktop has nothing around it, so
    /// it keeps 30.
    ///
    /// 17.5 is what macOS 27 draws around its own menu bar panels, measured off
    /// Control Centre's Wi-Fi panel, and what `MenuBarPanel` draws here. A
    /// plain window measures 17.25 by the same method. This said 19.75 for one
    /// build, the figure an `NSPopover` clips at, which is the control this app
    /// used before the panel; the card was then visibly rounder than the panel
    /// holding it.
    ///
    /// `MenuBarPanel.cornerRadius` is 18.25 rather than this, because an
    /// `NSVisualEffectView` blends its edge and draws about 0.75 pt tighter
    /// than the radius it is given. SwiftUI draws what it is told, so the card
    /// carries the drawn number.
    public static let panelCornerRadius: CGFloat = 17.5
    public static let containerBorder = Color.white.opacity(0.14)
    public static let containerFill = Color(.sRGB, red: 0.06, green: 0.06, blue: 0.065, opacity: 0.94)
}

/// The rounded, bordered plate a macOS widget sits in.
public struct WidgetContainer<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: ClockStyle.containerCornerRadius,
                                     style: .continuous)
        content
            .background(shape.fill(ClockStyle.containerFill))
            .overlay(shape.strokeBorder(ClockStyle.containerBorder, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
    }
}

/// The clock face: four seven-segment digits, a colon, unlit strokes showing
/// through at `style.dimOpacity`.
public struct ClockFaceView: View {
    public var reading: ClockReading
    public var style: ClockStyle

    public init(reading: ClockReading, style: ClockStyle) {
        self.reading = reading
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width / ClockLayout.faceWidth,
                           geo.size.height / ClockLayout.faceHeight)
            let digitHeight = ClockLayout.digitHeight * unit
            ZStack {
                ClockGhostShape().fill(style.offColor)
                litLayer(digitHeight: digitHeight)
            }
        }
    }

    @ViewBuilder
    private func litLayer(digitHeight: CGFloat) -> some View {
        let shape = ClockLitShape(reading: reading).fill(style.litColor)
        if style.neon {
            let layers = ClockStyle.glowLayers
            let glow = style.flatLitColor
            shape
                .shadow(color: glow.opacity(layers[0].opacity),
                        radius: layers[0].scale * digitHeight)
                .shadow(color: glow.opacity(layers[1].opacity),
                        radius: layers[1].scale * digitHeight)
                .shadow(color: glow.opacity(layers[2].opacity),
                        radius: layers[2].scale * digitHeight)
        } else {
            shape
        }
    }
}

/// Face plus its own background, for the widget body and the desktop window.
public struct ClockPanelView: View {
    public var reading: ClockReading
    public var style: ClockStyle
    public var padding: CGFloat

    public init(reading: ClockReading, style: ClockStyle, padding: CGFloat = 0.10) {
        self.reading = reading
        self.style = style
        self.padding = padding
    }

    public var body: some View {
        GeometryReader { geo in
            ClockFaceView(reading: reading, style: style)
                .padding(.horizontal, geo.size.width * padding)
                .padding(.vertical, geo.size.height * padding)
        }
    }
}
