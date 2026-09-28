"""Level 2 "The flood" sounds (SPEC Round 2 Stage 3), all synthesised here with ffmpeg, so there is no licence question
(audio/SOURCES.md "Made here"). Nobody has listened to them yet: the owner judges; any that sound bad can be swapped for CC0 files.

Run from the project folder:  python tools/make_flood_sounds.py
Writes (mono, 44.1 kHz, Ogg Vorbis; one-shots start with 30 ms of silence, skill section 7: the engine's fade-in eats a short attack):
  audio/body/diarrhoea.ogg        the intro's blast from the clogged stall: a big wet fart layered with splatter
  audio/water/trickle_loop.ogg    water spilling out under the stall door (loop)
  audio/water/gush_loop.ogg       a basin overflowing / the toilet gushing (loop, at each running source)
  audio/water/rise_loop.ogg       the whole room filling: low slosh and rumble (loop, 2D, louder as the water rises)
  audio/water/wade_01..04.ogg     a step in shallow water
  audio/water/dive.ogg            going under: a splash and bubbles
  audio/water/surface.ogg         coming back up: a splash and a gasp of air
  audio/water/plunge_01..03.ogg   the plunger: a rubbery squelch
  audio/water/glug.ogg            the toilet unclogs: a long glug of bubbles
  audio/water/tap_squeak.ogg      a tap turned (on or off)
  audio/water/plug_pop.ogg        the drain plug comes out
  audio/water/gurgle_loop.ogg     the drain swallowing the room (loop)
"""
import os
import re
import subprocess
import tempfile

from make_ambience import RATE, ffmpeg, seamless

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WATER = os.path.join(ROOT, "audio", "water")
BODY = os.path.join(ROOT, "audio", "body")


def peak_of(path: str) -> float:
	out = subprocess.run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True).stderr
	m = re.search(r"max_volume: (-?[\d.]+) dB", out)
	return float(m.group(1)) if m else 0.0


def one_shot(raw: str, dst: str, peak_db: float) -> None:
	"""Pad 30 ms in front, set the peak to `peak_db`, write Ogg."""
	gain = peak_db - peak_of(raw)
	ffmpeg("-i", raw, "-af", "adelay=30,volume=%.2fdB,aresample=%d" % (gain, RATE), "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", dst)


def lavfi(tmp: str, name: str, graph: str, dur: float) -> str:
	out = os.path.join(tmp, name + ".wav")
	ffmpeg("-f", "lavfi", "-i", graph, "-t", "%.3f" % dur, "-ac", "1", "-ar", str(RATE), out)
	return out


def splash(tmp: str, name: str, dur: float, lo: int, hi: int, seed: int, decay: float) -> str:
	"""A burst of filtered noise with a fast attack and an exponential tail: the body of every splash."""
	g = ("anoisesrc=d=%f:c=white:r=%d:a=0.9:seed=%d,highpass=f=%d,lowpass=f=%d,"
		"volume='exp(-%f*t)*min(1,t*80)':eval=frame" % (dur, RATE, seed, lo, hi, decay))
	return lavfi(tmp, name, g, dur)


def bubbles(tmp: str, name: str, dur: float, rate: float, f0: float, f1: float, amp: float = 0.6) -> str:
	"""A train of bubble blips: each a short sine whose pitch rises as it decays."""
	expr = "%f*sin(2*PI*(%f+%f*mod(t*%f,1))*mod(t*%f,1)/%f)*exp(-9*mod(t*%f,1))" % (amp, f0, f1 - f0, rate, rate, rate, rate)
	return lavfi(tmp, name, "aevalsrc='%s':s=%d:d=%f" % (expr, RATE, dur), dur)


def mix(tmp: str, name: str, inputs: list, extra: str = "") -> str:
	out = os.path.join(tmp, name + ".wav")
	args = []
	for i in inputs:
		args += ["-i", i]
	ffmpeg(*args, "-filter_complex", "amix=inputs=%d:normalize=0:duration=longest%s" % (len(inputs), "," + extra if extra else ""), "-ac", "1", out)
	return out


def loops(tmp: str) -> None:
	raw = lavfi(tmp, "trickle", "anoisesrc=d=11:c=pink:r=%d:a=0.5:seed=3,highpass=f=900,lowpass=f=6000,tremolo=f=7:d=0.35,loudnorm=I=-24:TP=-3" % RATE, 11)
	seamless(raw, os.path.join(WATER, "trickle_loop.ogg"), 8.0, 1.5)
	raw = lavfi(tmp, "gush", "anoisesrc=d=9:c=pink:r=%d:a=0.7:seed=5,highpass=f=250,lowpass=f=3500,tremolo=f=3.3:d=0.4,loudnorm=I=-20:TP=-3" % RATE, 9)
	seamless(raw, os.path.join(WATER, "gush_loop.ogg"), 6.0, 1.5)
	a = lavfi(tmp, "rise_a", "anoisesrc=d=14:c=brown:r=%d:a=0.8:seed=7,lowpass=f=450,highpass=f=35,tremolo=f=0.35:d=0.6" % RATE, 14)
	b = lavfi(tmp, "rise_b", "anoisesrc=d=14:c=pink:r=%d:a=0.25:seed=8,bandpass=f=900:w=700,tremolo=f=0.23:d=0.8" % RATE, 14)
	raw = mix(tmp, "rise", [a, b], "loudnorm=I=-22:TP=-3")
	seamless(raw, os.path.join(WATER, "rise_loop.ogg"), 10.0, 2.0)
	n = lavfi(tmp, "gurgle_n", "anoisesrc=d=9:c=brown:r=%d:a=0.6:seed=9,lowpass=f=600,tremolo=f=5:d=0.7" % RATE, 9)
	b1 = bubbles(tmp, "gurgle_b1", 9, 6.3, 120, 320)
	b2 = bubbles(tmp, "gurgle_b2", 9, 4.1, 180, 420, 0.4)
	raw = mix(tmp, "gurgle", [n, b1, b2], "lowpass=f=1500,loudnorm=I=-20:TP=-3")
	seamless(raw, os.path.join(WATER, "gurgle_loop.ogg"), 6.0, 1.5)


