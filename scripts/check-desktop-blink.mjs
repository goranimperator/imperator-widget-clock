// Gate G7: the desktop clock really animates.
//
// It sits at desktop-icon level, under every window, so a full-screen grab
// would photograph whatever is on top of it. The window is captured by id
// instead, which reaches an occluded window.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// fileURLToPath, not URL.pathname: the latter stays percent-encoded, so a repo
// checked out to a path with a space would hand swift a file name with %20.
const helper = fileURLToPath(new URL('window-id.swift', import.meta.url));
// The desktop clock is an opt-in, so its absence is a skip, not a failure. The
// helper exits non-zero when there is no window, which makes execFileSync throw
// before any check on its output can run.
let list;
try {
  list = execFileSync('swift', [helper], { encoding: 'utf8' }).trim();
} catch {
  console.log('G7 SKIPPED -- the desktop clock is off; enable it in the menu bar app');
  process.exit(0);
}
const match = list.match(/id=(\d+)/);
if (!match) {
  console.log('G7 SKIPPED -- the desktop clock is off; enable it in the menu bar app');
  process.exit(0);
}
console.log(list);

const dir = mkdtempSync(join(tmpdir(), 'clockblink-'));
const hashes = [];
for (let i = 0; i < 8; i += 1) {
  const file = join(dir, `f${i}.png`);
  execFileSync('screencapture', ['-x', '-o', `-l${match[1]}`, '-t', 'png', file]);
  hashes.push(createHash('sha256').update(readFileSync(file)).digest('hex').slice(0, 8));
  execFileSync('sleep', ['0.25']);
}
const unique = new Set(hashes).size;
console.log(`frames=${hashes.join(' ')} unique=${unique}`);
if (unique < 4) {
  console.error(`FAIL only ${unique} distinct frames in two seconds; the clock is static`);
  process.exit(1);
}
console.log('G7_DESKTOP_BLINK_OK');
