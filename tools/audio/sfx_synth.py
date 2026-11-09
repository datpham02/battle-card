#!/usr/bin/env python3
"""Tessera procedural SFX synthesiser (docs/skill-v2/10-audio-system-design.md §5–§9).

Pure Python standard library. Every sound is synthesised from oscillators, filtered noise and envelopes by the recipes
below: original material, no samples, no paid tool, no generator service. Output: 16-bit mono 44.1 kHz WAV under
assets/audio/sfx/, named sfx_<category>_<subject>_<action>_<nn>.wav (tier files _s/_m/_l), plus assets/audio/CREDITS.md
(one line per file). Deterministic: the noise seed is the file name, so a re-run writes identical files.

Usage (from the repo root):
    python -X utf8 -I tools/audio/sfx_synth.py            # write every WAV + CREDITS.md
    python -X utf8 -I tools/audio/sfx_synth.py --check    # exit 1 if audio_events.json and the recipes disagree
    python -X utf8 -I tools/audio/sfx_synth.py --qoa      # after `godot --import`: set every SFX .import to QOA, reimport

Mix rules applied here: peaks normalised to -3 dBFS (warnings -1 dBFS, UI -6 dBFS); warnings keep their energy in
1-3 kHz (never only above 4 kHz, accessibility); short, transient-first.
"""

import json
import math
import os
import random
import struct
import sys
import wave
import zlib

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVENTS_JSON = os.path.join(ROOT, "assets", "data", "audio_events.json")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
CREDITS = os.path.join(ROOT, "assets", "audio", "CREDITS.md")
TAU = 2.0 * math.pi


# --- building blocks -------------------------------------------------------------------------------------------------

def n_of(sec):
    return max(1, int(round(sec * SR)))


def silence(sec):
    return [0.0] * n_of(sec)


def env(n, attack=0.002, decay=0.2, hold=0.0, curve=4.0):
    """Attack (linear) -> hold -> exponential-ish decay to 0 over the rest of n samples."""
    a = max(1, int(attack * SR))
    h = int(hold * SR)
    out = []
    rest = max(1, n - a - h)
    d = max(decay, 1e-4)
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + h:
            out.append(1.0)
        else:
            t = (i - a - h) / SR
            lin = max(0.0, 1.0 - (i - a - h) / rest)
            out.append(math.exp(-t * curve / d) * lin)
    return out


def swell(n, power=2.0):
    """0 -> 1 rise over n samples (pressure, wind-ups)."""
    return [(i / max(1, n - 1)) ** power for i in range(n)]


def tone(sec, f0, f1=None, shape="sine", amp=1.0, attack=0.002, decay=None, curve=4.0, glide="exp", phase=0.0):
    n = n_of(sec)
    f1 = f0 if f1 is None else f1
    e = env(n, attack, decay if decay is not None else sec, 0.0, curve)
    out = []
    ph = phase
    for i in range(n):
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** k if glide == "exp" and f0 > 0 and f1 > 0 else f0 + (f1 - f0) * k
        ph += TAU * f / SR
        if shape == "sine":
            s = math.sin(ph)
        elif shape == "tri":
            s = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "square":  # band-limited-ish: odd harmonics 1..7
            s = sum(math.sin(ph * h) / h for h in (1, 3, 5, 7)) * 0.9
        elif shape == "saw":
            s = sum(math.sin(ph * h) / h for h in range(1, 9)) * 0.6
        else:
            raise ValueError(shape)
        out.append(s * e[i] * amp)
    return out


def bell(sec, f, partials=(1.0, 2.0, 3.01), amps=(1.0, 0.5, 0.25), amp=1.0, decay=None):
    out = silence(sec)
    for p, a in zip(partials, amps):
        layer = tone(sec, f * p, amp=a * amp, decay=(decay or sec) / (1 + 0.6 * (p - 1)), curve=5.0)
        out = mix(out, layer)
    return out


