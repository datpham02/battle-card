class_name CombatConfig
extends RefCounted
## Combat start values, timing and the board shape, loaded from assets/data/combat.json.
## Schema: assets/data/schema.md. Implements: Story 003, Story 007.

const DEFAULT_PATH: String = "res://assets/data/combat.json"
## Built-in fallback board (columns / rows of ONE half), used only when the JSON omits them.
const FALLBACK_SIDE_COLS: int = 3
const FALLBACK_SIDE_ROWS: int = 3

var player_max_hp: float = 100.0
var enemy_max_hp: float = 100.0
## Columns / rows of one half of the board.
var side_cols: int = FALLBACK_SIDE_COLS
var side_rows: int = FALLBACK_SIDE_ROWS
## Holes in side coordinates (mirrored to the other half by BoardGrid).
var missing_cells: Array[Vector2i] = []
## The board built from the three values above (never null after construction).
var grid: BoardGrid = BoardGrid.new(FALLBACK_SIDE_COLS, FALLBACK_SIDE_ROWS)
## Optional start-cell overrides (board cells). BoardGrid.NO_CELL = use the grid's default.
var player_start_cell: Vector2i = BoardGrid.NO_CELL
var enemy_start_cell: Vector2i = BoardGrid.NO_CELL
## Cap (s) on one frame's time step so a frame hitch cannot skip logic windows.
var max_tick_sec: float = 0.1
## Seconds the HIT / MISS feedback stays on screen.
var feedback_sec: float = 1.0
## Story 016: the pause is refused during the last this-many seconds of a running swing
## (no "preview the hit" pause). 0 = only the skill menu blocks the pause.
var pause_lockout_sec: float = 0.5
## Story 029 formation map: a covered enemy cell stays lit `base + per_cell x (real enemy cells)`
## seconds (see [method formation_fade_for]); the HUD blinks a cell when its fade ratio left is
## below warn_ratio (0..1); the completion flash lasts flash_sec.
var formation_fade_base_sec: float = 5.0
var formation_fade_per_cell_sec: float = 0.8
var formation_fade_warn_ratio: float = 0.25
var formation_flash_sec: float = 0.5
## Story 021: keyboard key name (OS.find_keycode_from_string) that fires the signature on desktop.
var signature_key: String = "Q"
## Board-scaled step cooldown: [member step_cooldown_ref_sec] on a board that is
## [member step_cooldown_ref_steps] steps across, scaled by (ref_steps / steps_across)^exponent
## and clamped to [min, max]. See [method step_cooldown_for].
var step_cooldown_ref_sec: float = 0.45
var step_cooldown_ref_steps: int = 2
var step_cooldown_exponent: float = 0.75
var step_cooldown_min_sec: float = 0.18
var step_cooldown_max_sec: float = 0.60
## DEPRECATED absolute override of the computed player step cooldown; negative = not set.
var player_step_cooldown_sec: float = -1.0
## Story 020 keywords. These are the ONLY built-in fallbacks (used when combat.json omits or
## invalidates a key); the tuned values live in combat.json.
## Ghim: damage multiplier against a pinned unit (>= 0; 1.0 = control only, Story 023).
var pinned_damage_mult: float = 1.0
## Dot: seconds added to a re-ignited burning cell, extra damage per tick per extra stack, stack cap.
var burn_stack_extend_sec: float = 2.0
var burn_stack_tick_bonus: float = 1.0
var burn_max_stacks: int = 3
## 2026-10-31: combat.json `burn_on_entry` -> StatusEffects.burn_on_entry (stepping onto a burning cell costs one tick).
var burn_on_entry: bool = true
## Story 023: Ran (fragile) damage multiplier (>= 1) and stack cap (>= 1); Han (frost) stacks that
## trigger the burst (>= 1) and its damage (>= 0, ignores defense and Ran); default execute threshold
## (share of max HP, 0..1) for cards with `execute: true`. Ghim is control only: its multiplier is 1.0.
var fragile_mult: float = 1.5
var fragile_max_stacks: int = 3
var frost_stacks_to_burst: int = 3
var frost_burst_damage: float = 24.0
var execute_ratio: float = 0.25
## Story 028: most pieces one cast may join (1..3) and the fallback cap on a cast's total cells (0 = off, else >= 1).
## (join_extra_sec was removed 2026-11-01: pieces join before Tung phép, never into the open menu.)
var max_pieces_per_cast: int = 2
var max_cast_cells: int = 0
## Story 027 zones (combat.json `zones` block; cards may override per card): seconds a Ket gioi (seal) holds,
## seconds a Tran gai (thorns) lasts, damage per entry into a thorn cell, Ran stacks per entry.
var seal_sec: float = 1.2
var thorn_sec: float = 3.0
var thorn_damage: float = 6.0
var thorn_fragile_stacks: int = 1
## Drop tiles (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md, combat.json `zones`): seconds a chosen cell
## cracks before it falls (the hole then stays open seal_sec), the reaction share taken off that warning when judging
## whether the player can step off in time (cell eligible when step cooldown left <= warn - margin), and whether a
## fall is lethal (false = lose hazards.fall_damage, the Sky Isles crumble fallback). hole_return_fade_sec is
## presentation only (the white fade-in after the hole closes; the cell is steppable at once).
var hole_warn_sec: float = 0.8
var hole_reaction_margin_sec: float = 0.2
var hole_fall_lethal: bool = true
var hole_return_fade_sec: float = 0.3
## Story 036 tile hazards (combat.json `hazards` block), kept as a dictionary (see [method hazards]).
var _hazards: Dictionary = TileHazards.DEFAULTS.duplicate()
## Story 046 Part C telegraph tiles (combat.json `telegraph` block; design/art/art-bible.md 4, design/ux/hud.md E-17).
## Each pair is [alpha at progress 0, alpha at progress 1] of one layer of the boss's red tiles, lerped by
## [method telegraph_fill_alpha] / [method telegraph_stripe_alpha] / [method telegraph_edge_alpha]. These are the ONLY
## built-in fallbacks (used when combat.json omits or invalidates a key).
var telegraph_fill: Vector2 = Vector2(0.0, 0.45)
var telegraph_stripe: Vector2 = Vector2(0.5, 1.0)
var telegraph_edge: Vector2 = Vector2(0.3, 1.0)
## Stripe alpha of a QUEUED boss swing (Story 013): drawn at progress 0, no fill, sparser than a running swing's.
var telegraph_queued_stripe_alpha: float = 0.35
## Progress levels the telegraph snaps to under reduce motion (>= 2 values, each 0..1, non-decreasing).
var telegraph_reduce_motion_steps: Array[float] = [0.0, 0.5, 1.0]
## Floor perspective (ADR-0002, combat.json `floor.perspective.back_ratio`, shipped 0.82): back-row width over
## front-row width of the trapezoid board (FloorPerspective via BoardGeometry); 0 / absent = the flat board.
## `--floor-perspective=<r>` overrides it.
var floor_perspective_back_ratio: float = FloorPerspective.OFF
## Story 046 Part B (combat.json `hud.hp_trail_sec`, art bible 7.5): seconds the damage trail behind an HP fill
## takes to shrink to the new HP (0 = no trail).
var hud_hp_trail_sec: float = 0.4
## 2026-10-31 (user: "khi chiến đấu thì hiện số máu dưới chân còn ẩn cái thanh máu ở trên"): combat.json
## `hud.corner_panels`. False (shipped) = no HP panels in the top corners during a battle; each unit shows its HP
## on a plate under its feet (CutHudView._draw_hp_plates) and the boss's held points float in the top-right
## corner. True = the corner panels of 2026-10-31 (ScreenLayout.hud_panel_rect).
var hud_corner_panels: bool = false
## 2026-11-03 (user: the hero's HP in the top-left panel, monsters keep the number under their feet): combat.json
## `hud.player_panel`. True (shipped) with corner_panels false = only the player's corner panel (name, HP, bar; the
## Engraving count stays on the Awaken button) and no plate under the player; the boss keeps its plate and no panel.
## Ignored while corner_panels is true (both panels, no plates).
var hud_player_panel: bool = true
## 2026-10-31 (user: "ko cần cái vòng cd mỗi lần di chuyển"): combat.json `hud.step_rings`. False (shipped) = no
## step-cooldown ring around the player or the boss after a step; the boss's solid "rooted by its swing" ring stays.
var hud_step_rings: bool = false
## ADR-0001 A6 (combat.json `timing.beat_sec`): seconds in one pack "beat" (> 0). Pack timings authored in beats
## convert through [method beats_to_sec]; nothing hard-codes the number.
var beat_sec: float = 0.5
## ADR-0001 A1 (combat.json `timing.delivery`): per delivery type the seconds that time its per-cell arrivals
## (SkillDelivery.normalize_timing form; defaults = SkillDelivery.DEFAULT_TIMING).
var delivery_timing: Dictionary = SkillDelivery.DEFAULT_TIMING.duplicate(true)


