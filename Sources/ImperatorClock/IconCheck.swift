import AppKit

/// `ImperatorClock --icon-check` measures the drawn menu bar icon in real
/// pixels: that it is the same size and shape as the gamepad icon in
/// imperator-free-games, and that the colon sits dead centre inside the outline
/// on whole pixels at every scale.
///
/// Both halves were bugs. The icon shipped 23 x 16 while every other Imperator
/// app uses 18 x 18 per brandbook 8.1, and the colon sat half a point right of
/// centre: a 2pt dot cannot be both centred on a 23pt canvas and land on whole
/// pixels, and `.rounded()` hid the mismatch by nudging it one way.
enum IconCheck {
    /// The gamepad body from imperator-free-games, verbatim, drawn through the
    /// same NSImage SVG path that app uses. Comparing against the live drawing
    /// rather than against copied numbers means a change in how macOS renders
    /// it moves both icons together instead of failing this gate.
    private static let referenceSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="6" x2="10" y1="12" y2="12"/><line x1="8" x2="8" y1="10" y2="14"/><line x1="15" x2="15.01" y1="13" y2="13"/><line x1="18" x2="18.01" y1="11" y2="11"/><rect width="20" height="12" x="2" y="6" rx="2"/></svg>
    """

    static func run() -> Int32 {
        var failures: [String] = []
        let expect = { (ok: Bool, message: String) in if !ok { failures.append(message) } }

        guard let reference = referenceImage(size: 18) else {
            print("FAIL could not render the imperator-free-games reference icon")
            return 1
        }
        let icon = StatusItemIcon.make()

        expect(icon.size == reference.size,
               "canvas is \(icon.size.width)x\(icon.size.height), the games icon is "
               + "\(reference.size.width)x\(reference.size.height)")
        expect(icon.isTemplate,
               "the icon is not a template image, so the menu bar cannot tint it")

        // Outline: the ink box and the stroke thickness have to match the games
        // icon, which covers width, height, border weight and corner radius.
        for scale in [1, 2, 3] {
            guard let mine = box(of: icon, scale: scale),
                  let theirs = box(of: reference, scale: scale) else {
                failures.append("could not rasterize at \(scale)x"); continue
            }
            expect(mine == theirs,
                   "at \(scale)x the ink box is \(mine) and the games icon's is \(theirs)")
            print("ink \(scale)x: clock \(mine)  games \(theirs)")

            guard let a = strokeWidths(of: icon, scale: scale),
                  let b = strokeWidths(of: reference, scale: scale) else {
                failures.append("could not read stroke bands at \(scale)x"); continue
            }
            expect(a == b, "at \(scale)x the border is \(a)px and the games icon's is \(b)px")
            print("border \(scale)x: clock \(a)px  games \(b)px")
        }

        // Colon: centred on the outline, and made only of whole pixels.
        for scale in [1, 2, 3] {
            guard let dots = colon(of: icon, scale: scale), !dots.isEmpty else {
                failures.append("no colon could be isolated at \(scale)x"); continue
            }
            let weight = dots.reduce(0.0) { $0 + $1.alpha }
            let cx = dots.reduce(0.0) { $0 + Double($1.x) * $1.alpha } / weight
            let cy = dots.reduce(0.0) { $0 + Double($1.y) * $1.alpha } / weight
            let side = Double(Int(icon.size.width) * scale)
            let offsetX = (cx - (side - 1) / 2) / Double(scale)
            let offsetY = (cy - (side - 1) / 2) / Double(scale)
            let soft = dots.filter { $0.alpha < 0.999 }.count
            print(String(format: "colon %dx: x off=%+.3f pt  y off=%+.3f pt  soft=%d  px=%d",
                         scale, offsetX, offsetY, soft, dots.count))
            expect(abs(offsetX) < 0.01, "at \(scale)x the colon is \(offsetX) pt off centre in x")
            expect(abs(offsetY) < 0.01, "at \(scale)x the colon is \(offsetY) pt off centre in y")
            expect(soft == 0, "at \(scale)x the colon has \(soft) part-lit pixels, so it is blurred")
        }

        if failures.isEmpty {
            print("G11_ICON_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }

    // MARK: Rasterizing

    private static func referenceImage(size: CGFloat) -> NSImage? {
        guard let data = referenceSVG.data(using: .utf8),
              let image = NSImage(data: data) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: size, height: size)
        return image
    }

    private static func raster(_ image: NSImage, scale: Int) -> NSBitmapImageRep? {
        let width = Int((image.size.width * CGFloat(scale)).rounded())
        let height = Int((image.size.height * CGFloat(scale)).rounded())
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// A pixel counts as inked past this much coverage. Below it the pixel is
    /// the soft edge of an antialiased curve rather than part of the shape.
    private static let inkThreshold = 0.35

    private static func alpha(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> Double {
        Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0)
    }

    // MARK: Measurements

    /// The ink's bounding box in points, rounded to hundredths so two renders
    /// of the same shape compare equal.
    private static func box(of image: NSImage, scale: Int) -> [Double]? {
        guard let rep = raster(image, scale: scale) else { return nil }
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where alpha(rep, x, y) > inkThreshold {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else { return nil }
        let s = Double(scale)
        return [Double(minX) / s, Double(minY) / s,
                Double(maxX - minX + 1) / s, Double(maxY - minY + 1) / s]
    }

    /// The two outer stroke bands on the row through the outline's middle.
    /// Their widths are the border weight, and where they start is the corner
    /// radius' only observable effect on that row.
    private static func strokeWidths(of image: NSImage, scale: Int) -> [Int]? {
        guard let rep = raster(image, scale: scale), let box = box(of: image, scale: scale) else {
            return nil
        }
        let row = Int(((box[1] + box[3] / 2) * Double(scale)).rounded())
        guard row >= 0, row < rep.pixelsHigh else { return nil }
        var bands: [Int] = [], run = 0
        for x in 0..<rep.pixelsWide {
            if alpha(rep, x, row) > inkThreshold {
                run += 1
            } else if run > 0 {
                bands.append(run); run = 0
            }
        }
        if run > 0 { bands.append(run) }
        guard bands.count >= 2 else { return nil }
        // Only the outer pair: whatever a glyph puts between them is its own.
        return [bands.first!, bands.last!]
    }

    private struct Pixel { let x: Int; let y: Int; let alpha: Double }

    /// Everything inside the outline, found without assuming where the outline
    /// is: flood the empty ground in from the border, then walk the ink it
    /// reaches. The colon is the ink left over.
    private static func colon(of image: NSImage, scale: Int) -> [Pixel]? {
        guard let rep = raster(image, scale: scale) else { return nil }
        let width = rep.pixelsWide, height = rep.pixelsHigh
        let inside = { (x: Int, y: Int) in x >= 0 && y >= 0 && x < width && y < height }
        var ground = Array(repeating: false, count: width * height)
        var queue: [(Int, Int)] = []
        for x in 0..<width { queue.append((x, 0)); queue.append((x, height - 1)) }
        for y in 0..<height { queue.append((0, y)); queue.append((width - 1, y)) }
        while let (x, y) = queue.popLast() {
            guard inside(x, y) else { continue }
            let i = y * width + x
            if ground[i] || alpha(rep, x, y) > inkThreshold { continue }
            ground[i] = true
            queue.append((x + 1, y)); queue.append((x - 1, y))
            queue.append((x, y + 1)); queue.append((x, y - 1))
        }

        // The outline is the ink the flooded ground touches, plus everything
        // connected to it.
        var outline = Array(repeating: false, count: width * height)
        var seeds: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width where alpha(rep, x, y) > inkThreshold {
                let touchesGround = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                    let nx = x + dx, ny = y + dy
                    return !inside(nx, ny) || ground[ny * width + nx]
                }
                if touchesGround { outline[y * width + x] = true; seeds.append((x, y)) }
            }
        }
        while let (x, y) = seeds.popLast() {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1),
                             (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let nx = x + dx, ny = y + dy
                guard inside(nx, ny) else { continue }
                let i = ny * width + nx
                if outline[i] || alpha(rep, nx, ny) <= inkThreshold { continue }
                outline[i] = true; seeds.append((nx, ny))
            }
        }

        var dots: [Pixel] = []
        for y in 0..<height {
            for x in 0..<width {
                let value = alpha(rep, x, y)
                if value > inkThreshold && !outline[y * width + x] {
                    dots.append(Pixel(x: x, y: y, alpha: value))
                }
            }
        }
        return dots
    }
}
