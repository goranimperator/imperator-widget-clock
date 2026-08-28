# GATES: Imperator WidgetClock

CONTRACT: A macOS WidgetKit medium widget showing a seven-segment HH:MM clock:
one gallery card, unlit segments visible at 5 %, upright digits with even
spacing. Everything it looks like is set in a menu bar app whose popover follows
the Imperator apps brandbook: five preset colours plus a colour picker, a neon
toggle and an hour format. Nothing animates, because nothing can.

OWNS: Package.swift Makefile Sources/** Resources/** scripts/** README.md CLAUDE.md

Run every runnable gate with `make gates`.

## G1 Release build is clean
- [x] The whole package compiles in release with no errors.
      CHECK: swift build -c release 2>&1 | grep -c "error:" | grep -qx 0 && echo G1_BUILD_OK
      EXPECT: G1_BUILD_OK

## G2 Colours, neon, the brandbook and the widget line up
- [x] Presets, the colour picker, the neon toggle, the brand-red switches, the
      pinned accent, the one gallery card and the widget's read path all hold,
      and no pulse or blinking colon has crept back in.
      CHECK: node scripts/check-config.mjs
      EXPECT: G2_CONFIG_OK
      EVIDENCE: both negative checks were run against a known positive control,
      a decoy second `StaticConfiguration` and a decoy `Color.accentColor`, and
      failed on it before passing once it was removed.

## G2B The settings file round-trips
- [x] The installed app writes and reads the file the widget reads.
      CHECK: "/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" --group-check
      EXPECT: G2B_STORE_OK
      EVIDENCE: store is the widget extension's own container. An App Group was
      tried first and had to go: `containermanagerd` logs
      `requesting [group.com.goranimperator.ImperatorClock]: REJECTED. Group
      containers identifiers should be prefixed by requestor's team ID`, and the
      rejection killed the extension at sandbox init.

## G3 Unlit segments render at 5 %
- [x] Measured luminance of an unlit segment is 0.05 of a lit one, +/- 0.015.
      CHECK: ./.build/release/ClockPreview --verify
      EXPECT: G3_DIM_OK
      EVIDENCE: `lit=255.0 unlit=25.0 ratio=0.0980`

## G10 Every junction has the same channel
- [x] The gap where two segments meet is the same width at all eight junctions
      of a digit, corners and the middle bar alike.
      CHECK: ./.build/release/ClockPreview --verify-gaps
      EXPECT: G10_GAPS_OK
      EVIDENCE: `min=20.00 max=21.00 mean=20.56 spread=4.9%` on an "8" rendered
      at four times review size. The probes are the midpoints between the two
      facing tips, read back out of the outlines themselves, and the width is
      twice the distance from a probe to the nearest lit pixel. Positive
      control: with the vertical segments inset by `thickness / 2 + miter` from
      the middle instead of by `miter`, which is how the face shipped, the four
      middle junctions measure `64.00 65.00 66.50 68.00` against `20.00` to
      `21.00` at the corners, and the gate fails at `spread 111.0%`.

## G4 Digits are upright, not italic
- [x] No shear, skew, oblique or rotation reaches the glyph geometry.
      CHECK: node scripts/check-upright.mjs
      EXPECT: G4_UPRIGHT_OK

## G5 Bundle assembles and both signatures verify
- [x] The app bundle contains the widget appex, and codesign verifies both.
      CHECK: make build >/dev/null && codesign --verify --deep --strict "build/Imperator WidgetClock.app" && codesign --verify --strict "build/Imperator WidgetClock.app/Contents/PlugIns/ClockWidget.appex" && echo G5_SIGN_OK
      EXPECT: G5_SIGN_OK

## G6 The widget extension is alive, not merely registered
- [x] It answers WidgetKit's descriptor query and its timeline provider runs and
      reads the settings file. Registration alone proves nothing: the extension
      was registered for hours while exiting after 44 ms.
      CHECK: node scripts/check-widget-live.mjs
      EXPECT: G6_WIDGET_LIVE_OK
      EVIDENCE: `heartbeat ... skin=purple neon=true`, and chronod logging
      `getAllDescriptors result.` rather than `error result`.

## G8 Visual review against the references
- [x] MANUAL: rendered faces match the reference image's proportions (1:2.4),
      segment weight (0.22 of digit width), even gaps, upright digits, and a
      lavender core inside a coloured halo rather than a white core.

## G7 The desktop clock animates
- [x] ABANDON: G7 measured a desktop window that no longer exists. It was
      removed on request: the clock is a widget and nothing else. Its evidence
      while it existed was `frames=... unique=8` with the pulse on and
      `unique=2` with only the colon blinking.

## G9 The widget cannot blink its colon
- [x] ABANDON: G9 measured half-second timeline entries. Ten window captures
      0.22 s apart were byte-identical, so WidgetKit collapses sub-minute
      entries on macOS 26, and the reload budget is dozens of refreshes a day
      against the 86 400 one blink a second needs. The colon is therefore lit
      always, and the pulse and the blink are gone from the code rather than
      offered as settings that do nothing. G2 checks they stay gone.
