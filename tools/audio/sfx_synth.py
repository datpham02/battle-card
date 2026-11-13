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


# --- Unified audio identity (docs/design/audio/unified-audio-identity.md, user 2026-11-13) ---------------------------
# One small palette for the whole game, Minecraft-style: simple, recognisable, pleasant, never cinematic.
# Feedback <= 200 ms, warnings <= 400 ms, no swell / riser / hall reverb, no waiting drone. Five materials:
#   tick  (dry wood/stone click)  knock (short struck body)  thump (soft low body)  ting (one clean note)
#   puff  (very short air, no sweep)  plus a short crackle for fire.
# Every note sits on one C major pentatonic scale so the whole game shares one "voice". Actions are told apart by
# material, pitch and length, never by which unit acts.

C4, D4, E4, G4, A4 = 261.6, 293.7, 329.6, 392.0, 440.0
C5, D5, E5, G5, A5 = 523.3, 587.3, 659.3, 784.0, 880.0
C6, D6, E6, G6 = 1046.5, 1174.7, 1318.5, 1568.0


def u_tick(rng, f=1200.0, sec=0.04, amp=1.0):
    """Dry click: a 3 ms band of noise and a very short body at f."""
    click = bandpass(noise(0.006, rng, attack=0.0005, decay=0.004, curve=5.0), f * 0.8, f * 3.0)
    body = tone(sec, f, amp=0.5, attack=0.001, decay=sec * 0.35, curve=6.0)
    return gain(mix(gain(click, 2.0), body), amp)


def u_knock(rng, f=400.0, sec=0.08, amp=1.0):
    """Struck wood/stone: two inharmonic partials and a click, fast decay."""
    body = bell(sec, f, partials=(1.0, 2.31), amps=(1.0, 0.35), decay=sec * 0.3)
    return gain(mix(u_tick(rng, f * 2.5, 0.02, 0.6), body), amp)


def u_thump(rng, f0=150.0, f1=80.0, sec=0.12, amp=1.0):
    """Soft low body: a short downward sine and a little low noise (felt, not boomy)."""
    return gain(mix(tone(sec, f0, f1, amp=1.0, attack=0.002, decay=sec * 0.35, curve=5.0),
                    gain(lowpass(noise(0.03, rng, decay=0.02), 600.0), 0.5)), amp)


def u_ting(f, sec=0.18, amp=1.0):
    """One clean pleasant note (sine with a faint 2nd and 3rd partial)."""
    return bell(sec, f, partials=(1.0, 2.0, 3.0), amps=(1.0, 0.18, 0.06), amp=amp, decay=sec * 0.45)


def u_puff(rng, lo=800.0, hi=3000.0, sec=0.1, amp=1.0):
    """Very short air: band of noise, quick attack, no pitch sweep."""
    return gain(bandpass(noise(sec, rng, attack=0.006, decay=sec * 0.5, curve=4.0), lo, hi), amp * 2.0)


def u_crackle(rng, sec=0.15, density=90.0, amp=1.0):
    return crackle(sec, rng, density, lo=1200.0, hi=4500.0, amp=amp)


def u_at(x, sec):
    """x delayed by sec (for use inside mix)."""
    return silence(sec) + list(x)


def u_seq(*pairs):
    """[(offset_sec, samples), ...] mixed."""
    return place(*[at(x, o) for o, x in pairs])


# UI / Block / card ------------------------------------------------------------------------------------------------

@recipe("sfx_ui_tap", -6, "tap: dry tick", variants=2)
def _(rng, v):
    return u_tick(rng, 1250.0 if v == 1 else 1400.0)


@recipe("sfx_ui_back", -6, "back: two ticks, second lower")
def _(rng, v):
    return u_seq((0.0, u_tick(rng, 1250.0)), (0.06, u_tick(rng, 950.0)))


@recipe("sfx_ui_toggle", -6, "toggle: two ticks, second higher")
def _(rng, v):
    return u_seq((0.0, u_tick(rng, 1100.0)), (0.05, u_tick(rng, 1450.0)))


@recipe("sfx_block_pickup", -6, "Block pick-up: knock, smaller Block higher", tiers=["S", "M", "L"])
def _(rng, t):
    return u_knock(rng, {"S": G5, "M": E5, "L": C5}[t], 0.08)


@recipe("sfx_block_select", -6, "Block select: light tick")
def _(rng, v):
    return u_tick(rng, 1600.0, 0.035, 0.8)


@recipe("sfx_block_place", -4, "Block place: low stone knock with a soft thump", variants=2)
def _(rng, v):
    f = 300.0 if v == 1 else 320.0
    return mix(u_knock(rng, f, 0.1), u_thump(rng, 160.0, 110.0, 0.08, 0.6))


