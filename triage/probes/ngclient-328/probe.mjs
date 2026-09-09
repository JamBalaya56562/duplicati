// API-only probe for ngclient#328: create a job, GET it, PUT it unchanged, compare the stored TargetURL.
// usage: node probe.mjs <baseUrl> <password> <datafolder> <sourceFolder> <outJson>
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

const [baseUrl, password, dataFolder, source, outFile] = process.argv.slice(2);
const cases = [
  ['report', 'ssh://fixture-user:fixture-secret@Example.COM:022/archive%2fpart?auth-password=p%2525&buffer-size=64MB&web-timeout=2m&future=a+b&future=two&flag'],
  ['edge', 'ftp://Example.COM/a%2Fb%20c?auth-username=u&empty=&plus=a+b&space=a%20b&double=%2520&auth-password=x%26y%3D&flag&dup=1&dup=2'],
  ['no-secret', 'ssh://Example.COM:022/archive%2fpart?future=a+b&future=two&flag'],
];

let token;
async function call(method, url, body) {
  const r = await fetch(baseUrl + url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${url} -> ${r.status} ${text}`);
  return text ? JSON.parse(text) : null;
}
function stored(id) {
  const db = new DatabaseSync(path.join(dataFolder, 'Duplicati-server.sqlite'), { readOnly: true });
  try { return db.prepare('SELECT TargetURL FROM Backup WHERE ID=?').get(Number(id)).TargetURL; } finally { db.close(); }
}

token = (await call('POST', '/api/v1/auth/login', { Password: password, RememberMe: false })).AccessToken;
const results = [];
for (const [name, target] of cases) {
  const { ID: id } = await call('POST', '/api/v1/backups', {
    Backup: { Name: `URL preservation ${name}`, TargetURL: target, Sources: [source + path.sep], Settings: [{ Name: '--no-encryption', Value: 'true' }], Tags: [], Filters: [], Metadata: {} },
    Schedule: null,
  });
  const created = stored(id);
  const got = await call('GET', `/api/v1/backup/${id}`);
  const getTarget = got.Backup.TargetURL;
  await call('PUT', `/api/v1/backup/${id}`, got);
  const afterPut = stored(id);
  const getAgain = (await call('GET', `/api/v1/backup/${id}`)).Backup.TargetURL;

  // An explicit change: replace the masked password and one other value in the GET URL.
  const edited = getTarget.replace(/(auth-password=)[^&]*/i, '$1changed%2Bpw').replace('buffer-size=64MB', 'buffer-size=32MB');
  let afterEdit = null;
  if (edited !== getTarget) {
    got.Backup.TargetURL = edited;
    await call('PUT', `/api/v1/backup/${id}`, got);
    afterEdit = stored(id);
  }
  results.push({ name, id, submitted: target, created, createdEqualsSubmitted: created === target, getTarget, getHidesSecret: !/p%2525|x%26y%3D/.test(getTarget), afterPut, afterPutEqualsCreated: afterPut === created, getAgain, getStable: getAgain === getTarget, edited, afterEdit });
}
fs.writeFileSync(outFile, JSON.stringify(results, null, 2));
for (const r of results) {
  console.log(`== ${r.name} (id ${r.id})`);
  console.log(`created     : ${r.created}`);
  console.log(`GET         : ${r.getTarget}`);
  console.log(`after PUT   : ${r.afterPut}`);
  console.log(`unchanged   : ${r.afterPutEqualsCreated}   GET hides secret: ${r.getHidesSecret}   GET stable: ${r.getStable}`);
  if (r.afterEdit) { console.log(`edited PUT  : ${r.edited}`); console.log(`after edit  : ${r.afterEdit}`); }
}
