| `signature.<id>.name` / `.desc` | `characters.json` `signature.name_key` / `signature.desc_key` (Story 021) | `signature.tram.name` |
| `characters[].signature` | object | Story 021: `{id, name_key, desc_key, cooldown_sec, params}`; id is a `SignatureRegistry` key (`tram`, `thien_hoa`, `anh_bo`), unknown or malformed -> warning and no signature (the character plays as before); the signature becomes ready when the formation map is complete AND its cooldown is over (Story 029, see `formation_*` in combat.json), checked on every player cover and when the cooldown reaches 0, then stays ready until used (fading cells do not revoke it); activating it resets the map; not carried across matches (cooldown 0 at match start). `cooldown_sec` (Story 029 Phần D, number >= 0, scaled sim seconds, missing -> 0, negative -> 0, non-number -> warning and 0): cooldown after each use, started when a timed effect (`tram`, `anh_bo`) ends or at once for an instant one (`thien_hoa`); the map keeps lighting during it. Shipped: tram 20, thien_hoa 15, anh_bo 12 (placeholders pending the bot measurement); the boss never has one. `charge_cells` (Story 021 charge bar, removed by Story 029) is no longer read: a leftover key is ignored |
| `formation_fade_base_sec` | float >= 0 | seconds | Story 029 formation map: a covered enemy cell stays lit `base + per_cell x (real cells of the enemy half)` seconds (3x3 = 12.2 s, 4x3 = 14.6 s, 21-cell ring = 21.8 s with the defaults; tuned 2026-10-25 from 4.0/0.6 by the bot measurement in production/qa/evidence/formation-map/formation-timing.md) | 5.0 |
| `formation_fade_per_cell_sec` | float >= 0 | seconds | Story 029: seconds of fade added per real enemy cell (see above) | 0.8 |
| `formation_fade_warn_ratio` | float 0..1 | share of the fade | Story 029: the HUD blinks a lit cell when its `fraction_left` is below this | 0.25 |
| `formation_flash_sec` | float >= 0 | seconds | Story 029: length of the whole-enemy-half flash when the map completes (`CombatView.get_formation_flash()` runs 1..0 over it) | 0.5 |
| `signature_charge_cells` | removed | - | Story 021 key, REMOVED by Story 029 (the formation map replaces the charge bar); `CombatConfig` no longer reads it, a leftover key is ignored | - |
# Data file schemas

Keys are `snake_case`. Pixel units are reference viewport pixels (1280x720 landscape,
scaled by the `canvas_items` stretch mode). All keys are read by code in `src/`.

## hold_slots.json  (read by `src/hold/hold_slots_config.gd`)

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `slot_count` | integer 3..4 | slots | Number of hold slots; clamped into 3..4 (the boss hand) | 4 |
| `piece_slot_count` | integer 1..6 | slots | Story 024: size of the player's piece bag (`HoldSlots.create_piece_hand`, not subject to the 3..4 clamp); clamped into 1..6 | 3 |
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
| `piece_spawn_interval_sec` | number > 0 | seconds | Story 024, piece mode only (`FieldDrops.enable_pieces`): base time between piece drops (hunger multiplier still applies); replaces `spawn_interval_sec` in that mode | 3.0 |
| `piece_max_on_field` | integer >= 1 | pieces | Story 024, piece mode only: maximum pieces (rotten ones included) lying on the half; replaces `max_on_field` in that mode | 3 |
| `piece_freshness_sec` | number > 0 | seconds | Story 024, piece mode only: life of a piece on the field; held pieces never rot (rotten ones leave the hand after their `rot_in_hand_sec`) | 8.0 |
| `start_pieces` | integer >= 0 | pieces | Story 024, piece mode only: pieces lying on the half when the match starts (`FieldDrops.place_start_pieces`, capped by `piece_max_on_field`) | 1 |
| `odd_blocks` | object | - | Story 041: odd blocks ("Khối Lạ"), see below. Absent or not an object = odd blocks off | absent (off) |

### `odd_blocks` block (Story 041, read by `src/pieces/odd_block_config.gd`, class OddBlockConfig)

Each TICK spawn of either side (never a `start_pieces` piece) is an odd block with probability `chance`; otherwise (and when the generation fails) it is the classic weighted draw. An odd block is a random edge-connected polyomino generated at runtime by `OddBlock.generate`: it is never equivalent under a 90° rotation (no mirroring) to any shape of `pieces.json` (both pools), it fits the TARGET half (the boss's half for the player's drops, the player's half for the boss's) somewhere in some rotation, and its `shape_id` is `odd:` + its canonical key. It follows every rule of a classic piece (bag, rotation, placement, join, cast time, damage per cell, featured shape on the union, imprint, interrupt) but never enters the piece deck (learn / forget / ink / shop) and is never saved. Odd draws use their own RNG (`hash([drops seed, "odd"])`), so with `chance` 0 no extra draw happens and the classic sequences are unchanged.

Size: with `N` = the real cells of the target half (after the arena variant; sand and fallen cells are not subtracted), `max_size = clamp(N / size_divisor + size_add, size_min, size_max)` (integer division). The allowed sizes are `min_cells .. max_size` whose `size_weights` entry is > 0; each try draws one of them by weight. No allowed size = no odd blocks on that half for the match (e.g. `size_max` < `min_cells`). Shipped arenas: 9 cells → 5, 10–11 → 5, 12–15 → 6, 16+ → 7.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `chance` | number 0..1 (clamped) | probability | Chance that one tick spawn is an odd block; 0 = off. Shipped 0.25 (to be tuned by the Story 041 simulation) | 0 |
| `min_cells` | integer >= 1 | cells | Smallest odd block. Below 5 only wastes tries (every 1–4 cell shape is in `pieces.json`), so it warns but is accepted | 5 |
| `size_divisor` | integer >= 1 | cells | Divisor of the target half's cell count in the max size formula | 4 |
| `size_add` | integer | cells | Added after the division | 3 |
| `size_min` | integer >= 1 | cells | Lower clamp of the max size | 4 |
| `size_max` | integer >= `size_min` | cells | Upper clamp of the max size | 7 |
| `size_weights` | object {"size": weight >= 0} | weight | Draw weight per size (negative → 0, missing size = 0). Shipped `{"5": 6, "6": 3, "7": 1}` | `{"5": 6, "6": 3, "7": 1}` |
| `max_tries` | integer >= 1 | tries | Generation tries per spawn; all failing = the classic draw and `FieldDrops.get_odd_fallbacks()` + 1 | 40 |

Match override: a match's `odd_blocks` (same keys) is merged over this block for BOTH sides (a `size_weights` override replaces the whole map), e.g. `"odd_blocks": {"chance": 0}` turns odd blocks off for that match. DEV: the user arg `--odd-chance=X` overrides `chance` for both sides (captures/tests).

## pieces.json  (read by `src/pieces/piece_library.gd`)

Story 024: the puzzle-piece shapes the player drops and places on the enemy half, and their per-chapter drop weights. A missing or invalid file gives a warning and a built-in library with only the `mono` shape. Rotation (0..3 quarter turns clockwise, no mirroring) is not data: the drop draws it at random.

| Key | Type | Meaning | Default if missing |
|---|---|---|---|
| `shapes` | array | The shapes, in drawing order | mono only |
| `shapes[].id` | string | Unique id (`mono`, `bar2`, `bar3`, `l3`, `square`, `t4`, `l4`, `s4`, `bar4`, `plus5`, `u5`, `p5`, `bar5`; run_only: `z4`, `j4`, `y5`); `rotten` is reserved for the rotten piece | - |
| `shapes[].cells` | array of `[x, y]` | UNROTATED cells relative to any origin (normalised on load, y grows downward); 1..5 distinct cells, edge-connected; an invalid shape is dropped with a warning | - |
| `shapes[].name_key` | string | `TEXT_*`-style translation key of the name (the strings live in `assets/i18n/strings.csv`) | `piece.<id>.name` |
| `shapes[].pool` | `"default"` or `"run_only"` | Story 034: `default` shapes are in every run's starting piece deck and drop by `weights`; `run_only` shapes enter the player's deck only through Ink (`PieceDeck`), have NO entry in `weights` (`PieceLibrary.weight` returns 0 for them: the boss and runless matches never draw them) and, once owned, drop with `rewards.json` `piece_rewards.run_only_weight` x mult. An unknown value falls back to `default` with a warning (`PieceLibrary.pool / is_run_only / base_shape_ids / run_only_ids`) | `default` |
| `weights` | object | Drop weights: `{ "default": {<shape id>: weight}, "<chapter id>": {<shape id>: weight} }`; chapter ids are those of `chapters.json` (`ch1`, `ch2`, `ch3`) | - |
| `weights.<map>.<shape id>` | number >= 0 | Relative chance of the shape being drawn; 0 = never. A chapter's map wins, else `default`, else 1.0 for a shape listed in neither. Shapes with no placement on the match's enemy half are skipped regardless of weight | 1.0 |

Current balance intent: chapter 1 favours 1-3 cell shapes (5-cell shapes rare, `bar5` 0.5 of 100), chapters 2-3 progressively more large shapes. Numbers are a starting point for tuning.

Story 034 shapes (cells UNROTATED, x right, y down; no mirroring exists, so a mirror image is a separate shape): `z4` = `[[0,0],[1,0],[1,1],[2,1]]` (mirror of `s4`), `j4` = `[[1,0],[1,1],[1,2],[0,2]]` (mirror of `l4`), `y5` = `[[0,1],[1,1],[2,1],[3,1],[1,0]]` (a bar of 4 with one bump). All three are `pool: "run_only"`.

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
| `pinned_damage_mult` | number >= 0 | x | Ghim: damage/push hits on a pinned unit are multiplied by this. Story 023: Ghim is control only, so this is 1.0 (code path kept) | 1.0 |
| `burn_stack_extend_sec` | number | seconds | Dot: added to the remaining time when a burning cell is re-ignited | 2.0 |
| `burn_stack_tick_bonus` | number | damage | Dot: extra damage per tick per extra stack | 1.0 |
| `burn_max_stacks` | int | stacks | Dot: stack cap (>= 1) | 3 |
| `fragile_mult` | number >= 1 | x | Story 023 Ran (fragile): a damage/push hit on a unit with Ran stacks is multiplied by this and spends 1 stack. Order: card x conditions -> Ghim -> Ran -> execute -> passive -> signature -> defense | 1.5 |
| `fragile_max_stacks` | int >= 1 | stacks | Ran stack cap per unit | 3 |
| `frost_stacks_to_burst` | int >= 1 | stacks | Story 023 Han (frost): reaching this many stacks bursts (stacks cleared) | 3 |
| `frost_burst_damage` | number >= 0 | HP | Damage of a Han burst; ignores flat defense and Ran | 24 |
| `execute_ratio` | number 0..1 | share of max HP | Default threshold of cards with `execute: true`: damage x2 when the target's HP <= ratio x max HP (after Ran, before the passive) | 0.25 |
| `max_pieces_per_cast` | int 1..3 | pieces | Story 028: most pieces one cast may join on the boss's half (clamped) | 2 |
| `max_cast_cells` | int >= 0 | cells | Story 028 fallback lock: a joined piece that would push the cast's total cells above this is refused; 0 = off | 0 |
| `zones` | object | - | Story 027 zone numbers (Tran gai thorns; `seal_sec` is now the drop-tile hole time, the player seal cards were removed 2026-11-01), keys below (validated together in `CombatConfig._parse_zones`: one invalid -> all four fall back with a warning). A card overrides them per card (see cards.json `thorn_sec`, `thorn_damage`, `thorn_fragile_stacks`) | defaults below |
| `zones.seal_sec` | number > 0 | s | Drop tile (boss `seal_caster`): how long a fallen cell stays an open hole (cannot be entered). The player seal zone (Ket gioi) that used it was removed 2026-11-01 (ADR-0001 Phase 1); the key name is kept | 1.2 |
| `zones.thorn_sec` | number > 0 | s | How long a thorn cell lasts | 3.0 |
| `zones.thorn_damage` | number >= 0 | HP | Damage each time a unit CHANGES cell into a thorn cell (walk, push, teleport); standing in it when it forms does not trigger | 6 |
| `zones.thorn_fragile_stacks` | int >= 0 | stacks | Ran stacks added per entry into a thorn cell | 1 |
| `zones.hole_warn_sec` | number > 0 | s | Drop tile (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md, boss trait `seal_caster` only): how long a chosen cell cracks before it falls. During the crack the cell can still be entered and left; the crack deepens like a boss telegraph (red fill, no text). Validated on its own (`CombatConfig._parse_holes`). Range 0.6-1.2 | 0.8 |
| `zones.hole_reaction_margin_sec` | number, 0..`hole_warn_sec` | s | Drop tile: reaction share taken off the warning when judging whether the player can step off in time. The player's own cell may be chosen only when the step cooldown left <= `hole_warn_sec` - this (0.6 s shipped) and the player is neither Frozen nor rooted. Range 0.1-0.3 | 0.2 |
| `zones.hole_fall_lethal` | bool | - | Drop tile: true = a unit standing on a cell when it falls drops to HP 0 (for the player: the match is lost, the run ends). false = it is pushed to an open neighbour and loses `hazards.fall_damage` like a Sky Isles crumble (no landing cell = that cell does not fall) | true |
| `zones.hole_return_fade_sec` | number >= 0 | s | Drop tile, presentation only: after the hole closes (`zones.seal_sec` = how long the hole stays open, cannot be entered) the cell fades back in from white over this long. The cell can be stepped on as soon as the hole closes. 0 = no fade | 0.3 |
| `telegraph` | object | - | Story 046 Part C: the boss's red telegraph tiles on the player's half fade in with the swing's progress k = 1 - time_left / windup (no countdown label; full strength exactly when the hit lands; art bible 4, hud.md E-17). Keys below, validated together in `CombatConfig._parse_telegraph` (one invalid -> all fall back with a warning) | defaults below |
| `telegraph.fill` | [from, to], each 0..1 | alpha | Flat red #E5293B fill alpha at k = 0 and k = 1 (lerped) | [0.0, 0.45] |
| `telegraph.stripe` | [from, to], each 0..1 | alpha | 45-degree stripe texture (`fx_telegraph_stripe_8.png`) alpha at k = 0 and k = 1 | [0.5, 1.0] |
| `telegraph.edge` | [from, to], each 0..1 | alpha | 2 px red edge + 1 px Ink outer edge alpha at k = 0 and k = 1 | [0.3, 1.0] |
| `telegraph.queued_stripe_alpha` | number 0..1 | alpha | Stripe alpha of a QUEUED boss combo swing (Story 013), drawn at k = 0 with no fill | 0.35 |
| `telegraph.reduce_motion_steps` | array of >= 2 numbers 0..1, non-decreasing | k | With reduce motion on, k snaps to these levels (n levels: level i covers [i/n, (i+1)/n)) | [0.0, 0.5, 1.0] |
| `hud` | object | - | Story 046 Part B: timing of the sharp Z1 header (`CombatView._draw_hud`, art bible 7.5). Parsed in `CombatConfig._parse_hud`; an invalid value falls back with a warning | defaults below |
| `hud.hp_trail_sec` | number >= 0 | seconds | The #B8B0A0 damage trail behind an HP fill shrinks linearly to the new HP over this time (0 = no trail) | 0.4 |
| `burn_on_entry` | bool | - | 2026-10-31 (user: crossing a burning row did nothing): stepping onto a burning cell costs one tick of its damage at once and restarts that cell's tick clock (StatusEffects.burn_on_entry) | true |
| `hud.step_rings` | bool | - | 2026-10-31 (user): `false` hides the step-cooldown ring around the player and the boss after a step; the boss's solid "rooted by its swing" ring is not affected | false |
| `hud.corner_panels` | bool | - | 2026-10-31 (user): `false` hides the HP panels in the top corners during a battle; each unit shows its HP number (number only, no bar) on a plate under its feet and the boss's held points float in the top-right corner. `true` draws the corner panels (name, HP bar, Engraving / boss number) | false |
| `timing.beat_sec` | number > 0 | seconds | ADR-0001 A6: seconds in one design-pack "beat"; anything authored in beats converts through `CombatConfig.beats_to_sec()` (never a hard-coded 0.5). <= 0 / non-number keeps the default (warning) | 0.5 |
| `timing.delivery` | object | seconds | ADR-0001 A1: per delivery type (keys `CASTER_TO_TARGET`, `SKY_TO_TARGET`, `GROUND_PROPAGATION`, `DIRECT_MANIFESTATION`, `SEQUENTIAL_CHAIN`) the numbers of its per-cell arrival rule (`SkillDelivery.arrival_times`, seconds after the swing resolves; presentation only: damage still lands on the mask at the resolve). `CASTER_TO_TARGET.spread_step_sec` / `first_hold_sec` (first cell at 0, breadth-first spread; the sword wave), `SKY_TO_TARGET.fall_sec` / `stagger_sec` (fall + row-major index x stagger), `GROUND_PROPAGATION.step_sec` (Manhattan distance from the origin cell x step), `DIRECT_MANIFESTATION.appear_sec` (all at once), `SEQUENTIAL_CHAIN.step_sec` (k-th link at k x step). Unknown keys / negative values are ignored with a warning | 0.08 / 0.13, 0.12 / 0.03, 0.06, 0.0, 0.1 |

All five Story 023 keys are validated together in `CombatConfig._parse_keywords` (one invalid -> all five fall back) and passed to `StatusEffects.configure_keywords` by `configure_status`.
| `player_step_cooldown_sec` | number >= 0 | seconds | DEPRECATED, not shipped: if present it overrides the computed value on every board (warning) | absent |

Measured (defaults): 2x2 = 0.60 (clamped), 3x3 = 0.45, 4x3 = 0.33, 6x6 = 0.23, 10x10 = 0.18 (clamped).

