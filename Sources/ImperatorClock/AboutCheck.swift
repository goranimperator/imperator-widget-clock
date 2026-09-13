import AppKit

/// `ImperatorClock --about-check` builds the real About panel and measures it
/// against brandbook 10.2 and 10.3.
///
/// The panel is the one window in the app nobody opens during normal use, so
/// nothing else would notice it drifting from the spec. It also carries the
/// `hidesOnDeactivate` fix, which has no visible effect until someone clicks
/// away from an `.accessory` app and the panel disappears.
enum AboutCheck {
    @MainActor
    static func run() -> Int32 {
        // Creating a window needs NSApp, and the checks run before main() sets
        // the app up. Touching `shared` is enough; nothing is ever run.
        _ = NSApplication.shared

        var failures: [String] = []
        let expect = { (ok: Bool, message: String) in if !ok { failures.append(message) } }

        let panel = AboutPanel.makePanel()
        let frame = panel.contentRect(forFrameRect: panel.frame)
        print("panel \(Int(frame.width))x\(Int(frame.height)) styleMask=\(panel.styleMask.rawValue)")

        // The spec's own numbers, not the app's constants. Comparing the panel
        // against the constant it was built from passes whatever the constant
        // says, which is how a 320pt panel survived this check once.
        expect(AboutPanel.width == 300,
               "AboutPanel.width is \(AboutPanel.width), brandbook 10.2 says 300")
        expect(AboutPanel.specifiedHeight == 260,
               "the brandbook height is recorded as \(AboutPanel.specifiedHeight), not 260")
        expect(frame.width == 300,
               "panel content is \(frame.width) wide, brandbook 10.2 says 300")
        expect(frame.height >= AboutPanel.specifiedHeight,
               "the panel is \(frame.height)pt tall, shorter than the brandbook's 260")
        // The panel measured 300x260 here and still came up 146pt tall on
        // screen, because the hosting controller resizes the window to what the
        // laid-out view actually needs. Lay it out and measure that instead of
        // trusting the frame that was asked for.
        if let hosted = panel.contentViewController?.view {
            hosted.layoutSubtreeIfNeeded()
            let fitting = hosted.fittingSize
            print("laid out: \(Int(fitting.width))x\(Int(fitting.height))")
            // The point of the fixed number was that nothing gets cut off.
            // Measure that directly: the panel has to be at least as tall as
            // what the laid-out content needs.
            expect(frame.height >= fitting.height,
                   "the panel is \(frame.height)pt tall but the content needs "
                   + "\(fitting.height)pt, so the bottom line is clipped")
            expect(fitting.width == 300,
                   "the laid-out view is \(fitting.width) wide, not 300")
        } else {
            failures.append("the panel has no content view")
        }

        // An empty NSImage takes no space in SwiftUI rather than drawing a
        // blank, which is how the icon went missing without the layout
        // complaining.
        let icon = AboutView.iconImage
        print("icon \(Int(icon.size.width))x\(Int(icon.size.height))")
        expect(icon.size.width > 0 && icon.size.height > 0,
               "the About icon is \(icon.size.width)x\(icon.size.height), so it renders nothing")

        for (flag, name) in [(NSWindow.StyleMask.titled, "titled"),
                             (.closable, "closable"),
                             (.fullSizeContentView, "fullSizeContentView")] {
            expect(panel.styleMask.contains(flag), "the panel is not .\(name)")
        }
        expect(panel.titlebarAppearsTransparent, "the title bar is not transparent")
        expect(panel.titleVisibility == .hidden, "the title is not hidden")
        expect(panel.isMovableByWindowBackground, "the panel cannot be dragged by its background")
        expect(!panel.isReleasedWhenClosed,
               "the panel is released when closed, so reopening it would rebuild it")
        // The one setting with no visible symptom until an .accessory app loses
        // focus, which is exactly when a user reads an About panel.
        expect(!panel.hidesOnDeactivate,
               "the panel hides on deactivate, so it vanishes on the first click outside it")

        // The strings have to come from the bundle rather than from a constant,
        // or the panel can claim a version the build does not carry.
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let version = AboutView.versionText()
        print("version line: \(version)")
        if let short, let build {
            expect(version == "Version \(short) (Build \(build))",
                   "the version line is \"\(version)\" but the bundle says \(short) (\(build))")
        } else {
            failures.append("the bundle carries no version keys; run this from the built app")
        }

        // Brandbook 10.4, with the end year stamped at launch.
        let copyright = AboutView.copyrightText(year: 2031)
        print("copyright line: \(AboutView.copyrightText())")
        expect(copyright == "© 1986-2031 Goran Imperator",
               "the copyright line reads \"\(copyright)\"")

        let url = AboutView.websiteURL
        expect(url.scheme == "https", "the website link is not https: \(url)")
        expect(url.host?.hasSuffix("goranimperator.com") == true,
               "the website link does not point at goranimperator.com: \(url)")

        panel.close()

        if failures.isEmpty {
            print("G12_ABOUT_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
