# Character System Redesign — Audit & Design Proposal

**Status:** DESIGN ONLY — nothing implemented, nothing deleted, no source or asset touched.
**Date:** 2026-11-13
**Scope:** move the game from a Class/Weapon-based character model to a Character-based one, built on
five mandatory pillars (Identity, Base Attributes, Passive, Character Skills, Run Progression).
**Repo:** `C:\WorkSpace\my-game`, branch `main`, Godot 4.6.3 / GDScript.
**Decisions:** all nine open decisions were **approved by the user on 2026-11-13**, each as recommended.
See the decision log below and section G. Still design only — approval of the *design*, not a go-ahead
to implement; no phase starts without a further instruction.
**Sibling sessions holding uncommitted work (not touched by this audit):** multi-enemy
(`combat_state.gd`, `combat_view.gd`, `status_effects.gd`, `trait_host.gd`, `pattern_controller.gd`,
`src/audio`), monster-skills (`enemy_skills.json`), card-art (`assets/art/cards`, asset registry).

---

## Decision log — approved 2026-11-13

| # | Decision as approved |
|---|---|
| OD-1 | **`phap_su` max_hp 210 → ~170.** The "frail" description stays; the 5 s focus and `wide_caster` are the payoff. Needs a bot balance pass. |
| OD-2 | **Add exactly two base attributes:** `cast_speed_mult`, `hazard_resist_mult`. **`formation_fade_mult` is NOT added** (it would change the signature charge rate). |
| OD-3 | **Owned card pool 3 → 5 per character** (+10 cards). Each new card must introduce a different `effect` / `delivery` / `shape_clause` combination. **Sequenced after the card-art session reports.** |
| OD-4 | **Tighten `starter_identity_test.gd`:** ≤2 shared cards between any two characters, ≤1 copy of the shared base card, ≥4 distinct cards per starter deck. Forces `sat_thu` and `giao_si` deck edits + a bot balance pass. |
| OD-5 | **Relics stay character-agnostic.** The earlier decision in `schema.md:629` stands; per-character progression lives in boons. |
| OD-6 | **Icons (passive ×5, signature ×5, boon ×15) are produced free** (scripted / `vfx_workbench` / `pixelfx`, 0 gen). **Only the 5 portraits may use paid generation**, each anchor passing the written checklist with a separate user yes per call. |
| OD-7 | **F5 is built, but last and as its own slice**, with its own bot balance pass and its own run-save v7 → v8 bump. F1–F4 + F6 ship first. |
| OD-8 | **I draft lore / personality / playstyle for all 5; the user approves or redirects each.** **Sino-Vietnamese names are intentional** — keep `Kiếm sĩ` / `Pháp sư` / `Sát thủ` / `Thợ săn` / `Giáo sĩ`; the lore is written to sit inside Tessera's Western-fantasy direction rather than to justify a wuxia reading. |
| OD-9 | **The audit's premise is accepted:** there is no Class/Weapon system to migrate away from. Phase F8 is documentation wording only. |

**Resulting phase order:** F1 → F2 → F3 → F4 → F6 → F8 → F9, then **F5 alone, last**.

---

## 0. Headline finding — read this first

**The premise of the task does not match the repo.** This project has **no Class system and no Weapon
system to migrate away from.** It is already Character-based, and has been since an explicit user
decision recorded in `design/game-brief.md` line 95:

> ### Nhân vật (018, 021) — không có "lớp"
> **Không có "lớp" (quyết định 2026-10-22):** không lá nào gắn nhân vật, thưởng không nghiêng theo nhân vật.

`assets/data/characters.json` already holds 5 characters, each with id, name/desc keys, own HP, own
step-speed multiplier, own focus window, **one unique passive**, **one unique signature (tuyệt kỹ)**,
**its own starter deck**, and an unlock condition. `src/passives/` and `src/signatures/` are registry-
based plug-in systems, exactly the shape the task asks for.

What actually exists that *contains the word* "class" or "weapon":

| Hit | What it really is | Verdict |
|---|---|---|
| `schema.md:604` "Playable **classes**" | Stale wording in the data schema doc. The data is characters. | **Terminology fix only** — no code change |
| `character_config.gd:2` "Playable characters (**classes**)" | Same stale wording in a doc comment. | **Terminology fix only** |
| `cast_presentation: "weapon"` (`skill_config.gd:24-25`, 62 cards) | **Animation routing key**, not equipment. Picks which cast clip a body plays (`weapon`/`hand`/`throw`/`body`/`special`). The hero carries one fixed body sprite; nothing is equippable, nothing changes stats. | **KEEP — do not remove.** Renaming it is a cosmetic, test-breaking change with zero gameplay gain. |
| `UnitLayer.WEAPON_CAST_BODIES` (`unit_layer.gd:112`) | List of the 4 hero sprite sheets whose `cast_gesture` clip shows a held implement, so a `hand` card does not play a sword swing. | **KEEP** |
| `character_select_view.gd:541`, `save_slots_view.gd:337` "raised-**weapon** clip" | Comment about sprite frame height. | **KEEP** |

**Therefore the real work is not a migration away from Class/Weapon. It is deepening the existing
Character model so each of the five pillars is actually carried.** The sections below audit what each
pillar already has, what is thin, and what is missing, and propose the additions. The "Migration
Roadmap" in section F is written against that reality, and section G lists the decisions that need
your approval before any of it is built.

---

## A. Current Asset Audit

### A.1 Character definition (Pillar 1 + 2)

| Item | Purpose | Referenced by | Pillar | Reusable | Action | Risk |
|---|---|---|---|---|---|---|
| `assets/data/characters.json` (72 lines, 5 characters) | Source of truth: id, name/desc keys, max_hp, step_cooldown_mult, focus_max_sec, passive {id,params}, signature {id,params,cooldown}, starter_deck, unlock_by | `CharacterConfig` only | 1,2,3,4,5 | Yes | **Redesign (extend schema, additive)** | Low — new keys default-absent; `CharacterConfig._add` ignores unknown keys |
| `src/run/character_config.gd` | Loads, validates, clamps, exposes `ids/unlocked_ids/get_character/deck_of/default_id` | `game_flow.gd`, `run_controller.gd`, `run_session.gd`, `chapter_map_view.gd`, `screen_layout.gd`, `combat_view.gd`, 15+ tests | 1,2 | Yes | **Keep + extend** | Medium — every character test reads `get_character()`'s dictionary shape |
| `assets/data/schema.md` §`characters.json` (604-628) | Documents the above; calls them "Playable classes" | Humans and agents | — | — | **Redesign (wording + new keys)** | None |
| `assets/i18n/strings.csv` `character.<id>.name/.desc` | Display name + a one-line description | `character_select_view.gd` via `tr()` | 1 | Yes | **Keep + extend** (lore/personality keys are missing) | Low |
| `design/game-brief.md` §"Nhân vật (018, 021)" | The design record for characters (workflow mode has no per-system GDD here) | Design | 1 | Yes | **Keep + extend** | None |

**Base attributes present today — only three:** `max_hp`, `step_cooldown_mult`, `focus_max_sec`.
Everything else a hero does numerically comes from shared `assets/data/combat.json`
(`step_cooldown_ref_sec`, `step_cooldown_exponent`, `step_cooldown_min_sec/max_sec`,
`player_start_cell`, `hazards.mire_step_mult`, `telegraph.*`) or from the cards.
This is the thinnest of the five pillars.

**No hardcoded per-character numbers were found in shared combat code.** `combat_view.gd` reads the
character dictionary through `match_params["character"]`; `combat.json` carries only the shared
baseline. This is a genuine strength of the current design and must be preserved.

### A.2 Passive system (Pillar 3)