@recipe("sfx_block_invalid", -6, "invalid: two dull low knocks (a soft 'no')")
def _(rng, v):
    return u_seq((0.0, u_knock(rng, 220.0, 0.07)), (0.08, u_knock(rng, 200.0, 0.07)))


@recipe("sfx_card_menu_open", -5, "card menu: short paper puff and a soft ting")
def _(rng, v):
    return mix(u_puff(rng, 1500.0, 5000.0, 0.07, 0.6), u_at(u_ting(C5, 0.14, 0.6), 0.02))


@recipe("sfx_card_highlight", -8, "card highlight: soft high tick")
def _(rng, v):
    return u_tick(rng, 1800.0, 0.03, 0.7)


@recipe("sfx_card_choose", -4, "card choose: two quick tings (E5, G5)")
def _(rng, v):
    return u_seq((0.0, u_ting(E5, 0.12)), (0.05, u_ting(G5, 0.14)))


@recipe("sfx_card_unavailable", -5, "card unavailable: one dull knock")
def _(rng, v):
    return u_knock(rng, 200.0, 0.08)


@recipe("sfx_card_ready", -9, "card ready: one soft high ting")
def _(rng, v):
    return u_ting(C6, 0.2, 0.8)


# Combat ------------------------------------------------------------------------------------------------------------

@recipe("sfx_combat_hit_player", -3, "player hit: low thump and a short crunch", variants=2)
def _(rng, v):
    return mix(u_thump(rng, 130.0 if v == 1 else 120.0, 70.0, 0.12), u_puff(rng, 500.0, 2500.0, 0.05, 0.7))


@recipe("sfx_combat_hit_enemy", -3, "enemy hit: thump and a click", variants=2)
def _(rng, v):
    return mix(u_thump(rng, 170.0 if v == 1 else 160.0, 95.0, 0.1), u_tick(rng, 900.0, 0.03, 0.7))


@recipe("sfx_combat_interrupt", -3, "interrupt (NGẮT!): low knock cut by a puff")
def _(rng, v):
    return u_seq((0.0, u_knock(rng, 260.0, 0.08)), (0.03, u_puff(rng, 600.0, 2500.0, 0.08, 0.8)))


@recipe("sfx_combat_parry", -3, "parry: bright metal ting over a knock")
def _(rng, v):
    return mix(u_knock(rng, 500.0, 0.06, 0.8), u_ting(A5, 0.16))


@recipe("sfx_combat_crit", -3, "crit: thump with a high ting on top")
def _(rng, v):
    return mix(u_thump(rng, 170.0, 90.0, 0.1), u_at(u_ting(C6, 0.15, 0.8), 0.005))


@recipe("sfx_combat_death", -3, "death: longer low thump and a soft puff of dust")
def _(rng, v):
    return mix(u_thump(rng, 120.0, 55.0, 0.28), u_at(u_puff(rng, 300.0, 1500.0, 0.2, 0.5), 0.04))


@recipe("sfx_combat_hp_low", -6, "low HP: two soft heartbeat thumps")
def _(rng, v):
    return u_seq((0.0, u_thump(rng, 90.0, 60.0, 0.1)), (0.16, u_thump(rng, 80.0, 55.0, 0.12, 0.8)))


@recipe("sfx_combat_lock", -5, "lock: high tick and a small knock")
def _(rng, v):
    return mix(u_tick(rng, 2000.0, 0.03), u_knock(rng, G5, 0.06, 0.6))


# Warnings (<= 400 ms; energy kept in 1-3 kHz for accessibility) -------------------------------------------------

@recipe("sfx_warn_boss_windup", -1, "boss wind-up: low thump and a knock-tick at 1.5 kHz")
def _(rng, v):
    return mix(u_thump(rng, 110.0, 70.0, 0.16), u_at(u_knock(rng, 600.0, 0.08, 0.8), 0.01), u_at(u_tick(rng, 1500.0, 0.04), 0.02))


@recipe("sfx_warn_boss_imminent", -1, "boss imminent: two notes up (G5, C6), clear and short")
def _(rng, v):
    return u_seq((0.0, u_ting(G5, 0.14)), (0.13, u_ting(C6, 0.18)))


@recipe("sfx_warn_boss_recovery", -3, "boss recovery (opening): two notes down (C6, G5), soft")
def _(rng, v):
    return u_seq((0.0, u_ting(C6, 0.14, 0.8)), (0.12, u_ting(G5, 0.2, 0.8)))


@recipe("sfx_warn_terrain_vent", -1, "terrain vent: short 1-3 kHz puff over a low thump")
def _(rng, v):
    return mix(u_puff(rng, 1000.0, 3000.0, 0.25), u_thump(rng, 100.0, 70.0, 0.15, 0.6))


