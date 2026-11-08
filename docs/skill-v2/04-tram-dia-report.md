# Skill v2 — Trảm Địa (tram_dia) prototype report

**Date:** 2026-11-08 · **Status:** playable prototype, validated in the real battle scene · nothing committed.
No other card, starter deck, reward pool or hero ability changed. No PixelLab call. Mage work untouched.

## 1. Summary

- **Gameplay:** Trảm Địa is the first card whose damage resolves through **authoritative scheduled impacts**.
  - The Knight's swing ends, the sword wave lands on the first cell (t = 0), then the surge reaches every other cell
    of the placed Block at its own time on the combat clock.
  - Damage, the burst's Pin and the interrupt happen **at the event that finds the boss**, not at the swing end.
- **VFX:** played event by event from `SwingArbiter.impact_resolved`, so the picture follows the gameplay schedule.
  - A cell that does not hit shows its ground burst only, with no HIT / damage feedback.
  - Damage is applied only by the arbiter; no visual callback applies damage.

## 2. Skill data (`assets/data/cards.json`)

| Field | Value |
|---|---|
| id / name | `tram_dia` / Trảm Địa (Earth-Splitting Wave), strings in `assets/i18n/strings.csv` |
| hero | `kiem_si` (Knight only); rarity `rare` |
| min_cells / damage_per_cell / cooldown_sec | 3 / 6 / 6 s |
| cast_mode / delivery | `direct` / `CASTER_TO_TARGET`, origin caster, travel `hero_pack`, impact `burst` |
| resolve / max_hits | `arrival` / 1 (one wave: the boss is hit at most once per cast) |
| burst_first / burst_pin_sec | ×1.5 / Pin 0.4 s on a hit |
| shape_clause | `{tag: line_h, scope: any_piece, surge_per_step: 0.15, surge_cap: 0.45}` |
| upgrade | `cooldown_sec −1` per level (placeholder; no extra damage bonus added) |

**Ownership:**
- A hero card: never in reward, shop or event pools.
- Not in any starter deck (production decks unchanged).
- B1 rule: hero cards are never the block-brain boss's (`SkillConfig.is_boss_playable`). The only other hero card,
  `do_kiem`, was already excluded as a parry card, so no boss behaviour changes.
- It joins `card_order` (the game lists every player card there). The golden test now pins exactly the 32
  **legacy** (`instant`) cards. Its fixture was **not** re-recorded and all 640 cases are unchanged.

## 3. Gameplay event timeline (bar4 flat, swing 1.2 s)

| Clock | Event | Code |
|---|---|---|
| 0 → 1.05 s | Knight wind-up (`cast_gesture` held on the coil frame), charge glint at the blade | CutActor swing, `hand_charge` |
| 1.05 s | release slash at the hand; the sword wave flies 0.15 s to the landing cell | `release_square_slash_steel`, `travel_square_wave_steel` |
| **1.20 s** (t = 0) | **burst** on the landing cell: ×1.5, Pin 0.4 s if the boss is there | `impact_resolved` kind `burst` |
| 1.41 s (t = 0.21) | surge step 1 (first_hold 0.13 + 0.08) | kind `surge`, step 1 |
| 1.49 s (t = 0.29) | step 2 | step 2 |
| 1.57 s (t = 0.37) | step 3 | step 3 |
| after the last event | one card-level `swing_resolved` (`scheduled: true`): relics, signature, pattern hooks, stats | |

- **Timing source:** `combat.json` `timing.delivery.CASTER_TO_TARGET` (the same numbers the visuals use).
- **Projectile landing:** the projectile lands exactly at the swing end, which is the burst event (`CastVfx.flight_t`).

## 4. Shape propagation rules (`CastResolver.surge_events`)

1. **Open cells:** the mask minus the cells locked at the resolve (cracking or holes). Locked cells get no event, and
   the surge never crosses them.
2. **Landing cell:** `SkillDelivery.first_link`, the open cell nearest the Knight (column first). The projectile flies
   to this same cell (the overlay now skips locked cells too).
