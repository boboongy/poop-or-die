"""Stage 6 SOUND (SPEC Round 3, C1 cartoon + (1) + (9) + the owner's constant background bed), all synthesised here with ffmpeg
(audio/SOURCES.md "Made here"), so there is no licence question. The owner listens and rejects (B1).

Run from the project folder:  python tools/make_cartoon_sounds.py [part ...] [--pack=<folder>]
  parts: mop paper poop tummy bed splash (default: all but splash); splash needs --pack = the unzipped CC0 pack
  "40 CC0 water / splash / slime SFX" (https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip)
Writes (mono, 44.1 kHz, Ogg Vorbis; one-shots start with 30 ms of silence: the engine's fade-in eats a short attack):
  audio/paper/mop_squeak_01..03.ogg        a squeaky mop: squeaks only (Stage 6b: the owner wants a squeak, the noise swish went)
  audio/water/swim_splash_01..04.ogg       splash: a REAL recorded CC0 splash per stroke (Stage 6b C; the synthesised strokes went)
  audio/paper/wipe_01..03.ogg              an exaggerated scrunch then swipe
  audio/paper/tear_01..02.ogg              a paper tear (tissue_grab frame 40)
  audio/body/poop_blast_01..02.ogg         Bob's poop: an explosive diarrhoea + fart burst with splats and plops
  audio/body/tummy_01..04.ogg              tummy rumbles (gurgles)
  audio/ambience/bed_loop.ogg              the CONSTANT background (owner 2026-09-28): farts, plops, flushes, sink water and groans heard
                                           through the stall walls, 36 s seamless loop
"""
import os
import random
import sys
import tempfile

from make_ambience import RATE, ffmpeg, seamless
from make_flood_sounds import bubbles, lavfi, mix, one_shot, peak_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "audio")


def squeak(tmp: str, name: str, dur: float, f0: float, f1: float, vib: float, amp: float = 0.8) -> str:
	"""A rubbery chirp: a clipped sine gliding f0 -> f1 with a fast wobble, round envelope."""
	phase = "2*PI*(%f*t+%f*t*t/(2*%f))+2.5*sin(2*PI*%f*t)" % (f0, f1 - f0, dur, vib)
	expr = "%f*tanh(2.2*sin(%s))*pow(sin(PI*t/%f),0.6)" % (amp, phase, dur)
	return lavfi(tmp, name, "aevalsrc='%s':s=%d:d=%f" % (expr, RATE, dur), dur)


def mop(tmp: str) -> None:
	"""Stage 6b (owner: "the mop should be a squeak"): two rubbery squeaks, a push and a pull, no noise swish."""
	for i in range(3):
		sq = squeak(tmp, "ms%d" % i, 0.22 + 0.04 * i, 900 + 120 * i, 1500 + 100 * i, 26 + 4 * i, 0.6)
		sq2 = squeak(tmp, "ms2_%d" % i, 0.16, 1600 + 60 * i, 1150, 32, 0.5)
		out = os.path.join(tmp, "mop%d.wav" % i)
		ffmpeg("-i", sq, "-i", sq2, "-filter_complex",
			"[1:a]adelay=%d[b];[0:a][b]amix=inputs=2:normalize=0:duration=longest" % (260 + 40 * i), "-ac", "1", out)
		one_shot(out, os.path.join(A, "paper", "mop_squeak_%02d.ogg" % (i + 1)), -2.0)


# Stage 6b C: the pack's short splashes (0.46-0.77 s: a stroke comes about twice a second), picked by length and loudness
# (ebur128 -17.0 to -21.8 LUFS); nobody has listened yet. Only a peak gain (-1 dB, at most +3) and the 30 ms pad are applied.
SPLASHES = ["splash_06.ogg", "splash_08.ogg", "splash_13.ogg", "splash_15.ogg"]


def splashes(pack: str) -> None:
	for i, name in enumerate(SPLASHES):
		src = os.path.join(pack, name)
		gain = min(3.0, -1.0 - peak_of(src))
		ffmpeg("-i", src, "-af", "adelay=30,volume=%.2fdB,aresample=%d" % (gain, RATE), "-ac", "1", "-c:a", "libvorbis", "-q:a", "5",
			os.path.join(A, "water", "swim_splash_%02d.ogg" % (i + 1)))


