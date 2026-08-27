import ClockCore
import Foundation
import WidgetKit

/// `ImperatorClock --widget-status` asks WidgetKit what it actually has
/// installed, and forces a timeline reload. It is the only way to see the
/// widget's own state from outside, since the extension cannot report anything.
enum WidgetStatus {
    static func run() -> Int32 {
        let group = DispatchGroup()
        group.enter()

        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let widgets):
                print("installed_widgets=\(widgets.count)")
                for widget in widgets {
                    print("  kind=\(widget.kind) family=\(widget.family)")
                }
            case .failure(let error):
                print("getCurrentConfigurations failed: \(error)")
            }
            group.leave()
        }

        _ = group.wait(timeout: .now() + 8)
        WidgetCenter.shared.reloadAllTimelines()
        print("reload_requested")
        Thread.sleep(forTimeInterval: 3)
        return 0
    }
}
