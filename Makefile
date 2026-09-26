APP_NAME    = Imperator WidgetClock
BINARY_NAME = ImperatorClock
WIDGET_NAME = ClockWidget
BUNDLE      = build/$(APP_NAME).app
APPEX       = $(BUNDLE)/Contents/PlugIns/$(WIDGET_NAME).appex
DIST        = dist
ZIP         = $(DIST)/Imperator-WidgetClock-$(VERSION).zip
BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
# `release` commits before it tags, but every variable expands first, so the
# tagged build needs the count plus that commit. `dist` alone commits nothing,
# and there the plain count is right.
RELEASE_BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null | awk '{print $$1 + 1}')
# Monotonic per-build stamp, so every install looks like a new version to WidgetKit.
# Seconds since a fixed recent epoch: monotonic, and short enough to stay a
# valid CFBundleVersion. A 14-digit timestamp is rejected and the extension
# then renders as an empty widget.
STAMP = $(shell echo $$(( $$(date +%s) - 1750000000 )))

# AppKit picks which generation of a control it draws from the `sdk` field in
# the binary's LC_BUILD_VERSION, and SwiftPM stamps that field from `platforms:`
# in Package.swift rather than from the SDK it compiled against. Pinned to
# macOS 14, this app therefore asked macOS 27 for macOS 14 era controls: the old
# narrow switch with a round knob instead of today's capsule, and the previous
# generation of NSPopover frame, which clips its content at 9.5 pt against the
# 19.75 pt macOS 27 draws. That is why this app's popover looked unlike every
# other Imperator app on the same machine.
#
# The minimum stays MIN_MACOS, so the app still installs on macOS 14. Only the
# sdk field moves, through the linker. Verify on the built binary:
#
#   vtool -show-build-version "build/Imperator WidgetClock.app/Contents/MacOS/ImperatorClock"
MIN_MACOS   = 14.0
SDK_VERSION = $(shell xcrun --sdk macosx --show-sdk-version)
PLATFORM_STAMP = -Xlinker -platform_version -Xlinker macos \
	-Xlinker $(MIN_MACOS) -Xlinker $(SDK_VERSION)

# Self-signed identity, not ad-hoc. Two reasons here. The app registers a login
# item through SMAppService, and that registration is keyed to the bundle's
# designated requirement. And WidgetKit caches the widget extension by its
# signing identity, so an ad-hoc cdhash that changes on every build makes the
# widget disappear from the gallery after an update.
CODESIGN_IDENTITY ?= Imperator Dev