# Flow (short stingers on the same scale) ---------------------------------------------------------------------------

@recipe("sfx_flow_victory", -3, "victory: C5 E5 G5 C6")
def _(rng, v):
    return u_seq(*[(i * 0.09, u_ting(f, 0.22 if i == 3 else 0.14)) for i, f in enumerate([C5, E5, G5, C6])])


@recipe("sfx_flow_defeat", -3, "defeat: G4 E4 C4, soft")
def _(rng, v):
    return u_seq(*[(i * 0.12, u_ting(f, 0.24 if i == 2 else 0.16, 0.9)) for i, f in enumerate([G4, E4, C4])])


# Skill archetypes (every card without its own set) -----------------------------------------------------------------

@recipe("sfx_skill_generic_windup", -5, "wind-up: soft low puff and a tick", variants=2)
def _(rng, v):
    return mix(u_puff(rng, 400.0, 1800.0, 0.1, 0.8), u_at(u_tick(rng, 900.0 if v == 1 else 1000.0, 0.03, 0.6), 0.04))


@recipe("sfx_skill_generic_commit", -4, "release: puff with a small thump")
def _(rng, v):
    return mix(u_puff(rng, 600.0, 2600.0, 0.1), u_thump(rng, 160.0, 100.0, 0.08, 0.7))


@recipe("sfx_skill_generic_travel", -8, "travel: very soft short air")
def _(rng, v):
    return u_puff(rng, 700.0, 2200.0, 0.12, 0.7)


@recipe("sfx_skill_generic_hit", -5, "hit confirm: small knock")
def _(rng, v):
    return u_knock(rng, 520.0, 0.06)


@recipe("sfx_skill_generic_cancel", -5, "cancel: two soft tings down (C6, G5)")
def _(rng, v):
    return u_seq((0.0, u_ting(C6, 0.08, 0.7)), (0.06, u_ting(G5, 0.1, 0.6)))


@recipe("sfx_skill_generic_fizzle", -7, "fizzle: tiny dry puff")
def _(rng, v):
    return u_puff(rng, 900.0, 3000.0, 0.05, 0.8)


@recipe("sfx_skill_impact_burst", -3, "impact burst: thump and puff")
def _(rng, v):
    return mix(u_thump(rng, 150.0, 75.0, 0.14), u_puff(rng, 500.0, 2500.0, 0.1, 0.8))


@recipe("sfx_skill_impact_slash", -3, "impact slash: high puff and a short steel ting")
def _(rng, v):
    return mix(u_puff(rng, 2000.0, 6000.0, 0.06, 0.8), u_at(u_ting(E6, 0.1, 0.6), 0.01), u_knock(rng, 700.0, 0.05, 0.5))


@recipe("sfx_skill_impact_burn", -3, "impact burn: thump and a short crackle")
def _(rng, v):
    return mix(u_thump(rng, 140.0, 80.0, 0.12), u_crackle(rng, 0.16, 110.0, 1.2))


@recipe("sfx_skill_impact_freeze", -3, "impact freeze: high ting and a crisp tick")
def _(rng, v):
    return mix(u_ting(G6, 0.16, 0.7), u_tick(rng, 3000.0, 0.03))


@recipe("sfx_skill_impact_knockback", -3, "impact knockback: low thump and air")
def _(rng, v):
    return mix(u_thump(rng, 120.0, 65.0, 0.14), u_puff(rng, 400.0, 1500.0, 0.12, 0.8))


@recipe("sfx_skill_impact_shatter", -3, "impact shatter: three quick high ticks")
def _(rng, v):
    return u_seq((0.0, u_tick(rng, 2600.0)), (0.035, u_tick(rng, 3100.0, 0.03)), (0.07, u_tick(rng, 2300.0, 0.03)))


@recipe("sfx_skill_impact_thorns", -3, "impact thorns: three quick knocks")
def _(rng, v):
    return u_seq((0.0, u_knock(rng, 700.0, 0.04)), (0.04, u_knock(rng, 780.0, 0.04)), (0.08, u_knock(rng, 660.0, 0.04)))


@recipe("sfx_skill_impact_poison", -4, "impact poison: two soft bubble blips")
def _(rng, v):
    return u_seq((0.0, tone(0.06, 300.0, 520.0, amp=0.9, decay=0.04)), (0.07, tone(0.06, 340.0, 600.0, amp=0.8, decay=0.04)))


@recipe("sfx_skill_impact_curse", -4, "impact curse: low thump and a low ting (dark, short)")
def _(rng, v):
    return mix(u_thump(rng, 110.0, 60.0, 0.16), u_ting(C4, 0.2, 0.7))


