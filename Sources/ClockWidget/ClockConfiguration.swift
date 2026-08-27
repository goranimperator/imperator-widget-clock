import AppIntents
import ClockCore

// The widget's own configuration, so colour and glow are chosen on the widget
// itself rather than in the app. WidgetKit builds that Edit sheet from App
// Intents metadata, which Xcode normally generates; see
// scripts/make-appintents-metadata.mjs for how it is produced here.

extension ClockSkin: @retroactive AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Colour" }

    public static var caseDisplayRepresentations: [ClockSkin: DisplayRepresentation] {
        [
            .red: "Imperator Red",
            .green: "Arcade Green",
            .blue: "Neon Blue",
            .white: "Classic White",
            .purple: "Electric Purple",
            .custom: "Custom"
        ]
    }
}

extension ClockHourFormat: @retroactive AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Hours" }

    public static var caseDisplayRepresentations: [ClockHourFormat: DisplayRepresentation] {
        [.system: "System", .twentyFour: "24-hour", .twelve: "12-hour"]
    }
}

struct ClockConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Clock"
    static let description = IntentDescription("Colour and glow for the seven-segment face.")

    @Parameter(title: "Colour", default: ClockSkin.purple)
    var skin: ClockSkin

    @Parameter(title: "Neon glow", default: true)
    var neon: Bool

    @Parameter(title: "Pulse the glow", default: false)
    var pulse: Bool

    @Parameter(title: "Hours", default: ClockHourFormat.system)
    var hourFormat: ClockHourFormat

    init() {}

    var preferences: ClockPreferences {
        ClockPreferences(skin: skin, neon: neon, pulse: pulse, hourFormat: hourFormat)
    }
}
