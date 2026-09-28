"""How loud each sound EVENT can get: the loudest file's peak (dBFS, both channels) + the event's db, capped by its max_db (a 3D
sound heard up close). Reads the one-line event entries of scripts/sfx.gd.
  python tools/sound_levels.py                 print every event
  python tools/sound_levels.py --check E1 E2   exit 1 if any named event peaks under FLOOR (the Stage 6 "every action is heard" rule)
"""
import json
import math
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLOOR = -12.0 # SPEC Round 3 Stage 6 slice 0: every action's sound peaks at -12 dB or louder
LINE = re.compile(r'^\t"(\w+)": (\{.*\}),?\s*(#.*)?$')


def events() -> dict:
	out = {}
	with open(os.path.join(ROOT, "scripts", "sfx.gd"), encoding="utf-8") as f:
		for line in f:
			m = LINE.match(line.rstrip("\n"))
			if m:
				out[m.group(1)] = json.loads(m.group(2))
	return out


def file_peak(rel: str) -> float:
	# the file's own channels: `-ac 2` upmixed a mono file 3 dB down (squeak_walk measured -5.5 here, -2.5 by volumedetect)
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(ROOT, "audio", rel), "-f", "s16le", "-ar", "44100", "-"],
		capture_output=True, check=True).stdout
	peak = max((abs(x) for x in memoryview(raw).cast("h")), default=0) / 32768.0
	return 20 * math.log10(peak) if peak > 0 else -120.0


def level(ev: dict) -> float:
	db = ev.get("db", 0.0)
	if "range" in ev: # 3D: Sfx caps every 3D player at max_db (default Sfx.MAX_3D_DB = 0)
		db = min(db, ev.get("max_db", 0.0))
	return max(file_peak(f) for f in ev["files"]) + db


def file_lufs(rel: str) -> float:
	"""Integrated loudness (LUFS, EBU R128) of one file under audio/: how loud it SOUNDS, not just its highest sample."""
	err = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", os.path.join(ROOT, "audio", rel), "-af", "ebur128", "-f", "null", "-"],
		capture_output=True, text=True).stderr
	found = re.findall(r"I:\s+(-?[\d.]+) LUFS", err)
	return float(found[-1]) if found else -120.0


def main() -> None:
	if sys.argv[1:2] == ["--lufs"]: # python tools/sound_levels.py --lufs body/x.ogg ...: one "LUFS <value> <file>" line each
		for rel in sys.argv[2:]:
			print("LUFS %.1f %s" % (file_lufs(rel), rel))
		return
	evs = events()
	names = sys.argv[2:] if len(sys.argv) > 1 and sys.argv[1] == "--check" else sorted(evs)
	bad = []
	for n in names:
		if n not in evs:
			print("MISSING  %s (no such event in sfx.gd)" % n)
			bad.append(n)
			continue
		lv = level(evs[n])
		ok = lv >= FLOOR
		print("%-8s %-14s %6.1f dB" % ("ok" if ok else "QUIET", n, lv))
		if not ok:
			bad.append(n)
	if sys.argv[1:2] == ["--check"]:
		print("SOUND LEVELS %s (%d of %d under %.0f dB or missing)" % ("FAIL" if bad else "OK", len(bad), len(names), FLOOR))
		sys.exit(1 if bad else 0)


if __name__ == "__main__":
	main()
