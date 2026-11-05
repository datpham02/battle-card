# Quick Design Spec: Lửa của Pháp sư gây sát thương khi trúng

**Type**: Tweak (+ Tuning)
**System**: Cast effects (burn cards), Mage starter deck
**GDD Reference**: `design/game-brief.md` (no GDD at `workflow: minimal`)
**Date**: 2026-11-05

## Change Summary

A burn card with `damage_per_cell > 0` now hits like a damage card when the target stands inside its cells,
then ignites the cells as before. The Mage's three fire cards get 6 damage per cell, shorter cooldowns, and Hỏa
Trận needs 4 cells instead of 5.

## Motivation

User 2026-11-05: "Cân bằng Pháp sư"; chose variant F ("Áp dụng F").

`deck_sim` ch1, 40 seeds, build policy (before): Mage 0 % chapter wins (Kiếm sĩ 27.5, Giáo sĩ 27.5, Sát thủ 20,
Thợ săn 0), 276 damage dealt per match against 394 for Kiếm sĩ. 4 of the 6 Mage starter cards are burns. A burn hurt
only a unit standing on the cell, and enemies step off at once, so making the burn stronger (tick 1.5 → 2.5) or
longer (+1 s) changed nothing (0 %, 277 damage per match).

## Design Delta

Before: effect `burn` ignites every covered cell, `hit` = the target is inside, no direct damage
(`damage_per_cell` ignored).

After: as before, and when the target is inside and `damage_per_cell > 0` the cast also goes through the normal
damage path (damage_per_cell × cells → Ran → featured → execute → passive → signature → defense, keywords applied
there). A burn card with `damage_per_cell` 0 is unchanged. Code: `CutEffects.apply` (`burn_hits_too`); the balance
bot values the hit too (`SimCore.cast_value`).

## Tuning Knobs

| Card | Knob | Old | New |
|---|---|---|---|
| hoa_xa | damage_per_cell / cooldown_sec | 0 / 6 | 6 / 4 |
| hoa_tinh | damage_per_cell / cooldown_sec | 0 / 7 | 6 / 5 |
| hoa_tran | damage_per_cell / min_cells | 0 / 5 | 6 / 4 |

## Variants Measured (Mage only, ch1, 40 seeds)

| Variant | Mage win % | vs Forest Witch |
|---|---|---|
| Now | 0 | 0 |
| Burn tick 2.5 / duration +1 s | 0 | 0 |
| Impact 4 per cell | 2.5 | 2.9 |
| Impact 6 per cell | 7.5 | 8.8 |
| Impact 6 + passive from 3 cells | 15 | 16.2 |
| **F: impact 6 + cooldowns 4 / 5 + Hỏa Trận 4 cells** | **27.5** | **28.9** |

## Acceptance Criteria

- [x] A burn card with damage hits for damage_per_cell × cells when inside, ignites every cell, a miss deals nothing
      (`tests/unit/combat/burn_impact_test.gd`, watched failing on the old code).
- [x] Hỏa Trận is available from 4 cells (`tests/unit/combat/status_test.gd`).
- [x] Mage ch1 win % within a few points of Kiếm sĩ in `deck_sim`: after the change (40 seeds, build) Mage 27.5 %
      (vs Witch 28.9 %), Kiếm sĩ 27.5, Giáo sĩ 27.5, Sát thủ 20, Thợ săn 0, the other rows unchanged.
- [x] A burn card with no `damage_per_cell` key defaults to 0 (not the cuts.json base), so fixtures and old data keep
      the old rule (`SkillConfig._normalize`).
- [x] Card texts say the fire hits first (`assets/i18n/strings.csv`, new `desc_battle` for Hỏa Tinh / Hỏa Trận).
- [x] Evidence: `production/qa/evidence/mage-fire/` (bot match, Pháp sư vs Goblin Archer won in 40 s, was 89 s).

## Open

Thợ săn is also at 0 % in ch1 (same Witch problem plus a weaker deck): not touched here.

The Forest Witch is too hard for every character (best 27.5 %, ch1 target 40–60 %): a separate tuning pass.