| Item | Purpose | Referenced by | Reusable | Action | Risk |
|---|---|---|---|---|---|
| `src/passives/base_passive.gd` | Hook surface: `setup`, `on_match_start`, `on_match_won` → extra heal, `modify_swing_duration`, `modify_damage`, `tick`, `on_frost_burst`, `on_boss_thorn_step`, `on_player_zone_formed`, `teardown` | 5 passives, `combat_view.gd` | Yes | **Keep + extend hooks** | Medium — new hooks are additive but `combat_view.gd` is held by multi-enemy |
| `src/passives/passive_registry.gd` | id → script map (`SCRIPTS` const) | `character_config.gd` (validation), `combat_view.gd:1045` | Yes | **Keep** | Low |
| `second_wind` / `wide_caster` / `quick_blade` / `hunter_mark` / `prayer` | One per character | `characters.json` | Yes | **Keep** | Low |
| Passive **feedback** (VFX/audio) | — | **Does not exist.** No passive script references a flash, banner, SFX or audio event. `prayer`'s "+N" HP flash is the generic heal flash, not a passive cue. | — | **Missing — design needed** | — |
| Passive **icon** | — | **Does not exist.** `character_select_view.gd` draws the passive as text only. No `assets/art/.../passive*` file exists. | — | **Missing — design needed** | — |

**Verdict on Pillar 3:** mechanically complete and well-factored; **presentationally absent.** A
player cannot see a passive fire. Per `vfx-readable-from-afar` and the project's own
verification-driven standard, that is the single biggest gap in the passive pillar.

### A.3 Signature / tuyệt kỹ (also Pillar 3-adjacent, and the main identity driver)

| Item | Purpose | Referenced by | Reusable | Action |
|---|---|---|---|---|
| `src/signatures/base_signature.gd`, `timed_signature.gd` | Base + timed-window subclass; exposes `zone_sec_mult`, `extra_thorn_cells`, `fragile_mult_override`, `frost_burst_mult` as read-through knobs that shared combat code consults | all 5 signatures, `combat_view.gd`, `cut_effects.gd` | Yes | **Keep** |
| `signature_registry.gd` | id → script | `character_config.gd:_read_signature` | Yes | **Keep** |
| `tram` / `thien_hoa` / `anh_bo` / `vay_bat` / `thanh_an` | One per character; charged by the formation map (`formation_map.gd`), gated by `cooldown_sec` | `characters.json` | Yes | **Keep** |
| Signature feedback | `UnitLayer` `awaken` clip while active (`unit_layer.gd:588`); `overlay_layer.gd` signature forms per card | — | Yes | **Keep** |

Signatures are the one pillar with real presentation. They are the model the passives should follow.

### A.4 Character skills / skill ownership (Pillar 4)

| Item | Purpose | Referenced by | Reusable | Action | Risk |
|---|---|---|---|---|---|
| `assets/data/cards.json` — **62 cards** | All player and enemy skills; one flat pool | `SkillConfig` | Yes | **Keep** | — |
| `cards.json` `hero` field (`skill_config.gd:233-237`) | **This is character skill ownership and it already exists.** 15 cards are owned: 3 per character × 5. A hero card may sit in its owner's starter deck but **never** enters a shared reward / shop / event pool. | `reward_roller.gd:195-226`, `shop_logic.gd`, `event_logic.gd`, `hero_card_pool_test.gd` | Yes | **Keep** | — |
| `cards.json` `hero_reward` flag | 12 of the 15 hero cards may be offered **in that hero's own rewards only** (Skill v2 Q3) | `reward_roller.gd:226` | Yes | **Keep** | — |
| Hero cards by owner | `kiem_si`: `do_kiem`, `ngan_kiem`*, `tram_dia`* · `phap_su`: `hoa_loi`, `hoa_tuyen`*, `thien_thach`* · `sat_thu`: `song_dao`, `dau_tu`*, `phi_tieu`* · `tho_san`: `bay_kep`*, `gai_no`*, `moc_keo`* · `giao_si`: `thanh_thuan`*, `chuong_thanh`*, `thien_quang`* (`*` = `hero_reward`) | — | Yes | **Keep; the pool is thin (3 each)** | — |
| `starter_deck` per character | 6 cards | `CharacterConfig.deck_of` | Yes | **Keep** | — |
| `tests/unit/run/starter_identity_test.gd` (Story 040 C2) | **Already enforces deck distinctness:** ≥3 of 6 cards in that character's own direction, ≤2 copies of the shared base card `kiem_khi`, and any two characters share ≤3 cards (duplicates counted) | CI | Yes | **Keep — raise the bar** | — |
| Shared mechanics reuse | `effect` keys, `delivery` blocks, `shape_clause`, `requires_shape`, `resolve`, `echo`, status keywords (Ghim/Đốt/Rạn/Hàn) are all shared logic driven by data | `cut_effects.gd`, `skill_delivery.gd`, `zone_rules.gd`, `status_effects.gd` | Yes | **Keep — this is the no-reskin engine** | — |

**Current starter decks (verbatim):**

| Character | Starter deck | Shared-base copies |
|---|---|---|
| `kiem_si` | `do_kiem`, `kiem_vu` ×2, `thiet_kiem` ×2, `chan_phong` | 0 `kiem_khi` |
| `phap_su` | `kiem_khi`, `hoa_xa`, `hoa_tinh` ×2, `hoa_tran`, `bang_phong` | 1 |
| `sat_thu` | `kiem_khi` ×2, `kiem_vu`, `thiet_kiem`, `bang_chau`, `han_kiem` | 2 |
| `tho_san` | `kiem_khi` ×2, `tran_gai` ×2, `gai_doc`, `ran_kich` | 2 |
| `giao_si` | `kiem_khi` ×2, `han_khi` ×2, `han_kiem` ×2 | 2 |

**Finding (flagged against your "characters must feel different from match one" rule):** `sat_thu`
shares `kiem_vu` + `thiet_kiem` with `kiem_si` and `han_kiem` with `giao_si`; four of five decks open
with `kiem_khi`. The existing test permits this (≤3 shared). It is inside the rule as written, but it
is the closest thing in the repo to "same cards, different ratio", and **`kiem_si` alone opens with a
deck containing none of the shared base card** — i.e. the standard is already achievable. Tightening
the gate is tightened in F4 (**OD-4 approved**): ≤2 shared, ≤1 base copy, ≥4 distinct cards. It changes balance, so it needs a bot pass.

### A.5 Progression during a run (Pillar 5)

| Item | Purpose | Referenced by | Character-aware? | Action |
|---|---|---|---|---|
| `assets/data/rewards.json` + `src/run/reward_roller.gd` | 3-of-N card offers, rarity weights, luck curve, upgrade offers, removals, piece offers, per-node-kind rules, v2 reward tiers 1–3 | `run_controller.gd` | **Yes** — via `hero_id` for `hero_reward` cards | **Keep + extend** |
| Card upgrade levels (`max_card_level: 3`, `upgrade` block per card) | Picking an owned card upgrades it (+2 max) | `reward_roller.gd`, `run_session.gd` | No | **Keep** |
| `src/relics/` (10 relics + `config_mod_relic`) | Run-long passive **rule changes**, not stat sticks. Explicitly **no per-character relics** (`schema.md:629`) | `relic_roller.gd`, `relic_registry.gd` | **No, by design** | **Keep — OD-5 approved: relics stay shared** |
| `src/pieces/` + `pieces.json` | Polyomino piece deck; shape rewards, shape removals | `piece_deck_view.gd` | No | **Keep** |
| `assets/data/kiep_levels.json` + `kiep_rules.gd` | 10 stacking difficulty levels, unlocked **per character** (`progress_state.get_kiep_unlocked(character_id)`) | `character_select_view.gd` (Story 038 panel) | **Yes** | **Keep** |
| `assets/data/achievements.json` + `unlock_rules.gd` | Milestone unlocks; `unlock_by` on `tho_san` (`hunter_path`) and `giao_si` (`mercy_path`) | `character_config.set_unlock_source` | **Yes** | **Keep** |
| `assets/data/economy.json`, `shop_logic.gd`, `event_logic.gd` | Gold, shop, events | — | Via `hero_id` gating only | **Keep** |
| **Passive upgrades / variants** | — | **Do not exist** | — | **Missing — design needed** |
| **Signature upgrades / variants** | — | **Do not exist** | — | **Missing — design needed** |

