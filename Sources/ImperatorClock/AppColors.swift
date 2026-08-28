import AppKit
import SwiftUI

/// Imperator brand tokens. Section 2.6 of the Imperator apps brandbook: every
/// app defines this enum, and `brand` is the one colour that may never be
/// substituted by `Color.accentColor`, which falls back to macOS blue.
enum AppColors {
    static let brand = Color(red: 0xa0 / 255.0, green: 0x18 / 255.0, blue: 0x18 / 255.0)
    static let popoverBackground = Color.black.opacity(0.15)
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }

    func expandTapTarget() -> some View {
        contentShape(Rectangle())
    }
}

/// Brandbook 7.1: the one interactive button style. Dim until hovered.
struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) { label() }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .opacity(isHovered ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
            .cursor(.pointingHand)
    }
}

/// Brandbook 7.2: a switch, tinted brand red, at 0.55 scale in a 36x20 frame.
/// The label sits on the left and the switch on the right, so every toggle in
/// the popover lines up on the same two columns whatever its nesting.
struct BrandToggle: View {
    let title: String
    @Binding var isOn: Bool
    var help: String?

    init(_ title: String, isOn: Binding<Bool>, help: String? = nil) {
        self.title = title
        self._isOn = isOn
        self.help = help
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.55)
                .frame(width: 36, height: 20)
                .tint(AppColors.brand)
                .labelsHidden()
        }
        .expandTapTarget()
        .help(help ?? "")
    }
}

