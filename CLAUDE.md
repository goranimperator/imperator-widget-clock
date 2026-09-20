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
container, and a widget's `kind` is resolved against it. The shared settings
file used to live in that container and does not any more, see trap 4.

```bash
make run
make preview
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
- **`ClockPreview`**: headless renderer. Produces the review PNGs and the pixel
  measurements behind gates G3 and G10. Never shipped. It used to render the app
  icon too, with `--icon` defaulting to `Resources/AppIcon.png`: `make icon` was
  removed before 1.0.0 so nothing would overwrite the supplied sigil, but the
  command itself survived and still would have. Both are gone now.

### The face

`ClockGhostShape` draws every segment of every digit plus both colon dots.
`ClockLitShape` draws only the ones that are on. The ghost sits underneath at
`ClockStyle.dimOpacity`, which is 0.25, and gate G3 measures it in the rendered
pixels rather than trusting the constant.

It was 0.05 until macOS 27, and 0.05 is the right number for an undimmed face.
It is the wrong number for the face people actually look at. `Desktop & Dock` >
`Widgets` > `Dim widgets on desktop` composites the widget from outside at
about 0.75 and in greyscale, and it is not linear: a ghost sourced at 0.30
disappeared outright, 0.37 came back at 0.188 and 0.45 at 0.251. At 0.05 the
ghosts were gone entirely whenever any window covered the desktop, which is
most of the time.

The widget is never told. A desktop widget always renders in `.fullColor`;
`.vibrant` is for Lock Screen and StandBy. This was measured, not assumed: a
probe that drew the whole face red whenever the mode was not `.fullColor`
produced zero red pixels with Dim on. Do not add a branch on
`widgetRenderingMode` for the desktop; it will never run.

The setting itself is readable, and this file claimed otherwise for a version.
`DesktopSettings.appex` writes the three-valued `Dim widgets on desktop` to
`com.apple.widgets` under `widgetAppearance`, and an unsandboxed process can
read it. The widget cannot, since that domain is outside its sandbox, so the
menu bar app polls the key and publishes the answer as `widgetsDimmed` in the
shared file; `ClockPreferences.effectiveStyle` turns that into a white face and
`WidgetDimming` holds the mapping. See `--dim-check` and G13.

The raw values were measured rather than read off the pane's App Intents
metadata, because the two disagree: the metadata orders the cases Automatically,
Never, Always, while the key held 0 in the state whose widgets render greyscale
and 1 for Never. Apple's own Weather widget was captured to settle it, and at 0
there is no colour in it at all. So 1 is the only value proven to leave the face
alone, an absent key is treated the same way, and everything else means dimmed.

0.25 was settled by eye against the real dimmed desktop. The popover preview is
never dimmed and shows the ghosts at any value, so it cannot be used to judge
this.

A dimmed face draws white whatever colour is picked, because greyscale maps a
colour to its luminance and Imperator Blue's is 0.07: a blue face under Dim was
a black rectangle with faint ghosts, which is what it looked like on the desktop
before this existed. The skin is not overwritten, only what is drawn, so
turning the dimming off brings the colour straight back.

The ghost is a neutral grey, not the chosen colour dimmed down. A real LCD's
dark bars do not take the tint of the lit ones, and a magenta face with magenta
ghosts read as a smudge. `offColor` therefore ignores the skin entirely.

All geometry is axis-aligned. The digits are upright by design, so no shear,
skew or rotation may enter `ClockCore`; gate G4 enforces it.

Neon mode is the glow from the `.neon` rule in imperator-deals
`src/styles.css`, and only the glow. The CSS also swaps the text colour for a
near-white `#f7fff9`, and that was ported once as a core at a third of the
skin's saturation. On a seven-segment glyph it washes the colour out: switching
the glow on made the digits paler rather than brighter, and a saturated pink
came back almost white. The digits keep their colour now and gain a halo, so
`litColor` is `flatLitColor` whether or not neon is on. G2 fails on the word
`neonCore` for that reason.

The widest CSS layer floods a seven-segment glyph, which is far denser than
text, so `ClockStyle.glowLayers` dials its opacity back the way `sigilPulseRed`
does.

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

## Four traps that each looked like a different bug