**Verdict on Pillar 5:** run progression is rich and shared, and it is already character-aware in two
places (hero card rewards, per-character Kiep). What is missing is **progression that changes the
character itself** — the passive and the signature are fixed from match one to the end of the run.
That is where "meaningful build differences" per character has to come from, and it is the second
biggest gap after passive feedback.

### A.6 Visual assets (Pillar 1 presentation)

| Item | State | Action |
|---|---|---|
| Hero body sheets `assets/art/units/unit_{kiem_si,phap_su,sat_thu,tho_san,giao_si}_sheet.png/.json` | **Exist, complete, approved.** 14-frame sets, palette-locked, committed (`c72ff7f`, `f262016`, `9d7ad25`, `b04ca62`, `52636a9`) | **Keep — do not regenerate** |
| Per-unit idle/movement motion profiles | Exist (commit `dae2794`) | **Keep** |
| **Character portraits** | **None.** `find assets/art -iname "*portrait*"` → 0 results | **Missing** |
| Character select card art | **None** — `character_select_view.gd` draws the body sheet's frames plus code-drawn text/panels | **Redesign** |
| **Passive icons** | **None** | **Missing** |
| **Signature icons** | **None** (signature is text + the in-combat `awaken` clip + overlay forms) | **Missing** |
| Card art `assets/art/cards/*.png` | 36 cards, **owned by the card-art session right now** | **Do not touch** |
| Class / weapon UI | **None exists** — nothing in the UI shows a class or a weapon | **Nothing to remove** |

### A.7 Save / load

| Item | Shape | Character data | Risk of change |
|---|---|---|---|
| `src/run/progress_state.gd` — **version 8** | Permanent progress: locale, regions beaten, best floor, seen cards, milestones (`runs_won:<character_id>`), unlocks per kind (`character`/`card`/`piece`/`relic`/`region`), `_kiep_unlocked` / `_kiep_best_won` **keyed by character id**, play time | Yes, keyed by id | **HIGH** — any new permanent per-character state needs a v9 bump with a documented v8 fallback |
| `src/run/run_session.gd` — save **version 7** | In-progress run: `character` (id string only), floor, region, map, deck, hp, seed, relics, pieces, stats, `kiep_level` | **Only the id** — stats/passive/signature are re-derived from `characters.json` at load | **MEDIUM** — a character's live passive/signature *state* is not saved; adding in-run character progression (F5) **requires a v8 run-save bump** |
| `src/run/save_slots.gd` / `save_slots_view.gd` | 3 slots; the view draws the character's body frames | id only | Medium |
| **Renaming or removing a character id** | — | — | **Breaks saves silently.** `run_session.gd:1221` drops a run whose character id is unknown; `progress_state` keeps orphan `runs_won:`/kiep keys forever. **No character id may ever be renamed.** |

---

## B. Proposed Character Architecture

### B.1 Principle

Keep every existing mechanism. **Extend `characters.json` additively** and add two new registries that
mirror the ones that already work (`PassiveRegistry`, `SignatureRegistry`). No new per-character
system, no per-character code path in shared combat: everything a character does must be either data,
or a registered plug-in that shared code calls through a fixed hook.

**Hard rules carried forward from the current design (do not break):**
1. No gameplay number for a character lives in shared combat code.
2. A character id is permanent (saves key on it).
3. Shared mechanics are reused through `effect` / `delivery` / `shape_clause` data, never by copying a
   card and changing one number (`starter_identity_test.gd` is the gate).
4. Relics stay character-agnostic (`schema.md:629`) — **OD-5 approved: not reopened.**

### B.2 Resource relationships

```
characters.json ── id (PERMANENT KEY, saves depend on it)
  ├─ identity{}            NEW   name/desc/lore/personality/playstyle keys, portrait path, accent colour
  ├─ attributes{}          EXTEND  max_hp, step_cooldown_mult, focus_max_sec  (+ proposed, see B.3)
  ├─ passive{id,params}    EXISTS → PassiveRegistry → src/passives/<id>.gd : BasePassive
  │    └─ feedback{}       NEW     vfx id + audio event id + icon path
  ├─ signature{id,params}  EXISTS → SignatureRegistry → src/signatures/<id>.gd : BaseSignature
  │    └─ feedback{}       NEW     icon path (vfx/audio already exist via overlay/awaken)
  ├─ skill_pool{}          NEW     explicit view over the ownership cards.json already carries
  │    ├─ starter_deck[]   EXISTS
  │    └─ (derived) hero cards = cards.json entries with hero == <id>
  ├─ progression{}         NEW     boon tracks (see B.4) + the existing unlock_by / kiep hooks
  └─ unlock_by             EXISTS → achievements.json → UnlockRules → ProgressState
```

### B.3 Proposed schema (additive — every new key optional, old files keep loading)

```jsonc
{
  "id": "kiem_si",                      // PERMANENT. never rename.
  "identity": {                          // NEW — pillar 1
    "name_key": "character.kiem_si.name",        // moved here; top-level kept as fallback
    "desc_key": "character.kiem_si.desc",
    "lore_key": "character.kiem_si.lore",        // NEW string, 2-3 sentences
    "personality_key": "character.kiem_si.personality",  // NEW, one line
    "playstyle_key": "character.kiem_si.playstyle",      // NEW, one line, player-facing
    "accent_color": "#8FA8BE",                   // select screen + passive VFX tint (steel)
    "portrait": "res://assets/art/portraits/portrait_kiem_si.png",  // NEW asset
    "select_art": "res://assets/art/select/select_kiem_si.png"      // NEW asset (optional)
  },
  "attributes": {                        // NEW wrapper — pillar 2. Old flat keys still read.
    "max_hp": 200,
    "step_cooldown_mult": 1.0,
    "focus_max_sec": 4.0,
    "cast_speed_mult": 1.0,              // NEW (OD-2 approved): multiplies card windup (CutActor duration)
    "hazard_resist_mult": 1.0            // NEW (OD-2 approved): multiplies mire/burn/thorn tick taken
    // NOTE: `formation_fade_mult` was proposed and REJECTED (OD-2) — it would change the signature charge rate.
  },
  "passive": {
    "id": "second_wind",
    "params": {"heal_after_match": 20},
    "feedback": {                        // NEW — pillar 3 presentation
      "icon": "res://assets/art/icons/passive_second_wind.png",
      "vfx": "passive_pulse",            // key into the shared VFX registry
      "audio": "passive.second_wind"     // key into audio_events.json
    }
  },
  "signature": { "...": "unchanged", "feedback": {"icon": "res://assets/art/icons/sig_tram.png"} },
  "skill_pool": {                        // NEW — pillar 4, explicit instead of derived
    "starter_deck": ["do_kiem", "kiem_vu", "kiem_vu", "thiet_kiem", "thiet_kiem", "chan_phong"],
    "owned_cards": ["do_kiem", "ngan_kiem", "tram_dia"],   // must agree with cards.json `hero`
    "affinity": ["slash", "guard"]       // NEW tags; biases shared-pool offers (pool is 5 owned cards, OD-3)
  },
  "progression": {                       // NEW — pillar 5
    "boons": ["kiem_si_edge", "kiem_si_endurance", "kiem_si_reach"],  // ids into BoonRegistry
    "passive_ranks": [                   // NEW: the passive can be upgraded during a run
      {"heal_after_match": 20}, {"heal_after_match": 32}, {"heal_after_match": 45}
    ],
    "signature_variants": ["tram_bleed", "tram_sweep"]     // ids into VariantRegistry
  },
  "unlock_by": ""                        // unchanged
}
```

**Validation rules to add to `CharacterConfig`** (same style as today — warn and drop, never crash):
`identity.accent_color` must parse as a colour else a default; `portrait`/`select_art`/icon paths that
do not exist → warning, the view falls back to the body sheet / code-drawn icon;
`attributes.*_mult` ≤ 0 → 1.0; `skill_pool.owned_cards` must match `cards.json` `hero` exactly
(mismatch → warning, `cards.json` wins — one source of truth for ownership);
unknown `boons` / `passive_ranks` beyond 3 / unknown `signature_variants` → warning and dropped.