3. **Primary region:** breadth-first from the landing cell over 4-neighbours inside the region. Step k lands at
   first_hold + k × step.
   - Straight: a forward surge.
   - L: turns at the corner.
   - T: from the junction, branches together.
   - Plus: reaches the centre, then the three far arms together.
   - Odd: follows connected cells only.
4. **Disconnected regions** (separate pieces, or a hole that cuts the Block):
   - Each region is reached by its **own split of the wave**: a `landing` event at t = 0 on its cell nearest the
     Knight, with no burst and no Pin, then its own surge.
   - No path is hit or drawn between regions.
   - Regions are ordered primary first, then by distance to the Knight, y, x. Events are ordered by
     (t, region, y, x), independent of how the mask is listed.
5. **Hit rules:**
   - One hit per cast (`max_hits 1`, one wave): the boss is hit by the first event whose cell it stands on at that
     moment. A 2×2 boss under several cells takes one hit.
   - A boss that moves onto a later cell is hit there.
   - A boss that leaves the mask before the surge arrives is not hit.
6. **Multipliers (shape group S, capped ×2.0, applied right after crit):**
   - Burst: ×1.5.
   - Surge step k: ×(1 + min(0.15 k, 0.45)) **only** when a placed piece is `line_h` (scope `any_piece`, physical
     cells; Awakening ×2 cells never changes tags or the path).
   - Damage counts the cast's total open cells (`cast_cell_count`). Passive, Awakening, Resonance, relic, defense,
     Rạn and crit run unchanged, through the same `CutEffects.apply`.
7. **Interruption and cancellation:**
   - A Knight interrupted before the release schedules nothing.
   - The first damaging event cancels the boss's running swing.
   - A unit death clears every pending event.

## 5. VFX module mapping (no new art; installed packs + code)

| Beat | Module |
|---|---|
| A charge | `hand_charge` pack at the blade (existing Knight cast entry) |
| B sword wave | `release_square_slash_steel` + `travel_square_wave_steel` (fxkit steel packs) |
| C primary impact | `impact_burst_big_steel` + `mark_stamp_big_steel` on the landing tile, plus a **new code-drawn double square shockwave** (`CastFloorFx.shock_rects`, 16 + 8 squares, one cell wide) |
| D propagation | per event: `impact_burst_small_steel` + `mark_stamp_small_steel`, plus a **new code-drawn steel crack** from the cell the surge came from (`CastFloorFx.crack_rects`), revealed in 0.08 s; a `landing` gets a small shock ring |
| E aftermath | stamps fade (pack timing); the cracks shrink away over 0.6 s; `get_surge_fx` prunes them |
| hit only | `hit_impact` + HIT / damage marker at the hitting event |

- **Colours:** the Knight's block steel (`#8FA3B8` / `#EEF4FA`), never telegraph red.
- **Anchors:** all effects are anchored on the tile (FloorVfx cell anchors), not on the enemy sprite.

## 6. Tests

| Test | Result |
|---|---|
| `tests/unit/combat/tram_dia_test.gd` (new, 66 checks) | Pass. Covers: data / Knight-only, min cells, cooldown (and level 2), clock timing, burst ×1.5 + Pin 0.4 s, surge order, E4 (bar4 → 34.8), cap (bar5 → 43.5), line_v no bonus, L / T / plus geometry, multi-piece scope, disconnected landing, locked at resolve and mid-surge, moving boss (out / onto a later cell), 2×2 boss once, interruption / cancel, Awakening / passive / relic / Resonance, determinism (tick sizes, mask order), crack / shock helpers, cleanup |
| Mutation check (burst mult off + lock filter off) | 6 checks fail as expected; code restored, 0 fails |
| Golden 640 legacy cases | Unchanged fixture, pass |
| `cast_scheduler_test`, `cast_resolver_test`, `shape_tags_test` | Pass |
| Full suite (after the final change) | **206 / 206 files green, 0 script errors** |
| Tests updated for the new card (counts, not behaviour) | golden test pins the 32 legacy `instant` cards (fixture untouched); `deck_power_test` 33 player cards / 12 rare, boss list also excludes hero cards; `cast_scheduler_test` only `tram_dia` leaves `instant` |
| Card text | `{burst_first}`, `{burst_pin_sec}`, `{surge_pct}`, `{surge_cap_pct}` placeholders (no hard-coded digits); a short `desc_battle` line fits the battle menu card (vi / en, 1280 and 1600 wide) |

