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

## pieces.json  (read by `src/pieces/piece_library.gd`)

Story 024: the puzzle-piece shapes the player drops and places on the enemy half, and their per-chapter drop weights. A missing or invalid file gives a warning and a built-in library with only the `mono` shape. Rotation (0..3 quarter turns clockwise, no mirroring) is not data: the drop draws it at random.

| Key | Type | Meaning | Default if missing |
|---|---|---|---|
| `shapes` | array | The shapes, in drawing order | mono only |
| `shapes[].id` | string | Unique id (`mono`, `bar2`, `bar3`, `l3`, `square`, `t4`, `l4`, `s4`, `bar4`, `plus5`, `u5`, `p5`, `bar5`); `rotten` is reserved for the rotten piece | - |
| `shapes[].cells` | array of `[x, y]` | UNROTATED cells relative to any origin (normalised on load, y grows downward); 1..5 distinct cells, edge-connected; an invalid shape is dropped with a warning | - |
| `shapes[].name_key` | string | `TEXT_*`-style translation key of the name (the strings live in `assets/i18n/strings.csv`) | `piece.<id>.name` |
| `weights` | object | Drop weights: `{ "default": {<shape id>: weight}, "<chapter id>": {<shape id>: weight} }`; chapter ids are those of `chapters.json` (`ch1`, `ch2`, `ch3`) | - |
| `weights.<map>.<shape id>` | number >= 0 | Relative chance of the shape being drawn; 0 = never. A chapter's map wins, else `default`, else 1.0 for a shape listed in neither. Shapes with no placement on the match's enemy half are skipped regardless of weight | 1.0 |

Current balance intent: chapter 1 favours 1-3 cell shapes (5-cell shapes rare, `bar5` 0.5 of 100), chapters 2-3 progressively more large shapes. Numbers are a starting point for tuning.

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
| `join_extra_sec` | number >= 0 | s | Story 028: card-choice time added when a second piece joins the open card menu | 1.5 |
| `max_cast_cells` | int >= 0 | cells | Story 028 fallback lock: a joined piece that would push the cast's total cells above this is refused; 0 = off | 0 |
| `zones` | object | - | Story 027 Ket gioi / Tran gai numbers, keys below (validated together in `CombatConfig._parse_zones`: one invalid -> all four fall back with a warning). A card overrides them per card (see cards.json `seal_sec`, `thorn_sec`, `thorn_damage`, `thorn_fragile_stacks`) | defaults below |
| `zones.seal_sec` | number > 0 | s | How long a sealed cell cannot be stepped INTO (a unit already inside is not pushed, but cannot re-enter once out) | 1.2 |
| `zones.thorn_sec` | number > 0 | s | How long a thorn cell lasts | 3.0 |
| `zones.thorn_damage` | number >= 0 | HP | Damage each time a unit CHANGES cell into a thorn cell (walk, push, teleport); standing in it when it forms does not trigger | 6 |
| `zones.thorn_fragile_stacks` | int >= 0 | stacks | Ran stacks added per entry into a thorn cell | 1 |