The first two made the widget register with `pluginkit` and then render
nothing, which looks identical to a widget that was never installed. The third
put a Dock tile on a menu bar app. The fourth arrived with macOS 27 and made
every setting stop reaching the widget.

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
3. **`LSUIElement`.** It is the only thing that keeps the Dock tile away.
   `setActivationPolicy(.accessory)` was in `main()` from the first commit and
   1.0.0 still shipped a Dock icon: LaunchServices decides on the tile before
   the process runs, so a policy change from `main()` arrives too late to take
   it back. Both are needed. The key hides the tile, the call keeps the app out
   of the switcher and makes the popover behave as an accessory window. Ask
   LaunchServices rather than reading the plist, since the plist was right in
   the docs and missing in the file for the whole 1.0.0 cycle:

   ```bash
   lsappinfo info -only ApplicationType "$(lsappinfo find LSDisplayName='Imperator WidgetClock' | head -1)"
   ```

   `UIElement` is right. `Foreground` means the tile is back.
4. **The shared file cannot live in the widget's container.** It did until
   macOS 27, which closed outside access to another app's container. After the
   upgrade the app could neither read nor write it: `NSCocoaErrorDomain 257` on
   read, `513` on write. Nothing the user changed reached the widget, and
   because `SharedStore.save` returns a Bool that nothing checks, the popover
   went on showing a colour it held only in memory. The face stayed white with
   no glow, which is what the defaults are.

   The file lives in the real home now, at
   `~/Library/Application Support/ImperatorClock`, and the sandboxed widget
   reaches it through
   `com.apple.security.temporary-exception.files.home-relative-path.read-write`.
   A temporary exception is a plain entitlement and is not checked against a
   team ID, which is what made the App Group impossible. Keep the path in the
   entitlement in step with `SharedStore.homeRelativePath`.

   `NSHomeDirectory()` is redirected to the container inside a sandbox, so the
   app and the widget would compute different paths from it. `SharedStore`
   reads the passwd entry with `getpwuid` instead, which is not redirected.

When diagnosing this, do not run a check flag from a shell and believe the
answer. TCC attributes a file request to the *responsible* process, and for a
binary started from a terminal that is the terminal, not the app. Ask the app
itself:

```bash
open -n -a "/Applications/Imperator WidgetClock.app" --args --report /tmp/store.txt
```

`--report` writes the settings, the heartbeat and a write probe with the real
`NSError`, rather than the Bool `SharedStore.save` returns.

When the widget looks dead, read the real logs. `log` is a zsh builtin that
shadows the tool, so always call `/usr/bin/log`:

```bash
/usr/bin/log show --last 5m --info --debug --predicate 'process == "chronod"' --style compact
```

`getAllDescriptors result.` means the extension answered. `error result` means it
died first.

Two more things the logs will show after a reinstall, both self-inflicted.
`bundleStubNotSupported ... "Bundle version did not match; LaunchServices DB may
need to be rebuilt"` is chronod holding a cached stub for the previous build;
it clears itself, and `killall chronod` clears it at once. And chronod keeps the
*running* extension process alive across a reinstall, so a freshly installed
appex may not be the one answering. `killall chronod` is the only reliable way
to be sure a measurement came from the build just installed. `make install`
does it for that reason.

Left alone across several reinstalls in a row, this shows up as a widget that
draws nothing: a black rounded rectangle with no digits and no ghosts, which
looks exactly like a face rendered in a colour that vanishes under
`Dim widgets on desktop`. The two are told apart by capturing the widget's own
window rather than the screen, since the window is there whether or not
anything covers the desktop:

```bash
screencapture -x -o -l "$(...window id of "Imperator WidgetClock"...)" /tmp/widget.png
```

The window is owned by Notification Centre, is named after the app and is
360x180 for a medium widget. `CGWindowListCopyWindowInfo` finds it; the app
itself is not the owner, so `pgrep` and the heartbeat say nothing about what is
on screen. G6 passes in this state: the extension is alive and writing its
heartbeat, and only the picture chronod is showing is stale.

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

## The settings panel

Built to the Imperator apps brandbook (`~/Code/imperator/imperator-apps-brandbook`):
header, divider, scrolling content, divider, footer; 340pt wide; forced dark;
every toggle a brand-red `.switch` at 0.55 scale in a 36x20 frame. Three details
had to deviate or be built by hand:

