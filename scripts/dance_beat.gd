extends RefCounted
## Level 5: the dance battle's beat, SYNTHESISED here (no file, no licence question; the exact tempo keeps the arrows on the beat).
## A PLACEHOLDER boom-bap drum loop (kick, snare, hi-hat) until a real CC0 loop with a known tempo is found (SPEC "Level 5",
## audio/SOURCES.md). build() returns a looping 16-bit mono AudioStreamWAV, BARS bars long, starting on beat 1.

const BPM := 100
const BARS := 2
const RATE := 22050
## 16 steps (sixteenth notes) per bar. K = kick, S = snare; hats play on every 8th note.
const KICKS := [[0, 7, 8, 10], [0, 7, 10, 14]]
const SNARES := [4, 12]


static func beat_seconds() -> float:
	return 60.0 / BPM


static func build() -> AudioStreamWAV:
	var step := beat_seconds() / 4.0
	var total := int(round(beat_seconds() * 4.0 * BARS * RATE))
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for bar in BARS:
		for s in 16:
			var at := int(round((bar * 16 + s) * step * RATE))
			if s in KICKS[bar % KICKS.size()]:
				_kick(buf, at)
			if s in SNARES:
				_snare(buf, at, rng)
			if s % 2 == 0:
				_hat(buf, at, rng, 0.22 if s % 4 == 0 else 0.14)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav


## The loudest sample (0..1) between `from` and `to` seconds (tests).
static func peak(wav: AudioStreamWAV, from: float, to: float) -> float:
	var a := maxi(int(from * wav.mix_rate), 0)
	var b := mini(int(to * wav.mix_rate), int(wav.data.size() / 2.0)) # 16-bit samples
	var best := 0.0
	for i in range(a, b):
		best = maxf(best, absf(wav.data.decode_s16(i * 2) / 32767.0))
	return best


## A falling sine thump, 120 -> 45 Hz.
static func _kick(buf: PackedFloat32Array, at: int) -> void:
	var n := mini(int(0.35 * RATE), buf.size() - at)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (45.0 + 75.0 * exp(-t / 0.04)) / RATE
		buf[at + i] += 0.9 * sin(phase) * exp(-t / 0.07)


## A noise crack with a little tone.
static func _snare(buf: PackedFloat32Array, at: int, rng: RandomNumberGenerator) -> void:
	var n := mini(int(0.25 * RATE), buf.size() - at)
	for i in n:
		var t := float(i) / RATE
		buf[at + i] += 0.45 * rng.randf_range(-1.0, 1.0) * exp(-t / 0.05) + 0.3 * sin(TAU * 190.0 * t) * exp(-t / 0.04)


## A short tick of high noise (the difference of two random values removes the low end).
static func _hat(buf: PackedFloat32Array, at: int, rng: RandomNumberGenerator, level: float) -> void:
	var n := mini(int(0.06 * RATE), buf.size() - at)
	var last := 0.0
	for i in n:
		var t := float(i) / RATE
		var r := rng.randf_range(-1.0, 1.0)
		buf[at + i] += level * (r - last) * 0.5 * exp(-t / 0.015)
		last = r
