"""Local SMTP test double with auth, temporary failures and ambiguous delivery. Never forwards mail."""
import argparse
import base64
import email
from email import policy
import json
import socketserver
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, required=True)
parser.add_argument('--smtp-port', type=int, required=True)
args = parser.parse_args()
lock = threading.Lock()
accepted = {}
attempts = {}

class SmtpHandler(socketserver.StreamRequestHandler):
    def reply(self, value):
        self.wfile.write((value + '\r\n').encode('ascii'))
        self.wfile.flush()

    def handle(self):
        self.reply('220 localhost SMTP test server')
        authenticated = False
        recipient = ''
        while True:
            line = self.rfile.readline()
            if not line:
                return
            command = line.decode('utf-8', 'replace').strip()
            verb = command.split(' ', 1)[0].upper()
            if verb in ('EHLO', 'HELO'):
                self.reply('250-localhost\r\n250-AUTH PLAIN\r\n250 8BITMIME')
            elif verb == 'AUTH':
                parts = command.split()
                if len(parts) < 3:
                    self.reply('334 ')
                    parts.append(self.rfile.readline().decode().strip())
                credentials = base64.b64decode(parts[-1]).split(b'\0')
                authenticated = credentials[-2:] == [b'company@company.example', b'test-app-password']
                self.reply('235 2.7.0 Authenticated' if authenticated else '535 5.7.8 Invalid credentials')
            elif verb == 'MAIL':
                self.reply('250 2.1.0 OK' if authenticated else '530 Authentication required')
            elif verb == 'RCPT':
                recipient = command.split('<', 1)[-1].split('>', 1)[0]
                self.reply('250 2.1.5 OK')
            elif verb == 'DATA':
                self.reply('354 End with dot')
                chunks = []
                while True:
                    chunk = self.rfile.readline()
                    if not chunk or chunk in (b'.\r\n', b'.\n'):
                        break
                    chunks.append(chunk[1:] if chunk.startswith(b'..') else chunk)
                message = email.message_from_bytes(b''.join(chunks), policy=policy.default)
                key = message['Message-Id']
                text = message.get_body(preferencelist=('plain',)).get_content()
                welcome = 'Mật khẩu ban đầu' in text
                with lock:
                    attempts[key] = attempts.get(key, 0) + 1
                    if welcome and recipient == 'b.tran@company.example' and attempts[key] == 1:
                        self.reply('451 4.3.0 Temporary failure')
                        continue
                    accepted[key] = {'welcome': welcome, 'recipient': recipient,
                        'valid': not welcome or (recipient in text and '12345678' in text
                            and 'Đổi mật khẩu' in text and 'khuôn mặt' in text)}
                    if (welcome and recipient == 'd.pham@company.example') or (not welcome and recipient == 'c.le@company.example'):
                        return  # Mail accepted but connection lost before final 250.
                self.reply('250 2.0.0 Accepted')
            elif verb == 'QUIT':
                self.reply('221 Bye')
                return
            elif verb in ('RSET', 'NOOP'):
                self.reply('250 OK')
            else:
                self.reply('502 Command not implemented')

class StatsHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        with lock:
            data = json.dumps({'accepted': len(accepted),
                'accepted_welcome': sum(m['welcome'] for m in accepted.values()),
                'valid_messages': all(m['valid'] for m in accepted.values()),
                'uncertain_attempts': sum(attempts[k] for k, m in accepted.items() if m['recipient'] == 'd.pham@company.example')}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

smtp = socketserver.ThreadingTCPServer(('127.0.0.1', args.smtp_port), SmtpHandler)
smtp.daemon_threads = True
threading.Thread(target=smtp.serve_forever, daemon=True).start()
ThreadingHTTPServer(('127.0.0.1', args.port), StatsHandler).serve_forever()