## Loads from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> CombatConfig:
	if not FileAccess.file_exists(path):
		push_error("CombatConfig: file not found: %s" % path)
		return null
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Returns null (and pushes an error) if invalid.
static func from_json_text(text: String) -> CombatConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CombatConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults. Start cells that are not
## real cells of the unit's half are dropped (warning) so the grid default is used.
static func from_dictionary(data: Dictionary) -> CombatConfig:
	var config := CombatConfig.new()
	config.player_max_hp = maxf(float(data.get("player_max_hp", config.player_max_hp)), 1.0)
	config.enemy_max_hp = maxf(float(data.get("enemy_max_hp", config.enemy_max_hp)), 1.0)
	config.side_cols = int(data.get("side_cols", config.side_cols))
	config.side_rows = int(data.get("side_rows", config.side_rows))
	config.missing_cells = _parse_cells(data.get("missing_cells"))
	config.grid = BoardGrid.new(config.side_cols, config.side_rows, config.missing_cells)
	config.player_start_cell = _parse_cell(data.get("player_start_cell"), BoardGrid.NO_CELL)
	config.enemy_start_cell = _parse_cell(data.get("enemy_start_cell"), BoardGrid.NO_CELL)
	config._validate_start_cells()
	config.max_tick_sec = maxf(float(data.get("max_tick_sec", config.max_tick_sec)), 0.001)
	config.feedback_sec = maxf(float(data.get("feedback_sec", config.feedback_sec)), 0.0)
	config.pause_lockout_sec = maxf(float(data.get("pause_lockout_sec", config.pause_lockout_sec)), 0.0)
	config.formation_fade_base_sec = maxf(float(data.get("formation_fade_base_sec", config.formation_fade_base_sec)), 0.0)
	config.formation_fade_per_cell_sec = maxf(float(data.get("formation_fade_per_cell_sec", config.formation_fade_per_cell_sec)), 0.0)
	config.formation_fade_warn_ratio = clampf(float(data.get("formation_fade_warn_ratio", config.formation_fade_warn_ratio)), 0.0, 1.0)
	config.formation_flash_sec = maxf(float(data.get("formation_flash_sec", config.formation_flash_sec)), 0.0)
	var key_name: String = str(data.get("signature_key", config.signature_key)).strip_edges()
	if key_name.is_empty() or OS.find_keycode_from_string(key_name) == KEY_NONE:
		push_warning("CombatConfig: signature_key '%s' is not a key name, using '%s'" % [key_name, config.signature_key])
	else:
		config.signature_key = key_name
	config._parse_step_cooldown(data)
	config._parse_keywords(data)
	config.max_pieces_per_cast = clampi(int(data.get("max_pieces_per_cast", config.max_pieces_per_cast)), 1, 3)
	var cap: int = int(data.get("max_cast_cells", config.max_cast_cells))
	config.max_cast_cells = 0 if cap <= 0 else cap
	config._parse_zones(data)
	var entry: Variant = data.get("burn_on_entry", config.burn_on_entry)
	if typeof(entry) == TYPE_BOOL:
		config.burn_on_entry = bool(entry)
	else:
		push_warning("CombatConfig: burn_on_entry must be true or false, using %s" % config.burn_on_entry)
	var hazard_block: Variant = data.get("hazards")
	if typeof(hazard_block) == TYPE_DICTIONARY:
		config._hazards = TileHazards.clean(hazard_block as Dictionary)
	config._parse_telegraph(data)
	config._parse_hud(data)
	config._parse_timing(data)
	config._parse_floor(data)
	return config


