"""Per-card voices: one wind-up and one impact sound per skill, matched to that skill's own VFX (user 2026-11-13).

Reads assets/data/cards.json and assets/art/vfx/cast/index.json, writes tools/audio/card_voices.json (the reviewable
table sfx_synth.py renders from) and, with --apply, the per-card events + card map in assets/data/audio_events.json.

Rules (deterministic, observable in the table):
- impact shape = the card's VFX impact form (impact_variants.form + its modifiers: count, drops, diag, tilt, web,
  sparse, vine) mapped to the same gesture in sound; cards without a VFX form get a shape from their own data (hits,
  delivery, impact family, name) in NO_FORM below.
- note = a register per impact family (slash high, freeze highest, knockback / burst low, burn / thorns middle,
  curse lowest), then each card in the family gets its own degree of one C-major pentatonic scale (card id order), so
  no two cards of a family share a pitch.
- impact length = 60 % of the VFX form's sec (impact_style sec without a form), clamped 0.12-0.4 s (identity §3).
- wind-up shape = the card's cast_presentation (hand / body / weapon / throw), else its delivery (sky, ground, chain,
  throw, hand); wind-up note = the card note one octave down (hand / body) or the same (others).
The three reference cards (tram_dia, ngan_kiem, hoa_loi) keep their own hand-made sets and are skipped.

python -X utf8 -I tools/audio/card_voices.py            # write card_voices.json
python -X utf8 -I tools/audio/card_voices.py --apply    # also write the events + card map into audio_events.json
python -X utf8 -I tools/audio/card_voices.py --check    # exit 1 if the table or the events are stale / not unique
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CARDS = os.path.join(ROOT, "assets", "data", "cards.json")
VFX = os.path.join(ROOT, "assets", "art", "vfx", "cast", "index.json")
EVENTS = os.path.join(ROOT, "assets", "data", "audio_events.json")
OUT = os.path.join(ROOT, "tools", "audio", "card_voices.json")
OWN_SETS = {"tram_dia", "ngan_kiem", "hoa_loi"}

PENTA = [261.6, 293.7, 329.6, 392.0, 440.0]  # C4 D4 E4 G4 A4
# register = octave multiplier of PENTA for the family's first card
# (shapes multiply the note by up to x3 for their bright transients, so registers stay low enough to be pleasant)
REGISTER = {"slash": 1.0, "freeze": 2.0, "shatter": 1.0, "knockback": 1.0, "burst": 1.0, "burn": 1.0,
            "thorns": 1.0, "poison": 1.0, "curse": 0.5, "guard": 1.0, "seal": 1.0}

FORM_SHAPE = {
    "ring": "ring", "ring2": "ring2", "arc_h": "arc_h", "arc_v": "arc_v", "cross_x": "cross_x", "double": "double",
    "stab4": "stab4", "dagger": "dagger", "hook": "hook", "echo": "echo", "deathmark": "deathmark", "wedge": "wedge",
    "slam": "slam", "column": "column", "vortex": "vortex", "quake": "quake", "crater": "crater", "frame": "frame",
    "cross": "cross", "spike": "spike", "cluster": "cluster", "crack": "crack", "chunks": "chunks", "shards": "shards",
    "iceburst": "iceburst", "steam": "steam", "spikes": "spikes", "bubbles": "bubbles", "jaw": "jaw",
    "spring": "spring", "splinter": "splinter", "ward": "ward", "plate": "plate", "pillar": "pillar",
    "firewall": "firewall", "bell": "bell", "lightpillar": "lightpillar",
}

# cards with no VFX impact form: the shape their own data suggests
NO_FORM = {
    "song_dao": "twin",          # two blades, many quick hits
    "lien_tram": "chain3",       # chained slashes
    "vung_lay": "wide",          # a wide sweep
    "thuong_xuyen": "pierce",    # a piercing thrust
    "dap_vo": "smash",           # a smash that breaks
    "chuoi_set": "spark4",       # a chain of sparks
    "min_tre": "knock_puff",     # a small mine pop
    "hoa_tinh": "sparks_fall",   # falling fire squares
    "hoa_xa": "floor_fire",      # fire running on the floor
    "hoa_tran": "fire_field",    # a fire field
    "liet_hoa": "firewall",      # fierce floor fire
    "thien_hoa": "fire_sky",     # sky fire
    "ganh_nang": "curse_low",    # a weight curse
    "oan_hon": "ghost",          # a ghostly curse
}

DELIVERY_WINDUP = {"SKY_TO_TARGET": "sky", "GROUND_PROPAGATION": "ground", "SEQUENTIAL_CHAIN": "chain",
                   "CASTER_TO_TARGET": "throw", "DIRECT_MANIFESTATION": "hand"}


def build():
    cards = json.load(open(CARDS, encoding="utf8"))["cards"]
    vfx = json.load(open(VFX, encoding="utf8"))
    variants = vfx.get("impact_variants", {})
    style = vfx.get("impact_style", {})
    fam_of = {k: str(v.get("delivery", {}).get("impact", "burst")) for k, v in cards.items() if k not in OWN_SETS}
    by_fam = {}
    for k in sorted(fam_of):
        by_fam.setdefault(fam_of[k], []).append(k)
    out = {}
    for fam, ids in by_fam.items():
        base = REGISTER.get(fam, 2.0)
        for i, cid in enumerate(ids):
            card = cards[cid]
            var = variants.get(cid, {})
            form = str(var.get("form", ""))
            if form:
                shape = FORM_SHAPE[form]
                if form == "frame" and var.get("sparse"):
                    shape = "frame_sparse"
                if form == "cross" and var.get("diag"):
                    shape = "cross_diag"
                if form == "cross" and int(var.get("drops", 0)) >= 3:
                    shape = "drops3"
                if form == "spike" and var.get("tilt"):
                    shape = "spike_tilt"
                if form == "spike" and int(var.get("count", 1)) >= 2:
                    shape = "spike2"
                if form == "column" and int(var.get("count", 1)) >= 2:
                    shape = "column2"
                if form == "crack" and var.get("web"):
                    shape = "crack_web"
                if form == "spikes" and var.get("vine"):
                    shape = "vine"
                sec = float(var.get("sec", 0.5))
            else:
                shape = NO_FORM[cid]
                sec = float(style.get(fam, {}).get("sec", 0.25)) / 0.6
            note = round(PENTA[i % 5] * base * (2 ** (i // 5)), 1)
            pres = card.get("cast_presentation")
            windup = str(pres) if pres in ("hand", "body", "weapon", "throw") else \
                DELIVERY_WINDUP.get(str(card.get("delivery", {}).get("type", "")), "hand")
            out[cid] = {"family": fam, "vfx_form": form or "-", "impact_shape": shape, "note": note,
                        "impact_sec": round(min(0.4, max(0.12, sec * 0.6)), 3), "windup_shape": windup,
                        "windup_note": round(note / 2.0 if windup in ("hand", "body") else note, 1)}
    return out


def table_doc(cards):
    return {"_doc": "Per-card voices, built by tools/audio/card_voices.py from cards.json + the cast VFX index "
                    "(impact_variants form -> impact shape; family register + pentatonic degree -> note; VFX sec -> "
                    "length; cast_presentation / delivery -> wind-up). sfx_synth.py renders sfx_skill_card_<id>_*.",
            "cards": cards}


def apply(cards):
    a = json.load(open(EVENTS, encoding="utf8"))
    ev = a["events"]
    for cid, v in cards.items():
        ev["skill.card.%s.windup" % cid] = {"bus": "Skill", "priority": "normal",
                                            "files": ["res://assets/audio/sfx/sfx_skill_card_%s_windup_01.wav" % cid],
                                            "gain_db": -6}
        ev["skill.card.%s.impact" % cid] = {"bus": "Skill", "priority": "high",
                                            "files": ["res://assets/audio/sfx/sfx_skill_card_%s_impact_01.wav" % cid],
                                            "gain_db": -5}
        m = a["cards"].setdefault(cid, {})
        # own wind-up and impact; no generic commit on top (the impact follows), travel stays the shared delivery
        # streak because the travel VFX is shared too
        m.update({"windup": "skill.card.%s.windup" % cid, "impact": "skill.card.%s.impact" % cid, "commit": ""})
    with open(EVENTS, "w", encoding="utf8", newline="\n") as fh:
        fh.write(json.dumps(a, ensure_ascii=False, indent="\t") + "\n")


def check(cards):
    ok = True
    if not os.path.exists(OUT) or json.load(open(OUT, encoding="utf8"))["cards"] != cards:
        print("card_voices.json is stale: run tools/audio/card_voices.py")
        ok = False
    keys = [(v["impact_shape"], v["note"]) for v in cards.values()]
    if len(set(keys)) != len(keys):
        print("two cards share an impact shape and note")
        ok = False
    a = json.load(open(EVENTS, encoding="utf8"))
    for cid in cards:
        if a["cards"].get(cid, {}).get("impact") != "skill.card.%s.impact" % cid:
            print("audio_events.json does not map", cid, "to its own impact: run with --apply")
            ok = False
    return ok


if __name__ == "__main__":
    c = build()
    if "--check" in sys.argv:
        sys.exit(0 if check(c) else 1)
    with open(OUT, "w", encoding="utf8", newline="\n") as fh:
        fh.write(json.dumps(table_doc(c), ensure_ascii=False, indent=1) + "\n")
    print("wrote %d card voices to %s" % (len(c), os.path.relpath(OUT, ROOT)))
    if "--apply" in sys.argv:
        apply(c)
        print("events + card map written to", os.path.relpath(EVENTS, ROOT))
