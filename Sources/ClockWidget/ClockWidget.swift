import ClockCore
import SwiftUI
import WidgetKit

/// The widget's look comes from the settings file the menu bar app writes into
/// this extension's own container. A WidgetConfigurationIntent would put the
/// colour picker in the widget's own Edit sheet, but that sheet is built from
/// App Intents metadata which only Xcode's `appintentsmetadataprocessor` can
/// produce, so the app owns the settings instead.
struct ClockEntry: TimelineEntry {
    let date: Date
    let preferences: ClockPreferences
    let colonLit: Bool
    let glowScale: Double
}

struct ClockProvider: TimelineProvider {
    /// Half-second entries so the colon can blink. WidgetKit pre-renders a
    /// supplied timeline and swaps entries on schedule without spending reload
    /// budget; only asking for a new timeline is budgeted. This trades a much
    /// higher timeline-request rate for a blinking colon, which is the only way
    /// a widget can animate at all.
    /// One entry per minute. Sub-minute entries were measured on macOS 26: ten
    /// frames sampled 0.22 s apart were byte-identical, so WidgetKit collapses
    /// anything finer and a half-second timeline only burns reload budget. The
    /// colon therefore sits still here; the app's desktop clock does the blink.
    private static let step: TimeInterval = 60
    private static let entryCount = 90

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), preferences: SharedStore.load(), colonLit: true, glowScale: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let preferences = SharedStore.load()
        SharedStore.writeHeartbeat(preferences, family: "snapshot")
        completion(ClockEntry(date: Date(), preferences: preferences, colonLit: true, glowScale: 1))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let preferences = SharedStore.load()
        SharedStore.writeHeartbeat(preferences, family: "timeline")

        // Start on a whole second so the blink lines up with the clock.
        let now = Date()
        let start = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))

        let entries = (0..<ClockProvider.entryCount).map { index -> ClockEntry in
            let date = start.addingTimeInterval(Double(index) * ClockProvider.step)
            // The pulse needs sub-second frames, which a widget does not get.
            let scale = 1.0
            return ClockEntry(date: date,
                              preferences: preferences,
                              colonLit: true,
                              glowScale: scale)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension ClockEntry {
    var style: ClockStyle {
        var style = preferences.style
        style.glowScale = glowScale
        return style
    }
}

struct ClockWidgetView: View {
    var entry: ClockEntry

    var body: some View {
        ClockPanelView(
            reading: ClockReading.reading(for: entry.date, format: entry.preferences.hourFormat),
            colonLit: entry.colonLit,
            style: entry.style,
            padding: 0.06
        )
        .containerBackground(for: .widget) {
            ClockStyle.faceBackground
        }
    }
}

struct RetroClockWidget: Widget {
    let kind = "ImperatorRetroClock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("ImperatorClock")
        .description("Seven-segment retro clock. Pick the colour and the neon glow in the Imperator Clock menu bar app.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        RetroClockWidget()
    }
}
