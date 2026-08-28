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

struct IconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 200, style: .continuous)
                .fill(ClockStyle.faceBackground)
            ClockPanelView(reading: ClockReading(digits: [0, 6, 5, 3]),
                           style: ClockStyle(skin: .purple, neon: true),
                           padding: 0.13)
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
func commandIcon(to url: URL) throws {
    let image = try render(IconArt(), size: CGSize(width: 1024, height: 1024))
    try writePNG(image, to: url)
    print("ICON_OK \(url.path)")
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
                case "--icon":
                    let path = arguments.count > 1 ? arguments[1] : "Resources/AppIcon.png"
                    try commandIcon(to: URL(fileURLWithPath: path))
                case "--render", nil:
                    let path = arguments.count > 1 ? arguments[1] : "build/preview"
                    let count = try commandRender(into: URL(fileURLWithPath: path))
                    print("PREVIEW_OK \(count) -> \(path)")
                default:
                    FileHandle.standardError.write(
                        "usage: ClockPreview [--render <dir>|--verify|--icon <path>]\n"
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