### B.4 Two new registries (mirroring what already works)

| New file | Mirrors | Contract |
|---|---|---|
| `src/progression/boon_registry.gd` + `src/progression/base_boon.gd` | `PassiveRegistry` / `BasePassive` | A **boon** is a character-owned run upgrade offered by the existing `RewardRoller`. Same hook surface as `BasePassive`, plus `on_offer()` for the reward card text. A boon never adds a flat stat; it changes a rule, like a relic. |
| `src/signatures/variant_registry.gd` | `SignatureRegistry` | A **signature variant** replaces one signature's params and may override one hook, chosen once per run at a boss/forge node. |

Both are pure additions. Shared combat code gains **no** `if character_id ==` branch: `CombatView`
instantiates boons the same way it instantiates the passive (`_setup_passive`, line 1038).

### B.5 Directory structure (new paths only — nothing moves)

```
assets/
  art/
    portraits/        NEW  portrait_<id>.png        (5)
    select/           NEW  select_<id>.png          (5, optional; free production only)
    icons/            NEW  passive_<id>.png (5), sig_<id>.png (5), boon_<id>.png (15)
  data/
    characters.json        EXTENDED (additive)
    boons.json        NEW  boon id -> {name_key, desc_key, params, rarity, character}
src/
  progression/        NEW  base_boon.gd, boon_registry.gd, <boon_id>.gd ...
  signatures/
    variant_registry.gd    NEW
docs/design/character-system/   THIS DOC
tests/unit/run/
  character_identity_test.gd   NEW
  boon_registry_test.gd        NEW
tests/unit/combat/
  passive_feedback_test.gd     NEW
```

### B.6 Worked example — `kiem_si` (Swordsman) across all five pillars

**Pillar 1 — Identity.** Name `Kiếm sĩ` / Swordsman. Accent `#8FA8BE` (steel — `world-context.md` §6 block material, not an invented gold).
Lore (NEW, draft, needs approval): a sworn blade of a fallen order who kept the oath after the order
stopped existing; he reads a duel as a single long sentence and tries to end it in one clause.
Personality: terse, patient, never taunts. Playstyle line shown to the player: *"Few casts, each one
heavy. Hold the line, then end it."* Recognisable without any class or weapon label because the
identity is carried by the accent colour, the portrait, the `do_kiem` opening card, the `awaken`
stance during Trảm, and the passive's gold pulse — not by the word "swordsman".

**Pillar 2 — Base Attributes.** `max_hp` 200 (highest tier with `giao_si`), `step_cooldown_mult` 1.0,
`focus_max_sec` 4.0 — all three already in the file. Proposed additions: `cast_speed_mult` 0.95 (his
heavy cards commit slightly faster than their cell count implies) and `hazard_resist_mult` 0.9 (he eats
ground damage — a real nerf, deliberate). Both approved under OD-2; `formation_fade_mult` was rejected.

**Pillar 3 — Passive: `second_wind`.**
*Effect:* heals +20 HP after a won match, on top of the run's between-match heal.
*Trigger:* `BasePassive.on_match_won()` → return value added by `RunSession.complete_node(passive_heal)`
before the max-HP clamp.
*Combat interaction:* it does not touch the match itself, so it never interacts with damage order
(`card dpc × cells → Ghim → passive → signature`). It is a **run-economy** passive: it converts clean
wins into fewer rest-node visits, which frees nodes for reward/shop. This is why it pairs with his
high HP rather than duplicating it.
*VFX/audio feedback (NEW, missing today):* on the victory screen, a gold ring pulses outward from the
hero sprite and the HP bar's gained segment lights in the accent colour, one cue, ~0.6 s;
audio event `passive.second_wind` — a single low sustained chime, synced to the ring's first frame
(per the `skill-audio-follows-animation` rule). Sized from the cell, readable from afar.

**Pillar 4 — Character Skills.** Pool = 3 owned cards (`do_kiem` starter-only, `ngan_kiem` and
`tram_dia` offered in his rewards) + the shared pool. Starter deck `do_kiem`, `kiem_vu` ×2,
`thiet_kiem` ×2, `chan_phong` — the only deck with zero copies of the shared base card. Every one of
his cards reuses shared logic: `effect: damage`, `delivery.type` from the shared enum,
`requires_shape`/`shape_clause` from the shared shape tags. Nothing is a reskin: `do_kiem` is a parry
card (cast rhythm `parry`), `tram_dia` is a delayed eruption, `ngan_kiem` is multi-wave.
*Gap:* 3 owned cards is thin for a 35-node run. **OD-3 approved: his pool grows to 5**, the two new
cards sequenced after the card-art session reports, each introducing a different effect/delivery/shape
combination rather than a tuned copy.

**Pillar 5 — Progression.** Today: card upgrades (×3), relics, pieces, per-character Kiep 1–10.
Proposed additions, all through the **existing** `RewardRoller`:
- `passive_ranks`: rank 2 at the first region boss, rank 3 at the second — `heal_after_match` 20 → 32 → 45.
- Boons (one offered at each forge/rest node, 3 of his own + shared ones):
  `kiem_si_edge` (a cast of ≥4 cells also applies 1 Ghim), `kiem_si_endurance` (the between-match heal
  also restores one revive charge every two regions), `kiem_si_reach` (Trảm's cell multiplier applies
  to the first cast *after* the window too).
- `signature_variants`, chosen once: `tram_bleed` (less lifesteal, leaves a damage-over-time) or
  `tram_sweep` (shorter window, hits the whole row). Two runs of the same character diverge from the
  first boss onward instead of only by deck.

---

## C. Character Design Matrix

`[MISSING]` = not in the repo and not decided. `[PROPOSED]` = drafted in this doc, **needs approval**.

