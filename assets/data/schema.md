# Data file schemas

Keys are `snake_case`. Pixel units are reference viewport pixels (1280x720 landscape,
scaled by the `canvas_items` stretch mode). All keys are read by code in `src/`.

## hold_slots.json  (read by `src/hold/hold_slots_config.gd`)

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `slot_count` | integer 3..4 | slots | Number of hold slots; clamped into 3..4 | 4 |
| `drag_pick_padding_px` | number >= 0 | px | Extra margin around a belt card in which a press still picks it up (thumb tolerance) | 12.0 |
| `drop_hit_padding_px` | number >= 0 | px | Extra margin around a slot in which a drop counts as on that slot | 16.0 |
| `drag_lift_px` | number >= 0 | px | How far above the pointer the dragged card is held, so the thumb does not hide it | 56.0 |
| `tap_threshold_px` | number >= 0 | px | Pointer travel on a slot card below which press + release counts as a tap (uses a non-Step card); beyond it the card follows the pointer and releasing outside its slot cancels (Story 006) | 12.0 |

## field_drops.json  (read by `src/drops/field_drops_config.gd`)

Cut-point drops, one `FieldDrops` instance per side (Story 007). A missing or invalid file gives the defaults below with a warning; non-positive intervals are replaced by the default with a warning.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `spawn_interval_sec` | number > 0 | seconds | Base time between drops | 1.8 |
| `initial_delay_sec` | number >= 0 | seconds | Time before the first drop | 0.5 |
| `max_on_field` | integer >= 1 | points | Maximum points lying on one half; the drop timer holds while full | 4 |
| `freshness_sec` | number > 0 | seconds | Life of a point on the field; held points never rot | 7.0 |
| `hungry_after_sec` | number >= 0 | seconds | Empty-hand time after which the interval is shortened until a pickup | 4.0 |
| `hungry_interval_mult` | number > 0 | factor | Interval multiplier while hungry (< 1 = faster) | 0.6 |
| `allow_drop_in_danger` | boolean | - | When true points may land on the opponent's swing cells; when false they avoid them | true |

Point labels are not configured here: they are the board's perimeter labels (`BoardGrid.perimeter_labels()`: A1..A`side_cols` top, B1..B`side_rows` right, C1..C`side_cols` bottom, D1..D`side_rows` left), so they follow the board size in `combat.json`.

## combat.json  (read by `src/combat/combat_config.gd`)

Combat start values, timing caps and the board shape (Stories 003, 007). The board is two facing halves of `side_cols` x `side_rows` cells (`BoardGrid`), so it is `2 * side_cols` columns wide. A BOARD cell is `[col, row]` (row 0 = top); columns `0..side_cols-1` are the player's half, `side_cols..2*side_cols-1` the boss's.

**Side coordinates** (used by `missing_cells`): each half has its own `[side_col, side_row]` where side col 0 is the column FARTHEST from the divider and `side_cols-1` the column NEAREST it, for both halves. So `[0, 0]` is the top-left cell of the player half and the top-right cell of the boss half. Side to board: player col = side_col; boss col = `2 * side_cols - 1 - side_col`; row unchanged.

**Mirroring rule**: `missing_cells` are holes given once, in side coordinates, and are mirrored to the other half so both halves stay symmetric around the divider (`[0, 0]` removes board cells `(0, 0)` and `(2*side_cols-1, 0)`). Out-of-range entries are ignored with a warning; if every cell would be missing, no cell is removed (warning).

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `player_max_hp` | number >= 1 | HP | Player starting and maximum HP | 100 |
| `enemy_max_hp` | number >= 1 | HP | Dummy enemy starting and maximum HP | 100 |
| `side_cols` | integer >= 1 | cells | Columns of ONE half (board width = 2x) | 3 |
| `side_rows` | integer >= 1 | cells | Rows of the board | 3 |
| `missing_cells` | array of `[side_col, side_row]` | cell | Holes in the board, side coordinates, mirrored to the other half (see above) | `[]` |
| `player_start_cell` | `[col, row]` (board cell) | cell | Optional override of where the player starts; must be a real cell of the player's half or the grid default (real cell nearest the centre of the half) is used with a warning | grid default |
| `enemy_start_cell` | `[col, row]` (board cell) | cell | Optional override of where the boss starts (absent in the shipped file: the boss starts on the grid default cell and then walks, Story 009); must be a real cell of the boss's half or the grid default is used with a warning | grid default |
| `max_tick_sec` | number > 0 | seconds | Cap on one frame's time step for logic timers, so a frame hitch cannot skip a timing window | 0.1 |
| `feedback_sec` | number >= 0 | seconds | How long the HIT / MISS feedback stays on screen | 1.0 |
| `player_step_cooldown_sec` | number >= 0 | seconds | Wait after an accepted step before the next is allowed; presses during it are dropped, not queued | 0.45 |

