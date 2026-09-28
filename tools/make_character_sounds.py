"""Stage 6 SOUND (SPEC Round 3 (2), (8), (9), (10)): the characters' non-dialogue voice sounds, spoken by the SAME Piper casts as the
dialogue (tools/make_voices.py CASTS: public domain / CC0 voices, audio/SOURCES.md "Voices"), so every character sounds like itself.

Run from the project folder:  python tools/make_character_sounds.py
Writes audio/grunts/ (mono Ogg Vorbis, 30 ms lead-in, loudness-normalised by make_voices.render):
  oof_<cast>_NN.ogg          a hit in a fight: OOF / OW / UGH (the three cutters + the three generic Jijio voices)
  ko_<cast>.ogg              knocked out: a long cartoon groan
  bob_ouch_NN.ogg            Bob hit
  bob_groan_<level>_NN.ogg   Bob holding it in: 1 mild, 2 bad, 3 desperate (the level timer running low)
  complain_<cast>_NN.ogg     Jijios complaining in the background
and audio/ambience/gibberish_loop.ogg: the waiting-room crowd as high-pitched funny Jijio gibberish (owner (8): the old muttering
sounded like men), 4 voices, 20 s seamless loop.
"""
import os
import re
import subprocess
import tempfile
import wave

from make_ambience import RATE, ffmpeg, seamless
from make_voices import CASTS, MODELS, render

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "grunts")
AMB = os.path.join(ROOT, "audio", "ambience")

JIJIOS = ["jijio_a", "jijio_b", "jijio_c"]
CUTTERS = ["pushy", "sneaky", "bossy"]
# Spelled as words, "!!" for a shout (make_voices.shouted): Piper spells an all-caps non-word letter by letter ("OOF!" = "O. O. F.", 2.3 s)
OOFS = ["Ooff!!", "Oww!!", "Urgh!!", "Hmmph!!"]
KO = "Ooooooh nooooooo..."
BOB_OUCH = ["Oww!!", "Ooff!!", "Ouchie!!"]
BOB_GROANS = {
	1: ["Mmmmh... my tummy.", "Oh... I really need to go.", "Hmmmm... hold it, Bob."],
	2: ["Hnnnngh... come on, come on...", "Oh no. Oh no no no.", "Hurry, hurry, hurry!"],
	3: ["Hnnnnngh!! I can't hold it!!", "It's coming!! It's coming!!", "Please, please, PLEASE!"],
}
COMPLAINTS = ["Who ate the chili?!", "Hurry up in there!", "It smells like a swamp!", "No paper AGAIN?!", "Ugh, my tummy!", "Somebody flush that!"]
GIBBERISH = [
	"Blibba jabba wooba? Nee nee flumpa doo!", "Gibbi gobba, snorkle wop, ha ha ha!", "Oompa loo, jiji wiji, bleh!",
	"Wibby wobby, doodle poo? Nah nah nah!", "Floob! Floob floob, mimi jabber.", "Yibba dabba, pee pee toot toot!",
	"Hoo hoo, bloop, snazzle wazzle.", "Jiji? Jiji jiji! Moo moo gabba!",
]
GIBBER_PITCH = [1.55, 1.7, 1.62, 1.78] # higher than the dialogue voices: a crowd of chipmunks


def voices() -> dict:
	from piper import PiperVoice
	out = {}
	for c in set(JIJIOS + CUTTERS + ["bob"]):
		out[c] = PiperVoice.load(os.path.join(MODELS, CASTS[c]["model"] + ".onnx"))
	return out


def first_sound_only(path: str) -> None:
	"""A grunt is one sound: the norman model (jijio_c, pushy) adds a second breath after a 0.4 s gap ("Ooff!!" was 1.9 s). Cut at the first
	silence of 0.2 s or more that starts after 0.15 s."""
	err = subprocess.run(["ffmpeg", "-i", path, "-af", "silencedetect=n=-35dB:d=0.2", "-f", "null", "-"], capture_output=True, text=True).stderr
	starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err) if float(x) > 0.15]
	if starts:
		tmp = path + ".cut.ogg"
		ffmpeg("-i", path, "-af", "atrim=0:%.3f,afade=t=out:st=%.3f:d=0.05" % (starts[0] + 0.05, starts[0]), "-c:a", "libvorbis", "-q:a", "4", tmp)
		os.replace(tmp, path)


