// API probe for the user info password and the export without passwords.
// usage: node probe2.mjs <baseUrl> <password> <datafolder> <sourceFolder> <outJson>
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

const [baseUrl, password, dataFolder, source, outFile] = process.argv.slice(2);
const target = 'ssh://fixture-user:fixture-secret@Example.COM:022/archive%2fpart?auth-password=p%2525&buffer-size=64MB&future=a+b&future=two&flag';
const secrets = ['fixture-secret', 'p%2525', 'p%25'];

let token;
async function call(method, url, body, raw = false) {
  const r = await fetch(baseUrl + url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${url} -> ${r.status} ${text}`);
  return raw ? text : text ? JSON.parse(text) : null;
}
function stored(id) {
  const db = new DatabaseSync(path.join(dataFolder, 'Duplicati-server.sqlite'), { readOnly: true });
  try { return db.prepare('SELECT TargetURL FROM Backup WHERE ID=?').get(Number(id)).TargetURL; } finally { db.close(); }
}

token = (await call('POST', '/api/v1/auth/login', { Password: password, RememberMe: false })).AccessToken;
const { ID: id } = await call('POST', '/api/v1/backups', {
  Backup: { Name: 'User info password', TargetURL: target, Sources: [source + path.sep], Settings: [{ Name: '--no-encryption', Value: 'true' }], Tags: [], Filters: [], Metadata: {} },
  Schedule: null,
});
const created = stored(id);
const got = await call('GET', `/api/v1/backup/${id}`);
const getTarget = got.Backup.TargetURL;
await call('PUT', `/api/v1/backup/${id}`, got);
const afterPut = stored(id);

const args = await call('GET', `/api/v1/backup/${id}/export-argsonly?export-passwords=false`, undefined, true);
const cmdline = await call('GET', `/api/v1/backup/${id}/export-cmdline?export-passwords=false`, undefined, true);

// The old UI moves user:password@ into its fields and writes them back to the query
const moved = getTarget.replace('fixture-user:***************@', '') + '&auth-username=fixture-user';
got.Backup.TargetURL = moved.replace('auth-password=***************', 'auth-password=***************');
await call('PUT', `/api/v1/backup/${id}`, got);
const afterMoved = stored(id);


const result = { id, created, getTarget, getHidesSecrets: !secrets.some((s) => getTarget.includes(s)), afterPut, afterPutEqualsCreated: afterPut === created, moved, afterMoved, exportArgs: args, exportArgsHidesSecrets: !secrets.some((s) => args.includes(s)), exportCmdline: cmdline, exportCmdlineHidesSecrets: !secrets.some((s) => cmdline.includes(s)) };
fs.writeFileSync(outFile, JSON.stringify(result, null, 2));
for (const [k, v] of Object.entries(result)) console.log(`${k.padEnd(26)}: ${typeof v === 'string' ? v.slice(0, 400) : v}`);
