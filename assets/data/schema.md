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
| `enemy_start_cell` | `[col, row]` (board cell) | cell | Optional override of where the boss starts; must be a real cell of the boss's half or the grid default is used with a warning. `[3, 1]` is the boss's front-centre cell on the default 3x3 sides; Story 009 moves it | grid default |
| `max_tick_sec` | number > 0 | seconds | Cap on one frame's time step for logic timers, so a frame hitch cannot skip a timing window | 0.1 |
| `feedback_sec` | number >= 0 | seconds | How long the HIT / MISS feedback stays on screen | 1.0 |
| `player_step_cooldown_sec` | number >= 0 | seconds | Wait after an accepted step before the next is allowed; presses during it are dropped, not queued | 0.45 |
