# GATES: Imperator WidgetClock

CONTRACT: A macOS WidgetKit medium widget showing a seven-segment HH:MM clock:
one gallery card, unlit segments visible at 25 %, upright digits with even
spacing. Everything it looks like is set in a menu bar app whose panel follows
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

## G3 Unlit segments render at 25 %
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

## G14 The rounded shapes carry the radii macOS 27 draws
- [x] The widget's plate measures 30 pt at both bottom corners and the preview
      card 17.5, each from a constant that matches what macOS was measured
      drawing.
      CHECK: ./.build/release/ClockPreview --verify-corner
      EXPECT: G14_CORNER_OK
      EVIDENCE: `widget plate 360.0 x 180.0 pt  left=30.25 pt (rms 1.72 px)
      right=30.25 pt (rms 1.73 px)` and `panel preview card 308.0 x 92.0 pt
      left=17.75 pt (rms 1.12 px)  right=17.75 pt (rms 1.12 px)`. The quarter
      point is a continuous corner read by a circular fit on a quarter-point
      grid, not drift.

      Both numbers were measured on macOS 27.0 (26A428) rather than taken from a
      header, by capturing the window with `screencapture -o -l` and fitting the
      bottom corner profile of the drawn pixels against circles. The bottom, not
      the top, because an `NSPopover` puts an arrow on the top edge and it
      contaminates the profile.

      30.0 pt is the medium desktop widget, across 345 x 164 drawn points.
      17.50 pt is Control Centre's Wi-Fi panel, which is the panel macOS itself
      puts under a menu bar item; a titled window, Notes and this app's About
      panel alike, reads 17.25 by the same method.

      The card followed the container it sits in, and that container changed
      twice. It was 19.75 while the app used an `NSPopover` and the binary
      carried `sdk 27.0`, then 10 while the popover measurement was taken from a
      binary stamped `sdk 14.0`, and it is 17.5 now that `MenuBarPanel` draws the
      surface. Each of those was the right number for the container of the day
      and wrong for the next one, which is the argument for measuring the thing
      on screen rather than carrying a constant forward.

      `MenuBarPanel.cornerRadius` is 18.25 rather than 17.5, because an
      `NSVisualEffectView` blends its edge and draws about 0.75 pt tighter than
      the radius it is given: the panel measured 16.75 at 17.5 and measures 17.50
      at 18.25. SwiftUI draws what it is told, so `ClockStyle.panelCornerRadius`
      carries the drawn number instead.

      Reading the layer would have said something else. `NSPopoverFrame` reports
      `cornerRadius` 0 and rounds with a mask, so a probe holding an opaque
      magenta view still came back with the magenta rounded off at 19.75 pt.

      Which constant a shape takes depends on what it is seen against. The widget
      has nothing around it, so `WidgetContainer` answers to macOS alone at 30.
      The card sits inside the panel's corner and is read against it, so it takes
      17.5; at 30 it bulged against the frame holding it. Before any of this the
      same shape carried three numbers: 24 in `ClockStyle`, 20 in the review
      render and 10 in the preview.

      What the pixel half proves for the card is the constant's shape, not
      `SettingsView`'s use of it; that half is the source check in G2. The widget
      plate is measured end to end, because `WidgetContainer` is what draws it.

      The gate compares against the literals rather than against the constants it
      is checking, which is the lesson G12 learned when a 320 pt About panel
      passed a 300 pt gate. Verified in both directions on both shapes: with the
      widget constant set to 20 it fails `containerCornerRadius is 20.00, macOS
      27 draws 30.00 around a widget`; with that constant left at 30 but
      `WidgetContainer` drawing `- 10` it fails on the pixels, `widget plate
      bottom left corner measures 20.00 pt, macOS 27 draws 30.00 +/- 1.5`; and
      with the panel constant set to 30 it fails `panelCornerRadius is 30.00,
      macOS 27 draws its menu bar panels at 17.50`, which fails G2 as well.

## G15 The binary asks macOS for today's controls, not macOS 14's
- [x] The app carries the installed SDK in `LC_BUILD_VERSION` and the widget
      extension keeps macOS 14, with the minimum at macOS 14 on both.
      CHECK: make build >/dev/null && vtool -show-build-version "build/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock" | grep -q "sdk $(xcrun --sdk macosx --show-sdk-version)" && vtool -show-build-version "build/Imperator WidgetClock.app/Contents/PlugIns/ClockWidget.appex/Contents/MacOS/ClockWidget" | grep -q "sdk 14.0" && echo G15_SDK_STAMP_OK
      EXPECT: G15_SDK_STAMP_OK
      EVIDENCE: app `minos 14.0` / `sdk 27.0`, appex `minos 14.0` / `sdk 14.0`.
      Before the flag both read `sdk 14.0`, because SwiftPM stamps `sdk` from
      `platforms:` in Package.swift rather than from the SDK it compiled
      against.

      The two binaries differ on purpose. Stamping the extension as well made
      WidgetKit draw every segment in the same flat grey, lit and unlit alike:
      the widget's own window came back a uniform 88:88 with no ghosts and no
      readable time, through a `killall chronod` and a forced reload. Stamping
      only the extension back to 14 brought the face straight back, with
      nothing else changed. The app draws the popover and the extension draws
      the face, so they have no reason to agree.

      AppKit picks which generation of a control to draw from that field, so
      the app was asking macOS 27 for macOS 14 era controls: the narrow switch
      with a round knob instead of today's capsule, and the previous generation
      of popover frame. That frame is why this app's popover looked unlike every
      other Imperator app on the same machine, and why two sibling apps grew a
      hand-drawn `MenuBarPanel` of about 200 lines each to imitate it.

      Proven by stamp alone, with nothing else changed: one probe binary showing
      the same SwiftUI content was captured twice, once as built and once after
      `vtool -set-build-version macos 14.0 14.0 -replace` plus a re-sign. The
      frame moved from a 26.25 pt squircle clipping content at 19.75 to a 9.5 pt
      circular corner, and the switches moved from capsules to the old narrow
      knob.

      The minimum deliberately does not move. `platforms:` still says macOS 14,
      so the app installs there; only the `sdk` field is stamped through the
      linker.

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
