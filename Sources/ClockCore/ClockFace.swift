import CoreGraphics
import SwiftUI

/// The four digit positions of an HH:MM face. `nil` is a blank position, used
/// for the suppressed leading zero in 12-hour mode.
public struct ClockReading: Equatable, Sendable {
    public var digits: [Int?]

    public init(digits: [Int?]) {
        self.digits = digits
    }

    public init(hour: Int, minute: Int, blankLeadingZero: Bool) {
        let tens = hour / 10
        self.digits = [
            (blankLeadingZero && tens == 0) ? nil : tens,
            hour % 10,
            minute / 10,
            minute % 10
        ]
    }

    public static func reading(for date: Date,
                               format: ClockHourFormat,
                               calendar: Calendar = .current,
                               locale: Locale = .current) -> ClockReading {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let rawHour = parts.hour ?? 0
        let minute = parts.minute ?? 0

        if format.usesTwelveHour(locale: locale) {
            var hour = rawHour % 12
            if hour == 0 { hour = 12 }
            return ClockReading(hour: hour, minute: minute, blankLeadingZero: true)
        }
        return ClockReading(hour: rawHour, minute: minute, blankLeadingZero: false)
    }

    /// One blink per second: lit for the first half of every second.
    public static func colonLit(at date: Date) -> Bool {
        Int((date.timeIntervalSince1970 * 2).rounded(.down)) % 2 == 0
    }
}

/// Shared helper that turns a frame into face metrics.
struct FaceMetrics {
    let unit: CGFloat
    let origin: CGPoint

    init(rect: CGRect) {
        let unit = min(rect.width / ClockLayout.faceWidth,
                       rect.height / ClockLayout.faceHeight)
        self.unit = unit
        self.origin = CGPoint(
            x: rect.minX + (rect.width - ClockLayout.faceWidth * unit) / 2,
            y: rect.minY + (rect.height - ClockLayout.faceHeight * unit) / 2
        )
    }

    func digitOffset(_ index: Int) -> CGPoint {
        CGPoint(x: origin.x + ClockLayout.digitOriginX(index) * unit, y: origin.y)
    }

    func colonDotRects() -> [CGRect] {
        let d = ClockLayout.colonDot * unit
        let cx = origin.x + (ClockLayout.colonOriginX + ClockLayout.colonWidth / 2) * unit
        return ClockLayout.colonDotOffsets.map { fraction in
            let cy = origin.y + ClockLayout.digitHeight * fraction * unit
            return CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)
        }
    }
}

/// Every segment of every digit plus both colon dots. Drawn underneath the lit
/// layer at a low opacity so an unlit stroke is still there, the way the bars of
/// a real LCD clock never fully disappear.
public struct ClockGhostShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let metrics = FaceMetrics(rect: rect)
        var path = Path()
        for index in 0..<4 {
            let offset = metrics.digitOffset(index)
            for segment in SegmentMask.ordered {
                path.addSegment(SegmentGeometry.outline(segment, unit: metrics.unit),
                                offsetBy: offset)
            }
        }
        for dot in metrics.colonDotRects() {
            path.addColonDot(dot)
        }
        return path
    }
}

/// Only the segments that are on for the current reading.
public struct ClockLitShape: Shape {
    public var reading: ClockReading
    public var colonLit: Bool

    public init(reading: ClockReading, colonLit: Bool) {
        self.reading = reading
        self.colonLit = colonLit
    }

    public func path(in rect: CGRect) -> Path {
        let metrics = FaceMetrics(rect: rect)
        var path = Path()
        for (index, digit) in reading.digits.enumerated() {
            guard index < 4, let digit else { continue }
            let mask = SegmentMask.digit(digit)
            let offset = metrics.digitOffset(index)
            for segment in SegmentMask.ordered where mask.contains(segment) {
                path.addSegment(SegmentGeometry.outline(segment, unit: metrics.unit),
                                offsetBy: offset)
            }
        }
        if colonLit {
            for dot in metrics.colonDotRects() {
                path.addColonDot(dot)
            }
        }
        return path
    }
}


extension Path {
    /// Colon dot: a rounded square, the shape a real LCD colon uses.
    mutating func addColonDot(_ rect: CGRect) {
        let radius = rect.width * ClockLayout.colonDotRounding
        addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius),
                       style: .continuous)
    }
}
