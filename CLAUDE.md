# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Build & Run

The `Makefile` is the only build path. Do not add a second one.

```bash
make install
```

Builds release into `build/ImperatorClock.app`, signs the widget extension and
then the app, installs to `/Applications`, and launches. `make install` kills any
running instance first.

```bash
make run
make preview
make icon
make gates
swift build
```

## No Xcode on this machine

Only the Command Line Tools are installed, so `xcodebuild` does not exist and
there is no `.xcodeproj`. Everything is SwiftPM plus Makefile bundle assembly,
the same shape as the other Imperator apps. Two consequences that shaped the
design:

1. **The widget appex is assembled by hand.** `make build` copies the
   `ClockWidget` executable into `Contents/PlugIns/ClockWidget.appex`, drops
   `Resources/WidgetInfo.plist` beside it, signs the appex with the sandbox
   entitlement, then signs the app around it. Inside out, always.
2. **No App Intents metadata.** `appintentsmetadataprocessor` ships only with
   Xcode. Without it there is no `Metadata.appintents`, and a
   `WidgetConfigurationIntent` would give the widget an empty Edit sheet. So the
   widget is a `StaticConfiguration` that reads its look from the App Group
   settings file. Do not reintroduce an AppIntent-configured widget unless full
   Xcode is available and verified.

## Architecture

Four targets:

- **`ClockCore`** — the whole face. `SegmentGeometry` builds the seven-segment
  outlines, `ClockFace` turns a time into lit and unlit paths, `ClockStyle`
  carries the colour and the neon glow, `SharedStore` is the app/widget contract.
- **`ImperatorClock`** — menu bar app (`LSUIElement`, `.accessory`). Status item
  with a settings popover, plus `DesktopClockWindow`, a borderless `NSPanel` at
  desktop-icon level whose `TimelineView(.periodic(by: 0.5))` blinks the colon.
- **`ClockWidget`** — the WidgetKit extension. Medium family only, one timeline
  entry per minute, 90 entries per request.
- **`ClockPreview`** — headless renderer. Produces the review PNGs, the app icon,
  and the pixel measurements behind gates G3 and G7. Never shipped.

### The face

`ClockGhostShape` draws every segment of every digit plus both colon dots.
`ClockLitShape` draws only the ones that are on. The ghost sits underneath at
`ClockStyle.dimOpacity`, which is 0.25 — that is the "unlit strokes still
visible" requirement, and gate G3 measures it in the rendered pixels rather than
trusting the constant.

All geometry is axis-aligned. The digits are upright by design, so no shear,
skew or rotation may enter `ClockCore`; gate G4 enforces it.

Neon mode is the `.neon` rule from imperator-deals `src/styles.css`: a near-white
`#f7fff9` core with three stacked coloured glows. The widest CSS layer floods a
seven-segment glyph, which is far denser than text, so `ClockStyle.glowLayers`
dials its opacity back the way `sigilPulseRed` does.

Colours match `Skin` in imperator-retropong. `litColor` pushes brightness to full
in HSB and leaves hue and saturation alone; lifting towards white instead turned
Imperator Red into pink.

### Why the widget cannot blink

Measured, not assumed: with half-second timeline entries, ten window captures
0.22 s apart were byte-identical. WidgetKit collapses sub-minute entries on
macOS 26, so the widget shows a steady colon and one entry per minute, and the
desktop window does the blinking and the pulsing. Do not try to "fix" this with
second-resolution entries; it only burns reload budget.

## Two traps that cost a whole afternoon

Both made the widget register with `pluginkit` and then render nothing, which
looks identical to a widget that was never installed.

1. **The entry point.** Every shipping macOS widget binary references
   `_NSExtensionMain`; a SwiftPM executable does not, so WidgetKit's `@main`
   falls into ExtensionFoundation, fails to recognise the extension type and
   returns. The process then exits before answering `getAllDescriptors`.
   `Package.swift` links `ClockWidget` with `-e _NSExtensionMain` for this
   reason. Do not remove it. Verify with
   `nm -u .build/release/ClockWidget | grep NSExtensionMain`.
2. **The App Group entitlement.** `containermanagerd` rejects a group whose
   identifier lacks the signing team ID prefix, and the rejection kills the
   extension at sandbox init: `exited due to exit(0), ran for 44ms`. The
   settings file lives in the extension's own container instead.

When the widget looks dead, read the real logs. `log` is a zsh builtin that
shadows the tool, so always call `/usr/bin/log`:

```bash
/usr/bin/log show --last 5m --info --debug --predicate 'process == "chronod"' --style compact
```

`getAllDescriptors result.` means the extension answered. `error result` means it
died first.

## Gates

`GATES.md` holds the acceptance ledger. `make gates` runs every runnable check.
Two of them need the installed bundle and a placed widget:

```bash
node scripts/check-widget-live.mjs
node scripts/check-desktop-blink.mjs
```

The first refuses to accept registration as proof: it reads the heartbeat the
widget writes from `getTimeline` and checks chronod's own verdict on the
descriptor query. The second captures the desktop clock **by window id**, since
the clock sits below every other window and a screen grab would photograph
whatever is on top of it.

`--widget-status` on the app binary prints what WidgetKit has installed and
forces a timeline reload.

## Release

Follow the `imperator-release` skill. Audit first, tag last, never without
Goran's explicit word in that message. `release` bumps **both** `Info.plist`
files; the appex version has to move with the app.

## Conventions

English only in filenames, comments and file content. No em dashes or en dashes
anywhere.
