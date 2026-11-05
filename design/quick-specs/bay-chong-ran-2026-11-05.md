# Quick Design Spec: Ba lá gai có ba vai trò (Bẫy chông Rạn 2, Dây úa Rạn 3)

**Type**: Tuning
**System**: Thorn cards (Story 027 zones / Story 037 unlocks)
**GDD Reference**: `design/game-brief.md` (no GDD at `workflow: minimal`); follows `tho-san-gai-trung-2026-11-05.md`
**Date**: 2026-11-05

## Change

| Parameter | Old Value | New Value | Rationale |
|-----------|-----------|-----------|-----------|
| `cards.json` gai_doc (Bẫy chông) `thorn_fragile_stacks` | 1 | 2 | Trap role: light hit (2 per cell), strong thorns |
| `cards.json` gai_nguyen (Dây úa) `thorn_fragile_stacks` | 2 | 3 | Rare: one entry fills Ran (combat.json `fragile_max_stacks` 3) |

The three thorn cards now each have a reason to pick them:

| Card | Rarity | Cells / cd | Hit damage | Ran per thorn entry | Role |
|---|---|---|---|---|---|
| Bụi rậm (tran_gai) | common | 3 / 6 s | 6 per cell | 1 (combat.json) | the hit card |
| Bẫy chông (gai_doc) | common | 3 / 6 s | 2 per cell | 2 | the trap card |
| Dây úa (gai_nguyen) | rare | 4 / 8 s | 0 | 3 (full Ran) | the rare trap |

Card texts read `{thorn_fragile_stacks}` from the card, so they update without a strings change.

## Motivation

User 2026-11-05: "Chỉnh Bẫy chông" → chose "Đổi vai trò lá" over a plain damage raise; then "Dây úa Rạn 3".

After `tho-san-gai-trung` Bụi rậm (6 per cell) beat Bẫy chông (2 per cell, same thorns) on every axis. Raising Bẫy
chông's hit damage to 3 or 4 left it weaker than Bụi rậm and pushed the Hunter (who starts with 1 Bẫy chông) past 60 %.
Bẫy chông at Ran 2 then made the rare Dây úa (Ran 2, 4 cells, cd 8, no damage) worse than a common card.

## Measured (deck_sim ch1, 80 seeds, build policy, chapter win %)

| Variant | Kiếm sĩ | Pháp sư | Sát thủ | Thợ săn | Giáo sĩ |
|---|---|---|---|---|---|
| Before (Bẫy chông 2 dmg, Ran 1) | 62.5 | 40 | 41.3 | 52.5 | 66.3 |
| Bẫy chông 3 dmg | 63.7 | 37.5 | 41.3 | 61.3 | 68.8 |
| Bẫy chông 4 dmg | 67.5 | 38.8 | 43.8 | 62.5 | 70 |
| Bẫy chông Ran 2 | 63.7 | 38.8 | 37.5 | 60 | 66.3 |
| **Bẫy chông Ran 2 + Dây úa Ran 3** | **63.7** | **37.5** | **38.8** | **58.8** | **65** |

40 seeds swing about ±7 points; at 80 seeds the non-Hunter rows stay within noise.

## Acceptance Criteria

- [x] gai_doc reads thorn_fragile_stacks 2 and gai_nguyen 3 from `assets/data/cards.json`; their thorns give 2 / 3 Ran
      per entry, more than Bụi rậm's 1, and 3 = fragile_max_stacks (`tests/unit/combat/thorn_impact_test.gd`, watched
      failing on the old data; `unlock_content_test`, `zone_test` updated).
- [x] Card faces show "Rạn 2 tầng" / "Rạn 3 tầng" (`production/qa/evidence/hunter-thorn/03-reward-thorn-cards-vi.png`).
- [x] No regression: full suite green; every character stays 37.5-65 % in ch1.

## Open

- Pháp sư / Sát thủ sit at the low edge (37.5-40 %), Kiếm sĩ / Giáo sĩ at the high edge (63-66 %): a spread to watch in
  playtest, not a data problem yet.
