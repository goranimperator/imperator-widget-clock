import AppKit
import Combine
import ClockCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var clockWindows: [DesktopClockWindow] = []
    private var cancellables: Set<AnyCancellable> = []

    private let settings = ClockSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        setUpStatusItem()
        observeSettings()
        syncDesktopClock()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Imperator Clock")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(settings: settings)
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func observeSettings() {
        settings.$showDesktopClock
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDesktopClock() }
            .store(in: &cancellables)

        settings.$faceWidth
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.clockWindows.forEach { $0.applySize() } }
            .store(in: &cancellables)

        settings.$locked
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.clockWindows.forEach { $0.applyInteraction() } }
            .store(in: &cancellables)

        settings.$allScreens
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildDesktopClocks() }
            .store(in: &cancellables)

        // A display waking, sleeping or being rearranged changes the set of
        // screens, so the windows are rebuilt rather than left stranded.
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildDesktopClocks() }
            .store(in: &cancellables)
    }

    private func syncDesktopClock() {
        guard settings.showDesktopClock else {
            closeDesktopClocks()
            return
        }
        if clockWindows.isEmpty { rebuildDesktopClocks() }
    }

    private func rebuildDesktopClocks() {
        closeDesktopClocks()
        guard settings.showDesktopClock else { return }

        let screens = settings.allScreens
            ? NSScreen.screens
            : [NSScreen.main].compactMap { $0 }

        clockWindows = screens.map { screen in
            let window = DesktopClockWindow(settings: settings, screen: screen)
            window.orderFront(nil)
            return window
        }
    }

    private func closeDesktopClocks() {
        clockWindows.forEach { $0.orderOut(nil) }
        clockWindows.removeAll()
    }
}
