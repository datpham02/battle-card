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
| `implemented` | boolean | - | False = shown locked ("not yet"); using it falls back to slash | false |