def grunts(v: dict) -> None:
	os.makedirs(OUT, exist_ok=True)
	for c in JIJIOS + CUTTERS:
		for i, t in enumerate(OOFS):
			render(v[c], CASTS[c], t, os.path.join(OUT, "oof_%s_%02d.ogg" % (c, i + 1)))
			first_sound_only(os.path.join(OUT, "oof_%s_%02d.ogg" % (c, i + 1)))
		for i, t in enumerate(COMPLAINTS if c in JIJIOS else []):
			render(v[c], CASTS[c], t, os.path.join(OUT, "complain_%s_%02d.ogg" % (c, i + 1)))
	for c in CUTTERS:
		render(v[c], {**CASTS[c], "fx": ""}, KO, os.path.join(OUT, "ko_%s.ogg" % c)) # not sped up: a long drawn-out groan
	for i, t in enumerate(BOB_OUCH):
		render(v["bob"], CASTS["bob"], t, os.path.join(OUT, "bob_ouch_%02d.ogg" % (i + 1)))
		first_sound_only(os.path.join(OUT, "bob_ouch_%02d.ogg" % (i + 1)))
	for level, lines in BOB_GROANS.items():
		for i, t in enumerate(lines):
			render(v["bob"], CASTS["bob"], t, os.path.join(OUT, "bob_groan_%d_%02d.ogg" % (level, i + 1)))


def gibberish(v: dict, tmp: str) -> None:
	models = [v["jijio_a"], v["jijio_b"], v["jijio_c"], v["jijio_b"]]
	layers = []
	for n, (voice, pitch) in enumerate(zip(models, GIBBER_PITCH)):
		parts = []
		for k in range(len(GIBBERISH)):
			raw = os.path.join(tmp, "g%d_%d.raw.wav" % (n, k))
			with wave.open(raw, "wb") as w:
				voice.synthesize_wav(GIBBERISH[(k * 3 + n * 5) % len(GIBBERISH)], w)
			rate = voice.config.sample_rate
			p = os.path.join(tmp, "g%d_%d.wav" % (n, k))
			# pitched up, 25 % faster, then a pause of 0.3-1.1 s
			ffmpeg("-i", raw, "-af", "asetrate=%d,aresample=%d,atempo=%.4f,atempo=1.25,apad=pad_dur=%.2f,aresample=%d"
				% (int(rate * pitch), rate, 1.0 / pitch, 0.3 + 0.27 * ((k + n) % 4), RATE), "-ac", "1", p)
			parts.append(p)
		lst = os.path.join(tmp, "g%d.txt" % n)
		with open(lst, "w", encoding="utf-8") as fh:
			for p in parts:
				fh.write("file '%s'\n" % p.replace("\\", "/"))
		out = os.path.join(tmp, "glayer%d.wav" % n)
		ffmpeg("-f", "concat", "-safe", "0", "-i", lst, "-af", "adelay=%d,aloop=loop=2:size=%d,atrim=0:23" % (n * 1300, 40 * RATE), "-ac", "1", "-ar", str(RATE), out)
		layers.append(out)
	raw = os.path.join(tmp, "gibberish.wav")
	args = []
	for l in layers:
		args += ["-i", l]
	# across a tiled room: a bit muffled and roomy, but brighter than the old muttering (high voices)
	ffmpeg(*args, "-filter_complex", "amix=inputs=4:normalize=0,lowpass=f=2600,highpass=f=180,aecho=0.8:0.5:45|90:0.3|0.2,loudnorm=I=-22:TP=-3",
		"-ac", "1", raw)
	seamless(raw, os.path.join(AMB, "gibberish_loop.ogg"), 20.0, 2.0)


def main() -> None:
	v = voices()
	grunts(v)
	with tempfile.TemporaryDirectory() as tmp:
		gibberish(v, tmp)
	for f in sorted(os.listdir(OUT)):
		out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", os.path.join(OUT, f)], capture_output=True, text=True)
		print("%-26s %s s" % (f, out.stdout.strip()))


if __name__ == "__main__":
	main()