## 7. In-game evidence

Captured in `production/qa/evidence/skill-v2-tram-dia/`.

- **Setup:** the real battle scene, 1280×720 (a 2× view of the 640×360 game resolution), demo
  `--character=kiem_si --arena=rect --demo=tram_live`, `--fixed-fps 60`.
- **Board:** each scenario's frames share one board (`<name>.boards.txt` = 1).
- **Event logs:** `<name>.events.txt` lists that scenario's events.
- **Enemy:** the encounter enemy varies between boots (Goblin Scout / Rootling); the boss cell is the same.

| Scenario | Frames | Result |
|---|---|---|
| straight_bar4 | f62 charge · f70 wave · f77/f80/f84 burst · f88/f93 surge + HIT · f98 last cell · f115 aftermath | boss at step 1: 27.6 (24 × 1.15) |
| l_shape_l4 | f77 · f88 · f93 · f115 | turns at the corner, boss hit at step 1 (24) |
| branch_t4 | f77 · f88 · f93 · f115 | junction branches together, boss at step 2 |
| cross_plus5 | f92 · f103 · f108 · f130 | centre then three arms, boss on the centre (30) |
| moving_boss | f62 · f73 · f78 · f100 | boss steps ahead after the burst, hit on the far cell ×1.30 (23.4) |
| boss_first_pin | f62 · f65 · f80 | burst hit 27 + Pin |
| boss_2x2 | f77 · f88 · f93 · f115 | 2×2 pattern boss: one hit (24) |
| locked_cell | f77 · f88 · f93 | a cracking cell takes no event; damage counts 3 open cells (18) |

Reproduce, for example:

```bash
godot --path . --fixed-fps 60 -- --character=kiem_si --arena=rect --demo=tram_live --tram-shape=bar4 --shot=out.png --shot-frame=80
```

## 8. Remaining issues

1. **Primary impact weight.** The burst is now clearly the strongest beat (big steel pack plus a double shock ring),
   but it is still the generic steel burst used by the other Knight cards. The brief asks for an explosion "erupting
   upward" with a distinct silhouette, which needs a dedicated pack.
2. **Cast gesture.** The Knight's `cast_gesture` releases correctly: it holds the coil, then jumps to the slash at
   `gesture_lead_sec`. But the pose is an upward cut, not a low forward drive. A future `cast_forward` clip is
   proposed (vfx-concepts §2); no animation was generated.
3. **Card-level hooks.** Relics, signature `on_hit`, pattern `on_enemy_hit` and stats fire once at the cast's last
   event (≤ 0.37 s after the hit for a 4-cell Block). The HIT marker and hit flash fire at the hit itself.
4. **No forecast or boss awareness of the surge timing.** The forecast does not show the landing cell or the cells
   cut off by holes. The boss brain does not plan around the surge (roadmap S2).
5. **Demo enemy variety.** The demo's enemy varies per boot (cosmetic). The bot QA tool cannot play the card yet,
   because it is not in any deck.
6. **Mobile.** Not checked on a real phone. Captures are at the desktop 2× scale.

## 9. PixelLab assets worth paying for (each needs your yes first)

1. **`tram_dia_burst`.** A tall steel eruption from the tile: 6–8 frames, 1 cell wide × 1.5 cells high, stepped
   square shards rising. This replaces the shared big steel burst on the burst cell only.
2. **Knight `cast_forward`.** A low two-handed forward drive, 6 frames, from the Knight anchor, so the release reads
   as a ground-skimming wave.
3. Optional: **`tram_dia_wave`.** A wider, lower sword-energy crescent travel sprite (steel), replacing the shared
   square wave for this card only.
