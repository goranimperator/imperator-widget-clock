import CoreGraphics
import SwiftUI

/// Which of the seven segments are lit.
///
/// ```
///   aaaa
///  f    b
///  f    b
///   gggg
///  e    c
///  e    c
///   dddd
/// ```
public struct SegmentMask: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let a = SegmentMask(rawValue: 1 << 0)
    public static let b = SegmentMask(rawValue: 1 << 1)
    public static let c = SegmentMask(rawValue: 1 << 2)
    public static let d = SegmentMask(rawValue: 1 << 3)
    public static let e = SegmentMask(rawValue: 1 << 4)
    public static let f = SegmentMask(rawValue: 1 << 5)
    public static let g = SegmentMask(rawValue: 1 << 6)

    public static let every: SegmentMask = [.a, .b, .c, .d, .e, .f, .g]
    public static let blank: SegmentMask = []

    public static let ordered: [SegmentMask] = [.a, .b, .c, .d, .e, .f, .g]

    /// Standard seven-segment numerals. `nil` renders a blank digit position.
    public static func digit(_ value: Int) -> SegmentMask {
        switch value {
        case 0: return [.a, .b, .c, .d, .e, .f]
        case 1: return [.b, .c]
        case 2: return [.a, .b, .g, .e, .d]
        case 3: return [.a, .b, .g, .c, .d]
        case 4: return [.f, .g, .b, .c]
        case 5: return [.a, .f, .g, .c, .d]
        case 6: return [.a, .f, .g, .e, .c, .d]
        case 7: return [.a, .b, .c]
        case 8: return .every
        case 9: return [.a, .b, .c, .d, .f, .g]
        default: return .blank
        }
    }
}

/// Face metrics, expressed in digit widths. One digit box is 1.0 wide.
///
/// Every number here is a length. There is no shear, slant or oblique term in
/// this file on purpose: the digits stand upright, unlike the italic LED faces
/// these usually imitate.
public enum ClockLayout {
    public static let digitWidth: CGFloat = 1.0
    public static let digitHeight: CGFloat = 2.40

    /// Segment weight. Deliberately heavy, matching the thick reference face
    /// rather than the hairline segments of the macOS screen saver.
    public static let thickness: CGFloat = 0.22

    /// Breathing room between two segments that meet. One value for every
    /// junction, so the channel at a corner and the channel around the middle
    /// bar come out the same width: each segment's end stops `miter` short of
    /// its neighbour's centre line, which puts the two facing 45-degree edges
    /// `miter * sqrt(2)` apart wherever they meet.
    public static let miter: CGFloat = 0.028

    /// How far the 45-degree cut at a segment's end travels inwards, as a
    /// fraction of half the thickness. 1.0 is a full taper to a point, which
    /// reads as a stretched hexagon. Well under 1 keeps the ends blunt and the
    /// glyph square.
    public static let chamfer: CGFloat = 1.0

    /// Space between any two neighbours on the face. One value, so the gap
    /// between the digits of a pair and the gap on either side of the colon are
    /// identical; two different values read as a spacing mistake.
    public static let gap: CGFloat = 0.19
    public static let pairGap: CGFloat = gap
    public static let colonGap: CGFloat = gap
    /// Width of the colon column.
    public static let colonWidth: CGFloat = 0.34
    /// Diameter of a colon dot.
    public static let colonDot: CGFloat = 0.27
    /// Corner rounding of a colon dot, as a fraction of its own size.
    public static let colonDotRounding: CGFloat = 0.32
    /// Vertical centres of the two colon dots, as a fraction of digit height.
    public static let colonDotOffsets: [CGFloat] = [0.315, 0.685]

    public static let faceWidth: CGFloat =
        digitWidth * 4 + pairGap * 2 + colonGap * 2 + colonWidth
    public static let faceHeight: CGFloat = digitHeight

    /// Left edge of each digit box, in digit widths, for digit index 0...3.
    public static func digitOriginX(_ index: Int) -> CGFloat {
        switch index {
        case 0: return 0
        case 1: return digitWidth + pairGap
        case 2: return digitWidth * 2 + pairGap + colonGap * 2 + colonWidth
        default: return digitWidth * 3 + pairGap * 2 + colonGap * 2 + colonWidth
        }
    }