@recipe("sfx_status_burn_ignite", -8, "fire catches: short crackle")
def _(rng, v):
    return mix(u_crackle(rng, 0.14, 120.0), u_puff(rng, 600.0, 2000.0, 0.08, 0.4))


@recipe("sfx_status_burn_loop", -8, "burning starts (any source): short soft crackle, one shot (no drone)")
def _(rng, v):
    return u_crackle(rng, 0.2, 70.0, 0.9)


@recipe("sfx_status_burn_hurt", -8, "burn tick on a unit: tiny sizzle")
def _(rng, v):
    return u_puff(rng, 2000.0, 6000.0, 0.06, 0.7)


@recipe("sfx_status_burn_out", -9, "fire out: short soft puff")
def _(rng, v):
    return u_puff(rng, 700.0, 2200.0, 0.12, 0.6)


# The three reference cards keep their own events (doc §8.1) but use the same palette --------------------------------

@recipe("sfx_skill_tram_dia_windup", -4, "Tram Dia wind-up: low stone knock and a soft thump")
def _(rng, v):
    return mix(u_knock(rng, 200.0, 0.1), u_thump(rng, 110.0, 80.0, 0.1, 0.6))


@recipe("sfx_skill_tram_dia_commit", -3, "Tram Dia release: puff and thump")
def _(rng, v):
    return mix(u_puff(rng, 500.0, 2000.0, 0.12), u_thump(rng, 140.0, 80.0, 0.1))


@recipe("sfx_skill_tram_dia_travel", -5, "Tram Dia wave: low short puff")
def _(rng, v):
    return u_puff(rng, 250.0, 1000.0, 0.14)


@recipe("sfx_skill_tram_dia_impact_final", -1, "Tram Dia first eruption (biggest): deep thump, rock knock, low steel ting")
def _(rng, v):
    return mix(u_thump(rng, 120.0, 55.0, 0.22), u_knock(rng, 260.0, 0.1), u_at(u_ting(G4, 0.25, 0.6), 0.01))


@recipe("sfx_skill_tram_dia_impact", -4, "Tram Dia surge step: small rock knock", variants=2)
def _(rng, v):
    return mix(u_knock(rng, 300.0 if v == 1 else 330.0, 0.08), u_thump(rng, 150.0, 100.0, 0.06, 0.5))


@recipe("sfx_skill_tram_dia_aftermath", -9, "Tram Dia aftermath: two pebble ticks")
def _(rng, v):
    return u_seq((0.0, u_tick(rng, 1400.0, 0.03, 0.7)), (0.08, u_tick(rng, 1700.0, 0.03, 0.5)))


@recipe("sfx_skill_ngan_kiem_charge", -6, "Ngan Kiem gather (silent by design): soft ting")
def _(rng, v):
    return u_ting(E6, 0.12, 0.6)


@recipe("sfx_skill_ngan_kiem_channel_loop", -8, "Ngan Kiem summon: three soft steel tings at the tiles, one shot (no drone)")
def _(rng, v):
    return u_seq((0.0, u_ting(G5, 0.1, 0.8)), (0.045, u_ting(C6, 0.1, 0.7)), (0.09, u_ting(E6, 0.11, 0.6)))


@recipe("sfx_skill_ngan_kiem_commit", -3, "Ngan Kiem command (silent by design): knock")
def _(rng, v):
    return u_knock(rng, 600.0, 0.06)


@recipe("sfx_skill_ngan_kiem_impact", -4, "Ngan Kiem drop: steel ting into a stone knock", variants=3)
def _(rng, v):
    f = [A5, G5, C6][v - 1]
    return mix(u_knock(rng, 380.0, 0.07), u_ting(f, 0.1, 0.7))


@recipe("sfx_skill_ngan_kiem_impact_final", -2, "Ngan Kiem centre blade: thump, knock and a lower ting")
def _(rng, v):
    return mix(u_thump(rng, 140.0, 70.0, 0.16), u_knock(rng, 340.0, 0.08), u_ting(E5, 0.2, 0.8))


@recipe("sfx_skill_ngan_kiem_cancel", -5, "Ngan Kiem dispersal: three tings down")
def _(rng, v):
    return u_seq((0.0, u_ting(E6, 0.07, 0.7)), (0.05, u_ting(C6, 0.07, 0.6)), (0.1, u_ting(G5, 0.1, 0.5)))


@recipe("sfx_skill_hoa_loi_windup", -6, "Hoa Loi cast: soft crackle, fire catching")
def _(rng, v):
    return u_crackle(rng, 0.2, 80.0, 0.9)