## cuts.json  (read by `src/combat/cut_config.gd`)

Cut numbers (Story 008). A missing or invalid file gives the defaults below with a warning.

**Covered cells** (Story 026: runes and the perimeter cut are retired; no code uses perimeter labels): a cast covers exactly the board cells of the piece(s) placed for it on the TARGET half (`CastPlan`, 1..`max_pieces_per_cast` pieces, optional `max_cast_cells` cap in combat.json). Missing board cells never count.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `base_damage_per_cell` | number >= 0 | HP | Slash damage per covered real cell | 6 |
| `swing_base_sec` | number >= 0 | seconds | Fixed part of the swing windup | 0.2 |
| `swing_per_cell_sec` | number >= 0 | seconds | Windup added per covered real cell (windup = base + per_cell * cells) | 0.25 |
| `place_window_sec` | number 0.5..10 (tuning range 1.5..6) | REAL seconds | Quick spec menu-la-giua-man-hinh-2026-11-01: time from the FIRST piece dropped on the enemy half until Tung phép is pressed automatically. Before that the player may join a 2nd piece (3rd with tam_hop) and press Tung phép; the card menu opens only on that press. The bar sits above the Tung phép / Awaken buttons. Scaled by the "Thời gian chọn lá" setting like the card menu (6 s = x2, không giới hạn = no auto press) | 3.0 |

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