    public static var colonOriginX: CGFloat {
        digitWidth * 2 + pairGap + colonGap
    }
}

/// Builds the segment outlines. All geometry is axis-aligned; the chamfered
/// ends come from the hexagonal segment shape, not from a transform.
public enum SegmentGeometry {

    /// A horizontal segment: a flat bar with 45-degree points at both ends.
    static func horizontal(centerY cy: CGFloat, from x0: CGFloat, to x1: CGFloat,
                           thickness t: CGFloat) -> [CGPoint] {
        let h = t / 2
        let c = h * ClockLayout.chamfer
        return [
            CGPoint(x: x0, y: cy - h + c),
            CGPoint(x: x0 + c, y: cy - h),
            CGPoint(x: x1 - c, y: cy - h),
            CGPoint(x: x1, y: cy - h + c),
            CGPoint(x: x1, y: cy + h - c),
            CGPoint(x: x1 - c, y: cy + h),
            CGPoint(x: x0 + c, y: cy + h),
            CGPoint(x: x0, y: cy + h - c)
        ]
    }

    /// A vertical segment: same bar, stood on end.
    static func vertical(centerX cx: CGFloat, from y0: CGFloat, to y1: CGFloat,
                         thickness t: CGFloat) -> [CGPoint] {
        let h = t / 2
        let c = h * ClockLayout.chamfer
        return [
            CGPoint(x: cx - h + c, y: y0),
            CGPoint(x: cx + h - c, y: y0),
            CGPoint(x: cx + h, y: y0 + c),
            CGPoint(x: cx + h, y: y1 - c),
            CGPoint(x: cx + h - c, y: y1),
            CGPoint(x: cx - h + c, y: y1),
            CGPoint(x: cx - h, y: y1 - c),
            CGPoint(x: cx - h, y: y0 + c)
        ]
    }

    /// Outline of one segment inside a digit box of `size` unit lengths.
    /// `unit` is the pixel length of one digit width.
    public static func outline(_ segment: SegmentMask, unit: CGFloat) -> [CGPoint] {
        let w = ClockLayout.digitWidth * unit
        let h = ClockLayout.digitHeight * unit
        let t = ClockLayout.thickness * unit
        let m = ClockLayout.miter * unit
        let half = t / 2
        // A bar's end stops `m` short of the centre line of the bar it meets.
        // The horizontals meet the verticals, whose centre lines are `half` in
        // from each side; the verticals meet a horizontal centred on `half`,
        // `h / 2` or `h - half`.
        let inset = half + m

        switch segment {
        case .a:
            return horizontal(centerY: half, from: inset, to: w - inset, thickness: t)
        case .g:
            return horizontal(centerY: h / 2, from: inset, to: w - inset, thickness: t)
        case .d:
            return horizontal(centerY: h - half, from: inset, to: w - inset, thickness: t)
        case .f:
            return vertical(centerX: half, from: inset, to: h / 2 - m, thickness: t)
        case .b:
            return vertical(centerX: w - half, from: inset, to: h / 2 - m, thickness: t)
        case .e:
            return vertical(centerX: half, from: h / 2 + m, to: h - inset, thickness: t)
        case .c:
            return vertical(centerX: w - half, from: h / 2 + m, to: h - inset, thickness: t)
        default:
            return []
        }
    }

    /// Centre of a segment's solid body. Used by the pixel gates to sample a
    /// point that is guaranteed to be inside the fill.
    public static func center(_ segment: SegmentMask, unit: CGFloat) -> CGPoint {
        let points = outline(segment, unit: unit)
        guard !points.isEmpty else { return .zero }
        let sx = points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        let sy = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        return CGPoint(x: sx, y: sy)
    }
}

public extension Path {
    mutating func addSegment(_ points: [CGPoint], offsetBy offset: CGPoint) {
        guard let first = points.first else { return }
        move(to: CGPoint(x: first.x + offset.x, y: first.y + offset.y))
        for point in points.dropFirst() {
            addLine(to: CGPoint(x: point.x + offset.x, y: point.y + offset.y))
        }
        closeSubpath()
    }
}
