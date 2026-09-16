import ClockCore
import Foundation

/// `ImperatorClock --dim-check` proves the dimming channel end to end: the
/// mapping, the live reading, and that a dimmed face comes out white whatever
/// colour is picked.
///
/// The mapping is the part worth a gate. It was measured, not read off the
/// settings pane's App Intents metadata, because the two disagree: the metadata
/// orders the cases Automatically, Never, Always, while the key held 0 in the
/// state whose widgets actually render in greyscale and 1 for Never.
enum DimCheck {
    @MainActor
    static func run() -> Int32 {
        var failures: [String] = []
        let expect = { (ok: Bool, message: String) in if !ok { failures.append(message) } }

        expect(WidgetDimming.isDimmed(rawValue: 0),
               "0 is not treated as dimmed, and that is the value Apple's widgets go grey at")
        expect(!WidgetDimming.isDimmed(rawValue: 1),
               "1 is treated as dimmed, but 1 is Never")
        expect(!WidgetDimming.isDimmed(rawValue: nil),
               "an absent key is treated as dimmed, so a machine that never touched the "
               + "setting would lose the colour it picked")
        expect(WidgetDimming.isDimmed(rawValue: 2),
               "2 is not treated as dimmed; the metadata calls it Always")

        // The override itself: the skin stays whatever the user picked, and only
        // what is drawn changes.
        let blue = ClockPreferences(skin: .blue, widgetsDimmed: true)
        expect(blue.skin == .blue, "the dimmed face forgot the colour that was picked")
        expect(blue.effectiveStyle.flatLitComponents == ClockStyle(skin: .white, neon: false).flatLitComponents,
               "a dimmed blue face does not draw white, so it stays a black rectangle")
        let undimmed = ClockPreferences(skin: .blue, widgetsDimmed: false)
        expect(undimmed.effectiveStyle.flatLitComponents
               == ClockStyle(skin: .blue, neon: false).flatLitComponents,
               "an undimmed face is overridden anyway, so the colour picker does nothing")
        // Neon is the user's, dimmed or not.
        let neon = ClockPreferences(skin: .blue, neon: true, widgetsDimmed: true)
        expect(neon.effectiveStyle.neon, "the glow is dropped when the face is dimmed")

        // The live reading, which is the half a unit test cannot cover.
        let watch = DimWatch(settings: ClockSettings.shared)
        let raw = watch.rawValue
        let live = WidgetDimming.isDimmed(rawValue: raw)
        print("\(WidgetDimming.domain)/\(WidgetDimming.key) = "
              + (raw.map(String.init) ?? "absent") + " -> dimmed=\(live)")
        // A store that disagrees with the setting means the watcher is not
        // running or its write failed, and the widget would be drawing the
        // wrong thing right now.
        switch SharedStore.loadResult() {
        case .loaded(let stored):
            print("shared file: skin=\(stored.skin) widgetsDimmed=\(stored.widgetsDimmed)")
            expect(stored.widgetsDimmed == live,
                   "the shared file says widgetsDimmed=\(stored.widgetsDimmed) while the "
                   + "setting says \(live), so the widget is drawing the wrong face")
        case .missing:
            print("shared file: missing, nothing has been published yet")
        case .unreadable:
            failures.append("the shared file cannot be read, so the widget cannot be told "
                            + "about the dimming at all")
        }

        if failures.isEmpty {
            print("G13_DIM_CHANNEL_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
