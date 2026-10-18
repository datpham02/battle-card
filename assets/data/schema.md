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

## combat_cards.json  (read by `src/combat/combat_config.gd`)

Placeholder card effects and combat start values (Story 003; the full card set is Story 006).

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `player_max_hp` | number >= 1 | HP | Player starting and maximum HP | 100 |
| `enemy_max_hp` | number >= 1 | HP | Dummy enemy starting and maximum HP | 100 |
| `cards` | object | - | Map of card type id (same ids as `conveyor_belt.json`) to an effect entry. A card with no entry cannot be played | none |

`cards.<id>` entries:

| Key | Type | Unit | Meaning |
|---|---|---|---|
| `effect` | string | - | `attack` (subtracts enemy HP) or `shield` (adds player armor). Any other value: entry ignored |
| `amount` | number >= 0 | HP / armor points | Damage dealt or armor gained |
| `recovery_sec` | number >= 0 | seconds | Time the player cannot play another card after this one. Belt flow and belt-to-slot picking are unaffected |
| `lane_shift` | boolean, optional (default false) | - | If true, playing the card also moves the player to an adjacent lane. The destination is the lane column the card is dropped on; it must be adjacent to the player's current lane (Story 005; only `sidestep` uses it) |

## enemy_patterns.json  (read by `src/combat/enemy_pattern_config.gd`)

Fixed, cyclic enemy attack pattern (Story 005). No randomness: attacks run in list order and repeat. Exactly one attack is telegraphed at a time. Lanes are numbered 0..2 left to right.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `initial_pause_sec` | number >= 0 | seconds | Idle time before the first attack is telegraphed | 1.0 |
| `feedback_sec` | number >= 0 | seconds | How long the HIT / MISS feedback stays on screen | 1.0 |
| `max_tick_sec` | number > 0 | seconds | Cap on one frame's time step for enemy, recovery and feedback timers, so a frame hitch cannot telegraph and resolve an attack in the same tick | 0.1 |
| `attacks` | array, non-empty | - | Attack list, repeated in order. If empty the enemy stays idle | - |

`attacks[]` entries:

| Key | Type | Unit | Meaning |
|---|---|---|---|
| `target_lane` | integer 0..2 | lane index | Lane the attack hits (clamped) |
| `damage` | number >= 0 | HP | Damage on hit; armor absorbs first, remainder hits HP |
| `telegraph_sec` | number >= 0.1 | seconds | Warning countdown before the attack resolves |
| `pause_after_sec` | number >= 0 | seconds | Idle time after resolution before the next telegraph |