| Character | Identity | Base Attributes | Passive | Skill Pool | Progression |
|---|---|---|---|---|---|
| **`kiem_si`** Kiếm sĩ / Swordsman | Name ✓ · desc ✓ · body sheet ✓ · **lore ✓ · personality ✓ · playstyle ✓ · block material ✓ (steel) · accent ✓ `#8FA8BE`** (F1 shipped) · portrait `[MISSING — F9]` | HP 200 · step ×1.0 · focus 4.0 s · cast/hazard/fade mults `[PROPOSED]` | `second_wind` — +20 HP after a won match. Hook `on_match_won`. Icon `[MISSING]` · VFX `[MISSING]` · audio `[MISSING]` | Starter: `do_kiem`, `kiem_vu` ×2, `thiet_kiem` ×2, `chan_phong`. Owned: `do_kiem`, `ngan_kiem`*, `tram_dia`*. Signature **Trảm** (3 s, cells ×2, lifesteal 20 %) | Card upgrades ✓ · relics ✓ · pieces ✓ · Kiep 1–10 ✓ · boons `[PROPOSED ×3]` · passive ranks `[PROPOSED]` · sig variants `[PROPOSED ×2]` |
| **`phap_su`** Pháp sư / Mage | Name ✓ · desc ✓ · body sheet ✓ · **lore ✓ · personality ✓ · playstyle ✓ · block material ✓ (ember) · accent ✓ `#E08A2E`** (F1 shipped) · portrait `[MISSING — F9]` | HP **210 → ~170 (OD-1 approved, needs a bot balance pass)** · step ×1.0 · focus **5.0 s** (longest) · `cast_speed_mult` / `hazard_resist_mult` `[PROPOSED]` | `wide_caster` — casts of ≥4 cells wind up ×0.75. Hooks `modify_swing_duration`. Icon/VFX/audio `[MISSING]` | Starter: `kiem_khi`, `hoa_xa`, `hoa_tinh` ×2, `hoa_tran`, `bang_phong`. Owned: `hoa_loi`, `hoa_tuyen`*, `thien_thach`*. Signature **Thiên Hỏa** (detonate burn ×2, reset burn cooldowns, ignite lit cells) | as above; boons/ranks/variants `[MISSING — not drafted]` |
| **`sat_thu`** Sát thủ / Assassin | Name ✓ · desc ✓ · body sheet ✓ (v2 anti-lookalike anchor, approved) · **lore ✓ · personality ✓ · playstyle ✓ · block material ✓ (keen ice) · accent ✓ `#6FD8E8`** (F1 shipped) · portrait `[MISSING — F9]` | HP **180** (lowest) · step **×0.9** (fastest) · focus 4.0 s · rest `[PROPOSED]` | `quick_blade` — hits of ≤4 cells deal ×1.4. Hook `modify_damage`. Icon/VFX/audio `[MISSING]` | Starter: `kiem_khi` ×2, `kiem_vu`, `thiet_kiem`, `bang_chau`, `han_kiem`. Owned: `song_dao`, `dau_tu`*, `phi_tieu`*. Signature **Ảnh Bộ** (2 s no step cooldown, ≤3-cell hits ×1.75) | as above; **deck overlap with `kiem_si` is the highest in the roster — OD-4 approved, this deck must be edited in F4** |
| **`tho_san`** Thợ săn / Hunter | Name ✓ · desc ✓ · body sheet ✓ · unlock `hunter_path` ✓ · **lore ✓ · personality ✓ · playstyle ✓ · block material ✓ (wood and cord) · accent ✓ `#7FA64B`** (F1 shipped) · portrait `[MISSING — F9]` | HP 200 · step ×0.95 · focus 4.0 s · rest `[PROPOSED]` | `hunter_mark` — the enemy gains 1 Rạn when it steps on the player's thorn cell, or when thorns are laid adjacent to it; 3 s ICD. Hooks `tick`, `on_boss_thorn_step`, `on_player_zone_formed`. Icon/VFX/audio `[MISSING]` | Starter: `kiem_khi` ×2, `tran_gai` ×2, `gai_doc`, `ran_kich`. Owned: `bay_kep`*, `gai_no`*, `moc_keo`*. Signature **Vây Bắt** (zone ×1.5 s, +1 thorn cell, Rạn ×2) | as above; boons/ranks/variants `[MISSING]` |
| **`giao_si`** Giáo sĩ / Priest | Name ✓ · desc ✓ · body sheet ✓ · unlock `mercy_path` ✓ · **lore ✓ · personality ✓ · playstyle ✓ · block material ✓ (stained glass) · accent ✓ `#C08FE8`** (F1 shipped) · portrait `[MISSING — F9]` | HP 210 · step **×1.05** (slowest) · focus 4.5 s · rest `[PROPOSED]` | `prayer` — every Hàn burst on the enemy heals the player 8. Hook `on_frost_burst`, ctx `heal_player`. Icon/VFX `[MISSING]` (the "+N" flash is the generic heal flash) · audio `[MISSING]` | Starter: `kiem_khi` ×2, `han_khi` ×2, `han_kiem` ×2 — **only 3 distinct cards, the least varied opening in the roster — OD-4 approved, this deck must be edited in F4**. Owned: `thanh_thuan`*, `chuong_thanh`*, `thien_quang`*. Signature **Thanh Ấn** (+1 Hàn per hit, burst ×1.5) | as above; boons/ranks/variants `[MISSING]` |
| **Character 6+** | `[MISSING — none planned]` | — | — | — | — |

