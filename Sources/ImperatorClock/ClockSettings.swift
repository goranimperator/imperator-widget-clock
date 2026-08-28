import ClockCore
import Foundation
import SwiftUI
import WidgetKit

/// Everything the face looks like.
///
/// All of it goes to the file the widget reads, and every change asks WidgetKit
/// for a fresh timeline so the widget catches up at once.
@MainActor
final class ClockSettings: ObservableObject {
    static let shared = ClockSettings()

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
    @Published var hourFormat: ClockHourFormat {
        didSet { publishShared() }
    }
    private init() {
        let shared = SharedStore.load()
        skin = shared.skin
        customHex = shared.customHex
        neon = shared.neon
        hourFormat = shared.hourFormat
    }

    var preferences: ClockPreferences {
        ClockPreferences(skin: skin,
                         customHex: customHex,
                         neon: neon,
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
}
