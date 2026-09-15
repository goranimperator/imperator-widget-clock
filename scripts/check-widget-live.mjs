// Gate G6: the widget extension is not merely registered, it answers.
//
// A registered-but-dead extension looks identical from `pluginkit`, so the
// oracle is the heartbeat the widget writes from getTimeline, plus chronod's
// own verdict on the descriptor query.
//
// Either one is proof on its own, and both can be unavailable: WidgetKit may
// simply not have asked recently. When that happens this gate reports SKIPPED
// rather than OK. It used to print OK after skipping both halves, which is the
// same mistake as accepting registration as proof of life.
import { execFileSync } from 'node:child_process';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { homedir } from 'node:os';

// The real home, not the widget's container. macOS 27 closed outside access to
// another app's container, so the store moved here and the widget reaches it
// through a sandbox temporary exception. Keep this in step with
// SharedStore.homeRelativePath.
const store = `${homedir()}/Library/Application Support/ImperatorClock`;
const heartbeat = `${store}/widget-heartbeat.json`;
const settings = `${store}/settings.json`;
const failures = [];
// What was actually observed, as opposed to what merely did not fail.
const proofs = [];

const registered = execFileSync('pluginkit', ['-mAv', '-p', 'com.apple.widgetkit-extension'], {
  encoding: 'utf8',
}).includes('ImperatorClock.ClockWidget');
if (!registered) failures.push('the widget is not registered with WidgetKit');

// A read here used to throw a raw stack trace at whoever ran `make gates`.
// The three interesting outcomes are "not there yet", "not allowed to look" and
// "there but corrupt", and they are different problems with different fixes.
const readJSON = (path) => {
  try {
    return { value: JSON.parse(readFileSync(path, 'utf8')) };
  } catch (error) {
    return { error };
  }
};
const denied = (error) => error.code === 'EPERM' || error.code === 'EACCES';
const missing = (error) => error.code === 'ENOENT';

// Not existsSync: it returns false for a permission error too, which reported a
// denied store as "the widget never ran" and hid the case this branch is for.
const beatRead = readJSON(heartbeat);
if (beatRead.error && denied(beatRead.error)) {
  failures.push(`cannot read ${beatRead.error.path}: ${beatRead.error.code}. `
    + 'Ask the app itself: open -n -a "/Applications/Imperator WidgetClock.app" '
    + '--args --report /tmp/store.txt');
} else if (beatRead.error && missing(beatRead.error)) {
  failures.push(`no ${heartbeat}: getTimeline has never run`);
} else if (beatRead.error) {
  failures.push(`${heartbeat} is unreadable: ${beatRead.error.message}`);
} else {
  const beat = beatRead.value;
  const ranAt = Date.parse(beat.ranAt);
  if (!Number.isFinite(ranAt)) {
    // NaN compares false against everything, so an undated heartbeat used to
    // slip past the age limit and still collect a proof.
    failures.push(`${heartbeat} has no usable ranAt: ${JSON.stringify(beat.ranAt)}`);
  } else {
    const ageMinutes = (Date.now() - ranAt) / 60000;
    console.log(`heartbeat ${beat.ranAt} (${ageMinutes.toFixed(0)} min old) `
      + `skin=${beat.skin} neon=${beat.neon}`);
    if (ageMinutes > 180) failures.push(`heartbeat is ${ageMinutes.toFixed(0)} minutes old`);
    // The widget writes the directory it actually resolved. If that is not the
    // one being read here, the two sides are looking at different files and
    // every other check below is meaningless.
    if (beat.container && beat.container !== store) {
      failures.push(`the widget wrote to ${beat.container}, not ${store}`);
    }

    const wantedRead = readJSON(settings);
    if (wantedRead.error && missing(wantedRead.error)) {
      // A fresh install has a heartbeat before it has settings: the app only
      // writes on the first change. Absent evidence is not a failure.
      console.log('no settings file yet; skipping the value comparison');
    } else if (wantedRead.error) {
      failures.push(`${settings} is unreadable: ${wantedRead.error.message}`);
    } else if (ranAt < statSync(settings).mtimeMs) {
      // WidgetKit can be a minute behind a fresh edit, and that is not a
      // failure. It is also not proof of anything, so nothing is pushed.
      console.log('settings changed after the last timeline; skipping the value comparison');
    } else if (beat.skin !== wantedRead.value.skin) {
      failures.push(`widget read skin ${beat.skin}, settings say ${wantedRead.value.skin}`);
    } else {
      proofs.push(`the widget read skin=${beat.skin} ${ageMinutes.toFixed(0)} minutes ago`);
    }
  }
}

// chronod's own answer. An error result here is the failure mode that kept the
// widget blank for hours: the extension exited before answering.
// Filter inside `log show`, not afterwards. Unfiltered, half an hour of chronod
// is tens of megabytes and overran the buffer the moment the log got busy,
// which killed the gate with a Node stack trace instead of a verdict.
let log = '';
try {
  log = execFileSync('/usr/bin/log', [
    'show', '--last', '30m', '--info', '--debug',
    '--predicate',
    'process == "chronod" AND eventMessage CONTAINS "ImperatorClock.ClockWidget"',
    '--style', 'compact',
  ], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
} catch (error) {
  console.log(`could not read the chronod log: ${error.code ?? error.message}; skipping that half`);
}
const lines = log.split('\n').filter((l) => l.includes('getAllDescriptors'));
const lastResult = [...lines].reverse().find((l) => l.includes('result'));
if (!lastResult) {
  console.log('no getAllDescriptors in the last 30 minutes; skipping that half');
} else if (lastResult.includes('error result')) {
  failures.push(`chronod could not read the widget: ${lastResult.trim().slice(-120)}`);
} else {
  console.log('chronod getAllDescriptors: result');
  proofs.push('chronod answered the descriptor query');
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL ${f}`);
  process.exit(1);
}
if (proofs.length === 0) {
  // Nothing failed, but nothing was observed either. Say so instead of
  // claiming the widget is alive.
  console.log('G6_WIDGET_LIVE SKIPPED -- no evidence in this window; place the '
    + 'widget, then run ImperatorClock --widget-status to force a timeline');
  process.exit(0);
}
for (const proof of proofs) console.log(`proof: ${proof}`);
console.log('G6_WIDGET_LIVE_OK');