`*` = `hero_reward` (may appear in that character's own reward offers).

**Matrix-level findings**
1. Every character has a distinct passive *mechanism* (run economy / cast speed / damage / status
   application / sustain). The pillar-3 design is genuinely differentiated. Only its presentation is absent.
2. Identity data is ~30 % present: names, one-line descriptions and approved body sprites exist;
   lore, personality, playstyle, portrait and accent colour exist for nobody.
3. Base attributes are 3 keys for 5 characters; `phap_su` and `giao_si` differ from `kiem_si` by one
   number each (focus, step). That is the "same thing, different ratio" risk at the *stat* level.
4. Progression is identical for all five apart from hero-card rewards and the Kiep ladder.

---

## D. Asset Migration Matrix

| Existing asset | Current purpose | Proposed action | Reason | Dependencies / risk |
|---|---|---|---|---|
| `assets/data/characters.json` | 5 character definitions | **Redesign (additive)** | Carry pillars 1/2/5 data that has nowhere to live today | `CharacterConfig`; 15+ tests read `get_character()` — keep every existing key readable |
| `src/run/character_config.gd` | Load + validate | **Keep + extend** | New blocks need the same warn-and-drop validation | `game_flow`, `run_controller`, `run_session`, `combat_view`, `screen_layout`, `chapter_map_view` |
| `schema.md` §characters.json wording "Playable **classes**" | Doc | **Redesign (wording)** | Only remaining "class" terminology; it misleads every future agent | None |
| `character_config.gd:2` doc comment "(classes)" | Doc | **Redesign (wording)** | Same | None |
| `cast_presentation` key + `CAST_PRESENTATIONS` enum | Animation routing | **KEEP — explicitly not a weapon system** | It selects a cast clip. Removing or renaming breaks 62 cards, `unit_layer.gd` and `cast_presentation_test.gd` for no gameplay gain | `skill_config.gd`, `unit_layer.gd`, `tests/unit/battle/cast_presentation_test.gd` |
| `UnitLayer.WEAPON_CAST_BODIES` | Which bodies may play `cast_gesture` | **Keep** | Sprite-sheet fact, not equipment | `unit_layer.gd`, `cast_presentation_test.gd` |
| `src/passives/*` (7 files) | Passive plug-ins | **Keep + extend** | The architecture is already correct | `combat_view.gd` (**held by multi-enemy**) |
| `src/signatures/*` (9 files) | Signature plug-ins | **Keep + extend** | Same | `combat_view.gd`, `cut_effects.gd` |
| `cards.json` `hero` / `hero_reward` | Character skill ownership | **Keep** | **This already is pillar 4.** It must stay the single source of ownership truth | `reward_roller.gd`, `shop_logic.gd`, `event_logic.gd`, `hero_card_pool_test.gd` |
| `cards.json` 62 cards | Shared skill pool | **Keep** | Shared mechanics + data = the no-reskin engine | `SkillConfig` and most of combat |
| `tests/unit/run/starter_identity_test.gd` | Deck distinctness gate | **Keep — tighten (OD-4)** | Already enforces ≥3 direction cards, ≤2 base, ≤3 shared | Balance; tightening forces deck edits |
| `src/relics/*` | Run-long rule changes | **Keep as character-agnostic** | Per-character relics were explicitly rejected (`schema.md:629`) | **OD-5 approved: not reopened** |
| `rewards.json` / `reward_roller.gd` | Run offers | **Keep + extend** | Boons and passive ranks ride the existing offer flow — no second progression system | `run_controller.gd`, `reward_run_test.gd` |
| `kiep_levels.json` / `kiep_rules.gd` | Per-character difficulty ladder | **Keep** | Already character-aware | `progress_state` v8 |
| `achievements.json` / `unlock_rules.gd` | Character + content unlocks | **Keep** | Already character-aware | `progress_state` v8 |
| `progress_state.gd` (v8) | Permanent save | **Migrate to v9 only if B.4 adds permanent state** | Boons/ranks are **run** state, so v9 may be avoidable | **HIGH** — needs a documented v8 fallback |
| `run_session.gd` (save v7) | In-progress run | **Migrate to v8** | In-run boons / passive rank / signature variant must survive a mid-run quit | **HIGH** — `save_slots_test.gd`, `run_session_v*_test.gd` |
| `assets/art/units/unit_<hero>_sheet.*` ×5 | Hero bodies | **Keep — do not regenerate** | Approved, palette-locked, committed | — |
| `assets/art/cards/*` | Card art | **Do not touch** | Owned by the card-art session | — |
| Character portraits | — | **Create (new)** | Pillar 1 has no face | **OD-6: paid generation approved for the 5 portraits only**, one user yes per call |
| Passive / signature / boon icons | — | **Create (new)** | Pillars 3 and 5 are invisible | **OD-6: free production only** (scripted / vfx_workbench / pixelfx, 0 gen) |
| Any Class or Weapon UI | — | **Nothing to remove** | None exists | — |

---

## E. Visual Redesign Plan

| Visual | Today | Action | Notes |
|---|---|---|---|
| **Hero body sprites** (5 sheets, 14 clips) | Exist, approved, palette-locked, per-unit motion profiles | **Reuse unchanged** | These already carry identity in silhouette. The `no-lookalike-characters` and `no-hand-painted-details` rules apply to anything new. |
| **Portraits** (face, select + HUD + save slots) | None | **Create** — 5 new, one per character | Must pass the anchor checklist before any paid gen: name the closest famous character first, held prop visible, accent on big shapes, readable face, contrast. `verify-before-spending-gens`. |
| **Character select art** | Body frames + code-drawn panels | **Redesign the screen, reuse the sprites** | Add portrait, accent-coloured frame, playstyle line, passive icon + name, signature icon + name, deck strip. Angular shapes only, no circles (`angular-ui-shapes`); no rivet/stone frame — that is cards only (`rivet-frame-cards-only`); icon + number for stats, no boxes around map/stat icons (`icons-over-text-no-borders`). |
| **Passive icons** ×5 | None | **Create** | Flat angular glyph, accent-tinted, readable at 24 px and at select-card size. |
| **Signature icons** ×5 | None | **Create** | Same system as passive icons, visually one tier louder. |
| **Boon icons** ×15 (F5, which runs last) | — | **Create** | Can be procedural/scripted first pass; paid gen only if you approve. |
| **Passive in-combat VFX** ×5 | **None** | **Create** | One cue per passive, sized from the cell, bright, judged at 1× and 2× (`vfx-readable-from-afar`). Floor effects centred in the cell (`floor-vfx-centred`). Bare emphasised text, never a bordered chip (`effect-labels-no-box`). First pass through the free `vfx_workbench` / `pixelfx`, not paid gen. |
| **Passive audio** ×5 | **None** | **Create** | One cue each, synced to real VFX frames, no waiting drone (`skill-audio-follows-animation`). Note: `src/audio` is handed to the multi-enemy session — coordinate before touching `audio_events.json`. |
| **Signature VFX / audio** | Exist (`awaken` clip, overlay forms, per-card forms) | **Reuse** | Model for the passive cues. |
| **Combat HUD** | HP bar top-left, status row, formation map, signature readiness | **Redesign (small)** — add a passive chip (icon + rank) and the signature icon beside its readiness | Icons over text, no borders. |
| **Save-slot view** | Draws the body frames | **Redesign (small)** — swap in the portrait | `save_slots_view.gd:337` already handles frame height. |
| **Class / weapon UI** | **None exists** | **Nothing to remove** | — |

---

## F. Migration Roadmap — 9 phases

Each phase is independently shippable, data-first, and leaves the game playable. Phases 1–3 touch no
file currently held by another session except `combat_view.gd` (phase 3), which must wait for the
multi-enemy session to hand it back.

### F1 — Identity & data schema — **DONE + VERIFIED 2026-11-13, shipped in commit `40e6e3b4`**

> **Where F1 actually lives in the history.** F1 was committed and pushed as part of **`40e6e3b4`
> "feat: unified sound identity with a per-skill voice for every card"**, whose message describes only
> the audio work. Searching the log for the character system will not find it. The seven F1 artefacts
> inside that commit are `assets/data/characters.json`, `assets/data/schema.md`,
> `design/game-brief.md`, `src/run/character_config.gd`,
> `tests/unit/run/character_identity_test.gd`, this document, and the 20 `character.*` rows added to
> `assets/i18n/strings.csv` (exactly +20/−0 — no audio strings).
>
> **How it happened, so it is not repeated.** Eleven sessions share this working tree and therefore
> share one git index. The character-system session staged its six F1 paths while preparing its own
> commit and then ended its turn with them still staged; fifteen minutes later the audio session ran
> a correctly pathspec-limited `git add` and committed — and `git commit` takes the **whole index**,
> not the paths that were just added. Any session committing in that window would have swept the same
> files. The audio session did nothing wrong.
>
> **Not split.** `40e6e3b4` reached `origin/main` before the sweep was noticed, so separating it would
> mean force-pushing a branch eleven sessions share, three of them holding uncommitted work in this
> same checkout. The user chose this note over that rewrite. Content is unaffected: every F1 file is
> correct and its tests are green.
>
> **Rule for this repo:** stage and commit in a single operation, never end a turn with anything
> staged, and verify `git diff --cached --name-only` is exactly your own paths immediately before
> committing. To stage part of a file another session is editing, use a temporary index via
> `GIT_INDEX_FILE` so the shared index is never touched — and re-read `HEAD` immediately before
> building any blob, since `HEAD` can move mid-task (a blob built from a stale
> `git show HEAD:assets/i18n/strings.csv` silently duplicated 20 rows during this very cleanup).
Shipped: `identity` block on all 5 characters (`lore_key`, `personality_key`, `playstyle_key`,
`block_material_key`, `accent_color`, `portrait`, `select_art`); `CharacterConfig._read_identity` +
`identity_of()` / `accent_of()` with warn-and-clean validation; 20 new strings (vi + en) drawn from
`design/world-context.md` §6; `schema.md` and `character_config.gd` no longer say "classes";
`design/game-brief.md` points at this document; new `tests/unit/run/character_identity_test.gd`.
Accents were re-picked during F1: the first gold `#C8A24A` for `kiem_si` failed the test's own
colour-separation gate against `phap_su`'s amber, and `#8FA8BE` steel is both further away and truer
to `world-context.md` §6. `giao_si` moved `#B9A8E8` → `#C08FE8` for the same reason.
**Verification (2026-11-13, headless, on a slot granted by the monster-skills session):**
`character_identity_test.gd` 195 PASS / 0 FAIL / no SCRIPT ERROR in 3 s; `character_test.gd` FAILS=0;
`i18n_test.gd` FAILS=0 (which is what proves the 20 new keys resolve in both locales and collide with
nothing). The first run of the new suite reported 177 PASS / 0 FAIL **while silently skipping a whole
gate**: `Array[String] + Array[String]` yields an untyped Array in GDScript, so the typed assign threw
at runtime and aborted `_test_malformed_blocks_degrade`. Fixed with `append_array`; the 18 extra PASS
lines in the re-run are that gate actually executing. Worth remembering when reading any FAILS=0 from
a `SceneTree` suite here — a script error does not fail the suite, so FAILS=0 alone is not proof.

**Deliberately NOT in F1:** `phap_su` max_hp 210 → ~170 (OD-1) belongs to F2, where it can share one
bot balance pass with the two new multipliers.
- **Files:** `assets/data/characters.json`, `src/run/character_config.gd`, `assets/i18n/strings.csv`, `assets/data/schema.md`, `design/game-brief.md`
- **Depends on:** nothing. OD-1 and OD-8 are decided; I draft the lore, the user approves each character.
- **Regression risk:** `CharacterConfig.get_character()` returns a dictionary that 15+ tests read — new keys must be additive and old flat keys must keep working.
- **Tests:** extend `character_test.gd`; new `character_identity_test.gd` (every character has non-empty lore/personality/playstyle/accent; every string key resolves in both locales); `terminology_scan` must stay green on the new strings.
- **Acceptance:** all 5 characters have lore, personality, playstyle, accent colour; `schema.md` and `character_config.gd` no longer call characters "classes"; a `characters.json` without any new key still loads with zero warnings.

### F2 — Base attributes
- **Files (corrected 2026-11-13 after reading the code — the earlier list was wrong):**
  `assets/data/characters.json`, `src/run/character_config.gd` (**done**), and
  `src/combat/combat_view.gd` — **four lines, in that one file.** `cut_actor.gd`, `unit_mover.gd`
  and `tile_hazards.gd` need **no change at all**:
  - `cut_actor.gd` already has the hook: `begin_swing` multiplies by `duration_mult`, and the
    PLAYER's actor never sets it (it is only ever set on boss/enemy actors, `combat_view.gd:487`
    and `:2769`). `cast_speed_mult` is therefore one assignment to `_cut_actor.duration_mult`, and
    it lands exactly where the approved order wants it — before the passive.
  - `unit_mover.gd` already carries `cooldown_mult` for `step_cooldown_mult`. Nothing new.
  - `tile_hazards.gd` **never applies damage** — it only signals, and its own header says the caller
    applies the amount. The three places a hazard signal becomes HP loss are all in `combat_view.gd`:
    `_on_mire_damage` (:711), `_on_cell_fell` → `_state.damage(side, fall_damage)` (:729), and the
    vent tick handing `vent_tick_damage` to `StatusEffects.ignite` (:724). `hazard_resist_mult` goes
    at those three points. (Confirmed by the multi-enemy session, which owns the file.)
