// Gate G2: the five colours, the colour picker and the neon switch exist end to
// end -- in the shared model, in the app's settings UI, and on the widget's
// read path -- and the popover follows the Imperator apps brandbook.
import { readdirSync, readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
/// Every Swift file under a directory, as repo-relative paths. Used to check a
/// claim about the whole tree rather than about the files this script happens
/// to name.
function* globSwift(dir) {
  for (const entry of readdirSync(new URL(`../${dir}`, import.meta.url), { withFileTypes: true })) {
    if (entry.isDirectory()) yield* globSwift(`${dir}/${entry.name}`);
    else if (entry.name.endsWith('.swift')) yield `${dir}/${entry.name}`;
  }
}
const failures = [];
const expect = (condition, message) => { if (!condition) failures.push(message); };

const skinFile = read('Sources/ClockCore/ClockSkin.swift');
// ClockSkin and ClockHourFormat share the file, so read only the skin's own body.
const skinSource = skinFile.split('public enum ClockHourFormat')[0];
const cases = [...skinSource.matchAll(/^\s{4}case (\w+)$/gm)].map((m) => m[1]);
const wanted = ['red', 'green', 'blue', 'white', 'purple', 'custom'];
expect(
  cases.length === wanted.length && wanted.every((c) => cases.includes(c)),
  `ClockSkin cases are ${JSON.stringify(cases)}, expected ${JSON.stringify(wanted)}`
);

// Every skin needs real components, otherwise a case could exist and render black.
for (const skin of wanted) {
  expect(
    new RegExp(`case \\.${skin}:\\s+return `).test(skinSource),
    `ClockSkin.components has no entry for .${skin}`
  );
}
expect(/defaultCustomHex/.test(skinSource) && /components\(fromHex/.test(skinSource),
  'ClockSkin cannot resolve a custom hex colour');
const defaultHex = skinSource.match(/defaultCustomHex = "([0-9A-Fa-f]{6})"/)?.[1];
expect(defaultHex !== undefined && defaultHex.toUpperCase() !== 'FF7A18',
  `the default custom colour is still the old orange (${defaultHex})`);

const styleSource = read('Sources/ClockCore/ClockStyle.swift');
expect(/dimOpacity: Double = 0\.25/.test(styleSource),
  'ClockStyle.dimOpacity does not default to 0.25');
expect(/glowLayers/.test(styleSource),
  'ClockStyle is missing the glow layers');
// Neon adds a halo and nothing else. A core that drops saturation makes the
// digits paler the moment the glow is switched on, which is the opposite of
// what the glow is for.
expect(!/neonCore/.test(styleSource),
  'the neon core is back, so switching the glow on washes the colour out');
expect(/litColor: Color \{ flatLitColor \}/.test(styleSource),
  'the lit colour changes with the glow instead of staying put');

const sharedSource = read('Sources/ClockCore/SharedStore.swift');
expect(/var skin: ClockSkin/.test(sharedSource) && /var neon: Bool/.test(sharedSource)
  && /var hourFormat: ClockHourFormat/.test(sharedSource),
  'ClockPreferences is missing skin, neon or hourFormat');

const settingsView = read('Sources/ImperatorClock/SettingsView.swift');
expect(/ForEach\(ClockSkin\.presets/.test(settingsView),
  'the settings popover does not offer every preset skin');
expect(/BrandToggle\("Neon glow", isOn: \$settings\.neon\)/.test(settingsView),
  'the settings popover has no neon toggle');
expect(/ColorPanelController\.shared\.present/.test(settingsView),
  'the custom swatch does not open the colour picker');
expect(!/TextField\(/.test(settingsView),
  'the custom colour is typed rather than picked');
// `Dim widgets on desktop` greyscales the whole widget from outside and tells
// the widget nothing, so the popover has to explain what happens to the colour.
expect(/Dim widgets on desktop/.test(settingsView),
  'the popover no longer explains what Dim widgets on desktop does to the colour');
const appDelegateSource = read('Sources/ImperatorClock/AppDelegate.swift');
// chronod serves the extension and the snapshot it drew from before the
// install, so without this the widget on the desktop shows the previous build
// and eventually nothing at all. The heartbeat keeps being written either way,
// so no other gate sees it.
expect(/WidgetRefresh\.afterInstall\(\)/.test(appDelegateSource),
  'the app does not refresh the widget after an install, so chronod keeps the old build');
// The dimming channel: the app reads the setting the widget cannot see, and the
// face draws white while it is on. Three separate things can break here, and
// only the mapping is covered by --dim-check's pure half.
const dimSource = read('Sources/ClockCore/WidgetDimming.swift');
expect(/com\.apple\.widgets/.test(dimSource) && /widgetAppearance/.test(dimSource),
  'WidgetDimming no longer reads com.apple.widgets/widgetAppearance');
expect(/var widgetsDimmed: Bool/.test(sharedSource),
  'the shared file no longer carries widgetsDimmed, so the widget cannot be told');
expect(/effectiveStyle/.test(sharedSource),
  'ClockPreferences has no effectiveStyle, so a dimmed face draws the picked colour');
const widgetSource = read('Sources/ClockWidget/ClockWidget.swift');
expect(/preferences\.effectiveStyle/.test(widgetSource),
  'the widget draws style rather than effectiveStyle, so a dimmed blue face is black again');
expect(/DimWatch\(settings: settings\)/.test(appDelegateSource),
  'the app does not watch the dimming setting, so widgetsDimmed is never published');
// The popover has to describe the behaviour rather than ask the user to work
// around it, which is what it did while this was thought impossible.
expect(/renders white while that is on/.test(settingsView),
  'the popover no longer says the face renders white while widgets are dimmed');
expect(!/Use Classic White while Dim is on/.test(settingsView),
  'the popover still tells the user to pick white by hand');
const refreshSource = read('Sources/ImperatorClock/WidgetRefresh.swift');
expect(/killall/.test(refreshSource) && /chronod/.test(refreshSource),
  'WidgetRefresh no longer restarts chronod, and a timeline reload alone does not clear its snapshot');
// Restarting chronod redraws every widget on the desktop, so it may only
// happen when the build has actually moved.
expect(/CFBundleVersion/.test(refreshSource) && /previous != current/.test(refreshSource),
  'WidgetRefresh restarts chronod on every launch rather than only on a new build');
// Brandbook 7.2: every toggle is a brand-tinted switch, and they all sit on the
// same two columns, so no toggle may carry an indent of its own.
expect(!/\.padding\(\.leading,\s*\d+\)/.test(settingsView),
  'a toggle row is indented, so the glow toggles no longer line up');

const appColors = read('Sources/ImperatorClock/AppColors.swift');
expect(/toggleStyle\(\.switch\)/.test(appColors) && /\.tint\(AppColors\.brand\)/.test(appColors),
  'BrandToggle is not a brand-tinted switch');
expect(/0xa0 \/ 255\.0/.test(appColors),
  'AppColors.brand is not Imperator red #A01818');

// Brandbook 14.2, method 3: a bare accentColor can fall back to macOS blue.
// Comments are stripped first, or the very comment explaining the rule would
// trip it.
const stripComments = (source) => source
  .split('\n')
  .map((line) => line.replace(/\/\/.*$/, ''))
  .join('\n');
for (const path of ['Sources/ImperatorClock/SettingsView.swift',
                    'Sources/ImperatorClock/AppColors.swift',
                    'Sources/ImperatorClock/AppDelegate.swift']) {
  expect(!/\baccentColor\b/.test(stripComments(read(path))),
    `${path} uses Color.accentColor, which shows macOS blue`);
}

const appDelegate = appDelegateSource;
expect(/AppleAccentColor/.test(appDelegate),
  'the app never pins its accent colour, so system blue can leak in');
// The panel is drawn rather than taken from NSPopover, because macOS 27 draws
// its own menu bar panels at a 17.5 pt corner with no arrow and no animation,
// and an NSPopover matches none of that. See MenuBarPanel.
const panelSource = read('Sources/ImperatorClock/MenuBarPanel.swift');
expect(/MenuBarPanel\(/.test(appDelegate),
  'the app no longer opens a MenuBarPanel, so its panel is not the system shape');
expect(/cornerRadius: CGFloat = 18\.25/.test(panelSource),
  'MenuBarPanel.cornerRadius is not 18.25, which is what draws the measured 17.50');
expect(!/arrowHeight|arrowWidth/.test(panelSource),
  'the panel has grown an arrow back; macOS 27 menu bar panels have none');
expect(!/NSAnimationContext|animator\(\)/.test(panelSource),
  'the panel animates; macOS 27 puts its own menu bar panels up instantly');
// The colour wheel is a window of its own, so every click in it is a click
// outside the panel. Closing on those drops the colour that was just picked.
expect(/shouldCloseOnOutsideClick = \{ !NSColorPanel\.shared\.isVisible \}/.test(appDelegate),
  'the panel would close on a click in the colour wheel, dropping the colour');
expect(/addGlobalMonitorForEvents/.test(panelSource),
  'nothing closes the panel on a click outside');

// A widget is a still frame: WidgetKit collapses sub-minute timeline entries,
// so a pulse or a blinking colon can only ever be a setting that does nothing.
for (const [path, source] of [['ClockStyle.swift', styleSource],
                              ['SharedStore.swift', sharedSource],
                              ['SettingsView.swift', settingsView]]) {
  expect(!/\bpulse/i.test(source), `${path} still carries the pulse`);
  expect(!/colonLit/.test(source), `${path} still carries the blinking colon`);
}

const appSettings = read('Sources/ImperatorClock/ClockSettings.swift');
expect(/SharedStore\.save\(self\.preferences\)/.test(appSettings),
  'the app never writes the shared settings file');
expect(/publishWorkItem\?\.cancel\(\)/.test(appSettings),
  'settings writes are not coalesced, so a colour drag would drain the reload budget');
expect(/WidgetCenter\.shared\.reloadAllTimelines\(\)/.test(appSettings),
  'the app never asks WidgetKit to reload, so the widget would lag behind');

const widget = read('Sources/ClockWidget/ClockWidget.swift');
expect(/SharedStore\.load\(\)/.test(widget),
  'the widget does not read the shared settings');
expect(/style: entry\.style/.test(widget) && /preferences\.effectiveStyle/.test(widget),
  'the widget does not apply the shared style');
expect(/supportedFamilies\(\[\.systemMedium\]\)/.test(widget),
  'the widget does not declare the medium family');
// Settings live in the menu bar app, so the gallery carries exactly one card.
const cards = [...widget.matchAll(/StaticConfiguration\(kind:/g)].length;
expect(cards === 1, `the widget bundle publishes ${cards} gallery cards, expected 1`);
expect(!/ColourClockWidget/.test(widget),
  'the per-colour gallery cards are back');

// Brandbook 10.1: About sits in the footer next to Quit, and the full name
// "About Imperator WidgetClock" is the tooltip because the row already carries
// the login toggle inside 340pt.
expect(/AboutPanel\.show\(\)/.test(settingsView),
  'the footer has no About button');
expect(/\.help\("About Imperator WidgetClock"\)/.test(settingsView),
  'the About button does not carry the brandbook name as its tooltip');
expect(/dismissPopover\(\)/.test(settingsView),
  'opening About leaves the popover up, so there are two things to dismiss');

// The About panel is a window of its own in an .accessory app, the same shape
// as the colour panel, and it needs the same two fixes or it never shows.
const aboutPanel = read('Sources/ImperatorClock/AboutPanel.swift');
expect(/hidesOnDeactivate = false/.test(aboutPanel),
  'the About panel hides on deactivate, so it vanishes on the first click outside');
expect(/NSApp\.activate\(ignoringOtherApps: true\)/.test(aboutPanel),
  'the About panel is never activated, so it opens behind the frontmost app');
expect(/setContentSize\(/.test(aboutPanel) && /layoutSubtreeIfNeeded\(\)/.test(aboutPanel),
  'the panel does not lay out and re-assert its size, so it opens 0pt tall');

// The sandboxed widget reaches the store through a temporary exception naming
// an exact path. That string, SharedStore.homeRelativePath and the path this
// script reads are three hand-kept copies of one value; if they drift, every
// other gate still passes and the widget silently falls back to its defaults,
// which is how the App Group and the container traps both presented.
const storeSource = read('Sources/ClockCore/SharedStore.swift');
const relativePath = storeSource.match(/homeRelativePath = "([^"]+)"/)?.[1];
expect(relativePath !== undefined, 'SharedStore has no homeRelativePath');
if (relativePath) {
  const entitlements = read('Resources/ClockWidget.entitlements');
  const granted = `/${relativePath}/`;
  expect(entitlements.includes('com.apple.security.temporary-exception.files.'
    + 'home-relative-path.read-write'),
    'the widget has no home-relative-path exception, so it cannot read the store');
  expect(entitlements.includes(`<string>${granted}</string>`),
    `the entitlement does not grant "${granted}", which is where SharedStore reads`);
  expect(read('scripts/check-widget-live.mjs').includes(relativePath),
    'this gate script reads a different path than SharedStore does');
}

// A menu bar app with a Dock tile is not a menu bar app. The runtime
// setActivationPolicy(.accessory) call is not enough on its own: LaunchServices
// creates the tile before main() runs, and the app shipped a Dock icon for that
// reason until LSUIElement went into the plist.
const appPlist = read('Resources/Info.plist');
expect(/<key>LSUIElement<\/key>\s*<true\/>/.test(appPlist),
  'Resources/Info.plist has no LSUIElement, so the app takes a Dock tile');
expect(/setActivationPolicy\(\.accessory\)/.test(read('Sources/ImperatorClock/AppMain.swift')),
  'the app no longer sets .accessory, so it would show in the app switcher');

// Every rounded shape the app draws in a system shape takes its radius from
// one of two measured constants, never from a literal of its own. There were
// three numbers for one shape before this: 24 in ClockStyle, 20 in the review
// render and 10 in the popover preview. The measured values live in G14; this
// only checks that nothing has gone back to a literal.
expect(/containerCornerRadius: CGFloat = 30/.test(styleSource),
  'ClockStyle.containerCornerRadius is not 30, which is what macOS 27 draws round a widget');
expect(/panelCornerRadius: CGFloat = 17\.5/.test(styleSource),
  'ClockStyle.panelCornerRadius is not 17.5, which is the corner the panel draws');
// The radius above is only right while the binary carries the real SDK stamp,
// so the flag that produces it is part of the same claim. G15 checks the built
// binary; this catches the Makefile losing the flag.
expect(/PLATFORM_STAMP/.test(read('Makefile')) && /platform_version/.test(read('Makefile')),
  'the Makefile no longer stamps the real SDK, so macOS draws the previous generation of popover');
// And the extension has to keep the old one: on the new stamp WidgetKit drew
// every segment the same flat grey, which erases the unlit ghosts the face is
// made of. G15 checks the built binaries; this catches the recipe losing it.
expect(/vtool -set-build-version macos \$\(MIN_MACOS\)/.test(read('Makefile')),
  'the widget appex is no longer stamped back to MIN_MACOS, so the face loses its ghosts');
// The card sits inside the popover's own corner and is read against it, so it
// takes the popover's radius rather than the widget's.
expect(/RoundedRectangle\(cornerRadius: ClockStyle\.panelCornerRadius/.test(settingsView),
  'the preview card no longer uses ClockStyle.panelCornerRadius');
expect(/cornerRadius: ClockStyle\.containerCornerRadius/
  .test(read('Sources/ClockPreview/main.swift')),
  'the review render no longer uses ClockStyle.containerCornerRadius');
expect(/macOSWidgetCornerRadius: CGFloat = 30/.test(read('Sources/ClockPreview/main.swift')),
  'the corner gate no longer measures against the literal 30');

// The update check. One GET a day to this repo's releases/latest is the app's
// only network traffic, and three separate promises hang off that sentence: the
// slug has to be this app's, the request has to be the only one in the tree,
// and the link that comes back out of it may only ever open github.com.
const updateSource = read('Sources/ImperatorClock/UpdateChecker.swift');
expect(/repoSlug = "goranimperator\/imperator-widget-clock"/.test(updateSource),
  'UpdateChecker points at another app\'s repo, so it would compare against the wrong releases');
expect(/api\.github\.com\/repos\/\\\(repoSlug\)\/releases\/latest/.test(updateSource),
  'UpdateChecker no longer asks for releases/latest on its own repo');
expect(/url\.scheme == "https", url\.host == "github\.com"/.test(updateSource),
  'UpdateChecker.open no longer pins the link to https://github.com, and that URL comes '
  + 'out of a network response');
expect(/interval: TimeInterval = 24 \* 60 \* 60/.test(updateSource),
  'the check is no longer once a day');
// Only a successful, parsed response may count toward the day, or a GitHub
// outage would cost the user a whole day of checks instead of an hour.
expect(updateSource.indexOf('set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)')
  > updateSource.indexOf('JSONDecoder().decode(LatestRelease.self'),
  'the last-check timestamp is written before the response is parsed, so a failed check '
  + 'would count toward the daily interval');
expect(/string\(forKey: Self\.notifiedKey\) != release\.version/.test(updateSource),
  'the notification is no longer once per version');
// The permission question belongs to the moment there is something to say. At
// first launch it is a prompt for a feature the user has not met yet.
expect(updateSource.indexOf('requestAuthorization') > updateSource.indexOf('private func notifyOnce'),
  'the notification permission is asked outside notifyOnce, so it would come up before '
  + 'there is any update to report');
// The whole tree, so a second request cannot appear somewhere the README does
// not mention. The widget runs sandboxed with no network entitlement and has no
// business asking GitHub anything.
const networkFiles = [...globSwift('Sources')]
  .filter((path) => path !== 'Sources/ImperatorClock/UpdateChecker.swift')
  .filter((path) => /URLSession|URLRequest|NSURLConnection|CFSocket|Network\b/
    .test(stripComments(read(path))));
expect(networkFiles.length === 0,
  `network code outside UpdateChecker: ${JSON.stringify(networkFiles)}, so "one request a `
  + 'day" is no longer the whole story');
expect(/UpdateChecker\.shared\.start\(\)/.test(appDelegateSource),
  'the app never starts the update checker, so it would never check');
// start() sets the notification delegate, and UNUserNotificationCenter refuses
// to exist outside a real bundle, so a gate running the bare binary from
// .build must reach its exit before this does.
expect(/func applicationDidFinishLaunching[\s\S]*UpdateChecker\.shared\.start\(\)/
  .test(appDelegateSource),
  'the update checker starts somewhere other than applicationDidFinishLaunching');
expect(/BrandToggle\("Check for updates", isOn: \$checkForUpdates\)/.test(settingsView),
  'the panel has no switch for the update check');
expect(/@AppStorage\(UpdateChecker\.enabledKey\)/.test(settingsView),
  'the switch does not write the key the checker reads');
expect(/Text\("Check Now"\)/.test(settingsView),
  'the panel has no Check Now button');
// Brandbook 7.1: one button style in these panels, and it is HoverButton. The
// spec this was ported from used .bordered, which is the system style.
expect(!/buttonStyle\(\.bordered\)/.test(settingsView),
  'the Updates row uses the system bordered button rather than HoverButton');
// The row is measured once, when the panel opens, so it has to stay one line
// tall whatever the check finds. See updatesSection.
expect(/Text\(updateStatus\)[\s\S]{0,320}?lineLimit\(1\)/.test(settingsView),
  'the update status can wrap, and the panel sizes itself once, so a longer status would '
  + 'push the footer off the bottom edge');
// Installing is manual and meets Gatekeeper again, and the panel is where
// someone stands when they press Download.
expect(/quarantine flag/.test(settingsView),
  'the panel no longer says a downloaded update has to clear quarantine again');

// The README and CLAUDE.md both promised this app made no network requests at
// all. Both now have to say what the one request is, or the next session reads
// the checker as network code nobody asked for.
const readme = read('README.md');
expect(/api\.github\.com/.test(readme) && /releases\/latest/.test(readme),
  'the README does not name the one request the app makes');
expect(/notification/i.test(readme) && /quarantine/.test(readme),
  'the README does not cover the notification permission or the quarantine flag on an update');
const claudeMd = read('CLAUDE.md');
expect(/UpdateChecker/.test(claudeMd) && /api\.github\.com/.test(claudeMd),
  'CLAUDE.md does not document the update check, so the next session reads it as stray '
  + 'network code');

if (failures.length) {
  for (const failure of failures) console.error(`FAIL ${failure}`);
  process.exit(1);
}
console.log('G2_CONFIG_OK');
