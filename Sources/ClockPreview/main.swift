import AppKit
import ClockCore
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Headless renderer. Two jobs: produce PNGs for visual review, and measure the
// rendered pixels so the acceptance gates have something real to read.

struct Bitmap {
    let width: Int
    let height: Int
    let pixels: [UInt8]   // RGBA8, premultiplied-last, sRGB

    func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        let i = (y * width + x) * 4
        guard i + 2 < pixels.count else { return (0, 0, 0) }
        return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
    }

    func luminance(x: Int, y: Int) -> Double {
        let c = rgb(x: x, y: y)
        return 0.2126 * Double(c.r) + 0.7152 * Double(c.g) + 0.0722 * Double(c.b)
    }
}

enum RenderError: Error { case failed(String) }

@MainActor
func render<V: View>(_ view: V, size: CGSize) throws -> CGImage {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 1
    // Composite in gamma-encoded space so a 25 % fill measures as 25 % of the
    // lit value. Linear blending would report 54 %.
    renderer.colorMode = .nonLinear
    guard let image = renderer.cgImage else {
        throw RenderError.failed("ImageRenderer produced no image")
    }
    return image
}

func bitmap(from image: CGImage) throws -> Bitmap {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = pixels.withUnsafeMutableBytes({ buffer -> CGContext? in
        CGContext(data: buffer.baseAddress,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }) else {
        throw RenderError.failed("could not create sampling context")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = context.data else { throw RenderError.failed("no context data") }
    let raw = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for i in 0..<(width * height * 4) { pixels[i] = raw[i] }
    return Bitmap(width: width, height: height, pixels: pixels)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw RenderError.failed("could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RenderError.failed("could not write \(url.path)")
    }
}

// MARK: - Views used only for rendering

struct FaceOnly: View {
    var reading: ClockReading
    var style: ClockStyle
    /// Zero for the pixel gates, which need the face centred in the whole frame.
    var inset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black
            ClockFaceView(reading: reading, style: style)
                .padding(inset)
        }
    }
}

struct WidgetMock: View {
    var reading: ClockReading
    var style: ClockStyle