- **Scope (OD-2 approved):** exactly two new multipliers — `cast_speed_mult`, `hazard_resist_mult`. `formation_fade_mult` is out. **Also carries OD-1: `phap_su` max_hp 210 → ~170.**
- **Depends on:** F1; **the multi-enemy session handing back `combat_view.gd`** (it holds unverified Phase 4 work there). Every remaining F2 edit is in that one file, so there is nothing to do in parallel — do not interleave.
- **Regression risk:** `cast_speed_mult` multiplies the same duration the passive `modify_swing_duration` already modifies — **order must be fixed and documented**. The real order in `CutActor.begin_swing` is:
  `swing_duration(cells) * duration_mult` → passive `duration_modifier` → `cast_time_fn` →
  `duration_override` → relic `cast_time_modifier` → `channel_extend_fn`.
  **`cast_time_fn` and `duration_override` OVERWRITE rather than multiply**, so they already bypass
  the passive and will bypass the character attribute too. **OD-10, approved 2026-11-13: that is
  intended — a fixed cast time stays fixed**, consistent with `cast_time_fn` already replacing the
  passive. Anything that must act as a *global* speed factor has to be applied AFTER those two or it
  silently does nothing for every Skill v2 fixed-cast card.
  `hazard_resist_mult` must sit at the three attribution points above and **not** inside the shared
  hazard tick: `side` is now a unit key rather than a board half, so a resist applied in the tick
  would hand a player attribute to enemy units.
