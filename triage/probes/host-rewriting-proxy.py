# A reverse proxy that does not pass the Host header on, like Apache ProxyPass without
# ProxyPreserveHost: the backend sees Host: 127.0.0.1:<backend port>.
# Usage: python host-rewriting-proxy.py <listen port> <backend port>
import http.client
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN = int(sys.argv[1])
BACKEND = int(sys.argv[2])
HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade", "host", "content-length"}


class Proxy(BaseHTTPRequestHandler):
    def _forward(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
        headers["Host"] = f"127.0.0.1:{BACKEND}"
        conn = http.client.HTTPConnection("127.0.0.1", BACKEND, timeout=60)
        conn.request(self.command, self.path, body=body, headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        self.send_response(resp.status, resp.reason)
        for k, v in resp.getheaders():
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        conn.close()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = _forward

    def log_message(self, fmt, *args):
        sys.stderr.write("PROXY " + (fmt % args) + "\n")


ThreadingHTTPServer(("127.0.0.1", LISTEN), Proxy).serve_forever()
