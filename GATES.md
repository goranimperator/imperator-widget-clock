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

## G2C The app takes no Dock tile
- [x] The menu bar app runs as a UIElement, so the Dock shows nothing for it.
      CHECK: lsappinfo info -only ApplicationType "$(lsappinfo find LSDisplayName='Imperator WidgetClock' | head -1)"
      EXPECT: "ApplicationType"="UIElement"
      EVIDENCE: it read `"ApplicationType"="Foreground"` through 1.0.0, and the
      Dock carried a tile with a running dot. `setActivationPolicy(.accessory)`
      was already there and did not prevent it: LaunchServices creates the tile
      before `main()` runs. `LSUIElement` in Info.plist is what fixes it, and
      G2 now fails if the key goes missing, verified against the plist with the
      key deleted.

## G2B The settings file round-trips
- [x] The installed app writes and reads the file the widget reads.
      CHECK: "/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" --group-check
      EXPECT: G2B_STORE_OK
      EVIDENCE: store is `~/Library/Application Support/ImperatorClock`, and the
      sandboxed widget reaches it through a temporary exception entitlement.
      Two earlier homes failed. An App Group was tried first:
      `containermanagerd` logs `requesting
      [group.com.goranimperator.ImperatorClock]: REJECTED. Group containers
      identifiers should be prefixed by requestor's team ID`, and the rejection
      killed the extension at sandbox init. The widget's own container worked
      until macOS 27 closed outside access to another app's container; the app
      then reported `NSCocoaErrorDomain 257` on read and `513` on write even
      when launched by LaunchServices so it was responsible for itself. Measured
      with `--report`, not inferred: running a check flag from a shell attributes
      the request to the shell, not the app, so it proves nothing either way.
      After the move the widget's own heartbeat reads
      `"container": "/Users/goran/Library/Application Support/ImperatorClock"`
      with the skin and neon values the app had just written, which is the
      sandboxed side proving it can reach the file.

## G11 The menu bar icon matches its siblings and its colon is centred
- [x] The drawn icon is the same size, border weight and corner radius as the
      gamepad icon in imperator-free-games, and the colon sits dead centre
      inside the outline on whole pixels.
      CHECK: ./.build/release/ImperatorClock --icon-check
      EXPECT: G11_ICON_OK
      EVIDENCE: the check renders imperator-free-games' own gamepad SVG and
      compares against the live drawing, not against copied numbers. Before:
      canvas 23 x 16, ink 22.00 x 13.00 pt, corner inset 2.25 pt, colon 0.50 pt
      right of centre. After: canvas 18 x 18, ink 16.50 x 10.50 pt, corner inset
      1.50 pt, colon 0.000 pt off in x and y at 1x, 2x and 3x with no part-lit
      pixels. The games icon measures 18 x 18 and 16.50 x 10.50 with a 1.50 pt
      inset. Negative controls: a canvas back at 16pt failed on five counts, and
      a colon nudged 0.5 pt failed on offset and on blur.

## G12 The About panel matches brandbook 10
- [x] The footer carries About next to Quit, and the panel it opens is the size,
      shape and content section 10 specifies.
      CHECK: "/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" --about-check
      EXPECT: G12_ABOUT_OK
      EVIDENCE: `panel 300x260`, `laid out: 300x247`, `icon 128x128`. The check
      builds the real NSPanel and reads it rather than re-stating the numbers:
      300 wide, .titled/.closable/.fullSizeContentView, transparent title bar,
      hidden title, movable by background, not released when closed, and not
      hidden on deactivate. It lays the content out and measures what it needs,
      so the gate proves nothing is clipped instead of trusting the height. The
      version line is compared against the bundle's own keys, so the panel
      cannot claim a version the build does not carry.

      Four defects were found this way, none of them visible in a screenshot.
      Assigning contentViewController resizes the window to the SwiftUI view's
      fitting size, which is zero before layout, so the panel came up 0x0. The
      first version of the check compared the panel against its own constant, so
      a 320pt panel passed; it compares against the literal 300 now and fails on
      320, verified. `NSApp.applicationIconImage` returns an empty image in an
      LSUIElement app, and an empty image in SwiftUI takes no space at all
      rather than drawing a blank, so the panel laid out 146pt tall with no icon
      and no gap where one belonged; the icon is loaded from the bundle by name
      now and the gate fails on a zero-sized one. And hidesOnDeactivate defaults
      to true on an NSPanel, which in an .accessory app means the panel vanishes
      on the first click outside it; removing that fix fails both this gate and
      G2.

      One thing the gate does not cover: the panel was photographed showing all
      four text lines, but a system permission dialog from another app sat over
      it on both attempts at a clean shot with the icon in place. The icon is
      measured, not seen.

