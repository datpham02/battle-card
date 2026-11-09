"""Measure SFX files for sound-design review (observations, not verdicts).

Per file: onset (first sample above 10 % of peak), time of the peak, peak dBFS, RMS dBFS, crest factor, the time the
10 ms envelope falls 20 dB under its maximum, and the share of energy under 200 Hz (one-pole low-pass).
Reads WAV directly; anything else via ffmpeg (tools/audio/skill_audition.py:read_audio).

python -X utf8 -I tools/audio/sfx_measure.py FILE [FILE ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_audition import SR, read_audio  # noqa: E402


def measure(path):
    x = read_audio(path)
    n = len(x)
    pk = max(abs(v) for v in x) or 1e-9
    ip = max(range(n), key=lambda i: abs(x[i]))
    on = next(i for i in range(n) if abs(x[i]) > pk * 0.1)
    win = int(0.01 * SR)
    env = [math.sqrt(sum(v * v for v in x[i:i + win]) / win) for i in range(0, n - win, win)]
    pe = max(env)
    k0 = env.index(pe)
    t20 = next((k for k in range(k0, len(env)) if env[k] < pe * 0.1), len(env)) * 0.01
    r = math.sqrt(sum(v * v for v in x) / n)
    a = 1 - math.exp(-2 * math.pi * 200 / SR)
    y = 0.0
    lo = 0.0
    for v in x:
        y += a * (v - y)
        lo += y * y
    tot = sum(v * v for v in x) or 1e-9
    return {"file": os.path.basename(path), "len": n / SR, "onset": on / SR, "peak_at": ip / SR, "peak_db": 20 * math.log10(pk),
            "rms_db": 20 * math.log10(max(r, 1e-9)), "crest_db": 20 * math.log10(pk / max(r, 1e-9)), "decay20": t20,
            "low_pct": 100 * lo / tot}


if __name__ == "__main__":
    print("%-48s %5s %6s %7s %6s %6s %6s %7s %6s" % ("file", "len", "onset", "peak@", "peak", "rms", "crest", "-20dB@", "<200Hz"))
    for p in sys.argv[1:]:
        m = measure(p)
        print("%-48s %5.2f %6.3f %7.3f %6.1f %6.1f %6.1f %7.2f %5.0f%%" % (m["file"][:48], m["len"], m["onset"], m["peak_at"],
              m["peak_db"], m["rms_db"], m["crest_db"], m["decay20"], m["low_pct"]))
