// Gate G4: the digits stand upright. The reference LED faces lean; Goran asked
// for straight numerals, so no shear or rotation may reach the glyph geometry.
import { readFileSync, readdirSync } from 'node:fs';

const dir = new URL('../Sources/ClockCore/', import.meta.url);
const banned = [
  /rotationEffect/,
  /rotation3DEffect/,
  /\.rotated\(/,
  /CGAffineTransform\s*\(\s*rotationAngle/,
  /shear/i,
  /skew/i,
  /oblique/i,
  /italic/i,
  /transform\s*=\s*CGAffineTransform/
];

const hits = [];
for (const name of readdirSync(dir)) {
  if (!name.endsWith('.swift')) continue;
  const lines = readFileSync(new URL(name, dir), 'utf8').split('\n');
  lines.forEach((line, index) => {
    // A comment may name the thing it is refusing to do.
    if (/^\s*(\/\/|\/\*|\*)/.test(line)) return;
    for (const pattern of banned) {
      if (pattern.test(line)) hits.push(`${name}:${index + 1}: ${line.trim()}`);
    }
  });
}

if (hits.length) {
  console.error('FAIL glyph geometry carries a slant or rotation:');
  for (const hit of hits) console.error(`  ${hit}`);
  process.exit(1);
}
console.log('G4_UPRIGHT_OK');
