# GATES — ImperatorClock

CONTRACT: A macOS WidgetKit medium widget showing a seven-segment HH:MM clock,
five preset colours plus a free colour picker, a neon toggle and a pulse toggle,
unlit segments visible at 10 %, upright digits with even spacing, plus a menu bar
app whose desktop clock blinks the colon once a second, pulses the glow, and can
put one clock on every display.

OWNS: Package.swift Makefile Sources/** Resources/** scripts/** README.md CLAUDE.md

Run every runnable gate with `make gates`.

## G1 Release build is clean
- [x] The whole package compiles in release with no errors.
      CHECK: swift build -c release 2>&1 | grep -c "error:" | grep -qx 0 && echo G1_BUILD_OK
      EXPECT: G1_BUILD_OK

## G2 Colours, neon, pulse and displays exist end to end
- [x] Presets, custom hex, both toggles, the display switch, and the widget's
      read path all line up.
      CHECK: node scripts/check-config.mjs
      EXPECT: G2_CONFIG_OK

## G2B The settings file round-trips
- [x] The installed app writes and reads the file the widget reads.
      CHECK: "/Applications/ImperatorClock.app/Contents/MacOS/ImperatorClock" --group-check
      EXPECT: G2B_STORE_OK
      EVIDENCE: store is the widget extension's own container. An App Group was
      tried first and had to go: `containermanagerd` logs
      `requesting [group.com.goranimperator.ImperatorClock]: REJECTED. Group
      containers identifiers should be prefixed by requestor's team ID`, and the
      rejection killed the extension at sandbox init.

## G3 Unlit segments render at 10 %
- [x] Measured luminance of an unlit segment is 0.10 of a lit one, +/- 0.02.
      CHECK: ./.build/release/ClockPreview --verify
      EXPECT: G3_DIM_OK
      EVIDENCE: `lit=255.0 unlit=25.0 ratio=0.0980`

## G4 Digits are upright, not italic
- [x] No shear, skew, oblique or rotation reaches the glyph geometry.
      CHECK: node scripts/check-upright.mjs
      EXPECT: G4_UPRIGHT_OK

## G5 Bundle assembles and both signatures verify
- [x] The app bundle contains the widget appex, and codesign verifies both.
      CHECK: make build >/dev/null && codesign --verify --deep --strict "build/ImperatorClock.app" && codesign --verify --strict "build/ImperatorClock.app/Contents/PlugIns/ClockWidget.appex" && echo G5_SIGN_OK
      EXPECT: G5_SIGN_OK

## G6 The widget extension is alive, not merely registered
- [x] It answers WidgetKit's descriptor query and its timeline provider runs and
      reads the settings file. Registration alone proves nothing: the extension
      was registered for hours while exiting after 44 ms.
      CHECK: node scripts/check-widget-live.mjs
      EXPECT: G6_WIDGET_LIVE_OK
      EVIDENCE: `heartbeat ... skin=purple neon=true`, and chronod logging
      `getAllDescriptors result.` rather than `error result`.

## G7 The desktop clock animates
- [x] Eight window captures a quarter second apart are not all identical, which
      is the colon blink and the glow pulse. Captured by window id, since the
      clock sits below every other window.
      CHECK: node scripts/check-desktop-blink.mjs
      EXPECT: G7_DESKTOP_BLINK_OK
      EVIDENCE: `frames=... unique=7`

## G8 Visual review against the references
- [x] MANUAL: rendered faces match the reference image's proportions (1:2.4),
      segment weight (0.22 of digit width), even gaps, upright digits, and a
      lavender core inside a coloured halo rather than a white core.

## G9 The widget cannot blink its colon
- [x] ABANDON: G9 measured half-second timeline entries. Ten window captures
      0.22 s apart were byte-identical, so WidgetKit collapses sub-minute
      entries on macOS 26. The widget keeps a steady colon by design and the
      desktop clock does the blinking, which is what G7 measures instead.
