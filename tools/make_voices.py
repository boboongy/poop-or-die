"""Spoken voices for every dialogue line (SPEC "Round 2" Stage 2), made offline with Piper TTS.

Run from the project folder:  python tools/make_voices.py        (add --list to only print the lines, --force to redo all)
Needs: pip install piper-tts, ffmpeg on PATH, the voice models in %LOCALAPPDATA%/piper-voices (see audio/SOURCES.md "Voices").

1. Finds the lines: every `.say(` / `.choose(` / `.bubble(` / `.shout_voice(` call in scripts/ (dialogue.gd itself excluded). A text argument that is
   not a plain string is followed to its definition in the same file (a const, a local var, a table key like def["open"]), so
   arrays of lines, the cutters' table and the walkers' chatter are all found. `%` lines are expanded from FORMATS below.
2. The speaker comes from the call's `who` argument (default "Jijio"); a choose()'s replies are Bob's.
3. Each (cast, line) becomes audio/voices/<cast>/<md5 of the text, 10 hex>.ogg; generic Jijio lines are made in every JIJIO_CASTS
   voice. scripts/dialogue.gd computes the same name, so no table is needed in the game. audio/voices/manifest.json lists them.
Every line printed while the game runs is checked: dialogue.gd prints "VOICE MISSING" and tests/run.sh fails that test.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "voices")
MODELS = os.path.join(os.environ.get("LOCALAPPDATA", ""), "piper-voices")

# Only voices whose training data is public domain or CC0 (no credit needed; SPEC Round 2). Checked 2026-09-27 on each MODEL_CARD.
# pitch: x frequency (tempo kept); speed: Piper length_scale (lower = faster); noise / noise_w: Piper noise_scale (intonation varies more)
# and noise_w_scale (rhythm varies more); fx: extra ffmpeg filter.
# Owner 2026-09-27 after A/B samples ("Bob sounds boring, more animated and cute"; "Jijio good but more sassy", defaults): Bob = a light
# voice pitched up like a cartoon kid (was joe x1.08); every Jijio and named character livelier, a bit faster and higher; GHOST unchanged.
# Stage 6 A1 (owner 2026-09-28, "yes" to the A/B samples): every Jijio and named character except GHOST gets a Bob-style high, funny voice
# (each pitched a bit differently) and speaks 30 % faster. The speed-up is ffmpeg atempo on the finished line: Piper's length_scale made a
# PUSHY sample LONGER (6.4 s vs 6.1 s, noise_w adds pauses); atempo=1.3 gave 22-32 % shorter in 4 of 4 renders. Bob keeps his speed (A).
SASSY = {"noise": 0.95, "noise_w": 1.2}
FAST = {"fx": "atempo=1.3"}
CASTS = {
	"bob": {"model": "en_US-kristin-medium", "pitch": 1.22, "speed": 0.85, "noise": 0.9, "noise_w": 1.0},
	"jijio_a": {"model": "en_US-bryce-medium", "pitch": 1.32, "speed": 0.92, **SASSY, **FAST},
	"jijio_b": {"model": "en_US-kristin-medium", "pitch": 1.27, "speed": 0.9, **SASSY, **FAST},
	"jijio_c": {"model": "en_US-norman-medium", "pitch": 1.36, "speed": 0.88, **SASSY, **FAST},
	"ghost": {"model": "en_US-john-medium", "pitch": 0.82, "speed": 1.25, "fx": "aecho=0.8:0.6:90|170:0.35|0.22"},
	"queen": {"model": "en_GB-cori-medium", "pitch": 1.29, "speed": 0.84, **SASSY, **FAST},
	"pushy": {"model": "en_US-norman-medium", "pitch": 1.22, "speed": 0.84, **SASSY, **FAST},
	"sneaky": {"model": "en_US-kathleen-low", "pitch": 1.33, "speed": 1.0, **SASSY, **FAST},
	"bossy": {"model": "en_US-ljspeech-medium", "pitch": 1.25, "speed": 0.88, **SASSY, **FAST},
}
JIJIO_CASTS = ["jijio_a", "jijio_b", "jijio_c"]
# The name shown in the talk box -> cast. Anything else is a generic Jijio (the same map is in dialogue.gd CAST_OF_WHO).
CAST_OF_WHO = {"Bob": "bob", "GHOST": "ghost", "SHUFFLE QUEEN": "queen", "PUSHY": "pushy", "SNEAKY": "sneaky", "BOSSY": "bossy"}
# Lines built with `%`: the argument lists they are formatted with (every value the game can produce).
FORMATS = {
	"stall number %d from the entrance": [(row, n) for row in (
		"first row (along the corridor you walk in from)", "back row (the corridor behind the stalls)") for n in range(1, 11)],
}
# Values that come from another file: identifier -> (file, table key).
EXTERNAL = {"_hint": ("scripts/level_defs.gd", "walker_hint")}

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
CALL = re.compile(r"\.(say|choose|bubble|shout_voice)\(")


def unescape(s: str) -> str:
	return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def balanced(src: str, start: int) -> str:
	"""The text between the bracket at `start` and its partner (strings skipped)."""
	pairs = {"(": ")", "[": "]", "{": "}"}
	stack = [pairs[src[start]]]
	i = start + 1
	while i < len(src):
		c = src[i]
		if c == '"':
			m = STRING.match(src, i)
			i = m.end()
			continue
		if c in pairs:
			stack.append(pairs[c])
		elif c == stack[-1]:
			stack.pop()
			if not stack:
				return src[start + 1:i]
		i += 1
	raise ValueError("unbalanced bracket")


def split_args(args: str) -> list:
	out, depth, cur, i = [], 0, "", 0
	while i < len(args):
		c = args[i]
		if c == '"':
			m = STRING.match(args, i)
			cur += m.group(0)
			i = m.end()
			continue
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
		if c == "," and depth == 0:
			out.append(cur.strip())
			cur = ""
		else:
			cur += c
		i += 1
	if cur.strip():
		out.append(cur.strip())
	return out


def definition(src: str, name: str) -> str:
	"""The right-hand side of `const/var NAME ... = <expr>` (or `NAME = <expr>`) in this file."""
	m = re.search(r"(?:const|var)\s+%s\b[^=\n]*?:?=\s*" % re.escape(name), src) or re.search(r"^\s*%s\s*=\s*" % re.escape(name), src, re.M)
	if not m:
		return ""
	i = m.end()
	if src[i] in "([{":
		return src[i:i + len(balanced(src, i)) + 2]
	return src[i:src.index("\n", i)]


def table_values(src: str, key: str) -> list:
	vals = []
	for m in re.finditer(r'"%s"\s*:\s*' % re.escape(key), src):
		i = m.end()
		if src[i] in "([{":
			vals += [unescape(s) for s in STRING.findall(src[i:i + len(balanced(src, i)) + 2])]
		elif src[i] == '"':
			vals.append(unescape(STRING.match(src, i).group(1)))
		else: # a constant: "name": BOSS
			name = re.match(r"[A-Za-z_]\w*", src[i:]).group(0)
			vals += [unescape(s) for s in STRING.findall(definition(src, name))]
	return vals


def resolve(expr: str, src: str, depth: int = 0) -> list:
	"""Every string the expression can evaluate to."""
	if depth > 4:
		return []
	lits = [unescape(m.group(1)) for m in STRING.finditer(expr) if not re.match(r"\s*:", expr[m.end():])] # not dictionary keys
	key = re.search(r'\w+\["(\w+)"\]', expr)
	if key and not expr.lstrip().startswith('"'):
		return table_values(src, key.group(1))
	sub = re.match(r"\s*([A-Za-z_]\w*)\s*\[", expr) # LINES[i], CHATTER[job]: the strings in the index are not lines
	if sub:
		rhs = definition(src, sub.group(1))
		return resolve(rhs, src, depth + 1) if rhs else []
	if lits and "%" in expr.split('"')[-1]:
		for pattern, args in FORMATS.items():
			if pattern in lits[0]:
				return [lits[0] % a for a in args]
		raise ValueError("no FORMATS entry for: " + lits[0])
	if lits:
		return lits
	name = re.match(r"\s*([A-Za-z_]\w*)", expr)
	if not name:
		return []
	name = name.group(1)
	if name in EXTERNAL:
		path, k = EXTERNAL[name]
		return table_values(open(os.path.join(ROOT, path), encoding="utf-8").read(), k)
	rhs = definition(src, name)
	return resolve(rhs, src, depth + 1) if rhs else []


def cast_of(who: str) -> list:
	return [CAST_OF_WHO[who]] if who in CAST_OF_WHO else list(JIJIO_CASTS)


def find_lines() -> dict:
	"""{cast: set(text)}"""
	lines = {c: set() for c in CASTS}
	for folder, _, files in os.walk(os.path.join(ROOT, "scripts")):
		for f in files:
			if not f.endswith(".gd") or f == "dialogue.gd":
				continue
			src = open(os.path.join(folder, f), encoding="utf-8").read()
			for m in CALL.finditer(src):
				args = split_args(balanced(src, m.end() - 1))
				kind = m.group(1)
				who_i = {"bubble": 4, "shout_voice": 2}.get(kind, 3)
				whos = resolve(args[who_i], src) if len(args) > who_i else ["Jijio"]
				texts = resolve(args[1], src)
				if not texts:
					raise ValueError("%s: cannot resolve %s" % (f, args[1]))
				for who in whos:
					for c in cast_of(who):
						lines[c].update(texts)
				if kind == "choose":
					lines["bob"].update(resolve(args[2], src))
	return lines


def key(text: str) -> str:
	return hashlib.md5(text.encode("utf-8")).hexdigest()[:10]


def shouted(text: str) -> bool:
	return "!" in text and (re.search(r"\b[A-Z]{3,}\b", text) is not None or "!!" in text)


def spoken(text: str) -> str:
	"""What Piper reads: stage directions like *knock knock* are left out."""
	t = re.sub(r"\*[^*]*\*", " ", text)
	return re.sub(r"\s+", " ", t).strip() or text


def render(voice, cast: dict, text: str, path: str) -> float:
	from piper import SynthesisConfig
	shout = shouted(text)
	noise = cast.get("noise", 0.667)
	cfg = SynthesisConfig(length_scale=cast["speed"] * (0.85 if shout else 1.0), noise_scale=max(noise, 0.8) if shout else noise,
		noise_w_scale=cast.get("noise_w", 0.8))
	with tempfile.TemporaryDirectory() as tmp:
		raw = os.path.join(tmp, "raw.wav")
		with wave.open(raw, "wb") as w:
			voice.synthesize_wav(spoken(text), w, syn_config=cfg)
		rate = voice.config.sample_rate
		pitch = cast["pitch"] * (1.07 if shout else 1.0)
		fx = ["asetrate=%d" % int(rate * pitch), "aresample=%d" % rate, "atempo=%.4f" % (1.0 / pitch)]
		if cast.get("fx"):
			fx.append(cast["fx"])
		# 30 ms of silence in front: the engine fades every sound in (SOURCES.md "Edited files"); shouts end up 3 dB louder.
		fx += ["adelay=30", "loudnorm=I=%d:TP=-1.5:LRA=11" % (-13 if shout else -16), "aresample=%d" % rate]
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", ",".join(fx), "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", path], check=True)
	out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
	return round(float(out.stdout.strip()), 3)


def main() -> None:
	lines = find_lines()
	if "--list" in sys.argv:
		for c, texts in lines.items():
			for t in sorted(texts):
				print("%-8s %s  %s%s" % (c, key(t), "SHOUT " if shouted(t) else "", t))
		print(sum(len(v) for v in lines.values()), "files")
		return
	force = "--force" in sys.argv
	# --redo=cast1,cast2: re-render only these casts (a voice change must not re-roll the others: Piper output varies per render)
	redo = set(next((a.split("=", 1)[1].split(",") for a in sys.argv if a.startswith("--redo=")), []))
	old = {}
	manifest_path = os.path.join(OUT, "manifest.json")
	if os.path.exists(manifest_path):
		old = json.load(open(manifest_path, encoding="utf-8"))
	from piper import PiperVoice
	manifest, made = {}, 0
	for c, texts in lines.items():
		cast = CASTS[c]
		folder = os.path.join(OUT, c)
		os.makedirs(folder, exist_ok=True)
		voice = None
		manifest[c] = {}
		for t in sorted(texts):
			k = key(t)
			path = os.path.join(folder, k + ".ogg")
			if not force and c not in redo and os.path.exists(path) and k in old.get(c, {}):
				manifest[c][k] = old[c][k]
				continue
			if voice is None:
				voice = PiperVoice.load(os.path.join(MODELS, cast["model"] + ".onnx"))
			manifest[c][k] = {"text": t, "seconds": render(voice, cast, t, path)}
			made += 1
		for f in os.listdir(folder): # lines that no longer exist
			stem = f.split(".")[0]
			if stem not in manifest[c]:
				os.remove(os.path.join(folder, f))
	with open(manifest_path, "w", encoding="utf-8", newline="\n") as fh:
		json.dump(manifest, fh, indent=1, ensure_ascii=False, sort_keys=True)
		fh.write("\n")
	print("made %d, total %d" % (made, sum(len(v) for v in manifest.values())))


if __name__ == "__main__":
	main()
