"""Stage 4 "WATER WAR" sounds (SPEC "Stage 4 plan APPROVED 2026-09-27" (9)), all synthesised here with ffmpeg, so there is no licence
question (audio/SOURCES.md "Made here"). Nobody has listened to them yet: the owner judges; any that sound bad can be swapped.

Run from the project folder:  python tools/make_shooter_sounds.py
Writes (mono, 44.1 kHz, Ogg Vorbis; one-shots start with 30 ms of silence, skill references/sound.md: the engine's fade-in eats a short
attack) into audio/shooter/:
  gun_shot_01..03.ogg     Bob's water gun: a pressurised squirt with a small pump thump
  blob_splash_01..03.ogg  a blob lands on a wall or a Jijio: a small wet splat
  hit_tick.ogg            hit marker, body: a short bright tick
  hit_ding.ogg            hit marker, head: a bell ding
  kill_chime.ogg          a kill: two rising bell notes
  enemy_shot_01..03.ogg   a crew / BOSSY shot: a lower, gloopier squirt
  bob_splat_01..02.ogg    a brown blob hits Bob: a heavy wet splat
  dry_click.ogg           the trigger on an empty tank: a double plastic click
  refill.ogg              the tank refills at a sink: bubbling, rising in pitch as it fills
  hose_loop.ogg           the SUPER-SOAKER hose: a pressurised roaring spray (loop)
"""
import os
import tempfile

from make_ambience import RATE, ffmpeg, seamless
from make_flood_sounds import bubbles, lavfi, mix, one_shot, splash

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "shooter")


def tone(tmp: str, name: str, expr: str, dur: float) -> str:
	return lavfi(tmp, name, "aevalsrc='%s':s=%d:d=%f" % (expr, RATE, dur), dur)


def bell(freq: float, decay: float, start: float = 0.0, amp: float = 0.5) -> str:
	"""A bell partial set (1, 2.76, 5.4 x) starting at `start` s, as an aevalsrc expression."""
	t = "(t-%f)" % start
	on = "gte(t,%f)" % start
	return ("%s*%f*(sin(2*PI*%f*%s)+0.45*sin(2*PI*%f*%s)+0.2*sin(2*PI*%f*%s))*exp(-%f*%s)*min(1,%s*400)"
		% (on, amp, freq, t, freq * 2.76, t, freq * 5.4, t, decay, t, t))


def guns(tmp: str) -> None:
	for i in range(3):
		# the squirt: noise band-passed high, a fast attack and a short tail; the pump: a low falling thump
		sq = splash(tmp, "shot_s%d" % i, 0.16, 1100 + 150 * i, 7000 - 500 * i, 100 + i, 26.0)
		th = tone(tmp, "shot_t%d" % i, "0.7*sin(2*PI*(%d*t-400*t*t))*exp(-45*t)" % (170 + 15 * i), 0.1)
		one_shot(mix(tmp, "shot%d" % i, [sq, th]), os.path.join(OUT, "gun_shot_%02d.ogg" % (i + 1)), -6.0)
		es = splash(tmp, "eshot_s%d" % i, 0.22, 400 + 80 * i, 3000 - 200 * i, 110 + i, 18.0)
		eb = bubbles(tmp, "eshot_b%d" % i, 0.22, 22.0, 180, 420, 0.3)
		one_shot(mix(tmp, "eshot%d" % i, [es, eb], "lowpass=f=3200"), os.path.join(OUT, "enemy_shot_%02d.ogg" % (i + 1)), -6.0)
		sp = splash(tmp, "splash%d" % i, 0.28, 450 + 60 * i, 4500 - 300 * i, 120 + i, 14.0)
		one_shot(sp, os.path.join(OUT, "blob_splash_%02d.ogg" % (i + 1)), -6.0)
	for i in range(2):
		s = splash(tmp, "bsplat_s%d" % i, 0.5, 150, 2600 - 300 * i, 130 + i, 8.0)
		t = tone(tmp, "bsplat_t%d" % i, "0.8*sin(2*PI*(%d*t-150*t*t))*exp(-18*t)" % (90 + 20 * i), 0.3)
		one_shot(mix(tmp, "bsplat%d" % i, [s, t], "lowpass=f=2400"), os.path.join(OUT, "bob_splat_%02d.ogg" % (i + 1)), -4.0)


def markers(tmp: str) -> None:
	tick = tone(tmp, "tick", "0.8*sin(2*PI*2400*t)*exp(-90*t)+0.3*sin(2*PI*4800*t)*exp(-140*t)", 0.08)
	one_shot(tick, os.path.join(OUT, "hit_tick.ogg"), -8.0)
	one_shot(tone(tmp, "ding", bell(1760.0, 9.0), 0.45), os.path.join(OUT, "hit_ding.ogg"), -6.0)
	one_shot(tone(tmp, "chime", bell(1318.5, 6.0) + "+" + bell(1760.0, 5.0, 0.11), 0.75), os.path.join(OUT, "kill_chime.ogg"), -5.0)
	click = tone(tmp, "click", "0.9*(exp(-900*t)+0.8*gte(t,0.035)*exp(-900*(t-0.035)))*sin(2*PI*3100*t)", 0.08)
	one_shot(click, os.path.join(OUT, "dry_click.ogg"), -8.0)


def water(tmp: str) -> None:
	b = bubbles(tmp, "refill_b", 1.5, 12.0, 200, 520, 0.6)
	n = lavfi(tmp, "refill_n", "anoisesrc=d=1.5:c=pink:r=%d:a=0.4:seed=140,bandpass=f=900:w=900,volume='min(1,t*10)*(1-0.5*t/1.5)':eval=frame" % RATE, 1.5)
	# the pitch of the bubbling rises as the tank fills: speed the whole thing up by 25 % over its length
	raw = mix(tmp, "refill", [b, n], "lowpass=f=3000,afade=t=out:st=1.3:d=0.2")
	one_shot(raw, os.path.join(OUT, "refill.ogg"), -6.0)
	raw = lavfi(tmp, "hose", "anoisesrc=d=6:c=pink:r=%d:a=0.8:seed=150,highpass=f=500,lowpass=f=8000,tremolo=f=11:d=0.15,loudnorm=I=-20:TP=-3" % RATE, 6)
	seamless(raw, os.path.join(OUT, "hose_loop.ogg"), 4.0, 1.0)


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	with tempfile.TemporaryDirectory() as tmp:
		guns(tmp)
		markers(tmp)
		water(tmp)
	print("shooter sounds written")


if __name__ == "__main__":
	main()
