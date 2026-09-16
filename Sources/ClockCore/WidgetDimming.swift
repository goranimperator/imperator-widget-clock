import Foundation

/// Whether macOS is dimming desktop widgets, which it never tells a widget.
///
/// `Dim widgets on desktop` in System Settings, Desktop & Dock, Widgets is
/// three-valued, and `DesktopSettings.appex` writes the choice to
/// `com.apple.widgets` under `widgetAppearance`. The pane's own App Intents
/// metadata names the cases Automatically, Never and Always.
///
/// The widget itself cannot read this. It is sandboxed, another app's
/// preference domain is outside the sandbox, and `WidgetRenderingMode` stays
/// `.fullColor` on the desktop whatever the setting says: a probe that painted
/// the face red whenever the mode was not `.fullColor` produced zero red pixels
/// with the dimming on. The unsandboxed menu bar app reads the key instead and
/// writes the answer into the shared file, which is how the widget finds out.
///
/// The raw values were measured rather than taken from the metadata's case
/// order, because the two disagree. Toggling the setting while a long-lived
/// process read the key gave 0 for the state whose widgets render in greyscale
/// and 1 for Never, confirmed by capturing Apple's own Weather widget: at 0 it
/// has no colour in it at all. So 1 is the only value proven to mean the face
/// is left alone, and everything else is treated as dimmed. The metadata's
/// third case sits at 2 and is unverified; dimming is the safe reading, since
/// the worst it costs is a white face on a screen that was going to be
/// greyscale anyway.
public enum WidgetDimming: Sendable {
    public static let domain = "com.apple.widgets"
    public static let key = "widgetAppearance"

    /// Measured: the value present while Apple's widgets render greyscale.
    public static let dimmedRawValue = 0
    /// Measured: the value written by Never.
    public static let neverRawValue = 1

    /// `nil` means the key is absent, which is a machine that never touched the
    /// setting. That is not a licence to override the colour the user picked.
    public static func isDimmed(rawValue: Int?) -> Bool {
        guard let rawValue else { return false }
        return rawValue != neverRawValue
    }
}
