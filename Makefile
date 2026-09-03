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

# Self-signed identity, not ad-hoc. Two reasons here. The app registers a login
# item through SMAppService, and that registration is keyed to the bundle's
# designated requirement. And WidgetKit caches the widget extension by its
# signing identity, so an ad-hoc cdhash that changes on every build makes the
# widget disappear from the gallery after an update.
CODESIGN_IDENTITY ?= Imperator Dev

.PHONY: all build clean run install preview dist release check-version gates

all: build

build:
	swift build -c release
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	@mkdir -p "$(APPEX)/Contents/MacOS"
	cp ".build/release/$(BINARY_NAME)" "$(BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	cp ".build/release/$(WIDGET_NAME)" "$(APPEX)/Contents/MacOS/$(WIDGET_NAME)"
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
	open "/Applications/$(APP_NAME).app"

run: build
	open "$(BUNDLE)"

# Renders the face to PNGs for visual review. Nothing here ships.
preview:
	swift build -c release
	./.build/release/ClockPreview --render build/preview
	open build/preview

# Every runnable gate in GATES.md, in order. G8 is a visual review.
gates: build
	@swift build -c release 2>&1 | grep -c "error:" | grep -qx 0 && echo G1_BUILD_OK
	@node scripts/check-config.mjs
	@node scripts/check-upright.mjs
	@./.build/release/ClockPreview --verify
	@./.build/release/ClockPreview --verify-gaps | tail -1
	@codesign --verify --deep --strict "$(BUNDLE)" \
		&& codesign --verify --strict "$(APPEX)" && echo G5_SIGN_OK
	@pluginkit -mAv -p com.apple.widgetkit-extension 2>/dev/null \
		| grep -qi "ImperatorClock.ClockWidget" && echo G6_WIDGET_REGISTERED \
		|| echo "G6 SKIPPED -- run make install first"
	@./.build/release/$(BINARY_NAME) --icon-check | tail -1
	# Before --group-check, which writes a probe to the settings file: that
	# moves its mtime, and the live check will not compare a heartbeat older
	# than the settings it is supposed to have read.
	@node scripts/check-widget-live.mjs
	@"/Applications/$(APP_NAME).app/Contents/MacOS/$(BINARY_NAME)" --group-check \
		| tail -1 || echo "G2B SKIPPED -- run make install first"

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
		--notes "A seven-segment retro clock as a macOS desktop widget, with a menu bar app that holds its settings. Six colours including one you pick yourself, an optional neon glow, and unlit strokes held at 5 percent so the face reads like a real LCD. Signed with a self-signed certificate and not notarized, so Gatekeeper blocks the first launch: right-click the app and choose Open, or run \`xattr -dr com.apple.quarantine \"/Applications/$(APP_NAME).app\"\`." \
		"$(ZIP)#$(APP_NAME) $(VERSION) (macOS)"
	@echo "Released v$(VERSION)"
