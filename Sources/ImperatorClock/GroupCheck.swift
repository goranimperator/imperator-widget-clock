import ClockCore
import Foundation

/// `ImperatorClock --group-check` proves, from the signed and installed binary,
/// that the settings file the widget reads is reachable and round-trips.
///
/// The store lives in the real home at `~/Library/Application Support/
/// ImperatorClock`, and the sandboxed widget reaches it through a temporary
/// exception entitlement. Two earlier homes failed: an App Group, whose
/// identifier has to carry a signing team ID a self-signed build does not have,
/// and the widget extension's own container, which macOS 27 closed to everyone
/// outside it. The name and the flag are left alone on purpose: renaming them
/// would break every GATES.md line and every note that cites them.
enum GroupCheck {
    static func run() -> Int32 {
        print("sandboxed=\(isSandboxed())")
        print("store=\(SharedStore.directory.path)")
        print("settings=\(SharedStore.settingsURL.path)")

        // The store used to live in the widget's container and the check began
        // by proving that container existed. It does not live there any more:
        // macOS 27 closed outside access to another app's container, so the app
        // could neither read nor write it. There is nothing to prove up front
        // now; the write below is the whole test.

        // Restoring what `load()` returned is only safe when it really read
        // something. A file that exists but cannot be read also returns the
        // defaults, and writing those back is how a gate destroys the settings
        // it claims to round-trip.
        let existing = SharedStore.loadResult()
        if existing == .unreadable {
            print("FAIL \(SharedStore.settingsURL.path) exists but could not be read")
            print("     refusing to probe: the restore would overwrite it with defaults")
            return 1
        }
        let original = SharedStore.load()
        let probe = ClockPreferences(skin: .green, neon: false, hourFormat: .twelve)
        guard SharedStore.save(probe) else {
            print("FAIL could not write \(SharedStore.settingsURL.path)")
            print("     run --report to see the real error")
            return 1
        }
        let readBack = SharedStore.load()
        guard SharedStore.save(original) else {
            print("FAIL could not restore \(SharedStore.settingsURL.path); it now holds the probe")
            return 1
        }

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
