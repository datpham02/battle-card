"""Render an audition WAV of one REAL skill timeline (tools/audio/skill_timeline_dump.gd JSON).

Mix rules follow src/audio/audio_director.gd so the audition sounds like the game:
  gain  = event gain_db + step_gain_db * step (+ tier_gain_db[tier] when the event has no per-tier files)
  pitch = step_pitch_semitones * step (the game adds a random +-pitch/gain jitter; the audition leaves it out so
          takes are compared on equal terms)
  files = variants in order (the game picks one at random)
  loops = the file repeated from the voice start to the moment the bridge stopped it
  merge rows = no new sound (same-tick repeats merge into one voice in the game)
Bus volumes are 0 dB (default_bus_layout.tres); the master HardLimiter is NOT emulated: the report gives the raw peak.

--override EVENT=PATH swaps an event's files for the audition only (e.g. an ElevenLabs take for the charge);
--match-rms makes each override as loud (RMS) as the file it replaces, so a take is judged on character, not level.
Reads WAV (16-bit PCM) directly; anything else (MP3) is decoded with ffmpeg to 44.1 kHz mono first.
Nothing under assets/ is written.

python -X utf8 -I tools/audio/skill_audition.py TIMELINE.json OUT.wav [--override skill.x.y=path] [--match-rms]
    [--pre 0.5] [--tail 1.0] [--stems OUT_DIR]
"""
import argparse
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def ffmpeg_bin():
    found = shutil.which("ffmpeg")
    if found:
        return found
    link = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
    return link if os.path.exists(link) else None


def res_path(p):
    return os.path.join(ROOT, p[len("res://"):]) if p.startswith("res://") else p


def read_audio(path):
    """Mono float samples at 44.1 kHz."""
    path = res_path(path)
    if path.lower().endswith(".wav"):
        with wave.open(path, "rb") as w:
            if w.getsampwidth() == 2 and w.getframerate() == SR:
                n = w.getnframes()
                ch = w.getnchannels()
                raw = struct.unpack("<%dh" % (n * ch), w.readframes(n))
                return [sum(raw[i * ch:(i + 1) * ch]) / (ch * 32768.0) for i in range(n)]
    ff = ffmpeg_bin()
    if ff is None:
        sys.exit("ffmpeg is needed to decode %s" % path)
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "d.wav")
        subprocess.run([ff, "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SR), "-c:a", "pcm_s16le", tmp], check=True)
        return read_audio(tmp)


def rms(x):
    return math.sqrt(sum(v * v for v in x) / max(len(x), 1))


def repitch(x, semis):
    if abs(semis) < 1e-6:
        return x
    r = 2.0 ** (semis / 12.0)
    n = int(len(x) / r)
    out = []
    for i in range(n):
        p = i * r
        j = int(p)
        f = p - j
        a = x[j]
        b = x[j + 1] if j + 1 < len(x) else 0.0
        out.append(a + (b - a) * f)
    return out


def write_wav(path, x, peak_db=None):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767))))) for v in x))


