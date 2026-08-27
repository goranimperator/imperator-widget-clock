import AppKit

// Menu bar only: no Dock icon, no main window. LSUIElement in Info.plist keeps
// it out of the Dock; .accessory keeps it out of the app switcher.
@main
@MainActor
struct ImperatorClockApp {
    /// NSApplication holds its delegate weakly, so keep a strong reference.
    static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.contains("--group-check") {
            exit(GroupCheck.run())
        }
        if CommandLine.arguments.contains("--widget-status") {
            exit(WidgetStatus.run())
        }
        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
