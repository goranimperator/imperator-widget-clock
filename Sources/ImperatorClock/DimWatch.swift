import ClockCore
import Foundation

/// Keeps the shared file's `widgetsDimmed` in step with System Settings.
///
/// The app is unsandboxed, so it can read `com.apple.widgets`; the widget
/// cannot, and WidgetKit never tells it. Polling rather than observing: a
/// preference in another app's domain has no notification this app is entitled
/// to, and one integer read is cheap enough to do on a timer. Measured first,
/// because a long-lived process could have cached the value at launch and been
/// useless here: toggling the setting moved both `UserDefaults(suiteName:)` and
/// `CFPreferencesCopyAppValue` inside a process that had been running for
/// minutes.
@MainActor
final class DimWatch {
    /// Long enough that the read is invisible, short enough that the face
    /// catches up while the user is still looking at System Settings.
    static let interval: TimeInterval = 3

    private let settings: ClockSettings
    private var timer: Timer?
    private let defaults: UserDefaults?

    init(settings: ClockSettings,
         defaults: UserDefaults? = UserDefaults(suiteName: WidgetDimming.domain)) {
        self.settings = settings
        self.defaults = defaults
    }

    func start() {
        apply()
        let timer = Timer.scheduledTimer(withTimeInterval: DimWatch.interval, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
        // The popover blocks the default run loop mode while it is up, and the
        // setting can change behind it.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// The raw value, or nil when the key is absent.
    var rawValue: Int? {
        guard let object = defaults?.object(forKey: WidgetDimming.key) else { return nil }
        return (object as? NSNumber)?.intValue
    }

    private func apply() {
        // The setter publishes only on a change, so a poll that sees the same
        // value costs nothing beyond the read.
        settings.widgetsDimmed = WidgetDimming.isDimmed(rawValue: rawValue)
    }
}