def shots(tmp: str) -> None:
	for i in range(4): # (swim_NN.ogg retired in Stage 6: the stroke is make_cartoon_sounds.py stroke_NN.ogg)
		raw = splash(tmp, "wade%d" % i, 0.3, 200 + 40 * i, 2800 - 200 * i, 40 + i, 11 + i)
		one_shot(raw, os.path.join(WATER, "wade_%02d.ogg" % (i + 1)), -6.0)
	s = splash(tmp, "dive_s", 0.7, 250, 5000, 60, 5.0)
	b = bubbles(tmp, "dive_b", 0.9, 9.0, 250, 700, 0.35)
	one_shot(mix(tmp, "dive", [s, b], "lowpass=f=4000"), os.path.join(WATER, "dive.ogg"), -3.0)
	s = splash(tmp, "surf_s", 0.5, 400, 6000, 61, 6.0)
	one_shot(s, os.path.join(WATER, "surface.ogg"), -5.0)
	for i in range(3):
		# a rubber cup: a low thump whose pitch drops, plus a sucking noise
		thump = lavfi(tmp, "pl_t%d" % i, "aevalsrc='0.9*sin(2*PI*(%d*t-70*t*t))*exp(-9*t)':s=%d:d=0.35" % (95 + 12 * i, RATE), 0.35)
		suck = splash(tmp, "pl_s%d" % i, 0.35, 150, 900 + 150 * i, 70 + i, 9.0)
		one_shot(mix(tmp, "plunge%d" % i, [thump, suck], "lowpass=f=1500"), os.path.join(WATER, "plunge_%02d.ogg" % (i + 1)), -4.0)
	b = bubbles(tmp, "glug_b", 1.4, 5.0, 90, 260, 0.9)
	n = lavfi(tmp, "glug_n", "anoisesrc=d=1.4:c=brown:r=%d:a=0.5:seed=80,lowpass=f=500,volume='min(1,t*8)*exp(-1.6*t)':eval=frame" % RATE, 1.4)
	one_shot(mix(tmp, "glug", [b, n], "lowpass=f=1200"), os.path.join(WATER, "glug.ogg"), -3.0)
	sq = lavfi(tmp, "squeak", "aevalsrc='0.6*sin(2*PI*(1300*t+900*t*t+6*sin(2*PI*28*t)))*min(1,t*60)*exp(-6*t)':s=%d:d=0.28" % RATE, 0.28)
	one_shot(sq, os.path.join(WATER, "tap_squeak.ogg"), -8.0)
	pop = lavfi(tmp, "pop", "aevalsrc='sin(2*PI*(320*t-900*t*t))*exp(-30*t)':s=%d:d=0.16" % RATE, 0.16)
	one_shot(pop, os.path.join(WATER, "plug_pop.ogg"), -3.0)


def blast(tmp: str) -> None:
	fart = os.path.join(BODY, "fart_06.ogg")
	splat = lavfi(tmp, "splat", "anoisesrc=d=2.6:c=brown:r=%d:a=0.9:seed=90,bandpass=f=500:w=800,tremolo=f=13:d=0.9,"
		"volume='min(1,t*20)*(1-t/2.6)':eval=frame" % RATE, 2.6)
	b = bubbles(tmp, "blast_b", 2.6, 11.0, 70, 190, 0.7)
	out = os.path.join(tmp, "blast.wav")
	ffmpeg("-i", fart, "-i", splat, "-i", b, "-filter_complex",
		"[0:a]aresample=%d[f];[1:a]adelay=250[s];[2:a]adelay=400,volume=0.6[b];[f][s][b]amix=inputs=3:normalize=0:duration=longest,lowpass=f=2200" % RATE,
		"-ac", "1", out)
	one_shot(out, os.path.join(BODY, "diarrhoea.ogg"), -1.5)


def main() -> None:
	os.makedirs(WATER, exist_ok=True)
	with tempfile.TemporaryDirectory() as tmp:
		loops(tmp)
		shots(tmp)
		blast(tmp)
	print("flood sounds written")


if __name__ == "__main__":
	main()
