import AppKit
import ClockCore
import ServiceManagement
import SwiftUI

/// The menu bar popover, laid out the way the Imperator apps brandbook asks a
/// popover app to be laid out: header, divider, scrolling content, divider,
/// footer, 340pt wide, forced dark, brand red instead of the system accent.
struct SettingsView: View {
    @ObservedObject var settings: ClockSettings

    static let width: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 16) {
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
        HStack(spacing: 8) {
            Text("Imperator WidgetClock")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            LaunchAtLoginToggle()
            Spacer()
            HoverButton {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit").font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Sections

    private var colourSection: some View {
        section("Colour") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(ClockSkin.presets, id: \.self) { skin in
                        SkinSwatch(color: ClockStyle(skin: skin, neon: false).flatLitColor,
                                   help: skin.displayName,
                                   isSelected: settings.skin == skin) {
                            settings.skin = skin
                        }
                    }
                    // The sixth swatch is the colour well itself: clicking it
                    // opens the system colour picker and selects the custom
                    // skin, so there is one control rather than a swatch that
                    // has to be armed before a separate picker means anything.
                    SkinSwatch(color: customColor,
                               help: "Pick any colour",
                               isSelected: settings.skin == .custom) {
                        openColorPanel()
                    }
                }
                Text("The last swatch opens the colour wheel. Pick any colour you like.")
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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

/// Brandbook 13: a skin swatch has a 3pt radius and glows in its own colour
/// while selected.
struct SkinSwatch: View {
    let color: Color
    let help: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0.12),
                                      lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? color.opacity(0.9) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .help(help)
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