All five Story 023 keys are validated together in `CombatConfig._parse_keywords` (one invalid -> all five fall back) and passed to `StatusEffects.configure_keywords` by `configure_status`.
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
| `effect` | `damage` / `push` / `burn` / `pin` / `fragile` / `frost` / `seal` / `thorns` | - | What the swing does on resolve (Story 010). Story 023: `fragile` / `frost` apply the card's `fragile_stacks` / `frost_stacks` to the target when it stands in the covered cells (no direct damage). `burn`: every covered cell ignites whether or not the target stands there; burning cells take no new field points and refuse pick-up. `pin`: pins the target if it stands in the covered cells. Story 027 `seal` / `thorns`: form a Ket gioi / Tran gai zone over the covered cells on the target half, hit or miss (see `seal_sec` .. `thorn_fragile_stacks` below) | `damage` |
| `burn_duration_sec` | number >= 0 | seconds | Burn only: how long ignited cells burn; re-igniting resets the timer | 0 |
| `burn_tick_sec` | number > 0 | seconds | Burn only: interval of damage to a unit standing on a burning cell (<= 0 uses 0.5 with a warning) | 0.5 |
| `burn_damage_per_tick` | number >= 0 | HP | Burn only: damage per tick, per unit standing on the cell | 0 |
| `pin_duration_sec` | number >= 0 | seconds | Pin only: how long the target cannot step; re-pinning refreshes it | 0 |
| `rarity` | `common` / `rare` / `epic` | - | Card rarity (unknown -> common with a warning). Story 023 curve: rarity buys conditions, not damage per cell (commons 6-7, rares 7-8, epics 8 + a condition) | `common` |
| `fragile_stacks` | int >= 0 | stacks | Story 023: Ran stacks applied to the target on a hit (any effect) | 0 |
| `frost_stacks` | int >= 0 | stacks | Story 023: Han stacks applied to the target on a hit (any effect) | 0 |
| `pierce_defense` | bool | - | Story 023: the card's damage/push hit skips the match's `boss_defense` | false |
| `execute` | bool | - | Story 023: damage x2 when the target's HP <= combat.json `execute_ratio` x max HP | false |
| `execute_ratio` | number 0..1 | share | Card-level execute threshold overriding combat.json (0 = use `execute`) | 0 |
| `seal_sec` | number >= 0 | s | Story 027, effect `seal` only: this card's seal duration, overriding combat.json `zones.seal_sec`. Effect `seal` (Ket gioi) seals the cut cells on the TARGET's half when the swing arrives, HIT OR MISS (they cannot be stepped into; a unit already inside is not pushed), minus the cells the leave-a-path rule drops (`ZoneRules.fit_cells`: the target keeps at least one steppable neighbour, fewest cells dropped). A seal card with `damage_per_cell` > 0 (Long an) also deals the normal damage on a hit; with 0 a hit only applies its keywords | combat.json |
| `thorn_sec` | number >= 0 | s | Story 027, effect `thorns` only: this card's thorn duration (overrides `zones.thorn_sec`). Effect `thorns` (Tran gai) covers the cut cells on the target's half, hit or miss; thorns are never reduced by the leave-a-path rule | combat.json |
| `thorn_damage` | number >= 0 | HP | Story 027: damage per entry into one of this card's thorn cells (overrides `zones.thorn_damage`) | combat.json |
| `thorn_fragile_stacks` | int >= 0 | stacks | Story 027: Ran stacks per entry into one of this card's thorn cells (overrides `zones.thorn_fragile_stacks`; Gai nguyen = 2) | combat.json |
| `bonus_vs_fragile_mult` | number >= 1 | x | Story 023: damage multiplier while the target has Ran stacks, applied BEFORE the Ran stack is spent (song_kiem) | 1 |
| `upgrade` | object key -> number | additive delta | Per level above 1 (level 2 = one application, level 3 = two): keys `damage_per_cell`, `min_cells` (never below 1), `cooldown_sec` (never below 0), `burn_damage_per_tick`, `burn_duration_sec`, `pin_duration_sec`, `push_cells`, `fragile_stacks`, `frost_stacks`. Read through `SkillConfig.resolved(id, level)` | `{}` (warning) |
| `implemented` | boolean | - | False = shown locked ("not yet"); using it falls back to slash | false |

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