@recipe("sfx_skill_hoa_loi_ignite", -4, "Hoa Loi release (seals appear): one short puff and thump")
def _(rng, v):
    return mix(u_puff(rng, 500.0, 2500.0, 0.1), u_thump(rng, 170.0, 100.0, 0.08, 0.7))


@recipe("sfx_skill_hoa_loi_seal", -4, "Hoa Loi seal (silent by design): tick")
def _(rng, v):
    return u_tick(rng, 900.0)


@recipe("sfx_skill_hoa_loi_charge", -10, "Hoa Loi fuse (silent by design): tiny crackle")
def _(rng, v):
    return u_crackle(rng, 0.12, 60.0)


@recipe("sfx_skill_hoa_loi_tick", -5, "Hoa Loi countdown (silent by design): tick")
def _(rng, v):
    return u_tick(rng, 1000.0)


@recipe("sfx_skill_hoa_loi_prime", -4, "Hoa Loi prime (silent by design): puff")
def _(rng, v):
    return u_puff(rng, 900.0, 3000.0, 0.08)


@recipe("sfx_skill_hoa_loi_impact", -1, "Hoa Loi blast, one per cast: crack, thump and crackle (bigger tier lower and longer)",
        tiers=["S", "M", "L"])
def _(rng, t):
    k = ["S", "M", "L"].index(t)
    sec = 0.18 + 0.06 * k
    return mix(u_tick(rng, 2500.0, 0.03), u_thump(rng, 170.0 - 20.0 * k, 70.0 - 8.0 * k, sec),
               u_at(u_crackle(rng, sec * 0.8, 100.0, 1.0), 0.02))


@recipe("sfx_skill_hoa_loi_fizzle", -7, "Hoa Loi fizzle: tiny puff")
def _(rng, v):
    return u_puff(rng, 900.0, 3000.0, 0.05, 0.8)


# New events approved 2026-11-13 (doc §4, §8 item 3); wiring is Phase 4 (multi-enemy) ------------------------------

@recipe("sfx_move_step", -9, "hero step to a cell: soft low stone tick", variants=2)
def _(rng, v):
    return u_knock(rng, 240.0 if v == 1 else 260.0, 0.05, 0.8)


@recipe("sfx_pickup_point", -5, "pick up a field point: one pleasant ting", variants=2)
def _(rng, v):
    return u_ting(G5 if v == 1 else A5, 0.14)


@recipe("sfx_status_apply", -7, "a status lands: two quick tings up (pitch by status at runtime)", variants=2)
def _(rng, v):
    base = [D5, E5][v - 1]
    return u_seq((0.0, u_ting(base, 0.07, 0.7)), (0.045, u_ting(base * 1.5, 0.09, 0.7)))


@recipe("sfx_status_expire", -8, "a status ends: two quick tings down", variants=2)
def _(rng, v):
    base = [D5, E5][v - 1]
    return u_seq((0.0, u_ting(base * 1.5, 0.07, 0.6)), (0.045, u_ting(base, 0.09, 0.6)))


# Per-card voices (user 2026-11-13: "làm biến thể" — each skill its own sound, matched to its VFX, same palette) ---
# tools/audio/card_voices.json (built by tools/audio/card_voices.py from cards.json + assets/art/vfx/cast/index.json)
# gives every card without its own hand-made set: a windup shape + note and an impact shape + note + length. The
# shapes below turn the card's VFX form (impact_variants form: ring, double, stab4, bell, jaw ...) into the same
# gesture in sound. Same five materials, same scale: one voice for the game, a different word for each skill.


def _len(x, sec):
    n = n_of(sec)
    x = list(x[:n])
    return fade_out(x + [0.0] * (n - len(x)), min(0.02, sec * 0.2))


