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
| `pause_lockout_sec` | number >= 0 | seconds | Story 016: the pause is refused during the last this-many seconds of a running swing (the player's or the boss's), and while the skill menu is open, so it cannot be used to preview a hit. 0 = only the menu blocks it | 0.5 |
| `step_cooldown_ref_sec` | number > 0 | seconds | Player step cooldown on a board `step_cooldown_ref_steps` steps across. Cooldown = ref_sec * (ref_steps / steps_across)^exponent, clamped to [min, max]; steps_across = max(side_cols, side_rows) - 1 (>= 1). Presses during the cooldown are dropped, not queued. Invalid values (ref_sec <= 0, ref_steps < 1, exponent < 0, min > max) fall back to defaults with a warning | 0.45 |
| `step_cooldown_ref_steps` | integer >= 1 | steps | Reference board width in steps | 2 |
| `step_cooldown_exponent` | number >= 0 | - | How strongly bigger boards speed stepping up (0 = constant) | 0.75 |
| `step_cooldown_min_sec` | number | seconds | Lower clamp (<= max) | 0.18 |
| `step_cooldown_max_sec` | number | seconds | Upper clamp | 0.60 |
| `player_step_cooldown_sec` | number >= 0 | seconds | DEPRECATED, not shipped: if present it overrides the computed value on every board (warning) | absent |

Measured (defaults): 2x2 = 0.60 (clamped), 3x3 = 0.45, 4x3 = 0.33, 6x6 = 0.23, 10x10 = 0.18 (clamped).

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

## cards.json  (read by `src/combat/skill_config.gd`, class SkillConfig)