## cuts.json  (read by `src/combat/cut_config.gd`)

Cut numbers (Story 008). A missing or invalid file gives the defaults below with a warning.

**Perimeter label convention** (same on both boards, by SCREEN position, referring to the TARGET half's square): `A` = top edge, numbered left to right (`A1` = leftmost column); `C` = bottom edge, left to right; `B` = right edge, top to bottom; `D` = left edge, top to bottom. In square coordinates `[0,cols] x [0,rows]` (x right, y down, 1 unit per cell): `A_i=(i-0.5,0)`, `C_i=(i-0.5,rows)`, `D_i=(0,i-0.5)`, `B_i=(cols,i-0.5)`. One point cuts straight to its opposite (`A_i`<->`C_i` = column i, `B_i`<->`D_i` = row i); 2 points = segment, 3-4 points = closed polygon, in selection order. Covered cells = cells a segment/edge crosses with positive length, plus polygon-interior cells (centre inside, even-odd). Missing board cells never count.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `base_damage_per_cell` | number >= 0 | HP | Slash damage per covered real cell | 6 |
| `swing_base_sec` | number >= 0 | seconds | Fixed part of the swing windup | 0.2 |
| `swing_per_cell_sec` | number >= 0 | seconds | Windup added per covered real cell (windup = base + per_cell * cells) | 0.25 |
| `single_point_opens_menu` | boolean | - | When false a one-point cut goes straight to slash; the menu opens only for 2-4 points | false |
| `hand_max_points` | integer 1..4 | points | Most points one cut may use; clamped into 1..4 | 4 |

## skills.json  (read by `src/combat/skill_config.gd`)

Skill menu timing and skill definitions (Story 008; burn and pin are data only until Story 010). A missing or invalid file gives a built-in slash-only config with a warning.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `menu_time_scale` | number 0..1 | factor | Simulation speed while the skill menu is open (applied by the view) | 0.2 |
| `menu_choose_sec` | number >= 0 | REAL seconds | Time to choose before the default skill is auto-picked | 3.0 |
| `default_skill` | string | skill id | Skill auto-picked on timeout; must exist in `skills` | `slash` |
| `skill_order` | array of skill ids | - | Stable order of the menu entries; skills not listed are appended | order of `skills` |
| `skills` | object id -> skill | - | Skill definitions (below) | slash only |

Skill entry keys:

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `display_name` | string | text | Player-facing name | the id |
| `min_cells` | integer >= 1 | cells | Covered real cells needed to use the skill (menu shows "need N cells") | 1 |
| `cooldown_sec` | number >= 0 | seconds | Cooldown started when the skill is used | 0 |
| `damage_multiplier` | number >= 0 | factor | Multiplier on the slash damage (`base_damage_per_cell * cells`) | 1.0 |
| `push_cells` | integer >= 0 | cells | Cells the target is pushed away from the divider along its row (stops at a missing cell/edge); push only | 0 |
| `effect` | `damage` / `push` / `burn` / `pin` | - | What the swing does on resolve (Story 010). `burn`: every covered cell ignites whether or not the target stands there; burning cells take no new field points and refuse pick-up. `pin`: pins the target if it stands in the covered cells | `damage` |
| `burn_duration_sec` | number >= 0 | seconds | Burn only: how long ignited cells burn; re-igniting resets the timer | 0 |
| `burn_tick_sec` | number > 0 | seconds | Burn only: interval of damage to a unit standing on a burning cell (<= 0 uses 0.5 with a warning) | 0.5 |
| `burn_damage_per_tick` | number >= 0 | HP | Burn only: damage per tick, per unit standing on the cell | 0 |
| `pin_duration_sec` | number >= 0 | seconds | Pin only: how long the target cannot step; re-pinning refreshes it | 0 |
| `implemented` | boolean | - | False = shown locked ("not yet"); using it falls back to slash | false |

## boss_brain.json  (read by `src/combat/boss_brain_config.gd`)

Boss brain timing and named weight sets (Story 009). The brain scores every ordered selection of 1..4 held points (up to 64) as a cut, the 4 step directions as moves, and waiting; the best score wins. A missing or invalid file gives the built-in `balanced` set with a warning; weights are clamped to >= 0.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `step_cooldown_sec` | number >= 0 | seconds | Boss wait after an accepted step (used by the controller to build the boss `UnitMover`) | 0.55 |
| `think_interval_sec` | number >= 0 | seconds | Time between brain evaluations; `decide` returns wait in between | 0.3 |
| `reaction_sec` | number >= 0 | seconds | How long the player's swing must have been visible before the brain reacts to it (dodge, interrupt, pickup danger) | 0.35 |
| `noise` | number >= 0 | score | Amplitude of the uniform seeded noise added to every candidate score | 0.15 |
| `active_set` | string | set name | Weight set in use; must exist in `sets` | `balanced` |
| `sets` | object name -> weights | - | Named weight sets (below) | built-in `balanced` |

Weight keys (inside each set; missing keys take the built-in balanced value):

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `cut_hit_now` | number >= 0 | score | Bonus when the player's current cell is in the candidate's covered cells | 3.0 |
| `cut_per_cell` | number >= 0 | score/cell | Value per covered cell (= damage) | 1.0 |
| `cut_duration_penalty` | number >= 0 | score/s | Penalty per second of windup | 0.8 |
| `cut_interrupt_bonus` | number >= 0 | score | Bonus when the player is mid-swing (visible), the player's cell is covered and our windup ends before the player's remaining time | 4.0 |
| `cut_point_cost` | number >= 0 | score/point | Penalty per point spent | 0.4 |
| `cut_hand_wait` | number >= 0 | score | Penalty for cutting with fewer than `hand_target` points while the hand is not full | 1.5 |
| `hand_target` | integer 1..4 | points | Hand size the brain prefers to wait for | 3 |
| `min_cut_score` | number | score | A cut is committed only at or above this score | 3.0 |
| `skill_bonus_<id>` | number >= 0 | score | Preference for skill `<id>` (e.g. `skill_bonus_push`) when available; slash is 0, so a skill with a bonus above 0 beats slash | `skill_bonus_push` 1.0 |
| `dodge_danger` | number >= 0 | score | Penalty for standing in the player's visible incoming swing, times urgency = 1 / max(time_left, 0.1) | 2.0 |
| `pickup_value` | number >= 0 | score | Value of the best reachable point, divided by 1 + Manhattan steps | 2.0 |
| `pickup_danger_penalty` | number >= 0 | score | Subtracted from a point's value when it lies under the incoming swing | 2.0 |
| `pickup_full_hand_zero` | boolean | - | When true pickups are worth 0 while the hand is full | true |
| `idle_bias` | number >= 0 | score | Baseline score of waiting; a move or cut must beat it | 0.2 |
| `retreat_hp_ratio` | number 0..1 | ratio | Below this boss HP ratio the brain prefers cells far from the divider | 0.3 |
| `retreat_bonus` | number >= 0 | score | Bonus for the farthest column (scaled 0..1 by distance from the divider) while retreating | 1.0 |
| `skill_bonus_burn` | number >= 0 | score | Preference for Burn (needs >= 5 covered cells) when available (balanced 1.0, aggressive 1.5, cautious 0.5) | 1.0 |
| `skill_bonus_pin` | number >= 0 | score | Preference for Pin (needs >= 7 covered cells) when available (balanced 1.0, aggressive 0.5, cautious 2.0) | 1.0 |
| `burn_avoid` | number >= 0 | score | Flat penalty for the boss standing on a burning cell (in the move score). A field point lying on a burning cell is worth 0 (pickup is refused there) | 3.0 |

### `learning` section of boss_brain.json (Story 010)

Rules of `BossLearning` (`src/combat/boss_learning.gd`): the boss adapts to the player. Missing keys take the default.

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `dodge_streak_threshold` | integer >= 1 | dodges | Early dodges in a row (player leaves a boss swing's cells; a hit resets) before the boss starts to feint | 3 |
| `feint_chance_base` | number 0..1 | probability | Chance a committed 1-point cut is a feint when the streak equals the threshold (0 below it) | 0.15 |
| `feint_chance_per_dodge` | number >= 0 | probability | Added per dodge beyond the threshold | 0.1 |
| `feint_chance_max` | number 0..1 | probability | Cap of the feint chance | 0.5 |
| `feint_cancel_fraction` | number 0..1 | fraction of windup | The feint is cancelled once this share of the swing duration has elapsed (no damage) | 0.5 |
| `full_hand_seconds` | number >= 0 | seconds | Player hand continuously full for this long switches on the quick-cut bias | 4.0 |
| `quick_cut_bias` | number >= 1 | multiplier | Multiplies `cut_duration_penalty` while the bias is on (the boss prefers fast cuts) | 2.0 |
| `interrupt_count_threshold` | integer >= 1 | interrupts | Times the player interrupted the boss before it favours 1-point cuts | 2 |
| `single_point_bonus` | number >= 0 | score | Flat bonus added to 1-point cut candidates once the interrupt threshold is reached | 2.0 |

## `run.json` (Story 011)

Run structure, read by `RunConfig` (`src/run/run_config.gd`). A bad or missing file gives one default match. The match numbers below are PLACEHOLDERS (a rough monotone difficulty ramp) for the later balance pass.

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `heal_between_matches` | number >= 0 | HP | Flat HP the player recovers after winning a non-final match (result clamped to max HP) | 25 |
| `intro_sec` | number >= 0 | seconds (real) | Length of each match intro (battle drawn but frozen) | 1.5 |
| `end_delay_sec` | number >= 0 | seconds (real) | Pause after the last hit before leaving the match | 1.5 |
| `between_sec` | number >= 0 | seconds (real) | Auto-advance of the between-matches screen; 0 = wait for the button only | 3.0 |
| `matches` | array, >= 1 | - | Ordered matches; the LAST one is the boss match | one default match |

Each `matches` entry:

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `id` | string | - | Stable id | `match_<n>` |
| `display_name` | string | - | Opponent name shown in the HUD | `Match <n>` |
| `boss_max_hp` | number > 0 | HP | Opponent max HP | 100 |
| `brain_set` | string | - | Weight set of `boss_brain.json` (balanced / aggressive / cautious); unknown = warning, file's `active_set` stays | balanced |
| `boss_step_cooldown_sec` | number >= 0 | seconds | Overrides `step_cooldown_sec` of `boss_brain.json` for this match | 0.55 |
| `boss_think_interval_sec` | number >= 0 | seconds | Overrides `think_interval_sec` | 0.3 |
| `boss_reaction_sec` | number >= 0 | seconds | Overrides `reaction_sec` | 0.35 |
| `boss_drop_interval_mult` | number > 0 | multiplier | Multiplies `spawn_interval_sec` of the BOSS half's drops only (< 1 = faster drops); the player's drops are unchanged | 1.0 |

Ramp (placeholder): matches 1..4 = hp 80/100/120/150, sets cautious/cautious/balanced/aggressive, step 0.80/0.65/0.55/0.50, think 0.50/0.40/0.30/0.25, reaction 0.60/0.45/0.35/0.30, drop mult 1.3/1.15/1.0/0.9.
