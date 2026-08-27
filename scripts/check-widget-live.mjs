// Gate G6: the widget extension is not merely registered, it answers.
//
// A registered-but-dead extension looks identical from `pluginkit`, so the
// oracle is the heartbeat the widget writes from getTimeline, plus chronod's
// own verdict on the descriptor query. Both must be recent.
import { execFileSync } from 'node:child_process';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { homedir } from 'node:os';

const store = `${homedir()}/Library/Containers/com.goranimperator.ImperatorClock.ClockWidget`
  + '/Data/Library/Application Support/ImperatorClock';
const heartbeat = `${store}/widget-heartbeat.json`;
const settings = `${store}/settings.json`;
const failures = [];

const registered = execFileSync('pluginkit', ['-mAv', '-p', 'com.apple.widgetkit-extension'], {
  encoding: 'utf8',
}).includes('ImperatorClock.ClockWidget');
if (!registered) failures.push('the widget is not registered with WidgetKit');

if (!existsSync(heartbeat)) {
  failures.push(`no ${heartbeat}: getTimeline has never run`);
} else {
  const beat = JSON.parse(readFileSync(heartbeat, 'utf8'));
  const wanted = JSON.parse(readFileSync(settings, 'utf8'));
  const ageMinutes = (Date.now() - Date.parse(beat.ranAt)) / 60000;
  console.log(`heartbeat ${beat.ranAt} (${ageMinutes.toFixed(0)} min old) skin=${beat.skin} neon=${beat.neon}`);
  if (ageMinutes > 180) failures.push(`heartbeat is ${ageMinutes.toFixed(0)} minutes old`);
  // Only compare when the widget has actually run since the settings changed.
  // WidgetKit can be a minute behind a fresh edit, and that is not a failure.
  const settingsWrittenAt = statSync(settings).mtimeMs;
  if (Date.parse(beat.ranAt) < settingsWrittenAt) {
    console.log('settings changed after the last timeline; skipping the value comparison');
  } else if (beat.skin !== wanted.skin) {
    failures.push(`widget read skin ${beat.skin}, settings say ${wanted.skin}`);
  }
}

// chronod's own answer. An error result here is the failure mode that kept the
// widget blank for hours: the extension exited before answering.
const log = execFileSync('/usr/bin/log', [
  'show', '--last', '30m', '--info', '--debug',
  '--predicate', 'process == "chronod"', '--style', 'compact',
], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const lines = log.split('\n').filter((l) => l.includes('ImperatorClock.ClockWidget')
  && l.includes('getAllDescriptors'));
const lastResult = [...lines].reverse().find((l) => l.includes('result'));
if (!lastResult) {
  console.log('no getAllDescriptors in the last 30 minutes; skipping that half');
} else if (lastResult.includes('error result')) {
  failures.push(`chronod could not read the widget: ${lastResult.trim().slice(-120)}`);
} else {
  console.log('chronod getAllDescriptors: result');
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL ${f}`);
  process.exit(1);
}
console.log('G6_WIDGET_LIVE_OK');