def db(v):
    return 20.0 * math.log10(max(v, 1e-9))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("out")
    ap.add_argument("--override", action="append", default=[])
    ap.add_argument("--match-rms", action="store_true")
    ap.add_argument("--pre", type=float, default=0.5)
    ap.add_argument("--tail", type=float, default=1.0)
    ap.add_argument("--stems", default="")
    ap.add_argument("--pitch", action="append", default=[], help="EVENT=semitones, audition-only transpose")
    ap.add_argument("--gain", action="append", default=[], help="EVENT=dB, audition-only gain offset")
    ap.add_argument("--trim", action="append", default=[], help="EVENT=sec, cut each sound of EVENT to sec (40 ms fade)")
    ap.add_argument("--loop-begin", action="append", default=[], help="EVENT=sec, a loop event plays once, then repeats "
                    "from sec to the end (Godot AudioStreamWAV loop_begin)")
    a = ap.parse_args()
    loop_begin = {k: float(v) for k, v in (p.split("=", 1) for p in a.loop_begin)}
    trim = {k: float(v) for k, v in (p.split("=", 1) for p in a.trim)}
    pitch_off = {k: float(v) for k, v in (p.split("=", 1) for p in a.pitch)}
    gain_off = {k: float(v) for k, v in (p.split("=", 1) for p in a.gain)}

    tl = json.load(open(a.timeline, encoding="utf-8"))
    bank = json.load(open(os.path.join(ROOT, "assets", "data", "audio_events.json"), encoding="utf-8"))
    events = bank["events"]
    defaults = bank["defaults"]
    tier_gain = bank["tier_gain_db"]
    overrides = dict(o.split("=", 1) for o in a.override)

    cache = {}

    def load(p):
        if p not in cache:
            cache[p] = read_audio(p)
        return cache[p]

    # loop ends from the voice spans
    loop_end = {}
    for v in tl["voices"]:
        if v.get("loop"):
            loop_end[(v["id"], round(v["start"], 4))] = v["end"]

    t0 = tl["swing_start_clock"] - a.pre
    plays = [r for r in tl["log"] if r["op"] == "play"]
    end_clock = 0.0
    used = {}
    layers = []
    for r in plays:
        ev = events.get(r["id"], {})
        files = ev.get("files", [])
        tier = str(r.get("tier", "M"))
        tier_files = ev.get("tier_files", {})
        if isinstance(tier_files, dict) and tier in tier_files:
            files = tier_files[tier]
        if not files:
            continue
        n = used.get(r["id"], 0)
        used[r["id"]] = n + 1
        src = files[n % len(files)]
        x = load(src)
        if r["id"] in overrides:
            # a comma list of files plays them in turn (like an event's variants)
            choices = overrides[r["id"]].split(",")
            pick = choices[n % len(choices)]
            o = load(pick)
            if a.match_rms:
                k = rms(x) / max(rms(o), 1e-9)
                o = [v * k for v in o]
            x, src = o, pick
        if r["id"] in trim:
            cut = int(trim[r["id"]] * SR)
            if cut < len(x):
                x = list(x[:cut])
                fade = min(int(0.04 * SR), cut)
                for i in range(fade):
                    x[cut - fade + i] *= 1.0 - i / fade
        step = int(r.get("step", 0) or 0)
        g = float(ev.get("gain_db", defaults["gain_db"])) + float(ev.get("step_gain_db", 0.0)) * step
        if not tier_files:
            g += float(tier_gain.get(tier, 0.0))
        g += gain_off.get(r["id"], 0.0)
        x = repitch(x, float(ev.get("step_pitch_semitones", 0.0)) * step + pitch_off.get(r["id"], 0.0))
        start = float(r["clock"])
        if ev.get("loop"):
            # the voice start in the pool is the frame after the log row; match by the nearest span
            ends = [e for (i, s), e in loop_end.items() if i == r["id"] and abs(s - start) < 0.05]
            stop = ends[0] if ends and ends[0] > 0 else start + 2.0
            need = int((stop - start) * SR)
            reps = list(x)
            seg = x[int(loop_begin.get(r["id"], 0.0) * SR):] or x
            while len(reps) < need:
                reps.extend(seg)
            x = reps[:need]
            fade = min(int(0.03 * SR), len(x))
            for i in range(fade):
                x[len(x) - fade + i] *= 1.0 - i / fade
        k = 10.0 ** (g / 20.0)
        layers.append({"id": r["id"], "start": start, "x": [v * k for v in x], "src": os.path.relpath(res_path(src), ROOT),
                       "gain_db": round(g, 2), "step": step, "tier": tier})
        end_clock = max(end_clock, start + len(x) / SR)

    total = int((end_clock - t0 + a.tail) * SR)
    mix = [0.0] * total
    for L in layers:
        off = int(round((L["start"] - t0) * SR))
        for i, v in enumerate(L["x"]):
            if 0 <= off + i < total:
                mix[off + i] += v
    peak = max(abs(v) for v in mix) if mix else 0.0
    write_wav(a.out, mix)
    if a.stems:
        by_id = {}
        for L in layers:
            by_id.setdefault(L["id"], []).append(L)
        for i, ls in by_id.items():
            s = [0.0] * total
            for L in ls:
                off = int(round((L["start"] - t0) * SR))
                for j, v in enumerate(L["x"]):
                    if 0 <= off + j < total:
                        s[off + j] += v
            write_wav(os.path.join(a.stems, i.replace(".", "_") + ".wav"), s)
    report = {"out": os.path.relpath(a.out, ROOT), "timeline": os.path.relpath(a.timeline, ROOT), "pre_sec": a.pre,
              "overrides": overrides, "match_rms": a.match_rms, "peak_dbfs": round(db(peak), 2), "rms_dbfs": round(db(rms(mix)), 2),
              "clipped": peak > 1.0, "duration_sec": round(total / SR, 3),
              "layers": [{k: L[k] for k in ("id", "start", "src", "gain_db", "step", "tier")} |
                         {"t_in_file": round(L["start"] - t0, 3), "len_sec": round(len(L["x"]) / SR, 3),
                          "peak_dbfs": round(db(max(abs(v) for v in L["x"])), 2)} for L in layers]}
    with open(os.path.splitext(a.out)[0] + ".json", "w", encoding="utf-8") as f:
        json.dump(report, f, indent=1, ensure_ascii=False)
    print("%s  peak %.2f dBFS  rms %.2f dBFS  %d layers  %.2f s%s" % (report["out"], report["peak_dbfs"], report["rms_dbfs"],
          len(layers), report["duration_sec"], "  CLIPPED" if report["clipped"] else ""))


if __name__ == "__main__":
    main()
