# ImperatorClock

A seven-segment retro clock for macOS: a desktop widget, plus a menu bar app
whose optional desktop clock blinks the colon once a second.

Unlit strokes stay visible at 10 %, the way the bars of a real LCD clock never
go fully dark. Five preset colours shared with the rest of the Imperator apps,
a free colour picker, a neon glow ported from the `.neon` rule in
imperator-deals, and a pulse that swells the glow once a second.

The digits stand upright. Most LED clock faces lean; this one does not.

## Two surfaces, one face

| | Widget | Desktop clock |
|---|---|---|
| Where | Desktop widget gallery, medium size | Floating window at desktop-icon level |
| Blinking colon | No | Yes, once per second |
| Pulsing glow | No | Yes, once per second |
| Every display | Per widget, placed by hand | One window per screen |
| Updates | Once a minute | Twice a second |
| Settings | From the menu bar app | From the menu bar app |

A WidgetKit widget is a still frame that the system renders in advance and swaps
on a schedule, and its reload budget is measured in dozens of refreshes a day.
One blink a second needs 86 400. So the widget shows a steady colon and the
desktop clock does the blinking.

## Install

```bash
make install
```

Builds release into `build/ImperatorClock.app`, codesigns the widget extension
and the app, installs to `/Applications`, and launches. Then add the widget:
right-click the desktop, choose Edit Widgets, and search for ImperatorClock.

Colour, neon glow and hour format live in the menu bar popover and apply to both
surfaces. Changing them asks WidgetKit for a fresh timeline, so the widget
catches up immediately.

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

Colour, glow, pulse and hour format go to a JSON file inside the widget
extension's own sandbox container:

```
~/Library/Containers/com.goranimperator.ImperatorClock.ClockWidget/Data/Library/Application Support/ImperatorClock/settings.json
```

An extension may always read its own container, and the app is not sandboxed, so
it writes there by absolute path. An App Group was the obvious choice and does
not work here: `containermanagerd` refuses a group whose identifier is not
prefixed with the signing team ID, and a self-signed build has no team. Worse,
the refusal is fatal, so the widget died at sandbox init and rendered nothing.

The desktop window's own settings — size, dark plate, locked position — stay in
the app's normal defaults, since the widget has no use for them.

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
xattr -dr com.apple.quarantine "/Applications/ImperatorClock.app"
```

## Licence

MIT.
