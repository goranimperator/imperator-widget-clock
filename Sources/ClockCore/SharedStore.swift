import Foundation

/// What the face looks like. Written by the menu bar app, read by the widget
/// extension.
public struct ClockPreferences: Codable, Equatable, Sendable {
    public var skin: ClockSkin
    /// Used when `skin` is `.custom`. Six hex digits, no leading hash.
    public var customHex: String
    public var neon: Bool
    public var hourFormat: ClockHourFormat
    /// Whether macOS is dimming desktop widgets. System state, not a setting:
    /// the app reads `WidgetDimming` and writes the answer here, because the
    /// widget is sandboxed and cannot read another app's preferences.
    public var widgetsDimmed: Bool

    public init(skin: ClockSkin = .white,
                customHex: String = ClockSkin.defaultCustomHex,
                neon: Bool = false,
                hourFormat: ClockHourFormat = .system,
                widgetsDimmed: Bool = false) {
        self.skin = skin
        self.customHex = customHex
        self.neon = neon
        self.hourFormat = hourFormat
        self.widgetsDimmed = widgetsDimmed
    }

    /// Every field is decoded on its own and falls back on its own. A key that
    /// is missing, or present with a value this build does not recognise, must
    /// cost only that one setting. `decodeIfPresent` throws on the second case,
    /// which would fail the whole initialiser and silently reset the lot, so
    /// each read is wrapped.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skin = (try? container.decodeIfPresent(ClockSkin.self, forKey: .skin)) as? ClockSkin ?? .white
        let storedHex = (try? container.decodeIfPresent(String.self, forKey: .customHex))
            as? String ?? ClockSkin.defaultCustomHex
        customHex = ClockSkin.legacyCustomHexes.contains {
            storedHex.caseInsensitiveCompare($0) == .orderedSame
        } ? ClockSkin.defaultCustomHex : storedHex
        neon = (try? container.decodeIfPresent(Bool.self, forKey: .neon)) as? Bool ?? false
        hourFormat = (try? container.decodeIfPresent(ClockHourFormat.self, forKey: .hourFormat))
            as? ClockHourFormat ?? .system
        widgetsDimmed = (try? container.decodeIfPresent(Bool.self, forKey: .widgetsDimmed))
            as? Bool ?? false
    }

    /// The colour that was picked.
    public var style: ClockStyle {
        ClockStyle(skin: skin, neon: neon, customHex: customHex)
    }

    /// The colour the face draws, which is white while macOS is dimming
    /// widgets.
    ///
    /// Dimming is a greyscale composite applied from outside the widget, and
    /// greyscale maps a colour to its luminance: Imperator Blue's is 0.07, so a
    /// blue face came back as a black rectangle. Nothing the widget draws can
    /// undo that, and the one skin that survives it is the one that is already
    /// white. Both the widget and the popover preview go through here, so the
    /// preview shows what the desktop will show.
    public var effectiveStyle: ClockStyle {
        guard widgetsDimmed else { return style }
        return ClockStyle(skin: .white, neon: neon, customHex: customHex)
    }
}

/// The one piece of state the app and the widget share.
///
/// It lives in the real home at `~/Library/Application Support/ImperatorClock`,
/// which the unsandboxed app owns outright. Two earlier homes did not survive:
///
/// An App Group needs its identifier prefixed with the signing team ID, and a
/// self-signed build has no team. `containermanagerd` rejects it and the
/// rejection kills the extension at sandbox init.
///
/// The widget extension's own container worked until macOS 27, which closed
/// outside access to another app's container. The app then could neither read
/// nor write it: `NSCocoaErrorDomain 257` on read and `513` on write, even when
/// launched by LaunchServices so it was responsible for itself. Nothing the
/// user changed reached the widget any more, and because the write failed
/// silently the app kept showing the colour it had only in memory.
///
/// So the file sits where the app can always write, and the widget reaches it
/// through a sandbox temporary exception declared in `ClockWidget.entitlements`.
/// That exception is a plain entitlement: unlike an App Group it is not checked
/// against a team ID, so a self-signed build can carry it.
public enum SharedStore {
    public static let widgetBundleID = "com.goranimperator.ImperatorClock.ClockWidget"

    /// The path the entitlement names, relative to the real home. Keep the two
    /// in step: the sandbox grants exactly this prefix and nothing else.
    public static let homeRelativePath = "Library/Application Support/ImperatorClock"

    /// The real home, not the container.
    ///
    /// Inside a sandbox `NSHomeDirectory()` is redirected to the container, so
    /// the app and the widget would compute different paths from it and never
    /// meet. `getpwuid` reads the passwd entry and is not redirected.
    static var realHome: URL {
        if let passwd = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: passwd.pointee.pw_dir))
        }
        // NSHomeDirectory() is the container inside the widget, which is the
        // split this function exists to prevent: the app and the widget would
        // read different files and both would think they succeeded. If the
        // passwd lookup ever fails, fail where it can be seen.
        preconditionFailure("no passwd entry for uid \(getuid()); cannot locate the real home")
    }

    public static var directory: URL {
        realHome.appendingPathComponent(homeRelativePath, isDirectory: true)
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

    /// The store's old home, readable only from inside the widget.
    ///
    /// Until macOS 27 the file lived in the widget extension's own container.
    /// The app cannot reach it any more, but the extension always can: inside
    /// the sandbox `NSHomeDirectory()` *is* that container. So the widget is
    /// the one process that can carry a user's settings forward, and it does
    /// that once, on its first timeline after the upgrade.
    static var legacySettingsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/ImperatorClock", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// Copy the pre-macOS-27 settings forward if nothing has been written to
    /// the new location yet. Safe to call on every timeline: it does nothing
    /// once the new file exists.
    @discardableResult
    public static func migrateFromWidgetContainer() -> Bool {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: settingsURL.path) else { return false }
        let legacy = legacySettingsURL
        guard legacy != settingsURL,
              let data = try? Data(contentsOf: legacy),
              let preferences = try? JSONDecoder().decode(ClockPreferences.self, from: data) else {
            return false
        }
        return save(preferences)
    }

    /// What `load()` found, for callers that must not confuse "nothing saved
    /// yet" with "saved, but unreadable". Writing defaults back over a file
    /// that merely failed to read destroys the settings it was restoring.
    public enum LoadResult: Equatable {
        case loaded(ClockPreferences)
        case missing
        case unreadable
    }

    public static func loadResult() -> LoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: settingsURL)
        } catch {
            return (error as NSError).code == NSFileReadNoSuchFileError ? .missing : .unreadable
        }
        guard let preferences = try? JSONDecoder().decode(ClockPreferences.self, from: data) else {
            return .unreadable
        }
        return .loaded(preferences)
    }

    public static func load() -> ClockPreferences {
        if case .loaded(let preferences) = loadResult() { return preferences }
        return ClockPreferences()
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