Card menu timing, hand size, default deck and card definitions (Story 008/010/017). A card is what v3 called a skill. A missing or invalid file gives a built-in kiem_khi-only config with a warning.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `menu_time_scale` | number 0..1 | factor | Simulation speed while the skill menu is open (applied by the view) | 0.2 |
| `menu_choose_sec` | number >= 0 | REAL seconds | Time to choose before the default skill is auto-picked | 3.0 |
| `hand_size` | integer >= 1 | cards | Cards drawn from the deck into the menu hand per cut | 4 |
| `default_card` | string | card id | Basic card auto-picked on timeout even when the hand lacks it (a rule, not a hand card); must exist in `cards` | `kiem_khi` |
| `default_deck` | array of card ids | - | Starting deck, duplicates allowed; unknown ids dropped with a warning; empty = `[default_card]` | `[default_card]` |
| `card_order` | array of card ids | - | Stable display order of known cards (also the boss's default card list); cards not listed are appended | order of `cards` |
| `focus` | object | - | "Focus" (Tập trung) pause, keys below | all defaults below |
| `cards` | object id -> card | - | Card definitions (below) | kiem_khi only |

`focus` object keys (Story 012; bad values fall back to the default with a warning):

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `focus_time_scale` | number 0..1 | factor | Simulation speed while Focus is active; 0 = full stop, >0 = slow motion | 0.0 |
| `focus_max_sec` | number > 0 | REAL seconds | Longest one Focus lasts; on timeout the match resumes and the selection is kept | 4.0 |
| `focus_cooldown_sec` | number >= 0 | REAL seconds | Cooldown after ANY end (confirm, deselect, timeout, death); selecting points does not pause meanwhile | 8.0 |
| `focus_locks_movement` | boolean | - | true = step input is ignored (nothing queued) while Focus is active | true |

Card entry keys (ids: `kiem_khi`, `chan_phong`, `hoa_tran`, `bang_phong`; `effect` names stay behaviours):

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `name_key` | string | i18n key | Player-facing name: `card.<id>.name`, looked up with `tr()` in `assets/i18n/strings.csv` | `card.<id>.name` |
| `desc_key` | string | i18n key | One-line description: `card.<id>.desc` | `card.<id>.desc` |
| `min_cells` | integer >= 1 | cells | Covered real cells needed to use the skill (menu shows "need N cells") | 1 |
| `cooldown_sec` | number >= 0 | seconds | Cooldown started when the skill is used | 0 |
| `damage_multiplier` | number >= 0 | factor | Multiplier on the slash damage (`base_damage_per_cell * cells`) | 1.0 |
| `push_cells` | integer >= 0 | cells | Cells the target is pushed away from the divider along its row (stops at a missing cell/edge); push only | 0 |
| `effect` | `damage` / `push` / `burn` / `pin` | - | What the swing does on resolve (Story 010). `burn`: every covered cell ignites whether or not the target stands there; burning cells take no new field points and refuse pick-up. `pin`: pins the target if it stands in the covered cells | `damage` |
| `burn_duration_sec` | number >= 0 | seconds | Burn only: how long ignited cells burn; re-igniting resets the timer | 0 |
| `burn_tick_sec` | number > 0 | seconds | Burn only: interval of damage to a unit standing on a burning cell (<= 0 uses 0.5 with a warning) | 0.5 |
| `burn_damage_per_tick` | number >= 0 | HP | Burn only: damage per tick, per unit standing on the cell | 0 |
| `pin_duration_sec` | number >= 0 | seconds | Pin only: how long the target cannot step; re-pinning refreshes it | 0 |
| `rarity` | `common` / `rare` / `epic` | - | Card rarity (unknown -> common with a warning) | `common` |
| `class_tags` | array of strings | - | Class tags for future class decks | `[]` |
| `implemented` | boolean | - | False = shown locked ("not yet"); using it falls back to slash | false |

## boss_brain.json  (read by `src/combat/boss_brain_config.gd`)

Boss brain timing and named weight sets (Story 009). The brain scores every ordered selection of 1..4 held points (up to 64) as a cut, the 4 step directions as moves, and waiting; the best score wins. A missing or invalid file gives the built-in `balanced` set with a warning; weights are clamped to >= 0.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `step_cooldown_sec` | number >= 0 | seconds | Boss wait after an accepted step (used by the controller to build the boss `UnitMover`); fallback only: a match's `boss_step_cooldown_mult` overrides it | 0.55 |
| `think_interval_sec` | number >= 0 | seconds | Time between brain evaluations; `decide` returns wait in between | 0.3 |
| `reaction_sec` | number >= 0 | seconds | How long the player's swing must have been visible before the brain reacts to it (dodge, interrupt, pickup danger). DEFAULT only: a set's `movement.reaction_sec` wins when present (Story 013) | 0.35 |
| `noise` | number >= 0 | score | Amplitude of the uniform seeded noise added to every CUT candidate score (movement uses the set's `movement.move_noise`) | 0.15 |
| `active_set` | string | set name | Weight set in use; must exist in `sets` | `balanced` |
| `sets` | object name -> weights | - | Named weight sets (below) | built-in `balanced` |

Weight keys (inside each set; missing keys take the built-in balanced value):

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `cut_hit_now` | number >= 0 | score | Bonus when the player's current cell is in the candidate's covered cells (lowered from 3.0 in Story 013: `escape_penalty` now carries the "will it land" judgement) | 1.5 |
| `cut_per_cell` | number >= 0 | score/cell | Value per covered cell (= damage) | 1.0 |
| `cut_duration_penalty` | number >= 0 | score/s | Penalty per second of windup | 0.8 |
| `cut_interrupt_bonus` | number >= 0 | score | Bonus when the player is mid-swing (visible), the player's cell is covered and our windup ends before the player's remaining time | 4.0 |
| `cut_point_cost` | number >= 0 | score/point | Penalty per point spent | 0.4 |
| `cut_hand_wait` | number >= 0 | score | Penalty for cutting with fewer than `hand_target` points while the hand is not full | 1.5 |
| `hand_target` | integer 1..4 | points | Hand size the brain prefers to wait for | 3 |
| `min_cut_score` | number | score | A cut is committed only at or above this score | 3.0 |
| `skill_bonus_<id>` | number >= 0 | score | Preference for skill `<id>` (e.g. `skill_bonus_chan_phong`) when available; slash is 0, so a skill with a bonus above 0 beats slash | `skill_bonus_push` 1.0 |
| `dodge_danger` | number >= 0 | score | Penalty for standing in the player's visible incoming swing, times urgency = 1 / max(time_left, 0.1) | 2.0 |
| `pickup_value` | number >= 0 | score | Value of the best reachable point, divided by 1 + Manhattan steps | 2.0 |
| `pickup_danger_penalty` | number >= 0 | score | Subtracted from a point's value when it lies under the incoming swing | 2.0 |
| `pickup_full_hand_zero` | boolean | - | When true pickups are worth 0 while the hand is full | true |
| `idle_bias` | number >= 0 | score | Baseline score of waiting; a move or cut must beat it | 0.2 |
| `retreat_hp_ratio` | number 0..1 | ratio | Below this boss HP ratio the brain prefers cells far from the divider | 0.3 |
| `retreat_bonus` | number >= 0 | score | Bonus for the farthest column (scaled 0..1 by distance from the divider) while retreating | 1.0 |
| `skill_bonus_burn` | number >= 0 | score | Preference for Burn (needs >= 5 covered cells) when available (balanced 1.0, aggressive 1.5, cautious 0.5) | 1.0 |
| `skill_bonus_pin` | number >= 0 | score | Preference for Pin (needs >= 7 covered cells) when available (balanced 1.0, aggressive 0.5, cautious 2.0) | 1.0 |
| `burn_avoid` | number >= 0 | score | Legacy weight (Story 009/010): since Story 013 burning cells are never entered or targeted at all (BFS routes around them), so this no longer enters a score. A field point lying on a burning cell is still worth 0 (pickup is refused there) | 3.0 |
| `escape_penalty` | number >= 0 | score | Story 013 escape-route scoring: added as `escape_penalty / (1 + escape_cells)`, where `escape_cells` = cells the player can reach within `EscapeAnalysis.steps_for_swing(windup, player step cooldown)` 4-way steps on the player's half (burning cells excluded) that the cut does NOT cover. 0 escape cells = the full bonus (balanced 4.0, aggressive 5.0, cautious 3.0) | 4.0 |
| `combo_chance` | number 0..1 | probability | Story 013 combo: when the boss holds >= 2 points and commits a cut, chance (own seeded RNG stream; no roll at 0 or 1) that it also queues a SECOND slash at once, chosen with the same escape analysis to cover the escape cells of the first (the two share no hand point). The player has no combo (the `CutActor` queue is boss-only). Shipped: cautious 0.0, balanced 0.25, aggressive 0.6 | 0.25 |
| `combo_gap_sec` | number >= 0 | seconds | Seconds between the two impacts of a combo: swing 2 starts the moment swing 1 resolves and its windup is EXACTLY this gap, floored at `swing_base_sec` of `cuts.json` (`BossController.combo_gap_sec()`), independent of its cell count and of the match `swing_speed_mult`. Interrupting swing 1 drops swing 2 with it. `SwingArbiter` ticks both actors in time slices; the queued swing is started by `CutActor.tick` when swing 1 resolves and is ticked from the NEXT slice, never in the same one. HUD: swing 1 solid red with its countdown, swing 2 hatched lighter red with "2: +gap s" | 0.5 |

### `movement` block of each set (Story 013)

Per-set movement profile, read by `BossBrainConfig.movement_for(set)` and used by `BossBrain`: the brain keeps ONE destination `{cell, purpose}` (purpose = `pickup` / `dodge` / `retreat` / `wander`) and walks one step per decision toward it. The destination is dropped at once when it stops making sense (point gone or picked, cell burning, unreachable, reached, a visible player swing on the current cell or on the NEXT cell of the path -> dodge to the nearest safe cell). A match of `chapters.json` may override any of these keys (see below). A set without the block uses the defaults.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `move_commitment` | number 0..1 | probability | Each think with a live non-dodge destination re-evaluates it only with probability `1 - move_commitment` (seeded roll; 1.0 = never, no RNG consumed; 0.0 = always, no RNG consumed) | 0.7 |
| `move_noise` | number >= 0 | score | Amplitude of the uniform seeded noise on destination choice and the move score. 0 = movement is a pure function of the state (no RNG) | 0.15 |
| `reaction_sec` | number >= 0 | seconds | Per-set reaction time (replaces the file-level `reaction_sec` for this set); absent = file-level value | absent |
| `path_style` | `row_first` / `shortest` / `mixed` | - | `row_first`: walk along the row (change column) until the column matches, then change row; `shortest`: Manhattan with the fixed tie rule (keep the current row = horizontal step first, then the step ending nearer the divider); `mixed`: per destination a seeded coin picks `row_first` or its mirror `column_first`. Burning / missing cells are never entered: a BFS over real non-burning own cells routes around them with the same tie rule | shortest |
| `juke_chance` | number 0..1 | probability | Right after a dodge destination is reached, chance (seeded; 0 = no roll) of one extra step perpendicular to the dodge direction when that cell exists on the own half, is not burning and not inside the visible swing | 0.2 |
| `wander_when_idle` | boolean | - | With no pickup target, no threat and no retreat: true = walk to a random (seeded) safe own cell, false = stand still | true |

Profiles shipped (starting values, retune after playtest): cautious = 1.0 / 0.0 / 0.35 / `row_first` / 0.0 / false (the story's 0.6 broke the cautious dodge/interrupt baseline of the brain simulation, so the slow reaction of matches 1-2 comes from `chapters.json` `boss_reaction_sec` 0.60 / 0.45 instead); balanced = 0.7 / 0.15 / 0.35 / `shortest` / 0.2 / true; aggressive = 0.5 / 0.3 / 0.25 / `mixed` / 0.4 / true (commitment / noise / reaction / style / juke / wander).

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

## `chapters.json` (Stories 011, 015)

Chapters -> floors -> matches, read by `ChaptersConfig` (`src/run/chapters_config.gd`). A run is ONE floor: `ChaptersConfig.resolved_floor` fills `arena` and `arena_seed` of every match and `RunConfig.from_floor` builds the run. A bad or missing file gives one default chapter / floor / match (warning). A chapter or floor without matches is dropped (warning); ids must be unique per level (a duplicate is dropped with a warning). The match numbers below are PLACEHOLDERS for the later balance pass. `RunConfig.load_from_file` still reads the flat single-floor format (used by tests): the keys of `defaults` plus `matches` at the root.

Top level: `{ "defaults": {...}, "chapters": [...] }`.

`defaults` (all optional; also accepted as per-floor overrides on a floor):

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `heal_between_matches` | number >= 0 | HP | Flat HP the player recovers after winning a non-final match (result clamped to max HP); HP does not carry across floors | 25 |
| `intro_sec` | number >= 0 | seconds (real) | Length of each match intro (battle drawn but frozen) | 1.5 |
| `end_delay_sec` | number >= 0 | seconds (real) | Pause after the last hit before leaving the match | 1.5 |
| `between_sec` | number >= 0 | seconds (real) | Auto-advance of the between-matches screen; 0 = wait for the button only | 3.0 |
| `heal_between_floors` | number >= 0 | HP | Story 019: HP recovered after a floor's boss (clamped to max HP; HP is never refilled on a new floor) | 40 |
| `revive_tokens` | integer >= 0 | count | Story 019: revives a run starts with (reserved for the future revive item, unused) | 0 |
| `retry_min_hp_ratio` | number 0..1 | ratio of max HP | OPTIONAL, legacy (Story 015): `RunState.retry_match` / `resume_at` start with max(HP at match start, this x max HP). Not shipped; the Story 019 run flow passes 0 (no minimum) | 0 |

Each `chapters` entry: `id` (unique string), `name_key` (`chapter.<id>.name`), `floors` (>= 1). Each floor: `id` (unique within the chapter; the floor key is `"<chapter id>/<floor id>"`, e.g. `ch1/f2`), `name_key` (`floor.<chapter id>.<floor id>.name`), `matches` (>= 1, the LAST is the boss), and optionally:

| Key | Type | Meaning | Default |
|---|---|---|---|
| `arena` | object | Fixed board for every match of the floor: `{"shape": id}` / `{"shape": id, "variant": true}` / direct block (see the match `arena` key below) | none |
| `arena_pool` | array of shape ids | Each match draws a shape from the pool with a seeded shuffle bag: the pool is shuffled once with `floor_seed`, then walked cyclically by match index (adjacent matches differ when the pool has >= 2 shapes). Ids unknown to `arenas.json` are dropped with a warning; an empty pool gives the `combat.json` board | none |
| `arena_variant` | boolean | Applied to every shape drawn from `arena_pool` (a seeded variant, Story 014) | false |

Arena rules per match: the match's own non-empty `arena` wins; else the floor's `arena`; else the pool draw; else `{}` (the `combat.json` board). A floor with BOTH `arena` and `arena_pool` is a data error (warning, `arena` is used). `arena_seed` of match i = `hash([floor_seed, i])` (non-negative) is filled by CODE for every match (also fixed arenas) so variants are reproducible; do not write it in the data. `floor_seed` is new on every entry to a floor and kept when a lost match is retried (`--seed=N` forces it).

Each floor `matches` entry (optional per-match `arena` override as below; `arena_seed` is filled by code, default -1 = random):

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `id` | string | - | Stable id | `match_<n>` |
| `name_key` | string | - | i18n key of the opponent name shown in the HUD (`boss.<id>.name`, translated with `tr()`) | none |
| `display_name` | string | - | LEGACY literal name (flat test configs only, warning); shipped data uses `name_key` | `Match <n>` |
| `boss_max_hp` | number > 0 | HP | Opponent max HP | 100 |
| `brain_set` | string | - | Weight set of `boss_brain.json` (balanced / aggressive / cautious); unknown = warning, file's `active_set` stays | balanced |
| `boss_step_cooldown_mult` | number > 0 | multiplier | Boss step cooldown = the player's computed (board-scaled) step cooldown x this; wins over `step_cooldown_sec` of `boss_brain.json`, which is only the fallback for runs without match params | 1.0 |
| `boss_step_cooldown_sec` | number >= 0 | seconds | DEPRECATED, not shipped: if present it is used as an absolute boss cooldown instead of the multiplier (warning) | absent |
| `boss_think_interval_sec` | number >= 0 | seconds | Overrides `think_interval_sec` | 0.3 |
| `boss_reaction_sec` | number >= 0 | seconds | Overrides the boss reaction time for this match (both the file-level `reaction_sec` and the match set's `movement.reaction_sec`; precedence: file < set < this < `movement.reaction_sec` below) | 0.35 |
| `boss_drop_interval_mult` | number > 0 | multiplier | Multiplies `spawn_interval_sec` of the BOSS half's drops only (< 1 = faster drops); the player's drops are unchanged | 1.0 |
| `swing_speed_mult` | number > 0 | multiplier | Story 013: multiplies the windup of every BOSS swing in this match (`CutActor.duration_mult`; < 1 = faster, the countdown shows the scaled time); the player's swings are unchanged. A combo's second swing is NOT scaled (its windup is the gap). Shipped: match 2 = 1.0, others default; the ramp 1.0/1.0/0.9/0.8 is for the balance pass | 1.0 |
| `combo_chance` | number -1 or 0..1 | probability | Story 013: overrides the match set's `combo_chance` (`boss_brain.json`) for this match only; -1 or absent = use the set's value | -1 |
| `combo_gap_sec` | number -1 or >= 0 | seconds | Story 013: overrides the match set's `combo_gap_sec` for this match only (still floored at `swing_base_sec`); -1 or absent = use the set's value | -1 |
| `movement` | object | - | Story 013: keys of the `movement` block of `boss_brain.json` (`move_commitment`, `move_noise`, `reaction_sec`, `path_style`, `juke_chance`, `wander_when_idle`), merged over the match set's profile for this match only; unknown keys warn and are ignored | `{}` (set's profile) |
| `traits` | array of `{id, params}` | - | Story 014: boss traits switched on for this match (see **Boss traits** below). `id` is a `TraitRegistry` key; `params` (optional object) overrides that trait's defaults. Unknown id / non-object entry = warning, skipped, the match still runs; a non-array = warning, no traits. Shipped: match 3 `row_burner`, match 4 (boss) `rotten_thrower` with `interval_sec` 5.0, matches 1-2 none | `[]` |
| `arena` | object | - | Story 014: the board of this match. `{"shape": "<id>"}` = a shape of `arenas.json`; `{"shape": "<id>", "variant": true}` = a seeded variant of it (1-3 holes toggled, maybe flipped vertically; falls back to the base shape); or a direct block `{side_cols, side_rows, missing_cells}` (validated like a library shape). Unknown id / invalid block = warning, the `combat.json` board is kept. Absent = `combat.json`. Floors normally set the arena (see above); a match-level block overrides it. Dev: `--arena=<id>[:variant]` overrides match 1 | `{}` (combat.json board) |

Ramp (placeholder): matches 1..4 = hp 80/100/120/150, sets cautious/cautious/balanced/aggressive, step mult 1.78/1.44/1.22/1.11 (= 0.80/0.65/0.55/0.50 s on 3x3), think 0.50/0.40/0.30/0.25, reaction 0.60/0.45/0.35/0.30, drop mult 1.3/1.15/1.0/0.9. Match 2 overrides `movement` = {move_commitment 0.9, move_noise 0.05, reaction_sec 0.45} (Story 013).


### Boss traits (`chapters.json` -> floor `matches[].traits`, Story 014)

A trait is one self-contained boss mechanic: a `BossTrait` subclass (`src/traits/`) created fresh per match by `TraitHost` (owned by `CombatView`), fed the hooks `on_match_start`, `on_tick(step)` (SCALED simulation seconds, after the arbiter, only while both units live), `on_boss_swing_started`, `on_boss_swing_resolved`, `on_player_swing_resolved`, `on_point_spawned`, `on_boss_damaged` (player swings only; burn ticks are not reported) and `teardown` (when the battle leaves the tree). Traits touch the battle only through public APIs (`state`, `grid`, both `FieldDrops`, `BossController`, `StatusEffects`, `SwingArbiter`, the player's `HoldSlots`); none edits `BossBrain`. RNG: each trait has its own `RandomNumberGenerator` seeded from the match seed + index * 1009 + a per-class offset (negative seed = random), so seeded runs stay deterministic.

`rotten_thrower` params (defaults in `RottenThrowerTrait`):

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `interval_sec` | number >= 0 | seconds (sim) | Time between throws, counted from a throw | 6.0 |
| `first_delay_sec` | number >= 0 | seconds (sim) | Time from match start to the first throw | 3.0 |
| `field_freshness_sec` | number >= 0 | seconds | Life of a rotten point on the field before it rots away | 5.0 |
| `rot_in_hand_sec` | number >= 0 | seconds (sim) | Time a picked-up rotten point blocks a hand slot before it leaves on its own (`HoldSlots.tick_rot`) | 6.0 |
| `label` | string | - | Label shown on the rotten point | `X` |
| `max_on_field` | integer >= 1 | points | Rotten points allowed on the player's half at once; at the cap the throw waits (no burst) | 1 |

A rotten point (`FieldPoint.rotten`) lands on a random seeded free, non-burning player cell that is not the player's cell; it counts toward the half's `max_on_field` of `field_drops.json`, is picked up like any point (needs a free slot), occupies the slot, cannot be selected (`toggle_selected` is false) and never enters a cut.

`row_burner` params (defaults in `RowBurnerTrait`):

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `interval_sec` | number >= 0 | seconds (sim) | Time between warnings (warning to warning); a running warning finishes before the next starts | 8.0 |
| `first_delay_sec` | number >= 0 | seconds (sim) | Time from match start to the first warning | 4.0 |
| `warn_sec` | number >= 0 | seconds (sim) | Warning length before the row ignites (the HUD flashes the cells) | 1.2 |
| `burn_sec` | number >= 0 | seconds (sim) | How long the row burns (`StatusEffects.ignite`, same rules as the Burn skill) | 2.5 |
| `tick_sec` | number > 0 | seconds (sim) | Damage interval for a unit standing in the burning row | 0.5 |
| `damage_per_tick` | number >= 0 | HP | Damage per tick | 2.0 |
| `row_pick` | `player_row` / `random` | - | Which row: the one the player stands on when the warning starts, or a seeded random row of the half | `player_row` |

Adding a new boss = one JSON block in a floor's `matches` (`arena`, `traits`, the brain/timing keys above). Adding a new mechanic = one trait class + one registry line:
1. Create `src/traits/<id>.gd`: `class_name <Name>Trait extends BossTrait`, override `get_id()` (return the id) and `seed_offset()`.
2. Read every number in `setup()` with `param_float` / `param_int` / `param_string` against a `DEFAULT_*` constant; keep the live state in private vars and reset it in `on_match_start()`.
3. Act in the hooks through the context's public APIs only (`status.ignite`, `player_drops.place_rotten`, `state.damage`, ...); expose getters / signals for the HUD.
4. Add `"<id>": preload("res://src/traits/<id>.gd")` to `TraitRegistry.SCRIPTS`.
5. Switch it on from `chapters.json`: `"traits": [{"id": "<id>", "params": {...}}]`, document the params here.

## `arenas.json` (Story 014)

Named board shapes, read by `ArenaLibrary` (`src/arena/arena_library.gd`). Every shape is checked by `ArenaValidator` at load; a shape that fails is dropped with a warning naming the reasons. A bad or missing file gives a library with only the built-in 3x3 `square`.

SIDE COORDINATES: `missing_cells` entries are `[col, row]` on ONE half. Col 0 is the column FARTHEST from the divider on both halves (so `[0, 0]` is the top-left cell of the player half and the top-right cell of the boss half), row 0 is the top. Holes are mirrored to the other half automatically, so shapes are symmetric by construction.

`rules` block:

| Key | Type | Unit | Meaning |
|---|---|---|---|
| `min_cells_per_side` | int | cells | Fewest real cells a half may have |
| `variant_max_attempts` | int >= 1 | tries | Candidates `ArenaVariants` tries before returning the base shape (warning) |
| `variant_change_min` / `variant_change_max` | int >= 1 | cells | Random side cells toggled (hole added or filled) per candidate; a vertical flip is also tried with probability 0.5 |

Each `shapes` entry: `id` (unique string), `name_key` (`arena.<id>.name`; `ArenaNames` holds the same keys for the HUD), `side_cols`, `side_rows` (cells of one half), `missing_cells` (`[[col,row],...]`), `difficulty` (1..5, for the later per-tier pools, Story 015).

Validator checks: each half has >= `min_cells_per_side` cells; each half is 4-connected; both default cells exist; the halves mirror each other; from each half's default cell, EVERY single-point cut (A1..D<n>) leaves >= 1 uncovered cell reachable in 1 step.

| id | side cols x rows | cells per side | difficulty |
|---|---|---|---|
| `square` | 3x3 | 9 | 1 |
| `rect` | 4x3 | 12 | 2 |
| `cross` | 4x4 | 12 | 3 |
| `u_shape` | 4x3 | 11 | 3 |
| `staircase` | 4x4 | 10 | 3 |
| `ring` | 6x5 | 21 | 4 |
| `islands_bridge` | 6x3 | 14 | 4 |
| `diamond` | 5x5 | 13 | 4 |

Adding a new arena = one JSON block:
1. Append `{id, name_key, side_cols, side_rows, missing_cells, difficulty}` to `shapes` (and the key's vi/en rows to `strings.csv`) (holes in side coordinates; the far column is col 0).
2. Keep each half connected (and give the walls next to a hole thickness >= 2 where the default cell sits: a 1-cell-wide wall is fully covered by one straight cut) and at least `min_cells_per_side` cells; do not make the half's default (centre-most) cell a dead end that one straight cut can cover entirely.
3. Launch the game; a shape that fails the validator is dropped and the warning says why.
4. Use it from `chapters.json` with a floor `"arena": {"shape": "<id>"}` or an `arena_pool` (add `"variant": true` / `arena_variant` for a seeded variant), or capture it with `--arena=<id>`.
5. A cut line through a hole covers nothing there; that is intended, not fixed.

## `progress.json` (Story 015, v2 in Story 019, `user://progress.json`)

Player save written by `ProgressStore` (atomic: temp file renamed over the target) at milestones: start of every match, after a reward pick, run end. Never written mid-match. Parsed by `ProgressState.from_json`: empty, corrupt, non-object or unknown-version text gives an empty state (warning). A version-1 file loads without warning: only `locale` is read, the rest is ignored. With a `ChaptersConfig`, unknown chapter ids in `cleared_chapters` are dropped and an invalid `run_in_progress` is dropped (warning). Dev: `--progress=none|all` uses an in-memory store.

| Key | Type | Meaning |
|---|---|---|
| `version` | integer | Always 2 |
| `locale` | string | UI language code (`vi` / `en`) |
| `cleared_chapters` | array of chapter ids | Chapters whose last floor boss was beaten, e.g. `["ch1"]`. Chapter 0 is always unlocked; chapter N+1 unlocks when chapter N is cleared (any character) |
| `seen_cards` | array of card ids | Cards ever offered or owned (write-only for now) |
| `run_in_progress` | object or null | The run being played (`RunSession.to_dict`): `character` (id), `chapter` (chapter id), `floor` (floor id), `match_index` (0-based), `hp` (HP at the start of that match, negative = full), `deck` (card ids, duplicates allowed), `run_seed`, `elapsed` (seconds), `pending_reward` (card ids offered but not yet picked/skipped, `[]` when none; kept so quitting on the reward screen cannot re-roll), `revives`. The floor seed is derived: `RunSession.floor_seed()` |

## `rewards.json` (Story 019, read by `src/run/reward_roller.gd`, class RewardRoller)

Card reward after every won match that does not end the run. Bad or missing file: defaults below (warning).

| Key | Type | Meaning | Default |
|---|---|---|---|
| `offer_count` | integer >= 1 | Distinct cards offered | 3 |
| `rarity_weights` | object rarity -> number >= 0 | Draw weight per rarity (`common`, `rare`, `epic`); a missing rarity = 0 weight | 70 / 25 / 5 |
| `class_tag_bonus` | number >= 1 | Weight multiplier for a card whose `class_tags` contain the character's id | 2.0 |
| `allow_skip` | boolean | The reward screen offers a Skip button | true |
| `pool_excludes_defaults` | boolean | Cards in `cards.json` `default_deck` are not offered | false |

The pool is every `implemented` card; the roll is a seeded weighted draw without replacement.

## `characters.json` (Story 018, read by `src/run/character_config.gd`, class CharacterConfig)

Playable classes. Pure data; the stats and starter deck enter the match through `match_params["character"]` (GameFlow -> RunController -> CombatView). No character chosen = the plain combat.json player (old numbers).

| Key | Type | Meaning |
|---|---|---|
| `default_character` | string | Id used by `CharacterConfig.default_id()`; unknown/absent -> the first character |
| `characters[].id` | string | Unique id (duplicate -> warning, later dropped) |
| `characters[].name_key` / `desc_key` | translation keys | Class name and short description (`character.<id>.name` / `.desc`) |
| `characters[].max_hp` | number | Player max and start HP; clamped >= 1 |
| `characters[].step_cooldown_mult` | number | Multiplies the board-scaled player step cooldown (0.9 = 10 % faster steps); <= 0 -> 1. The boss's own step cooldown is NOT affected |
| `characters[].focus_max_sec` | number | Real seconds one Focus lasts (overrides cards.json `focus.focus_max_sec`); clamped >= 0 |
| `characters[].passive` | object | `{id, params}`; id is a `PassiveRegistry` key (`second_wind`, `wide_caster`, `quick_blade`), unknown id -> warning and no passive |
| `characters[].passive_name_key` / `passive_desc_key` | translation keys | Passive name / description for the select screen (`passive.<id>.name` / `.desc`) |
| `characters[].starter_deck` | array of card ids | Deck of the match; unknown card -> warning and dropped, empty -> cards.json `default_deck` |
| `characters[].unlocked` | bool | Selectable now (only a data flag; unlock rules are out of scope) |

Passive params: `second_wind {heal_after_match}` extra HP after a won match (added before the max clamp); `wide_caster {min_cells, duration_mult}` player swings over `min_cells` or more cells wind up `duration_mult` times as long; `quick_blade {max_cells, damage_mult}` player hits over `max_cells` or fewer cells deal `damage_mult` times the final damage. Passives only affect the player.

Dev arg: `--character=<id>` (GameFlow) selects a character; without it and without the select screen no character is passed.

## Translation keys (Story 017, `assets/i18n/strings.csv`)

Every player-facing string is a key. The CSV has the header `keys,vi,en` (UTF-8; a third language is one more column); Godot imports it into `assets/i18n/strings.<locale>.translation` (gitignored, regenerated by `godot --headless --path . --import`), registered in `project.godot` under `[internationalization]` with `locale/fallback="vi"`. Code never holds display text: `const TEXT_*` constants are keys drawn through `tr()` (`tr(key) % [...]` for printf templates; placeholders are identical in every column), and data files carry keys only:

| Key group | Where | Example |
|---|---|---|
| `ui.<screen>.<label>` | `TEXT_*` in views | `ui.hud.cast`, `ui.title.play`, `ui.floor_select.title` |
| `title.*` | title screen name / tagline | `title.name` |
| `card.<id>.name` / `card.<id>.desc` | `cards.json` `name_key` / `desc_key` | `card.kiem_khi.name` |
| `chapter.<id>.name` | `chapters.json` chapter `name_key` | `chapter.ch1.name` |
| `floor.<chapter>.<floor>.name` | floor `name_key` | `floor.ch1.f2.name` |
| `boss.<id>.name` | every match `name_key` (foe name) | `boss.goblin_chief.name` |
| `arena.<id>.name` | `arenas.json` `name_key`, `ArenaNames.NAMES` | `arena.square.name` |
| `trait.<id>.name` | trait names (reserved for a later HUD / codex) | `trait.row_burner.name` |
| `character.<id>.name` / `.desc` | `characters.json` `name_key` / `desc_key` (Story 018) | `character.phap_su.name` |
| `passive.<id>.name` / `.desc` | `characters.json` `passive_name_key` / `passive_desc_key` | `passive.wide_caster.name` |

A missing key shows the raw key (Godot's default), on purpose. The saved UI locale lives in `progress.json` as `locale` (`"vi"` when absent, v1 saves load unchanged).
