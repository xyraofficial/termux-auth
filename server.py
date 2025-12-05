#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 5000
HOST = "0.0.0.0"

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Disable caching to ensure updates are visible
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def log_message(self, format, *args):
        # Simple logging
        print(f"{self.address_string()} - {format % args}")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    with socketserver.TCPServer((HOST, PORT), MyHTTPRequestHandler) as httpd:
        print(f"Server running at http://{HOST}:{PORT}/")
        print("Serving files from current directory")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped")
