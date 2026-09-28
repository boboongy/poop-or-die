"""The toilet's background sounds (SPEC "Round 2" Stage 2), all made here, so there is no licence question (audio/SOURCES.md "Made here").

Run from the project folder:  python tools/make_ambience.py
Needs ffmpeg, and for the voices piper-tts + the models (see tools/make_voices.py). Writes:
  audio/ambience/hum_loop.ogg         fluorescent tubes (120 Hz and harmonics) + ventilation air, a seamless 12 s loop
  (the queue's muttering, chatter_loop.ogg, was replaced in Stage 6 by tools/make_character_sounds.py gibberish_loop.ogg: owner "sounds like men")
  audio/ambience/groan_NN.ogg         groans and straining from inside a stall (Piper voices, muffled by the door)
  audio/body/fart_NN.ogg              a cartoon fart set, synthesised (a buzz whose pitch wobbles, with a sputter and a little air)
"""
import os
import subprocess
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AMB = os.path.join(ROOT, "audio", "ambience")
BODY = os.path.join(ROOT, "audio", "body")
MODELS = os.path.join(os.environ.get("LOCALAPPDATA", ""), "piper-voices")
RATE = 44100

# Same voices as the generic Jijios (tools/make_voices.py CASTS), public domain / CC0.
VOICES = [("en_US-bryce-medium", 1.12), ("en_US-kristin-medium", 1.05), ("en_US-norman-medium", 1.15)]
GROANS = [
	"Hnnnnnngh...", "Oh no. Oh no no no.", "Come on... come on...", "Ugh. My stomach.", "Why did I eat that burrito.",
	"Hhhhmmmph!", "Ooooh...", "Almost... almost...",
]
# Farts: base pitch Hz, wobble depth (0..1), wobble Hz, seconds, pitch drop over the sound (0..1), sputter Hz (0 = none), loudness LUFS
FARTS = [
	(115, 0.18, 9.0, 0.35, 0.10, 0.0, -16), # short pfft
	(85, 0.30, 7.0, 1.40, 0.35, 0.0, -15), # long rip
	(185, 0.25, 11.0, 0.80, -0.25, 0.0, -17), # squeaky, rising
	(72, 0.20, 5.0, 1.10, 0.20, 9.0, -16), # wet sputter
	(95, 0.22, 6.0, 1.00, 0.15, 5.5, -16), # stutter, three bursts
	(68, 0.35, 4.5, 1.90, 0.30, 0.0, -12), # the big one (Level 3 intro)
]


def ffmpeg(*args: str) -> None:
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


def seamless(src: str, dst: str, length: float, cross: float, extra_filter: str = "") -> None:
	"""A loop of `length` s from `src` (at least length + cross long): x[cross, length+cross) with its last `cross` s crossfaded into
	x[0, cross), so the end flows into the start (which is x(cross))."""
	body_end = length  # x[cross : length] kept as is
	fc = (
		"[0:a]asplit=3[a][b][c];"
		"[a]atrim=%f:%f,asetpts=PTS-STARTPTS[body];" % (cross, body_end) +
		"[b]atrim=%f:%f,asetpts=PTS-STARTPTS,afade=t=out:st=0:d=%f[tail];" % (length, length + cross, cross) +
		"[c]atrim=0:%f,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=%f[head];" % (cross, cross) +
		"[tail][head]amix=inputs=2:normalize=0[join];[body][join]concat=n=2:v=0:a=1%s[out]" % ("," + extra_filter if extra_filter else "")
	)
	ffmpeg("-i", src, "-filter_complex", fc, "-map", "[out]", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst)


def hum(tmp: str) -> None:
	raw = os.path.join(tmp, "hum.wav")
	# tube hum: 120 Hz and harmonics (whole cycles in any length), plus low air
	expr = "0.10*sin(2*PI*120*t)+0.05*sin(2*PI*240*t)+0.025*sin(2*PI*360*t)+0.012*sin(2*PI*480*t)"
	ffmpeg("-f", "lavfi", "-i", "aevalsrc=%s:s=%d:d=14" % (expr, RATE), "-f", "lavfi", "-i", "anoisesrc=d=14:c=brown:r=%d:a=0.35" % RATE,
		"-filter_complex", "[1:a]lowpass=f=500,highpass=f=40[air];[0:a][air]amix=inputs=2:normalize=0,loudnorm=I=-24:TP=-3", "-ac", "1", raw)
	seamless(raw, os.path.join(AMB, "hum_loop.ogg"), 12.0, 1.5)


def groans(tmp: str) -> None:
	from piper import PiperVoice, SynthesisConfig
	n = 0
	for i, (model, pitch) in enumerate(VOICES):
		voice = PiperVoice.load(os.path.join(MODELS, model + ".onnx"))
		for k, line in enumerate(GROANS):
			if (k + i) % 3 == 0: # each voice says two thirds of the lines: 16 files
				continue
			raw = os.path.join(tmp, "g.wav")
			with wave.open(raw, "wb") as w:
				voice.synthesize_wav(line, w, syn_config=SynthesisConfig(length_scale=1.35, noise_scale=0.9))
			rate = voice.config.sample_rate
			n += 1
			# through a stall door: low-passed, a small boxy echo, 30 ms lead-in (the engine fades sounds in)
			ffmpeg("-i", raw, "-af", "asetrate=%d,aresample=%d,atempo=%.4f,lowpass=f=1600,aecho=0.7:0.4:18:0.3,adelay=30,loudnorm=I=-18:TP=-2,aresample=%d"
				% (int(rate * pitch * 0.95), rate, 1.0 / (pitch * 0.95), RATE), "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", os.path.join(AMB, "groan_%02d.ogg" % n))


def farts() -> None:
	for i, (f0, depth, wob, dur, drop, sputter, lufs) in enumerate(FARTS):
		# pitch f(t) = f0 (1 - drop t/d) (1 + depth sin(2 pi wob t)); its phase is the integral (the wobble part exactly, the drop by t^2)
		phase = "2*PI*%f*(t-%f*t*t/(2*%f))-%f*cos(2*PI*%f*t)" % (f0, drop, dur, f0 * depth / wob, wob)
		env = "min(1,t/0.015)*pow(max(0,1-t/%f),0.55)" % dur
		chop = "(0.55+0.45*sin(2*PI*%f*t))" % sputter if sputter else "1"
		expr = "(tanh(3.5*sin(%s))*0.8+0.25*(random(0)*2-1))*%s*%s" % (phase, env, chop)
		out = os.path.join(BODY, "fart_%02d.ogg" % (i + 1))
		ffmpeg("-f", "lavfi", "-i", "aevalsrc='%s':s=%d:d=%f" % (expr, RATE, dur + 0.05),
			"-af", "lowpass=f=1100,highpass=f=45,adelay=30,loudnorm=I=%d:TP=-1.5,aresample=%d" % (lufs, RATE), "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", out)


def main() -> None:
	os.makedirs(AMB, exist_ok=True)
	with tempfile.TemporaryDirectory() as tmp:
		farts()
		hum(tmp)
		groans(tmp)
	for folder in (AMB, BODY):
		for f in sorted(os.listdir(folder)):
			if f.endswith(".ogg"):
				out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", os.path.join(folder, f)], capture_output=True, text=True)
				print("%-22s %s s" % (f, out.stdout.strip()))


if __name__ == "__main__":
	main()
