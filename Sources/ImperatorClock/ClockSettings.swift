import ClockCore
import Foundation
import SwiftUI
import WidgetKit

/// Settings for both surfaces.
///
/// Colour, glow and hour format go to the App Group file the widget reads, and
/// every change asks WidgetKit for a fresh timeline so the widget catches up at
/// once. Everything else here only concerns the desktop window and stays in the
/// app's own defaults.
@MainActor
final class ClockSettings: ObservableObject {
    static let shared = ClockSettings()

    private let defaults = UserDefaults.standard
    private var publishWorkItem: DispatchWorkItem?

    @Published var skin: ClockSkin {
        didSet { publishShared() }
    }
    /// Six hex digits. Only used when `skin` is `.custom`.
    @Published var customHex: String {
        didSet { publishShared() }
    }
    @Published var neon: Bool {
        didSet { publishShared() }
    }
    /// With neon on, the glow swells once a second.
    @Published var pulse: Bool {
        didSet { publishShared() }
    }
    @Published var hourFormat: ClockHourFormat {
        didSet { publishShared() }
    }
    @Published var showDesktopClock: Bool {
        didSet { defaults.set(showDesktopClock, forKey: Key.showDesktopClock) }
    }
    @Published var faceWidth: Double {
        didSet { defaults.set(faceWidth, forKey: Key.faceWidth) }
    }
    @Published var showPlate: Bool {
        didSet { defaults.set(showPlate, forKey: Key.showPlate) }
    }
    /// Locked means the window ignores the mouse, so clicks land on the desktop
    /// behind it. Unlocked, the clock can be dragged to a new spot.
    @Published var locked: Bool {
        didSet { defaults.set(locked, forKey: Key.locked) }
    }
    /// One clock window per display, rather than only the main one.
    @Published var allScreens: Bool {
        didSet { defaults.set(allScreens, forKey: Key.allScreens) }
    }

    private enum Key {
        static let showDesktopClock = "showDesktopClock"
        static let faceWidth = "faceWidth"
        static let showPlate = "showPlate"
        static let locked = "locked"
        static let allScreens = "allScreens"
    }

    private init() {
        defaults.register(defaults: [
            Key.showDesktopClock: false,
            Key.faceWidth: 420.0,
            Key.showPlate: true,
            Key.locked: false,
            Key.allScreens: true
        ])
        let shared = SharedStore.load()
        skin = shared.skin
        customHex = shared.customHex
        neon = shared.neon
        pulse = shared.pulse
        hourFormat = shared.hourFormat
        showDesktopClock = defaults.bool(forKey: Key.showDesktopClock)
        faceWidth = defaults.double(forKey: Key.faceWidth)
        showPlate = defaults.bool(forKey: Key.showPlate)
        locked = defaults.bool(forKey: Key.locked)
        allScreens = defaults.bool(forKey: Key.allScreens)
    }

    var preferences: ClockPreferences {
        ClockPreferences(skin: skin,
                         customHex: customHex,
                         neon: neon,
                         pulse: pulse,
                         hourFormat: hourFormat)
    }

    var style: ClockStyle { preferences.style }

    /// Write the shared file, then nudge WidgetKit. Without the nudge the widget
    /// would keep its old colour until its current timeline ran out.
    ///
    /// Coalesced on purpose. Dragging in the colour wheel fires the setter
    /// continuously, and one file write plus one `reloadAllTimelines()` per tick
    /// would spend WidgetKit's daily reload budget in a few seconds, after which
    /// the widget stops picking up any change at all.
    private static let publishDelay: TimeInterval = 0.4

    private func publishShared() {
        publishWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            SharedStore.save(self.preferences)
            WidgetCenter.shared.reloadAllTimelines()
        }
        publishWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + ClockSettings.publishDelay,
                                      execute: item)
    }

    /// Height that keeps the face's proportions at the chosen width.
    var faceHeight: Double {
        faceWidth / Double(ClockLayout.faceWidth) * Double(ClockLayout.faceHeight)
    }
}
