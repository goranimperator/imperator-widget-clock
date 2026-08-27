// Prints the desktop clock's window id, level and size, for the blink gate.
import CoreGraphics
import Foundation

guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}
let desktopIcon = Int(CGWindowLevelForKey(.desktopIconWindow))
for window in list {
    guard (window[kCGWindowOwnerName as String] as? String) == "ImperatorClock",
          let layer = window[kCGWindowLayer as String] as? Int,
          layer == desktopIcon,
          let id = window[kCGWindowNumber as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any] else { continue }
    print("id=\(id) layer=\(layer) size=\(bounds["Width"] ?? 0)x\(bounds["Height"] ?? 0)")
    exit(0)
}
print("no desktop clock window")
exit(1)