# ADR-0002: `floor.perspective.back_ratio` (number; anything else or out of range = off, warning).
func _parse_floor(data: Dictionary) -> void:
	var floor_block: Variant = data.get("floor")
	if typeof(floor_block) != TYPE_DICTIONARY:
		return
	var persp: Variant = (floor_block as Dictionary).get("perspective")
	if typeof(persp) != TYPE_DICTIONARY:
		return
	var raw: Variant = (persp as Dictionary).get("back_ratio", FloorPerspective.OFF)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		push_warning("CombatConfig: floor.perspective.back_ratio must be a number; the floor stays flat")
		return
	var ratio: float = float(raw)
	if ratio != FloorPerspective.OFF and not FloorPerspective.is_on(ratio):
		push_warning("CombatConfig: floor.perspective.back_ratio %s is outside (%s, 1]; the floor stays flat" % [ratio, FloorPerspective.MIN_RATIO])
		return
	floor_perspective_back_ratio = ratio


## ADR-0001 A6: seconds of [param beats] pack beats ([member beat_sec] each).
func beats_to_sec(beats: float) -> float:
	return beats * beat_sec


# ADR-0001 A6 / A1: the `timing` block: beat_sec (> 0, else the default + warning) and the delivery timings.
func _parse_timing(data: Dictionary) -> void:
	var raw: Variant = data.get("timing")
	if raw == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("CombatConfig: timing must be an object, using defaults")
		return
	var block: Dictionary = raw as Dictionary
	if block.has("beat_sec"):
		var v: Variant = block["beat_sec"]
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0:
			beat_sec = float(v)
		else:
			push_warning("CombatConfig: timing.beat_sec must be a number > 0, using %s" % beat_sec)
	var t: Dictionary = SkillDelivery.normalize_timing(block.get("delivery"))
	for p: String in t["problems"]:
		push_warning("CombatConfig: %s" % p)
	delivery_timing = t["timing"]


