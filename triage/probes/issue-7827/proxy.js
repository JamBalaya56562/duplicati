// Stands in for DSM's nginx: /duplicati/ is proxied to the server with the PreAuth header,
// the forwarded prefix and the DSM session cookie a logged-in browser would send.
// Every request is logged with whether it carried X-Syno-Token or SynoToken, and its status.
const http = require('http');
const net = require('net');
const fs = require('fs');
const path = require('path');

const LISTEN = 8311, TARGET = 8211, PREAUTH = 'prekey-1234567890';
const log = path.join(__dirname, 'proxy.log');
const W = (s) => fs.appendFileSync(log, new Date().toISOString().slice(11, 23) + ' ' + s + '\n');

function rewrite(req) {
  const headers = { ...req.headers };
  headers['authorization'] = 'PreAuth ' + PREAUTH;
  headers['x-forwarded-prefix'] = '/duplicati';
  headers['x-real-ip'] = '127.0.0.1';
  headers['x-forwarded-proto'] = 'http';
  if (!/(^|;\s*)id=/.test(headers['cookie'] || ''))
    headers['cookie'] = (headers['cookie'] ? headers['cookie'] + '; ' : '') + 'id=fakedsmsession';
  return headers;
}

const server = http.createServer((req, res) => {
  if (!req.url.startsWith('/duplicati/')) { res.writeHead(404); res.end('not proxied'); return; }
  const url = req.url.substring('/duplicati'.length);
  const hasHeader = !!req.headers['x-syno-token'];
  const hasQuery = /[?&]SynoToken=/.test(url);
  const p = http.request({ host: '127.0.0.1', port: TARGET, method: req.method, path: url, headers: rewrite(req) }, (r) => {
    W(`${r.statusCode} ${req.method} ${url.split('?')[0]} header=${hasHeader} query=${hasQuery}`);
    res.writeHead(r.statusCode, r.headers);
    r.pipe(res);
  });
  p.on('error', (e) => { W(`ERR ${req.method} ${url} ${e.message}`); res.writeHead(502); res.end(); });
  req.pipe(p);
});

server.on('upgrade', (req, socket, head) => {
  const url = req.url.substring('/duplicati'.length);
  const headers = rewrite(req);
  const up = net.connect(TARGET, '127.0.0.1', () => {
    let s = `${req.method} ${url} HTTP/1.1\r\n`;
    for (const [k, v] of Object.entries(headers)) s += `${k}: ${v}\r\n`;
    up.write(s + '\r\n');
    up.write(head);
    socket.pipe(up).pipe(socket);
  });
  W(`WS ${url.split('?')[0]} header=${!!req.headers['x-syno-token']} query=${/[?&]SynoToken=/.test(url)}`);
  up.on('error', () => socket.destroy());
});

server.listen(LISTEN, '127.0.0.1', () => W(`listening on ${LISTEN}`));