IMPACT_SHAPES = {
    # slash family
    "ring": lambda rng, f, s: mix(u_puff(rng, 1500.0, 5000.0, 0.08, 0.7), u_ting(f, s * 0.8)),
    "ring2": lambda rng, f, s: u_seq((0.0, u_ting(f, 0.1)), (0.07, mix(u_puff(rng, 1500.0, 5000.0, 0.06, 0.6), u_ting(f * 1.5, 0.12)))),
    "arc_h": lambda rng, f, s: mix(u_puff(rng, 800.0, 3000.0, 0.12, 0.9), u_at(u_ting(f, 0.12, 0.7), 0.04)),
    "arc_v": lambda rng, f, s: mix(u_puff(rng, 1200.0, 4000.0, 0.06, 0.8), u_at(u_knock(rng, f * 0.5, 0.08), 0.04)),
    "cross_x": lambda rng, f, s: u_seq((0.0, mix(u_puff(rng, 1500.0, 5000.0, 0.05, 0.7), u_ting(f, 0.07, 0.7))),
                                       (0.06, mix(u_puff(rng, 1500.0, 5000.0, 0.05, 0.7), u_ting(f * 1.26, 0.09, 0.7)))),
    "double": lambda rng, f, s: u_seq((0.0, mix(u_knock(rng, f * 0.5, 0.06), u_ting(f, 0.07, 0.6))),
                                      (0.08, mix(u_knock(rng, f * 0.5, 0.06), u_ting(f, 0.09, 0.6)))),
    "stab4": lambda rng, f, s: u_seq(*[(i * 0.045, mix(u_tick(rng, f * 2.0, 0.03), u_ting(f * (1.0 + 0.12 * i), 0.05, 0.5))) for i in range(4)]),
    "dagger": lambda rng, f, s: mix(u_tick(rng, f * 3.0, 0.03), u_ting(f * 2.0, 0.12, 0.7)),
    "hook": lambda rng, f, s: u_seq((0.0, u_knock(rng, f, 0.06)), (0.05, u_puff(rng, 500.0, 1800.0, 0.1, 0.7))),
    "echo": lambda rng, f, s: u_seq((0.0, u_ting(f, 0.1)), (0.12, gain(u_ting(f, 0.1), 0.45))),
    "deathmark": lambda rng, f, s: mix(u_ting(f * 0.5, s * 0.8, 0.8), u_tick(rng, 2400.0, 0.03, 0.6)),
    "wide": lambda rng, f, s: mix(u_puff(rng, 600.0, 2600.0, 0.16), u_at(u_ting(f, 0.1, 0.6), 0.06)),
    "pierce": lambda rng, f, s: mix(u_tick(rng, f * 2.5, 0.03), u_ting(f * 1.5, 0.16, 0.8)),
    "chain3": lambda rng, f, s: u_seq(*[(i * 0.06, mix(u_puff(rng, 1500.0, 5000.0, 0.04, 0.6), u_ting(f * (1.0 + 0.25 * i), 0.06, 0.6))) for i in range(3)]),
    "twin": lambda rng, f, s: u_seq((0.0, u_ting(f, 0.06)), (0.035, u_ting(f * 1.33, 0.08))),
    # knockback / burst / earth family
    "wedge": lambda rng, f, s: mix(u_knock(rng, f, 0.08), u_thump(rng, 160.0, 100.0, 0.1, 0.8)),
    "slam": lambda rng, f, s: mix(u_thump(rng, 130.0, 60.0, s), u_knock(rng, f * 0.5, 0.1, 0.7)),
    "column": lambda rng, f, s: mix(u_puff(rng, 700.0, 2500.0, s), u_at(u_tick(rng, f * 2.0, 0.03), s * 0.6)),
    "column2": lambda rng, f, s: u_seq((0.0, u_puff(rng, 700.0, 2500.0, 0.12)), (0.1, u_puff(rng, 900.0, 3200.0, 0.12))),
    "vortex": lambda rng, f, s: u_seq(*[(i * 0.07, u_puff(rng, 600.0 + 300.0 * i, 2200.0 + 600.0 * i, 0.09, 0.8)) for i in range(3)]),
    "quake": lambda rng, f, s: u_seq((0.0, u_thump(rng, 100.0, 55.0, 0.18)), (0.06, u_knock(rng, f * 0.5, 0.06, 0.6)), (0.13, u_knock(rng, f * 0.45, 0.06, 0.5))),
    "crater": lambda rng, f, s: mix(u_thump(rng, 120.0, 50.0, s), u_puff(rng, 400.0, 1800.0, s * 0.7, 0.7), u_at(u_ting(f * 0.5, 0.2, 0.5), 0.02)),
    "knock_puff": lambda rng, f, s: mix(u_knock(rng, f, 0.07), u_puff(rng, 500.0, 2000.0, 0.1, 0.7)),
    "smash": lambda rng, f, s: mix(u_thump(rng, 150.0, 80.0, 0.12), u_seq((0.02, u_tick(rng, 2600.0)), (0.05, u_tick(rng, 3000.0, 0.03)))),
    "spark4": lambda rng, f, s: u_seq(*[(i * 0.05, mix(u_tick(rng, f * 3.0, 0.03), u_ting(f * 2.0, 0.04, 0.4))) for i in range(4)]),
    # shatter / freeze family
    "frame": lambda rng, f, s: u_seq(*[(i * 0.04, u_tick(rng, f * 2.0 * (1.0 + 0.06 * i), 0.03)) for i in range(4)]),
    "frame_sparse": lambda rng, f, s: u_seq((0.0, u_tick(rng, f * 2.0, 0.03)), (0.09, u_tick(rng, f * 2.4, 0.03)), (0.17, u_ting(f * 2.0, 0.08, 0.5))),
    "cross": lambda rng, f, s: u_seq((0.0, u_tick(rng, f * 2.5, 0.03)), (0.03, u_tick(rng, f * 2.0, 0.03)), (0.05, u_ting(f * 2.0, 0.12, 0.6))),
    "cross_diag": lambda rng, f, s: u_seq((0.0, u_tick(rng, f * 2.0, 0.03)), (0.05, u_tick(rng, f * 2.6, 0.03)), (0.08, u_ting(f * 1.5, 0.12, 0.6))),
    "drops3": lambda rng, f, s: u_seq(*[(i * 0.08, tone(0.06, f * (1.4 - 0.12 * i), f * (1.1 - 0.1 * i), amp=0.8, decay=0.04)) for i in range(3)]),
    "spike": lambda rng, f, s: mix(u_tick(rng, f * 3.0, 0.03), u_ting(f * 2.0, 0.14, 0.7)),
    "spike_tilt": lambda rng, f, s: mix(u_tick(rng, f * 2.6, 0.03), u_ting(f * 1.75, 0.14, 0.7), u_at(u_tick(rng, f * 3.2, 0.02, 0.5), 0.05)),
    "spike2": lambda rng, f, s: u_seq((0.0, mix(u_tick(rng, f * 3.0, 0.03), u_ting(f * 2.0, 0.08, 0.6))), (0.07, mix(u_tick(rng, f * 3.0, 0.03), u_ting(f * 2.5, 0.1, 0.6)))),
    "cluster": lambda rng, f, s: u_seq((0.0, u_ting(f * 2.0, 0.08, 0.6)), (0.03, u_ting(f * 2.5, 0.08, 0.6)), (0.06, u_ting(f * 3.0, 0.1, 0.6))),
    "crack": lambda rng, f, s: mix(u_tick(rng, 2600.0, 0.03), u_knock(rng, f, 0.08)),
    "crack_web": lambda rng, f, s: u_seq((0.0, mix(u_tick(rng, 2600.0, 0.03), u_knock(rng, f, 0.06))), (0.05, u_tick(rng, 2900.0, 0.03)), (0.09, u_tick(rng, 2300.0, 0.03))),
    "chunks": lambda rng, f, s: u_seq((0.0, u_knock(rng, f * 0.75, 0.07)), (0.06, u_knock(rng, f * 0.6, 0.07)), (0.12, u_knock(rng, f * 0.7, 0.07))),
    "shards": lambda rng, f, s: u_seq(*[(i * 0.03, u_tick(rng, f * (3.0 + 0.4 * i), 0.03)) for i in range(5)]),
    "iceburst": lambda rng, f, s: mix(u_thump(rng, 150.0, 90.0, 0.08, 0.6), u_seq((0.0, u_ting(f * 2.0, 0.1, 0.7)), (0.04, u_tick(rng, 3000.0, 0.03)), (0.07, u_tick(rng, 3400.0, 0.03)))),
    "steam": lambda rng, f, s: mix(u_puff(rng, 2000.0, 6000.0, s * 0.8, 0.8), u_crackle(rng, s * 0.6, 80.0, 0.7)),
    # thorns / poison / guard / curse / light family
    "spikes": lambda rng, f, s: u_seq((0.0, u_knock(rng, f, 0.05)), (0.04, u_knock(rng, f * 1.12, 0.05)), (0.08, u_knock(rng, f * 0.9, 0.05))),
    "vine": lambda rng, f, s: u_seq((0.0, u_knock(rng, f, 0.05)), (0.05, u_puff(rng, 500.0, 1800.0, 0.1, 0.6)), (0.1, u_knock(rng, f * 1.12, 0.05))),
    "bubbles": lambda rng, f, s: u_seq(*[(i * 0.06, tone(0.05, f * (0.55 + 0.1 * i), f * (0.9 + 0.1 * i), amp=0.8, decay=0.035)) for i in range(3)]),
    "jaw": lambda rng, f, s: u_seq((0.0, u_knock(rng, f, 0.05)), (0.05, mix(u_knock(rng, f * 0.8, 0.07), u_tick(rng, 2000.0, 0.03)))),
    "spring": lambda rng, f, s: u_seq((0.0, u_ting(f, 0.06)), (0.04, u_ting(f * 1.5, 0.06)), (0.08, u_ting(f, 0.08, 0.7))),
    "splinter": lambda rng, f, s: mix(u_knock(rng, f, 0.06), u_seq((0.02, u_tick(rng, 1800.0, 0.03)), (0.05, u_tick(rng, 2100.0, 0.03)))),
    "ward": lambda rng, f, s: mix(u_ting(f, 0.2, 0.7), u_ting(f * 1.5, 0.2, 0.5)),
    "plate": lambda rng, f, s: mix(u_knock(rng, f * 0.5, 0.08), u_ting(f, 0.16, 0.7)),
    "pillar": lambda rng, f, s: u_seq((0.0, u_knock(rng, f * 0.5, 0.08)), (0.08, u_knock(rng, f * 0.6, 0.08)), (0.16, u_thump(rng, 120.0, 80.0, 0.08, 0.6))),
    "bell": lambda rng, f, s: bell(min(s, 0.35), f, partials=(1.0, 2.0, 2.76), amps=(1.0, 0.35, 0.2), decay=min(s, 0.35) * 0.4),
    "lightpillar": lambda rng, f, s: mix(u_ting(f * 2.0, s * 0.8, 0.7), u_puff(rng, 2500.0, 7000.0, s * 0.6, 0.5)),
    "curse_low": lambda rng, f, s: mix(u_thump(rng, 110.0, 60.0, 0.14), u_ting(f * 0.5, s * 0.8, 0.7)),
    "ghost": lambda rng, f, s: u_seq((0.0, u_ting(f * 0.5, 0.12, 0.6)), (0.06, u_ting(f * 0.53, 0.14, 0.5))),
    # fire family
    "firewall": lambda rng, f, s: mix(u_crackle(rng, s, 120.0), u_puff(rng, 500.0, 2000.0, s * 0.6, 0.6)),
    "sparks_fall": lambda rng, f, s: mix(u_crackle(rng, s, 90.0), u_seq((0.0, u_tick(rng, f * 3.0, 0.03)), (0.07, u_tick(rng, f * 3.3, 0.03)))),
    "floor_fire": lambda rng, f, s: mix(u_crackle(rng, s, 110.0), u_thump(rng, 140.0, 90.0, 0.08, 0.6)),
    "fire_field": lambda rng, f, s: mix(u_crackle(rng, s, 140.0, 1.1), u_puff(rng, 400.0, 1500.0, s * 0.7, 0.6)),
    "fire_sky": lambda rng, f, s: mix(u_crackle(rng, s, 130.0), u_thump(rng, 150.0, 70.0, s * 0.8), u_at(u_ting(f, 0.1, 0.4), 0.02)),
}

