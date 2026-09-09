const fs = require('fs');
const p = process.argv[2];
let t = fs.readFileSync(p, 'utf8');
const rep = (a, b, n) => { const c = t.split(a).length - 1; if (c !== n) throw new Error(c + ' matches for ' + a); t = t.split(a).join(b); };
rep('private static readonly TimeSpan LongGrace = TimeSpan.FromSeconds(1);',
    'private static readonly TimeSpan LongGrace = Environment.GetEnvironmentVariable("PROBE_OLD_GRACE") == "1" ? TimeSpan.FromMilliseconds(50) : TimeSpan.FromSeconds(1);', 1);
rep('await Task.Delay(LongGrace / 4);',
    'await Task.Delay(LongGrace / 4 + TimeSpan.FromMilliseconds(int.Parse(Environment.GetEnvironmentVariable("PROBE_LATE_MS") ?? "0")));', 3);
rep('        if (Directory.Exists(BASEFOLDER))\n            foreach (var file in Directory.EnumerateFiles(BASEFOLDER, "duplicati-changes-*.txt"))',
    '        if (Environment.GetEnvironmentVariable("PROBE_NO_TEARDOWN") == "1")\n            return;\n        if (Directory.Exists(BASEFOLDER))\n            foreach (var file in Directory.EnumerateFiles(BASEFOLDER, "duplicati-changes-*.txt"))', 1);
fs.writeFileSync(p, t);
console.log('probe ok');
