"""Free procedural MOCKUPS for Hỏa Lôi's cast / seal / countdown (user direction 2026-11-09), for auditions only.

Writes to audio_src/derived/hoa_loi_mockups/ (not exported, not in the game). Deterministic (fixed seeds).
- cast_stamp_A "stone stamp": sharp click + low thump + short modal stone/arcane resonance (320/470/690 Hz).
- cast_stamp_B "arcane brand": click + resonant low-mid band of noise + a short fire hiss underneath.
- cast_stamp_C "dark lock": two-stage lock (tiny pre-click, then the main hit) with a small downward pitch drop.
- seal_armed "restrained": a soft low hum with a quiet flicker as the sigils arm (no transient, no rise).
- pulse "subtle warning pulse": a dark muffled heartbeat-like pulse with a faint ember tick (step pitch at runtime).
All 0.15-0.35 s, no rising sweep, no bells. Peaks normalised like sfx_synth (-3 dBFS).

python -X utf8 -I tools/audio/hoa_loi_mockups.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_synth as S  # noqa: E402

OUT = os.path.join(S.ROOT, "audio_src", "derived", "hoa_loi_mockups")


def sat(x, drive=2.0):
    """Soft saturation (tanh), for weight without clipping."""
    k = math.tanh(drive)
    return [math.tanh(v * drive) / k for v in x]


def modal(sec, freqs, decays, amps):
    """Sum of decaying sines (struck resonant body)."""
    n = S.n_of(sec)
    out = [0.0] * n
    for f, d, a in zip(freqs, decays, amps):
        for i in range(n):
            t = i / S.SR
            out[i] += a * math.sin(S.TAU * f * t) * math.exp(-t / d)
    return out


def click(rng, sec=0.006, lo=1800, hi=7000, amp=1.0):
    return S.gain(S.bandpass(S.noise(sec, rng, attack=0.0005, decay=sec, curve=5), lo, hi), amp)


def thump(f0, f1, sec, amp=1.0):
    """Low sine with a pitch glide f0 -> f1 and a fast decay."""
    n = S.n_of(sec)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / S.SR
        f = f0 * (f1 / f0) ** (i / max(1, n - 1))
        ph += S.TAU * f / S.SR
        out.append(amp * math.sin(ph) * math.exp(-t / (sec * 0.3)))
    return out


def stamp_a(rng):
    return sat(S.mix(click(rng, amp=0.9), thump(95, 70, 0.22, 1.0),
                     modal(0.25, [320, 470, 690], [0.07, 0.05, 0.035], [0.45, 0.3, 0.2])), 1.6)


def stamp_b(rng):
    band = S.gain(S.bandpass(S.noise(0.28, rng, attack=0.001, decay=0.12, curve=4), 300, 900), 2.2)
    hiss = S.gain(S.bandpass(S.noise(0.2, rng, attack=0.01, decay=0.12, curve=4), 2500, 7000), 0.35)
    return sat(S.mix(click(rng, amp=0.8), thump(110, 80, 0.18, 0.8), band, hiss), 1.8)


def stamp_c(rng):
    pre = click(rng, sec=0.004, lo=2500, hi=8000, amp=0.35)
    main = S.mix(click(rng, amp=1.0), thump(160, 95, 0.2, 1.0), modal(0.22, [260, 410], [0.06, 0.045], [0.4, 0.25]))
    return sat(S.mix(pre, main, offsets=[0.0, 0.035]), 1.7)


def seal_armed(rng):
    n = S.n_of(0.35)
    hum = []
    for i in range(n):
        t = i / S.SR
        e = min(1.0, t / 0.04) * math.exp(-t / 0.18)
        hum.append(e * (0.6 * math.sin(S.TAU * 140 * t) + 0.3 * math.sin(S.TAU * 280 * t + 0.4 * math.sin(S.TAU * 9 * t))))
    flicker = S.crackle(0.3, rng, 40, lo=1500, hi=4500, amp=0.35)
    return S.mix(hum, flicker)


def pulse(rng):
    return sat(S.mix(thump(120, 90, 0.16, 1.0), S.gain(S.lowpass(S.noise(0.1, rng, attack=0.002, decay=0.06), 900), 0.6),
                     S.crackle(0.08, rng, 60, lo=1500, hi=4000, amp=0.25)), 1.4)


# --- Electrical family (direction 2026-11-09: Hỏa Lôi = magical thunderstrike) -----------------------------------------

def buzz(sec, f, rng, jitter=0.08, amp=1.0):
    """Mains-like electrical buzz: a band-limited pulse train with random pitch jitter."""
    n = S.n_of(sec)
    out = []
    ph = 0.0
    for i in range(n):
        ph += S.TAU * f * (1.0 + jitter * (rng.random() * 2 - 1)) / S.SR
        s = sum(math.sin(k * ph) / k for k in range(1, 9))  # odd and even harmonics up to ~1 kHz at 120 Hz
        out.append(amp * s * 0.5)
    return out


def arcs(sec, rng, count, lo=2500, hi=8000, amp=1.0):
    """Short random electric arc snaps (band-passed noise bursts of 2-8 ms)."""
    n = S.n_of(sec)
    x = [0.0] * n
    for _ in range(count):
        i0 = int(rng.random() * max(1, n - S.n_of(0.01)))
        ln = S.n_of(0.002 + rng.random() * 0.006)
        a = 0.5 + rng.random() * 0.5
        for k in range(ln):
            x[i0 + k] += (rng.random() * 2 - 1) * a * (1.0 - k / ln)
    return S.gain(S.bandpass(x, lo, hi), amp)


def env_ad(x, attack, decay):
    out = []
    for i, v in enumerate(x):
        t = i / S.SR
        out.append(v * min(1.0, t / max(attack, 1e-4)) * math.exp(-max(0.0, t - attack) / decay))
    return out


def elec_cast(rng):
    """Subtle low electrical ignition under the Mage's gather gesture (0.25 s, soft attack, no rise)."""
    return S.mix(env_ad(buzz(0.25, 95, rng, 0.05, 0.7), 0.06, 0.12), env_ad(arcs(0.25, rng, 5, amp=0.5), 0.03, 0.15))


