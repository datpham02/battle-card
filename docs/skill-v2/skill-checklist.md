# Skill v2 — completion checklist

One row per Skill v2 card. A card is **done** when every column is COMPLETE / APPROVED / PASSED except Real-device QA,
which stays PENDING until it is run on an Android phone (see `production/qa/android-device-qa-skill-v2.md`).

| Card | Hero | Gameplay | Animation | VFX | Automated tests | Real-device QA | Docs |
|---|---|---|---|---|---|---|---|
| `tram_dia` Trảm Địa | Knight (`kiem_si`) | **COMPLETE** | **APPROVED** (`cast_forward`) | **APPROVED** (`impact_eruption_tram_dia` + `mark_eruption_tram_dia` + code surge) | **PASSED** (2026-11-08) | **PENDING** (Android) | 04, 05, 06 reports |
| `ngan_kiem` Ngàn Kiếm | Knight | not started | — | — | — | — | — |

## Trảm Địa (approved by the user 2026-11-08)

### What is in it

**Gameplay:** `resolve: arrival` CASTER_TO_TARGET surge (CastResolver M03).
- Burst ×1.5 with Pin 0.4 s.
- `line_h` surge bonus +15 % per step, cap +45 %; shape group S capped ×2.0.
- `max_hits` 1, one hit per wave.
- Locked cells cut the surge; disconnected regions get their own landing.
- First damaging event interrupts.
- Boss awareness of the pending surge, limited to the cells it saw.
- Knight-only `hero_reward` (rare); not in a starter deck, never the boss's.

**Cast animation:** `cast_forward`, 9 slots, PixMiniMax job `5e5e14ed`, mechanical clean, cape interior recoloured to
navy.

**VFX:**
- Charge at the coil.
- Release slash.
- Square-wave travel.
- Eruption overlay pack + floor mark pack on the burst cell (`card_casts.tram_dia`).
- Code surge fronts, cracks, secondary bursts.
- Wind-up and menu targeting preview.

**Numbers (cards.json):** min 3 cells, dpc 6, cooldown 6 s (−1 per level), `burst_first` 1.5, `burst_pin_sec` 0.4.

### Evidence

- `production/qa/evidence/skill-v2-tram-dia/`: prototype frames and event logs.
- `production/qa/evidence/skill-v2-tram-dia-polish/`: polish sheets and preview captures.
- `production/qa/evidence/skill-v2-tram-dia-art/`:
  - cast_forward raw / clean / cape fix / in-game sheets;
  - eruption spritesheets ×3;
  - `sequences/` with straight, L, T and Plus at 2× and native 640×360, plus events logs.

**AVI recordings:** `skill-v2-tram-dia-polish/tram_dia_bar4.avi` and
`skill-v2-tram-dia-art/sequences/tram_dia_bar4_final.avi`.
- They stay on disk but are not committed: about 17 MB each, and the repo has never tracked video.
- Rebuild them with the demo command below.

### Reproduce

```bash
godot --path . --fixed-fps 60 -- --character=kiem_si --seed=1 --match=1 --arena=rect --demo=tram_live --no-autopause --tram-shape=bar4
```

- **Shapes:** `--tram-shape=l4 --tram-rot=1`, `t4 --tram-rot=2`, `plus5`.
- **Scenarios:** `--tram-move=1,0` (moving boss), `--tram-first` (burst on the boss), `--pattern=dev_pattern_boss`
  (2×2 boss), `--cast-lock` (a cracking cell).
- **Continuous capture:** add `--write-movie <dir>/f.png --quit-after 135` before `--`, then
  `godot --headless --path . -s res://tools/qa/contact_sheet.gd -- <dir> f 45 113 3 full 4 half out.png`.

### Tests

| Test | Covers |
|---|---|
| `tests/unit/combat/tram_dia_test.gd` | data, geometry, timing, hooks, VFX helpers, asset overrides |
| `tests/unit/combat/boss_surge_awareness_test.gd` | the boss sees the pending surge it saw during the swing |
| `tests/unit/run/hero_card_pool_test.gd` | Knight-only reward |
| `skill_v2_golden_test` | the 640 legacy cases, fixture untouched |
| `sheet_export_test`, `sprite_sheet_test`, `floor_vfx_test` | sheet and pack data |

### Open (not blocking the next skill)

1. **Android real-device QA:** PENDING (`production/qa/android-device-qa-skill-v2.md`).
2. **Accepted visual notes:**
   - the cast_forward wind-up raises the sword high;
   - small gold collar patches on slots 5–6;
   - the formation map's gold rings overlap the fading stamps.
3. **Menu preview:** the menu-time preview is mostly hidden by the card menu (the wind-up preview carries the
   telegraph).