def noise(sec, rng, amp=1.0, attack=0.002, decay=None, curve=4.0):
    n = n_of(sec)
    e = env(n, attack, decay if decay is not None else sec, 0.0, curve)
    return [(rng.random() * 2.0 - 1.0) * e[i] * amp for i in range(n)]


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a float or a (start, end) sweep."""
    out = []
    y = 0.0
    n = len(x)
    for i, s in enumerate(x):
        c = cutoff if not isinstance(cutoff, tuple) else cutoff[0] * (cutoff[1] / cutoff[0]) ** (i / max(1, n - 1))
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, lo, hi):
    """Two passes each side for a steeper band."""
    y = highpass(highpass(x, lo), lo)
    return lowpass(lowpass(y, hi), hi)


def resonator(x, f, q=30.0):
    """Two-pole resonant band-pass (biquad, constant peak gain) at f."""
    w = TAU * f / SR
    alpha = math.sin(w) / (2.0 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for s in x:
        y = (b0 * s + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, s
        y2, y1 = y1, y
        out.append(y)
    return out


def crackle(sec, rng, density=60.0, lo=800.0, hi=4000.0, amp=1.0, fade=True):
    """Sparse random clicks (embers, pebbles)."""
    n = n_of(sec)
    x = [0.0] * n
    p = density / SR
    for i in range(n):
        if rng.random() < p:
            a = (rng.random() * 0.7 + 0.3) * (1.0 - i / n if fade else 1.0)
            for k in range(min(40, n - i)):
                x[i + k] += (rng.random() * 2 - 1) * a * math.exp(-k / 6.0)
    return [v * amp for v in bandpass(x, lo, hi)]


def mix(*layers, offsets=None):
    offsets = offsets or [0.0] * len(layers)
    n = max(n_of(o) + len(l) for l, o in zip(layers, offsets)) if layers else 0
    out = [0.0] * n
    for l, o in zip(layers, offsets):
        start = int(round(o * SR))
        for i, s in enumerate(l):
            out[start + i] += s
    return out


def at(layer, offset):
    return (layer, offset)


def place(*pairs):
    return mix(*[p[0] for p in pairs], offsets=[p[1] for p in pairs])


def gain(x, g):
    return [s * g for s in x]


def amp_mod(x, rate, depth):
    return [s * (1.0 - depth + depth * (0.5 + 0.5 * math.sin(TAU * rate * i / SR))) for i, s in enumerate(x)]


def fade_out(x, sec=0.01):
    n = min(len(x), n_of(sec))
    out = list(x)
    for i in range(n):
        out[len(x) - n + i] *= 1.0 - (i + 1) / n
    return out


def normalize(x, peak_db):
    peak = max(1e-9, max(abs(s) for s in x))
    g = 10 ** (peak_db / 20.0) / peak
    return [s * g for s in x]


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(round(s * 32767))))) for s in x))


# --- shared gestures -------------------------------------------------------------------------------------------------

def thud(rng, f0=110.0, f1=50.0, sec=0.3, amp=1.0):
    return mix(tone(sec, f0, f1, amp=amp, decay=sec * 0.6, curve=5.0),
               gain(lowpass(noise(0.04, rng, decay=0.03), 400.0), amp * 0.8))


def clack(rng, body=400.0, sec=0.12, amp=1.0):
    click = bandpass(noise(sec, rng, decay=sec * 0.25, curve=6.0), 700.0, 3200.0)
    return mix(gain(click, amp * 2.2), tone(sec, body * 1.05, body, amp=amp * 0.6, decay=sec * 0.4, curve=6.0))


def whoosh(rng, sec, lo, hi, rise=True, amp=1.0):
    n = noise(sec, rng, attack=sec * (0.6 if rise else 0.05), decay=sec * (0.4 if rise else 0.9))
    sweep = (lo, hi) if rise else (hi, lo)
    return gain(lowpass(highpass(n, lo * 0.5), sweep), amp * 2.5)


def ping(f, sec=0.15, amp=1.0):
    return bell(sec, f, partials=(1.0, 2.76, 5.4), amps=(1.0, 0.35, 0.12), amp=amp)


def steel_ring(f, sec=0.9, amp=1.0):
    return bell(sec, f, partials=(1.0, 1.58, 2.21, 2.75), amps=(1.0, 0.6, 0.4, 0.25), amp=amp)


# --- recipes: name -> (function(rng, v) -> samples, peak dBFS, description) -------------------------------------------

R = {}


def recipe(base, peak=-3.0, desc="", variants=1, tiers=None):
    def deco(fn):
        if tiers:
            for t in tiers:
                R[f"{base}_{t.lower()}_01"] = (lambda rng, t=t: fn(rng, t), peak, f"{desc} (tier {t})")
        else:
            for v in range(1, variants + 1):
                R[f"{base}_{v:02d}"] = (lambda rng, v=v: fn(rng, v), peak, desc + (f" (variant {v})" if variants > 1 else ""))
        return fn
    return deco


# UI / Block / card (wood and stone family, not sci-fi)
@recipe("sfx_ui_tap", -6, "short wood tick", variants=2)
def _(rng, v):
    f = 880 * (1.0 if v == 1 else 1.08)
    return mix(tone(0.05, f, f * 0.8, amp=0.7, decay=0.02, curve=6), gain(bandpass(noise(0.02, rng, decay=0.006), 1500, 4000), 0.9))


@recipe("sfx_ui_back", -6, "two descending wood ticks")
def _(rng, v):
    return place(at(tone(0.05, 800, 700, decay=0.02, curve=6), 0.0), at(tone(0.06, 600, 520, decay=0.025, curve=6), 0.06))


@recipe("sfx_ui_toggle", -6, "two quick rising ticks")
def _(rng, v):
    return place(at(tone(0.04, 1000, decay=0.015, curve=6), 0.0), at(tone(0.05, 1300, decay=0.02, curve=6), 0.03))


@recipe("sfx_block_pickup", -6, "stone clack, pitch by Block size", tiers=["S", "M", "L"])
def _(rng, t):
    body = {"S": 560.0, "M": 400.0, "L": 270.0}[t]
    return clack(rng, body, 0.12 + 0.03 * ["S", "M", "L"].index(t))


@recipe("sfx_block_select", -6, "light lift, airy rising tone")
def _(rng, v):
    return mix(tone(0.09, 600, 900, amp=0.6, attack=0.01, decay=0.06), gain(bandpass(noise(0.08, rng, attack=0.02, decay=0.05), 1200, 3500), 0.6))


@recipe("sfx_block_place", -4, "firm stone set: low thud and clack", variants=2)
def _(rng, v):
    return mix(thud(rng, 150 if v == 1 else 135, 80, 0.18), clack(rng, 330 if v == 1 else 300, 0.1, 0.8))


@recipe("sfx_block_invalid", -6, "one muted buzz")
def _(rng, v):
    b = lowpass(tone(0.13, 180, shape="square", amp=0.8, attack=0.004, decay=0.1, curve=2), 1200)
    return place(at(b, 0.0), at(gain(b, 0.6), 0.14))


@recipe("sfx_block_confirm", -4, "two-stone lock")
def _(rng, v):
    return place(at(clack(rng, 330, 0.1), 0.0), at(clack(rng, 470, 0.12), 0.07))


@recipe("sfx_block_slot_full", -6, "dull knock, twice")
def _(rng, v):
    k = mix(tone(0.12, 220, 190, decay=0.06, curve=5), gain(lowpass(noise(0.05, rng, decay=0.02), 900), 0.8))
    return place(at(k, 0.0), at(gain(k, 0.7), 0.11))


@recipe("sfx_card_menu_open", -5, "paper flip and soft rune hum")
def _(rng, v):
    flip = gain(bandpass(noise(0.18, rng, attack=0.05, decay=0.1), 1000, 5000), 1.6)
    hum = mix(tone(0.4, 330, amp=0.35, attack=0.08, decay=0.3), tone(0.4, 495, amp=0.2, attack=0.1, decay=0.3))
    return mix(flip, hum)


@recipe("sfx_card_highlight", -8, "soft tick")
def _(rng, v):
    return tone(0.03, 1400, 1300, amp=0.8, decay=0.012, curve=6)


@recipe("sfx_card_choose", -4, "bright confirm bell")
def _(rng, v):
    return mix(ping(880, 0.3), gain(ping(1320, 0.3), 0.6))


@recipe("sfx_card_unavailable", -5, "dull locked click")
def _(rng, v):
    return mix(lowpass(clack(rng, 160, 0.08), 900), tone(0.06, 160, 140, amp=0.6, decay=0.03))


@recipe("sfx_card_ready", -9, "soft ready tone")
def _(rng, v):
    return ping(1046, 0.32, 0.8)


# Generic combat
@recipe("sfx_combat_hit_player", -3, "body hit: low thump and crunch", variants=2)
def _(rng, v):
    return mix(thud(rng, 95 if v == 1 else 85, 55, 0.2), gain(bandpass(noise(0.12, rng, decay=0.05), 600, 2500), 1.4))


@recipe("sfx_combat_hit_enemy", -3, "impact smack", variants=2)
def _(rng, v):
    return mix(thud(rng, 150 if v == 1 else 170, 80, 0.16), gain(bandpass(noise(0.1, rng, decay=0.035), 1000, 4000), 1.5))


@recipe("sfx_combat_interrupt", -3, "broken whoosh cut by a thud (NGAT!)")
def _(rng, v):
    w = whoosh(rng, 0.18, 500, 2500, rise=True)
    return place(at(w, 0.0), at(thud(rng, 120, 45, 0.3), 0.17), at(gain(clack(rng, 250, 0.1), 0.7), 0.17))


@recipe("sfx_combat_parry", -3, "metallic clang")
def _(rng, v):
    return mix(steel_ring(1200, 0.5), gain(bandpass(noise(0.03, rng, decay=0.01), 1500, 5000), 1.2))


@recipe("sfx_combat_crit", -3, "sharp crack, ping and thump")
def _(rng, v):
    return mix(gain(bandpass(noise(0.06, rng, decay=0.02), 1200, 5000), 1.6), ping(1600, 0.25, 0.7), thud(rng, 130, 60, 0.2, 0.8))


@recipe("sfx_combat_death", -3, "falling low tone with dust")
def _(rng, v):
    return mix(tone(0.9, 200, 60, amp=0.8, attack=0.01, decay=0.8, curve=3), gain(lowpass(noise(0.9, rng, attack=0.05, decay=0.7), 700), 0.6))


@recipe("sfx_combat_hp_low", -6, "heartbeat lub-dub")
def _(rng, v):
    beat = tone(0.14, 70, 50, decay=0.1, curve=4)
    return place(at(beat, 0.0), at(gain(beat, 0.75), 0.2), at(silence(0.3), 0.34))


@recipe("sfx_combat_lock", -5, "short bright lock clink")
def _(rng, v):
    return mix(ping(2000, 0.14), gain(ping(3000, 0.1), 0.4), gain(clack(rng, 600, 0.05), 0.5))


# Boss warnings: energy in 1-3 kHz, never only above 4 kHz
@recipe("sfx_warn_boss_windup", -1, "low drum hit, armour shift and rattle (1-2.5 kHz)")
def _(rng, v):
    drum = thud(rng, 90, 50, 0.35)
    cloth = gain(bandpass(noise(0.25, rng, attack=0.08, decay=0.15), 300, 1500), 1.2)
    rattle = gain(crackle(0.22, rng, density=120, lo=1500, hi=2500), 2.0)
    return mix(drum, cloth, rattle)


@recipe("sfx_warn_boss_imminent", -1, "two-note rising alarm, 1.1 then 1.65 kHz")
def _(rng, v):
    a = lowpass(tone(0.12, 1100, shape="square", attack=0.004, decay=0.11, curve=1.5), 3500)
    b = lowpass(tone(0.17, 1650, shape="square", attack=0.004, decay=0.16, curve=1.5), 3500)
    return place(at(a, 0.0), at(b, 0.13))


@recipe("sfx_warn_boss_recovery", -3, "soft descending exhale chime (opening)")
def _(rng, v):
    return mix(tone(0.5, 1320, 880, amp=0.7, attack=0.01, decay=0.45), gain(lowpass(noise(0.45, rng, attack=0.05, decay=0.35), 1500), 0.4))


@recipe("sfx_warn_terrain_vent", -1, "vent hiss over a rising rumble (1-3 kHz)")
def _(rng, v):
    hiss = gain(bandpass(noise(0.6, rng, attack=0.2, decay=0.35), 1000, 3000), 1.6)
    rumble = gain(lowpass(noise(0.6, rng, attack=0.3, decay=0.3), 200), 1.5)
    return mix(hiss, rumble)


# Stingers (placeholders until music, decision A8)
@recipe("sfx_flow_victory", -3, "major arpeggio stinger")
def _(rng, v):
    notes = [523.25, 659.25, 783.99, 1046.5]
    layers = [at(bell(1.2, f, amp=0.8), i * 0.13) for i, f in enumerate(notes)]
    layers.append(at(gain(tone(1.6, 261.6, attack=0.2, decay=1.4, curve=2), 0.3), 0.0))
    return place(*layers)


@recipe("sfx_flow_defeat", -3, "falling minor phrase over a low drone")
def _(rng, v):
    notes = [440.0, 349.2, 293.7]
    layers = [at(bell(1.0, f, amp=0.8, decay=0.9), i * 0.32) for i, f in enumerate(notes)]
    layers.append(at(gain(tone(2.0, 110, attack=0.3, decay=1.6, curve=2), 0.4), 0.0))
    return place(*layers)


# Generic skill archetype
@recipe("sfx_skill_generic_windup", -5, "rising wind-up whoosh", variants=2)
def _(rng, v):
    return whoosh(rng, 0.35 if v == 1 else 0.3, 400, 1500 if v == 1 else 1800, rise=True)


@recipe("sfx_skill_generic_commit", -4, "release whoosh with a thump")
def _(rng, v):
    return mix(whoosh(rng, 0.2, 600, 2000, rise=False), thud(rng, 140, 70, 0.15, 0.7))


@recipe("sfx_skill_generic_travel", -8, "soft air rush")
def _(rng, v):
    return gain(lowpass(noise(0.3, rng, attack=0.08, decay=0.2), (600, 1400)), 1.5)


@recipe("sfx_skill_generic_hit", -5, "crunchy hit confirm")
def _(rng, v):
    return mix(gain(bandpass(noise(0.06, rng, decay=0.02), 1000, 3000), 1.6), tone(0.06, 700, 500, amp=0.6, decay=0.03))


@recipe("sfx_skill_generic_cancel", -5, "descending scatter")
def _(rng, v):
    return place(*[at(ping(f, 0.12, 0.7), i * 0.045) for i, f in enumerate([1500, 1250, 1000, 800, 640])])


@recipe("sfx_skill_generic_fizzle", -7, "dry pop")
def _(rng, v):
    return mix(gain(lowpass(noise(0.05, rng, decay=0.015), 1000), 1.4), tone(0.05, 300, 200, amp=0.5, decay=0.02))


@recipe("sfx_skill_impact_burst", -3, "burst: deep thud and blast")
def _(rng, v):
    return mix(thud(rng, 110, 45, 0.45), gain(lowpass(noise(0.5, rng, decay=0.3), (2500, 500)), 1.6))


@recipe("sfx_skill_impact_slash", -3, "slash: sharp swish and blade ring")
def _(rng, v):
    return mix(gain(bandpass(noise(0.12, rng, attack=0.01, decay=0.06), 1500, 5000), 1.8), gain(steel_ring(1800, 0.3), 0.5))


@recipe("sfx_skill_impact_burn", -3, "burn: whump and crackle")
def _(rng, v):
    return mix(thud(rng, 90, 45, 0.35), gain(lowpass(noise(0.4, rng, attack=0.01, decay=0.3), 1800), 1.2), crackle(0.6, rng, 70, amp=1.5))


@recipe("sfx_skill_impact_freeze", -3, "freeze: crystalline chime and crack")
def _(rng, v):
    return mix(bell(0.6, 2100, partials=(1.0, 1.38, 1.76), amps=(0.8, 0.5, 0.3)), gain(bandpass(noise(0.05, rng, decay=0.015), 1500, 5000), 1.4))


@recipe("sfx_skill_impact_knockback", -3, "knockback: heavy punch and air")
def _(rng, v):
    return mix(thud(rng, 80, 40, 0.35), whoosh(rng, 0.25, 300, 1200, rise=False, amp=0.7))


@recipe("sfx_skill_impact_shatter", -3, "shatter: glassy breaks")
def _(rng, v):
    layers = [at(ping(rng.uniform(1500, 3800), 0.18, rng.uniform(0.3, 0.7)), rng.uniform(0.0, 0.08)) for _ in range(9)]
    layers.append(at(gain(bandpass(noise(0.08, rng, decay=0.03), 1500, 5000), 1.4), 0.0))
    return place(*layers)


@recipe("sfx_skill_impact_thorns", -3, "thorns: three quick spiked stabs")
def _(rng, v):
    stab = mix(resonator(noise(0.05, rng, decay=0.02), 1200, 8), tone(0.05, 260, 180, amp=0.5, decay=0.02))
    return place(at(stab, 0.0), at(gain(stab, 0.8), 0.05), at(gain(stab, 0.65), 0.1))


@recipe("sfx_skill_impact_poison", -4, "poison: bubbling chirps")
def _(rng, v):
    return place(*[at(tone(0.07, rng.uniform(300, 500), rng.uniform(600, 900), amp=0.6, attack=0.01, decay=0.05), i * 0.06)
                   for i in range(6)])


@recipe("sfx_skill_impact_curse", -4, "curse: dark beating drone with a reverse swell")
def _(rng, v):
    drone = mix(tone(0.6, 110, amp=0.6, attack=0.05, decay=0.5), tone(0.6, 116, amp=0.6, attack=0.05, decay=0.5))
    sw = [s * w for s, w in zip(bandpass(noise(0.3, rng), 400, 1500), swell(n_of(0.3), 3))]
    return place(at(gain(sw, 1.5), 0.0), at(drone, 0.25))


@recipe("sfx_status_burn_ignite", -8, "ignition whoosh and embers")
def _(rng, v):
    return mix(whoosh(rng, 0.25, 300, 1500, rise=True, amp=0.8), crackle(0.4, rng, 50, amp=1.2))


# Tram Dia: earth and grinding steel, low and heavy
@recipe("sfx_skill_tram_dia_windup", -4, "Tram Dia wind-up: low steel scrape and a rising breath of tension")
def _(rng, v):
    scrape = gain(resonator(bandpass(noise(0.5, rng, attack=0.15, decay=0.3), 400, 1600), 700, 12), 3.0)
    tension = tone(0.5, 196.0, 207.65, amp=0.4, attack=0.2, decay=0.3, curve=2)
    return mix(scrape, tension)


@recipe("sfx_skill_tram_dia_commit", -3, "Tram Dia release: heavy whoosh with a gritty floor-drag tail")
def _(rng, v):
    return place(at(whoosh(rng, 0.22, 300, 1500, rise=False, amp=1.2), 0.0), at(thud(rng, 100, 55, 0.2, 0.7), 0.0),
                 at(crackle(0.5, rng, 140, lo=300, hi=1800, amp=1.4), 0.12))


@recipe("sfx_skill_tram_dia_travel", -5, "Tram Dia wave: short grinding floor rumble")
def _(rng, v):
    return amp_mod(gain(lowpass(highpass(noise(0.4, rng, attack=0.05, decay=0.3), 60), 420), 3.0), 30.0, 0.6)


@recipe("sfx_skill_tram_dia_impact_final", -1, "Tram Dia eruption: deep thud, split-rock crack, bright steel ring")
def _(rng, v):
    return mix(thud(rng, 75, 38, 0.55, 1.2), gain(bandpass(noise(0.12, rng, decay=0.05), 800, 3000), 1.8),
               gain(steel_ring(1250, 0.9), 0.55))


@recipe("sfx_skill_tram_dia_impact", -4, "Tram Dia surge step: small rock crack", variants=2)
def _(rng, v):
    return mix(gain(bandpass(noise(0.12, rng, decay=0.04), 600, 2500), 1.6), thud(rng, 180 if v == 1 else 165, 100, 0.12, 0.7))


@recipe("sfx_skill_tram_dia_aftermath", -9, "Tram Dia aftermath: pebble trickle and fading ring")
def _(rng, v):
    return mix(crackle(0.9, rng, 35, lo=500, hi=2500, amp=1.5), gain(steel_ring(1250, 0.9), 0.15))


# Ngan Kiem: bright resonant steel, high and glassy; every gather sound sits on the tiles
@recipe("sfx_skill_ngan_kiem_charge", -6, "Ngan Kiem gather: staggered metallic tinkles at the tiles")
def _(rng, v):
    return place(*[at(ping(f, 0.18, 0.6), i * 0.06) for i, f in enumerate([2000, 2380, 2120, 2670, 2240])])


@recipe("sfx_skill_ngan_kiem_channel_loop", -10, "Ngan Kiem hovering swords: quiet steel resonance loop (1.0 s, seamless)")
def _(rng, v):
    n = SR  # 1.0 s, integer-Hz partials complete whole cycles -> seamless loop
    out = []
    for i in range(n):
        t = i / SR
        s = (math.sin(TAU * 880 * t) * 0.5 + math.sin(TAU * 1320 * t) * 0.3 + math.sin(TAU * 1761 * t) * 0.2
             + math.sin(TAU * 1759 * t) * 0.2)
        out.append(s * (0.75 + 0.25 * math.sin(TAU * 6 * t)))
    return out


@recipe("sfx_skill_ngan_kiem_commit", -3, "Ngan Kiem command: sharp downward shing and air cut")
def _(rng, v):
    shing = mix(tone(0.22, 3000, 1500, amp=0.6, decay=0.15), tone(0.22, 4500, 2250, amp=0.25, decay=0.1))
    return mix(shing, gain(bandpass(noise(0.15, rng, attack=0.005, decay=0.06), 1500, 6000), 1.4))


@recipe("sfx_skill_ngan_kiem_impact", -4, "Ngan Kiem drop: blade whistle and stab into stone", variants=3)
def _(rng, v):
    f = [2500, 2350, 2700][v - 1]
    whistle = tone(0.05, f, f * 0.72, amp=0.5, attack=0.003, decay=0.04)
    stab = mix(gain(bandpass(noise(0.08, rng, decay=0.025), 900, 3500), 1.6), thud(rng, 210, 120, 0.1, 0.6))
    return place(at(whistle, 0.0), at(stab, 0.045))


@recipe("sfx_skill_ngan_kiem_impact_final", -2, "Ngan Kiem centre blade: heavier stab, stone crack and ring")
def _(rng, v):
    stab = mix(gain(bandpass(noise(0.12, rng, decay=0.04), 700, 3000), 1.8), thud(rng, 150, 60, 0.25))
    return place(at(tone(0.06, 2400, 1700, amp=0.5, decay=0.05), 0.0), at(stab, 0.05),
                 at(steel_ring(1500, 0.7, 0.5), 0.05), at(gain(steel_ring(2300, 0.5), 0.25), 0.05))


@recipe("sfx_skill_ngan_kiem_cancel", -5, "Ngan Kiem dispersal: resonance cut, descending glassy scatter")
def _(rng, v):
    return place(*[at(ping(f, 0.16, 0.6), i * 0.05) for i, f in enumerate([3000, 2600, 2150, 1800, 1450, 1200])])


# Hoa Loi: ember crackle, rising pressure, deep whump
@recipe("sfx_skill_hoa_loi_windup", -5, "Hoa Loi book: page flick and a small ember spark")
def _(rng, v):
    flick = gain(bandpass(noise(0.04, rng, decay=0.015), 2000, 5000), 1.4)
    return place(at(flick, 0.0), at(gain(flick, 0.8), 0.06), at(crackle(0.25, rng, 60, lo=1000, hi=3500, amp=1.3), 0.12))


@recipe("sfx_skill_hoa_loi_seal", -4, "Hoa Loi brand: low sizzle at the seals")
def _(rng, v):
    sizzle = gain(bandpass(noise(0.45, rng, attack=0.01, decay=0.35), 1000, 3000), 1.3)
    return mix(amp_mod(sizzle, 40, 0.4), tone(0.4, 120, amp=0.4, attack=0.02, decay=0.35))


@recipe("sfx_skill_hoa_loi_charge", -10, "Hoa Loi fuse bed: soft crackle")
def _(rng, v):
    return crackle(1.0, rng, 45, lo=900, hi=3200, amp=1.2, fade=False)


@recipe("sfx_skill_hoa_loi_tick", -5, "Hoa Loi countdown tick (pitched up per step at runtime)")
def _(rng, v):
    return mix(tone(0.06, 1000, amp=0.8, decay=0.04, curve=5), gain(bandpass(noise(0.02, rng, decay=0.008), 1000, 3000), 0.8))


@recipe("sfx_skill_hoa_loi_prime", -4, "Hoa Loi last pulse: short rising pressure hiss")
def _(rng, v):
    n = noise(0.3, rng, attack=0.28, decay=0.05)
    return gain(lowpass(highpass(n, 600), (900, 3200)), 2.4)


@recipe("sfx_skill_hoa_loi_impact", -1, "Hoa Loi detonation: deep whump and roaring flame burst, one per cast", tiers=["S", "M", "L"])
def _(rng, t):
    k = ["S", "M", "L"].index(t)
    sec = 0.45 + 0.2 * k
    whump = thud(rng, 85 - 10 * k, 38 - 4 * k, sec * 0.9, 1.0 + 0.2 * k)
    roar = gain(lowpass(noise(sec, rng, attack=0.01, decay=sec * 0.7), (2200, 700)), 1.4 + 0.3 * k)
    return mix(whump, roar, crackle(sec, rng, 60 + 30 * k, lo=900, hi=3500, amp=1.2))


@recipe("sfx_status_burn_out", -9, "Burning ground out (last burning cell burned out): soft hiss-out")
def _(rng, v):
    return gain(bandpass(noise(0.6, rng, attack=0.02, decay=0.5, curve=3), 800, 2500), 1.2)


@recipe("sfx_status_burn_hurt", -8, "Burn tick on a unit: short light sizzle (no body thump)")
def _(rng, v):
    return mix(gain(bandpass(noise(0.12, rng, attack=0.004, decay=0.09, curve=4), 1800, 6000), 1.2),
               crackle(0.12, rng, 120, lo=1500, hi=5000, amp=0.8))


def loop_xfade(x, xf_sec):
    """Seamless loop: the last xf_sec cross-fades (equal power) into the head, then is cut off."""
    xf = n_of(xf_sec)
    n = len(x) - xf
    out = list(x[:n])
    for i in range(xf):
        t = (i + 0.5) / xf
        out[i] = x[i] * math.sin(t * math.pi / 2) + x[n + i] * math.cos(t * math.pi / 2)
    return out


@recipe("sfx_status_burn_loop", -6, "Burning ground: steady ember crackle over a low fire bed (1.5 s, seamless loop)")
def _(rng, v):
    sec = 1.7
    bed = lowpass([rng.random() * 2.0 - 1.0 for _ in range(n_of(sec))], 500)  # flat (env() always fades out)
    pops = crackle(sec, rng, 45, lo=700, hi=3200, amp=1.6, fade=False)
    return loop_xfade(mix(gain(bed, 0.5), pops), 0.2)


@recipe("sfx_skill_hoa_loi_fizzle", -7, "Hoa Loi fizzle: small dry pop")
def _(rng, v):
    return mix(gain(lowpass(noise(0.04, rng, decay=0.012), 1200), 1.4), tone(0.04, 260, 180, amp=0.5, decay=0.02))


# --- driver ----------------------------------------------------------------------------------------------------------

def event_files():
    data = json.load(open(EVENTS_JSON, encoding="utf8"))
    out = {}
    for eid, d in data["events"].items():
        files = list(d.get("files", []))
        for lst in d.get("tier_files", {}).values():
            files += lst
        for f in files:
            out[os.path.splitext(os.path.basename(f))[0]] = eid
    return out


EXTERNAL_JSON = os.path.join(ROOT, "tools", "audio", "external_sfx.json")


def external_files():
    """tools/audio/external_sfx.json entries (files built by sfx_import.py from external sources)."""
    if not os.path.exists(EXTERNAL_JSON):
        return {}
    return json.load(open(EXTERNAL_JSON, encoding="utf8"))["files"]


def replaced_recipes():
    """Recipe outputs (R keys, variants included: base, base_01, base_02 ...) that an external file replaces."""
    bases = {e["replaces_recipe"] for e in external_files().values() if e.get("replaces_recipe")}

    def variant(rest):  # "01" or a tier variant "s_01" / "m_01" / "l_01"
        return rest.isdigit() or (len(rest) > 2 and rest[0] in "sml" and rest[1] == "_" and rest[2:].isdigit())
    return {n for n in R for b in bases if n == b or (n.startswith(b + "_") and variant(n[len(b) + 1:]))}


def check():
    want = event_files()
    ext = external_files()
    replaced = replaced_recipes()
    missing = sorted(set(want) - set(R) - set(ext))
    extra = sorted(set(R) - set(want) - replaced)
    for m in missing:
        print("no recipe for", m)
    for e in extra:
        print("recipe not used by audio_events.json:", e)
    return not missing and not extra


def render_all(write=True, only=None):
    """Writes every recipe WAV (skipping recipes an external file replaces) and CREDITS.md; write=False (--credits)
    rebuilds CREDITS.md only; only = a set of recipe names (--only a,b) writes just those WAVs."""
    os.makedirs(OUT_DIR, exist_ok=True)
    want = event_files()
    lines = ["# Audio credits", "",
             "Files marked `sfx_synth.py (procedural)` are ORIGINAL, synthesised by `tools/audio/sfx_synth.py` (Python",
             "standard library: oscillators, filtered noise, envelopes; no samples, recordings, paid tools or generator",
             "services). Author: the Tessera project. Licence: CC0-equivalent (public-domain dedication; no attribution",
             "required). Regenerate with `python -X utf8 -I tools/audio/sfx_synth.py`.",
             "",
             "Files with another source are built by `tools/audio/sfx_import.py` from the raw material listed in",
             "`tools/audio/external_sfx.json` (raw takes in `audio_src/`, not exported); their licence is the one in that row.",
             "Format of every file: 16-bit mono 44.1 kHz WAV, imported as QOA.", "",
             "| File | Event | Source | Licence | Description |", "|---|---|---|---|---|"]
    total = 0
    ext = external_files()
    replaced = replaced_recipes()
    loops = loop_files()
    for name in sorted(R):
        if name in replaced:
            continue
        fn, peak, desc = R[name]
        if write and (only is None or name in only):
            rng = random.Random(zlib.crc32(name.encode("utf8")))
            x = normalize(fn(rng), peak)
            # a loop file must end where it starts: no end fade (it would dip at every wrap)
            x = x if name + ".wav" in loops else fade_out(x, 0.008)
            write_wav(os.path.join(OUT_DIR, name + ".wav"), x)
            total += len(x) * 2
        lines.append(f"| `sfx/{name}.wav` | `{want.get(name, '-')}` | sfx_synth.py (procedural) | CC0-equivalent, original | {desc} |")
    for name in sorted(ext):
        e = ext[name]
        src = f"{e['provider']}, generation `{e['generation_id']}`, {e['date']}; raw `{e['source']}`; prompt in `{e['prompt_ref']}`"
        lines.append(f"| `sfx/{name}.wav` | `{e['event']}` | {src} | {e['licence']} | {e['description']} |")
    with open(CREDITS, "w", encoding="utf8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"wrote {len(R)} files, {total / 1024:.0f} KiB PCM, and {os.path.relpath(CREDITS, ROOT)}")


def loop_files():
    data = json.load(open(EVENTS_JSON, encoding="utf8"))
    out = set()
    for d in data["events"].values():
        if d.get("loop", False):
            for f in d.get("files", []):
                out.add(os.path.basename(f))
    return out


def patch_imports():
    """Sets compress/mode=2 (QOA) on every SFX .import file Godot generated, and edit/loop_mode=2 (forward) on the
    files of loop events; returns how many changed."""
    changed = 0
    loops = loop_files()
    for name in sorted(os.listdir(OUT_DIR)):
        if not name.endswith(".wav.import"):
            continue
        p = os.path.join(OUT_DIR, name)
        text = open(p, encoding="utf8").read()
        lines = text.splitlines()
        is_loop = name[: -len(".import")] in loops
        new = []
        for l in lines:
            if l.startswith("compress/mode="):
                l = "compress/mode=2"
            elif l.startswith("edit/loop_mode=") and is_loop:
                l = "edit/loop_mode=2"
            new.append(l)
        if not any(l.startswith("compress/mode=") for l in lines):
            new.append("compress/mode=2")
        out = "\n".join(new) + "\n"
        if out != text:
            open(p, "w", encoding="utf8", newline="\n").write(out)
            changed += 1
    print(f"QOA set on {changed} import files (run `godot --headless --path . --import` again to reimport)")
    return changed


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    if "--credits" in sys.argv:
        if not check():
            sys.exit(1)
        render_all(write=False)
        sys.exit(0)
    if "--qoa" in sys.argv:
        patch_imports()
        sys.exit(0)
    if not check():
        sys.exit(1)
    only = None
    for a in sys.argv:
        if a.startswith("--only="):
            only = set(a[len("--only="):].split(","))
    render_all(only=only)