1. **The panel is drawn, not an `NSPopover`.** `MenuBarPanel` is a borderless
   `NSPanel` with an `NSVisualEffectView` on the `.popover` material, rounded at
   17.5 pt with no arrow and no animation, which is what macOS 27 puts under a
   menu bar item. Every Imperator menu bar app draws the same one. It also owns
   the click-outside dismissal, and `shouldCloseOnOutsideClick` is how this app
   keeps it from closing on the colour wheel: `NSColorPanel` is a window of its
   own, so every click in it is a click outside the panel, and closing there left
   the wheel pointing at a dead binding and dropped the colour.
2. **The colour picker is `NSColorPanel` driven directly**, not SwiftUI's
   `ColorPicker`. Its colour well draws a pill that does not match the swatch
   row, and inside an `.accessory` app's popover clicking it focuses the well
   without bringing the panel up. `ColorPanelController` sets the target, calls
   `NSApp.activate` and orders the panel front itself.
3. **`HourFormatPicker` replaces `.pickerStyle(.segmented)`.** The system control
   sizes itself to its widest label and centres the remainder, so it will not
   fill the row.

The swatch row follows brandbook 13: the selected swatch glows in its own
colour and carries no border. A white border was tried instead and had to go,
because Classic White is a pure white fill and the selection became invisible
on exactly one swatch. The glow sits outside the fill, so it reads on all six.

The custom swatch carries Lucide's `pen`, because five swatches that only
select and a sixth that also edits look identical until you click one. Only
that swatch gets it: a pen on a preset promises an edit that is not there. The
pen is black or white, whichever WCAG contrast says is readable on the colour
under it, so it survives the whole wheel rather than disappearing at one end.

Both swatch fills are `flatLitColor`, not the raw value, because that is what
the face draws. A dark pick comes back near-white on the clock, and a swatch
showing the raw colour would contradict the preview directly above it.

`AppleAccentColor` is pinned to 0 in `applicationWillFinishLaunching`, and
`NSColorPanel.shared.isRestorable` is switched off in the same place: window
restoration otherwise puts a colour panel back on screen the moment the first
colour well exists.

## Corner radii: measure them, and draw the one that is ours

macOS 27 (26A428), measured off the real pixels rather than read out of a header
or a layer. Every figure is a circular fit on the bottom corner of a captured
window, and the bottom, not the top, because an `NSPopover` puts an arrow on the
top edge and it contaminates the profile.

| shape | radius | who draws it |
| --- | --- | --- |
| medium desktop widget | 30.00 pt | macOS |
| Control Centre's Wi-Fi panel, the menu bar's own | 17.50 pt | macOS |
| titled window, Notes and the About panel alike | 17.25 pt | macOS |
| `NSPopover`, binary stamped `sdk 27.0` | 26.25 pt outer, 19.75 clip | macOS |
| `NSPopover`, binary stamped `sdk 14.0` | 9.50 pt | macOS |

The two popover rows are why this app no longer uses one. macOS 27 draws two
generations of popover frame and picks between them on the binary's `sdk` stamp,
and neither generation is the panel macOS itself puts under a menu bar item: one
is half again too round, the other half too tight. `NSPopover` exposes no radius,
so matching the system meant drawing the surface, which is what `MenuBarPanel`
does. See the settings panel section below.

That stamp is also the easiest thing here to measure wrong. A probe built today
carries `sdk 27.0` and answers for a frame a binary stamped `sdk 14.0` never
gets; the same probe re-stamped with
`vtool -set-build-version macos 14.0 14.0 -replace` and re-signed measured 19.75
before and 9.50 after, with nothing else changed. Check the stamp before trusting
any popover measurement:

```bash
vtool -show-build-version "/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock"
```

This app shipped stamped `sdk 14.0` until the Makefile started stamping the real
SDK, because SwiftPM takes that field from `platforms:` rather than from the SDK
it compiled against. It was drawing macOS 14 era controls on macOS 27: the old
popover frame, and the narrow switch with a round knob instead of today's
capsule. The minimum still says macOS 14, so nothing about where the app installs
changed. See `PLATFORM_STAMP` in the Makefile and G15.