WINDUP_SHAPES = {
    "hand": lambda rng, f: mix(u_tick(rng, f * 2.0, 0.03, 0.7), u_at(u_ting(f, 0.08, 0.6), 0.03)),
    "body": lambda rng, f: mix(u_puff(rng, 400.0, 1600.0, 0.1, 0.8), u_thump(rng, 130.0, 100.0, 0.07, 0.5), u_at(u_tick(rng, f, 0.03, 0.5), 0.05)),
    "weapon": lambda rng, f: mix(u_tick(rng, f * 2.5, 0.03, 0.8), u_at(u_ting(f * 1.5, 0.06, 0.4), 0.02)),
    "throw": lambda rng, f: mix(u_puff(rng, 900.0, 3000.0, 0.07, 0.8), u_tick(rng, f * 2.0, 0.03, 0.5)),
    "sky": lambda rng, f: u_seq((0.0, u_tick(rng, f * 2.0, 0.03, 0.6)), (0.05, u_ting(f * 1.5, 0.07, 0.5))),
    "ground": lambda rng, f: mix(u_knock(rng, f * 0.5, 0.07, 0.8), u_puff(rng, 300.0, 1200.0, 0.08, 0.5)),
    "chain": lambda rng, f: u_seq((0.0, u_tick(rng, f * 2.0, 0.03, 0.6)), (0.04, u_tick(rng, f * 2.5, 0.03, 0.6))),
}


def _card_voices():
    p = os.path.join(ROOT, "tools", "audio", "card_voices.json")
    return json.load(open(p, encoding="utf8"))["cards"] if os.path.exists(p) else {}


for _cid, _v in sorted(_card_voices().items()):
    def _impact(rng, v, _v=_v):
        return _len(IMPACT_SHAPES[_v["impact_shape"]](rng, float(_v["note"]), float(_v["impact_sec"])), float(_v["impact_sec"]))

    def _windup(rng, v, _v=_v):
        return WINDUP_SHAPES[_v["windup_shape"]](rng, float(_v["windup_note"]))

    recipe("sfx_skill_card_%s_impact" % _cid, -3, "%s impact: %s (VFX form %s)" % (_cid, _v["impact_shape"], _v.get("vfx_form", "-")))(_impact)
    recipe("sfx_skill_card_%s_windup" % _cid, -6, "%s wind-up: %s" % (_cid, _v["windup_shape"]))(_windup)


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
