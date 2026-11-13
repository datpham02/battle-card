# F3 — Passive Feedback: making the five passives visible

**Status:** DESIGN ONLY. No code, no assets, nothing committed. Written while `combat_view.gd` and
`src/audio` are held by other sessions, so that when they are free the work is wiring, not deciding.
**Date:** 2026-11-14
**Parent:** `docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md` phase F3.
**Depends on:** F1 (identity, accent colours — shipped), F2 (attributes — green, awaiting commit).

---

## 1. The problem, stated precisely

The audit found pillar 3 **mechanically complete and presentationally absent**: five passives, five
genuinely different mechanisms, and **not one line of VFX, audio or icon anywhere in the repo**. A
player cannot see a passive fire, cannot tell two characters apart by what happens on screen, and
cannot learn what their passive does by playing.

The naive fix — "give each passive a cue" — is wrong, and it is worth saying why before the spec.

**The five passives do not fire at comparable rates.** Read from the scripts:

| Passive | Hook | Fires | Where the cause is | Where the effect lands |
|---|---|---|---|---|
| `second_wind` | `on_match_won()` | **Once per won match** | the match ending | the run's HP, after combat |
| `wide_caster` | `modify_swing_duration(cells, dur)` | **Every cast of ≥ `min_cells`** | the player, at cast start | that cast's windup |
| `quick_blade` | `modify_damage(cells, dmg)` | **Every hit of ≤ `max_cells`** | the player's hit | the enemy, at impact |
| `hunter_mark` | `on_boss_thorn_step` / `on_player_zone_formed` | On a thorn event, then **3 s ICD** | the enemy's cell | the enemy (Rạn stack) |
| `prayer` | `on_frost_burst(damage)` | **Per Chill burst** on the enemy | the enemy | **the player's HP** |

Two of these fire on almost every action. Giving `wide_caster` and `quick_blade` a burst effect each
time would not read as "my passive is working" — it would read as wallpaper, and it would compete for
attention with the skill VFX, which is the thing the player actually needs to watch. The screen's
attention budget is already spent on casts, telegraphs and the formation map.

**So the rule for this phase is: frequency decides the form.**

| Band | Passives | Form |
|---|---|---|
| **Rare, outside combat** | `second_wind` | A full cue. It can be slow and satisfying; nothing competes with it. |
| **Gated, in combat** | `hunter_mark` (3 s ICD), `prayer` (per burst) | A real cue sized from the cell. These are events; treat them as events. |
| **Constant, per action** | `wide_caster`, `quick_blade` | **No new effect.** Modify the cue the action already produces, so the enhanced version is visibly different from the plain one. |

The third row is the design decision of this document. A passive that fires on every action should be
read as *a property of the action*, not as a separate event.

---

## 2. Per-passive specification

Shared constraints, from the project's standing rules: VFX are sized from the **cell**, bright, and
judged at 1× and 2× (not from a still). Floor effects sit in the **middle of the cell**, never at the
feet or the front edge. Effect text is **bare emphasised text, never a bordered chip**. Shapes are
**angular — any polygon, no circles**. Red is reserved for enemy telegraphs; the player HP green is
reserved for HP. Each cue is tinted with its character's accent from F1.

### 2.1 `second_wind` — Kiếm sĩ, `#8FA8BE` steel

*Mechanism:* +N HP after a won match, added before the max-HP clamp.

*Moment:* the victory/reward screen, not the match. The heal has already happened in `RunSession`.

*Visual:* a single angular ring — a hexagon outline, not a circle — expands once from the hero sprite
to roughly two cell widths and fades. The HP bar's **gained segment** lights in steel `#8FA8BE` for
the same beat, then settles into the normal HP green. One pulse, ~0.6 s, no repeat.

*Why this shape:* the player must connect "I won" with "I got HP back". Lighting the gained segment
is the connection; the ring is only what draws the eye to it. Without the segment highlight, the cue
is decoration.

*Audio:* `passive.second_wind` — one low sustained chime, struck **on the ring's first frame**, decay
inside 0.6 s. Bus `Combat`, priority `normal`. No drone, no riser.

*Rank display (F5):* when passive ranks land, the number in the gained segment is the only thing that
changes; the cue does not grow louder with rank.

### 2.2 `wide_caster` — Pháp sư, `#E08A2E` ember

*Mechanism:* casts covering ≥ `min_cells` wind up `duration_mult` times as long (0.75 = 25 % faster).

*Moment:* cast start, on the player.

*Visual:* **no new effect — two existing consumers of the windup already draw it.**
`CutActor.get_progress()` (0..1, documented to reach 1 exactly when the swing resolves) is read by
`telegraph_painter.gd:54`, which paints the telegraph at a quantized `k`, and by
`floor_dynamic_layer.gd:182` via `CastFloorFx.charge_step(...)`. For a qualifying cast, the player's
telegraph and charge step are drawn in ember `#E08A2E` instead of their default colour, completing
with a one-frame snap. A non-qualifying cast is unchanged.

Note the shape of the cue matches the mechanic: the passive makes the windup **shorter**, so the
honest read is the telegraph filling visibly faster in a different colour — the player sees the thing
that actually changed, not a symbol standing in for it.

