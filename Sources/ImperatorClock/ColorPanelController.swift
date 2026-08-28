import AppKit
import SwiftUI

/// Opens the system colour panel and feeds every change back to the caller.
///
/// SwiftUI's `ColorPicker` was tried first and does not work here: its colour
/// well draws a pill that does not match the swatch row, and inside a menu bar
/// popover of an `.accessory` app clicking it focuses the well without ever
/// bringing the panel up. Driving `NSColorPanel` directly also lets the app
/// activate first, which is what actually makes the panel appear.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var handler: ((NSColor) -> Void)?
    /// NSColorPanel exposes no readable target, so ownership is tracked here.
    private var isDriving = false

    func present(current: NSColor, onPick: @escaping (NSColor) -> Void) {
        handler = onPick
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        // An NSPanel hides itself when its app deactivates, and this app is an
        // .accessory that goes inactive the moment anything else is clicked. Left
        // alone the colour panel was ordered front and then hidden again a
        // fraction of a second later, which looked exactly like a picker that
        // does not open.
        panel.hidesOnDeactivate = false
        // Continuous, so the face in the popover follows the wheel while it is
        // being dragged. The write to the shared file is coalesced further down
        // in ClockSettings, so this does not drain WidgetKit's reload budget.
        panel.isContinuous = true
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        isDriving = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        let panel = NSColorPanel.shared
        if isDriving {
            panel.setTarget(nil)
            panel.setAction(nil)
            isDriving = false
        }
        handler = nil
        panel.orderOut(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        handler?(sender.color)
    }
}