def crackle(tmp: str, name: str, dur: float, seed: int, rate: float, lo: int, hi: int) -> str:
	"""Paper: dense random clicks (noise gated by a fast random square), band-passed."""
	g = ("anoisesrc=d=%f:c=white:r=%d:a=1:seed=%d,highpass=f=%d,lowpass=f=%d,"
		"volume='gt(random(1),%f)*1.0+0.15':eval=frame" % (dur, RATE, seed, lo, hi, 1.0 - rate))
	return lavfi(tmp, name, g, dur)


def paper(tmp: str) -> None:
	for i in range(3):
		scrunch = crackle(tmp, "sc%d" % i, 0.45, 150 + i, 0.35, 1500, 9000)
		swipe = lavfi(tmp, "sp%d" % i, "anoisesrc=d=0.4:c=pink:r=%d:a=0.9:seed=%d,highpass=f=900,lowpass=f=6000,"
			"volume='pow(sin(PI*t/0.4),0.7)':eval=frame" % (RATE, 160 + i), 0.4)
		out = os.path.join(tmp, "wipe%d.wav" % i)
		ffmpeg("-i", scrunch, "-i", swipe, "-filter_complex",
			"[0:a]volume='min(1,t*30)*max(0,1-t/0.45)':eval=frame[a];[1:a]adelay=%d[b];[a][b]amix=inputs=2:normalize=0:duration=longest"
			% (380 + 30 * i), "-ac", "1", out)
		one_shot(out, os.path.join(A, "paper", "wipe_%02d.ogg" % (i + 1)), -2.0)
	for i in range(2):
		t = crackle(tmp, "tr%d" % i, 0.38, 170 + i, 0.55, 2500, 11000)
		out = os.path.join(tmp, "tear%d.wav" % i)
		ffmpeg("-i", t, "-af", "volume='min(1,t*40)*(0.6+t)*max(0,1-t/0.38)':eval=frame", "-ac", "1", out)
		one_shot(out, os.path.join(A, "paper", "tear_%02d.ogg" % (i + 1)), -4.0) # -2 encoded to a 0.0 dB peak


def poop(tmp: str) -> None:
	"""Bob's poop (owner (1)): an explosive diarrhoea + fart burst: three farts in quick succession, wet splatter, plops, bubbles."""
	body = os.path.join(A, "body")
	sets = [("fart_02.ogg", "fart_04.ogg", "fart_06.ogg"), ("fart_04.ogg", "fart_01.ogg", "fart_02.ogg")]
	for i, (f1, f2, f3) in enumerate(sets):
		splat = lavfi(tmp, "ps%d" % i, "anoisesrc=d=2.2:c=brown:r=%d:a=0.9:seed=%d,bandpass=f=600:w=900,tremolo=f=%d:d=0.9,"
			"volume='min(1,t*25)*max(0,1-t/2.2)':eval=frame" % (RATE, 180 + i, 14 + 3 * i), 2.2)
		b = bubbles(tmp, "pb%d" % i, 1.8, 12.0, 70, 220, 0.6)
		plop = os.path.join(A, "water", "plop_0%d.ogg" % (i + 1))
		out = os.path.join(tmp, "poop%d.wav" % i)
		ffmpeg("-i", os.path.join(body, f1), "-i", os.path.join(body, f2), "-i", os.path.join(body, f3), "-i", splat, "-i", b, "-i", plop, "-i", plop,
			"-filter_complex",
			"[0:a]aresample=%d[a];[1:a]aresample=%d,adelay=%d[b];[2:a]aresample=%d,adelay=%d[c];[3:a]adelay=120,volume=1.2[s];"
			"[4:a]adelay=500,volume=0.5[u];[5:a]aresample=%d,adelay=1300[p];[6:a]aresample=%d,adelay=1750,volume=0.8[q];"
			# Stage 6b: lowpass 3000 -> 7000 and a harder compressor. The owner did not hear it: it fired but was dull and 3-5 LU
			# quieter than the ghost's fart (-16.7/-18.8 LUFS; tests/probe_poop_sound.gd, test_action_sounds "6b poop").
			"[a][b][c][s][u][p][q]amix=inputs=7:normalize=0:duration=longest,lowpass=f=7000,"
			"acompressor=threshold=-24dB:ratio=6:attack=5:release=120:makeup=8"
			% (RATE, RATE, 380 + 60 * i, RATE, 820 + 40 * i, RATE, RATE), "-ac", "1", out)
		one_shot(out, os.path.join(body, "poop_blast_%02d.ogg" % (i + 1)), -1.0)


