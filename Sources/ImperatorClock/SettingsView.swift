import AppKit
import ClockCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: ClockSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview

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
                        SkinSwatch(color: customColor,
                                   help: "Custom colour",
                                   isSelected: settings.skin == .custom) {
                            settings.skin = .custom
                        }
                    }
                    HStack(spacing: 8) {
                        ColorPicker("Custom", selection: Binding(
                            get: { customColor },
                            set: { newValue in
                                settings.customHex = SettingsView.hex(from: newValue)
                                settings.skin = .custom
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        Text("Pick any colour")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Neon glow", isOn: $settings.neon)
                    .toggleStyle(.checkbox)
                Toggle("Pulse the glow once a second", isOn: $settings.pulse)
                    .toggleStyle(.checkbox)
                    .disabled(!settings.neon)
                    .padding(.leading, 18)
            }

            Picker("Hours", selection: $settings.hourFormat) {
                ForEach(ClockHourFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider().overlay(Color.white.opacity(0.12))

            section("Desktop clock") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Show on the desktop", isOn: $settings.showDesktopClock)
                        .toggleStyle(.checkbox)
                    Text("Only the desktop clock blinks the colon every second. A widget is a still frame, redrawn once a minute at most.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text("Size").font(.system(size: 11)).foregroundStyle(.secondary)
                        Slider(value: $settings.faceWidth, in: 240...1000)
                        Text("\(Int(settings.faceWidth))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .disabled(!settings.showDesktopClock)

                    Toggle("Dark plate behind the face", isOn: $settings.showPlate)
                        .toggleStyle(.checkbox)
                        .disabled(!settings.showDesktopClock)
                    Toggle("Lock in place (clicks pass through)", isOn: $settings.locked)
                        .toggleStyle(.checkbox)
                        .disabled(!settings.showDesktopClock)
                    Toggle("One clock on every display", isOn: $settings.allScreens)
                        .toggleStyle(.checkbox)
                        .disabled(!settings.showDesktopClock)
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            section("Widget") {
                Text("Right-click the desktop, choose Edit Widgets, then search for Imperator Clock. Colour, glow and hour format are set on the widget itself: right-click it and choose Edit Widget.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Color.white.opacity(0.12))

            HStack {
                LaunchAtLoginToggle()
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 330)
        .background(Color(white: 0.10))
    }

    private var customColor: Color {
        let c = ClockSkin.components(fromHex: settings.customHex)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    /// SwiftUI's ColorPicker hands back a Color; go via NSColor to read channels.
    static func hex(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return ClockSkin.hex(fromComponents: (Double(ns.redComponent),
                                              Double(ns.greenComponent),
                                              Double(ns.blueComponent)))
    }

    private var preview: some View {
        ClockFaceView(
            reading: ClockReading(digits: [0, 6, 5, 3]),
            colonLit: true,
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
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct SkinSwatch: View {
    let color: Color
    let help: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0.12),
                                      lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? color.opacity(0.9) : .clear, radius: 5)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Open at login", isOn: $enabled)
            .toggleStyle(.checkbox)
            .onChange(of: enabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}
