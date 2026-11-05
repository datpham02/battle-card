# Quick Design Spec: Bụi rậm của Thợ săn gây sát thương khi trúng

**Type**: Tuning
**System**: Thorn cards (Story 027 zones), Hunter starter deck
**GDD Reference**: `design/game-brief.md` (no GDD at `workflow: minimal`)
**Date**: 2026-11-05

## Change

| Parameter | Old Value | New Value | Rationale |
|-----------|-----------|-----------|-----------|
| `cards.json` tran_gai (Bụi rậm) `damage_per_cell` | 0 | 6 | Same as Kiếm Khí and the Mage's fire cards (`phap-su-lua-trung-2026-11-05.md`) |

No code change: a thorn card with `damage_per_cell > 0` already goes through the normal damage path when the target is
inside (`CutEffects.apply`, as Bẫy chông / gai_doc does), and the balance sim plays the same `CutEffects`. Card texts
(`card.tran_gai.desc`, new `card.tran_gai.desc_battle`) now say it hits first.

## Motivation

User 2026-11-05: "Cân bằng Thợ săn"; chose "Áp dụng Trận Gai 6".

`deck_sim` ch1, 40 seeds, build policy (before): Hunter 0 % chapter wins, 305 damage dealt per match (Kiếm sĩ 394).
The Hunter laid about 7 thorn zones per match but the boss walked into them about once (6 damage): the boss avoids
thorns. Bụi rậm (2 of 6 starter cards) and Rạn kích dealt nothing on a hit.

## Variants Measured (Hunter only, ch1, 40 seeds)

| Variant | Hunter win % | dmg dealt / match |
|---|---|---|
| Now | 0 | 305 |
| Bụi rậm 4 per cell | 7.5 | 343 |
| Bụi rậm 5 per cell | 20 | 373 |
| **Bụi rậm 6 per cell** | **35** | **383** |
| + Bẫy chông 5 per cell | 42.5 | 399 |
| + hunter_mark icd 1.5 s, 2 stacks | 57.5 | 397 |

## Acceptance Criteria

- [x] tran_gai reads damage_per_cell 6 from `assets/data/cards.json`; a hit deals 6 x cells and still lays the thorns,
      a miss lays the thorns and deals nothing (`tests/unit/combat/thorn_impact_test.gd`, watched failing on the old
      data).
- [x] All 5 characters re-measured (40 seeds, build): Kiếm sĩ 27.5, Pháp sư 22.5, Sát thủ 20, Thợ săn 35, Giáo sĩ
      32.5. Pháp sư / Giáo sĩ moved ±5 because Bụi rậm is also a reward card for them; within the ±7 noise of 40 seeds.
- [x] Evidence: `production/qa/evidence/hunter-thorn/` (live Bụi rậm cast laying thorns on the boss; bot match Thợ săn
      vs Goblin Archer won in 23 s, 2 Bụi rậm casts).

## Open

Bẫy chông (gai_doc, unlocked after the first region boss) now hits for less (2 per cell) than the starter Bụi rậm (6)
with the same thorns: it is a worse card. Raise it (5 measured above) or give it another role in a later pass.

The Forest Witch is still too hard for every character (best 35.9 %, ch1 target 40-60 %).
