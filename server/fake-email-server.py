"""Isolated Resend-shaped HTTP test double; never sends email."""
import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=5082)
args = parser.parse_args()
accepted = {}
attempts = {}
lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, value):
        data = json.dumps(value).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        with lock:
            self.reply(200, {'accepted': len(accepted), 'attempts': sum(attempts.values()),
                'valid_messages': all(item['valid'] for item in accepted.values())})

    def do_POST(self):
        if self.path != '/emails' or self.headers.get('Authorization') != 'Bearer test-key':
            self.reply(403, {'error': 'Invalid test configuration'})
            return
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            chunks = []
            while True:
                size = int(self.rfile.readline().split(b';', 1)[0].strip(), 16)
                if size == 0:
                    while self.rfile.readline().strip():
                        pass
                    break
                chunks.append(self.rfile.read(size))
                self.rfile.read(2)
            content = b''.join(chunks)
        else:
            content = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        body = json.loads(content)
        key = self.headers.get('Idempotency-Key', '')
        recipient = body['to'][0]
        with lock:
            attempts[key] = attempts.get(key, 0) + 1
            if recipient == 'b.tran@company.example' and attempts[key] == 1:
                self.reply(503, {'error': 'Simulated provider failure'})
                return
            if key in accepted:
                self.reply(200, {'id': accepted[key]['id']})
                return
            text = body.get('text', '')
            record = {'id': 'fake-' + key.split('/')[-1],
                'valid': key.startswith('welcome-employee/') and recipient in text and '12345678' in text
                and 'Đổi mật khẩu' in text and 'khuôn mặt' in text}
            accepted[key] = record
            self.reply(200, {'id': record['id']})

ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
