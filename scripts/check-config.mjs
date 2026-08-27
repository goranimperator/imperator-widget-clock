// Gate G2: the five colours and the neon switch exist end to end -- in the
// shared model, in the app's settings UI, and on the widget's read path.
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

const styleSource = read('Sources/ClockCore/ClockStyle.swift');
expect(/dimOpacity: Double = 0\.05/.test(styleSource),
  'ClockStyle.dimOpacity does not default to 0.05');
expect(/glowLayers/.test(styleSource) && /neonCore/.test(styleSource),
  'ClockStyle is missing the neon core colour or the glow layers');
expect(/neonCoreSaturation/.test(styleSource) && /neonCoreBrightness/.test(styleSource),
  'the neon core is no longer derived from the skin hue');

const sharedSource = read('Sources/ClockCore/SharedStore.swift');
expect(/var skin: ClockSkin/.test(sharedSource) && /var neon: Bool/.test(sharedSource)
  && /var hourFormat: ClockHourFormat/.test(sharedSource),
  'ClockPreferences is missing skin, neon or hourFormat');

const settingsView = read('Sources/ImperatorClock/SettingsView.swift');
expect(/ForEach\(ClockSkin\.presets/.test(settingsView),
  'the settings popover does not offer every preset skin');
expect(/Toggle\("Neon glow", isOn: \$settings\.neon\)/.test(settingsView),
  'the settings popover has no neon toggle');
expect(/Toggle\("Pulse the glow once a second", isOn: \$settings\.pulse\)/.test(settingsView),
  'the settings popover has no pulse toggle');
expect(/ColorPicker\(/.test(settingsView),
  'the settings popover has no custom colour picker');
expect(/Toggle\("One clock on every display", isOn: \$settings\.allScreens\)/.test(settingsView),
  'the settings popover cannot put a clock on every display');
expect(/toggleStyle\(\.checkbox\)/.test(settingsView),
  'the neon control is not a checkbox');

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

if (failures.length) {
  for (const failure of failures) console.error(`FAIL ${failure}`);
  process.exit(1);
}
console.log('G2_CONFIG_OK');
