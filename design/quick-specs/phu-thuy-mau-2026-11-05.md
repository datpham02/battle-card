# Quick Design Spec: Máu Phù thủy Rừng 1210 → 1090

**Type**: Tuning
**System**: Misty Forest boss `forest_witch` (P2.4)
**GDD Reference**: `design/quick-specs/phase2-misty-forest-2026-11-01.md` §5.1 / §7 (D8: "số khởi đầu, chơi thử rồi chỉnh")
**Date**: 2026-11-05

## Change

| Parameter | Old Value | New Value | Rationale |
|-----------|-----------|-----------|-----------|
| `chapters.json` ch1 `forest_witch.boss_max_hp` | 1210 | 1090 | Sim Witch fights ran 150-175 s against the sim's 180 s cap; most Kiếm sĩ losses were timeouts |

## Tuning Knob Mapping

D8 pack budget: a boss = 4-7 x a normal (140 effective at floor 3). 1090 x 0.6375 = 695 effective at floor 3 = about
5.0 x 140, inside the 4-7 range (was 5.5 x).

## Motivation

User 2026-11-05: "Giảm khó Phù thủy"; chose "Áp dụng 1090".

`deck_sim` ch1, 40 seeds, build policy, before: every character 20-35 % chapter wins (target 40-60 %), almost all
chapter losses at the Witch. Kiếm sĩ: 27 of 29 Witch losses were timeouts. The game has no match clock, but a ~3 min
boss is too long for a phone session.

## Variants Measured (all 5 characters, ch1, 40 seeds, `--hp-ids=forest_witch --hp-ids-mult=X`)

| Witch HP | Kiếm sĩ | Pháp sư | Sát thủ | Thợ săn | Giáo sĩ |
|---|---|---|---|---|---|
| 1210 (before) | 27.5 | 22.5 | 20 | 35 | 32.5 |
| x0.95 ≈ 1150 | 57.5 | 42.5 | 22.5 | 42.5 | 50 |
| **x0.9 ≈ 1090** | **65** | **45** | **40** | **52.5** | **65** |
| x0.85 ≈ 1030 | 80 | 47.5 | 52.5 | 62.5 | 72.5 |
| x0.75 ≈ 910 | 97.5 | 67.5 | 50 | 65 | 90 |
| x0.9 + Bẫy chông 5/cell | 72.5 | 45 | 42.5 | 67.5 | 72.5 |

The curve is steep near the sim's 180 s cap, so part of the gain is fewer timeouts.

## Acceptance Criteria

- [x] `forest_witch.boss_max_hp` reads 1090 (`forest_witch_mechanics_test`, `map_gen_test`; D8 check now "inside the
      4-7 x 140 budget").
- [x] Re-measured with the real data: Kiếm sĩ 65, Pháp sư 45, Sát thủ 40, Thợ săn 50, Giáo sĩ 65 (mean 53 %, target
      40-60). Witch fights 133-167 s.
- [x] No regression: full suite green.

## Open

- Witch fights are still 130-165 s in the sim: confirm the length in a real playtest.
- Kiếm sĩ / Giáo sĩ at 65 %, slightly above the target, within the ±7 noise of 40 seeds.
- Bẫy chông (gai_doc) hits for 2 per cell, less than the starter Bụi rậm (6): a separate pass (about 4).
