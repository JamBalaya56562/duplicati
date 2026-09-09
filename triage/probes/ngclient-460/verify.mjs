// Real-API check of restoring from a secondary destination of a saved job (ngclient#460).
// Usage: node verify460.mjs <base-folder>
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const base = process.argv[2];
const api = 'http://127.0.0.1:8352/api';
const password = fs.readFileSync(path.join(base, 'pw.txt'), 'utf8').trim();
const work = path.join(base, 'work460');
const evidence = path.join(base, 'evidence460');
fs.rmSync(work, { recursive: true, force: true });
fs.rmSync(evidence, { recursive: true, force: true });
fs.mkdirSync(evidence, { recursive: true });
const log = [];
const note = (step, value) => { log.push({ step, ...value }); console.log(step, JSON.stringify(value)); };

let token;
async function call(method, url, body) {
  const res = await fetch(api + url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json, text };
}
token = (await (await fetch(api + '/v1/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ Password: password, RememberMe: false }) })).json()).AccessToken;

async function waitTask(id) {
  for (let i = 0; i < 480; i++) {
    const r = await call('GET', `/v1/task/${id}`);
    if (r.json.Status === 'Completed' || r.json.Status === 'Failed') return r.json;
    await new Promise(res => setTimeout(res, 250));
  }
  throw new Error('task timeout ' + id);
}
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const dlists = folder => fs.readdirSync(folder).filter(x => x.includes('.dlist.')).sort();
const url = folder => pathToFileURL(folder + path.sep).href;
const copyFolder = (from, to) => { fs.mkdirSync(to, { recursive: true }); for (const f of fs.readdirSync(from)) fs.copyFileSync(path.join(from, f), path.join(to, f)); };
async function filesetTimes(id) {
  const r = await call('POST', '/v2/backup/list-filesets', { BackupId: id });
  return { status: r.status, success: r.json?.Success, times: (r.json?.Data ?? []).map(x => new Date(x.Time).toISOString()), error: r.json?.Error ?? r.json?.ErrorMessage, helpId: r.json?.HelpId ?? r.json?.StatusCode, raw: r.json?.Success ? undefined : r.text.slice(0, 300) };
}

const folders = Object.fromEntries(['source', 'primary', 'secondary', 'restore'].map(x => [x, path.join(work, x)]));
for (const f of Object.values(folders)) fs.mkdirSync(f, { recursive: true });
const sample = path.join(folders.source, 'sample.bin');
const older = crypto.randomBytes(50000);
const newer = crypto.randomBytes(50000);
const key = 'secondary-' + crypto.randomUUID();

// 1. The older version on both destinations, the newer version on the main destination only
fs.writeFileSync(sample, older);
const created = await call('POST', '/v1/backups', {
  Backup: {
    Name: 'restore-from-secondary ' + crypto.randomUUID(), Description: '', TargetURL: url(folders.primary), Sources: [folders.source + path.sep],
    Settings: [{ Name: 'passphrase', Value: 'verify-460-passphrase' }, { Name: 'snapshot-policy', Value: 'Off' }],
    Filters: [], Metadata: {},
    AdditionalTargetURLs: [{ UrlKey: key, TargetUrl: url(folders.secondary), Mode: 'inline' }],
  },
});
const id = created.json.ID;
note('1-run-older', { task: (await waitTask((await call('POST', `/v1/backup/${id}/run`)).json.ID)).Status });
const lagging = folders.secondary + '-after-first';
copyFolder(folders.secondary, lagging);
await new Promise(res => setTimeout(res, 1500));
fs.writeFileSync(sample, newer);
note('1-run-newer', { task: (await waitTask((await call('POST', `/v1/backup/${id}/run`)).json.ID)).Status });
fs.rmSync(folders.secondary, { recursive: true });
fs.renameSync(lagging, folders.secondary);
const jobTimes = await filesetTimes(id);
note('1-destinations', { primaryDlists: dlists(folders.primary), secondaryDlists: dlists(folders.secondary), jobVersions: jobTimes.times, sha256Older: crypto.createHash('sha256').update(older).digest('hex'), sha256Newer: crypto.createHash('sha256').update(newer).digest('hex') });

const jobBefore = (await call('GET', `/v1/backup/${id}`)).text;
const dbPath = (await call('GET', `/v1/backup/${id}`)).json.Backup.DBPath;
const dbBefore = sha(dbPath);

// 2. The main destination is unavailable; the new API names the secondary destination
fs.renameSync(folders.primary, folders.primary + '-away');
const copy = await call('POST', `/v1/backup/${id}/copytotemp?destination=${encodeURIComponent(key)}`);
const tempId = copy.json.ID;
const temp = await call('GET', `/v1/backup/${tempId}`);
const tempTimes = await filesetTimes(tempId);
note('2-temporary-job', {
  copy: { status: copy.status, body: copy.json }, targetIsSecondary: temp.json.Backup.TargetURL.includes('secondary'),
  ownDatabase: temp.json.Backup.DBPath !== dbPath, additionalTargets: temp.json.Backup.AdditionalTargetURLs?.length ?? 0,
  versions: tempTimes.times, onlyOlder: JSON.stringify(tempTimes.times) === JSON.stringify([jobTimes.times[1]]),
});
const repair = await call('POST', `/v1/backup/${tempId}/repairupdate`, { only_paths: true, time: tempTimes.times[0] });
note('2-repairupdate', { task: (await waitTask(repair.json.ID)).Status });
const listed = await call('POST', '/v2/backup/list-folder', { BackupId: tempId, Paths: [folders.source + path.sep], Time: tempTimes.times[0], PageSize: 1000, Page: 0 });
note('2-list-folder', { status: listed.status, paths: (listed.json.Data ?? []).map(x => path.basename(x.Path)), size: (listed.json.Data ?? []).map(x => x.Size) });

// 3. Restore from a fresh copy, as the restore page does, and compare the bytes
const restoreCopy = await call('POST', `/v1/backup/${tempId}/copytotemp`);
const restore = await call('POST', `/v1/backup/${restoreCopy.json.ID}/restore`, { paths: [sample], time: tempTimes.times[0], restore_path: folders.restore, overwrite: true, permissions: false, skip_metadata: false });
const restoreState = await waitTask(restore.json.ID);
const restored = path.join(folders.restore, 'sample.bin');
note('3-restore', {
  request: restore.status, task: restoreState.Status, error: restoreState.ErrorMessage ?? null,
  matchesOlder: fs.existsSync(restored) && sha(restored) === crypto.createHash('sha256').update(older).digest('hex'),
  matchesNewer: fs.existsSync(restored) && sha(restored) === crypto.createHash('sha256').update(newer).digest('hex'),
  jobUnchanged: (await call('GET', `/v1/backup/${id}`)).text === jobBefore, dbUnchanged: sha(dbPath) === dbBefore,
});
const tempDbs = [temp.json.Backup.DBPath, (await call('GET', `/v1/backup/${restoreCopy.json.ID}`)).json.Backup.DBPath];
for (const t of [tempId, restoreCopy.json.ID]) {
  const d = await call('DELETE', `/v1/backup/${t}?delete-local-db=true`);
  await waitTask(d.json.ID);
}
const temporaries = (await call('GET', '/v1/backups/temporary')).json.map(x => x.ID);
note('3-cleanup', { temporaryJobsLeft: temporaries.filter(x => x === tempId || x === restoreCopy.json.ID).length, temporaryDatabasesLeft: tempDbs.filter(x => fs.existsSync(x)).length });

// 4. Refused keys, and a secondary destination that is unavailable
const refused = {};
for (const [name, k] of Object.entries({ unknown: 'no-such-key', empty: '', primaryWord: 'primary' })) {
  const r = await call('POST', `/v1/backup/${id}/copytotemp?destination=${encodeURIComponent(k)}`);
  refused[name] = { status: r.status, helpId: r.json.HelpId };
}
note('4-refused', { refused, temporaryJobs: (await call('GET', '/v1/backups/temporary')).json.length });
fs.renameSync(folders.primary + '-away', folders.primary);
fs.renameSync(folders.secondary, folders.secondary + '-away');
const down = await call('POST', `/v1/backup/${id}/copytotemp?destination=${encodeURIComponent(key)}`);
const downTimes = await filesetTimes(down.json.ID);
note('4-secondary-unavailable', { copy: down.status, listing: downTimes, mainDestinationIsBack: fs.existsSync(folders.primary) });
const d = await call('DELETE', `/v1/backup/${down.json.ID}?delete-local-db=true`);
await waitTask(d.json.ID);
note('4-cleanup', { temporaryJobsLeft: (await call('GET', '/v1/backups/temporary')).json.filter(x => x.ID === down.json.ID).length });
fs.renameSync(folders.secondary + '-away', folders.secondary);

// The API extension and the OpenAPI contract
const info = await call('GET', '/v1/systeminfo');
const swagger = await (await fetch('http://127.0.0.1:8352/swagger/v1/swagger.json')).json();
const op = swagger.paths['/api/v1/backup/{id}/copytotemp'].post;
fs.writeFileSync(path.join(evidence, 'openapi-excerpt.json'), JSON.stringify({ copytotemp: op }, null, 2));
note('contract', { extension: (info.json.APIExtensions ?? []).includes('v1:backup:copytotemp-destination'), parameters: op.parameters.map(p => `${p.name}:${p.in}:${p.schema?.type}`) });
fs.writeFileSync(path.join(evidence, 'log.json'), JSON.stringify(log, null, 2));
