# Imperator WidgetClock

A seven-segment retro clock for macOS: a desktop widget, plus a menu bar app
that holds its settings.

Unlit strokes stay visible at 5 %, the way the bars of a real LCD clock never
go fully dark. Five preset colours shared with the rest of the Imperator apps,
a free colour picker, a neon glow ported from the `.neon` rule in
imperator-deals.

The digits stand upright. Most LED clock faces lean; this one does not.

## Why the colon does not blink

A WidgetKit widget is a still frame that the system renders in advance and swaps
on a schedule, and its reload budget is measured in dozens of refreshes a day.
One blink a second needs 86 400. Half-second timeline entries were tried and
measured: ten window captures 0.22 s apart were byte-identical, because macOS
collapses anything finer than a minute. So the colon stays lit.

## Install

```bash
make install
```

Builds release into `build/Imperator WidgetClock.app`, codesigns the widget extension
and the app, installs to `/Applications`, and launches. Then add the widget:
right-click the desktop, choose Edit Widgets, and search for Imperator WidgetClock.

The gallery carries one card. Colour, glow and hour format all live in
the menu bar popover and apply to both surfaces; changing one asks WidgetKit for
a fresh timeline, so the widget catches up immediately.

macOS renders desktop widgets in greyscale unless System Settings, Desktop &
Dock, Widgets, Widget style is set to Full colour. A widget cannot override
that: `WidgetRenderingMode` is handed to it, not chosen by it.

```bash
make run
make preview
make icon
make gates
make clean
```

`make preview` renders the face to `build/preview` and opens it, `make icon`
regenerates `Resources/AppIcon.icns` from the clock renderer itself, and
`make gates` runs every acceptance check in `GATES.md`.

## Settings and where they live

Colour, glow, hour format and the custom colour's hex go to a JSON file
inside the widget extension's own sandbox container:

```
~/Library/Containers/com.goranimperator.ImperatorClock.ClockWidget/Data/Library/Application Support/ImperatorClock/settings.json
```

An extension may always read its own container, and the app is not sandboxed, so
it writes there by absolute path. An App Group was the obvious choice and does
not work here: `containermanagerd` refuses a group whose identifier is not
prefixed with the signing team ID, and a self-signed build has no team. Worse,
the refusal is fatal, so the widget died at sandbox init and rendered nothing.

That file is the whole of the app's state.

## Release

Follow the `imperator-release` skill. Audit first, tag last, never without
Goran's explicit word in that message.

```bash
make dist VERSION=x.y.z
make release VERSION=x.y.z
```

`dist` is safe: it touches nothing in git or on the remote. `release` bumps both
`Info.plist` files, commits, tags, pushes and publishes a GitHub release with
the zip attached.

Signing uses the self-signed `Imperator Dev` identity, not ad-hoc. The app
registers a login item via `SMAppService`, and that registration is keyed to the
bundle's designated requirement. WidgetKit also caches the extension by its
signing identity, so an ad-hoc cdhash that changes on every build would drop the
widget out of the gallery after an update.

Not notarized, so Gatekeeper blocks the first launch of a downloaded build:
right-click the app and choose Open, or

```bash
xattr -dr com.apple.quarantine "/Applications/Imperator WidgetClock.app"
```

## Licence

MIT.