    var body: some View {
        ZStack {
            Color(white: 0.10)
            ClockPanelView(reading: reading, style: style, padding: 0.09)
                .background(ClockStyle.faceBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(14)
        }
    }
}

// MARK: - Face geometry in pixels, for sampling

/// Where a given segment of a given digit lands inside a rendered face image.
func samplePoint(segment: SegmentMask, digitIndex: Int, imageSize: CGSize) -> CGPoint {
    let unit = min(imageSize.width / ClockLayout.faceWidth,
                   imageSize.height / ClockLayout.faceHeight)
    let originX = (imageSize.width - ClockLayout.faceWidth * unit) / 2
        + ClockLayout.digitOriginX(digitIndex) * unit
    let originY = (imageSize.height - ClockLayout.faceHeight * unit) / 2
    let local = SegmentGeometry.center(segment, unit: unit)
    return CGPoint(x: originX + local.x, y: originY + local.y)
}

// MARK: - Commands

let faceSize = CGSize(width: 720, height: 720 / ClockLayout.faceWidth * ClockLayout.faceHeight)

@MainActor
func commandRender(into directory: URL) throws -> Int {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var count = 0
    let reading = ClockReading(digits: [1, 6, 5, 4])

    for skin in ClockSkin.allCases {
        for neon in [false, true] {
            let style = ClockStyle(skin: skin, neon: neon)
            let image = try render(FaceOnly(reading: reading, style: style, inset: 28),
                                  size: faceSize)
            let name = "face-\(skin.rawValue)-\(neon ? "neon" : "flat").png"
            try writePNG(image, to: directory.appendingPathComponent(name))
            count += 1
        }
    }

    // Medium widget proportions on macOS.
    let mediumSize = CGSize(width: 680, height: 316)
    for skin in [ClockSkin.purple, .green, .white] {
        let style = ClockStyle(skin: skin, neon: true)
        let image = try render(WidgetMock(reading: reading, style: style),
                              size: mediumSize)
        try writePNG(image, to: directory.appendingPathComponent("widget-\(skin.rawValue).png"))
        count += 1
    }

    // Every segment lit, and every segment dark: the two extremes of the face.
    let all = try render(
        FaceOnly(reading: ClockReading(digits: [8, 8, 8, 8]),
                 style: ClockStyle(skin: .red, neon: false), inset: 28),
        size: faceSize
    )
    try writePNG(all, to: directory.appendingPathComponent("face-red-flat-8888.png"))
    count += 1

    let dark = try render(
        FaceOnly(reading: ClockReading(digits: [nil, nil, nil, nil]),
                 style: ClockStyle(skin: .white, neon: false), inset: 28),
        size: faceSize
    )
    try writePNG(dark, to: directory.appendingPathComponent("face-white-ghost-only.png"))
    count += 1

    return count
}

@MainActor
func commandVerifyDim() throws {
    // Digit "1" lights b and c only, so a, d, e, f and g are the unlit controls.
    let style = ClockStyle(skin: .white, neon: false)
    let image = try render(
        FaceOnly(reading: ClockReading(digits: [1, 1, 1, 1]), style: style),
        size: faceSize
    )
    let map = try bitmap(from: image)
    let size = CGSize(width: map.width, height: map.height)

    func sample(_ segment: SegmentMask) -> Double {
        let point = samplePoint(segment: segment, digitIndex: 0, imageSize: size)
        return map.luminance(x: Int(point.x.rounded()), y: Int(point.y.rounded()))
    }

    let lit = (sample(.b) + sample(.c)) / 2
    let unlitSamples = [SegmentMask.a, .d, .e, .f, .g].map(sample)
    let unlit = unlitSamples.reduce(0, +) / Double(unlitSamples.count)
    let ratio = unlit / lit

    print(String(format: "lit=%.1f unlit=%.1f ratio=%.4f", lit, unlit, ratio))
    guard lit > 200 else {
        throw RenderError.failed("lit segment measured \(lit), expected near 255")
    }
    guard unlit > 2 else {
        throw RenderError.failed("unlit segment measured \(unlit); it must stay visible")
    }
    guard abs(ratio - 0.05) <= 0.015 else {
        throw RenderError.failed(String(format: "unlit/lit ratio %.4f is not 0.05 +/- 0.015", ratio))
    }
    // A digit-1 face must not light a, d, e, f or g anywhere.
    for (index, value) in unlitSamples.enumerated() where value > lit * 0.4 {
        throw RenderError.failed("control segment \(index) reads \(value): mask is wrong")
    }
    print("G3_DIM_OK")
}

@MainActor
func commandVerifyGaps() throws {
    // Every junction on the face is two 45-degree ends facing each other across
    // a channel. They must all be the same width: a wider channel around the
    // middle bar than at the corners is what makes a seven-segment digit look
    // like it was assembled out of two halves.
    // Rendered at four times the review size: the channel is a couple of
    // hundredths of a digit width, and at review size a pixel of antialiasing
    // is a fifth of the measurement.
    let probeSize = CGSize(width: faceSize.width * 4, height: faceSize.height * 4)
    let image = try render(
        FaceOnly(reading: ClockReading(digits: [8, 8, 8, 8]),
                 style: ClockStyle(skin: .white, neon: false)),
        size: probeSize
    )
    let map = try bitmap(from: image)
    let unit = min(CGFloat(map.width) / ClockLayout.faceWidth,
                   CGFloat(map.height) / ClockLayout.faceHeight)
    let originX = (CGFloat(map.width) - ClockLayout.faceWidth * unit) / 2
    let originY = (CGFloat(map.height) - ClockLayout.faceHeight * unit) / 2

    /// The channel is the narrowest crossing between two segment ends, and the
    /// probe sits in the middle of it, so the width is twice the distance from
    /// the probe to the nearest lit pixel. Measuring it that way needs no
    /// direction, which is the part that is easy to get wrong per corner.
    func channelWidth(at point: CGPoint) -> Double {
        // Half brightness, so a partly covered edge pixel counts as the edge
        // rather than as open channel.
        let threshold = 128.0
        let limit = Double(unit) * 0.4
        var radius = 0.5
        while radius < limit {
            var angle = 0.0
            while angle < 2 * Double.pi {
                let x = Double(point.x) + cos(angle) * radius
                let y = Double(point.y) + sin(angle) * radius
                if x >= 0, y >= 0, Int(x) < map.width, Int(y) < map.height,
                   map.luminance(x: Int(x.rounded()), y: Int(y.rounded())) > threshold {
                    return radius * 2
                }
                angle += 0.02
            }
            radius += 0.25
        }
        return limit * 2
    }

    // The probes are derived from the outlines themselves rather than from the
    // numbers that produced them, so moving a segment end moves the probe with
    // it and the gate measures the channel that is really there.
    func tip(_ segment: SegmentMask, _ extreme: (CGPoint, CGPoint) -> Bool) -> CGPoint {
        let points = SegmentGeometry.outline(segment, unit: unit)
        var best = points[0]
        for point in points.dropFirst() where extreme(point, best) { best = point }
        return best
    }
    let leftmost: (CGPoint, CGPoint) -> Bool = { $0.x < $1.x }
    let rightmost: (CGPoint, CGPoint) -> Bool = { $0.x > $1.x }
    let topmost: (CGPoint, CGPoint) -> Bool = { $0.y < $1.y }
    let bottommost: (CGPoint, CGPoint) -> Bool = { $0.y > $1.y }

    let junctions: [(name: String, first: CGPoint, second: CGPoint)] = [
        ("corner a/f", tip(.a, leftmost), tip(.f, topmost)),
        ("corner a/b", tip(.a, rightmost), tip(.b, topmost)),
        ("corner d/e", tip(.d, leftmost), tip(.e, bottommost)),
        ("corner d/c", tip(.d, rightmost), tip(.c, bottommost)),
        ("middle f/g", tip(.f, bottommost), tip(.g, leftmost)),
        ("middle g/b", tip(.b, bottommost), tip(.g, rightmost)),
        ("middle e/g", tip(.e, topmost), tip(.g, leftmost)),
        ("middle g/c", tip(.c, topmost), tip(.g, rightmost))
    ]
    let probes = junctions.map { junction in
        (name: junction.name,
         point: CGPoint(x: (junction.first.x + junction.second.x) / 2,
                        y: (junction.first.y + junction.second.y) / 2))
    }

    var widths: [(String, Double)] = []
    for probe in probes {
        let point = CGPoint(x: originX + probe.point.x, y: originY + probe.point.y)
        let width = channelWidth(at: point)
        widths.append((probe.name, width))
    }

    let measured = widths.map(\.1)
    let smallest = measured.min() ?? 0
    let largest = measured.max() ?? 0
    print("channels " + widths.map { String(format: "%@=%.2f", $0.0, $0.1) }.joined(separator: " "))
    print(String(format: "min=%.2f max=%.2f spread=%.2f px", smallest, largest, largest - smallest))

    let mean = measured.reduce(0, +) / Double(measured.count)
    let spread = (largest - smallest) / mean
    print(String(format: "mean=%.2f spread=%.1f%%", mean, spread * 100))

    guard smallest > 1 else {
        throw RenderError.failed("a junction has no channel at all; two segments are touching")
    }
    // A tenth of the channel is rasterisation. The fault this gate exists for
    // was a middle channel three times the width of a corner one.
    guard spread <= 0.12 else {
        throw RenderError.failed(String(format: "channels differ by %.1f%% of their mean, wanted 12%% or less",
                                        spread * 100))
    }
    print("G10_GAPS_OK")
}

@main
struct ClockPreviewTool {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            try await MainActor.run {
                switch arguments.first {
                case "--verify":
                    try commandVerifyDim()
                case "--verify-gaps":
                    try commandVerifyGaps()
                case "--render", nil:
                    let path = arguments.count > 1 ? arguments[1] : "build/preview"
                    let count = try commandRender(into: URL(fileURLWithPath: path))
                    print("PREVIEW_OK \(count) -> \(path)")
                default:
                    FileHandle.standardError.write(
                        "usage: ClockPreview [--render <dir>|--verify|--verify-gaps]\n"
                            .data(using: .utf8)!
                    )
                    exit(2)
                }
            }
        } catch {
            FileHandle.standardError.write("ClockPreview failed: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
        exit(0)
    }
}
