import Foundation

/// What the face looks like. Written by the menu bar app, read by the widget
/// extension.
public struct ClockPreferences: Codable, Equatable, Sendable {
    public var skin: ClockSkin
    /// Used when `skin` is `.custom`. Six hex digits, no leading hash.
    public var customHex: String
    public var neon: Bool
    public var hourFormat: ClockHourFormat

    public init(skin: ClockSkin = .purple,
                customHex: String = ClockSkin.defaultCustomHex,
                neon: Bool = false,
                hourFormat: ClockHourFormat = .system) {
        self.skin = skin
        self.customHex = customHex
        self.neon = neon
        self.hourFormat = hourFormat
    }

    /// Every field is decoded on its own and falls back on its own. A key that
    /// is missing, or present with a value this build does not recognise, must
    /// cost only that one setting. `decodeIfPresent` throws on the second case,
    /// which would fail the whole initialiser and silently reset the lot, so
    /// each read is wrapped.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skin = (try? container.decodeIfPresent(ClockSkin.self, forKey: .skin)) as? ClockSkin ?? .purple
        let storedHex = (try? container.decodeIfPresent(String.self, forKey: .customHex))
            as? String ?? ClockSkin.defaultCustomHex
        customHex = storedHex.caseInsensitiveCompare(ClockSkin.legacyCustomHex) == .orderedSame
            ? ClockSkin.defaultCustomHex
            : storedHex
        neon = (try? container.decodeIfPresent(Bool.self, forKey: .neon)) as? Bool ?? false
        hourFormat = (try? container.decodeIfPresent(ClockHourFormat.self, forKey: .hourFormat))
            as? ClockHourFormat ?? .system
    }

    public var style: ClockStyle {
        ClockStyle(skin: skin, neon: neon, customHex: customHex)
    }
}

/// The one piece of state the app and the widget share.
///
/// It lives inside the *widget extension's own sandbox container*, not in an App
/// Group. App Groups need the entitlement to be honoured for a sandboxed
/// extension, and a self-signed build without a provisioning profile does not
/// get that: the widget silently read nothing and kept falling back to its
/// defaults. An extension may always read its own container, and the app is not
/// sandboxed, so it can write there by absolute path. Same file, both sides,
/// no entitlement involved.
public enum SharedStore {
    public static let widgetBundleID = "com.goranimperator.ImperatorClock.ClockWidget"

    /// Inside the widget `NSHomeDirectory()` is already the container's Data
    /// directory. Outside it, that is the real home, so the container is
    /// addressed the long way round.
    public static var directory: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let containerData = "Library/Containers/\(widgetBundleID)/Data"
        let base = home.path.contains(containerData)
            ? home
            : home.appendingPathComponent(containerData)
        return base
            .appendingPathComponent("Library/Application Support/ImperatorClock",
                                    isDirectory: true)
    }

    public static var settingsURL: URL {
        directory.appendingPathComponent("settings.json")
    }

    /// Written by the widget every time WidgetKit asks it for a timeline. It is
    /// the only evidence from outside that the extension really ran and what it
    /// read, so it doubles as the acceptance check for the shared store.
    public static var heartbeatURL: URL {
        directory.appendingPathComponent("widget-heartbeat.json")
    }

    public static func load() -> ClockPreferences {
        guard let data = try? Data(contentsOf: settingsURL),
              let preferences = try? JSONDecoder().decode(ClockPreferences.self, from: data) else {
            return ClockPreferences()
        }
        return preferences
    }

    @discardableResult
    public static func save(_ preferences: ClockPreferences) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: settingsURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public static func writeHeartbeat(_ preferences: ClockPreferences,
                                      family: String,
                                      at date: Date = Date()) {
        struct Heartbeat: Codable {
            let ranAt: String
            let family: String
            let skin: String
            let neon: Bool
            let hourFormat: String
            let container: String
        }
        let formatter = ISO8601DateFormatter()
        let beat = Heartbeat(ranAt: formatter.string(from: date),
                             family: family,
                             skin: preferences.skin.rawValue,
                             neon: preferences.neon,
                             hourFormat: preferences.hourFormat.rawValue,
                             container: directory.path)
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(beat).write(to: heartbeatURL, options: .atomic)
        } catch {
            // A widget cannot report anything, so a failed heartbeat is silent
            // by design. Its absence is what the acceptance check reads.
        }
    }
}
