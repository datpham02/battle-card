# Data file schemas

Keys are `snake_case`. Pixel units are reference viewport pixels (1280x720 landscape,
scaled by the `canvas_items` stretch mode). All keys are read by code in `src/`.

## conveyor_belt.json  (read by `src/conveyor/conveyor_config.gd`)

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `spawn_interval_sec` | number > 0 | seconds | Time between card spawns | 1.6 |
| `belt_speed` | number > 0 | belt units / second | Constant card speed | 160.0 |
| `belt_length` | number > 0 | belt units | Belt length; a card expires at this position. Belt units are abstract and mapped to screen width by the view. Time to cross = `belt_length / belt_speed` seconds | 1000.0 |
| `prewarm_sec` | number >= 0 | seconds | Simulated before the first frame so the belt starts populated | 0.0 |
| `cards` | array, non-empty | - | Card table (below). File is rejected if empty | - |

`cards[]` entries:

| Key | Type | Unit | Meaning |
|---|---|---|---|
| `id` | string | - | Card type id (unique) |
| `name` | string | - | Placeholder display name |
| `color` | string | hex RRGGBB | Placeholder card colour |
| `weight` | number >= 0 | relative weight | Spawn probability = weight / sum of weights |

## hold_slots.json  (read by `src/hold/hold_slots_config.gd`)

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `slot_count` | integer 3..4 | slots | Number of hold slots; clamped into 3..4 | 4 |
| `drag_pick_padding_px` | number >= 0 | px | Extra margin around a belt card in which a press still picks it up (thumb tolerance) | 12.0 |
| `drop_hit_padding_px` | number >= 0 | px | Extra margin around a slot in which a drop counts as on that slot | 16.0 |
| `drag_lift_px` | number >= 0 | px | How far above the pointer the dragged card is held, so the thumb does not hide it | 56.0 |
| `tap_threshold_px` | number >= 0 | px | Pointer travel on a slot card below which press + release counts as a tap (uses a non-Step card); beyond it the card follows the pointer and releasing outside its slot cancels (Story 006) | 12.0 |

## combat_cards.json  (read by `src/combat/combat_config.gd`)

Card effects, attack shapes, combat start values and timing caps (Stories 003, 006). The board is 6 columns x 3 rows, cell = `[col, row]`; columns 0-2 are the player's half, 3-5 the boss's; start cells come from `player_start_cell` / `enemy_start_cell`.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `player_max_hp` | number >= 1 | HP | Player starting and maximum HP | 100 |
| `enemy_max_hp` | number >= 1 | HP | Dummy enemy starting and maximum HP | 100 |
| `player_start_cell` | `[col, row]` | cell | Cell the player starts on; must be in the player's half (cols 0-2) or the default is used with a warning | `[1, 1]` |
| `enemy_start_cell` | `[col, row]` | cell | Cell the boss starts on; must be in the boss's half (cols 3-5) or the default is used with a warning. Story 006 uses `[3, 1]` (front column) so melee shapes can reach the stationary boss; Story 008 moves it | `[4, 1]` |
| `max_tick_sec` | number > 0 | seconds | Cap on one frame's time step for recovery and feedback timers, so a frame hitch cannot skip a timing window | 0.1 |
| `feedback_sec` | number >= 0 | seconds | How long the HIT / MISS feedback stays on screen | 1.0 |
| `shapes` | object | - | Named attack shape presets: name -> list of `[dx, dy]` offsets relative to the ATTACKER. `+dx` = toward the opponent (the resolver flips it for a unit facing -col), `+dy` = down a row. Cells off the board are ignored. An empty list (`self`) covers no cell | none |
| `cards` | object | - | Map of card type id (same ids as `conveyor_belt.json`) to an effect entry. A card with no entry cannot be played | none |

`cards.<id>` entries:

| Key | Type | Unit | Meaning |
|---|---|---|---|
| `effect` | string | - | `attack` (damages the boss if its cell is in the shape), `shield` (adds player armor) or `move` (Step: drag onto an adjacent own-half cell). Any other value: entry ignored |
| `shape` | string | - | Name from `shapes`. Used by `attack` and `shield`; default `self`; an unknown name ignores the entry. Not used by `move` |
| `amount` | number >= 0 | HP / armor points | Damage dealt or armor gained (ignored by `move`) |
| `recovery_sec` | number >= 0 | seconds | Time the player cannot play another card after this one. Belt flow and belt-to-slot picking are unaffected |

Preset shapes: `self` = `[]`; `front1` = the cell directly ahead; `row` = every cell ahead in the row; `wide` = the column directly ahead, all 3 rows.