*Why:* the player's question is never "did something happen?" — a cast is already loud. It is "was
*this* cast the fast one?". A colour difference on the thing they are already watching answers that;
a new particle does not.

*Audio:* **none.** Adding an event to every wide cast would spend a `Skill`-bus voice on information
the visual already carries. If an audible difference is wanted later, it should be a pitch offset on
the **existing** cast event rather than a new event — the mechanism and the right owner for it are an
open question (§4, Q2).

### 2.3 `quick_blade` — Sát thủ, `#6FD8E8` keen ice

*Mechanism:* hits covering ≤ `max_cells` deal `damage_mult` times damage.

*Moment:* impact, on the enemy.

*Visual:* **no new effect, and the codebase already contains the pattern to copy.**
`cut_hud_view.gd:2144` draws a hit's damage number in `PIN_BONUS_TEXT` ("pin blue") when Ghim
multiplied it — a keyword that boosted a hit already announces itself by **recolouring the number**.
`quick_blade` does exactly that in keen ice `#6FD8E8`. Nothing new is invented and the player already
knows how to read it.

Second beat, also existing: `UnitLayer` runs an OSFE hit feel (`CastVfx.hit_feel()`, white flash plus
shake per side, `get_flash_left`). For a boosted hit that flash is tinted keen ice instead of white.
One frame, inside the flash's own timeline.

*Why:* same argument as `wide_caster`, at the other end of the action. The impact is already the
loudest moment on screen; the passive should ride it, not follow it. And a convention the project has
already approved for Ghim beats a new convention invented for one passive.

*Audio:* **none**, for the same reason. The impact event already fires.

### 2.4 `hunter_mark` — Thợ săn, `#7FA64B` wood and cord

*Mechanism:* the enemy gains `fragile_stacks` Rạn when it steps onto the player's thorns, or when
thorns are laid on/next to its cell; then a `icd_sec` (3 s) internal cooldown.

*Moment:* on the enemy's cell, in combat. This is the one passive whose cue the player must read
**during** a fight, because it tells them a window has opened.

*Visual:* a floor mark, **centred in the enemy's cell** (standing rule — not at its feet, not at the
front edge): an angular bracket, two short wood-coloured strokes closing inward like a trap frame,
drawn over the cell for ~0.4 s, then handing off to the existing Rạn status indicator which persists.
Sized from the cell: the bracket spans roughly 70 % of the cell width so it reads at 1× from across
the board.

*Why a hand-off:* the mark is the *event*; Rạn is the *state*. The cue must not duplicate the status
indicator, or the player sees two things saying one thing.

*Audio:* `passive.hunter_mark` — one short wooden snap on the bracket's closing frame. Bus `Combat`,
priority `normal`, **`cooldown_ms: 400`** as a safety net (the 3 s ICD already gates it; the cooldown
exists so a future ICD change cannot turn it into a machine gun).

### 2.5 `prayer` — Giáo sĩ, `#C08FE8` stained glass

*Mechanism:* every Chill burst on the enemy heals the player `heal_per_burst` HP.

*Moment:* the burst happens **on the enemy**; the heal lands **on the player**. This is the only
passive whose cause and effect are in different places, and it is the one most likely to be missed.

*Visual:* a **connector**, not a flash. An angular line — two or three straight segments, no curve —
travels from the bursting cell across to the player's HP bar in `#C08FE8` over ~0.35 s, and the HP
bar's gained segment lights as it arrives. The existing Chill-burst effect is unchanged.

**Sized from the cell, not hairline.** The connector's stroke is **≥ 1/8 of a cell's width**, with a
brighter leading head about half a cell long. A one-pixel line is the single most likely way this cue
fails: it crosses the busiest part of the screen, and the project has already seen a VFX rejected for
being invisible from afar. It must be judged at 1× **and** 2× before it is called done — a still will
flatter it.

*Why:* without the connector the player sees a burst on the enemy and, separately, their own HP
rising, and never joins them. The whole informational content of this passive is the link.

*Audio:* `passive.prayer` — one short glass chime, struck **when the connector arrives** at the HP
bar, not when the burst fires. Bus `Combat`, priority `normal`, `cooldown_ms: 300`.

---

### 2.6 Standing-rule compliance, per cue

The user restated the cue rules when approving this phase. Mapping them to where each is honoured, so
a reviewer can check rather than trust:

| Rule | Where it binds in this spec |
|---|---|
| **Readable from afar, sized from the cell** | `second_wind` ring ≈ 2 cell widths · `hunter_mark` bracket ≈ 70 % of a cell · `prayer` connector stroke ≥ 1/8 cell with a half-cell head (§2.5) · `wide_caster` / `quick_blade` inherit the size of the telegraph and impact they recolour |
| **Judged at 1× and 2×, not from a still** | §2.5 explicitly, and acceptance criterion 1 requires a retained screenshot per passive at 1× |
| **Effect labels: bare emphasised text, no bordered chip** | `quick_blade`'s damage number (§2.3) — and it inherits the existing `PIN_BONUS_TEXT` treatment, which is already bare text |
| **Audio synced to a real frame, no waiting drone** | `second_wind` on the ring's first frame · `hunter_mark` on the bracket's closing frame · `prayer` on the connector's **arrival**, not on the burst · explicit "no drone, no riser" |
| **Angular shapes, no circles** | `second_wind` is a hexagon outline, stated as "not a circle" · `hunter_mark` is a two-stroke bracket · `prayer` is straight segments, "no curve" |
| **Floor VFX centred in the cell** | `hunter_mark` (§2.4) — the only floor effect here, centred, explicitly not at the feet or front edge |
| **No hand-painted details** | Icons are glyphs produced by script / workbench (§3), not painted over generated art |

