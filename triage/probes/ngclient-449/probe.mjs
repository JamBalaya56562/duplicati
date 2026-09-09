// Usage: node probe.mjs <server exe> <data dir> <remote folder> <restore folder or ""> <label> [list-before-restore: true|false]
// Starts an isolated Duplicati server on 127.0.0.1:8399, creates a temporary job for the remote folder as the
// UI does for a direct restore, lists the folders, optionally restores Documents, and stops the server again.
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';

const [exe, dataDir, remote, restoreTo, label, listFirstArg] = process.argv.slice(2);
const listFirst = listFirstArg !== 'false';
const port = 8399;
const base = `http://127.0.0.1:${port}`;
const here = path.dirname(new URL(import.meta.url).pathname).replace(/^\/([A-Za-z]:)/, '$1');
const password = (await fs.readFile(path.join(here, 'pw.txt'), 'utf8')).trim();
const out = [];
const log = (k, v) => { const line = `${k} ${typeof v === 'string' ? v : JSON.stringify(v)}`; out.push(line); console.log(line); };

const server = spawn(exe, [
  `--server-datafolder=${dataDir}`, `--webservice-port=${port}`, '--webservice-interface=loopback',
  `--webservice-password=${password}`, '--disable-update-check=true', '--disable-db-encryption=true',
  `--log-file=${path.join(here, `server-${label}.log`)}`, '--log-level=Information'
], { env: { ...process.env, DOTNET_ROOT: 'C:\\Users\\Jam\\AppData\\Local\\mise\\dotnet-root' }, stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
try {
  for (let i = 0; i < 120; i++) { try { await fetch(base + '/'); break; } catch { await sleep(1000); } }
  const login = await (await fetch(base + '/api/v1/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ Password: password }) })).json();
  const auth = { Authorization: `Bearer ${login.AccessToken}`, 'Content-Type': 'application/json' };
  const call = async (method, url, body) => {
    const r = await fetch(base + url, { method, headers: auth, body: body === undefined ? undefined : JSON.stringify(body) });
    const text = await r.text();
    let json = null; try { json = JSON.parse(text); } catch { }
    return { status: r.status, json, text };
  };

  const target = 'file://' + remote;
  const created = await call('POST', '/api/v1/backups?temporary=true', { Backup: { TargetURL: target, Settings: [{ Name: '--no-encryption', Value: 'true' }] } });
  const id = created.json?.ID;
  log('temporary-job', { status: created.status, id });

  let time = null;
  if (listFirst) {
    let sets;
    for (let i = 0; i < 60; i++) {
      sets = await call('POST', '/api/v2/backup/list-filesets', { BackupId: id });
      if (sets.json?.Success && sets.json.Data?.length) break;
      await sleep(1000);
    }
    log('list-filesets', { status: sets.status, success: sets.json?.Success, count: sets.json?.Data?.length, error: sets.json?.Error });
    time = sets.json?.Data?.[0]?.Time;
    // The select-files page of ngclient rebuilds the paths of the temporary job's database first
    const repair = await call('POST', `/api/v1/backup/${id}/repairupdate`, { only_paths: true, time });
    let repairState;
    for (let i = 0; i < 120; i++) {
      repairState = await call('GET', `/api/v1/task/${repair.json?.ID}`);
      if (['Failed', 'Completed'].includes(repairState.json?.Status)) break;
      await sleep(1000);
    }
    log('repairupdate', { status: repair.status, task: repairState.json?.Status, error: repairState.json?.ErrorMessage });
    const listing = { BackupId: id, Time: time, PageSize: 0, Page: 0, ReturnExtended: true };
    const roots = await call('POST', '/api/v2/backup/list-folder', { ...listing, Paths: null });
    log('roots', { status: roots.status, success: roots.json?.Success, error: roots.json?.Error, data: roots.json?.Data?.map((x) => ({ Path: x.Path, IsDirectory: x.IsDirectory })) });
    const root = roots.json?.Data?.[0]?.Path;
    const children = await call('POST', '/api/v2/backup/list-folder', { ...listing, Paths: [root] });
    log('children', { request: root, status: children.status, success: children.json?.Success, error: children.json?.Error, data: children.json?.Data?.map((x) => ({ Path: x.Path, IsDirectory: x.IsDirectory })) });
    const docs = children.json?.Data?.find((x) => x.IsDirectory && /Documents[\\/]?$/.test(x.Path));
    if (docs) {
      const nested = await call('POST', '/api/v2/backup/list-folder', { ...listing, Paths: [docs.Path] });
      log('documents', { request: docs.Path, status: nested.status, data: nested.json?.Data?.map((x) => ({ Path: x.Path, IsDirectory: x.IsDirectory })) });
    }
  }

  if (restoreTo) {
    const docsPath = process.env.DOCS_PATH;
    let restoreId = id;
    if (process.env.COPY_TO_TEMP === '1') {
      // ngclient restores a temporary job through a fresh copy that has no database yet
      const copy = await call('POST', `/api/v1/backup/${id}/copytotemp`);
      restoreId = copy.json?.ID;
      log('copytotemp', { status: copy.status, id: restoreId });
    }
    const body = { paths: [docsPath], restore_path: restoreTo, overwrite: true, permissions: false };
    if (time) body.time = time;
    log('restore-request', { id: restoreId, body });
    const started = await call('POST', `/api/v1/backup/${restoreId}/restore`, body);
    log('restore-start', { status: started.status, body: started.text.slice(0, 300) });
    const taskId = started.json?.ID;
    let state;
    for (let i = 0; i < 120; i++) {
      state = await call('GET', `/api/v1/task/${taskId}`);
      if (['Failed', 'Completed'].includes(state.json?.Status)) break;
      await sleep(1000);
    }
    log('restore-task', { status: state.json?.Status, error: state.json?.ErrorMessage });
    const files = [];
    const walk = async (d) => { for (const e of await fs.readdir(d, { withFileTypes: true }).catch(() => [])) { const p = path.join(d, e.name); if (e.isDirectory()) await walk(p); else files.push({ p: path.relative(restoreTo, p), content: await fs.readFile(p, 'utf8') }); } };
    await walk(restoreTo);
    log('restored-files', files);
  }
} finally {
  server.kill();
  await sleep(2000);
  try { server.kill('SIGKILL'); } catch { }
  await fs.writeFile(path.join(here, `result-${label}.txt`), out.join('\n') + '\n');
}
