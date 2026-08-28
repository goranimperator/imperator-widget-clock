import AppKit
import ClockCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsController: NSHostingController<SettingsView>?
    private var outsideClickMonitor: Any?

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
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let symbol = NSImage(systemSymbolName: "clock", accessibilityDescription: "Imperator WidgetClock")
        symbol?.isTemplate = true
        item.button?.image = symbol?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        )
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        let popover = NSPopover()
        // Not `.transient`, which is what the brandbook asks for, and the reason
        // is the colour picker. NSColorPanel is a window of its own, so opening
        // it steals key from the popover and a transient popover closes on the
        // spot: the panel is left pointing at a dead SwiftUI binding and every
        // colour picked is dropped. `.applicationDefined` plus the global mouse
        // monitor below keeps the click-outside dismissal the brandbook wants
        // while the colour panel is allowed to stay up.
        popover.behavior = .applicationDefined
        popover.animates = true
        let controller = NSHostingController(rootView: SettingsView(settings: settings))
        // The popover is positioned from its contentSize at the moment it is
        // shown. Left to grow afterwards it expands around the anchor instead of
        // hanging below it, and the header ends up above the top of the screen.
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        popover.contentSize = controller.view.fittingSize
        settingsController = controller
        popover.delegate = self
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // The panel is closed with the popover, so a visible one here is a
            // leftover from restoration rather than something the user opened.
            NSColorPanel.shared.orderOut(nil)
            if let size = settingsController?.view.fittingSize, size.height > 0 {
                popover.contentSize = size
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            startOutsideClickMonitor()
        }
    }

    /// Restores the click-outside dismissal that `.transient` would have given,
    /// without its habit of closing on the colour panel.
    ///
    /// A global monitor is meant to see only events in *other* applications, but
    /// the first click into an inactive accessory app's popover reaches it too,
    /// which closed the popover before the click landed on the control under the
    /// cursor. So "outside" is decided by the pointer, not by the monitor.
    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let popover = self.popover, popover.isShown else { return }
                guard !NSColorPanel.shared.isVisible else { return }
                let pointer = NSEvent.mouseLocation
                if let window = popover.contentViewController?.view.window,
                   window.frame.contains(pointer) {
                    return
                }
                if let button = self.statusItem?.button, let window = button.window,
                   window.convertToScreen(button.frame).contains(pointer) {
                    return
                }
                popover.performClose(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

}

extension AppDelegate: NSPopoverDelegate {
    /// The colour panel is driven by a SwiftUI ColorPicker that lives inside the
    /// popover. Once the popover is gone the panel would keep standing there
    /// changing nothing, so it goes with it.
    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        ColorPanelController.shared.dismiss()
    }
}
