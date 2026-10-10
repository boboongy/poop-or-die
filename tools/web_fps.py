"""Web build speed in the REAL installed Chrome (GPU, not swiftshader): FPS and where the frame goes, per level.
Serves build/web, opens index.html?probe (scripts/web_probe.gd prints fps / render cpu / draw calls to the console every 3 s),
clicks in, presses E through the start dialogue, then for each level counts requestAnimationFrame callbacks over 5 s (Godot's main
loop runs on them) RUNS times, keeps the probe lines, and saves one screenshot. F4 = next level.

Needs: pip install playwright (uses the installed Chrome, channel="chrome"). Close heavy programs first (a running test suite
halves the numbers). Run from the project folder:
  python tools/web_fps.py <out_dir> [runs=3] [extra query, e.g. "&chars=0"]

SIZE=<w>x<h> sets the viewport (default 1280x720). ALWAYS state the size with the number: the frame is fill-rate bound, so
SIZE=1920x1080 (how the owner plays, fullscreen) runs about a third of 720p's FPS. The old "L3 32-40 FPS" was 720p.
"""
import functools
import http.server
import os
import sys
import threading

from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 8767

out = sys.argv[1]
runs = int(sys.argv[2]) if len(sys.argv) > 2 else 3
extra = sys.argv[3] if len(sys.argv) > 3 else ""
VW, VH = (int(n) for n in os.environ.get("SIZE", "1280x720").split("x"))
os.makedirs(out, exist_ok=True)
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=os.path.join(ROOT, "build", "web"))
http.server.SimpleHTTPRequestHandler.log_message = lambda *a: None
srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()

probe_lines = []
RAF = """() => new Promise(r => { let n = 0; const t0 = performance.now();
	function f() { n++; if (performance.now() - t0 < 5000) requestAnimationFrame(f); else r(n / 5); }
	requestAnimationFrame(f); })"""


def on_console(m):
	t = m.text
	if "web_probe" in t or "ERROR" in t or "WARNING" in t:
		probe_lines.append(t)


summary = []
with sync_playwright() as p:
	b = p.chromium.launch(channel="chrome", headless=False,
		args=["--window-size=%d,%d" % (VW, VH + 80), "--autoplay-policy=no-user-gesture-required"])
	pg = b.new_page(viewport={"width": VW, "height": VH})
	print("viewport: %dx%d" % (VW, VH))
	pg.on("console", on_console)
	pg.goto("http://127.0.0.1:%d/index.html?probe%s" % (PORT, extra))
	print("gl:", pg.evaluate("""() => { const c = document.createElement('canvas').getContext('webgl2');
		const e = c.getExtension('WEBGL_debug_renderer_info'); return e ? c.getParameter(e.UNMASKED_RENDERER_WEBGL) : 'n/a'; }"""))
	pg.wait_for_timeout(40000) # boot + level 1 load
	pg.mouse.click(640, 360)
	for level in range(1, 6):
		for _ in range(8): # through the start dialogue
			pg.keyboard.press("e")
			pg.wait_for_timeout(600)
		pg.wait_for_timeout(4000)
		probe_lines.clear()
		fps = []
		for _ in range(runs):
			fps.append(pg.evaluate(RAF))
		pg.screenshot(path=os.path.join(out, "web_fps_level%d.png" % level))
		probes = [l for l in probe_lines if "web_probe frame" in l]
		print("L%d fps %s" % (level, " ".join("%.1f" % f for f in fps)))
		for l in probes[-2:]:
			print("   ", l[:200])
		for l in probe_lines:
			if "web_probe frame" not in l:
				print("   ", l[:200])
		summary.append("L%d min %.1f" % (level, min(fps)))
		if level < 5:
			pg.keyboard.press("F4")
			pg.wait_for_timeout(15000) # next level loads (navmesh bake)
	b.close()
srv.shutdown()
print("SUMMARY", " | ".join(summary))
