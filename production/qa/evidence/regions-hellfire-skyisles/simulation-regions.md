# Story 039 (2026-10-26) — region balance simulation

Tool: `tools/balance/deck_sim.gd --region=<ids> --floor=1,3,5 --seeds=30` (as in Story 036: each match alone, full HP,
starter deck, floor N = `floor_scaling` row N after `region_normalize`; bot dodge 0.85 = TD-006 default; timeout 180 s),
plus the new `--region-freq=200` mode. Raw output: `simulation-regions-raw.txt` (sections `===== <run>`). A 30-seed cell
has about +-9 points of noise per match, the region mean (9 matches x 3 characters) about +-3. Win % = mean of Kiem si /
Phap su / Sat thu.

## Result

| Region | Floor 1 | Floor 3 | Floor 5 |
|---|---|---|---|
| 5 existing regions (same build, same run) | 95.8 | 89.9 | 80.8 |
| hellfire | 97.4 (+1.6) | 93.8 (+3.9) | 87.3 (+6.5) |
| sky_isles, story data | 91.1 (-4.7) | 68.9 (-21.0) | 57.7 (-23.1) |
| sky_isles, tuned (shipped) | 96.4 (+0.6) | 83.1 (-6.8) | 74.7 (-6.1) |

Targets: each new region within +-10 points of the five-region mean at floors 1 / 3 / 5: PASS after tuning. "No match
above 95 % at floor 1" is the same measurement limit as Story 036 (every old-region match is 97-100 % there too).

## Other story checks

- Region frequency (200 seeded runs, 7 regions, random pick between the 2 offers): every region is offered in 27.5-31.1 %
  of the 1000 floor choices (target 20-40 %): PASS; chosen 13.5-14.6 % each; 0 of 200 runs repeat a region.
- Fire eater with the Phap su starter deck (fire-heavy), floor 1, 70 seeds: 100 % win (target >= 25 %): PASS. Burn and
  burning cells heal the boss, so the fire cards are weak there but the match is not a sure loss.
- Cloud veil (shroud): the player's hit rate is 1-7 points below the region's other matches (16-19 % against 20-23 %):
  the forecast matters, the match stays winnable (89-98 % win).
- Lava vents cost the bot almost no HP (0.01 HP / match): it leaves an erupting cell at once through its burning-cell
  dodge, and the first burn tick needs 0.5 s on the cell. Vents cost it burnt pieces (1.1-2.0 buried / match) and steps.
  Do not tune vent damage from the bot's HP column; watch it in the gate 8 playtest.
- Falls (sky_isles): 9-14 HP / match from falling cells, 1.2-1.7 pushes / match.

## Tuning (JSON only)

| Where | Change | Why |
|---|---|---|
| `chapters.json` `sky_isles.region_normalize.hp_mult` | 0.75 -> 0.53 | -21 / -23 points at floors 3 / 5, mostly timeouts (180 s): the small split arenas leave fewer placements, so damage per match is low |

Probes before choosing (Kiem si, floors 3 / 5, story data = 68.1 / 54.1): `crumble_after_sec` 3 with the bot leaving at
2.5 s: 58.9 / 45.6; `crumble_after_sec` 4: 63.3 / 44.4; bot leaving at 1.8 s: 65.9 / 52.2 (crumble timing is not the
cause); region HP x0.8: 76.7 / 65.6; x0.7: 81.5 / 73.3 (shipped, 0.75 x 0.7 = 0.53).

## Floor 5 per match after tuning (win %)

hellfire: imp 100, ember_hound 96, ash_golem 96, fire_eater 93, flame_cultist 91, ash_phoenix 87, hell_knight 87,
magma_slug 84, inferno_lord (boss) 52.
sky_isles: cloud_sprite 100, harpy 98, cloud_veil 89, thunder_shaman 89, gale_bird 88, wind_monk 82, storm_eagle 79,
sky_sentinel 40, storm_dragon (boss) 8 (mostly timeouts, like sand_sphinx in Story 036). Region bosses and the last
regular matches of sky_isles are the low end: watch them in the gate 8 playtest; the run-level retune is Story 040.
