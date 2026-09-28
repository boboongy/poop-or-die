"""Stage 8 web smoke test: the exported build (build/web) in headless Chrome, driven over the DevTools protocol with the standard library
only (no playwright / websocket packages). Real time: waits for the game to boot, clicks into it, presses E through the start dialogue,
screenshots each level (F4 = next level) and prints every console line (Godot's errors and warnings reach the browser console) and the
FPS label's text from the screenshot is NOT parsed: read the images.

Run from the project folder (it serves build/web itself):
  python tools/web_smoke.py <out_dir> [wait_seconds=60]
"""
import base64
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time
import urllib.request
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
HTTP_PORT = 8766
DEBUG_PORT = 9333


class WS:
	"""A minimal WebSocket client (RFC 6455, text frames, client masking) for the DevTools socket."""

	def __init__(self, url):
		host_port, path = url[len("ws://"):].split("/", 1)
		host, port = host_port.split(":")
		self.s = socket.create_connection((host, int(port)))
		key = base64.b64encode(os.urandom(16)).decode()
		self.s.sendall(("GET /%s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
			"Sec-WebSocket-Version: 13\r\n\r\n" % (path, host_port, key)).encode())
		resp = b""
		while b"\r\n\r\n" not in resp:
			resp += self.s.recv(1)
		self.buf = b""
		self.id = 0
		self.events = []

	def send(self, method, params=None):
		self.id += 1
		data = json.dumps({"id": self.id, "method": method, "params": params or {}}).encode()
		mask = os.urandom(4)
		head = bytes([0x81])
		n = len(data)
		if n < 126:
			head += bytes([0x80 | n])
		elif n < 65536:
			head += bytes([0x80 | 126]) + struct.pack(">H", n)
		else:
			head += bytes([0x80 | 127]) + struct.pack(">Q", n)
		self.s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
		want = self.id
		while True:
			msg = self.recv()
			if msg.get("id") == want:
				return msg.get("result", msg.get("error"))
			self.events.append(msg)

	def _read(self, n):
		while len(self.buf) < n:
			chunk = self.s.recv(1 << 20)
			if not chunk:
				raise ConnectionError("closed")
			self.buf += chunk
		out, self.buf = self.buf[:n], self.buf[n:]
		return out

	def recv(self):
		payload = b""
		while True:
			b0, b1 = self._read(2)
			n = b1 & 0x7F
			if n == 126:
				n = struct.unpack(">H", self._read(2))[0]
			elif n == 127:
				n = struct.unpack(">Q", self._read(8))[0]
			payload += self._read(n)
			if b0 & 0x80:
				return json.loads(payload.decode("utf-8", "replace"))

	def pump(self, seconds):
		"""Collect events for `seconds` of real time."""
		self.s.settimeout(0.2)
		end = time.time() + seconds
		while time.time() < end:
			try:
				self.events.append(self.recv())
			except (socket.timeout, TimeoutError):
				pass
		self.s.settimeout(None)


def key(ws, code, vk, text=""):
	for t in ("keyDown", "keyUp"):
		ws.send("Input.dispatchKeyEvent", {"type": t, "code": code, "key": text or code, "windowsVirtualKeyCode": vk, "nativeVirtualKeyCode": vk})
		time.sleep(0.08)


def shot(ws, path):
	data = ws.send("Page.captureScreenshot", {"format": "png"})["data"]
	open(path, "wb").write(base64.b64decode(data))
	print("saved", path)


def console_lines(ws):
	lines = []
	for e in ws.events:
		if e.get("method") == "Runtime.consoleAPICalled":
			p = e["params"]
			lines.append("%s: %s" % (p["type"], " ".join(str(a.get("value", a.get("description", ""))) for a in p["args"])))
		elif e.get("method") == "Runtime.exceptionThrown":
			lines.append("EXCEPTION: %s" % e["params"]["exceptionDetails"].get("text"))
	ws.events.clear()
	return lines


def main():
	out = sys.argv[1]
	wait = float(sys.argv[2]) if len(sys.argv) > 2 else 60.0
	os.makedirs(out, exist_ok=True)
	server = ThreadingHTTPServer(("127.0.0.1", HTTP_PORT), partial(SimpleHTTPRequestHandler, directory=os.path.join(ROOT, "build", "web")))
	threading.Thread(target=server.serve_forever, daemon=True).start()
	profile = os.path.join(out, "chrome-profile")
	chrome = subprocess.Popen([CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--window-size=1280,720",
		"--remote-debugging-port=%d" % DEBUG_PORT, "--user-data-dir=" + profile, "--autoplay-policy=no-user-gesture-required",
		"http://127.0.0.1:%d/index.html" % HTTP_PORT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	try:
		page = None
		for _ in range(50):
			try:
				tabs = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json" % DEBUG_PORT))
				page = next(t for t in tabs if t["type"] == "page")
				break
			except Exception:
				time.sleep(0.3)
		ws = WS(page["webSocketDebuggerUrl"])
		ws.send("Runtime.enable")
		ws.send("Page.enable")
		print("booting, waiting %.0f s ..." % wait)
		ws.pump(wait)
		for line in console_lines(ws):
			print("  ", line[:300])
		ws.send("Input.dispatchMouseEvent", {"type": "mousePressed", "x": 640, "y": 360, "button": "left", "clickCount": 1})
		ws.send("Input.dispatchMouseEvent", {"type": "mouseReleased", "x": 640, "y": 360, "button": "left", "clickCount": 1})
		shot(ws, os.path.join(out, "web_level1_intro.png"))
		for level in range(1, 6):
			for _ in range(8): # through the start dialogue
				key(ws, "KeyE", 69, "e")
				ws.pump(0.6)
			ws.pump(4.0)
			shot(ws, os.path.join(out, "web_level%d.png" % level))
			for line in console_lines(ws):
				print("  L%d %s" % (level, line[:300]))
			if level < 5:
				key(ws, "F4", 115, "F4")
				ws.pump(12.0) # the next level loads (navmesh bake)
	finally:
		chrome.terminate()
		server.shutdown()


if __name__ == "__main__":
	main()