## Seconds between steps on [param board]: the computed, board-scaled value (or the deprecated
## `player_step_cooldown_sec` override when combat.json still carries it).
func step_cooldown_for(board: BoardGrid) -> float:
	if player_step_cooldown_sec >= 0.0:
		return player_step_cooldown_sec
	var steps_across: int = maxi(maxi(board.side_cols, board.side_rows) - 1, 1)
	var raw: float = step_cooldown_ref_sec * pow(float(step_cooldown_ref_steps) / float(steps_across), step_cooldown_exponent)
	return clampf(raw, step_cooldown_min_sec, step_cooldown_max_sec)


## Story 029: seconds a covered cell stays lit on a board whose enemy half has [param cell_count]
## real cells: formation_fade_base_sec + formation_fade_per_cell_sec x cell_count.
func formation_fade_for(cell_count: int) -> float:
	return formation_fade_base_sec + formation_fade_per_cell_sec * float(maxi(cell_count, 0))


## Replaces the board (dev / capture override). Start-cell overrides were authored for the
## data board, so they are cleared and the new grid's default cells are used.
func use_grid(new_grid: BoardGrid) -> void:
	grid = new_grid
	side_cols = new_grid.side_cols
	side_rows = new_grid.side_rows
	missing_cells = new_grid.missing_side_cells()
	player_start_cell = BoardGrid.NO_CELL
	enemy_start_cell = BoardGrid.NO_CELL


## Story 027: the zone numbers as a dictionary {seal_sec, thorn_sec, thorn_damage, thorn_fragile_stacks}
## (what CutEffects takes as options.zones and a card may override), plus the drop tile numbers hole_warn_sec,
## hole_reaction_margin_sec, hole_fall_lethal (read by the seal_caster trait; cards ignore them).
func zone_numbers() -> Dictionary:
	return {
		"seal_sec": seal_sec, "thorn_sec": thorn_sec,
		"thorn_damage": thorn_damage, "thorn_fragile_stacks": thorn_fragile_stacks,
		"hole_warn_sec": hole_warn_sec, "hole_reaction_margin_sec": hole_reaction_margin_sec,
		"hole_fall_lethal": hole_fall_lethal,
	}


## Story 036: the tile hazard numbers {mire_step_mult, mire_tick_damage, mire_tick_sec, mire_grace_sec,
## sand_interval_sec, sand_cells, sand_sec, sand_warn_sec, drift_sec, wind_shift_sec, plus the Story 039 keys
## vent_interval_sec, vent_warn_sec, vent_sec, vent_tick_sec, vent_tick_damage, crumble_after_sec, crumble_warn_sec,
## fall_sec, fall_damage} (a copy; every key of TileHazards.DEFAULTS). A bad value keeps
## its default (warning); a match may override each key by the same name (TileHazards.configure).
func hazards() -> Dictionary:
	return _hazards.duplicate()


