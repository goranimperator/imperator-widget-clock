import AppIntents
import ClockCore
import SwiftUI
import WidgetKit

/// The widget's look is chosen on the widget itself: right-click it and pick
/// Edit Widget. That sheet is built by WidgetKit from App Intents metadata,
/// which Xcode normally generates and which `make build` writes by hand instead
/// (see scripts/make-appintents-metadata.mjs).
struct ClockEntry: TimelineEntry {
    let date: Date
    let preferences: ClockPreferences
    let colonLit: Bool

    var style: ClockStyle { preferences.style }
}

struct ClockProvider: AppIntentTimelineProvider {
    /// One entry per minute. Sub-minute entries were measured on macOS 26: ten
    /// window captures 0.22 s apart were byte-identical, so WidgetKit collapses
    /// anything finer and a half-second timeline only burns reload budget. The
    /// colon therefore sits still here; the app's desktop clock does the blink.
    private static let step: TimeInterval = 60
    private static let entryCount = 90

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), preferences: ClockPreferences(), colonLit: true)
    }

    func snapshot(for configuration: ClockConfiguration, in context: Context) async -> ClockEntry {
        let preferences = configuration.preferences
        SharedStore.writeHeartbeat(preferences, family: "snapshot")
        return ClockEntry(date: Date(), preferences: preferences, colonLit: true)
    }

    func timeline(for configuration: ClockConfiguration,
                  in context: Context) async -> Timeline<ClockEntry> {
        let preferences = configuration.preferences
        SharedStore.writeHeartbeat(preferences, family: "timeline")

        let calendar = Calendar.current
        let now = Date()
        let minuteStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now

        let entries = (0..<ClockProvider.entryCount).map { index in
            ClockEntry(date: minuteStart.addingTimeInterval(Double(index) * ClockProvider.step),
                       preferences: preferences,
                       colonLit: true)
        }
        return Timeline(entries: entries, policy: .atEnd)
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
        AppIntentConfiguration(kind: kind,
                               intent: ClockConfiguration.self,
                               provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("ImperatorClock")
        .description("Seven-segment retro clock. Right-click and choose Edit Widget to pick the colour and the glow.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        RetroClockWidget()
    }
}