Card entry keys (20 cards, see `card_order`; the class concept is gone, Story 020; `effect` names stay behaviours):

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `name_key` | string | i18n key | Player-facing name: `card.<id>.name`, looked up with `tr()` in `assets/i18n/strings.csv` | `card.<id>.name` |
| `desc_key` | string | i18n key | One-line description: `card.<id>.desc` | `card.<id>.desc` |
| `min_cells` | integer >= 1 | cells | Covered real cells needed to use the skill (menu shows "need N cells") | 1 |
| `cooldown_sec` | number >= 0 | seconds | Cooldown started when the skill is used | 0 |
| `damage_per_cell` | number >= 0 | HP per cell | Level-1 damage per covered cell of damage/push cards (0 for burn/pin); damage = `damage_per_cell * cells`. Replaces `damage_multiplier` (Story 020). Missing: cuts.json `base_damage_per_cell` | cuts.json base |
| `push_cells` | integer >= 0 | cells | Cells the target is pushed away from the divider along its row (stops at a missing cell/edge); push only | 0 |
| `effect` | `damage` / `push` / `burn` / `pin` / `fragile` / `frost` / `thorns` | - | What the swing does on resolve (Story 010). Story 023: `fragile` / `frost` apply the card's `fragile_stacks` / `frost_stacks` to the target when it stands in the covered cells (no direct damage). `burn`: every covered cell ignites whether or not the target stands there; burning cells take no new field points and refuse pick-up. `pin`: pins the target if it stands in the covered cells. Story 027 `thorns`: form a Tran gai zone over the covered cells on the target half, hit or miss (see `thorn_sec` .. `thorn_fragile_stacks` below). Effect `seal` (Ket gioi) was removed 2026-11-01 (ADR-0001 Phase 1) | `damage` |
| `burn_duration_sec` | number >= 0 | seconds | Burn only: how long ignited cells burn; re-igniting resets the timer | 0 |
| `burn_tick_sec` | number > 0 | seconds | Burn only: interval of damage to a unit standing on a burning cell (<= 0 uses 0.5 with a warning) | 0.5 |
| `burn_damage_per_tick` | number >= 0 | HP | Burn only: damage per tick, per unit standing on the cell | 0 |
| `pin_duration_sec` | number >= 0 | seconds | Pin only: how long the target cannot step; re-pinning refreshes it | 0 |
| `rarity` | `common` / `rare` / `epic` / `curse` | - | Card rarity (unknown -> common with a warning). Story 033 `curse` (ganh_nang, oan_hon): the card takes one of the 4 card-menu slots and is shown locked (purple border, cannot be chosen: `SkillAvailability` reason `curse`); never levels, has no `upgrade`, is never in `card_order` (so never in a reward / shop pool or the boss deck), and does not count toward `min_deck_size`. `SkillConfig.is_curse(id)`; `Deck.draw_menu` keeps >= 1 non-curse card in the menu while the deck holds one. Story 023 curve: rarity buys conditions, not damage per cell (commons 6-7, rares 7-8, epics 8 + a condition) | `common` |
| `draw_damage` | number >= 0 | HP | Story 033, `curse` cards only: HP the player loses each time this card is drawn into the card menu (`CombatView`, via `CombatState.damage_player`). oan_hon: 2 | 0 |
| `fragile_stacks` | int >= 0 | stacks | Story 023: Ran stacks applied to the target on a hit (any effect) | 0 |
| `frost_stacks` | int >= 0 | stacks | Story 023: Han stacks applied to the target on a hit (any effect) | 0 |
| `pierce_defense` | bool | - | Story 023: the card's damage/push hit skips the match's `boss_defense` | false |
| `execute` | bool | - | Story 023: damage x2 when the target's HP <= combat.json `execute_ratio` x max HP | false |
| `execute_ratio` | number 0..1 | share | Card-level execute threshold overriding combat.json (0 = use `execute`) | 0 |
| `seal_sec` | - | - | Removed 2026-11-01 (ADR-0001 Phase 1) with effect `seal` and the Wall cards (Ket gioi / Long an / Luoi san); no card reads it | - |
| `thorn_sec` | number >= 0 | s | Story 027, effect `thorns` only: this card's thorn duration (overrides `zones.thorn_sec`). Effect `thorns` (Tran gai) covers the cut cells on the target's half, hit or miss; thorns are never reduced by the leave-a-path rule | combat.json |
| `thorn_damage` | number >= 0 | HP | Story 027: damage per entry into one of this card's thorn cells (overrides `zones.thorn_damage`) | combat.json |
| `thorn_fragile_stacks` | int >= 0 | stacks | Story 027: Ran stacks per entry into one of this card's thorn cells (overrides `zones.thorn_fragile_stacks`; Gai nguyen = 2) | combat.json |
| `bonus_vs_fragile_mult` | number >= 1 | x | Story 023: damage multiplier while the target has Ran stacks, applied BEFORE the Ran stack is spent (song_kiem) | 1 |
| `upgrade` | object key -> number | additive delta | Per level above 1 (level 2 = one application, level 3 = two): keys `damage_per_cell`, `min_cells` (never below 1), `cooldown_sec` (never below 0), `burn_damage_per_tick`, `burn_duration_sec`, `pin_duration_sec`, `push_cells`, `fragile_stacks`, `frost_stacks`. Read through `SkillConfig.resolved(id, level)` | `{}` (warning) |
| `implemented` | boolean | - | False = shown locked ("not yet"); using it falls back to slash | false |
| `player_pool` | boolean | - | Quick spec o-rot-thay-tuong 2026-10-31: false = the player can never get the card (not in `card_order`, reward / shop / event pools, `default_deck`, starter decks; `SkillConfig.is_player_card`). The Wall cards `ket_gioi`, `long_an`, `luoi_san` that used it were removed 2026-11-01 (ADR-0001 Phase 1) | true |
| `delivery` | object | - | ADR-0001 D7 / A1 (pack `01` §1A, `06` `Delivery`): how the cast is SHOWN; required on every card (curses and `player_pool: false` cards included; the boss reuses cards through `boss_cards`, so this also covers boss attacks). Parsed by `SkillDelivery.parse` into `SkillConfig.cards[id].delivery`; CutEffects never reads it. Keys: `type` (`CASTER_TO_TARGET` / `SKY_TO_TARGET` / `GROUND_PROPAGATION` / `DIRECT_MANIFESTATION` / `SEQUENTIAL_CHAIN`), `origin` (allowed per type, first = default: CASTER `caster`; SKY `sky`; GROUND `origin_cell` (the caster's cell) or `first_cell`; DIRECT `target_cells`; CHAIN `first_cell` or `caster`), `travel` (square-based visual id: `hero_pack` (the hero's cast pack, `assets/art/vfx/cast/index.json`), `square_streak`, `falling_squares`, `floor_run`, `chain_spark`, `none`; DIRECT must be `none`; never the gameplay Block), `impact` (`slash`, `burst`, `shatter`, `burn`, `freeze`, `poison`, `knockback`, `guard`, `seal`, `thorns`, `curse`, `none`; mapped to FloorVfx packs by the cast index `impact_packs`), `cell_mask` (only `block_shape`: the cells of the placed shape are the ONLY cells that take damage or status), `chain_order` (SEQUENTIAL_CHAIN only: `nearest_first` (default; Manhattan from the origin, ties row-major), `row_major`, `authored` (the cut's cell order)), optional `path_rule` `{effect: damage / status, telegraphed: true}` (the travel cells may be affected ONLY with `telegraphed: true` on a CASTER / GROUND / CHAIN delivery; anything else is dropped with a warning; no shipped card uses one and the swing telegraph does not draw path cells yet). Missing / bad data: warning, per-key fallback; a missing object falls back to DIRECT_MANIFESTATION (never SKY by default) | DIRECT_MANIFESTATION / burst (flagged) |

## boss_brain.json  (read by `src/combat/boss_brain_config.gd`)

Boss brain timing and named weight sets (Story 009). The brain scores every ordered selection of 1..4 held points (up to 64) as a cut, the 4 step directions as moves, and waiting; the best score wins. A missing or invalid file gives the built-in `balanced` set with a warning; weights are clamped to >= 0.

| Key | Type | Unit | Meaning | Default if missing |
|---|---|---|---|---|
| `step_cooldown_sec` | number >= 0 | seconds | Boss wait after an accepted step (used by the controller to build the boss `UnitMover`); fallback only: a match's `boss_step_cooldown_mult` overrides it | 0.55 |
| `think_interval_sec` | number >= 0 | seconds | Time between brain evaluations; `decide` returns wait in between | 0.3 |
| `reaction_sec` | number >= 0 | seconds | How long the player's swing must have been visible before the brain reacts to it (dodge, interrupt, pickup danger). DEFAULT only: a set's `movement.reaction_sec` wins when present (Story 013) | 0.35 |
| `noise` | number >= 0 | score | Amplitude of the uniform seeded noise added to every CUT candidate score (movement uses the set's `movement.move_noise`) | 0.15 |
| `max_placements_scored` | integer >= 1 | placements | Story 025 (piece mode): every (piece, rotation, anchor) placement on the player's half is pre-ranked cheaply (covers the player's cell first, then reachable-escape cells covered); only the top N get the full score each think | 40 |
| `pair_seed_placements` | integer >= 1 | placements | Story 025 (piece mode): the best N single placements (by the same cheap pre-ranking) are paired across DIFFERENT held pieces (non-overlapping cells) into two-piece cast candidates; only used when the cast may join >= 2 pieces (`combat.json` `max_pieces_per_cast`). Pairs are scored as one cast | 12 |
| `root_while_swinging` | bool | - | Story 025: true = the boss's `UnitMover` refuses to step while its `CutActor` swings (a queued combo swing counts), so the player gets a counter window; interrupt / feint-cancel / resolve unlock at once. A match may override it with `boss_root_while_swinging` (bool) in `chapters.json` | true |
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
| `thorn_avoid` | number >= 0 | score per HP | Story 027: cost of stepping INTO a thorn cell of the boss's half = `thorn_avoid` x that cell's thorn damage. Paths count 1 per step plus this cost (a thorn is walked around while the detour is cheaper); a non-dodge step into a thorn adds `-cost` to the move score (`thorn` in the debug breakdown); a dodge picks the cell with the lowest thorn cost + (incoming swing's slash damage if it would arrive late), so the boss steps through thorns when the swing hurts more and goes around / stays when the thorns cost more (`dodge_plan` in last_debug). Sealed cells are never entered (like burning). Shipped: balanced 1.0, aggressive 0.5, cautious 1.5 | 1.0 |
| `mire_avoid` | number >= 0 | score per mire unit | Story 036: cost of stepping INTO a mire cell of the boss's half = `mire_avoid` x (`mire_step_mult` - 1 + `mire_tick_damage`) (hazards block of combat.json / match overrides); 0 when the match boss is `mire_immune`. Added to path costs like `thorn_avoid` (mire is walked around while the detour is cheaper; a dodge goes through when the swing hurts more); a non-dodge step into mire adds `-cost` to the move score (`mire` in the debug breakdown). With hazards set, sand cells (filled and warning) are blocked cells for paths and steps, and with wind on a field piece that drifts before the boss reaches it is scored at its drift cell; components in `last_debug().hazards`. Shipped: balanced 1.0, aggressive 0.5, cautious 1.5 | 1.0 |
| `crumble_avoid` | number >= 0 | score per HP | Story 039: cost of staying on one cell of a `crumble` arena (hazards `crumbles_side(ENEMY)`; since 2026-11-01 only the player's half crumbles, so this weight is inert in play and kept for a future boss-half crumble): `crumble_avoid` x `fall_damage` x f, where f (0..1) is the larger of `TileHazards.crumble_progress` of the boss's cell and the brain's own standing time on it / `crumble_after_sec`. The cost is taken off the wait score, and once the time left before the crack (1 - f) x `crumble_after_sec` is at most two boss steps + one think the boss relocates (purpose `crumble`, cheapest zone cost then fewest steps, no RNG) unless it has a better move or a cut scoring higher; 0 = the boss ignores the timer. Independent of the weight, fallen cells and cells in their crack warning are blocked cells (paths, steps, escape cells of both halves), and a vent that is warning or erupting is a blocked cell like a burning cell (vents never block when idle). Components in `last_debug().hazards`: `vent_blocked`, `crumble_blocked`, `crumble` {avoid, on, after_sec, stand_sec, fraction, cost, leave}. Shipped: balanced 1.0, aggressive 0.5, cautious 1.5 | 1.0 |
| `escape_penalty` | number >= 0 | score | Story 013 escape-route scoring: added as `escape_penalty / (1 + escape_cells)`, where `escape_cells` = cells the player can reach within `EscapeAnalysis.steps_for_swing(windup, player step cooldown)` 4-way steps on the player's half (burning cells excluded) that the cut does NOT cover. 0 escape cells = the full bonus (balanced 4.0, aggressive 5.0, cautious 3.0) | 4.0 |
| `min_runes_penalty` | number >= 0 | score | Story 023: with a match `boss_min_runes` N > 0, a candidate cut of fewer than N cells loses this per missing cell, and is skipped altogether while any candidate of >= N cells exists (`BossBrain._best_cut`) | 3.0 |
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
| `single_point_bonus` | number >= 0 | score | Flat bonus added to 1-point cut candidates once the interrupt threshold is reached (piece mode: to pieces of 1 cell) | 2.0 |
| `feint_max_cells` | integer >= 0 | cells | Story 025 (piece mode): a cut whose piece has at most this many cells may become a feint (the classic label path keeps the one-point rule) | 2 |

## `chapters.json` (Stories 011, 015; v2 in Story 022)

**v2 (Story 022)** — a chapter is a seeded MAP of 7 columns of nodes, generated by `ChapterMapGen.generate(spec, run_seed, cleared_bosses)` from `defaults.columns` and the chapter's `pools`; see "Chapter map v2" below. `GameFlow` plays one node per `RunConfig.from_node`. Story 026 removed the v1 floor API (`resolved_floor`, `floor_count`, `next_floor`, ...), `RunConfig.from_floor` and `legacy_floors`.

Chapters -> matches, read by `ChaptersConfig` (`src/run/chapters_config.gd`). A bad or missing file gives one default chapter / match (warning). A chapter without matches is dropped (warning); ids must be unique per level (a duplicate is dropped with a warning). The match numbers below are PLACEHOLDERS for the later balance pass. `RunConfig.load_from_file` still reads the flat format (used by tests): the keys of `defaults` plus `matches` at the root.

Top level: `{ "defaults": {...}, "chapters": [...] }`.

`defaults` (all optional; also accepted as per-floor overrides on a floor):

| Key | Type | Unit | Meaning | Default |
|---|---|---|---|---|
| `heal_between_matches` | number >= 0 | HP | Story 022: shipped 0 (HP heals only at `rest` nodes and from cards); legacy meaning: Flat HP the player recovers after winning a non-final match (result clamped to max HP); HP does not carry across floors |  0 |
| `intro_sec` | number >= 0 | seconds (real) | Length of each match intro (battle drawn but frozen) | 1.5 |
| `end_delay_sec` | number >= 0 | seconds (real) | Pause after the last hit before leaving the match | 1.5 |
| `between_sec` | number >= 0 | seconds (real) | Auto-advance of the between-matches screen; 0 = wait for the button only | 3.0 |
| `heal_between_floors` | number >= 0 | HP | Story 022: shipped 0 (reserved for `rest`); legacy meaning: Story 019: HP recovered after a floor's boss (clamped to max HP; HP is never refilled on a new floor) |  0 |
| `revive_tokens` | integer >= 0 | count | Story 019: revives a run starts with (reserved for the future revive item, unused) | 0 |
| `retry_min_hp_ratio` | number 0..1 | ratio of max HP | OPTIONAL, legacy (Story 015): `RunState.retry_match` / `resume_at` start with max(HP at match start, this x max HP). Not shipped; the Story 019 run flow passes 0 (no minimum) | 0 |

### Chapter map v2 (Story 022, `ChapterMapGen` + `ChaptersConfig.get_map_spec / generate_map / get_match_def`)

`defaults` also carries the map skeleton (all optional; built-in fallback = the same 7 columns):

| Key | Type | Meaning | Default |
|---|---|---|---|
| `columns` | array of column specs | One entry per column, in order. Column spec: `tier` (0..2, the pool tier, OSFE `CalculateStageNum`: col 0 -> 0, cols 1-2 -> 1, cols >= 3 -> 2), `kinds` (filler node kinds drawn at random; siblings differ in kind while unused kinds remain), `pick` (`[min, max]` node count of the column, seeded), `required` (kinds that appear exactly once; an inner array is a set of alternatives, one drawn 50/50). Shipped: col 0 one `battle`; cols 1-2 2-3 of battle/danger/treasure; col 3 `miniboss` + 1-2 battle/danger; col 4 `rest` + (treasure or battle) + optional third; col 5 2-3 battle/danger; col 6 one `boss` | 7 columns as described |
| `onboarding_tier_cap` | integer >= 0 | Every column tier is clamped to this while the save has `cleared_bosses == 0` (hidden onboarding) | 1 |
| `danger_traits` | array of `{id, params}` | Traits `RunConfig.from_node` adds to the match of a `danger` node (ids the match already has are not doubled) | `[row_burner]` |

Node kinds: `battle`, `danger`, `treasure` (free card, no fight), `rest`, `miniboss`, `boss`. A generated map is `[{index, tier, nodes: [{kind, match_id}]}]`; `match_id` is empty for treasure / rest. Same (chapter, `run_seed`, `cleared_bosses`) -> identical map. No match id repeats within a map unless its pool is exhausted; a kind's node draws from its own pool at the column tier, falling back to the nearest lower tier, then any tier of that kind (never from another kind's pool, so bosses are not spent on battle nodes).

Each v2 `chapters` entry: `id`, `name_key`, and:

| Key | Type | Meaning |
|---|---|---|
| `matches` | object match id -> match block | Every match of the chapter (the same block as a floor `matches[]` entry below, `id` implied by the key, each with its own `arena`) |
| `pools` | object kind -> object tier (`"0"`, `"1"`, `"2"`) -> array of match ids | Draw pools per node kind and tier; ids missing from `matches` are dropped with a warning. `miniboss` and `boss` have their own lists; the `boss` pool of the last tier must hold the chapter boss |
| `columns` | array | Optional per-chapter override of `defaults.columns` |

Per-chapter optional keys (Story 023): `intro_key` / `end_key` (`chapter.<id>.intro` / `chapter.<id>.end`, one line each in the CSV, shown by the run UI at chapter start / after the chapter boss), per-match `desc_key` (`match.<id>.desc`, one-line hint shown in the match intro for rule-breaker enemies and chapter bosses), `boss_defense` (number >= 0, flat armor subtracted per hit after Ghim/innate, min 1; Đốt and `pierce_defense` cards ignore it; default 0) and `boss_min_runes` (integer >= 0, the boss prefers pieces of at least this many cells; rune-era key name kept; default 0). Escalation (OSFE §5): normal enemies HP x1.15 per chapter, `boss_step_cooldown_mult` -0.1 per chapter, `boss_defense` 0 / 2 / 4 for normals in ch1 / ch2 / ch3 (ghosts 12 / 16), `boss_min_runes` 2 for elites (reacter, jailer, fuse_golem, frost_mage) and 3 for the ch2 / ch3 bosses. Think / reaction never below 0.3 / 0.35 s.

A chapter with the v1 `floors` key still loads: its floor matches become `matches` / `match_ids`, pools stay empty and every kind falls back to the whole match list.

`RunConfig.from_node(chapters, chapter_index_or_region, match_id, node_kind, run_seed, floor = -1)` builds the single-match run of one node: the match's own `arena`, `arena_seed = hash([run_seed, match_id])`, the chapter `defaults` for timings. The second argument is a chapter index (int) or a region id (String). With `floor >= 0` (Story 031) the match is scaled at this ONE point — see "World v6" below; `floor < 0` = no scaling (old behaviour).

### World v6 (Story 031, `world` block, `ChaptersConfig.world_spec / region_spec / floor_scaling / generate_region_map`, `WorldMapGen`)

A run is 5 floors then a final match; each floor offers 2 regions and the player picks one. A **region** is a `chapters` entry (keys unchanged: `ch1` Rừng Sương, `ch2` Hầm Ngục, `ch3` Tháp Sương); new code calls them regions (`region_id`), never `zone` (that word is the seals / thorns of Story 027). Every `floor` in the code API is the 0-based run floor (0..4; 5 = the final match); data rows are keyed by the 1-based floor number. A missing / bad `world` block gives the built-in values below with a warning (`DEFAULT_*` fallbacks only).

| Key (`world.`) | Type | Meaning | Shipped (starting values) | Fallback |
|---|---|---|---|---|
| `floors` | integer >= 1 | Floors before the final match | 5 | 5 |
| `choices_per_floor` | integer >= 1 | Regions offered per floor (`WorldMapGen.offer_for_floor`; fewer when the pool is smaller) | 2 | 2 |
| `region_pool` | array of chapter ids | Regions a floor may offer; unknown ids dropped (warning); empty = every chapter | `["ch1","ch2","ch3"]` | every chapter |
| `region_columns` | array of column specs (same shape as `defaults.columns`) | Frame of one region map. A `kinds` / `required` entry may be `{"kind": <kind>, "min_floor": <1-based floor>}`: the kind is left out on earlier floors. Shipped: col 0 one `battle`; col 1 2-3 nodes = exactly one of `rest` / `treasure` (50/50 seeded) + `battle` / `danger` / `miniboss` (miniboss `min_floor` 2); col 2 one `boss` from the region's `boss` pool. To lengthen a run, add a column here (data, no code). A chapter may carry its own `region_columns` override | 3 columns as described | same 3 columns |
| `floor_scaling` | object `"1".."5"`, `"final"` -> `{hp_mult, step_mult, defense_add, size_add}` | Floor difficulty (the four Story 023 axes): `boss_max_hp` x `hp_mult` (> 0), `boss_step_cooldown_mult` x `step_mult` (> 0; < 1 = faster), `boss_defense` + `defense_add`, `boss_min_runes` (the boss's smallest piece in cells, Story 023/025) + `size_add`. `final` is the final match; a missing `final` uses the last floor's row; a missing row = no change | 1: 1.00/1.00/0/0 · 2: 1.15/0.95/0/0 · 3: 1.30/0.90/1/0 · 4: 1.50/0.85/1/1 · 5: 1.70/0.80/2/1 · final: 1.90/0.80/2/1 | no scaling |
| `floor_tiers` | object `"1".."5"` -> `[first, middle, boss]` | Pool tiers of a region map on that floor: the first column, every middle column, the last (boss) column (a 2-entry list reuses the middle tier for the boss). `onboarding_tier_cap` still clamps every tier while the save has beaten no boss | 1-2: `[0,1,1]` · 3-5: `[1,2,2]` | the column's own `tier` |
| `floor_heal_ratio` | number 0..1 | Share of max HP healed when a region boss falls (clamped to max HP by the run) | 0.25 | 0.25 |
| `final_match` | `{region, match_id}` | The final match (Ấn Đài placeholder until Story 035); unknown region / match = ignored (warning) | `{"region": "ch3", "match_id": "mist_lord"}` | none |

Per chapter (= region), optional:

| Key | Type | Meaning | Shipped | Default |
|---|---|---|---|---|
| `region_normalize` | `{hp_mult > 0, step_mult > 0, defense_add}` | Cancels the chapter difficulty baked into the region's matches so the three regions are equally hard on the same floor; applied BEFORE `floor_scaling` | ch1 1/1/0 · ch2 0.85/1.05/0 · ch3 0.75/1.10/-1 | 1/1/0 |
| `region_columns` | array of column specs | Per-region override of `world.region_columns` | - | - |

Order of application in `RunConfig.from_node(..., floor >= 0)` (the only place; stored match data is never changed): `hp = boss_max_hp x normalize.hp_mult x row.hp_mult`; `step = boss_step_cooldown_mult x normalize.step_mult x row.step_mult` (a deprecated `boss_step_cooldown_sec` is scaled the same way); `defense = max(max(boss_defense + normalize.defense_add, 0) + row.defense_add, 0)`; `boss_min_runes = max(boss_min_runes + row.size_add, 0)`. Missing match keys count as the match defaults.

Seeds: the floor offer draws ties with `hash([run_seed, floor, chosen_path])`; a region map is `ChapterMapGen.generate(region_spec(region_id, floor), WorldMapGen.region_map_seed(run_seed, region_id, floor) = hash([run_seed, region_id, floor]), cleared_bosses)`, so the same region on another floor gives another map. Offer rules, in order: unvisited regions first, then the least visited, then avoid the previous floor's region while another is left, then the seeded draw.

**Shop and event nodes** (Story 033, `world.special_nodes`, `ChaptersConfig.special_nodes / shop_floors`, `ChapterMapGen._apply_special_nodes`, `WorldMapGen.shop_floors`). Kinds `shop` and `event` have no match (`match_id` ""). After a region map is built, a separate pass (own rng: `hash([map_seed, region_id, "special"])`, so every other node is the same as without it) may turn ONE optional fight (`battle` / `danger` / `miniboss`) of column `column` into a shop and ONE into an event, so a region has at most 1 of each. A non-guaranteed shop or an event only replaces while 2+ fights are left in that column (one fight is always kept). Run-level rule "at least 2 shops per run on two different floors": the run's SHOP PLAN `WorldMapGen.shop_floors(run_seed, floors, guaranteed_shops, guaranteed_min_floor)` (`hash([run_seed, "shop_floors"])`, distinct 0-based floors) makes the shop certain on those floors whichever region is picked (it may take the column's last fight). Without the block: no shop / event (old maps unchanged; 7-column chapter maps never get them).

| Key | Type | Meaning | Shipped | Default |
|---|---|---|---|---|
| `column` | int >= 1 | 0-based column of the region frame whose fights may be replaced (clamped to the middle columns) | 1 | 1 |
| `shop_weight` | float 0..1 | Chance a region (outside the shop plan) gets a shop | 0.3 | 0 |
| `event_weight` | float 0..1 | Chance a region gets an event (needs 2+ fights left in the column) | 0.6 | 0 |
| `guaranteed_shops` | int >= 0 | Floors per run whose region always has a shop | 2 | 0 |
| `guaranteed_min_floor` | int >= 1 | 1-based first floor the shop plan may use (gold is short before it) | 2 | 1 |

### Match block (and the v1 `floors` format)

A v1 `chapters` entry with `floors` (each `{id, name_key?, matches: [...]}`) still loads: its floor matches become the chapter's `matches` (see above). Floor-level `arena` / `arena_pool` / `arena_variant` are no longer applied (Story 026: the floor API is gone); every match uses its own `arena`.

Each match block (a value of a chapter's `matches`, or a v1 floor `matches[]` entry; `arena_seed` is filled by code, default -1 = random):

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
| `boss_defense` | number >= 0 | HP | Story 023 flat defense (OSFE 9.4): subtracted from every player damage/push hit on the boss AFTER Ran / execute / passive / signature; at least 1 damage lands; skipped by cards with `pierce_defense`; burn ticks and Han bursts ignore it. Applied in `CutEffects.apply` through `SwingArbiter.boss_defense` | 0 |
| `boss_min_runes` | int >= 0 | cells | Story 023: the boss brain prefers cuts of at least this many cells (`min_runes_penalty` per missing cell; smaller cuts are skipped while a big enough one exists). Story 025: the cut is now a PIECE, so this is the minimum CELLS of the piece (key name unchanged so `chapters.json` keeps working). 0 = off | 0 |
| `boss_root_while_swinging` | bool | - | Story 025: per-match override of `root_while_swinging` in `boss_brain.json` (true = the boss cannot step while it swings). Absent = the file's value | file value |
| `odd_blocks` | object | - | Story 041: keys of the `odd_blocks` block of `field_drops.json`, merged over it for both sides of this match (`{"chance": 0}` = no odd blocks in this match). Passed through by `RunConfig.clean_match`; a non-object = warning, ignored | absent (file block) |

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

Story 024: when the player's drops are in piece mode (`FieldDrops.enable_pieces`) the throw is a ROTTEN PIECE instead (`FieldDrops.place_rotten_piece`): a 1-cell grey piece (`FieldPoint.piece.is_rotten()`, `placeable()` false), same cell rules, timers and hand behaviour; `label` is unused in that mode.

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

### Boss traits of Story 023 (all params optional; fallbacks live in each trait's constants)

New hook: `on_player_stepped(from, to)` (after a SUCCESSFUL player step; CombatView.try_step_player). New context keys: `player_mover` (the player's `UnitMover`, with `blocked_cell_fn` and `cooldown_mult`) and `trait_host_ref` (WeakRef of the host; `TraitHost.add_trait(id, params)` adds a trait at runtime, `phase_changed(phase)` signal). `FieldDrops.interval_scale` multiplies the spawn interval; `CutActor.begin_swing(..., duration_override)` fixes a swing's windup.

| Trait | Param | Default | Meaning |
|---|---|---|---|
| `step_reactor` | `charges_to_fire` | 3 | Player steps that load the shot |
| | `warning_sec` | 0.5 | Windup of the fired boss swing (normal swing pipeline: interruptible, dodgeable) |
| | `swing_cells` | 3 | Size of the connected cluster (includes the player's cell) |
| | `cooldown_sec` | 2.0 | After firing no charges are gained for this long |
| | `skill_id` | `kiem_khi` | Card id used for the swing's damage |
| `fuse_cannon` | `fuse_sec` | 12.0 | Fuse length (sim seconds from match start / last blast / reset) |
| | `fuse_damage` | 40.0 | Damage to the player if still in the row at resolve |
| | `interrupt_damage` | 30.0 | A single player hit on the boss of at least this resets the fuse |
| | `row_scope` | `player_row` | `player_row` or `random` |
| | `warn_sec` | 0.6 | Row warning before the blast |
| `slam` | `slam_interval_sec` | 7.0 | Time between slams (also the first delay unless `first_delay_sec`) |
| | `cracked_cells` | 2 | Cells cracked per slam (player half, never the player's cell) |
| | `crack_sec` | 4.0 | How long a cell stays cracked (cannot be stepped onto) |
| | `warning_sec` | 0.8 | Warning before the cells crack |
| | `slam_damage` | 20.0 | Damage to the player if standing on a cell when it cracks |
| `frost_aura` | `rune_rate_mult` | 0.8 | Player field-piece drop rate multiplier (spawn interval x 1/mult; rune-era key name kept so chapters.json keeps working) |
| | `until_hp_ratio` | 0.5 | Active while boss HP ratio is above this; off for good at or below |
| `phase_shift` | `at_hp_ratio` | 0.5 | Boss HP ratio that starts phase 2 (once) |
| | `brain_set` | `aggressive` | Weight set the brain switches to |
| | `extra_traits` | `[{"id":"row_burner","params":{}}]` | Traits added to the host at phase 2 |
| | `step_mult` | 0.85 | Multiplies the boss's step cooldown |
| `seal_caster` | `interval_sec` | 8.0 | Story 027, drop tile since 2026-10-31 (Ô rớt: the chosen cells crack for `zones.hole_warn_sec`, then fall and stay a hole for `seal_sec`; a unit on a falling cell drops to HP 0 unless `zones.hole_fall_lethal` is false): seconds between drop tiles (armed again after each) |
| | `first_delay_sec` | = interval | Seconds before the first arming |
| | `cells_min` / `cells_max` | 2 / 3 | Seeded cell count of one seal (player half, escape cells of the swing: reachable within `escape_steps`, not covered, plus the player's own cell under `may_target_player_cell`; at least one escape cell is always left, then ZoneRules.cast_drop applies the fairness rule: a steppable, non-cracking, non-hole neighbour stays open, none = no cast) |
| | `lead_sec` | 0.6 | The seal forms when an armed qualifying boss swing has this long left (at once for a shorter swing) |
| | `min_swing_cells` | 3 | Smallest boss swing that carries a seal |
| | `escape_steps` | 2 | Steps the player is assumed to make when its escape cells are counted |
| | `seal_sec` | combat.json `zones.seal_sec` | Seconds the hole stays open after the crack (cannot be entered), override of `zones.seal_sec` |
| | `may_target_player_cell` | true | Drop tile (2026-10-31 spec): true = the player's own cell may be among the cracked cells (ranked first) when the fairness rule allows it (step cooldown left <= `zones.hole_warn_sec` - `zones.hole_reaction_margin_sec`, not Frozen, not rooted); false = the old choice (escape cells only, never the player's cell) |
| | `hole_warn_sec` / `hole_reaction_margin_sec` | combat.json `zones` | Per-boss overrides of the crack warning / reaction margin (not used by shipped data) |
| `thorn_field` | `min_swing_cells` | 4 | Story 027: a boss swing of at least this many cells lays thorns when it starts |
| | `max_cells` | 3 | Most thorn cells per field (escape cells touching the swing, nearest the player first) |
| | `escape_steps` | 2 | Reach of the player used to find its escape cells |
| | `cooldown_sec` | 0.0 | Seconds after a field before the next (0 = every qualifying swing) |
| | `thorn_sec` / `thorn_damage` / `fragile_stacks` | combat.json `zones` | Thorn numbers override |

HUD getters: `StepReactorTrait.get_charges()/get_charges_to_fire()`, `FuseCannonTrait.get_fuse_left()/get_fuse_sec()/get_warning_cells()`, `SlamTrait.get_cracked_cells()/get_warning_cells()`, `FrostAuraTrait.is_active()`, `PhaseShiftTrait.get_phase()`.

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

Each `shapes` entry: `id` (unique string), `name_key` (`arena.<id>.name`; `ArenaNames` holds the same keys for the HUD), `side_cols`, `side_rows` (cells of one half), `missing_cells` (`[[col,row],...]`), `difficulty` (1..5, for the later per-tier pools, Story 015). Shipped shapes: square, rect, cross, u_shape, ring, islands_bridge, staircase, diamond, and (Story 023, chapter 3) `cross_wide` (5x5 minus the four corners, 21 cells, difficulty 3) and `pillars` (5x5 with holes at [1,1] [1,3] [3,1] [3,3], 21 cells, difficulty 4). Both are pure data — no generator case was needed; `ArenaNames.NAMES` gained the two keys.

P2.2b `boss_only` (bool, default false): a shape only a multi-cell Warden fight names (`boss_hall`, 6x4 per side, no holes,
difficulty 5). `ArenaLibrary.shape_ids()` and `shapes_with_difficulty()` leave it out (pass `shape_ids(true)` to list it), so
no pool, scan or count built from them meets it; it is reached only by name (`get_shape`, a match `arena` block, `--arena=`,
an enemy's `arena` key in `enemy_skills.json`).

Story 028 featured shape (hinh chu dao), optional per shape (both keys or the feature is off for it, warning):
- `featured_shape`: `[[x,y],...]` relative cells (any offset; normalised), 5..7 cells, edge-connected (rule constants `ArenaLibrary.FEATURED_MIN_CELLS` / `FEATURED_MAX_CELLS`). A TWO-piece cast whose union of cells equals it in one of its 4 rotations (no flip) gets the bonus. It must be tileable by >= 2 distinct pairs of `pieces.json` shapes and placeable on the enemy half (test: `tests/unit/pieces/arena_featured_test.gd`).
- `featured_bonus`: `{damage_mult (>= 0, 1.5), effect ("fragile" | "pin" | "burn" | "frost"), stacks (int >= 0; Ran / Han stacks, or burn ignitions of the cast cells), sec (number >= 0; pin seconds, 0 for the others)}` plus, for `burn`, `burn_duration_sec` / `burn_tick_sec` / `burn_damage_per_tick` (fallbacks: CutEffects.FEATURED_BURN_*). Damage order: card x conditions -> Ghim -> Ran -> featured x damage_mult -> execute -> passive -> signature -> defense; the effect is applied once on a hit, never on a miss or for boss swings.
- A `chapters.json` match may override with its own `featured_shape` / `featured_bonus` (bonus keys override one by one). `ArenaLibrary.featured_for_match(match, grid)` turns the feature off when the (variant) board's enemy half cannot hold the shape.
- Theme mapping: solid ground (square, rect) = `pin` 1.2 s; stone (cross, cross_wide, pillars) = `fragile`; forge / climb (u_shape, staircase) = `burn` x1; water / crystal (ring, islands_bridge, diamond) = `frost`.

| id | featured shape (rows, # = cell) | cells | effect |
|---|---|---|---|
| `square` | `###/##.` (P) | 5 | pin 1.2 s |
| `rect` | `###/#.#` (U) | 5 | pin 1.2 s |
| `cross` | `#../###/.#.` (F, plus-like) | 5 | fragile x1 |
| `u_shape` | `###/#.#` (U) | 5 | burn x1 |
| `ring` | `#.../#.../####` (ring corner) | 6 | frost x1 |
| `islands_bridge` | `####/#...` (bridge + post) | 5 | frost x1 |
| `staircase` | `.##/##./#..` (W, stairs) | 5 | burn x1 |
| `diamond` | `.#./###/#..` (F, X-ish) | 5 | frost x2 |
| `cross_wide` | `###./#.##` | 6 | fragile x1 |
| `pillars` | `###/#.#/..#` | 6 | fragile x2 |

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

Player save written by `ProgressStore` (atomic: temp file renamed over the target) at milestones (Story 022): run start, every node choice, start of every match, every card offer, after a reward pick / skip / remove, after a rest choice, when leaving the run, run end. Never written mid-match. Parsed by `ProgressState.from_json`: empty, corrupt, non-object or unknown-version text gives an empty state (warning). A version-1 file loads without warning: only `locale` is read, the rest is ignored. With a `ChaptersConfig`, an invalid `run_in_progress` is dropped (warning); region ids are kept as saved (Story 031: not validated). Dev: `--progress=none|all|demo` uses an in-memory store (`demo` = chapter 1 cleared plus a v4 run in chapter 1 at column 3 with 1 removal token). Other `GameFlow` dev args (all force a memory store): `--node=chX/cC/nN` starts a fresh seeded run of the default character in chapter X, clears the columns before C with their first node and chooses node N of column C (`--floor=chX/fY` is a deprecated alias of `--node=chX/c0/n0`, warning); `--run=map|map3|rest|treasure|miniboss_reward|boss_reward|reward|runover|runwon` puts that run into a capture state (fresh map / 3 columns cleared, luck 3, 1 token / REST open / treasure offer / miniboss offer with the rare floor / boss offer with the token just granted / battle offer / RUN KẾT THÚC / RUN THẮNG); `--run=intro|between|won|lost`, `--match=`, `--demo=`, `--arena=` (RunController / DemoArgs) start a run with the first node chosen; `--seed=N` fixes the run seed (same map, arenas and offers).

| Key | Type | Meaning |
|---|---|---|
| `version` | integer | Written as 5 (Story 031). Files v1..v4 still load (v4 `cleared_chapters` migrate into `regions_boss_beaten`, `best_floor` = 0): v1 keeps only `locale`; v2/v3 have `cleared_bosses` = 0 and their `run_in_progress` (floor/match based) loads as a **needs_restart** run (below) |
| `cleared_bosses` | integer >= 0 | Permanent count of bosses ever beaten (`ProgressState.get_cleared_bosses()`, `record_boss_clear()`); clamps the map tier to <= 1 while 0 |
| `locale` | string | UI language code (`vi` / `en`) |
| `regions_boss_beaten` | array of region ids | Regions whose boss was ever beaten (any character), e.g. `["ch1"]`, first-beaten order, no duplicates (`ProgressState.add_region_boss_beaten`, `get_regions_boss_beaten`). v2..v4 files stored this as `cleared_chapters` (the old chapter ids ch1/ch2/ch3 are the region ids); it is read only for version < 5 and never written. Chapters no longer lock (Story 031) |
| `best_floor` | integer 0..6 | Highest floor ever reached (1..5 plus the final match = 6; 0 = none yet; `ProgressState.record_floor`, monotonic max, clamped; v < 5 files load as 0) |
| `seen_cards` | array of card ids | Cards ever offered or owned (write-only for now) |
| `run_in_progress` | object or null | The run being played (`RunSession.to_dict`, v4): `version` 4, `character` (id), `chapter` (chapter id), `map` (`[{index, tier, nodes: [{kind, match_id}]}]`, kinds battle/danger/treasure/rest/miniboss/boss; fixed for the run), `column` (current column; == map size when finished), `node_index` (chosen node in the column, -1 = none yet), `cleared_nodes` (`[{column, node_index, kind}]`), `hp` (HP at the start of the node, negative = full; never auto-healed between nodes), `deck` (`[{id, level}]`, duplicates allowed; id strings load as level 1), `run_seed`, `elapsed` (seconds), `pending_reward` (card ids offered but not yet picked/skipped, `[]` when none), `relics` (Story 032: relic ids owned, in received order, unique; unknown ids are dropped with a warning; a save without the key = no relics, no version bump), `pending_relic_offer` (Story 032: relic ids of the open treasure screen's second row, `[]` when none; picking a card or a relic, or skipping, clears it together with `pending_reward`), `revives`, `removal_tokens` (>= 0), `cleared_bosses_this_run`, `gold` (Story 033: int >= 0; missing = economy.json `starting_gold`, negative loads as 0), `run_modifiers` (Story 033: `[{id, matches_left >= 1, params}]`, `params` = config overrides per key in the `RelicRegistry.merge_overrides` form, e.g. `{"step_cooldown": {"mul": 1.2}}`; -1 `matches_left` per match played, dropped at 0; entries without id or with `matches_left` < 1 are dropped; missing = `[]`; handed to the match as `match_params["run_modifiers"]` = the folded `{key: {add, mul[, set]}}` table), `shop_state` / `event_state` (Story 033: opaque objects owned by the shop / event logic, stored and returned as is; missing or not an object = `{}`). The Story 033 keys need no version bump. Luck is derived: `luck_start + luck_per_node x cleared_nodes.size()` (rewards.json). A pre-v4 run (no `version` 4) or `{needs_restart: true}` loads as a session with `needs_restart` true, `restart_reason` `run.restart.old_save`, empty map and deck, so `GameFlow` restarts that chapter for that character from a fresh run; saved chapters are kept. Saved form of such a run: `{version, character, chapter, needs_restart, restart_reason, map: []}` |

Economy keys read by `RunSession` from the rewards config (documented fallbacks in `RunSession.CONFIG_DEFAULTS`, the file wins): `starting_removals` 1, `luck_start` 0, `luck_per_node` 1, `rest_heal_ratio` 0.3 (`rest_heal`: hp += ratio x max HP, clamped), `rest_forge_levels` 1 (`rest_forge`: +levels, capped at `SkillConfig.MAX_LEVEL`), `boss_removal_tokens` 1 (tokens granted by a boss node; fallback only). Max HP in `characters.json` is x3 since Story 022 (300 / 240 / 270) and `second_wind.heal_after_match` is 30; enemy damage is unchanged.

## `rewards.json` (Story 019, read by `src/run/reward_roller.gd`, class RewardRoller)

Card reward after a map node (Story 022: by node kind, see `node_rewards`). Bad or missing file: defaults below (warning).

| Key | Type | Meaning | Default |
|---|---|---|---|
| `offer_count` | integer >= 1 | Distinct cards offered | 3 |
| `rarity_weights` | object rarity -> number >= 0 | Draw weight per rarity (`common`, `rare`, `epic`); a missing rarity = 0 weight | 70 / 25 / 5 |
| `allow_remove` | boolean | Removal exists in this build. Story 022: the "remove 1 card" slot also needs `RunSession.removal_tokens > 0` and spends one token; the old free removal per match is gone | true |
| `min_deck_size` | integer >= 1 | The deck cannot drop below this many cards by removing | 4 |
| `max_card_level` | integer 1..3 | A card at this level is not offered again (unless the pool is short) | 3 |
| `offer_upgrades` | boolean | The reward view labels cards already owned as "upgrade" | true |
| `allow_skip` | boolean | The reward screen offers a Skip button | true |
| `pool_excludes_defaults` | boolean | Cards in `cards.json` `default_deck` are not offered | false |
| `rarity_weights_at_luck` | object luck (numeric string) -> `[common, rare, epic]` | Story 022: rarity weights by run luck, linearly interpolated between anchors and clamped outside them (`RewardRoller.luck_rarity_weights`). A custom `rarity_weights` without anchors holds flat at every luck | `{"0": [70, 25, 5], "70": [31, 35, 34]}` |
| `luck_start` | number >= 0 | Story 022: luck of a new run | 0 |
| `luck_per_node` | number >= 0 | Story 022: luck gained per cleared node (`luck = luck_start + luck_per_node * cleared nodes`) | 1 |
| `starting_removals` | integer >= 0 | Story 022: removal tokens a run starts with (+1 per chapter boss) | 1 |
| `rest_heal_ratio` | number 0..1 | Story 022: share of max HP healed by "Rest" at a `rest` node | 0.3 |
| `rest_forge_levels` | integer >= 1 | Story 022: card levels added by "Forge" at a `rest` node (capped at `max_card_level`) | 1 |
| `node_rewards` | object kind -> `{offers, min_rarity, free, removal_token}` | Story 022: card pick per node kind (`RewardRoller.reward_for_node`). `offers` 0 = no card; `min_rarity` = every offered card is at least this rarity (topped up from the whole pool with a warning when too few exist); `free` = no fight; `removal_token` = grants one token. Shipped: battle / danger 3 common; treasure 3 common free; miniboss 3 min rare; boss 3 common + token; rest 0; shop / event 0 (Story 033: no post-fight offer for them) | as listed |
| `piece_rewards` | object | Story 034, read by `src/pieces/piece_deck_config.gd` (class PieceDeckConfig); a missing block / key / out-of-range or non-number value keeps the default (warning). Keys below | see below |
| `piece_rewards.ink_offer_chance` | number 0..1 | Chance that a won `battle` / `danger` node also offers the Ink row (a `treasure` node always does; bosses never) | 0.35 |
| `piece_rewards.ink_offer_count` | integer >= 0 | Distinct shapes in one Ink offer (`PieceDeck.roll_ink_offer`, seeded; shapes at `mult_max` are not offered) | 2 |
| `piece_rewards.mult_step` | number > 0 | `mult` gained when an owned shape is inked again (a run_only shape not yet owned enters `added` at 1.0; a removed shape returns to 1.0) | 1.0 |
| `piece_rewards.mult_max` | number >= 1 | Ceiling of a shape's `mult` (drop weight = base x mult) | 4.0 |
| `piece_rewards.min_shapes` | integer >= 1 | Removing a shape is refused when fewer than this many shapes with `mult > 0` would stay | 5 |
| `piece_rewards.run_only_weight` | number >= 0 | Base drop weight of an owned run_only shape (the default pool uses `pieces.json` `weights`) | 6.0 |
| `piece_rewards.shape_removals_start` | integer >= 0 | Shape-removal tokens (`RunSession.shape_removals`) at the start of a run | 1 |
| `piece_rewards.shape_removals_per_boss` | integer >= 0 | Extra shape-removal tokens per region boss | 1 |

Player drop weight in a match (Story 034, `PieceDeck.effective_weights`): `w(shape) = base(shape, chapter key) x mult(shape)`, with `base = piece_rewards.run_only_weight` for a run_only shape; `w = 0` never drops. When no shape with `w > 0` has a placement on the enemy half, the match uses the ORIGINAL weights of the default shapes that fit (`PieceDeck.weights_for_match` -> `fallback: true`). Deck state in the run save: `piece_deck` = `{"mult": {shape id: number >= 0}, "added": [run_only shape id]}`.

The pool is every `implemented` card; the roll (`RewardRoller.roll(cards, config, seed, exclude_ids, deck_levels, luck, min_rarity)`) is a seeded weighted draw without replacement, weighted by rarity at the given luck and floored at `min_rarity`.

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
| `characters[].unlock_by` | string (optional) | Story 037: id of the achievement that unlocks the character (`achievements.json` rewards list it); absent = open from the start. The old static `unlocked` flag is gone: `CharacterConfig.set_unlock_source(fn)` decides (no source = everything unlocked), `get_character(id)` returns the computed `unlocked` and `unlock_by` |

Passive params: `second_wind {heal_after_match}` extra HP after a won match (added before the max clamp); `wide_caster {min_cells, duration_mult}` player swings over `min_cells` or more cells wind up `duration_mult` times as long; `quick_blade {max_cells, damage_mult}` player hits over `max_cells` or fewer cells deal `damage_mult` times the final damage. Passives only affect the player.

Signature params (Story 021): `tram {duration_sec, cell_mult, lifesteal}` for `duration_sec` every player cut counts `cell_mult` x its cells for damage (the swing covers the real cells) and heals `lifesteal` x the damage dealt (clamped to max HP); `thien_hoa {burn_stacks, burn_duration_sec, burn_tick_sec, burn_damage_per_tick, detonate_mult}` instant (Story 030, order chốt 2026-10-25): first the boss takes `detonate_mult` x the total remaining burn damage of every enemy-half cell ALREADY burning (time left / tick sec x damage per tick, stacks included; nothing burning: 0) and those cells stop burning; then every `effect: burn` card's cooldown is reset; then every LIT formation-map cell of the enemy half is ignited `burn_stacks` times with `burn_duration_sec` / `burn_tick_sec` / `burn_damage_per_tick` — a lasting fire that hurts the boss while it stands in it (the boss brain avoids burning cells, `burn_avoid`) and is NOT detonated in the same use (no formation or no lit cell: nothing is ignited). Shipped (bot-tuned, `production/qa/evidence/signature-rework/signature-balance.md`): 1 stack, `burn_duration_sec` 3.0, `burn_tick_sec` 0.5, `burn_damage_per_tick` 0.5, `detonate_mult` 2.0; `anh_bo {duration_sec, small_mult, small_cells}` for `duration_sec` the player's steps have no cooldown and EVERY player hit of `small_cells` or fewer cells is multiplied by `small_mult` (Story 030: the boss need not be pinned; shipped 1.75). The legacy key `pinned_small_mult` is still read when `small_mult` is absent (warning, used as `small_mult`). Damage order: card `damage_per_cell` x cells (Tram cell count) -> Ghim -> passive -> signature.

Story 037 characters: `tho_san` (Hunter, `unlock_by` `hunter_path`; max HP 190, step x0.95, focus 4.0; deck `kiem_khi` x2, `tran_gai` x2, `gai_doc`, `ran_kich` since the 2026-10-31 quick spec) and `giao_si` (Priest, `unlock_by` `mercy_path`; max HP 210, step x1.05, focus 4.5; deck `kiem_khi` x2, `han_khi` x2, `han_kiem`, `bang_phong`). Passives: `hunter_mark {fragile_stacks, icd_sec}` the boss gets `fragile_stacks` Ran when it steps onto one of the player's thorn cells (`StatusEffects.thorn_entered`, enemy side) or when the player lays thorns with the boss on a cell next to (4-neighbour, not inside) one of the cells just laid (quick spec 2026-10-31; was: a seal), then waits `icd_sec` simulation seconds (`BasePassive.tick`); `prayer {heal_per_burst}` every Han burst on the boss heals the player (ctx `heal_player`, clamped to max HP; the HUD shows a "+N" flash). Signatures (both timed): `vay_bat {duration_sec, zone_sec_mult, extra_thorn_cells, fragile_mult}` while active the thorns the player lays last `zone_sec_mult` x (thorn seconds only since the 2026-10-31 quick spec, read through `BaseSignature.zone_sec_mult`), each thorn card lays `extra_thorn_cells` extra cell(s) (`BaseSignature.extra_thorn_cells`, cells picked by `CutEffects.extra_thorn_cells`: 4-adjacent to the cast, not the boss's cell, not already thorned, not blocked, nearest the boss first, ties x then y) and one consumed Ran stack multiplies the hit by `fragile_mult` instead of combat.json `fragile_mult` (`BaseSignature.fragile_mult_override`); `thanh_an {duration_sec, extra_frost_stacks, burst_mult}` while active every player hit that lands on the boss adds `extra_frost_stacks` Han stacks and a Han burst on the boss deals `burst_mult` x (`BaseSignature.frost_burst_mult`). Match stats (`CombatView.get_match_stats()`): new int keys `frost_bursts` (Han bursts on the boss) and `boss_thorn_steps` (the boss stepped onto a player thorn cell, one per step).

Dev arg: `--character=<id>` (GameFlow) selects a character; without it and without the select screen no character is passed.

## `relics.json` (Story 032, read by `src/relics/relic_config.gd`, class RelicConfig)

Relics: passive rule changes the player carries for the whole run (no per-character relics, no active relics). Bad or missing file: `RelicConfig.DEFAULTS` for the top-level keys and no relics (warning); a bad entry is dropped with a warning, never a crash. All numbers are starting values, tuned by simulation.

| Key | Type | Meaning | Default |
|---|---|---|---|
| `relic_damage_mult_cap` | number >= 1 | Cap of the PRODUCT of every relic damage factor on one cast (`RelicRegistry.fold_damage`) | 3.0 |
| `rarity_weights` | object rarity -> number >= 0 | Draw weight per rarity for the `treasure` source; a missing rarity = 0 (so `boss` never appears in a treasure) | 60 / 30 / 10 (common / rare / epic) |
| `source_rules.treasure` | `{count, min_rarity}` | `count` different relics offered, none already owned (unless `stackable`); each slot draws a rarity by `rarity_weights` among rarities at or above `min_rarity` (floor) that still have a candidate | `{count: 3, min_rarity: "common"}` |
| `source_rules.shop` / `source_rules.event` | `{count, min_rarity}` | Story 033: drawn exactly like `treasure` (`RelicRoller.roll("shop" / "event", …)`); an event effect may raise the floor with its own `min_rarity` | `shop {count: 2, min_rarity: "common"}`, `event {count: 1, min_rarity: "common"}` |
| `source_rules.boss_kill` | `{count, tiers}` | Relics drawn tier by tier: from `tiers[0]` (`boss`) first, then the next tier (`epic`) when none is left | `{count: 1, tiers: ["boss", "epic"]}` |
| `relics[].id` | string | Unique relic id (duplicate -> warning, later dropped); saved in `run_in_progress.relics` | — |
| `relics[].rarity` | `common` / `rare` / `epic` / `boss` | Rarity (unknown -> warning, entry dropped) | — |
| `relics[].tags` | array of `negative`, `stackable` | `negative`: a relic with a drawback (red frame in the HUD); `stackable`: may be offered again while owned. Unknown tag -> warning, ignored. None of the 16 shipped relics is stackable | `[]` |
| `relics[].name_key` / `desc_key` | translation keys | `relic.<id>.name` / `relic.<id>.desc`; the description states the numbers of `params` | `relic.<id>.name` / `.desc` |
| `relics[].script` | string | `RelicRegistry.SCRIPTS` key: `config_mod` (shared `ConfigModRelic`) or the relic's own script (`an_don`, `chi_khau`, `khoi_the`, `phan_don`, `huyet_an`, `an_chu`, `tam_hop`). Unknown -> warning, no relic | the id |
| `relics[].params` | object | The relic's numbers (below) | `{}` |

Config-type relics (`script: "config_mod"`): `params` maps a canonical config key to `{add: x}`, `{mul: x}`, `{add: a, mul: m}`, `{set: v}` or a bare number (= `set`). Canonical keys (`RelicRegistry.CONFIG_KEYS`): `thorn_sec`, `thorn_ran`, `piece_freshness_sec`, `start_pieces`, `focus_sec`, `formation_fade`, `signature_cooldown`, `hold_slots`, `piece_spawn_interval`, `burn_max_stacks`, `han_stacks`, `han_damage`. All relics' overrides are folded by `RelicRegistry.merge_overrides` (adds sum, muls multiply, the last `set` wins) and applied to the match config BEFORE `FieldDrops`, the piece bag, `FormationMap` and `StatusEffects` are built: **value = (base, or `set` when present, + sum of adds) x product of muls** (`RelicRegistry.apply_override`). Where a number comes per card (e.g. a card's `thorn_sec`), the override applies after the card's number. Adding a config-type relic is JSON only.

Shipped relics: `an_don` common `{mult: 2.0}` a cast of exactly one `mono` piece deals x mult; `chi_khau` common `{heal: 3, max_heal_per_match: 15}` every joined cast heals `heal`, at most `max_heal_per_match` per match; `phong_an` common `thorn_sec +1.0` (Gai Dai, quick spec 2026-10-31; was `seal_sec`); `gai_ran` common `thorn_ran +1` (Fragile stacks from the player's thorn cells); `manh_tuoi` common `piece_freshness_sec +4` (the `start_pieces +1` part was removed by the Story 032 simulation); `dinh_tam` common `focus_sec +1.0`; `la_ban` rare `formation_fade x1.3` (cells fade slower); `tam_huong` rare `signature_cooldown x0.8`; `tui_rong` rare `hold_slots +1` (the `piece_spawn_interval x1.25` drawback was removed by the Story 032 simulation); `dau_than` rare `burn_max_stacks +1`; `khoi_the` rare `{first_casts: 1}` the first cast(s) of each match have no windup; `phan_don` rare `{shape: "mono"}` interrupting a boss spell puts one `shape` piece in the bag if there is room; `han_ky` epic `han_stacks` set 2, `han_damage x0.67`; `huyet_an` epic `negative` `{min_cells: 5, mult: 1.3, self_damage: 2}` casts of `min_cells`+ cells deal x mult, and such a cast that misses the boss costs `self_damage` HP (a hit costs nothing; smaller casts are unaffected; reworked 2026-10-26 from "every cast costs `self_damage`", which the simulation showed as a trap); `an_chu` boss `{featured_mult: 2.0}` replaces the featured-shape multiplier; `tam_hop` boss `{max_join_pieces: 3}` a third piece may be joined into one cast.

**Damage order of a player cast (Story 032, as implemented in `CutEffects.apply`; replaces the Story 021 order above):** card `damage_per_cell` x cells (Tram cell count) x card conditions (`bonus_vs_fragile_mult`) -> Ghim (Pin) -> Rạn (Fragile, spends 1 stack) -> featured shape (x `damage_mult`, or `an_chu`'s `featured_mult` when > 0) -> **relics** (every relic's `modify_cast_damage` in received order, multiplied together; the product is capped at `relic_damage_mult_cap`, `RelicRegistry.fold_damage`; the ONE hook is `SwingArbiter.player_relic_modifier`, player swings only) -> execute (x2) -> passive -> signature -> flat boss defense (minimum 1). Every step before flat defense is a multiplication, so their order does not change the number (the existing keyword steps were not moved); only flat defense, applied last, depends on the order. The relic cap applies to the relic product alone. Windup: the card's windup x `duration_mult` -> passive -> relics (`RelicRegistry.fold_cast_time` through `CutActor.cast_time_modifier`, once per begun player swing, floored at 0). Zone overrides (`thorn_sec`, `thorn_ran`) apply only to the PLAYER's zone cards, after the card's own number (else the `combat.json` zones number).

## `economy.json` (Story 033, read by `src/run/economy_config.gd`, class EconomyConfig)

Gold of a run and shop prices. A missing / bad file or key keeps the `EconomyConfig.DEFAULTS` value (warning). `floor` is RunSession's 0-based floor; a floor past the end of a multiplier list uses its last value (the final match). Gold is dropped by a WON node (`GameFlow._drop_gold`, also the treasure node when opened): `round(gold_drops[kind] x gold_floor_mult[floor] x (1 + variance x u))`, `u` uniform in [-1, 1] from `hash([run_seed, floor, column, node_index, "gold"])`, never negative; kinds without an entry (rest, shop, event) drop 0. Prices: `round(base x price_floor_mult[floor])`.

| Key | Type | Unit | Meaning | Shipped |
|---|---|---|---|---|
| `starting_gold` | int >= 0 | gold | Gold of a new run (and of a save without `gold`) | 20 |
| `gold_drops` | object kind -> int >= 0 | gold | Base drop per node kind: `battle`, `danger`, `miniboss`, `boss` (region boss and final), `treasure` (no fight) | 12 / 22 / 25 / 35 / 15 |
| `variance` | float 0..1 | share | Seeded spread of each drop (+-) | 0.2 |
| `gold_floor_mult` | array of float >= 0 | x | Drop multiplier per floor (index = 0-based floor) | 1.0, 1.1, 1.2, 1.3, 1.4 |
| `shop.stock` | `{cards, relics}` ints >= 0 | items | Stock of one shop (`EconomyConfig.stock_counts`) | 3 cards, 2 relics |
| `shop.card_prices` | object rarity -> int | gold | Card price by rarity (`price_card`; unknown rarity = common) | common 30, rare 40, epic 60 (Story 033 sim; started at 40 / 60 / 85) |
| `shop.relic_prices` | object rarity -> int | gold | Relic price by rarity (`price_relic`) | common 50, rare 70, epic 90 (Story 033 sim; started at 75 / 100 / 130) |
| `shop.price_floor_mult` | array of float >= 0 | x | Price multiplier per floor, also applied to services | 1.0, 1.05, 1.1, 1.15, 1.2 |
| `shop.services.remove_card` | `{price, max_uses}` | gold / uses | Remove one chosen card at once (no token); uses per shop visit (`service_price`, `service_max_uses`) | 60, 1 |
| `shop.services.remove_shape` | `{price, max_uses}` | gold / uses | Story 034: remove one chosen shape from the piece deck at once (gold, no shape-removal token); refused when `PieceDeck.can_remove` is not ok (e.g. `min_shapes`) | 45, 1 |
| `shop.services.heal` | `{price, max_uses, heal_ratio 0..1}` | gold / uses / share of max HP | Heal `heal_ratio` x max HP (`service_heal_ratio`) | 40, 1, 0.25 |

## `events.json` (Story 033, read by `src/run/event_logic.gd`, class EventLogic)

Event nodes: a short text and 2–4 choices; the LAST choice of every event is "Rời đi" (`label_key: ui.event.leave`, no cost, no effect). Missing / bad file: no events (warning); a malformed event or choice is dropped, an unknown effect type is dropped with a warning. All numbers are starting values (tuned by the `deck_sim` economy run). Which event a node shows: `EventLogic.pick_event` seeded by run seed / floor / column / node, never one already seen this run while an unseen one is left. Outcome draw: seeded by `hash([run_seed, floor, column, node_index, event_id, choice])`, so a reload gives the same result.

| Key | Type | Meaning |
|---|---|---|
| `events[].id` | string | Unique event id (`event.<id>.*` keys) |
| `events[].title_key` / `body_key` | translation keys | Title / body (body at most ~300 characters per language, no scrolling) |
| `choices[].id` | string | Choice id (`event.<id>.<choice>.label/.cost/.result`) |
| `choices[].label_key` / `cost_key` | translation keys | Button text / what it costs (shown in red; `""` = nothing) |
| `choices[].requires` | object | All optional: `gold: n` (gold >= n), `relic: "non_boss"` (owns a relic not of rarity `boss`), `hp_cost_ratio: r` (current HP > r x max HP, so a cost never kills), `cards: n` (deck size >= n). Failing = greyed out with `ui.event.need_*`. An `upgrade_card` effect also needs an upgradable card |
| `choices[].confirm` | bool | Needs a second tap (HP loss or a curse) |
| `choices[].outcomes` | `[{chance, result_key, effects}]` | One outcome is drawn by `chance` (they sum to 1); `result_key` is the result text |

Effects (closed list, `{type, …}`): `gold {amount}` ± gold (a loss takes at most what the run has); `hp {ratio}` ± ratio x max HP, clamped to [1, max HP]; `relic {source, min_rarity}` one unowned relic by `RelicRoller` (falls back to `common` when the floor has none left); `card_offer {rarity, count}` pick 1 of `count` cards of that rarity or better (a player pick, never a curse); `curse {id}` adds a curse card (`cards.json` rarity `curse`, never levels: a second one is a second copy); `remove_card {tokens}` `tokens` > 0 = that many removal tokens, else a player pick removes one card now; `upgrade_card {levels}` the player upgrades one non-curse card below the max level; `fight {kind, tier_add, then_effects}` an extra match of `kind` at +`tier_add` tier, `then_effects` apply only when it is won; `run_modifier {id, matches_left, params}` `RunSession.add_run_modifier` (params in the relic override form, e.g. `slow_step` `{step_cooldown: {mul: 1.2}}` for 2 matches); `swap_relic {rarity_up}` the player's relic (chosen, or seeded among non-boss ones) is replaced by an unowned relic `rarity_up` tiers higher (capped at `epic`).

Shipped events: `ban_tho_mau` lose 15 % max HP -> relic floor `rare`; `ke_buon_nguyen` curse `ganh_nang` -> pick 1 of 3 epic cards; `song_bac` bet 30 gold (50 %: +75, else −30) or bet 60 (40 %: +160, else −60); `tran_thach` a `danger` fight at +1 tier -> won: relic + 25 gold; `suoi_tinh` heal 25 % or lose 10 % max HP to upgrade a card; `ke_lang_thang` swap a non-boss relic for one a rarity higher; `mo_hoang` dig: 60 % +40 gold, 40 % curse `oan_hon`; `loi_the` `slow_step` for 2 matches -> +1 removal token and 30 gold.

## Translation keys (Story 017, `assets/i18n/strings.csv`)

Every player-facing string is a key. The CSV has the header `keys,vi,en` (UTF-8; a third language is one more column); Godot imports it into `assets/i18n/strings.<locale>.translation` (gitignored, regenerated by `godot --headless --path . --import`), registered in `project.godot` under `[internationalization]` with `locale/fallback="vi"`. Code never holds display text: `const TEXT_*` constants are keys drawn through `tr()` (`tr(key) % [...]` for printf templates; placeholders are identical in every column), and data files carry keys only:

| Key group | Where | Example |
|---|---|---|
| `ui.<screen>.<label>` | `TEXT_*` in views | `ui.hud.cast`, `ui.title.play`, `ui.floor_select.title` |
| `title.*` | title screen name / tagline | `title.name` |
| `card.<id>.name` / `card.<id>.desc` | `cards.json` `name_key` / `desc_key` | `card.kiem_khi.name` |
| `chapter.<id>.name` | `chapters.json` chapter `name_key` | `chapter.ch1.name` |
| `boss.<id>.name` | every match `name_key` (foe name) | `boss.goblin_chief.name` |
| `arena.<id>.name` | `arenas.json` `name_key`, `ArenaNames.NAMES` | `arena.square.name` |
| `trait.<id>.name` | trait names (reserved for a later HUD / codex) | `trait.row_burner.name` |
| `character.<id>.name` / `.desc` | `characters.json` `name_key` / `desc_key` (Story 018) | `character.phap_su.name` |
| `passive.<id>.name` / `.desc` | `characters.json` `passive_name_key` / `passive_desc_key` | `passive.wide_caster.name` |

A missing key shows the raw key (Godot's default), on purpose. The saved UI locale lives in `progress.json` as `locale` (`"vi"` when absent, v1 saves load unchanged).

## Story 035: fate, endings and the Ấn Đài final match (`chapters.json`, `arenas.json`)

Read by `ChaptersConfig.fate_config()`, `endings_config()`, `final_match_phases()` (`src/run/chapters_config.gd`). A missing block uses the built-in values (= the shipped ones below); a bad value is replaced by its default with a warning. This section supersedes the `final_match` row of "World v6" above (shipped value is now `{"region": "an_dai", "match_id": "an_dai_keeper"}`).

| Key (`world.`) | Type | Meaning | Shipped | Default |
|---|---|---|---|---|
| `fate.execute_artifact_offers` | int >= 1 | Relics offered after **Execute** on a region boss (the player may skip; it still counts as Execute) | 3 | 3 |
| `fate.execute_min_rarity` | rarity id of `relics.json` | Lowest relic rarity of the Execute offer | `"rare"` | `"rare"` |
| `fate.fate_hold_sec` | number >= 0 | Seconds the Spare / Execute button must be held to confirm (released early = cancelled) | 0.6 | 0.6 |
| `endings.spare_min_ratio` | number 0..1 | `spare_ratio = spared / (spared + executed)` at or above this = ending `spare` | 1.0 (every boss spared) | 1.0 |
| `endings.execute_max_ratio` | number 0..1, <= `spare_min_ratio` | `spare_ratio` at or below this = ending `execute`; anything between, or no fate at all = `balance` | 0.0 (every boss executed) | 0.0 |
| `final_match` | `{region, match_id}` | The final match: region `an_dai` (a `chapters` entry that is NOT in `region_pool`, so it is never offered on a floor), match `an_dai_keeper`. `floor_scaling.final` still applies | `{"region": "an_dai", "match_id": "an_dai_keeper"}` | none |
| `final_prelude` | array of columns, each an array of node kinds | TD-029: columns of the final floor's map placed BEFORE the final match's boss column (indices 0..n-1, the boss column is n). Only kinds that need no match id are allowed: `shop`, `rest`; any other kind (or a non-string) is dropped with a warning, a column left empty is dropped, a non-array value is ignored with a warning. A prelude shop is seeded like a region shop (`ShopLogic.build(run_seed, floor = world.floors, column, node)`) and its saved `shop_state` is tagged `"<floors>/<column>/<node>"`, so it never collides with the floor-5 region's shop. Read by `ChaptersConfig.final_prelude()` / `final_map()` | `[["shop"]]` (one column, one shop) | `[]` (missing or empty = the boss column alone) |

**Match key `phases`** (optional, any match; shipped only on `an_dai_keeper`): an array of phase objects. Element 0 is phase 1 (active from the start, no `at_hp_ratio`); element i >= 1 starts when the boss HP ratio falls to its `at_hp_ratio` (descending), once, in order. Every field is optional: a missing one keeps the previous phase's value.

| Phase key | Type | Meaning | Default |
|---|---|---|---|
| `at_hp_ratio` | number 0..1 | Phase i >= 1 starts at this boss HP ratio (a hit cannot carry the HP past it) | - |
| `phase_shift_sec` | number >= 0 | Boss invulnerable for this long on the shift (its cast in progress is cancelled) | 1.0 |
| `name_key` | string key | Banner of the phase (`phase.<match>.<n>`) | "" |
| `traits` | trait list (same shape as the match `traits`) | Traits active during the phase (the previous phase's are torn down) | previous |
| `brain_set` | set id of `boss_brain.json` | Brain weights of the phase | previous |
| `boss_step_cooldown_mult` | number > 0 | Multiplies the boss step cooldown for the phase (the match's own `boss_step_cooldown_mult` and floor scaling still apply) | previous |
| `boss_cards` | array of card ids | The boss's card list for the phase (curses / zone cards dropped like the match key) | previous |
| `root_while_swinging` | bool | `boss_brain.json` `root_while_swinging` for the phase | previous |

Reading: `RunConfig.clean_match` (so `RunConfig.from_node` and `ChaptersConfig.get_match_def` too) turns `phases` into the ONE match trait `{"id": "boss_phases", "params": {"phases": <the array>}}`, REPLACING the match's own `traits`, `brain_set` (back to the default) and `boss_cards` (back to `[]`); CombatView and the balance sim build their TraitHost from `match_params["traits"]`, so the trait `boss_phases` (Story 035, `src/traits/boss_phases.gd`) applies each phase. A `phases` value that is not a non-empty array of objects is ignored (warning). Matches without the key are unchanged.

Shipped `an_dai_keeper` (starting values, the Story 035 simulation retunes them): `boss_max_hp` 130 (x `floor_scaling.final` 1.5 = 195 in play; the old final `mist_lord` was 139 x ch3 normalize 0.75 x 1.5 = 156, the strongest floor-5 region boss about 170), `boss_step_cooldown_mult` 1.6 (x final 0.8 = 1.28 in both phases), `swing_speed_mult` 0.85, `boss_min_runes` 3 (+1 final), no `boss_defense` (+2 final), no `region_normalize` (identity). Phase 1: `seal_caster` (default params), `balanced`, step x1.0, cards `kiem_khi chan_phong kiem_vu hoa_tinh suong_mong ran_kich`, rooted while swinging. Phase 2 at 0.5 HP, 1.0 s shift, banner `phase.an_dai_keeper.2`: `seal_caster` + `row_burner` (default params), `aggressive`, step x1.0, phase 1's cards (no `boss_cards` key), still rooted while swinging. Retuned by the Story 035 simulation from the starting values (`thorn_field` added, step x0.85, strong cards, not rooted): with those the final-match win when reached was 0-7 %; an unrooted phase 2 alone gave 0 % (the bot cannot land a cast on a boss that moves while swinging) and `thorn_field` cost about 30 points; see `production/qa/evidence/spare-execute-endings/simulation-fate.md`. No new brain set: `balanced` / `aggressive` already express "measured then relentless" (no `final` set in `boss_brain.json`). The region `an_dai` has a `boss` pool (tiers 0-2) holding only `an_dai_keeper` so tools that build a map of every chapter still work; it is never offered as a region.

**Arena `an_dai_dais`** (`arenas.json`): a round dais with a hole in the middle of each half: 5x5 side minus the four corners and the centre `[2,2]` (20 cells per side, difficulty 4). Featured shape `###/..#/..#` (V, 5 cells; pairs `bar2+bar3`, `l4+mono`), bonus `fragile` x1 (stone theme). `ArenaNames.NAMES` gained `arena.an_dai_dais.name`.

New string keys: `boss.an_dai_keeper.name`, `match.an_dai_keeper.desc`, `phase.an_dai_keeper.2`, `chapter.an_dai.name` / `.intro` / `.end`, `arena.an_dai_dais.name` (placeholder texts marked "(Tạm)" / "(Placeholder)" until the narrative-director's text).

## Story 035 save keys (run save v6, progress v6; `src/run/run_session.gd`, `src/run/progress_state.gd`, `src/run/fate_logic.gd`)

Run save (`run_in_progress`, `RunSession.SAVE_VERSION` 6). A v5 run loads as a live run with the keys below at their defaults
(`[]`, `false`, `{}`, zero counters); runs below v5 still load as `needs_restart`.

| Key | Type | Meaning |
|---|---|---|
| `boss_fates` | array of `{floor: int, region_id: String, match_id: String, fate: "spare"\|"execute"}` | One entry per region boss met, in order. Entries with another `fate` are dropped on load. Decides the ending. |
| `pending_fate` | bool | True from the moment a region boss is downed until a fate is chosen; a resumed run opens the Spare / Execute screen. |
| `pending_fate_match` | `{floor, region_id, match_id}` | The boss waiting for a fate (`{}` when not pending; filled from `floor` / `region` when missing). |
| `stats` | object | `matches_won`, `hits_taken`, `casts`, `joins`, `featured_casts`, `signatures_used` (int >= 0), `damage_dealt`, `damage_taken` (float >= 0, HP), `death` (`{}` or `{floor, region_id, match_id, boss_name_key}`). Unknown keys dropped. |

Progress file (`user://progress.json`, `ProgressState.VERSION` 6). Files v1..v5 load with these keys empty / 0. Written by Story 035, read by Story 037.

| Key | Type | Meaning |
|---|---|---|
| `spared_bosses` | array of match ids | Bosses ever spared (no duplicates). |
| `executed_bosses` | array of match ids | Bosses ever executed (no duplicates; a boss can be in both lists). |
| `spare_total` / `execute_total` | int >= 0 | Every Spare / Execute choice ever made. |
| `endings_seen` | array of ending ids | `spare`, `execute`, `balance` ever reached (no duplicates). |

Execute relic offer: no `execute` source in `relics.json`. `FateLogic.roll_execute_offer` draws through `RelicRoller.roll("treasure", owned, rng, cfg, count, min_rarity)`
with `count = world.fate.execute_artifact_offers` and `min_rarity = world.fate.execute_min_rarity` (the rarity-weighted `treasure` draw restricted to that rarity or
above, by `rarity_weights`; never an owned relic unless `stackable`). Tune the Execute offer in `chapters.json -> world.fate` only.

## Story 036: swamp and desert regions, arena hazards (`chapters.json`, `arenas.json`, `pieces.json`)

| Key | Where | Type / default | Meaning |
|---|---|---|---|
| `swamp`, `desert` | `chapters.json` -> `chapters[]` | region entries | Đầm Lầy Độc / Sa Mạc Cát Ấn, same format as `ch2`/`ch3` (`name_key`, `intro_key`, `end_key`, `region_normalize` = ch1's values, `matches`, `pools` battle 0-2 / danger 0-2 / miniboss 1-2 / boss 1-2). Appended after `an_dai` (indices of ch1-ch3 and an_dai unchanged). |
| `world.region_pool` | `chapters.json` | `["ch1","ch2","ch3","swamp","desert"]` | `an_dai` stays outside the pool. |
| `mire_immune` | match entry | bool, absent = not set (combat default false) | The boss ignores mire (no tick damage, no step slow). Passed through by `RunConfig.clean_match`. |
| `mire_step_mult`, `mire_tick_damage`, `mire_tick_sec`, `mire_grace_sec`, `sand_interval_sec`, `sand_cells`, `sand_sec`, `sand_warn_sec`, `drift_sec`, `wind_shift_sec` | match entry | number >= 0, absent = not set | Per-match override of the same key of `combat.json` `hazards` (`RunConfig.HAZARD_OVERRIDE_KEYS`). |
| `hazards` | `arenas.json` shape | object, optional | `{"mire": {"per_side": N}}` (N mired cells on EACH half, seeded by the match `arena_seed`; 0..half of the half) or `{"mire": {"player": [[c,r]...], "enemy": [[c,r]...]}}` (side coordinates); `"sand": true` = periodic sand fall on. Unknown keys / bad values reject the shape (ArenaValidator). Mire never on a missing cell or the unit start cell, and the start cell keeps a mire-free neighbour (leave-a-path). |
| `wind` | `arenas.json` shape | bool, default false | Wind drift of field pieces on. |
| `featured_shape` rule | `arenas.json` shape | — | Story 036: must be buildable from >= 2 distinct piece pairs (`ArenaLibrary.FEATURED_MIN_PAIRS`, `FeaturedShape.pair_compositions`); otherwise the feature is off for the shape (warning). |
| `bog`, `reed_maze`, `dunes`, `oasis` | `arenas.json` shapes | — | Swamp arenas (`hazards.mire`, featured bonus `pin`) and desert arenas (`wind: true`, `hazards.sand: true`, featured bonus `fragile`). |
| `weights.swamp`, `weights.desert` | `pieces.json` | shape -> weight | Swamp leans 2-3 cell pieces (5-cell rare like ch1); desert leans `bar2`/`bar3`/`bar4`. Default-pool shapes only. |

`ArenaLibrary.hazards_for_match(match_params, grid, library = null) -> {mire_player, mire_enemy, sand, wind}` (static; `library` null = arenas.json, loaded once).

## Story 036: tile hazards (`combat.json` `hazards`, match overrides; read by `src/combat/combat_config.gd` `hazards()` and `src/combat/tile_hazards.gd`)

| Key | Where | Default | Meaning |
|---|---|---|---|
| `hazards.mire_step_mult` | `combat.json` (match key of the same name overrides) | 1.6 | Cooldown multiplier of a step that starts ON a mire cell (leaving mire). >= 0. Applied after the step's `cooldown_scale` (a free step, scale 0, stays free). |
| `hazards.mire_tick_damage` | same | 0.5 | Damage per mire tick while standing in mire. >= 0. Story 036 sim: 1.0 made mire 19-23 % of the HP lost in swamp matches (target <= 15 %); 0.5 gives 10-14 %. |
| `hazards.mire_tick_sec` | same | 0.5 | Seconds between mire ticks after the first. > 0. |
| `hazards.mire_grace_sec` | same | 0.5 | Seconds standing on one mire cell before the first tick (walking through one cell costs nothing). >= 0. |
| `hazards.sand_interval_sec` | same | 6.0 | Seconds between periodic sand falls (arena `hazards.sand: true`). > 0. |
| `hazards.sand_cells` | same | 2 | Cells per side per fall (never under a unit; leave-a-path may keep one fewer). >= 0. |
| `hazards.sand_sec` | same | 3.0 | Seconds a filled sand cell blocks. > 0. |
| `hazards.sand_warn_sec` | same | 0.8 | Warning seconds before a fall fills. >= 0. |
| `hazards.drift_sec` | same | 2.0 | Seconds between wind drifts (x the drift multiplier, sandstorm 0.5). > 0. |
| `hazards.wind_shift_sec` | same | 8.0 | Seconds between wind direction changes (seeded; a shift always turns to one of the 3 other directions). > 0. |
| `mire_immune` | match entry | false | The boss ignores mire (no tick damage, no step slow). |

A bad value keeps its default (warning). Code hooks: `UnitMover.step_cost_fn` (Callable(from_cell) -> float, after `cooldown_scale`), sand blocks through `UnitMover.add_blocker`, `FieldDrops.bury_cells(cells) -> int`, `FieldDrops.drift_pieces(dir, blocked_fn, dragged_cells) -> int` (signal `point_moved(point, old_cell)`), `FieldDrops.wind_offset_fn` (Callable() -> Vector2i; a new drop lands one cell along it when that cell is free), `CombatView.get_hazards()` and trait ctx key `hazards`. Drops never land on sand or sand-warning cells.

### Story 036 boss traits (match `traits[].params`; code defaults = the values below)

| Trait | Param | Default | Meaning |
|---|---|---|---|
| `spore_burst` | `spread_cells` | 2 | Each hit on the boss mires the player's cell plus up to this many real neighbours (seeded) |
| | `spore_mire_sec` | 4.0 | Seconds the spore mire lasts |
| | `icd_sec` | 1.5 | Internal cooldown between two bursts |
| `hop_skip` | `hop_every` | 3 | After this many boss steps the next move is a straight 2-cell hop over the middle cell (seals, thorns ignored; destination real, not sealed, not sand) |
| | `hop_warn_sec` | 0.4 | Seconds the destination shadow shows before the hop (boss steps locked meanwhile) |
| `bog_spread` | `interval_sec` | 8.0 | Seconds between two mire spreads on the player's half |
| | `cells` | 2 | Cells per spread (escape cells first while the boss casts >= `min_swing_cells`, else seeded) |
| | `mire_sec` | 5.0 | Seconds the spread mire lasts |
| | `min_swing_cells` | 3 | Smallest boss cast that turns on the escape-cell priority |
| | `escape_steps` | 2 | Reach of the player used to find its escape cells |
| | `first_delay_sec` | = interval | Seconds before the first spread |
| `burrow` | `interval_sec` | 7.0 | Seconds between two burrows (waits for a cast in progress) |
| | `burrow_sec` | 1.5 | Seconds underground: untargetable (a landing cast misses, its zone still forms), no decisions |
| | `surface_warn_sec` | 0.5 | The surface cell (seeded free cell of its half) shows for the last this-many seconds of the burrow |
| | `first_delay_sec` | = interval | Seconds before the first burrow |
| `riposte` | `min_cells` | 4 | A player cast of at least this many cells that hits the boss triggers a counter |
| | `warn_sec` | 0.4 | Warning on the player's cell at the moment of the hit (not re-aimed) |
| | `damage` | 10.0 | Damage if the player is still on that cell when the warning ends |
| `sandstorm` | `interval_sec` | 12.0 | Seconds between two storms |
| | `storm_sec` | 3.0 | Storm length (HUD bar) |
| | `drift_mult` | 0.5 | TileHazards drift multiplier during the storm (back to 1 after) |
| | `extra_sand` | 2 | Seeded player-half cells sent to TileHazards.add_sand at storm start (leave-a-path kept) |
| | `sand_sec` / `sand_warn_sec` | combat.json `hazards` | Sand duration / warning override (<= 0 = the hazards default) |
| | `first_delay_sec` | = interval | Seconds before the first storm |

HUD getters: `HopSkipTrait.get_hop_target()/get_hop_warn_left()`, `BurrowTrait.is_burrowed()/get_surface_cell()/get_surface_warn_left()`, `RiposteTrait.get_riposte_cell()/get_riposte_warn_left()`, `SandstormTrait.is_storm()/get_storm_fraction()`. Untargetable hook: `BossTrait.untargetable()` -> `TraitHost.is_boss_untargetable()` -> `SwingArbiter.enemy_untargetable_fn` (set by TraitHost from ctx `arbiter`) -> CutEffects option `target_untargetable`.

## Story 037 (W2): locked content keys, `heal_self`, three new shapes (`cards.json`, `pieces.json`, `relics.json`)

| File | Key | Type | Meaning |
|---|---|---|---|
| `cards.json` card | `heal_self` | number >= 0 (HP) | HP the CASTER (player swings only) heals when the cut lands, hit or miss, capped at max HP (`CutEffects.apply` ONE point, then `CombatState.set_player_hp`). Result key `healed` = HP actually restored. Used by `thanh_thuy` (4). Not upgradable. 0 / absent = none |
| `cards.json` card | `unlock_by` | achievement id | Human cross-reference: the achievement in `achievements.json` whose `rewards` unlock this card. Absent = open from the start. Ignored by `SkillConfig` (the `rewards` list is the runtime source of truth) |
| `pieces.json` shape | `unlock_by` | achievement id | Same, for a shape. Ignored by `PieceLibrary` |
| `relics.json` relic | `unlock_by` | achievement id | Same, for a relic. Ignored by `RelicConfig` |

New cards: `gai_doc` (common thorns, 3 cells, 2 dmg/cell on a hit, 1 Ran per thorn entry), `luoi_san` (removed 2026-11-01, ADR-0001 Phase 1), `thanh_thuy` (common frost, 3 cells, 1 Han, `heal_self` 4), `bang_tam` (rare damage, 4 cells, 5 dmg/cell, 2 Han). `gai_doc` is a zone card (kept out of the boss's card list).
New default-pool shapes (5 cells; weights 0.25 in `default ch2 ch3` and 0.125 in `ch1 swamp desert`, tuned x0.25 from the story's 0.5-1.0 because the unlocked shapes cost the bot 11-13 points of run win: production/qa/evidence/unlocks-achievements/simulation-characters.md): `w5` staircase `[[0,0],[0,1],[1,1],[1,2],[2,2]]`, `n5` `[[0,0],[0,1],[1,1],[1,2],[1,3]]`, `v5` `[[0,0],[0,1],[0,2],[1,2],[2,2]]`. Test: `tests/unit/run/unlock_content_test.gd`.

## `achievements.json` (Story 037, read by `src/run/achievements_config.gd`, class AchievementsConfig; evaluated by `src/run/unlock_rules.gd`, class UnlockRules)

22 achievements. The `rewards` lists are the SINGLE runtime source of "what is locked": content that is not the reward of any achievement is open from the start. The `unlock_by` keys in `cards.json`, `pieces.json`, `relics.json` and `characters.json` (the achievement id) are the human cross-reference; `tests/unit/run/unlock_content_consistency_test.gd` asserts both agree in both directions. Unlocks only widen the pools (card rewards, piece pool, relic pool, region pool, character select); no permanent power.

| Key | Type | Meaning |
|---|---|---|
| `achievements[].id` | string | Unique id (duplicate -> warning, later dropped) |
| `achievements[].name_key` / `desc_key` | translation keys | `achievement.<id>.name` / `.desc` (the desc states the condition in one line; the UI appends " - current/target" for milestone conditions) |
| `achievements[].condition` | `{type, params}` | One of the types below. Unknown type or a missing / non-positive param drops the entry (warning) |
| `achievements[].rewards` | array of `{kind, id}` | `kind` is `character`, `card`, `piece`, `relic` or `region`; may be empty. Content already rewarded by an earlier achievement drops the entry (warning) |
| `achievements[].hidden` | bool (default false) | Shown as "???" in the list until earned |

Condition types (`UnlockRules.process(cfg, progress, event)`; events are built by GameFlow after it wrote the milestones of a completed node / ended run):

| `type` | `params` | Meaning | Evaluated on |
|---|---|---|---|
| `milestone` | `key`, `min` | `ProgressState.get_milestone(key) >= min` | every event (self-heals) |
| `milestone_sum` | `prefix`, `min` | sum of the milestones whose key starts with `prefix` is `>= min` | every event |
| `run_counter` | `key`, `min` | `event.run_stats[key] >= min` (RunSession stats after adding the match) | `match_won`, `run_ended` |
| `match_counter` | `key`, `min` | `event.match_stats[key] >= min` (that match's stats) | `match_won` |
| `boss_clear_deck` | `min_cards` | a region boss match won (`is_region_boss`) with at least `min_cards` BURN cards in `deck_ids` (duplicates count). A card is a burn card when its `cards.json` definition has `"effect": "burn"` or a `burn_stacks` value above 0 (today: `hoa_tinh`, `hoa_xa`, `hoa_tran`, `liet_hoa`, `thien_hoa`) | `match_won` |
| `boss_clear_no_hit` | none | a region boss match won with `match_stats.hits_taken == 0` (the key must be present) | `match_won` |
| `run_won_deck_max` | `max` | the run is won (`won`) with `1 <= deck_ids.size() <= max` | `run_ended` |

Events: `{"type":"match_won","character_id","region_id","is_region_boss","is_final","match_stats","run_stats","deck_ids"}`, `{"type":"final_reached"}`, `{"type":"run_ended","won","ending_id","character_id","run_stats","deck_ids"}`. A contextual condition (`run_counter`, `match_counter`, `boss_clear_*`, `run_won_deck_max`) is never granted by another event type, and nothing is granted retroactively on a migrated save.

Milestone keys written to `ProgressState` (only at save points: end of a boss node, end of a run): `region_boss:<region_id>`, `reached_final`, `runs_won`, `runs_won:<character_id>`, `kills_total`, `spares_total`, `ending:<ending_id>`.

Shipped table: `first_region_boss` (milestone_sum `region_boss:` 1 -> card `gai_doc`), `reach_an_dai` (`reached_final` -> piece `w5`), `first_run_won` (`runs_won` -> relic `tui_rong`), `hunter_path` (`kills_total` 3 -> character `tho_san`), `mercy_path` (`spares_total` 3 -> character `giao_si`), `ending_mercy` (`ending:spare` -> relic `phong_an`), `ending_middle` (`ending:balance` -> card `bang_tam`), `ending_slaughter` (`ending:execute` -> relic `gai_ran`), `boss_forest` (`region_boss:ch1` -> piece `v5`), `boss_dungeon` (`region_boss:ch2` -> card `gai_nguyen`, was `luoi_san` before the 2026-10-31 quick spec), `boss_frost` (`region_boss:ch3` -> card `thanh_thuy`), `zone_trap` (hidden, run_counter `boss_thorn_steps` 5 -> piece `n5`), `frost_burst_5` (match_counter `frost_bursts` 5 -> relic `han_ky`), `win_kiem_si` / `win_phap_su` / `win_sat_thu` / `win_tho_san` / `win_giao_si` (`runs_won:<id>`), `burn_build` (boss_clear_deck 4), `featured_10` (run_counter `featured_casts` 10), `no_hit_boss` (hidden), `small_deck` (hidden, run_won_deck_max 8). The story names the third new shape `y5`; that id already exists as a run-only Ink shape, so the shape is `v5`.

### Progress save v7 (`ProgressState.VERSION` 7, Story 037)

New keys on top of v6 (a v7 file round-trips exactly; files v1..v6 still load and re-save as v7):

| Key | Type | Meaning |
|---|---|---|
| `milestones` | object `{key: int > 0}` | The milestone ledger (keys above). `add_region_boss_beaten` (+1 on `region_boss:<r>` on every call, the list stays deduped), `record_fate` (+1 `spares_total` / `kills_total`), `record_ending` (+1 `ending:<id>`), `record_run_won(character_id)` (+1 `runs_won` and `runs_won:<character_id>`), `record_final_reached()` (+1 `reached_final`) keep it in step |
| `achievements` | array of ids | Earned achievements, earned order, no duplicates (`add_achievement` returns true when new) |
| `seen_unlocks` | array of `"kind:id"` | Unlocked content the player has already seen (`mark_unlock_seen`); `is_new_unlock(kind, id)` = owner achievement earned and not in this list (drives the "New" mark) |

Migration of a v1..v6 file: `milestones` = `region_boss:<r>` 1 for each region in `regions_boss_beaten` (v4 `cleared_chapters` included), `spares_total` / `kills_total` from `spare_total` / `execute_total`, `ending:<id>` 1 for each `endings_seen`; `achievements` empty and `seen_unlocks` empty (no retroactive grants: the first `UnlockRules.process` after load grants the milestone-type achievements the ledger already satisfies). Dev `--progress=all` = `ProgressState.mark_all_unlocked(cfg, region_ids)`.

### `unlock_by` keys

`cards.json` cards, `pieces.json` shapes, `relics.json` relics and `characters.json` characters carry an optional `unlock_by` (an achievement id); none = open from the start. Only the content named in the table above is locked: 4 cards (`gai_doc`, `gai_nguyen`, `thanh_thuy`, `bang_tam`), 3 shapes (`w5`, `n5`, `v5`), 4 relics (`tui_rong`, `phong_an`, `gai_ran`, `han_ky`) and 2 characters (`tho_san`, `giao_si`); every other card, shape and relic is open from the start. A run takes its locked set at its start (`RunSession.locked`), so an unlock mid-run changes nothing for that run.

## `kiep_levels.json` (Story 038: Kiep levels)

Read by `KiepRules` (`src/run/kiep_rules.gd`, pure). Kiep only makes the game harder (no permanent power). Level 0 is the game exactly as without Kiep (every `KiepRules` function returns an equal copy / the base number). Level k applies the rules of levels 1..k in order; stacked multipliers are bounded by `clamp`. An unknown rule `type` = warning, that rule dropped (the level stays); a bad number (not a number or <= 0) = warning, the documented default kept; a row with no valid `level` (integer >= 1) or a duplicate level is skipped. The shipped file has 10 levels, ordered by the difficulty each rule adds alone (Story 038 sim, `--kiep-only`, Kiem si: gold -2.9 points, rest 0, danger 0, floor_shift -7.1, shop + final trait -10, floor heal / max HP / player drop / swing about -11.4, region boss trait -12.9):

| Level | Rule(s) | Shipped |
|---|---|---|
| 1 | `gold_mult` | 0.75 |
| 2 | `rest_heal_mult` | 0.67 |
| 3 | `node_weight` | danger x2 |
| 4 | `floor_shift` | shift 1, final hp x1.1 |
| 5 | `shop_price_mult` + `boss_extra_trait` (scope `final`) | 1.2; pool `thorn_field`, `slam` |
| 6 | `floor_heal_mult` | 0.5 |
| 7 | `max_hp_mult` | 0.85 |
| 8 | `player_drop_mult` | 1.15 |
| 9 | `boss_swing_mult` | 0.909 |
| 10 | `boss_extra_trait` (scope `region_boss`) | pool `row_burner`, `seal_caster`, `thorn_field`, `slam` |

| Key | Type | Meaning |
|---|---|---|
| `clamp` | object | Bounds on the STACKED multiplier of a rule type (keys below; an unknown key warns) |
| `levels[]` | array | One row per level 1..10: `{level, name_key, desc_key, rule}` |
| `levels[].name_key` / `desc_key` | translation keys | `kiep.level.N.name` / `kiep.level.N.desc` (the desc states the rule and its number in one line; shown in the select screen's rule list) |
| `levels[].rule` | `{type, params}` or an array of them | Level 5 has two (`shop_price_mult` + `boss_extra_trait` scope `final`) |

Rule types (fixed in code; numbers here). Every `mult` is a number > 0; the shipped starting values are in the last column:

| `type` | `params` | Applied at | Effect | Shipped |
|---|---|---|---|---|
| `boss_extra_trait` | `trait_pool` (array of `{id, params}`, `id` a `TraitRegistry` key), `count` (int >= 1, default 1), `scope` (`region_boss` = a `boss` node that is not the final, or `final` = the final match) | `KiepRules.apply_match` (match creation, `RunConfig.from_node`) | Appends `count` traits drawn from `trait_pool` with the seed `hash([run_seed, floor, match_id])` (+ the rule's index), never one the match already has; no candidate left = nothing added. A phased match (`phases`, the final) gets the same trait in EVERY phase's `traits` (a `phases` match ignores its top-level `traits`) | level 10: pool `row_burner`, `seal_caster`, `thorn_field`, `slam`, scope `region_boss`; level 5: pool `thorn_field`, `slam`, scope `final` |
| `node_weight` | `kind` (node kind, default `danger`), `mult` | `KiepRules.apply_map_spec` (region map generation) | `ChapterMapGen` has no weight table: a column's `kinds` filler list is drawn uniformly, so the weight of a kind is its number of copies in that list. The rule multiplies the copies of `kind` (mult rounded, at least 1) in the BRANCH columns only (not the first, not the last = boss column) | 2.0 (danger x2) |
| `rest_heal_mult` | `mult` | `KiepRules.rest_heal_ratio` (rest camp) | heal ratio x mult | 0.67 |
| `player_drop_mult` | `mult` | `apply_match` | NEW match key `player_drop_interval_mult` (default 1.0, > 0; multiplies the PLAYER's field piece drop interval, > 1 = slower drops, like `boss_drop_interval_mult` for the boss) x mult | 1.15 |
| `gold_mult` | `mult` | `KiepRules.economy_mult("gold")` | gold of a node x mult | 0.75 |
| `boss_swing_mult` | `mult` | `apply_match` | match `swing_speed_mult` x mult. `swing_speed_mult` scales the windup (< 1 = FASTER swings), so the shipped 0.909 (= 1 / 1.10) makes bosses wind up 10 % faster | 0.909 |
| `floor_heal_mult` | `mult` | `KiepRules.floor_heal_ratio` (heal when a region boss falls) | heal ratio x mult | 0.5 |
| `max_hp_mult` | `mult` | `KiepRules.apply_run_start` (run start) | character `max_hp` x mult (rounded, at least 1), the same value for the whole run | 0.85 |
| `floor_shift` | `shift` (int >= 0, default 1), `final_hp_mult` (> 0, default 1.1) | `KiepRules.scaling_floor` / `final_extra` (match creation) | Enemies use the `floor_scaling` row of floor + `shift` (never past the `final` row); on the last floor and the final match `hp_mult` is multiplied by `final_hp_mult` on top | shift 1, final hp x1.1 |
| `shop_price_mult` | `mult` | `KiepRules.economy_mult("shop_price")` | shop prices (cards, relics, services) x mult | 1.2 |

`clamp` keys (the stacked product of every rule of the type is bounded; defaults in the code when a key is absent): `node_weight_mult_max` 4.0 (copies of the kind), `rest_heal_mult_min` 0.25, `player_drop_mult_max` 1.5 (player drop interval at most x1.5), `gold_mult_min` 0.4, `boss_swing_mult_min` 0.6, `floor_heal_mult_min` 0.25, `max_hp_mult_min` 0.4 (max HP never below 40 % of the original), `floor_shift_max` 2 (total shift), `final_hp_mult_max` 1.5, `shop_price_mult_max` 2.0.

`KiepRules.set_only(level)` is for the balance sim only: every level > 0 then applies just that one level's rules, to measure one rule alone.

New string keys: `kiep.level.1.name` .. `kiep.level.10.name` and `kiep.level.1.desc` .. `kiep.level.10.desc`.

### Kiep save keys (Story 038: progress v8, run save v7)

`ProgressState.VERSION` 8 adds `kiep_unlocked` ({character_id: int 0..10}, the highest selectable level) and `kiep_best_won` ({character_id: int}, the highest level won; -1 / absent = never won). A win at level k sets `kiep_best_won = max(best, k)` and `kiep_unlocked = max(unlocked, min(k + 1, 10))`; a loss or a win below the unlocked level changes nothing (`ProgressState.record_kiep_result`). v1..v7 files load with every character at 0 / -1.

`RunSession.SAVE_VERSION` 7 adds `kiep_level` (int 0..10, chosen before the run, fixed for the whole run; clamped on load; absent = 0, so a v6 run save loads at Kiep 0).

## Story 039 (W1): lava vents and crumbling cells (`combat.json` `hazards`, match overrides; `src/combat/tile_hazards.gd`)

The same `hazards` block of Story 036 gains nine keys (each also overridable by a match key of the same name, `RunConfig.HAZARD_OVERRIDE_KEYS`; a bad value keeps its default with a warning, `TileHazards.clean`).

| Key | Default | Meaning |
|---|---|---|
| `hazards.vent_interval_sec` | 7.0 | Seconds between two vent eruptions of the arena (one seeded idle vent of either half starts each time; > 0). The `phase_shift` of `inferno_lord` multiplies it (`TileHazards.set_vent_interval_mult`). |
| `hazards.vent_warn_sec` | 1.0 | Warning seconds before a vent erupts (>= 0; 0 = erupt at once). |
| `hazards.vent_sec` | 2.0 | Seconds the erupted vent burns its cells (> 0). The caller (CombatView on `vent_erupted`) lights the cells through the SAME `StatusEffects.ignite` as `row_burner` / Hoa tran and burns the field pieces lying there (`FieldDrops.bury_cells`); vents never block a step. |
| `hazards.vent_tick_sec` | 0.5 | Burn tick cadence of an erupting vent cell (> 0; handed to `StatusEffects.ignite`). Not in the story's key list: the burn numbers must come from data. |
| `hazards.vent_tick_damage` | 2.0 | Damage per burn tick (>= 0; same as the `row_burner` default). |
| `hazards.crumble_after_sec` | 2.0 | Seconds a unit stands on ONE cell before it cracks (arena `crumble: true`; > 0). The standing time restarts when the unit changes cell. |
| `hazards.crumble_warn_sec` | 0.6 | Crack warning seconds before the cell falls (>= 0). A cracking cell can still be stepped on. |
| `hazards.fall_sec` | 4.0 | Seconds a fallen cell stays blocked (> 0), then it is restored. |
| `hazards.fall_damage` | 8.0 | Damage a unit takes when the cell under it falls and pushes it off (>= 0; applied by CombatView through `CombatState.damage`). |

Arena side (W2): `arenas.json` shape `hazards.vents` = `{"player": [{"row": r} | {"col": c}, ...], "enemy": [...]}` in SIDE coordinates and `crumble: true`; `ArenaLibrary.hazards_for_match` returns `vents_player`, `vents_enemy` (Array of Array[Vector2i]) and `crumble` (bool), read by CombatView with defaults.

Model API (`TileHazards`): signals `vent_warned/vent_erupted(side, vent_index, cells)`, `vent_ended(side, vent_index)`, `cell_crumbling(side, cell)`, `cell_fell(side, cell, occupant_pushed)`, `cell_restored(side, cell)`; `set_vents`, `enable_crumble`, `trigger_vent`, `trigger_vents(side, count, prefer_cell)`, `drop_cells(side, cells, fall_sec, warn_sec)` (island_drop; leave-a-path via `ZoneRules.fit_cells`, never the last standing island), `set_vent_interval_mult`, `islands(side)`, getters `is_venting`, `is_vent_warning`, `vent_cells`, `vent_warn_left`, `vent_burn_left`, `vent_count`, `vent_timer_left`, `is_fallen`, `fallen_cells`, `fallen_left`, `fall_total_sec`, `crumble_progress`, `is_crumble_warning`, `crumble_warn_left`, `crumble_enabled`, `config_value(key)` and `stats()` = `{pushes, vent_ticks, fall_damage_total, vent_damage_total}` (counters for the simulation; the vent numbers are estimated from the unit cells). A falling cell with a unit on it pushes the unit to the nearest open neighbour that itself keeps an exit (the model moves the unit through `CombatState.set_*_cell`); with no such neighbour the cell does not fall. A fallen cell is the fourth blocker source of `UnitMover.add_blocker` (crack, seal, sand, fall) and new field drops never land on it.


## Story 039 data (W2): regions `hellfire` / `sky_isles`, arena keys `hazards.vents` / `crumble`, condition `best_floor`

**Regions** (`chapters.json`, appended after `desert`; `world.region_pool` is now 7: `ch1 ch2 ch3 swamp desert hellfire sky_isles`). Same shape as `swamp` / `desert` (9 matches each: 6 normal, 2 breakers in the `miniboss` pools, the boss alone in `boss`). Hellfire: `imp` 92, `ember_hound` 110, `ash_golem` 132 (defense 3), `flame_cultist` 128 (`row_burner`), `magma_slug` 140, `hell_knight` 156 (defense 2); breakers `fire_eater` 90 (`burn_eater {heal_ratio 1.0}`), `ash_phoenix` 74 (`rebirth {revive_ratio 0.4, revive_sec 1.5}`); boss `inferno_lord` 180 aggressive (`vent_surge {interval_sec 10, vents 2}` + `phase_shift {at_hp_ratio 0.5, brain_set aggressive, step_mult 1.0, extra_traits [], vent_interval_mult 0.7}`). Sky isles: `cloud_sprite` 88, `harpy` 104, `wind_monk` 118, `storm_eagle` 126 (lowest step cooldown mult of the region), `sky_sentinel` 144 (defense 3), `thunder_shaman` 150 (`row_burner`); breakers `gale_bird` 86 (`gust {interval_sec 6, warn_sec 0.6}`), `cloud_veil` 96 (`shroud`); boss `storm_dragon` 185 (`island_drop {interval_sec 11, fall_sec 4, warn_sec 1.2}` + a light `gust {interval_sec 12}`). Hellfire matches alternate the arenas `forge` / `caldera`; every sky_isles match runs on `twin_isles`, `three_isles` or `islands_bridge` with the match-level arena key `"crumble": true` (`{"shape": "islands_bridge", "crumble": true}`; the shape itself stays non-crumbling for the other regions). `weights.hellfire` / `weights.sky_isles` in `pieces.json` (hellfire leans 4-5 cell pieces with `mono` / `bar2` 8; sky_isles leans 1-3 cell pieces; the three Story 037 shapes 0.125-0.25). The regions' unlock is `reach_floor_4` / `reach_floor_5` below (no `unlock_by` key on the chapters: the `rewards` list is the runtime source).

**Arena keys** (`arenas.json`, optional, checked by `ArenaValidator`):

| Key | Type | Meaning |
|---|---|---|
| `hazards.vents` | `{player: [line, ...], enemy: [line, ...]}` | Lava vents per half. A `line` is `{"row": r}` or `{"col": c}` (exactly one key) in SIDE coordinates (the same as `missing_cells`: side col 0 = farthest from the divider on both halves); the vent's cells = every REAL cell of that half on the line. A line with no real cell is rejected. `ArenaLibrary.hazards_for_match` returns `vents_player` / `vents_enemy`: an Array with one `Array[Vector2i]` (BoardGrid cells) per vent |
| `crumble` | bool | Cells stood on crumble (TileHazards). A match-level `arena` block that names a shape may also carry `"crumble": true/false` (wins over the shape). Validator: every real cell of each half is connected to the unit start cell, and every island has >= 2 cells (`ArenaValidator.CRUMBLE_MIN_ISLAND_CELLS`). `hazards_for_match` returns `crumble: bool` |

`ArenaValidator.bridge_cells(grid, player_half)` = real cells with exactly two real neighbours on opposite sides whose removal splits the half (a one-cell-wide straight corridor); `ArenaValidator.island_cells(grid, player_half)` = the 4-connected components of the half without its bridge cells (an arena without a bridge has one island: the whole half); `components_of(cells)` is the shared helper. New shapes: `forge` (5x3, row vents 0 and 1 per half, burn), `caldera` (5x5, side cells (3,1) (3,2) (3,3) missing, column vents 1 and 4, burn), `twin_isles` (6x3, bridge (2,1): islands of 4 and 9 cells, crumble, pin), `three_isles` (7x2, bridges (2,1) and (5,1): islands of 4, 4 and 2 cells, crumble, pin).

**Condition type `best_floor`** (`achievements.json`): `params {min}` (positive int): `ProgressState.get_best_floor() >= min`; evaluated on every event like `milestone`; `UnlockRules.progress_of` = `min(best floor, min) / min`. New achievements, appended after `small_deck`: `reach_floor_4` (`best_floor` 4 -> region `hellfire`) and `reach_floor_5` (`best_floor` 5 -> region `sky_isles`), name / desc keys `achievement.<id>.name|desc`. The table above ("22 achievements") is now 24.

## Phase 2 (P2.2): `enemy_skills.json` and the pattern brain (`chapters.json` `brain` / `enemy` / `pattern_tempo_mult`)

Spec: `design/quick-specs/phase2-misty-forest-2026-11-01.md`; ADR-0001. Read by `src/combat/enemy_skills_config.gd`
(class EnemySkillsConfig, pure: `load_from_file` / `from_dictionary`). Bad data never crashes: a broken skill or enemy is
dropped and the reason goes to `EnemySkillsConfig.problems` (the shipped file must load with `problems == []`, checked by
`tests/integration/run/pattern_dodge_test.gd`). Missing blocks / keys use the code defaults listed here.

Top level: `{ "version": 1, "fairness": {...}, "ai": {...}, "defaults": {...}, "statuses": {...}, "skills": {...}, "enemies": {...} }`.

| Block | Key | Type / unit | Meaning | Default |
|---|---|---|---|---|
| `fairness` | `reaction_margin_sec` | sec | Margin added to the hero's escape time (F1, `FairnessCheck.t_need`) | 0.25 |
| | `max_red_ratio` | 0..1 | Red (warned) cells at once / usable player cells, trait warnings included (F2) | 0.5 |
| | `cc_grace_sec` | sec | No new root / slow until this long after the hero's last step lock ended (F4, `StatusEffects.since_lock_ended`) | 1.0 |
| | `min_gap_between_warnings_sec` | sec | Minimum time between two warnings (F5) | 0.4 |
| | `followup_min_warning_sec` | sec | A followup warning below this drops the skill (problem) | 0.75 |
| | `heavy_recovery_sec` | sec | Recovery at or above this counts as heavy for the gap (F5) | 1.2 |
| `ai` | `punish_standing_still` | mult | Weight on skills covering a hero who stood still `standing_still_sec` | 1.2 |
| | `standing_still_sec` | sec | | 1.5 |
| | `avoid_repeat_last_skill` | mult | Weight of the last skill used | 0.45 |
| | `favor_phase_mechanic` | mult | Weight of the phase's `mechanic` skill | 1.25 |
| | `noise` | 0..1 | Seeded random spread on the weights | 0.1 |
| | `cancel_cooldown_ratio` | 0..1 | Share of the cooldown applied when a skill is interrupted | 0.5 |
| `defaults` | `windup_sec`, `recovery_sec`, `weight`, `interruptible`, `phase_transition_sec`, `marker_life_sec`, `marker_break_min_cells` | | Per-skill / per-phase fallbacks | 0.5, 0.6, 1.0, true, 1.5, 12.0, 1 |
| `statuses` | `root {sec}`, `slow {sec, step_mult}`, `guard {amount, sec}`, `fragile {stacks}`, `frost {stacks}` | | Numbers a skill's `effects.status` / `guard` falls back to | 0.7; 1.5, 1.3; 3, 3; 1; 1 |

**`skills.<id>`**: `id`, `owner` (enemy id, doc only), `kind` (`attack` | `self` | `marker`, default `attack`),
`pattern {offsets: [[dx,dy]...], anchor, rotations: [0|90|180|270...], must_cover_player, clip, min_cells, start, count}`
(anchor one of `EnemySkillsConfig.ANCHORS`: `on_player`, `near_player`, `row_of_player`, `column_of_player`, `row_of_anchor`,
`fixed`, `self_cell`, `enemy_half_empty`, ...; `must_cover_player` defaults to true for on_player / row / column anchors),
`windup_sec` (enemy stands still, scaled by tempo), `warning_sec` (red cells shown; NEVER scaled by tempo), `delivery`
(`{type, origin, travel, impact}` of `SkillDelivery`), `effects {damage, status {id, sec|stacks}, zone {id: thorns|drop, ...},
guard {amount, sec, while_markers}, marker {life_sec, break_min_cells}}`, `followup {offsets, rotations, relative_to:
first_cells|first_end|first_center|player, warning_sec, show_with_first, requires_anchor, effects}`, `recovery_sec`,
`cooldown_sec`, `weight`, `interruptible`, `conditions {requires_anchor, ...}`, `counter_key`.

**`enemies.<id>`**: `tier` (`normal` | `elite` | `warden`, ...), `ai` (overrides of the `ai` block), and EITHER
`skills: [ids]` (one phase) OR `phases: [{id, enter_hp_ratio, skills, mechanic, every_nth {skill, n}, transition {sec,
on_enter: [{skill}]}, overrides {skill id: {key: value}}}]` (any number of phases and skills, A4).
`"dev": true` marks a DEV-ONLY fixture enemy (today `dev_pattern_dummy` and the 2x2 `dev_pattern_boss`, both with skills
`dev_prick` / `dev_bar`): no chapters.json match may name it (checked by `pattern_dodge_test.gd`); reach it with
`--pattern=dev_pattern_dummy` / `--pattern=dev_pattern_boss` (`src/dev/demo_args.gd`).

P2.2b (decision D13 / ADR-0001 A7) optional enemy keys:

| Key | Type | Meaning | Default |
|---|---|---|---|
| `footprint` | `[[dx, dy], ...]` | The cells the enemy stands on, as BOARD-space offsets from its anchor `CombatState.enemy_cell`, which is the footprint's top-left cell (smallest col, smallest row): `dx`, `dy` >= 0 and `[0, 0]` must be present. A 2x2 Warden = `[[0,0],[1,0],[0,1],[1,1]]`. A negative offset or a missing `[0,0]` is refused back to 1 cell with a problem line. Every move / spawn / push / fall checks the WHOLE footprint (`CombatState.enemy_fits`: each cell a real cell of the enemy half, not blocked). A hit counts ONCE per resolution however many footprint cells it covers (`CombatState.enemy_in`); a fire zone ticks once per tick; thorns / burn entry tolls once per step. Casts start from the footprint's front-centre cell (`CombatState.enemy_cast_origin`: nearest the divider, upper on a tie). Set by `PatternController` from this data | `[[0, 0]]` (1 cell, the pre-P2.2b rules; every block-brain Warden) |
| `arena` | string | An `arenas.json` shape id the dev launcher `--pattern=<id>` starts this enemy on (unless `--arena=` names one); a multi-cell `--pattern` enemy is also drawn as itself (match `id` = the enemy id), not with the run's first match sheet. Not read by runs: a chapters.json match sets its own `arena` | `""` |

**`chapters.json` match keys** (read by `RunConfig._apply_brain`; carried ONLY when the match has `brain`, so a match
without it keeps exactly the keys it had before Phase 2):

| Key | Type | Meaning | Default |
|---|---|---|---|
| `brain` | `"block"` \| `"pattern"` | Which enemy brain plays the match. Unknown value -> `"block"` + warning; `"pattern"` without `enemy` -> `"block"` + warning | absent = block brain |
| `enemy` | string | `enemies` id of enemy_skills.json (pattern brain only). An id missing from the file warns in CombatView and the match keeps only the BossBrain's movement | — |
| `pattern_tempo_mult` | number > 0 | Scales windup / cooldown / recovery of the pattern skills (never `warning_sec`). `RunConfig.from_node` multiplies the authored value by the region's `region_normalize.step_mult` and the floor's `floor_scaling.step_mult` | 1.0 |

A pattern match picks up no field pieces on the enemy half (no boss piece hand); the BossBrain still moves the enemy
between skills and the mover holds it still while a skill runs (`PatternController.is_busy`).

### Phase 2 P2.3: the Misty Forest roster (`enemy_skills.json` + `chapters.json` `ch1`)

Spec: `design/quick-specs/phase2-misty-forest-2026-11-01.md` 5.1-5.5 and the user decisions D1-D14 at its end. Five
`enemies` (all 1 cell, no `dev`): `rootling` (normal: `root_prick`, `creep`), `mossbound_sentry` (normal: `slab_tap`,
`brace`), `greycap_sporeling` (normal: `spore_squares`, `seedbed`), `ancient_root_sentinel` (elite: `sentinel_anchor`,
`branch_net`, `bark_shift`; phase `main` with `mechanic` `sentinel_anchor`), `mistbriar_matron` (elite: `thorn_fork`,
`wreath_guard`). Their `arena` hint is the shape of their own match (square / rect / u_shape / rect / cross).
Substitutes the decisions fix: Poison is Phase 4 (D3), so `spore_squares` applies 1 Fragile (Rạn) and `seedbed` leaves
Thorns (Bãi Gai, 3 s, 6 damage, +1 Fragile); the Sentinel's "barrier" `bark_shift` is a DROP TILE (D6: `zone {id: drop,
warn_sec 0.8, hole_sec 1.2}` through `ZoneRules.cast_drop`, the 31/10 drop-tile rules); Root = step lock (D2, 0.7 s
Rootling, 0.8 s Sentinel on the net's first cell only); Guard = temporary armor that Pierce ignores (D5: +3 for 3 s
Sentry, +5 Matron while its wreath stands, max 8 s).
Authored HP (`chapters.json` `boss_max_hp`, decision D8 "pack budget", spec 5.1): in-game HP = `boss_max_hp` x
`region_normalize.hp_mult` (0.75 in `ch1`) x `floor_scaling.hp_mult`; reference floor 3 (0.75 x 0.85 = 0.6375); hero
standard HP 200 (`kiem_si`); a normal = 0.55-0.85 x 200, an elite = 1.5-2.2 x a normal (140). Written: `rootling` 190
(0.60), `greycap_sporeling` 220 (0.70), `mossbound_sentry` 250 (0.80), `mistbriar_matron` 400 (1.8 x 140),
`ancient_root_sentinel` 420 (1.9 x 140). The kept matches (goblins, wolves...) keep their numbers.

New optional skill keys (P2.3, read by `EnemySkillsConfig`; unknown values refuse the skill with a problem line):

| Key | Type | Meaning | Default |
|---|---|---|---|
| `name_key` | string | strings.csv key of the skill's name (`enemy_skill.<id>.name`); `counter_key` = its "how to dodge" line (`enemy_skill.<id>.counter`) | `""` |
| `effects.marker.kind` | string | What the marker is, for drawing only: `anchor` (root anchor, dark wood square) or `wreath` (dark moss square). FloorLayer draws markers under the red, never red, no glow | `anchor` |
| `effects.marker.break_stun_sec` | number >= 0 | Breaking this marker (a player cast of >= `break_min_cells` cells over it) stuns the enemy this long: it stands still, casts nothing, and the skill in progress is cancelled at once (red off, its followup dropped, cooldown x `ai.cancel_cooldown_ratio`). Sentinel anchor: 1.0 with `break_min_cells` 2 | 0 (no stun) |
| `effects.move` | `{to: "adjacent_row"}` | A `self` skill that moves the enemy one row up or down on its half (Rootling `creep`). The target is chosen when the windup starts, shown as an ivory frame (`PatternController.move_target_cell`, never red) and taken when the windup ends if still free (no hole / crack / marker); no free cell = the skill cannot be cast | absent |
| `followup.delay_sec` | number >= 0 | Seconds the enemy holds still after the first strike before the followup's warning starts; the followup cells are chosen and fairness-checked THEN, and `requires_anchor` is re-checked (Sentinel `branch_net`: 1.3, so the repeat lands 2.5 s after the first strike with its own 1.2 s warning) | 0 (warning at once, P2.2) |
| `followup.relative_to: "same_cells"` | enum value | The followup strikes exactly the first strike's cells again (offsets ignored); a cell that became invalid drops the followup | — |
| `pattern.row` | `"any"` \| `"player"` | For an `enemy_half_empty` skill: `player` keeps only the empty enemy-half cells in the player's CURRENT row (read when the marker is placed; the halves' rows line up) when there is at least one, and the controller picks one of them at random (seeded); with none it falls back to any empty cell. Another value refuses the skill. Shipped: `sentinel_anchor` = `player` (so `branch_net`, which strikes the anchor's row, starts on the player's row) | `any` |
| `conditions.player_aimed_within_sec` | number | The skill may only be chosen within this many seconds after the player placed a block covering the enemy (`PatternController.on_player_aim`, called by `CombatView.confirm_placement` for the first block of a cast and every joined block). Rootling `creep`: 1.0 | absent = no condition |

`chapters.json` match key (P2.3, decision D10):

| Key | Type | Meaning | Default |
|---|---|---|---|
| `teach_after` | array of match ids | This match may only stand after an EARLIER column of the same map that makes every path fight one of these matches (all that column's nodes are fights with an id in the list, e.g. the 1-node first column). The map generator (`ChapterMapGen`, via `ChaptersConfig.get_map_spec().teach_after`) draws it like any other id of its pool / tier; when it is drawn and nothing earlier teaches it, the generator FORCES the earliest earlier column whose nodes are all `battle` / `danger` and can each take a listed id legal in that node's own pool (its kind at the column's tier, else the nearest lower tier) to such ids (a node already holding one keeps it; two gated elites share a column through the intersection of their lists; a later battle / danger node that then repeats an earlier id is redrawn while its pool allows). Only when no column can teach is the elite replaced by another match of the same pool / tier. The forcing uses its own rng stream, so a chapter without `teach_after` generates exactly as before. The shop / event pass never replaces a node in a column that teaches a drawn elite. Shipped: `ancient_root_sentinel` = `["rootling", "mossbound_sentry"]`, `mistbriar_matron` = `["greycap_sporeling", "rootling"]` | absent = no gate |

`ch1` pools (spec 5.5): battle 0 + `rootling`, `mossbound_sentry`; battle 1 + `rootling`, `mossbound_sentry`,
`greycap_sporeling`; battle 2 + `greycap_sporeling`, `mossbound_sentry`; danger 1 + `greycap_sporeling`; danger 2 +
`mossbound_sentry`; miniboss 1 + `ancient_root_sentinel`; miniboss 2 + `ancient_root_sentinel`, `mistbriar_matron`; boss
1 = `goblin_warlock`, boss 2 = `forest_witch` only (D11). The Forest Witch lost its `rotten_thrower` trait (D12; the trait
itself stays for the Jailer and the other matches that use it); its rework is P2.4.

Fairness change in P2.3 (`FairnessCheck.escape_path`, stricter than spec 4.1): the escape path never walks THROUGH a
hazard (Thorns, burning) or a cracking cell, so a plan that can only be escaped across Thorns is not fair and the
perfect dodger takes 0 damage (tests `tests/unit/combat/pattern_roster_fairness_test.gd`,
`tests/integration/run/pattern_roster_dodge_test.gd`).
