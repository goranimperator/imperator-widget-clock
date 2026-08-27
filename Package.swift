// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ImperatorClock",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Shared seven-segment renderer, skins and neon styling. Used by the app,
        // the widget extension and the preview/verification tool.
        .target(
            name: "ClockCore",
            path: "Sources/ClockCore"
        ),
        // Menu bar app: settings popover + optional desktop clock window.
        .executableTarget(
            name: "ImperatorClock",
            dependencies: ["ClockCore"],
            path: "Sources/ImperatorClock"
        ),
        // WidgetKit extension binary. The Makefile wraps it in ClockWidget.appex.
        .executableTarget(
            name: "ClockWidget",
            dependencies: ["ClockCore"],
            path: "Sources/ClockWidget",
            // Every shipping macOS widget extension enters through Foundation's
            // extension bootstrap: Apple's own WorldClock, Notes and Weather
            // widgets all carry references to _NSExtensionMain. A SwiftPM build
            // does not, so WidgetKit's main falls into ExtensionFoundation,
            // fails to recognise the extension type and returns, and the process
            // exits before it can answer getAllDescriptors.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"
            ])]
        ),
        // Headless renderer used for visual review and for the numeric gates.
        // Never shipped inside the app bundle.
        .executableTarget(
            name: "ClockPreview",
            dependencies: ["ClockCore"],
            path: "Sources/ClockPreview"
        )
    ]
)
