import AppKit
import ClockCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var dimWatch: DimWatch?

    private let settings = ClockSettings.shared

    /// Brandbook 14.2, method 2. macOS ships a blue accent, and a blue control
    /// in an Imperator app is a bug. This pins the app's own accent to red;
    /// method 3, never touching `Color.accentColor`, does the rest.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(0, forKey: "AppleAccentColor")
        // NSColorPanel is restorable, so a panel that was on screen when the app
        // last quit is put back by AppKit during launch. Opening the settings
        // popover must not conjure a colour panel nobody asked for, and this has
        // to be switched off before window restoration runs, which is between
        // this call and applicationDidFinishLaunching.
        NSColorPanel.shared.isRestorable = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSColorPanel.shared.orderOut(nil)
        setUpStatusItem()
        // A new build of the app means a new build of the widget inside it, and
        // chronod will go on showing the old one until it is restarted.
        WidgetRefresh.afterInstall()
        // The widget cannot see `Dim widgets on desktop`. This app can, so it
        // reads it and writes the answer into the shared file.
        let watch = DimWatch(settings: settings)
        watch.start()
        dimWatch = watch
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusItemIcon.make()
        item.button?.toolTip = "Imperator WidgetClock"
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        // A MenuBarPanel rather than an NSPopover. macOS 27 draws its own menu
        // bar panels as plain rounded rectangles: 17.50 pt corner, no arrow and
        // no animation, measured off Control Centre's Wi-Fi panel. An NSPopover
        // draws none of that and exposes none of it for adjustment, and which
        // of its two frames it draws depends on the binary's SDK stamp. See
        // MenuBarPanel.
        let panel = MenuBarPanel(
            content: SettingsView(settings: settings) { [weak self] in
                self?.panel?.close()
            },
            width: SettingsView.width
        )
        // The colour picker is a window of its own. Every click in it is a
        // click outside this panel, and closing on it would leave the wheel
        // pointing at a dead SwiftUI binding and drop the colour that was just
        // picked. This is what `.applicationDefined` plus a hand-written mouse
        // monitor used to buy.
        panel.shouldCloseOnOutsideClick = { !NSColorPanel.shared.isVisible }
        // The colour panel is driven from inside this one, so once this is gone
        // the wheel would stand there changing nothing.
        panel.onClose = { ColorPanelController.shared.dismiss() }
        self.panel = panel
    }

    @objc private func togglePopover() {
        guard let panel, let button = statusItem?.button else { return }
        if panel.isShown {
            panel.close()
        } else {
            // The wheel is closed with the panel, so a visible one here is a
            // leftover from window restoration rather than something the user
            // opened.
            NSColorPanel.shared.orderOut(nil)
            panel.show(from: button)
            // The panel hides itself when the app deactivates, and an
            // .accessory app is inactive until something activates it. Without
            // this the panel is created, sized and ordered front, and then
            // hidden before it is ever drawn: the window exists with
            // `onscreen=false` and nothing appears under the icon.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }
}
