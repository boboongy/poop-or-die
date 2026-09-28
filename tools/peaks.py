"""Where a recording gets loud: prints the peak (dBFS) of every 0.25 s window above a threshold. Used on the windowed recordings of
tests/probe_soundscape.gd / probe_level5_sound.gd.  python tools/peaks.py <file.wav> [threshold_db=-3]"""
import math
import subprocess
import sys

path = sys.argv[1]
threshold = float(sys.argv[2]) if len(sys.argv) > 2 else -3.0
# both channels: a panned 3D sound can clip one side while a mono downmix stays under (first version missed 0 dB peaks)
raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "2", "-ar", "44100", "-"], capture_output=True, check=True).stdout
samples = memoryview(raw).cast("h")
n = len(samples)
win = 2 * 44100 // 4
for start in range(0, n, win):
	peak = max((abs(x) for x in samples[start:min(start + win, n)]), default=0) / 32768.0
	db = 20 * math.log10(peak) if peak > 0 else -120.0
	if db >= threshold:
		print("%6.2f s  %6.1f dB" % (start / 88200.0, db))
