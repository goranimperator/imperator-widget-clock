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
    /// Five per cent: there if you look, never loud enough to read as lit.
    public var dimOpacity: Double
    /// Multiplies the neon glow. 1 is the resting strength; the pulse rides
    /// between `ClockStyle.pulseFloor` and `ClockStyle.pulseCeiling`.
    public var glowScale: Double

    public init(skin: ClockSkin,
                neon: Bool,
                customHex: String = ClockSkin.defaultCustomHex,
                dimOpacity: Double = 0.05,
                glowScale: Double = 1) {
        self.skin = skin
        self.customHex = customHex
        self.neon = neon
        self.dimOpacity = dimOpacity
        self.glowScale = glowScale
    }

    public static let pulseFloor: Double = 0.55
    public static let pulseCeiling: Double = 1.45

    /// One pulse per second, smooth, peaking on the whole second.
    public static func pulseScale(at date: Date) -> Double {
        let phase = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        let wave = (cos(phase * 2 * .pi) + 1) / 2
        return pulseFloor + (pulseCeiling - pulseFloor) * wave
    }

    /// `.neon { color: #f7fff9 }` is the CSS core, but on a seven-segment glyph
    /// a pure near-white core loses the colour entirely: the reference face
    /// reads as light lavender, not white. So the core is the skin's own hue
    /// lifted most of the way towards white instead.
    /// Measured off the reference face: the lit core sits near #c9a3f5, which is
    /// the same hue as the glow at about a third of its saturation. Mixing
    /// towards white instead pulls purple towards magenta, so the core keeps the
    /// hue and drops the saturation.
    public static let neonCoreSaturation: Double = 0.34
    public static let neonCoreBrightness: Double = 0.97

    var neonCore: Color {
        let (hue, saturation, _) = ClockSkin.hsb(from: baseComponents)
        let core = ClockSkin.rgb(hue: hue,
                                 saturation: min(saturation, ClockStyle.neonCoreSaturation),
                                 brightness: ClockStyle.neonCoreBrightness)
        return Color(.sRGB, red: core.red, green: core.green, blue: core.blue, opacity: 1)
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
    public var flatLitColor: Color {
        let (hue, saturation, brightness) = ClockSkin.hsb(from: baseComponents)
        let lit = ClockSkin.rgb(hue: hue, saturation: saturation, brightness: max(brightness, 0.98))
        return Color(.sRGB, red: lit.red, green: lit.green, blue: lit.blue, opacity: 1)
    }

    public var litColor: Color { neon ? neonCore : flatLitColor }
    public var offColor: Color { baseColor.opacity(dimOpacity) }

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

    public func glowRadii(digitHeight: CGFloat) -> [CGFloat] {
        ClockStyle.glowLayers.map { $0.scale * digitHeight * glowScale }
    }

    /// The face background. Same near-black as imperator-retropong.
    public static let faceBackground = Color(.sRGB, red: 0.04, green: 0.04, blue: 0.04, opacity: 1)

    /// macOS widget chrome, so the desktop clock reads as a widget and not as a
    /// stray window: continuous rounded corners, a hairline edge and a soft
    /// drop shadow.
    public static let containerCornerRadius: CGFloat = 24
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
    public var colonLit: Bool
    public var style: ClockStyle

    public init(reading: ClockReading, colonLit: Bool, style: ClockStyle) {
        self.reading = reading
        self.colonLit = colonLit
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
        let shape = ClockLitShape(reading: reading, colonLit: colonLit).fill(style.litColor)
        if style.neon {
            let layers = ClockStyle.glowLayers
            let glow = style.flatLitColor
            let scale = style.glowScale
            shape
                .shadow(color: glow.opacity(min(1, layers[0].opacity * scale)),
                        radius: layers[0].scale * digitHeight * scale)
                .shadow(color: glow.opacity(min(1, layers[1].opacity * scale)),
                        radius: layers[1].scale * digitHeight * scale)
                .shadow(color: glow.opacity(min(1, layers[2].opacity * scale)),
                        radius: layers[2].scale * digitHeight * scale)
        } else {
            shape
        }
    }
}

/// Face plus its own background, for the widget body and the desktop window.
public struct ClockPanelView: View {
    public var reading: ClockReading
    public var colonLit: Bool
    public var style: ClockStyle
    public var padding: CGFloat

    public init(reading: ClockReading, colonLit: Bool, style: ClockStyle, padding: CGFloat = 0.10) {
        self.reading = reading
        self.colonLit = colonLit
        self.style = style
        self.padding = padding
    }

    public var body: some View {
        GeometryReader { geo in
            ClockFaceView(reading: reading, colonLit: colonLit, style: style)
                .padding(.horizontal, geo.size.width * padding)
                .padding(.vertical, geo.size.height * padding)
        }
    }
}