### 2.7 One rule this phase cannot satisfy yet

**Audio must sync to real clip/VFX frames — but the VFX frames do not exist yet.** Every timing above
("first frame", "closing frame", "on arrival") is a *contract* for implementation, not a measurement.
When F3 is built, each cue's audio offset must be re-derived from the finished animation and proven
with an in-game capture plus a timing table, the way the skill audio was. Writing the numbers now
would be inventing them.

---

## 3. Icons

Five passive icons, one per passive, plus the five signature icons listed in the parent document.

- **Production: free only** (OD-6 approved) — scripted / `vfx_workbench` / `pixelfx`. No paid
  generation for icons.
- Flat angular glyph, no outline box (standing rule: icons over text, no borders), tinted with the
  character's accent, legible at **24 px** (HUD chip) and at select-card size.
- One glyph per mechanism, not per character: a closing bracket for `hunter_mark`, a struck chime for
  `prayer`, a short blade for `quick_blade`, a broad arc for `wide_caster`, a rising step for
  `second_wind`. A player who sees the icon on the select screen should recognise the cue in combat.
- Paths follow the F1 schema: `identity.passive.feedback.icon`, already specified in
  `assets/data/schema.md`.

---

## 4. Open questions — need an answer before implementation

| # | Question | Why it blocks | My recommendation |
|---|---|---|---|
| ~~Q1~~ | ~~Does the game show damage numbers on hits?~~ | — | **ANSWERED by reading the code, 2026-11-14.** Yes: `cut_hud_view.gd` `_draw_feedback_for` draws a per-hit damage number, and **already recolours it when a keyword multiplied the hit** — `PIN_BONUS_TEXT` for Ghim (`:2144`), a larger `CRIT_NUMBER_SCALE` for crits. So `quick_blade` follows an approved existing convention rather than needing a new one, and `UnitLayer`'s existing white hit flash (`CastVfx.hit_feel`) gives it a second beat for free. §2.3 is updated; no new system is required. |
| **Q2** | `wide_caster` / `quick_blade` audio: no new event, or a pitch offset on the existing cast/impact event? `audio_events.json` has `step_pitch_semitones` and `step_gain_db` in `defaults`, but I have not confirmed what they apply to. | It decides whether F3 touches `src/audio` at all, which is the audio session's file. | **No audio for either** in F3. Ship the visuals, play it, and only add sound if the passives still read as invisible. Adding sound is cheap later; removing it after players learn it is not. |
| **Q3** | Where does the passive chip live in the combat HUD? The parent document proposes icon + rank beside the signature readiness. | F6 owns the select screen; the combat HUD is not yet assigned to a phase. | Put the chip in F3 with the cues — a cue the player cannot connect to a named passive teaches nothing. It is one icon in an existing HUD row. |
| **Q4** | `second_wind`'s cue is on the victory screen, which is run UI, not combat. Is that in F3's scope or F6's? | Scope boundary only; the work is small either way. | Keep it in F3. The phase is "the player can see each passive"; splitting one of the five into another phase breaks that acceptance criterion. |

---

## 5. Acceptance criteria for F3

1. Each of the five passives has a cue a player can identify **from across the board at 1× speed**,
   with a retained screenshot per passive in `production/qa/evidence/character-system/`.
2. `wide_caster` and `quick_blade` add **no new on-screen object** — a qualifying action differs from
   a non-qualifying one, and that difference is visible in a side-by-side capture.
3. `prayer`'s connector is visible from burst to HP bar in one capture — the cause and the effect in
   the same frame.
4. `hunter_mark`'s floor mark is **centred in the cell** and hands off to the Rạn indicator without
   duplicating it.
5. Every cue is tinted with its character's accent from `characters.json` — **no colour is hardcoded
   in combat code** (the F2 rule, extended to presentation).
6. Each registered passive has an icon, and `passive_feedback_test.gd` fails if any passive is missing
   an icon, a vfx key or (where specified) an audio key.
7. No new audio event fires more than once per gating interval; the full suite reports **0 script
   errors**, read from the runner's `se` column, not only `FAILS=`.

---

## 6. What this phase deliberately does not do

- **No new status effects, no mechanic changes.** Every passive's numbers and triggers stay exactly as
  they are. F3 is presentation only; if a passive turns out to be weak, that is a balance question for
  the F5 slice, not a reason to change it while adding its cue.
- **No paid art.** Icons are free-produced (OD-6).
- **No audio for the two high-frequency passives** (Q2), pending play-testing.
