"""Build the game WAVs of tools/audio/external_sfx.json from their raw sources (audio_src/, not exported).

Deterministic: decode (ffmpeg for MP3, via skill_audition.read_audio: 44.1 kHz, mono = channel average), then the
entry's "process" in this order: start_sec (skip), trim_sec (keep this long), fade_sec (linear fade at the end),
gain_db. No normalisation: the event's gain_db in audio_events.json sets the level, as in the audition renders.
Writes 16-bit mono 44.1 kHz WAV to assets/audio/sfx/<name>.wav and prints peak / RMS per file.

python -X utf8 -I tools/audio/sfx_import.py            # build every file
python -X utf8 -I tools/audio/sfx_import.py --check    # exit 1 if a source or an output is missing
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_audition import ROOT, SR, read_audio, write_wav  # noqa: E402

MANIFEST = os.path.join(ROOT, "tools", "audio", "external_sfx.json")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")


def load_manifest():
    return json.load(open(MANIFEST, encoding="utf-8"))["files"]


def sustain_loop(x, region_from, region_to, xfade):
    """Keeps x up to the loop start, then appends a seamless loop body built from x[region_from:region_to]
    (equal-power crossfade of its tail into its head). Returns (samples, loop_begin_sample): playing once from 0,
    then repeating loop_begin..end, is click-free and level-stable (Godot AudioStreamWAV loop_begin)."""
    a = int(region_from * SR)
    b = int(region_to * SR)
    xf = int(xfade * SR)
    r = x[a:b]
    n = len(r)
    body = list(r[:n - xf])
    for i in range(xf):
        t = (i + 0.5) / xf
        body[i] = r[i] * math.sin(t * math.pi / 2) + r[n - xf + i] * math.cos(t * math.pi / 2)
    begin = b - xf  # body[0] ~ x[b - xf]: the head ends right before it, so the first pass is continuous too
    return list(x[:begin]) + body, begin


def build(name, entry):
    x = read_audio(os.path.join(ROOT, entry["source"]))
    p = entry.get("process", {})
    loop_begin = None
    if "sustain_loop" in p:
        sl = p["sustain_loop"]
        x, loop_begin = sustain_loop(x, float(sl["from"]), float(sl["to"]), float(sl["xfade"]))
    s = int(float(p.get("start_sec", 0.0)) * SR)
    x = x[s:]
    if "trim_sec" in p:
        x = x[:int(float(p["trim_sec"]) * SR)]
    fade = min(int(float(p.get("fade_sec", 0.0)) * SR), len(x))
    for i in range(fade):
        x[len(x) - fade + i] *= 1.0 - i / fade
    k = 10.0 ** (float(p.get("gain_db", 0.0)) / 20.0)
    x = [max(-1.0, min(1.0, v * k)) for v in x]
    write_wav(os.path.join(OUT_DIR, name + ".wav"), x)
    if loop_begin is not None:
        set_loop_import(name, loop_begin)
    peak = max(abs(v) for v in x) or 1e-9
    rms = math.sqrt(sum(v * v for v in x) / len(x)) or 1e-9
    print("%-40s %.3f s  peak %6.2f dBFS  rms %6.2f dBFS%s" % (name, len(x) / SR, 20 * math.log10(peak), 20 * math.log10(rms),
          "" if loop_begin is None else "  loop_begin %d (%.3f s)" % (loop_begin, loop_begin / SR)))


def set_loop_import(name, loop_begin):
    """Forward loop from loop_begin to the end in the file's .import (written once Godot has imported it; run
    `godot --headless --path . --import` after the first build, then this script again)."""
    p = os.path.join(OUT_DIR, name + ".wav.import")
    if not os.path.exists(p):
        print("  (no .import yet for %s: import with Godot, then run this script again)" % name)
        return
    lines = open(p, encoding="utf8").read().splitlines()
    want = {"edit/loop_mode": "2", "edit/loop_begin": str(loop_begin), "edit/loop_end": "-1", "compress/mode": "2"}
    out = []
    for l in lines:
        k = l.split("=", 1)[0]
        out.append(k + "=" + want.pop(k) if k in want else l)
    out += [k + "=" + v for k, v in want.items()]
    open(p, "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")


def check():
    ok = True
    for name, e in load_manifest().items():
        if not os.path.exists(os.path.join(ROOT, e["source"])):
            print("missing source:", e["source"])
            ok = False
        if not os.path.exists(os.path.join(OUT_DIR, name + ".wav")):
            print("not built:", name)
            ok = False
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    for n, e in load_manifest().items():
        build(n, e)
