import ClockCore
import SwiftUI
import WidgetKit

/// One widget per colour.
///
/// The obvious design is a single widget with a `WidgetConfigurationIntent`, so
/// the colour is picked in the widget's own Edit sheet. That sheet is built from
/// App Intents metadata, which Xcode generates with appintentsmetadataprocessor;
/// hand-written metadata is indexed by `linkd` and does put `Edit "..."` in the
/// widget's context menu, but the sheet still renders without controls. Until
/// that is solved the gallery carries one card per colour instead, which needs
/// no metadata and no settings app: the colour is chosen by choosing the card.
struct ClockEntry: TimelineEntry {
    let date: Date
    let preferences: ClockPreferences

    var style: ClockStyle { preferences.style }
}

struct ClockProvider: TimelineProvider {
    let skin: ClockSkin

    /// One entry per minute. Sub-minute entries were measured on macOS 26: ten
    /// window captures 0.22 s apart were byte-identical, so WidgetKit collapses
    /// anything finer and a half-second timeline only burns reload budget. The
    /// colon therefore sits still here; the app's desktop clock does the blink.
    private static let step: TimeInterval = 60
    private static let entryCount = 90

    /// Colour comes from the widget's own kind. Everything else is shared, so a
    /// custom hex or a changed hour format still reaches every card.
    private func preferences() -> ClockPreferences {
        var preferences = SharedStore.load()
        preferences.skin = skin
        return preferences
    }

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), preferences: preferences())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), preferences: preferences()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let preferences = preferences()
        SharedStore.writeHeartbeat(preferences, family: skin.rawValue)

        let calendar = Calendar.current
        let now = Date()
        let minuteStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now

        let entries = (0..<ClockProvider.entryCount).map { index in
            ClockEntry(date: minuteStart.addingTimeInterval(Double(index) * ClockProvider.step),
                       preferences: preferences)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ClockWidgetView: View {
    var entry: ClockEntry

    var body: some View {
        ClockPanelView(
            reading: ClockReading.reading(for: entry.date, format: entry.preferences.hourFormat),
            colonLit: true,
            style: entry.style,
            padding: 0.06
        )
        .containerBackground(for: .widget) {
            ClockStyle.faceBackground
        }
    }
}

/// A gallery card for one colour. `kind` must stay stable: it is how WidgetKit
/// identifies a placed widget, so renaming one drops it off the desktop.
struct ColourClockWidget: Widget {
    /// Defaulted so the struct still has the `init()` that `Widget` requires.
    var skin: ClockSkin = .purple

    var kind: String { "ImperatorClock.\(skin.rawValue)" }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider(skin: skin)) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName(displayName)
        .description(summary)
        .supportedFamilies([.systemMedium])
    }

    private var displayName: String {
        skin == .custom ? "Clock, custom colour" : "Clock, \(skin.displayName)"
    }

    private var summary: String {
        skin == .custom
            ? "Seven-segment retro clock in a colour of your own, picked in the ImperatorClock app."
            : "Seven-segment retro clock in \(skin.displayName)."
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        ColourClockWidget(skin: .purple)
        ColourClockWidget(skin: .red)
        ColourClockWidget(skin: .green)
        ColourClockWidget(skin: .blue)
        ColourClockWidget(skin: .white)
        ColourClockWidget(skin: .custom)
    }
}
