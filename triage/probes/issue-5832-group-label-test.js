// Runs createGroupLabel from the master and the fixed RestoreController.js with a pinned "now"
const fs = require('fs');
const path = require('path');
const dir = process.argv[2];
const gettextCatalog = { getString: s => s };

function load(file) {
  const src = fs.readFileSync(path.join(dir, file), 'utf8');
  return (fixedNow) => {
    const RealDate = Date;
    class FakeDate extends RealDate {
      constructor(...args) { if (args.length === 0) super(fixedNow.getTime()); else super(...args); }
      static now() { return fixedNow.getTime(); }
    }
    return new Function('Date', 'gettextCatalog', src + '\nreturn createGroupLabel;')(FakeDate, gettextCatalog);
  };
}

const master = load('label-master.js');
const fixed = load('label-fixed.js');

// [today, version date, expected heading]
const cases = [
  ['2026-03-20', '2026-03-20', 'Today'],
  ['2026-03-20', '2026-03-19', 'Yesterday'],
  ['2026-03-20', '2026-03-14', 'This week'],
  ['2026-03-20', '2026-03-05', 'This month'],
  ['2026-03-20', '2026-02-25', 'Last month'],   // 23 days ago, in February
  ['2026-03-20', '2026-02-01', 'Last month'],
  ['2026-03-20', '2026-01-31', '2026'],
  ['2026-03-31', '2026-03-02', 'This month'],   // month end: 29 days ago, still in March
  ['2026-03-31', '2026-03-10', 'This month'],
  ['2026-05-31', '2026-05-05', 'This month'],
  ['2026-01-15', '2025-12-20', 'Last month'],   // across the year
  ['2026-01-15', '2025-11-30', '2025'],
  ['2026-03-03', '2026-02-26', 'This week'],    // the last 7 days reach into the previous month
];

const d = s => { const [y, m, dd] = s.split('-').map(Number); return new Date(y, m - 1, dd, 12, 0, 0); };
let failures = { master: 0, fixed: 0 };
for (const [now, at, expected] of cases) {
  const m = master(d(now))(d(at));
  const f = fixed(d(now))(d(at));
  if (m !== expected) failures.master++;
  if (f !== expected) failures.fixed++;
  console.log(`${now} / ${at}: expected ${expected.padEnd(10)} master ${m.padEnd(10)}${m === expected ? '' : ' X'}  fixed ${f}${f === expected ? '' : ' X'}`);
}
console.log(`failures: master ${failures.master}, fixed ${failures.fixed} of ${cases.length}`);
process.exit(failures.fixed ? 1 : 0);
