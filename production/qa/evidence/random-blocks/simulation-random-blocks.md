# Story 041 (2026-10-27): Khối Lạ (odd blocks), whole-run simulation

**Setup**
- Tool: `tools/balance/deck_sim.gd --run=v6`.
- Policy: "build", `--mercy=mixed --shop=on --pieces=off --relic=value`, Kiep 0, bot dodge 0.85. Same settings as the Story 040 final check.
- Seeds: **3001–3070**, a set no earlier tuning used (`--seed-offset=3000`), 70 runs per character.
- Each variant runs the same seeds. Only the odd-block chance changes, on both sides:
  - `off`: `--odd=off`
  - `c12`: `--odd-chance=0.12`, the shipped value
  - `c18`: `--odd-chance=0.18`
  - `on`: the first data value, 0.25
- Raw output: `simulation-random-blocks-raw.txt`, with sections `===== <variant>_<character>`. Every run has its `bot: ... | overrides: ...` header, plus the `odd=` part of the header.

**Noise:** one 70-seed cell has a standard deviation of about 5–6 points on run win %. The `off` row on this seed set already differs from Story 040's final check on seeds 2001–2070 (44.3 / 35.7 / 42.9 / 27.1 / 47.1) by up to 11.5 points (Giáo sĩ) with identical data. So only the on/off difference on the same seeds is a fair measure of odd blocks.

## Run win % by chance

| Character | off | 0.12 (shipped) | 0.18 | 0.25 |
|---|---|---|---|---|
| Kiếm sĩ | 37.1 | 40.0 (+2.9) | 52.9 (+15.8) | 44.3 (+7.2) |
| Pháp sư | 32.9 | 42.9 (+10.0) | 51.4 (+18.5) | 55.7 (+22.8) |
| Sát thủ | 38.6 | 34.3 (−4.3) | 32.9 (−5.7) | 44.3 (+5.7) |
| Thợ săn | 34.3 | 31.4 (−2.9) | 34.3 (0.0) | 47.1 (+12.8) |
| Giáo sĩ | 58.6 | 54.3 (−4.3) | 50.0 (−8.6) | 54.3 (−4.3) |
| Mean | 40.3 | 40.6 (+0.3) | 44.3 (+4.0) | 49.1 (+8.8) |

- Odd blocks help the player more than the boss, even though both sides get them at the same rate: bigger blocks mean bigger hits.
- **Pháp sư** gains the most. Its passive, Pháp trận rộng, makes casts of 4 cells or more 25 % faster, so a 5–7-cell odd block is cheaper for it than for anyone else.
- At 0.25, two characters moved more than 10 points: Pháp sư +22.8 and Thợ săn +12.8.
- The 0.18 row is not monotone between 0.12 and 0.25 for every character (Kiếm sĩ 52.9). That is the noise above, not a real peak.

## Odd blocks at the shipped 0.12

| Character | Odd share of player drops | Mean odd size | Fallbacks to a library shape (per run) | Boss odd share | Boss hits / won run | Won-run minutes |
|---|---|---|---|---|---|---|
| Kiếm sĩ | 11.1 % | 5.49 | 0.11 | 11.8 % | 33.5 | 27.6 |
| Pháp sư | 11.2 % | 5.47 | 0.13 | 11.9 % | 35.0 | 27.9 |
| Sát thủ | 11.1 % | 5.49 | 0.09 | 11.5 % | 29.5 | 25.7 |
| Thợ săn | 10.9 % | 5.45 | 0.11 | 11.9 % | 33.0 | 27.2 |
| Giáo sĩ | 10.9 % | 5.49 | 0.14 | 12.0 % | 33.8 | 26.7 |

- The share is a little under the chance because the start piece of every match is always a library shape.
- Fallbacks are rare, about 1 in 9 runs: the generator found no new shape that fits within 40 tries, so it dropped a library shape instead.
- Boss hits and run minutes barely move compared with `off` (28.5–34.9 hits, 25.9–29.7 minutes).

## Part E targets

| Target | Result | Verdict |
|---|---|---|
| No character more than 10 points apart between on and off (same seeds) | Max is 10.0 (Pháp sư); others +2.9 / −4.3 / −2.9 / −4.3 | PASS (at the limit for Pháp sư) |
| Run win 30–45 %, or within ±5 points of Story 040 | Kiếm sĩ 40.0, Pháp sư 42.9, Sát thủ 34.3, Thợ săn 31.4 are inside 30–45. Giáo sĩ 54.3 is outside both. But Giáo sĩ with odd blocks off on these same seeds is 58.6, so the miss comes from the seed set, not from odd blocks | FAIL for Giáo sĩ, not caused by this story (TD-037 already tracks the character band) |

## Data change (JSON only)

| Key | Old → new | Why |
|---|---|---|
| `assets/data/field_drops.json` `odd_blocks.chance` | 0.25 → 0.12 | At 0.25 Pháp sư was +22.8 and Thợ săn +12.8 against `off`. At 0.12 the mean win moved +0.3 and every character stays within 10 points |

`size_weights` (5: 6, 6: 3, 7: 1) and `min_cells` (5) are unchanged.

## Runtime

Ten processes in parallel (5 characters × 2 variants), 70 seeds each: about 11–12 minutes per batch on a 12-thread machine.
