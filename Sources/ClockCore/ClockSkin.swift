import SwiftUI

/// Display colours, shared with `Skin` in imperator-retropong so the family of
/// apps lights up in the same five colours.
public enum ClockSkin: String, CaseIterable, Codable, Sendable {
    case red
    case green
    case blue
    case white
    case purple
    /// Free choice, its value carried alongside in `ClockPreferences.customHex`.
    case custom

    public var displayName: String {
        switch self {
        case .red:    return "Imperator Red"
        case .green:  return "Arcade Green"
        case .blue:   return "Neon Blue"
        case .white:  return "Classic White"
        case .purple: return "Electric Purple"
        case .custom: return "Custom"
        }
    }

    /// 0-1 components. Values copied from imperator-retropong `Skin.color`.
    public var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .red:    return (0xa0 / 255, 0x18 / 255, 0x18 / 255)
        case .green:  return (0, 1, 0)
        case .blue:   return (0x18 / 255, 0x40 / 255, 0xd4 / 255)
        case .white:  return (1, 1, 1)
        case .purple: return (0x8b / 255, 0x18 / 255, 0xd4 / 255)
        // A custom skin's colour lives in ClockPreferences.customHex, which the
        // enum cannot see. Resolve it through ClockStyle.baseComponents, never
        // here.
        case .custom: return ClockSkin.components(fromHex: ClockSkin.defaultCustomHex)
        }
    }

    public static let defaultCustomHex = "FF7A18"

    /// Presets only, for the swatch row. `.custom` is offered separately.
    public static var presets: [ClockSkin] { allCases.filter { $0 != .custom } }

    public static func components(fromHex hex: String)
        -> (red: Double, green: Double, blue: Double) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return (1, 1, 1)
        }
        return (Double((value >> 16) & 0xff) / 255,
                Double((value >> 8) & 0xff) / 255,
                Double(value & 0xff) / 255)
    }

    public static func hex(fromComponents c: (red: Double, green: Double, blue: Double)) -> String {
        func channel(_ value: Double) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", channel(c.red), channel(c.green), channel(c.blue))
    }

    static func hsb(from c: (red: Double, green: Double, blue: Double))
        -> (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(c.red, c.green, c.blue)
        let minValue = min(c.red, c.green, c.blue)
        let delta = maxValue - minValue
        guard delta > 0, maxValue > 0 else { return (0, 0, maxValue) }

        var hue: Double
        if maxValue == c.red {
            hue = (c.green - c.blue) / delta
        } else if maxValue == c.green {
            hue = 2 + (c.blue - c.red) / delta
        } else {
            hue = 4 + (c.red - c.green) / delta
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, delta / maxValue, maxValue)
    }

    static func rgb(hue: Double, saturation: Double, brightness: Double)
        -> (red: Double, green: Double, blue: Double) {
        guard saturation > 0 else { return (brightness, brightness, brightness) }
        let sector = (hue - hue.rounded(.down)) * 6
        let index = Int(sector.rounded(.down))
        let fraction = sector - Double(index)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        switch index % 6 {
        case 0:  return (brightness, t, p)
        case 1:  return (q, brightness, p)
        case 2:  return (p, brightness, t)
        case 3:  return (p, q, brightness)
        case 4:  return (t, p, brightness)
        default: return (brightness, p, q)
        }
    }
}

/// How the hour is numbered.
public enum ClockHourFormat: String, CaseIterable, Codable, Sendable {
    /// Follow the locale's 12/24-hour preference.
    case system
    case twentyFour
    case twelve

    public var displayName: String {
        switch self {
        case .system:     return "System"
        case .twentyFour: return "24-hour"
        case .twelve:     return "12-hour"
        }
    }

    /// True when the hour should be shown 1-12.
    public func usesTwelveHour(locale: Locale = .current) -> Bool {
        switch self {
        case .twentyFour: return false
        case .twelve:     return true
        case .system:
            let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "H"
            return template.contains("a") || template.contains("h")
        }
    }
}