# What the GitHub release says. The default describes the app, which is right
# for a first release and wrong for every later one: override it per release so
# the notes say what changed. The Gatekeeper line is appended either way, since
# it is true of every build and is the first thing a downloader hits.
#
# Both have to stay on one logical line. A literal newline inside a recipe line
# splits it into two shell commands, and the release then publishes with half
# its notes and a stray command after it.
NOTES ?= A seven-segment retro clock as a macOS desktop widget, with a menu bar \
app that holds its settings. Six colours including one you pick yourself, an \
optional neon glow, and unlit strokes held at 25 percent so the face reads like \
a real LCD. With Dim widgets on desktop turned on macOS draws every widget in \
greyscale, which would turn a colour into its grey, so the face renders white \
while that setting is on and picks the colour back up when it is off. The \
settings panel is drawn the way macOS 27 draws its own menu bar panels: a 17.5 \
point corner, no arrow and no animation. This release drops the pointing hand \
cursor from the panel's controls, which macOS does not show over a switch or a \
swatch either.
GATEKEEPER = Signed with a self-signed certificate and not notarized, so \
Gatekeeper blocks the first launch: right-click the app and choose Open, or run \
\`xattr -dr com.apple.quarantine \"/Applications/$(APP_NAME).app\"\`.

.PHONY: all build clean run install preview dist release check-version gates

all: build

build:
	swift build -c release $(PLATFORM_STAMP)
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	@mkdir -p "$(APPEX)/Contents/MacOS"
	cp ".build/release/$(BINARY_NAME)" "$(BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	cp ".build/release/$(WIDGET_NAME)" "$(APPEX)/Contents/MacOS/$(WIDGET_NAME)"
	# The extension keeps the macOS 14 stamp while the app takes the real SDK.
	# WidgetKit draws the face differently on the new one: with `sdk 27.0` in the
	# appex every segment came out the same flat grey, lit and unlit alike, so
	# the widget showed a uniform 88:88 with no ghosts and no readable time.
	# Captured from the widget's own window both ways, through `killall chronod`
	# and a forced reload, with nothing but this stamp different.
	#
	# It is not the tinted rendering path: a probe that drew the face red
	# whenever `widgetRenderingMode` was not `.fullColor` produced no red at all
	# on the new stamp, so the mode is still full colour and something else in
	# the new WidgetKit flattens the two layers. Not chased further, because the
	# app is where the popover lives and the extension draws no popover, so the
	# two binaries have no reason to agree.
	vtool -set-build-version macos $(MIN_MACOS) $(MIN_MACOS) -replace \
		-output "$(APPEX)/Contents/MacOS/$(WIDGET_NAME)" \
		"$(APPEX)/Contents/MacOS/$(WIDGET_NAME)"
	cp Resources/WidgetInfo.plist "$(APPEX)/Contents/Info.plist"
	# chronod caches a widget's descriptors against the extension's version, so a
	# version that never moves means a reinstall keeps the old configuration.
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(STAMP)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(STAMP)" "$(APPEX)/Contents/Info.plist"
	# Inside out: the extension is signed first, then sealed inside the app.
	codesign --force --entitlements Resources/ClockWidget.entitlements \
		--sign "$(CODESIGN_IDENTITY)" "$(APPEX)"
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	@echo "Built: $(BUNDLE)"

install: build
	@pkill -f $(BINARY_NAME) 2>/dev/null || true
	@sleep 0.5
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed: /Applications/$(APP_NAME).app"
	# chronod keeps the running extension process and the snapshot it drew
	# across a reinstall, so the placed widget goes on showing the previous
	# build and, after enough reinstalls in a row, an empty face: a black
	# rounded rectangle with no digits and no ghosts. The extension itself is
	# fine and goes on writing its heartbeat, which is why the live gate still
	# passes. Restarting chronod is the only reliable way to make the build
	# that was just installed the one on screen.
	@killall chronod 2>/dev/null || true
	open "/Applications/$(APP_NAME).app"

run: build
	open "$(BUNDLE)"

# Renders the face to PNGs for visual review. Nothing here ships.
preview:
	swift build -c release $(PLATFORM_STAMP)
	./.build/release/ClockPreview --render build/preview
	open build/preview

# Every runnable gate in GATES.md, in order. G8 is a visual review.
gates: export SHELL := /bin/bash
gates: build
	@swift build -c release $(PLATFORM_STAMP) 2>&1 | grep -c "error:" | grep -qx 0 && echo G1_BUILD_OK
	@node scripts/check-config.mjs
	@node scripts/check-upright.mjs
	@./.build/release/ClockPreview --verify
	@./.build/release/ClockPreview --verify-gaps | tail -1; \
		test $${PIPESTATUS[0]:-$$?} -eq 0
	@./.build/release/ClockPreview --verify-corner | tail -1; \
		test $${PIPESTATUS[0]:-$$?} -eq 0
	@vtool -show-build-version "$(BUNDLE)/Contents/MacOS/$(BINARY_NAME)" \
		| grep -q "sdk $(SDK_VERSION)" \
		&& vtool -show-build-version "$(APPEX)/Contents/MacOS/$(WIDGET_NAME)" \
		| grep -q "sdk $(MIN_MACOS)" && echo G15_SDK_STAMP_OK
	@codesign --verify --deep --strict "$(BUNDLE)" \
		&& codesign --verify --strict "$(APPEX)" && echo G5_SIGN_OK
	@pluginkit -mAv -p com.apple.widgetkit-extension 2>/dev/null \
		| grep -qi "ImperatorClock.ClockWidget" && echo G6_WIDGET_REGISTERED \
		|| echo "G6 SKIPPED -- run make install first"
	@./.build/release/$(BINARY_NAME) --icon-check | tail -1; \
		test $${PIPESTATUS[0]:-$$?} -eq 0
	# Before --group-check, which writes a probe to the settings file: that
	# moves its mtime, and the live check will not compare a heartbeat older
	# than the settings it is supposed to have read.
	@node scripts/check-widget-live.mjs
	@if [ -x "/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" ]; then \
		out=$$("/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" --group-check) \
			|| { echo "$$out"; exit 1; }; \
		echo "$$out" | tail -1; \
	else echo "G2B SKIPPED -- run make install first"; fi
	# Reads CFBundleShortVersionString and CFBundleVersion, so it needs the
	# bundle rather than the bare binary in .build.
	@if [ -x "/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" ]; then \
		out=$$("/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" --about-check) \
			|| { echo "$$out"; exit 1; }; \
		echo "$$out" | tail -1; \
	else echo "G12 SKIPPED -- run make install first"; fi
	# The installed copy, because half of this gate compares the live setting
	# against what the running app published to the shared file.
	@if [ -x "/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" ]; then \
		out=$$("/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" --dim-check) \
			|| { echo "$$out"; exit 1; }; \
		echo "$$out" | tail -1; \
	else echo "G13 SKIPPED -- run make install first"; fi

clean:
	rm -rf build dist

check-version:
	@test -n "$(VERSION)" || { echo "Usage: make $(MAKECMDGOALS) VERSION=1.0.0"; exit 1; }

# Build a distributable zip. Safe -- touches nothing in git, nothing on the remote.
dist: check-version build
	@mkdir -p $(DIST)
	rm -f "$(ZIP)"
	# Stamp the version into the BUILT bundle, not the source, so a test zip
	# reports the version it will ship as without dirtying the working tree.
	# Editing either plist breaks its signature, so re-sign both afterwards.
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APPEX)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(APPEX)/Contents/Info.plist"
	# Identical to the signing in `build`, so the zip ships the artefact the
	# gates verified rather than a differently signed one.
	codesign --force --entitlements Resources/ClockWidget.entitlements \
		--sign "$(CODESIGN_IDENTITY)" "$(APPEX)"
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	ditto -c -k --sequesterRsrc --keepParent "$(BUNDLE)" "$(ZIP)"
	@echo "Packaged: $(ZIP)"

# Bump version, commit, tag, push, publish the GitHub release with the zip attached.
release: check-version
	@git diff --quiet && git diff --cached --quiet || { echo "Working tree dirty -- commit first."; exit 1; }
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Resources/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(RELEASE_BUILD_NUMBER)" Resources/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Resources/WidgetInfo.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(RELEASE_BUILD_NUMBER)" Resources/WidgetInfo.plist
	$(MAKE) dist VERSION=$(VERSION) BUILD_NUMBER=$(RELEASE_BUILD_NUMBER)
	git add Resources/Info.plist Resources/WidgetInfo.plist
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "$(APP_NAME) $(VERSION)"
	git push origin HEAD
	git push origin v$(VERSION)
	gh release create v$(VERSION) \
		--title "$(APP_NAME) $(VERSION)" \
		--notes "$(NOTES) $(GATEKEEPER)" \
		"$(ZIP)#$(APP_NAME) $(VERSION) (macOS)"
	@echo "Released v$(VERSION)"
