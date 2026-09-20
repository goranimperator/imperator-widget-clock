import AppKit
import ClockCore
import ServiceManagement
import SwiftUI

/// The menu bar popover, laid out the way the Imperator apps brandbook asks a
/// popover app to be laid out: header, divider, scrolling content, divider,
/// footer, 340pt wide, forced dark, brand red instead of the system accent.
struct SettingsView: View {
    @ObservedObject var settings: ClockSettings
    /// Closes the popover. The About panel is centred on screen while the
    /// popover hangs off the menu bar, and leaving both up means the user has
    /// two things to dismiss instead of one.
    var dismissPopover: () -> Void = {}

    static let width: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                if settings.writeFailed { writeFailureNotice }
                preview
                colourSection
                glowSection
                hourSection
            }
            .padding(16)
            Divider()
            footer
        }
        .frame(width: SettingsView.width)
        // No scroll view and no height cap: the popover is exactly as tall as
        // what is in it.
        .fixedSize(horizontal: false, vertical: true)
        .background(AppColors.popoverBackground)
    }

    // MARK: - Header and footer

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // The app's own menu bar glyph at 16pt, left of the name, the way
            // imperator-free-games and the other popover apps do it. Brandbook
            // 16.1 keeps the sigil out of the header; this is the app's icon,
            // not the sigil.
            Image(nsImage: SettingsView.headerIcon)
                .renderingMode(.template)
                .foregroundStyle(.primary)
            Text("Imperator WidgetClock")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Drawn once. The header is rebuilt on every settings change, and the
    /// glyph never varies.
    private static let headerIcon = StatusItemIcon.make(size: 16)

    private var footer: some View {
        HStack(spacing: 12) {
            LaunchAtLoginToggle()
            Spacer()
            // Brandbook 10.1 puts About next to Quit and names it "About
            // Imperator WidgetClock". The row already carries the login toggle
            // inside 340pt, so the full name is the tooltip and the button
            // reads "About", the way the other popover apps do it.
            HoverButton {
                dismissPopover()
                AboutPanel.show()
            } label: {
                Text("About").font(.caption)
            }
            .help("About Imperator WidgetClock")
            HoverButton {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit").font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Shown only when the shared file could not be written. Without it a
    /// failed write looks exactly like a working one, which is how the macOS 27
    /// breakage stayed invisible.
    private var writeFailureNotice: some View {
        Text("Could not save to \(SharedStore.directory.path). The widget will "
             + "keep showing its last saved settings.")
            .font(.system(size: 10))
            .foregroundStyle(AppColors.brand)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var colourSection: some View {
        section("Colour") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(ClockSkin.presets, id: \.self) { skin in
                        let swatch = ClockStyle(skin: skin, neon: false)
                        SkinSwatch(color: swatch.flatLitColor,
                                   help: skin.displayName,
                                   isSelected: settings.skin == skin,
                                   components: swatch.flatLitComponents) {
                            settings.skin = skin
                        }
                    }
                    // The sixth swatch is the colour well itself: clicking it
                    // opens the system colour picker and selects the custom
                    // skin, so there is one control rather than a swatch that
                    // has to be armed before a separate picker means anything.
                    let custom = ClockStyle(skin: .custom, neon: false,
                                            customHex: settings.customHex)
                    SkinSwatch(color: custom.flatLitColor,
                               help: "Pick any colour",
                               isSelected: settings.skin == .custom,
                               components: custom.flatLitComponents,
                               showsPen: true) {
                        openColorPanel()
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("The swatch with the pen opens the colour wheel. Pick any colour you like.")
                    // The widget is never told about the dimming, and cannot
                    // read the setting either. This app can, so DimWatch reads
                    // it and the face switches itself. Greyscale maps a colour
                    // to its luminance and blue's is 0.07, so the alternative
                    // was a black rectangle.
                    Text("With Dim widgets on desktop turned on, macOS draws the widget "
                         + "in greyscale, which turns a colour into its grey. The face "
                         + "renders white while that is on and picks your colour back up "
                         + "when you turn it off.")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var glowSection: some View {
        section("Glow") {
            VStack(alignment: .leading, spacing: 8) {
                BrandToggle("Neon glow", isOn: $settings.neon)
            }
        }
    }

    private var hourSection: some View {
        section("Hours") {
            HourFormatPicker(selection: $settings.hourFormat)
        }
    }

    // MARK: - Custom colour

    /// The raw picked colour, for seeding the colour wheel. The swatch shows
    /// `flatLitColor` instead, because that is what the face draws: a dark pick
    /// comes back near-white on the clock, and a swatch showing the raw value
    /// would contradict the preview sitting right above it.
    private var customColor: Color {
        let c = ClockSkin.components(fromHex: settings.customHex)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    /// Picking a colour also selects the custom swatch: choosing a colour and
    /// then not seeing it is the single most confusing thing this panel can do.
    private func applyCustom(_ hex: String) {
        settings.customHex = hex
        settings.skin = .custom
    }

    /// The custom swatch is the button that opens the picker, so one click both
    /// selects the custom skin and puts the wheel on screen.
    private func openColorPanel() {
        settings.skin = .custom
        let c = ClockSkin.components(fromHex: settings.customHex)
        let current = NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        ColorPanelController.shared.present(current: current) { picked in
            let rgb = picked.usingColorSpace(.sRGB) ?? .white
            applyCustom(ClockSkin.hex(fromComponents: (Double(rgb.redComponent),
                                                       Double(rgb.greenComponent),
                                                       Double(rgb.blueComponent))))
        }
    }

    private var preview: some View {
        ClockFaceView(
            reading: ClockReading(digits: [0, 6, 5, 3]),
            style: settings.style
        )
        .padding(12)
        .frame(height: 92)
        .frame(maxWidth: .infinity)
        // The popover's own corner, not the widget's. macOS 27 clips popover
        // content at 19.75 pt and rounds a desktop widget at 30, both measured
        // off the real windows, and the card is seen inside the popover's
        // corner rather than next to the widget. At 30 it bulged against the
        // frame holding it.
        .background(
            RoundedRectangle(cornerRadius: ClockStyle.panelCornerRadius,
                             style: .continuous)
                .fill(ClockStyle.faceBackground)
        )
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Three segments across the full width, in brand red.
///
/// SwiftUI's `.segmented` picker sizes itself to its widest label and then
/// centres what is left over, so `.frame(maxWidth: .infinity)` leaves a gap on
/// both sides instead of filling the row. Three buttons do fill it, and they
/// take the brand colour rather than the system's pink-red selection.
struct HourFormatPicker: View {
    @Binding var selection: ClockHourFormat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ClockHourFormat.allCases, id: \.self) { format in
                let isSelected = selection == format
                Button { selection = format } label: {
                    Text(format.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? AppColors.brand : Color.white.opacity(0.07))
                        )
                        .expandTapTarget()
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)
            }
        }
    }
}

/// Brandbook 13: a skin swatch has a 3pt radius. The book also gives the
/// selected one a glow in its own colour; that was dropped on request, because
/// a row of six saturated swatches with one haloed reads as smeared rather than
/// selected. The 2pt white border carries the selection on its own.
struct SkinSwatch: View {
    let color: Color
    let help: String
    let isSelected: Bool
    /// The fill as components, so the border can be inked against it. Every
    /// swatch passes this.
    var components: (red: Double, green: Double, blue: Double)?
    /// Only the swatch that opens the colour wheel carries a pen. Five swatches
    /// that only select and a sixth that also edits look identical until you
    /// click one, and a pen on a preset would promise an edit that is not there.
    var showsPen: Bool = false
    let action: () -> Void

    init(color: Color,
         help: String,
         isSelected: Bool,
         components: (red: Double, green: Double, blue: Double)? = nil,
         showsPen: Bool = false,
         action: @escaping () -> Void) {
        self.color = color
        self.help = help
        self.isSelected = isSelected
        self.components = components
        self.showsPen = showsPen
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(height: 24)
                .overlay(pen)
                // Selection is the glow, not a border. A white border vanished
                // on the Classic White swatch, and brandbook 13's glow reads on
                // every fill because it sits outside the swatch.
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        .opacity(isSelected ? 0 : 1)
                )
                .shadow(color: isSelected ? color.opacity(0.9) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .help(help)
    }

    @ViewBuilder
    private var pen: some View {
        if showsPen, let components, let glyph = PenIcon.glyph {
            // Black on a pale colour, white on a dark one. A fixed ink would
            // disappear at one end of the wheel or the other.
            Image(nsImage: glyph)
                .renderingMode(.template)
                .foregroundStyle(PenIcon.ink(on: components))
        }
    }
}

/// Brandbook 7.2: every popover app carries this in its footer.
struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .frame(width: 36, height: 20)
                .tint(AppColors.brand)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        isEnabled = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