def tummy(tmp: str) -> None:
	for i in range(4):
		dur = 1.2 + 0.3 * i
		b = bubbles(tmp, "tb%d" % i, dur, 4.0 + 1.5 * i, 55 + 10 * i, 170 + 25 * i, 0.8)
		growl = lavfi(tmp, "tg%d" % i, "aevalsrc='0.5*tanh(3*sin(2*PI*(%d*t+18*sin(2*PI*1.3*t))))*sin(PI*t/%f)':s=%d:d=%f"
			% (48 + 8 * i, dur, RATE, dur), dur)
		one_shot(mix(tmp, "tummy%d" % i, [b, growl], "lowpass=f=600,highpass=f=30"), os.path.join(A, "body", "tummy_%02d.ogg" % (i + 1)), -3.0)


def bed(tmp: str) -> None:
	"""The owner's constant background (2026-09-28): 40 s of other stalls heard through the walls, looped to 36 s. About one event
	every 1.2 s (farts, plops, groans, tummy rumbles), flushes, and sinks running now and then. Fixed seed: the same file each run.
	Stage 6b B (owner: "lacks audible farts, flushes, groans"): farts twice as likely and louder than the rest, four flushes instead of
	two, lowpass 2200 -> 3500 (the farts were a rumble); the event is +6 dB in sfx.gd."""
	rng = random.Random(7)
	amb, body, water = os.path.join(A, "ambience"), os.path.join(A, "body"), os.path.join(A, "water")
	farts = [os.path.join(body, "fart_%02d.ogg" % k) for k in range(1, 6)]
	pool = (farts * 6 + [os.path.join(water, "plop_0%d.ogg" % k) for k in (1, 2)] * 3
		+ [os.path.join(amb, "groan_%02d.ogg" % k) for k in range(1, 17)] + [os.path.join(body, "tummy_%02d.ogg" % k) for k in range(1, 5)])
	events = []
	t = 0.3
	while t < 38.5:
		pick = rng.choice(pool)
		events.append((pick, t, rng.uniform(0.75, 1.0) if pick in farts else rng.uniform(0.4, 0.75)))
		t += rng.uniform(0.6, 1.8)
	for at in (3.0, 12.5, 21.5, 31.0):
		events.append((os.path.join(water, "toilet_01.ogg"), at, 0.9))
	for at in (1.5, 15.0, 29.0):
		events.append((os.path.join(water, "loop_water_02.ogg"), at, 0.35))
	args, labels, chains = [], [], []
	for n, (path, at, vol) in enumerate(events):
		args += ["-i", path]
		chains.append("[%d:a]aresample=%d,aformat=channel_layouts=mono,adelay=%d,volume=%.2f[e%d]" % (n, RATE, int(at * 1000), vol, n))
		labels.append("[e%d]" % n)
	floor = lavfi(tmp, "bed_air", "anoisesrc=d=40:c=brown:r=%d:a=0.15:seed=190,lowpass=f=400" % RATE, 40.0)
	args += ["-i", floor]
	labels.append("[%d:a]" % len(events))
	fc = ";".join(chains) + ";" + "".join(labels) + "amix=inputs=%d:normalize=0:duration=longest,atrim=0:40," % len(labels) \
		+ "lowpass=f=3500,aecho=0.8:0.45:35|70:0.3|0.18,loudnorm=I=-20:TP=-3[out]"
	raw = os.path.join(tmp, "bed.wav")
	ffmpeg(*args, "-filter_complex", fc, "-map", "[out]", "-ac", "1", "-ar", str(RATE), raw)
	seamless(raw, os.path.join(amb, "bed_loop.ogg"), 36.0, 2.0)
	print("bed: %d events in 40 s" % len(events))


def main() -> None:
	pack = next((a[7:] for a in sys.argv[1:] if a.startswith("--pack=")), "")
	parts = [a for a in sys.argv[1:] if not a.startswith("--")] or ["mop", "paper", "poop", "tummy", "bed"]
	with tempfile.TemporaryDirectory() as tmp:
		for part in parts:
			if part == "splash":
				splashes(pack)
			else:
				{"mop": mop, "paper": paper, "poop": poop, "tummy": tummy, "bed": bed}[part](tmp)
			print("written: %s" % part)


if __name__ == "__main__":
	main()
