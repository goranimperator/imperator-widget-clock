// Gate G2: the five colours, the colour picker and the neon switch exist end to
// end -- in the shared model, in the app's settings UI, and on the widget's
// read path -- and the popover follows the Imperator apps brandbook.
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
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
// nothing inside it, so the popover is the only place this can be said. It has
// to name Classic White too: greyscale maps a colour to its luminance, and a
// blue face comes back as black rather than as a dimmer blue.
expect(/Dim widgets on desktop/.test(settingsView),
  'the popover no longer explains what Dim widgets on desktop does to the colour');
expect(/Use Classic White while Dim is on\./.test(settingsView),
  'the popover no longer recommends Classic White while Dim is on');
const appDelegateSource = read('Sources/ImperatorClock/AppDelegate.swift');
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
// A transient popover closes the moment NSColorPanel takes key, which drops
// every colour the user picks.
expect(/popover\.behavior = \.applicationDefined/.test(appDelegate),
  'the popover is transient, so opening the colour panel would dismiss it');
expect(/addGlobalMonitorForEvents/.test(appDelegate),
  'nothing closes the popover on a click outside');

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
expect(/style: entry\.style/.test(widget) && /preferences\.style/.test(widget),
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

if (failures.length) {
  for (const failure of failures) console.error(`FAIL ${failure}`);
  process.exit(1);
}
console.log('G2_CONFIG_OK');
