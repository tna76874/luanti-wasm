from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Wichtig für SharedArrayBuffer / crossOriginIsolated
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if __name__ == "__main__":
    import os
    port = 8000
    print("Serving on http://localhost:%d" % port)
    ThreadingHTTPServer(("", port), Handler).serve_forever()
