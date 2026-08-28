# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Build & Run

The `Makefile` is the only build path. Do not add a second one.

```bash
make install
```

Builds release into `build/Imperator WidgetClock.app`, signs the widget
extension and then the app, installs to `/Applications`, and launches.
`make install` kills any running instance first.

The bundle is named after the app, "Imperator WidgetClock", the same way the
other Imperator apps are. The SwiftPM product, the executable and the bundle
identifier all stay `ImperatorClock`: the identifier keys the widget's sandbox
container, which is where the shared settings file lives.

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
   Xcode. The metadata is plain JSON and was hand-written once
   (`git show a0ee5d4`): `linkd` accepted it, logged
   `✓ Completed indexing transaction`, and the widget's context menu gained
   `Edit "ImperatorClock"`. The sheet still rendered without controls, and the
   log carries `Unable to get teamId from com.goranimperator.ImperatorClock`,
   which a self-signed certificate cannot supply. One `StaticConfiguration` per
   colour was tried next and worked, but six near-identical gallery cards for a
   choice the menu bar app already owns is worse than one card. So the bundle
   publishes a single widget that reads the shared settings file, and the app is
   the only place settings live. Do not reintroduce an AppIntent-configured
   widget unless full Xcode is available and the Edit sheet is verified to
   render its controls.

   A widget's `kind` is how WidgetKit identifies a placed widget. Renaming one
   empties its slot on the desktop and the user has to place it again.

## Architecture

Four targets:

- **`ClockCore`**: the whole face. `SegmentGeometry` builds the seven-segment
  outlines, `ClockFace` turns a time into lit and unlit paths, `ClockStyle`
  carries the colour and the neon glow, `SharedStore` is the app/widget contract.
- **`ImperatorClock`**: menu bar app (`LSUIElement`, `.accessory`). A status
  item and a settings popover, nothing else. It draws nothing on the desktop;
  the widget is the clock.
- **`ClockWidget`**: the WidgetKit extension. One widget, medium family only,
  one timeline entry per minute, 90 entries per request. Everything it draws
  comes from the shared settings file.
- **`ClockPreview`**: headless renderer. Produces the review PNGs, the app icon,
  and the pixel measurement behind gate G3. Never shipped.

### The face

`ClockGhostShape` draws every segment of every digit plus both colon dots.
`ClockLitShape` draws only the ones that are on. The ghost sits underneath at
`ClockStyle.dimOpacity`, which is 0.05: that is the "unlit strokes still
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

### Why nothing animates

Measured, not assumed: with half-second timeline entries, ten window captures
0.22 s apart were byte-identical. WidgetKit collapses sub-minute entries on
macOS 26, and the reload budget is dozens of refreshes a day against the 86 400
that one blink a second would need. So the colon is always lit, and there is no
pulse and no blink anywhere in the code. A desktop window that did animate was
built and then removed on request: the clock is a widget and nothing else.

Do not reintroduce either as a setting. Gate G2 fails on the words `pulse` and
`colonLit` in `ClockStyle`, `SharedStore` and `SettingsView` for that reason.

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
One of them needs the installed bundle and a placed widget:

```bash
node scripts/check-widget-live.mjs
```

It refuses to accept registration as proof: it reads the heartbeat the widget
writes from `getTimeline` and checks chronod's own verdict on the descriptor
query.

`--widget-status` on the app binary prints what WidgetKit has installed and
forces a timeline reload.

## Release

Follow the `imperator-release` skill. Audit first, tag last, never without
Goran's explicit word in that message. `release` bumps **both** `Info.plist`
files; the appex version has to move with the app.

## The settings popover

Built to the Imperator apps brandbook (`~/Code/imperator/imperator-apps-brandbook`):
header, divider, scrolling content, divider, footer; 340pt wide; forced dark;
every toggle a brand-red `.switch` at 0.55 scale in a 36x20 frame. Three details
had to deviate or be built by hand:

1. **The popover is `.applicationDefined`, not `.transient`.** NSColorPanel is a
   window of its own, and a transient popover closes the moment the panel takes
   key, which drops every colour picked. A global mouse monitor restores the
   click-outside dismissal, and it stands down while the colour panel is up.
2. **The colour picker is `NSColorPanel` driven directly**, not SwiftUI's
   `ColorPicker`. Its colour well draws a pill that does not match the swatch
   row, and inside an `.accessory` app's popover clicking it focuses the well
   without bringing the panel up. `ColorPanelController` sets the target, calls
   `NSApp.activate` and orders the panel front itself.
3. **`HourFormatPicker` replaces `.pickerStyle(.segmented)`.** The system control
   sizes itself to its widest label and centres the remainder, so it will not
   fill the row.

`AppleAccentColor` is pinned to 0 in `applicationWillFinishLaunching`, and
`NSColorPanel.shared.isRestorable` is switched off in the same place: window
restoration otherwise puts a colour panel back on screen the moment the first
colour well exists.

## Conventions

English only in filenames, comments and file content. No em dashes or en dashes
anywhere.
