# Story 027 — zone cards in the balance sim (chapters 2–3, 70 seeds)

Tool: `tools/balance/deck_sim.gd`, build policy, default bot (`dodge=0.85`, TD-006 value, not anchored).
"Before" = `--no-zone-cards` (the 4 zone cards out of decks and the reward pool; boss zone traits stay on).
Same seeds for every column. Error on a difference of two win rates at 70 seeds is about ±8 points.

Bot rule (`SimCore._zone_choice`): never a zone card when a damage card in hand would kill; seal when the
boss has at most 3 open exits and the cut covers all but one; thorns when the cut covers at least 2 open exits;
after a zone forms the bot casts again at once at the boss and the exit still open. Build policy takes an
offered zone card after an upgrade pick, at most one per effect.

## Win % by seal duration of the two player seal cards

| Chapter | Character | Before (no zone cards) | Seal 1.2 s | Seal 2.0 s (shipped) | Seal 2.5 s |
|---|---|---|---|---|---|
| ch2 | Kiếm sĩ | 44.3 | 50.0 | 50.0 | 52.9 |
| ch2 | Pháp sư | 15.7 | 14.3 | 18.6 | 15.7 |
| ch2 | Sát thủ | 41.4 | 21.4 | 34.3 | 31.4 |
| ch3 | Kiếm sĩ | 24.3 | 21.4 | 15.7 | 24.3 |
| ch3 | Pháp sư | 15.7 | 8.6 | 11.4 | 8.6 |
| ch3 | Sát thủ | 12.9 | 12.9 | 12.9 | 14.3 |

No chapter rises more than 15 points (largest +8.6, ch2 Kiếm sĩ at 2.5 s); the story's "weaken if too strong"
rule does not fire. The one large move is ch2 Sát thủ at 1.2 s (−20, about 2.4× the noise), which shrinks to −7
at 2.0 s. A re-run of that cell on a fresh seed set was planned but not run.

## Hit % of non-zone casts started ≤ 2 s after a seal vs all other non-zone casts

| Chapter | Character | 1.2 s | 2.0 s (shipped) | 2.5 s |
|---|---|---|---|---|
| ch2 | Kiếm sĩ | 30.7 vs 39.7 | 35.5 vs 39.3 | 44.4 vs 39.1 |
| ch2 | Pháp sư | 34.0 vs 46.0 | 46.3 vs 45.8 | 41.1 vs 45.6 |
| ch2 | Sát thủ | 36.5 vs 39.9 | 46.5 vs 40.5 | 45.6 vs 40.2 |
| ch3 | Kiếm sĩ | 36.5 vs 37.3 | 35.6 vs 36.7 | 38.8 vs 36.8 |
| ch3 | Pháp sư | 41.9 vs 43.8 | 41.8 vs 44.3 | 47.2 vs 43.6 |
| ch3 | Sát thủ | 36.3 vs 38.6 | 39.3 vs 38.9 | 37.3 vs 38.6 |

(n = 90–230 post-seal casts per cell, so about ±7 points.) At 1.2 s the follow-up after a seal hit LESS often than
an ordinary cast: the seal swing lands, the player places a piece and picks a card, and the seal is gone or the
boss has left through the one open exit. At 2.0 s the follow-up is level with or above an ordinary cast. Decision:
the two player seal cards carry `seal_sec: 2.0` per card; the shared `combat.json` `seal_sec` stays 1.2 s, so the
boss's `seal_caster` seals on the player keep their short window.

## Zone card use (after, seal 1.2 s run)

| Chapter | Character | Picked / run | In final deck | Zone casts / match | Seals / match | Thorns / match | Boss thorn entries / match |
|---|---|---|---|---|---|---|---|
| ch2 | Kiếm sĩ | 1.17 | 0.69 | 1.48 | 0.82 | 0.50 | 0.13 |
| ch2 | Pháp sư | 0.94 | 0.74 | 1.13 | 0.57 | 0.44 | 0.11 |
| ch2 | Sát thủ | 1.04 | 0.69 | 1.39 | 0.84 | 0.42 | 0.10 |
| ch3 | Kiếm sĩ | 0.86 | 0.57 | 1.28 | 0.66 | 0.45 | 0.09 |
| ch3 | Pháp sư | 0.59 | 0.41 | 1.05 | 0.54 | 0.43 | 0.08 |
| ch3 | Sát thủ | 0.71 | 0.46 | 1.11 | 0.56 | 0.42 | 0.07 |

A seal covers 3.5–3.7 cells and thorns 4.0–4.3 cells on average. The boss rarely walks into thorns (0.07–0.13
per match: `thorn_avoid` works). The player bot walks into the `frost_mage` thorn_field 0.4–0.9 times per ch3 match.

Raw outputs: `simulation-zones-raw.txt` (24 runs); command per cell:
`godot --headless --path . -s res://tools/balance/deck_sim.gd -- --seeds=70 --policies=build --chapters=<1|2>
--characters=<id> [--no-zone-cards] [--card-set=ket_gioi.seal_sec:<s>,long_an.seal_sec:<s>]`.
