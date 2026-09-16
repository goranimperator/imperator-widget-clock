import Foundation
import WidgetKit

/// Makes the build that was just installed the one the desktop shows.
///
/// chronod keeps both the running extension process and the snapshot it drew
/// across an install, so a placed widget goes on showing the previous build
/// until something restarts the daemon. Left alone across a few installs it
/// stops drawing anything at all: a black rounded rectangle with no digits and
/// no ghosts, which looks exactly like a face whose colour vanished under
/// `Dim widgets on desktop` and is not that at all. The extension is alive
/// throughout, answers every reload and goes on writing its heartbeat, which is
/// why the live gate passes while the screen is blank.
///
/// `reloadAllTimelines()` alone does not fix it: the stale part is chronod's
/// own copy of the extension and of the picture, not the timeline. Restarting
/// chronod does, and launchd brings it back immediately.
///
/// Every widget on the desktop redraws when chronod comes back, so this runs
/// only when the bundle version has moved since the last launch. A login item
/// starting the app every morning must not restart a system daemon.
enum WidgetRefresh {
    static let versionKey = "LastLaunchedBundleVersion"

    @discardableResult
    static func afterInstall(defaults: UserDefaults = .standard,
                             bundle: Bundle = .main,
                             restart: () -> Void = restartChronod) -> Bool {
        guard let current = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !current.isEmpty else { return false }
        let previous = defaults.string(forKey: self.versionKey)
        defaults.set(current, forKey: self.versionKey)
        // `make install` stamps a monotonic CFBundleVersion, so a rebuilt copy
        // of the same release still counts as a new build here.
        guard previous != current else { return false }
        restart()
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// `killall chronod`, run rather than signalled: finding the daemon's pid
    /// means walking the process list, and the tool that already does it ships
    /// with the system.
    static func restartChronod() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["chronod"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // A missing chronod is not an error worth surfacing: the widget is
        // already going to be redrawn by the reload below.
        try? process.run()
    }
}
