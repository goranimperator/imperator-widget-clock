import AppKit

// Menu bar only: no Dock icon, no main window. LSUIElement in Info.plist is what
// actually keeps the tile out of the Dock: it has to be set before the process
// launches, because LaunchServices decides on the tile at launch and a policy
// change from main() arrives too late to take it back. Shipping without the key
// left the app reporting `ApplicationType="Foreground"` to `lsappinfo` and a
// Dock tile with a running dot under it. The call below is still needed for the
// app switcher, and it is what makes the popover behave as an accessory window.
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
        if CommandLine.arguments.contains("--icon-check") {
            exit(IconCheck.run())
        }
        if CommandLine.arguments.contains("--about-check") {
            exit(AboutCheck.run())
        }
        if CommandLine.arguments.contains("--dim-check") {
            exit(DimCheck.run())
        }
        if let index = CommandLine.arguments.firstIndex(of: "--report"),
           CommandLine.arguments.count > index + 1 {
            exit(StoreReport.run(path: CommandLine.arguments[index + 1]))
        }
        // An unrecognised flag used to fall straight through to `run()`, which
        // launched a second copy of the app with a second menu bar icon. A
        // check that is run against an older installed binary, which is exactly
        // when a flag is unrecognised, must not do that.
        if let unknown = CommandLine.arguments.dropFirst().first(where: { $0.hasPrefix("-") }) {
            FileHandle.standardError.write(
                "ImperatorClock: unknown option \(unknown)\n"
                    .data(using: .utf8)!
            )
            let usage = "usage: ImperatorClock "
                + "[--group-check|--widget-status|--icon-check|--about-check|--dim-check]\n"
                + "       ImperatorClock --report <absolute path>\n"
            FileHandle.standardError.write(usage.data(using: .utf8)!)
            exit(2)
        }
        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
