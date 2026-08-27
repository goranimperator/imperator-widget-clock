import ClockCore
import Foundation

/// `ImperatorClock --group-check` proves, from the signed and installed binary,
/// that the settings file the widget reads is reachable and round-trips.
///
/// The store lives in the widget extension's own sandbox container. The app
/// writes it by absolute path; the widget reads it as its own home. An App Group
/// was tried first and failed: the entitlement is not honoured for a sandboxed,
/// self-signed extension, and the widget silently kept its defaults.
enum GroupCheck {
    static func run() -> Int32 {
        print("sandboxed=\(isSandboxed())")
        print("widget_container=\(SharedStore.directory.path)")
        print("settings=\(SharedStore.settingsURL.path)")

        var isDirectory: ObjCBool = false
        let containerRoot = NSHomeDirectory()
            + "/Library/Containers/" + SharedStore.widgetBundleID
        guard FileManager.default.fileExists(atPath: containerRoot,
                                             isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("FAIL the widget has no container yet; place the widget once")
            return 1
        }

        let original = SharedStore.load()
        let probe = ClockPreferences(skin: .green, neon: false, hourFormat: .twelve)
        guard SharedStore.save(probe) else {
            print("FAIL could not write \(SharedStore.settingsURL.path)")
            return 1
        }
        let readBack = SharedStore.load()
        SharedStore.save(original)

        guard readBack == probe else {
            print("FAIL wrote \(probe) but read back \(readBack)")
            return 1
        }
        print("restored=\(original.skin.rawValue) neon=\(original.neon) hours=\(original.hourFormat.rawValue)")
        print("G2B_STORE_OK")
        return 0
    }

    /// Positive control. A sandboxed process cannot read the real home
    /// directory, only its container, so a successful read here proves the
    /// sandbox is NOT in force.
    private static func isSandboxed() -> Bool {
        guard let passwd = getpwuid(getuid()) else { return false }
        let home = String(cString: passwd.pointee.pw_dir)
        return (try? FileManager.default.contentsOfDirectory(atPath: home + "/Library/Preferences")) == nil
    }
}
