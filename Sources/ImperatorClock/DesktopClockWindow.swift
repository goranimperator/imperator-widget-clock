import AppKit
import ClockCore
import SwiftUI

/// The clock face as it sits on the desktop. `TimelineView` redraws ten times a
/// second, which is what gives the colon its one-second blink and the neon its
/// pulse. Neither is something a WidgetKit widget can do smoothly.
struct DesktopClockView: View {
    @ObservedObject var settings: ClockSettings

    /// The pulse is the only thing that needs sub-second frames. Without it the
    /// colon is the fastest moving part, and that changes twice a second.
    private var tick: TimeInterval {
        settings.neon && settings.pulse ? 0.1 : 0.5
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: tick)) { context in
            let panel = ClockPanelView(
                reading: ClockReading.reading(for: context.date, format: settings.hourFormat),
                colonLit: ClockReading.colonLit(at: context.date),
                style: settings.preferences.style(at: context.date),
                padding: 0.06
            )
            if settings.showPlate {
                WidgetContainer { panel }
                    .padding(14)
            } else {
                panel
            }
        }
    }
}

/// Borderless panel pinned at desktop-icon level: above the wallpaper, below
/// every real window, present on all Spaces. One of these per display.
final class DesktopClockWindow: NSPanel {
    private let settings: ClockSettings
    private let autosaveName: String

    init(settings: ClockSettings, screen: NSScreen) {
        self.settings = settings
        // Keyed on the display, not on its index in NSScreen.screens: unplugging
        // a monitor renumbers that list, and an index-keyed frame would then be
        // restored onto a different physical screen.
        let displayID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber)?.uint32Value ?? 0
        self.autosaveName = "ImperatorDesktopClock-display-\(displayID)"
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: settings.faceWidth, height: settings.faceHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        let host = NSHostingView(rootView: DesktopClockView(settings: settings))
        host.frame = contentLayoutRect
        host.autoresizingMask = [.width, .height]
        contentView = host

        setFrameAutosaveName(autosaveName)
        applyInteraction()
        placeIfUnpositioned(on: screen)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func applyInteraction() {
        ignoresMouseEvents = settings.locked
    }

    /// Resize around the window's own centre so the clock grows in place.
    func applySize() {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let size = NSSize(width: settings.faceWidth, height: settings.faceHeight)
        setFrame(
            NSRect(x: center.x - size.width / 2,
                   y: center.y - size.height / 2,
                   width: size.width,
                   height: size.height),
            display: true
        )
        saveFrame(usingName: autosaveName)
    }

    /// A display with no saved position gets the clock in its middle.
    private func placeIfUnpositioned(on screen: NSScreen) {
        let restored = setFrameUsingName(autosaveName)
        let onThisScreen = screen.visibleFrame.intersects(frame)
        guard !restored || !onThisScreen else { return }
        let visible = screen.visibleFrame
        setFrame(NSRect(x: visible.midX - settings.faceWidth / 2,
                        y: visible.midY - settings.faceHeight / 2,
                        width: settings.faceWidth,
                        height: settings.faceHeight),
                 display: true)
    }
}