Per-chapter optional keys (Story 023): `intro_key` / `end_key` (`chapter.<id>.intro` / `chapter.<id>.end`, one line each in the CSV, shown by the run UI at chapter start / after the chapter boss), per-match `desc_key` (`match.<id>.desc`, one-line hint shown in the match intro for rule-breaker enemies and chapter bosses), `boss_defense` (number >= 0, flat armor subtracted per hit after Ghim/innate, min 1; Đốt and `pierce_defense` cards ignore it; default 0) and `boss_min_runes` (integer >= 0, the boss prefers sigils of at least this many cells; default 0). Escalation (OSFE §5): normal enemies HP x1.15 per chapter, `boss_step_cooldown_mult` -0.1 per chapter, `boss_defense` 0 / 2 / 4 for normals in ch1 / ch2 / ch3 (ghosts 12 / 16), `boss_min_runes` 2 for elites (reacter, jailer, fuse_golem, frost_mage) and 3 for the ch2 / ch3 bosses. Think / reaction never below 0.3 / 0.35 s.

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
| `frost_aura` | `rune_rate_mult` | 0.8 | Player rune drop rate multiplier (spawn interval x 1/mult) |
| | `until_hp_ratio` | 0.5 | Active while boss HP ratio is above this; off for good at or below |
| `phase_shift` | `at_hp_ratio` | 0.5 | Boss HP ratio that starts phase 2 (once) |
| | `brain_set` | `aggressive` | Weight set the brain switches to |
| | `extra_traits` | `[{"id":"row_burner","params":{}}]` | Traits added to the host at phase 2 |
| | `step_mult` | 0.85 | Multiplies the boss's step cooldown |
| `seal_caster` | `interval_sec` | 8.0 | Story 027: seconds between seals (armed again after each seal) |
| | `first_delay_sec` | = interval | Seconds before the first arming |
| | `cells_min` / `cells_max` | 2 / 3 | Seeded cell count of one seal (player half, escape cells of the swing: reachable within `escape_steps`, not covered, never the player's cell; at least one escape cell is always left, then ZoneRules.cast_seal applies the leave-a-path rule) |
| | `lead_sec` | 0.6 | The seal forms when an armed qualifying boss swing has this long left (at once for a shorter swing) |
| | `min_swing_cells` | 3 | Smallest boss swing that carries a seal |
| | `escape_steps` | 2 | Steps the player is assumed to make when its escape cells are counted |
| | `seal_sec` | combat.json `zones.seal_sec` | Seal duration override |
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
| `run_in_progress` | object or null | The run being played (`RunSession.to_dict`, v4): `version` 4, `character` (id), `chapter` (chapter id), `map` (`[{index, tier, nodes: [{kind, match_id}]}]`, kinds battle/danger/treasure/rest/miniboss/boss; fixed for the run), `column` (current column; == map size when finished), `node_index` (chosen node in the column, -1 = none yet), `cleared_nodes` (`[{column, node_index, kind}]`), `hp` (HP at the start of the node, negative = full; never auto-healed between nodes), `deck` (`[{id, level}]`, duplicates allowed; id strings load as level 1), `run_seed`, `elapsed` (seconds), `pending_reward` (card ids offered but not yet picked/skipped, `[]` when none), `relics` (Story 032: relic ids owned, in received order, unique; unknown ids are dropped with a warning; a save without the key = no relics, no version bump), `pending_relic_offer` (Story 032: relic ids of the open treasure screen's second row, `[]` when none; picking a card or a relic, or skipping, clears it together with `pending_reward`), `revives`, `removal_tokens` (>= 0), `cleared_bosses_this_run`. Luck is derived: `luck_start + luck_per_node x cleared_nodes.size()` (rewards.json). A pre-v4 run (no `version` 4) or `{needs_restart: true}` loads as a session with `needs_restart` true, `restart_reason` `run.restart.old_save`, empty map and deck, so `GameFlow` restarts that chapter for that character from a fresh run; saved chapters are kept. Saved form of such a run: `{version, character, chapter, needs_restart, restart_reason, map: []}` |

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
| `node_rewards` | object kind -> `{offers, min_rarity, free, removal_token}` | Story 022: card pick per node kind (`RewardRoller.reward_for_node`). `offers` 0 = no card; `min_rarity` = every offered card is at least this rarity (topped up from the whole pool with a warning when too few exist); `free` = no fight; `removal_token` = grants one token. Shipped: battle / danger 3 common; treasure 3 common free; miniboss 3 min rare; boss 3 common + token; rest 0 | as listed |

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
| `characters[].unlocked` | bool | Selectable now (only a data flag; unlock rules are out of scope) |

Passive params: `second_wind {heal_after_match}` extra HP after a won match (added before the max clamp); `wide_caster {min_cells, duration_mult}` player swings over `min_cells` or more cells wind up `duration_mult` times as long; `quick_blade {max_cells, damage_mult}` player hits over `max_cells` or fewer cells deal `damage_mult` times the final damage. Passives only affect the player.

Signature params (Story 021): `tram {duration_sec, cell_mult, lifesteal}` for `duration_sec` every player cut counts `cell_mult` x its cells for damage (the swing covers the real cells) and heals `lifesteal` x the damage dealt (clamped to max HP); `thien_hoa {burn_stacks, burn_duration_sec, burn_tick_sec, burn_damage_per_tick, detonate_mult}` instant (Story 030, order chốt 2026-10-25): first the boss takes `detonate_mult` x the total remaining burn damage of every enemy-half cell ALREADY burning (time left / tick sec x damage per tick, stacks included; nothing burning: 0) and those cells stop burning; then every `effect: burn` card's cooldown is reset; then every LIT formation-map cell of the enemy half is ignited `burn_stacks` times with `burn_duration_sec` / `burn_tick_sec` / `burn_damage_per_tick` — a lasting fire that hurts the boss while it stands in it (the boss brain avoids burning cells, `burn_avoid`) and is NOT detonated in the same use (no formation or no lit cell: nothing is ignited). Shipped (bot-tuned, `production/qa/evidence/signature-rework/signature-balance.md`): 1 stack, `burn_duration_sec` 3.0, `burn_tick_sec` 0.5, `burn_damage_per_tick` 0.5, `detonate_mult` 2.0; `anh_bo {duration_sec, small_mult, small_cells}` for `duration_sec` the player's steps have no cooldown and EVERY player hit of `small_cells` or fewer cells is multiplied by `small_mult` (Story 030: the boss need not be pinned; shipped 1.75). The legacy key `pinned_small_mult` is still read when `small_mult` is absent (warning, used as `small_mult`). Damage order: card `damage_per_cell` x cells (Tram cell count) -> Ghim -> passive -> signature.

Dev arg: `--character=<id>` (GameFlow) selects a character; without it and without the select screen no character is passed.

## `relics.json` (Story 032, read by `src/relics/relic_config.gd`, class RelicConfig)

Relics: passive rule changes the player carries for the whole run (no per-character relics, no active relics). Bad or missing file: `RelicConfig.DEFAULTS` for the top-level keys and no relics (warning); a bad entry is dropped with a warning, never a crash. All numbers are starting values, tuned by simulation.

| Key | Type | Meaning | Default |
|---|---|---|---|
| `relic_damage_mult_cap` | number >= 1 | Cap of the PRODUCT of every relic damage factor on one cast (`RelicRegistry.fold_damage`) | 3.0 |
| `rarity_weights` | object rarity -> number >= 0 | Draw weight per rarity for the `treasure` source; a missing rarity = 0 (so `boss` never appears in a treasure) | 60 / 30 / 10 (common / rare / epic) |
| `source_rules.treasure` | `{count, min_rarity}` | `count` different relics offered, none already owned (unless `stackable`); each slot draws a rarity by `rarity_weights` among rarities at or above `min_rarity` (floor) that still have a candidate | `{count: 3, min_rarity: "common"}` |
| `source_rules.boss_kill` | `{count, tiers}` | Relics drawn tier by tier: from `tiers[0]` (`boss`) first, then the next tier (`epic`) when none is left | `{count: 1, tiers: ["boss", "epic"]}` |
| `relics[].id` | string | Unique relic id (duplicate -> warning, later dropped); saved in `run_in_progress.relics` | — |
| `relics[].rarity` | `common` / `rare` / `epic` / `boss` | Rarity (unknown -> warning, entry dropped) | — |
| `relics[].tags` | array of `negative`, `stackable` | `negative`: a relic with a drawback (red frame in the HUD); `stackable`: may be offered again while owned. Unknown tag -> warning, ignored. None of the 16 shipped relics is stackable | `[]` |
| `relics[].name_key` / `desc_key` | translation keys | `relic.<id>.name` / `relic.<id>.desc`; the description states the numbers of `params` | `relic.<id>.name` / `.desc` |
| `relics[].script` | string | `RelicRegistry.SCRIPTS` key: `config_mod` (shared `ConfigModRelic`) or the relic's own script (`an_don`, `chi_khau`, `khoi_the`, `phan_don`, `huyet_an`, `an_chu`, `tam_hop`). Unknown -> warning, no relic | the id |
| `relics[].params` | object | The relic's numbers (below) | `{}` |

Config-type relics (`script: "config_mod"`): `params` maps a canonical config key to `{add: x}`, `{mul: x}`, `{add: a, mul: m}`, `{set: v}` or a bare number (= `set`). Canonical keys (`RelicRegistry.CONFIG_KEYS`): `seal_sec`, `thorn_ran`, `piece_freshness_sec`, `start_pieces`, `focus_sec`, `formation_fade`, `signature_cooldown`, `hold_slots`, `piece_spawn_interval`, `burn_max_stacks`, `han_stacks`, `han_damage`. All relics' overrides are folded by `RelicRegistry.merge_overrides` (adds sum, muls multiply, the last `set` wins) and applied to the match config BEFORE `FieldDrops`, the piece bag, `FormationMap` and `StatusEffects` are built: **value = (base, or `set` when present, + sum of adds) x product of muls** (`RelicRegistry.apply_override`). Where a number comes per card (e.g. a card's `seal_sec`), the override applies after the card's number. Adding a config-type relic is JSON only.

Shipped relics: `an_don` common `{mult: 2.0}` a cast of exactly one `mono` piece deals x mult; `chi_khau` common `{heal: 3, max_heal_per_match: 15}` every joined cast heals `heal`, at most `max_heal_per_match` per match; `phong_an` common `seal_sec +1.0`; `gai_ran` common `thorn_ran +1` (Fragile stacks from the player's thorn cells); `manh_tuoi` common `piece_freshness_sec +4` (the `start_pieces +1` part was removed by the Story 032 simulation); `dinh_tam` common `focus_sec +1.0`; `la_ban` rare `formation_fade x1.3` (cells fade slower); `tam_huong` rare `signature_cooldown x0.8`; `tui_rong` rare `hold_slots +1` (the `piece_spawn_interval x1.25` drawback was removed by the Story 032 simulation); `dau_than` rare `burn_max_stacks +1`; `khoi_the` rare `{first_casts: 1}` the first cast(s) of each match have no windup; `phan_don` rare `{shape: "mono"}` interrupting a boss spell puts one `shape` piece in the bag if there is room; `han_ky` epic `han_stacks` set 2, `han_damage x0.67`; `huyet_an` epic `negative` `{min_cells: 5, mult: 1.3, self_damage: 2}` casts of `min_cells`+ cells deal x mult, every player cast costs `self_damage` HP; `an_chu` boss `{featured_mult: 2.0}` replaces the featured-shape multiplier; `tam_hop` boss `{max_join_pieces: 3}` a third piece may be joined into one cast.

**Damage order of a player cast (Story 032, as implemented in `CutEffects.apply`; replaces the Story 021 order above):** card `damage_per_cell` x cells (Tram cell count) x card conditions (`bonus_vs_fragile_mult`) -> Ghim (Pin) -> Rạn (Fragile, spends 1 stack) -> featured shape (x `damage_mult`, or `an_chu`'s `featured_mult` when > 0) -> **relics** (every relic's `modify_cast_damage` in received order, multiplied together; the product is capped at `relic_damage_mult_cap`, `RelicRegistry.fold_damage`; the ONE hook is `SwingArbiter.player_relic_modifier`, player swings only) -> execute (x2) -> passive -> signature -> flat boss defense (minimum 1). Every step before flat defense is a multiplication, so their order does not change the number (the existing keyword steps were not moved); only flat defense, applied last, depends on the order. The relic cap applies to the relic product alone. Windup: the card's windup x `duration_mult` -> passive -> relics (`RelicRegistry.fold_cast_time` through `CutActor.cast_time_modifier`, once per begun player swing, floored at 0). Zone overrides (`seal_sec`, `thorn_ran`) apply only to the PLAYER's zone cards, after the card's own number (else the `combat.json` zones number).

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
