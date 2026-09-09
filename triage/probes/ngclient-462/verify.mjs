// Real-API check of deleting a job with the remote files of chosen destinations (ngclient#462).
// Usage: node verify.mjs <base-folder> [out-of-process]
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const base = process.argv[2];
const outOfProcess = process.argv[3] === 'out-of-process';
const api = 'http://127.0.0.1:8352/api/v1';
const password = fs.readFileSync(path.join(base, 'pw.txt'), 'utf8').trim();
const work = path.join(base, outOfProcess ? 'work-oop' : 'work');
const evidence = path.join(base, outOfProcess ? 'evidence-oop' : 'evidence');
fs.rmSync(work, { recursive: true, force: true });
fs.rmSync(evidence, { recursive: true, force: true });
fs.mkdirSync(work, { recursive: true });
fs.mkdirSync(evidence, { recursive: true });

const log = [];
function note(name, value) {
  log.push({ step: name, ...value });
  console.log(name, JSON.stringify(value));
}

let token;
async function call(method, url, body) {
  const res = await fetch(api + url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}

const login = await fetch(api + '/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ Password: password, RememberMe: false }) });
token = (await login.json()).AccessToken;

if (outOfProcess) {
  const r = await call('PATCH', '/serversettings', { 'use-out-of-process-controller': 'true' });
  note('enable-out-of-process', { status: r.status });
}

function hashFolder(folder) {
  if (!fs.existsSync(folder)) return null;
  const out = {};
  for (const f of fs.readdirSync(folder).sort())
    if (f.startsWith('duplicati-') && fs.statSync(path.join(folder, f)).isFile())
      out[f] = crypto.createHash('sha256').update(fs.readFileSync(path.join(folder, f))).digest('hex');
  return out;
}
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const url = folder => pathToFileURL(folder + path.sep).href;

async function waitTask(id) {
  for (let i = 0; i < 480; i++) {
    const r = await call('GET', `/task/${id}`);
    if (r.json.Status === 'Completed' || r.json.Status === 'Failed') return r.json;
    await new Promise(res => setTimeout(res, 250));
  }
  throw new Error('task timeout ' + id);
}

let jobNo = 0;
async function createJob(sync = false) {
  jobNo++;
  const dir = path.join(work, `job${jobNo}`);
  const folders = Object.fromEntries(['source', 'primary', 'first', 'second'].map(x => [x, path.join(dir, x)]));
  for (const f of Object.values(folders)) fs.mkdirSync(f, { recursive: true });
  fs.writeFileSync(path.join(folders.source, 'a.txt'), crypto.randomBytes(2000).toString('hex'));
  fs.writeFileSync(path.join(folders.source, 'b.txt'), 'second file ' + jobNo);
  const keys = { first: `job${jobNo}-first-${crypto.randomUUID()}`, second: `job${jobNo}-second-${crypto.randomUUID()}` };
  const body = {
    Backup: {
      Name: `delete-destinations job ${jobNo} ${crypto.randomUUID()}`, Description: '', OperationType: sync ? 'Sync' : 'Backup',
      TargetURL: url(folders.primary), Sources: [folders.source + path.sep],
      Settings: [{ Name: '--no-encryption', Value: 'true' }, { Name: 'snapshot-policy', Value: 'Off' }],
      Filters: [], Metadata: {},
      AdditionalTargetURLs: sync ? [] : [
        { UrlKey: keys.first, TargetUrl: url(folders.first), Mode: 'inline' },
        { UrlKey: keys.second, TargetUrl: url(folders.second), Mode: 'inline' },
      ],
    },
  };
  const created = await call('POST', '/backups', body);
  const id = created.json.ID;
  const run = await call('POST', `/backup/${id}/run`);
  const runState = await waitTask(run.json.ID);
  const job = await call('GET', `/backup/${id}`);
  const db = job.json.Backup.DBPath;
  const urlKeys = (job.json.Backup.AdditionalTargetURLs ?? []).map(x => x.UrlKey);
  return { id, folders, keys, db, runState: runState.Status, urlKeys };
}

function snapshot(job) {
  return Object.fromEntries(['primary', 'first', 'second'].map(x => [x, hashFolder(job.folders[x])]));
}

// 1. Only the chosen secondary destination loses its files
{
  const job = await createJob();
  const before = snapshot(job);
  note('1-created', { id: job.id, run: job.runState, urlKeys: job.urlKeys, files: Object.fromEntries(Object.entries(before).map(([k, v]) => [k, Object.keys(v).length])) });
  const del = await call('DELETE', `/backup/${job.id}?remote-destinations=${job.keys.first}`);
  note('1-delete-request', { status: del.status, body: del.json });
  const state = await waitTask(del.json.ID);
  const after = snapshot(job);
  const jobAfter = await call('GET', `/backup/${job.id}`);
  note('1-result', {
    task: state.Status, failed: state.FailedDestinations ?? null,
    firstLeft: Object.keys(after.first).length,
    primaryUnchanged: same(before.primary, after.primary), secondUnchanged: same(before.second, after.second),
    jobStatus: jobAfter.status, dbExists: fs.existsSync(job.db),
  });
  fs.writeFileSync(path.join(evidence, '1-hashes.json'), JSON.stringify({ before, after }, null, 2));
}

// 2. One chosen destination fails; job and database are kept; a second try goes through
{
  const job = await createJob();
  const before = snapshot(job);
  const away = job.folders.second + '-away';
  fs.renameSync(job.folders.second, away);
  const query = `remote-destinations=${job.keys.first},${job.keys.second}&delete-local-db=true`;
  const del = await call('DELETE', `/backup/${job.id}?${query}`);
  note('2-delete-request', { status: del.status, body: del.json });
  const state = await waitTask(del.json.ID);
  const mid = snapshot(job);
  const jobMid = await call('GET', `/backup/${job.id}`);
  note('2-failed-result', {
    task: state.Status, failed: state.FailedDestinations, error: state.ErrorMessage,
    secondKey: job.keys.second, firstLeft: Object.keys(mid.first).length,
    primaryUnchanged: same(before.primary, mid.primary), jobStatus: jobMid.status, dbExists: fs.existsSync(job.db),
  });
  fs.renameSync(away, job.folders.second);
  const del2 = await call('DELETE', `/backup/${job.id}?${query}`);
  note('2-retry-request', { status: del2.status, body: del2.json });
  const state2 = await waitTask(del2.json.ID);
  const after = snapshot(job);
  const jobAfter = await call('GET', `/backup/${job.id}`);
  note('2-retry-result', {
    task: state2.Status, failed: state2.FailedDestinations ?? null,
    firstLeft: Object.keys(after.first).length, secondLeft: Object.keys(after.second).length,
    primaryUnchanged: same(before.primary, after.primary), jobStatus: jobAfter.status, dbExists: fs.existsSync(job.db),
  });
  fs.writeFileSync(path.join(evidence, '2-hashes.json'), JSON.stringify({ before, mid, after }, null, 2));
}

// 3. The older parameter, refused choices and a sync job
{
  const job = await createJob();
  const before = snapshot(job);
  const refused = {};
  for (const [name, query] of Object.entries({
    empty: 'remote-destinations=',
    unknown: 'remote-destinations=no-such-key',
    conflict: `remote-destinations=${job.keys.first}&delete-remote-files=true`,
  })) {
    const r = await call('DELETE', `/backup/${job.id}?${query}`);
    refused[name] = { status: r.status, helpId: r.json.HelpId };
  }
  const other = await createJob();
  const r = await call('DELETE', `/backup/${job.id}?remote-destinations=${other.keys.first}`);
  refused.otherJobKey = { status: r.status, helpId: r.json.HelpId };
  note('3-refused', { refused, nothingDeleted: same(before, snapshot(job)), jobStatus: (await call('GET', `/backup/${job.id}`)).status });

  const legacy = await call('DELETE', `/backup/${job.id}?delete-remote-files=true&delete-local-db=false`);
  const legacyState = await waitTask(legacy.json.ID);
  const after = snapshot(job);
  note('3-older-parameter', {
    request: legacy.status, task: legacyState.Status,
    primaryLeft: Object.keys(after.primary).length,
    firstUnchanged: same(before.first, after.first), secondUnchanged: same(before.second, after.second),
  });

  const sync = await createJob(true);
  const s = await call('DELETE', `/backup/${sync.id}?remote-destinations=primary`);
  note('3-sync-job', { status: s.status, helpId: s.json.HelpId, run: sync.runState, jobStatus: (await call('GET', `/backup/${sync.id}`)).status });
}

// The API extension and the OpenAPI contract
{
  const info = await call('GET', '/systeminfo');
  note('extension', { listed: (info.json.APIExtensions ?? []).includes('v1:backup:delete-remote-destinations') });
  const swagger = await (await fetch('http://127.0.0.1:8352/swagger/v1/swagger.json')).json();
  fs.writeFileSync(path.join(evidence, 'swagger.json'), JSON.stringify(swagger, null, 2));
  const params = swagger.paths['/api/v1/backup/{id}'].delete.parameters.map(p => `${p.name}:${p.schema?.type}${p.schema?.items ? '<' + p.schema.items.type + '>' : ''}`);
  const taskState = Object.keys(swagger.components.schemas.GetTaskStateDto.properties);
  note('openapi', { deleteParameters: params, taskStateFields: taskState });
}

fs.writeFileSync(path.join(evidence, 'log.json'), JSON.stringify(log, null, 2));