- **Tests:** new attribute unit test per multiplier (1.0 = today's numbers, exactly); `deck_power_test.gd` and the balance suites re-run and compared.
- **Acceptance:** with every new multiplier at 1.0 the full suite produces byte-identical balance output; each multiplier is proven to bite in isolation; no character number exists in shared combat code.
- **OPEN, found 2026-11-13 — the balance sim cannot see F2's attributes.** `tools/balance/deck_sim.gd`
  runs `tools/balance/sim_core.gd`, **not** `combat_view.gd`, and `sim_core.gd` **mirrors** the combat
  view's hazard wiring with its own `_on_mire_damage` (:3010), `_on_vent_erupted` (:3034) and
  `_on_cell_fell` (:3048). Verified by grep: `cast_speed_mult` and `hazard_resist_mult` appear
  **nowhere** in `sim_core.gd`. It reads `max_hp` (:818), `step_cooldown_mult` (:823) and
  `focus_max_sec` (:888) from the character, and sets `duration_mult` only on the BOSS actor (:919) —
  though its windup formula already multiplies by `actor.duration_mult` (:2337), so the hook exists.
  **Consequence:** the same four-line change must be mirrored into `sim_core.gd`, or the bot balance
  pass that OD-2 demands will measure nothing when either multiplier is tuned — the sim would report
  "no change" and the number would look safe. Harmless while both ship at 1.0; it must land **before**
  anyone tunes them. `sim_core.gd` was held and in use by the monster-skills calibration when this was
  found, so it was deliberately not touched.

### F3 — Passives: feedback + hooks
- **Files:** `src/passives/*.gd`, `src/combat/combat_view.gd` **(blocked on the multi-enemy session)**, `src/battle/overlay_layer.gd`, `assets/data/audio_events.json` **(coordinate with multi-enemy — `src/audio` is theirs)**, new icon + VFX assets
- **Depends on:** F1; the `combat_view.gd` and `audio_events.json` handovers. Icons are free-produced (OD-6), so no paid gen blocks this phase.
- **Regression risk:** a per-frame passive VFX in `overlay_layer.gd` can cost frame time on mobile; the passive hooks are called inside the simulation step, so a cue must never alter simulation state.
- **Tests:** new `passive_feedback_test.gd` (every registered passive has an icon, a vfx key and an audio key, all resolving); existing `hunter_prayer_test.gd` must stay green; a windowed run with `--audio-driver Dummy` capturing each passive firing, retained in `production/qa/evidence/character-system/`.
- **Acceptance:** each of the 5 passives has one on-screen cue a player can identify from across the board at 1× speed, with a retained screenshot per passive, and one audio cue synced to a real VFX frame.

### F4 — Skill ownership & pools
- **Files:** `assets/data/characters.json` (`skill_pool` block), `assets/data/cards.json` (+10 owned cards, OD-3 approved), `src/combat/skill_config.gd`, `src/run/reward_roller.gd`, `tests/unit/run/starter_identity_test.gd`
- **Scope (OD-3 + OD-4 approved):** owned pool 3 → 5 per character (+10 cards); `starter_identity_test.gd` tightened to ≤2 shared, ≤1 base copy, ≥4 distinct cards per deck — which forces `sat_thu` and `giao_si` deck edits.
- **Depends on:** F1; **the card-art session releasing `assets/art/cards` and the asset registry** (10 new cards need art)
- **Regression risk:** `cards.json` is **not** held by another session, but the card-art session owns `assets/art/cards` — a new card needs art, so adding cards must be sequenced after that session reports. Changing a starter deck shifts early-run difficulty for that character.
- **Tests:** `hero_card_pool_test.gd` extended (a character is never offered another character's card); `starter_identity_test.gd` with the tightened thresholds; `deck_power_test.gd` to confirm no deck's opening power moved more than the agreed band.
- **Acceptance:** `skill_pool.owned_cards` agrees with `cards.json` `hero` for all 5; each character's starter deck meets the tightened gate; no new card is a numeric reskin (each introduces a different `effect`, `delivery` or `shape_clause` combination).

### F5 — Progression: boons, passive ranks, signature variants
**RUNS LAST (OD-7 approved).** Everything else — F1, F2, F3, F4, F6, F8, F9 — ships before this phase starts.
- **Files:** new `src/progression/base_boon.gd`, `boon_registry.gd`, `src/progression/<boon>.gd`; new `assets/data/boons.json`; `src/signatures/variant_registry.gd`; `src/run/reward_roller.gd`, `src/run/run_session.gd`, `src/run/run_controller.gd`, `src/run/reward_view.gd`, `assets/data/rewards.json`
- **Depends on:** F1–F4, F6, F8, F9 all shipped first
- **Regression risk:** **highest in the roadmap.** Boons stack with relics; the existing
  `relic_damage_mult_cap` (3.0) caps relic damage factors only — boons would need their own cap or to
  join that product, otherwise a boon + relic stack breaks the damage ceiling. Offer frequency
  competes with card and relic offers for the same nodes.
- **Tests:** `boon_registry_test.gd`; a damage-cap test proving boons cannot exceed the agreed ceiling; a 1000-run bot balance pass (`tests/unit/balance`) comparing win rate per character before and after; `reward_run_test.gd` extended for offer mix.
- **Acceptance:** two runs of the same character with different boon choices diverge measurably (bot win-rate and average match length differ beyond noise); no boon adds a flat stat; no character has code outside its registered plug-in.

### F6 — Selection UI
- **Files:** `src/run/character_select_view.gd`, `src/layout/screen_layout.gd`, `src/run/save_slots_view.gd`, new portrait/icon assets
- **Depends on:** F1, F3 (icons); the 5 portraits (OD-6, paid, one user yes per call)
- **Regression risk:** the select screen already carries Story 037 (locked-card strip) and Story 038 (Kiep panel); adding a portrait, a playstyle line and two icon rows is a real layout squeeze at phone width with 5 cards sharing the width. Safe area is only verifiable on a real device build.
- **Tests:** existing select-screen capture args (`--screen=character_locked=<id>`, `--screen=kiep_hint`) re-captured; new captures at the narrowest supported width; `unlock_flow_test.gd` and `kiep_wiring_test.gd` green.
- **Acceptance:** every character card shows portrait, name, playstyle line, HP, passive icon + name, signature icon + name, deck strip and the Kiep panel, at phone width, with retained screenshots per character and for the locked state.

### F7 — Save / load compatibility
- **Files:** `src/run/run_session.gd` (save v7 → v8), `src/run/progress_state.gd` (v8 → v9 **only if** permanent per-character state is added), `src/run/save_slots.gd`
- **Depends on:** F5 (it defines what must be saved)
- **Regression risk:** **highest consequence.** A v7 run save must load into v8 with boons empty, passive rank 1 and no signature variant — never be dropped. `run_session.gd:1221` drops a run with an unknown character, so **no character id may be renamed in any phase.** Never write the real `user://` files while testing.
- **Tests:** `save_slots_test.gd` and `run_session_v*_test.gd` extended with a captured v7 fixture loading into v8; a v8 progress fixture loading into v9; a round-trip test.
- **Acceptance:** a run saved before this change continues after it with no warning and no lost state; a progress file from v8 keeps every unlock and Kiep level.

### F8 — Remove obsolete Class/Weapon dependencies
- **Files:** `assets/data/schema.md`, `src/run/character_config.gd` (doc comments), `design/game-brief.md`
- **Depends on:** F1
- **Regression risk:** **none, if limited to wording.** The phase's entire content is documentation. **`cast_presentation`, `CAST_PRESENTATIONS` and `WEAPON_CAST_BODIES` are explicitly out of scope** — they are animation routing, not equipment, and touching them would break 62 cards and `cast_presentation_test.gd` for no gain.
- **Tests:** full suite re-run (no behaviour change expected); `terminology_scan`.
- **Acceptance:** no document in the repo describes characters as "classes"; a grep for class/weapon returns only the animation-routing hits, each with a comment saying it is not an equipment system.

### F9 — Visual replacement & cleanup
- **Files:** `assets/art/portraits/*`, `assets/art/icons/*`, `src/art/art_assets.gd` (new path keys), the asset registry **(held by the card-art session — coordinate)**, `production/qa/evidence/character-system/`
- **Depends on:** F3, F6
- **Regression risk:** the asset registry is shared; a bootstrap run while another session holds it will conflict. Texture memory on mobile grows with 5 portraits + 25 icons.
- **Tests:** `asset-audit` over the new paths (naming, size budget, orphans); an in-game capture of every new asset in place; registry bootstrap re-run once the card-art session has released it.
- **Acceptance:** every new asset is referenced from `art_assets.gd`, present in the registry, visible in a retained in-game screenshot, and within the size budget; no placeholder remains on the select screen.

---

## G. Design Decisions — ALL NINE APPROVED 2026-11-13

Every decision below was approved by the user exactly as recommended. The "Decision" column is now
binding; the short form is in the decision log at the top of this document. **Nothing here is a
go-ahead to implement** — it fixes the design, and each phase still needs its own instruction.

| # | Question | Why it was blocking | Decision — APPROVED 2026-11-13 |
|---|---|---|---|
| **OD-1** | `phap_su`'s description says "frail" but its HP is 210 — the second highest in the roster, and 30 above `sat_thu`. Fix the number or fix the text? | Pillar 1 and pillar 2 contradict each other today. Any identity work inherits the lie. | **Fix the number**: drop `phap_su` to ~170 and let the long 5 s focus and `wide_caster` be the payoff. A frail, far-reaching caster reads instantly; a 210 HP "frail" mage reads as a typo. |
| **OD-2** | Add `cast_speed_mult`, `hazard_resist_mult`, `formation_fade_mult` per character, or keep base attributes at the current 3 keys? | 3 keys for 5 characters is why `phap_su` and `giao_si` differ from `kiem_si` by one number each. But each new multiplier is a new balance surface and a new double-apply risk. | **Add exactly two**: `cast_speed_mult` and `hazard_resist_mult`. Skip `formation_fade_mult` — it interacts with the signature charge rate and would need its own balance pass. |
| **OD-3** | Each character owns 3 cards. Deepen to 5–6? That means ~12 new cards and ~12 new card arts. | Pillar 4 says the character owns its skill pool; with 3 owned cards most of a run's deck is shared. | **Yes, to 5 each** (+10 cards), but **sequenced after the card-art session reports**, and only if you want to spend art on it. Each new card must introduce a new effect/delivery/shape combination, not a number tweak. |
| **OD-4** | Tighten `starter_identity_test.gd` from "≤3 shared cards, ≤2 base copies" to "≤2 shared, ≤1 base copy, ≥4 distinct cards in the deck"? | `sat_thu` shares 3 cards with `kiem_si`; `giao_si` opens with only 3 distinct cards. Your standing rule is that a character must feel different from match one. | **Yes.** It forces exactly the edits that make match one feel different, and `kiem_si` already proves the stricter bar is reachable. It does move early-run balance, so it needs a bot pass. |
| **OD-5** | Reopen per-character relics? `schema.md:629` says "no per-character relics", decided earlier. | Pillar 5 asks for character-specific progression; relics are the existing rule-changing item. | **No — keep relics character-agnostic.** Put character progression in boons (B.4) instead. Relics staying shared is what keeps the relic pool valuable across all 5 characters. |
| **OD-6** | Portraits (5), passive icons (5), signature icons (5), boon icons (15) — **paid PixelLab generation**. Approve, approve partially, or do a free scripted/workbench first pass? | Pillars 1, 3 and 5 are invisible without them. Nothing is generated without your explicit yes per call. | **Free first pass for the icons** (scripted / `vfx_workbench` / `pixelfx`), **paid only for the 5 portraits**, and only after each anchor passes the written checklist and you name the closest famous character to rule out a lookalike. |
| **OD-7** | Build in-run character progression (boons + passive ranks + signature variants) at all, or ship F1–F4 + F6 and stop? | F5 is the largest, riskiest phase and the only one that needs a run-save version bump. | **Build it, but last and alone.** F1–F4 + F6 already deliver four of the five pillars. Let F5 be its own approved slice with its own bot balance pass. |
| **OD-8** | Lore / personality / playstyle text for all 5 characters — written here by me, or by you? The `kiem_si` draft in B.6 is my proposal, nothing else is written. | Pillar 1 cannot be marked complete without it, and it must sit inside the Tessera Western-fantasy direction (`design/world-context.md`), not wuxia — note the character names are Sino-Vietnamese, which is worth a direction check. | **I draft all 5, you approve or redirect each.** Flagging now: the current names (Kiếm sĩ, Pháp sư, Sát thủ) and card names read Sino-Vietnamese against a Western-fantasy world direction — worth deciding whether that is intentional flavour or drift. |
| **OD-9** | ~~Is the task's premise accepted? There is no Class or Weapon system to migrate away from.~~ | — | **DECIDED 2026-11-13 — ACCEPTED by the user.** There is no Class/Weapon system to migrate away from. The 5 pillars apply to deepening the existing character system. The roadmap in section F stands as written; phase F8 is documentation wording only. |

---

## Appendix — what was and was not inspected

**Inspected:** `assets/data/` (characters, cards, rewards, kiep_levels, relics, combat, schema.md),
`src/run/` (character_config, character_select_view, reward_roller, run_session, progress_state,
save_slots), `src/passives/` (all), `src/signatures/` (all), `src/combat/` (combat_view wiring,
skill_config), `src/battle/` (unit_layer, overlay_layer), `src/art/art_assets.gd`,
`assets/art/units/`, `assets/i18n/strings.csv`, `design/game-brief.md`, `tests/` (98 files reference
character/passive/signature; the 46 direct consumers of the three configs were listed).

**Not inspected / deliberately left alone:** files held by the multi-enemy, monster-skills and
card-art sessions beyond reading them; `assets/art/cards/`; the asset registry;
`.claude/worktrees/`. **Godot was not launched** — no test was run, so every claim here is from
source reading, not from execution.

**Nothing in the repo was modified, deleted, generated or committed by this audit.** This document is
the only new file.