Two constants carry this. `ClockStyle.containerCornerRadius` is 30, the widget's
own shape, used by the review render: the widget has nothing around it, so it
answers to macOS and nothing else. `ClockStyle.panelCornerRadius` is 17.5, used
by the preview card in the panel, because the card sits inside the panel's corner
and the two are read against each other. `MenuBarPanel.cornerRadius` is 18.25
rather than 17.5, because an `NSVisualEffectView` blends its edge and draws about
0.75 pt tighter than the radius it is given: at 17.5 the panel measured 16.75, at
18.25 it measures 17.50, which is the Wi-Fi panel exactly.

Before this the widget's shape carried three numbers: 24 in `ClockStyle`, 20 in
the review render and 10 in the popover preview. `G14` and `--verify-corner`
measure both rendered shapes against the literals, and G2 fails if either
constant drifts, if a literal comes back in a view, or if the Makefile loses the
SDK stamp.

## The menu bar icon

`StatusItemIcon` draws the icon rather than taking `systemSymbolName: "clock"`.
That symbol is a hairline circle with two thin hands, and on a 1x display, an
external 2560x1440 panel for instance, the strokes fall between pixels and the
glyph turns to mush. The drawn icon is the clock's own face reduced to a
display outline with a lit colon, which lands on whole pixels at any scale. It
is a template image, so macOS inverts it for light and dark menu bars.

The outline is not its own shape: it is the gamepad body from
imperator-free-games, so the two apps sit side by side in the menu bar without
one looking bigger than the other. That icon is Lucide's `gamepad` at 18pt, a
24-unit viewBox holding `rect x=2 y=6 width=20 height=12 rx=2` at
`stroke-width=2`. Everything in `StatusItemIcon` is one of those units scaled
to `size`, which is why the numbers look arbitrary. The icon shipped at 23 x 16
until this was matched up, against 18 x 18 everywhere else and in brandbook
8.1.

The colon has to share the canvas's parity to be both centred and crisp. A 2pt
dot on a 23pt canvas cannot be, and `.rounded()` resolved the tie by moving it
half a point right, which is the bug that was visible in the menu bar. Nothing
in the drawing code enforces the rule now: a guard that grows the dot to fix
parity overflows the body at odd sizes, so `--icon-check` measures the finished
pixels instead. It renders the sibling's own SVG and compares, so the two icons
can only drift apart deliberately.

```bash
./.build/release/ImperatorClock --icon-check
```

## The About panel

Brandbook 10, and the numbers there are the spec rather than a suggestion:
`--about-check` builds the real panel and measures it. The footer button reads
"About" with the full "About Imperator WidgetClock" as its tooltip, because the
row already carries the login toggle inside 340pt.

It is a window of its own in an `.accessory` app, so it repeats the two fixes
`ColorPanelController` already documents. `hidesOnDeactivate` has to be forced
off, since an NSPanel defaults to hiding when its app deactivates and this app
deactivates on the first click anywhere else, which is exactly when someone is
reading an About panel. And `NSApp.activate(ignoringOtherApps:)` has to run
before the panel is ordered front, or it opens behind whatever the user was in.

One more that is invisible in the source: assigning `contentViewController`
resizes the window to the hosted view's fitting size, and a SwiftUI view that
has not laid out yet reports zero, so `setContentSize` has to re-assert the size
afterwards. Without it the panel opens 0x0 and the `contentRect` passed to the
initialiser is thrown away.

```bash
"/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" --about-check
```

An unrecognised option now exits 2 with a usage line instead of falling through
to `NSApplication.run()`. Running a new check flag against an older installed
binary used to launch a second copy of the app, with a second menu bar icon.

## Face proportions are in digit widths, and three of them are derived

Everything in `ClockLayout` is a fraction of one digit's width, so widening a
digit silently widens whatever else is expressed that way. That caught the
stroke weight and the colon dot once each: asked for wider digits, the face came
back with fatter strokes and a bigger colon too. `colonDot` is now
`thickness` rather than a number of its own, and any change to the face's width
has to hold `thickness`, `digitHeight` and `colonDot` steady in pixels unless
the change is meant to scale everything.

The face is width-constrained inside a medium widget: `faceWidth` is about five
digit widths against roughly 350 usable points. Extra spacing between digits
therefore comes out of the outer padding and the digits themselves, never for
free.

## Conventions

English only in filenames, comments and file content. No em dashes or en dashes
anywhere.