## Story 046 Part C: red fill alpha of a telegraph tile at progress [param k] (0..1, clamped):
## `lerp(telegraph_fill.x, telegraph_fill.y, k)`; 0 -> 0.0, 1 -> 0.45 with the shipped numbers.
func telegraph_fill_alpha(k: float) -> float:
	return lerpf(telegraph_fill.x, telegraph_fill.y, clampf(k, 0.0, 1.0))


## Story 046 Part C: diagonal stripe alpha at progress [param k]; 0.5 -> 1.0 with the shipped numbers.
func telegraph_stripe_alpha(k: float) -> float:
	return lerpf(telegraph_stripe.x, telegraph_stripe.y, clampf(k, 0.0, 1.0))


## Story 046 Part C: edge alpha (2 px red edge and the 1 px Ink edge outside it) at progress [param k];
## 0.3 -> 1.0 with the shipped numbers.
func telegraph_edge_alpha(k: float) -> float:
	return lerpf(telegraph_edge.x, telegraph_edge.y, clampf(k, 0.0, 1.0))


## Story 046 Part C: the progress the telegraph is drawn at. Continuous ([param k] clamped to 0..1) when
## [param reduce_motion] is false; otherwise snapped to [member telegraph_reduce_motion_steps] (0 / 0.5 / 1 shipped):
## n steps, step i covers [i/n, (i+1)/n), the last one includes 1.0 (thresholds at 1/3 and 2/3 for three).
func quantize_progress(k: float, reduce_motion: bool) -> float:
	var clamped: float = clampf(k, 0.0, 1.0)
	if not reduce_motion:
		return clamped
	var count: int = telegraph_reduce_motion_steps.size()
	var index: int = mini(floori(clamped * float(count)), count - 1)
	return telegraph_reduce_motion_steps[index]


# Story 046 Part C: the `telegraph` block; one invalid value -> the whole block falls back to the defaults (warning).
func _parse_telegraph(data: Dictionary) -> void:
	var raw: Variant = data.get("telegraph")
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var block: Dictionary = raw as Dictionary
	var fill: Vector2 = _parse_alpha_pair(block.get("fill"), telegraph_fill)
	var stripe: Vector2 = _parse_alpha_pair(block.get("stripe"), telegraph_stripe)
	var edge: Vector2 = _parse_alpha_pair(block.get("edge"), telegraph_edge)
	var queued: float = float(block.get("queued_stripe_alpha", telegraph_queued_stripe_alpha))
	var steps: Array[float] = []
	var steps_ok: bool = true
	var raw_steps: Variant = block.get("reduce_motion_steps", telegraph_reduce_motion_steps)
	if typeof(raw_steps) == TYPE_ARRAY and (raw_steps as Array).size() >= 2:
		for item: Variant in raw_steps as Array:
			var level: float = float(item)
			if level < 0.0 or level > 1.0 or (not steps.is_empty() and level < steps[steps.size() - 1]):
				steps_ok = false
			steps.append(level)
	else:
		steps_ok = false
	if fill.x >= 0.0 and stripe.x >= 0.0 and edge.x >= 0.0 and queued >= 0.0 and queued <= 1.0 and steps_ok:
		telegraph_fill = fill
		telegraph_stripe = stripe
		telegraph_edge = edge
		telegraph_queued_stripe_alpha = queued
		telegraph_reduce_motion_steps = steps
	else:
		push_warning("CombatConfig: invalid telegraph values (fill / stripe / edge = [from, to] alphas 0..1, queued_stripe_alpha 0..1, reduce_motion_steps >= 2 non-decreasing levels 0..1), using defaults")


# Story 046 Part B: the `hud` block; an invalid hp_trail_sec (not a number, or < 0) keeps the default (warning).
func _parse_hud(data: Dictionary) -> void:
	var raw: Variant = data.get("hud")
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var value: Variant = (raw as Dictionary).get("hp_trail_sec", hud_hp_trail_sec)
	if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) >= 0.0:
		hud_hp_trail_sec = float(value)
	else:
		push_warning("CombatConfig: hud.hp_trail_sec must be a number >= 0, using %s" % hud_hp_trail_sec)
	var rings: Variant = (raw as Dictionary).get("step_rings", hud_step_rings)
	if typeof(rings) == TYPE_BOOL:
		hud_step_rings = bool(rings)
	else:
		push_warning("CombatConfig: hud.step_rings must be true or false, using %s" % hud_step_rings)
	var panels: Variant = (raw as Dictionary).get("corner_panels", hud_corner_panels)
	if typeof(panels) == TYPE_BOOL:
		hud_corner_panels = bool(panels)
	else:
		push_warning("CombatConfig: hud.corner_panels must be true or false, using %s" % hud_corner_panels)
	var player_panel: Variant = (raw as Dictionary).get("player_panel", hud_player_panel)
	if typeof(player_panel) == TYPE_BOOL:
		hud_player_panel = bool(player_panel)
	else:
		push_warning("CombatConfig: hud.player_panel must be true or false, using %s" % hud_player_panel)


