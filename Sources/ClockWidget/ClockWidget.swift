import ClockCore
import SwiftUI
import WidgetKit

/// One widget, one card in the gallery.
///
/// Colour, glow and hour format are settings, and settings live in the menu bar
/// app. Two earlier shapes were tried and dropped. A `WidgetConfigurationIntent`
/// would put the colour in the widget's own Edit sheet, but that sheet is built
/// from App Intents metadata that only Xcode's appintentsmetadataprocessor can
/// generate; hand-written metadata got as far as an Edit item in the context
/// menu and a sheet with no controls in it. Publishing one `StaticConfiguration`
/// per colour worked, but it filled the gallery with six near-identical cards
/// for a choice the app already owns. So: a single card that reads the shared
/// file, and nothing to configure on the widget itself.
struct ClockEntry: TimelineEntry {
    let date: Date
    let preferences: ClockPreferences

    var style: ClockStyle { preferences.style }
}

struct ClockProvider: TimelineProvider {
    /// One entry per minute. Sub-minute entries were measured on macOS 26: ten
    /// window captures 0.22 s apart were byte-identical, so WidgetKit collapses
    /// anything finer and a half-second timeline only burns reload budget. The
    /// colon therefore sits still here; the app's desktop clock does the blink.
    private static let step: TimeInterval = 60
    private static let entryCount = 90

    private func preferences() -> ClockPreferences {
        SharedStore.load()
    }

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), preferences: preferences())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), preferences: preferences()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let preferences = preferences()
        SharedStore.writeHeartbeat(preferences, family: preferences.skin.rawValue)

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
            style: entry.style,
            padding: 0.01
        )
        .containerBackground(for: .widget) {
            ClockStyle.faceBackground
        }
    }
}

/// `kind` is how WidgetKit identifies a placed widget, so renaming it empties
/// the slot on the desktop and the widget has to be placed again.
struct ClockWidget: Widget {
    let kind = "ImperatorClock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("Imperator WidgetClock")
        .description("Seven-segment retro clock. Colour, glow and hour format are set in the Imperator WidgetClock menu bar app.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
    }
}
