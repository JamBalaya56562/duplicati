import http.server, sys, time
log = open(sys.argv[2], "a", encoding="utf-8")
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n)
        log.write(f"{time.strftime('%H:%M:%S')} POST {self.path} len={n} type={self.headers.get('Content-Type')}\n"); log.flush()
        open(sys.argv[2] + f".body{int(time.time()*1000)}", "wb").write(body)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    do_GET = do_POST
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