def elec_lock(rng):
    """Seal armed: a short distinct electric snap + low lock thunk (0.16 s)."""
    snap = arcs(0.03, rng, 3, lo=3000, hi=9000, amp=1.0)
    lock = env_ad(S.mix(buzz(0.16, 140, rng, 0.03, 0.8), thump(130, 100, 0.12, 0.9)), 0.002, 0.05)
    return sat(S.mix(snap, lock), 1.5)


def elec_pulse(rng):
    """Dry subtle warning pulse: a 70 ms electric tick (buzz blip + one arc), mid-range so phones hear it."""
    return S.mix(env_ad(buzz(0.07, 180, rng, 0.02, 0.8), 0.003, 0.025), arcs(0.02, rng, 1, lo=2000, hi=6000, amp=0.5))


# --- Fire cast (user 2026-11-09: "something slowly catching fire, then one burst") -------------------------------------

CAST_SEC = 0.45  # cards.json hoa_loi cast_time_sec: the release (seals authoritative) lands here


def fire_build(rng, sec=CAST_SEC):
    """Fire catching: crackles get denser and a low roar swells over the Mage's gesture (glyph lights every 0.05 s)."""
    n = S.n_of(sec)
    x = [0.0] * n
    for i in range(n):
        k = i / n
        if rng.random() < (20 + 260 * k * k) / S.SR:  # 20 -> 280 crackles / s
            a = 0.3 + 0.7 * k
            for j in range(min(30, n - i)):
                x[i + j] += (rng.random() * 2 - 1) * a * math.exp(-j / 5.0)
    crack = S.bandpass(x, 900, 5000)
    roar = S.lowpass([rng.random() * 2 - 1 for _ in range(n)], 700)
    roar = [v * (i / n) ** 2 * 1.4 for i, v in enumerate(roar)]
    return S.mix(crack, roar)


def fire_ignite(rng):
    """The one burst at the release: a short 'phụt' (low pop + bright flame puff), 0.22 s, well under the blast."""
    puff = env_ad(S.bandpass([rng.random() * 2 - 1 for _ in range(S.n_of(0.22))], 300, 3500), 0.004, 0.06)
    return sat(S.mix(thump(150, 85, 0.14, 1.0), S.gain(puff, 1.3), S.crackle(0.18, rng, 90, lo=1200, hi=4500, amp=0.6)), 1.6)


def cast_fire_combo(rng):
    """Audition helper: the build with the burst placed at CAST_SEC (the release), as the game would play them."""
    build = S.normalize(fire_build(rng), -9)
    burst = S.normalize(fire_ignite(rng), -3)
    return S.mix(build, burst, offsets=[0.0, CAST_SEC])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn, peak in [("cast_stamp_A", stamp_a, -3), ("cast_stamp_B", stamp_b, -3), ("cast_stamp_C", stamp_c, -3),
                           ("seal_armed", seal_armed, -3), ("pulse", pulse, -3),
                           ("elec_cast", elec_cast, -3), ("elec_lock", elec_lock, -3), ("elec_pulse", elec_pulse, -3),
                           ("fire_build", fire_build, -9), ("fire_ignite", fire_ignite, -3),
                           ("cast_fire_combo", cast_fire_combo, -3)]:
        x = S.fade_out(S.normalize(fn(random.Random(name)), peak), 0.01)
        S.write_wav(os.path.join(OUT, name + ".wav"), x)
        print("%-14s %.3f s" % (name, len(x) / S.SR))