## G3 Unlit segments render at 5 %
- [x] Measured luminance of an unlit segment is 0.25 of a lit one, +/- 0.015.
      CHECK: ./.build/release/ClockPreview --verify
      EXPECT: G3_DIM_OK
      EVIDENCE: `lit=255.0 unlit=25.0 ratio=0.0980`
      It was 0.05 until macOS 27. `Dim widgets on desktop` composites the widget
      from outside at about 0.75 and in greyscale, and not linearly: sourced at
      0.30 the ghosts disappeared outright, 0.37 measured 0.188 on screen and
      0.45 measured 0.251. At 0.05 they were gone whenever a window covered the
      desktop. Nothing in the code can react to it, measured with a probe that
      drew the face red whenever the rendering mode was not `.fullColor` and
      produced zero red pixels with Dim on. 0.25 was settled by eye against the
      real dimmed desktop; the popover preview is never dimmed and cannot judge
      it.

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
      EXPECT: G6_WIDGET_LIVE_OK, and a `proof:` line naming what was observed
      EVIDENCE: `proof: the widget read skin=white 2 minutes ago`. Either half
      is proof on its own: the heartbeat matching the settings the widget was
      asked to read, or chronod logging `getAllDescriptors result.` rather than
      `error result`. Both can be missing, because WidgetKit may not have asked
      in the window, and the check then prints `G6_WIDGET_LIVE SKIPPED` and its
      reason. It used to print OK after skipping both halves, which is the same
      mistake as accepting registration as proof of life; that was found during
      the 1.0.1 audit, when it reported OK on a 68 minute old heartbeat and no
      chronod entry at all. Verified in both directions: fresh heartbeat gives
      a proof line, and touching the settings file so the comparison cannot run
      gives SKIPPED.

## G13 A dimmed face draws white
- [x] `Dim widgets on desktop` set to anything but Never makes the face render
      white whatever colour is picked, and the colour comes back when it is off.
      CHECK: "/Applications/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" --dim-check
      EXPECT: G13_DIM_CHANNEL_OK
      EVIDENCE: `com.apple.widgets/widgetAppearance = 0 -> dimmed=true`,
      `shared file: skin=white widgetsDimmed=true`. The gate covers the mapping
      (0 and 2 dimmed, 1 and an absent key not), the override itself (a blue
      face with the dimming on draws white while `skin` stays `.blue`, and the
      glow survives), and the live half: the value the app reads now against the
      `widgetsDimmed` it published, which catches a watcher that stopped or a
      write that failed. Verified in both directions on the desktop: with
      `skin=blue` and the dimming on, the widget's own window capture came back
      white, and it had been a black rectangle before this existed. The gate
      also failed correctly against the previous build, which had no watcher:
      `FAIL the shared file says widgetsDimmed=false while the setting says
      true`.

      The mapping was measured, not taken from `DesktopSettings.appex`'s App
      Intents metadata, because the two disagree: the metadata orders the cases
      Automatically, Never, Always, while the key held 0 in the state whose
      widgets render in greyscale and 1 for Never. Apple's Weather widget
      settled it: captured at 0 it has no colour in it.

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