# A [from, to] pair of alphas, each clamped-checked to 0..1; (-1, -1) marks it invalid.
static func _parse_alpha_pair(raw: Variant, fallback: Vector2) -> Vector2:
	if raw == null:
		return fallback
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 2:
		var from: float = float((raw as Array)[0])
		var to: float = float((raw as Array)[1])
		if from >= 0.0 and from <= 1.0 and to >= 0.0 and to <= 1.0:
			return Vector2(from, to)
	return Vector2(-1.0, -1.0)


# Story 027: the `zones` block; one invalid value -> all four fall back to the defaults (warning).
func _parse_zones(data: Dictionary) -> void:
	var raw: Variant = data.get("zones")
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var zones: Dictionary = raw as Dictionary
	var seal: float = float(zones.get("seal_sec", seal_sec))
	var thorn: float = float(zones.get("thorn_sec", thorn_sec))
	var damage: float = float(zones.get("thorn_damage", thorn_damage))
	var stacks: int = int(zones.get("thorn_fragile_stacks", thorn_fragile_stacks))
	if seal > 0.0 and thorn > 0.0 and damage >= 0.0 and stacks >= 0:
		seal_sec = seal
		thorn_sec = thorn
		thorn_damage = damage
		thorn_fragile_stacks = stacks
	else:
		push_warning("CombatConfig: invalid zones values (seal_sec>0, thorn_sec>0, thorn_damage>=0, thorn_fragile_stacks>=0), using defaults")
	_parse_holes(zones)


# Drop tiles: the hole_* keys of the `zones` block, checked on their own (a bad one keeps its default, warning):
# hole_warn_sec > 0, 0 <= hole_reaction_margin_sec <= hole_warn_sec, hole_fall_lethal a bool, hole_return_fade_sec >= 0.
func _parse_holes(zones: Dictionary) -> void:
	var warn: float = float(zones.get("hole_warn_sec", hole_warn_sec))
	if warn > 0.0:
		hole_warn_sec = warn
	else:
		push_warning("CombatConfig: zones.hole_warn_sec must be > 0, keeping %s" % hole_warn_sec)
	var margin: float = float(zones.get("hole_reaction_margin_sec", hole_reaction_margin_sec))
	if margin >= 0.0 and margin <= hole_warn_sec:
		hole_reaction_margin_sec = margin
	else:
		push_warning("CombatConfig: zones.hole_reaction_margin_sec must be 0..hole_warn_sec, keeping %s" % hole_reaction_margin_sec)
	if zones.has("hole_fall_lethal"):
		if typeof(zones["hole_fall_lethal"]) == TYPE_BOOL:
			hole_fall_lethal = bool(zones["hole_fall_lethal"])
		else:
			push_warning("CombatConfig: zones.hole_fall_lethal must be true or false, keeping %s" % hole_fall_lethal)
	var fade: float = float(zones.get("hole_return_fade_sec", hole_return_fade_sec))
	if fade >= 0.0:
		hole_return_fade_sec = fade
	else:
		push_warning("CombatConfig: zones.hole_return_fade_sec must be >= 0, keeping %s" % hole_return_fade_sec)


func _parse_keywords(data: Dictionary) -> void:
	var mult: float = float(data.get("pinned_damage_mult", pinned_damage_mult))
	var extend: float = float(data.get("burn_stack_extend_sec", burn_stack_extend_sec))
	var bonus: float = float(data.get("burn_stack_tick_bonus", burn_stack_tick_bonus))
	var stacks: int = int(data.get("burn_max_stacks", burn_max_stacks))
	var f_mult: float = float(data.get("fragile_mult", fragile_mult))
	var f_max: int = int(data.get("fragile_max_stacks", fragile_max_stacks))
	var frost_n: int = int(data.get("frost_stacks_to_burst", frost_stacks_to_burst))
	var frost_dmg: float = float(data.get("frost_burst_damage", frost_burst_damage))
	var exec_ratio: float = float(data.get("execute_ratio", execute_ratio))
	if f_mult >= 1.0 and f_max >= 1 and frost_n >= 1 and frost_dmg >= 0.0 and exec_ratio >= 0.0 and exec_ratio <= 1.0:
		fragile_mult = f_mult
		fragile_max_stacks = f_max
		frost_stacks_to_burst = frost_n
		frost_burst_damage = frost_dmg
		execute_ratio = exec_ratio
	else:
		push_warning("CombatConfig: invalid Ran/Han/execute values (fragile_mult>=1, fragile_max_stacks>=1, frost_stacks_to_burst>=1, frost_burst_damage>=0, execute_ratio 0..1), using defaults")
	if mult >= 0.0 and extend >= 0.0 and bonus >= 0.0 and stacks >= 1:
		pinned_damage_mult = mult
		burn_stack_extend_sec = extend
		burn_stack_tick_bonus = bonus
		burn_max_stacks = stacks
	else:
		push_warning("CombatConfig: invalid keyword values (pinned_damage_mult>=0, burn_stack_*>=0, burn_max_stacks>=1), using defaults")


## Applies the keyword numbers to [param status].
func configure_status(status: StatusEffects) -> void:
	status.configure(burn_stack_extend_sec, burn_stack_tick_bonus, burn_max_stacks, pinned_damage_mult)
	status.configure_keywords(fragile_mult, fragile_max_stacks, frost_stacks_to_burst, frost_burst_damage)
	status.burn_on_entry = burn_on_entry
	# Drop tiles: lethal or not, the non-lethal fall damage (hazards.fall_damage; CombatView re-reads it with the
	# match overrides) and the return fade.
	status.hole_fall_lethal = hole_fall_lethal
	status.hole_fall_damage = float(_hazards.get("fall_damage", 0.0))
	status.hole_return_fade_sec = hole_return_fade_sec


func _parse_step_cooldown(data: Dictionary) -> void:
	var ref_sec: float = float(data.get("step_cooldown_ref_sec", step_cooldown_ref_sec))
	var ref_steps: int = int(data.get("step_cooldown_ref_steps", step_cooldown_ref_steps))
	var exponent: float = float(data.get("step_cooldown_exponent", step_cooldown_exponent))
	var min_sec: float = float(data.get("step_cooldown_min_sec", step_cooldown_min_sec))
	var max_sec: float = float(data.get("step_cooldown_max_sec", step_cooldown_max_sec))
	if ref_sec > 0.0 and ref_steps >= 1 and exponent >= 0.0 and min_sec <= max_sec:
		step_cooldown_ref_sec = ref_sec
		step_cooldown_ref_steps = ref_steps
		step_cooldown_exponent = exponent
		step_cooldown_min_sec = min_sec
		step_cooldown_max_sec = max_sec
	else:
		push_warning("CombatConfig: invalid step_cooldown_* values, using defaults")
	if data.has("player_step_cooldown_sec"):
		push_warning("CombatConfig: player_step_cooldown_sec is deprecated (overrides the board-scaled step cooldown); remove it")
		player_step_cooldown_sec = maxf(float(data["player_step_cooldown_sec"]), 0.0)


func _validate_start_cells() -> void:
	if player_start_cell != BoardGrid.NO_CELL and not grid.is_player_cell(player_start_cell):
		push_warning("CombatConfig: player_start_cell %s is not a cell of the player's half, using the default" % player_start_cell)
		player_start_cell = BoardGrid.NO_CELL
	if enemy_start_cell != BoardGrid.NO_CELL and not grid.is_enemy_cell(enemy_start_cell):
		push_warning("CombatConfig: enemy_start_cell %s is not a cell of the boss's half, using the default" % enemy_start_cell)
		enemy_start_cell = BoardGrid.NO_CELL


static func _parse_cell(raw: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return fallback


static func _parse_cells(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return cells
	for item: Variant in raw as Array:
		var cell: Vector2i = _parse_cell(item, BoardGrid.NO_CELL)
		if cell == BoardGrid.NO_CELL:
			push_warning("CombatConfig: bad missing_cells entry %s, ignored" % str(item))
		else:
			cells.append(cell)
	return cells
