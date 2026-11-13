class_name FormationRules
extends RefCounted
## Multi-enemy encounters, Phase 0 (docs/design/world-map-v2/MULTI-ENEMY-ENCOUNTER-AUDIT.md section 5, 8.4; decision
## change 03-encounter-system.md section 1, 2026-11-13): the pure validator of a chapter's `formations` block and of a
## match's `enemies` list. Data only: nothing here is read by the combat yet (that is Phase 1+); a formation that fails
## a rule is DROPPED with a problem line, never clamped into something playable, so bad data cannot reach a fight.
##
## Limits (approved with the audit): at most [constant MAX_UNITS] units and [constant MAX_UNIT_CELLS] occupied cells per
## half; a half of [constant SQUARE_CELLS] real cells (the `square` arena) takes 2 units; a multi-cell unit (a 2x2
## warden) with any other unit only on [constant WARDEN_PACK_SHAPES]; occupied cells <= 1/3 of the half's real cells
## and at least [constant MIN_FREE_CELLS] free cells for the player's pieces.

## Encounter types a formation may declare (map to the node kinds battle / danger / miniboss / boss).
const TYPES: Array[String] = ["normal", "hard", "elite", "boss"]
## Role labels (design / display only; no logic reads them in Phase 0).
const ROLES: Array[String] = ["attacker", "tank", "support", "disruptor"]
## Hard caps per half (audit section 8.4).
const MAX_UNITS: int = 4
const MAX_UNIT_CELLS: int = 5
const MIN_FREE_CELLS: int = 6
## A half this small (the `square` arena, 3x3) takes at most 2 units.
const SQUARE_CELLS: int = 9
const SQUARE_MAX_UNITS: int = 2
## Halves up to this many real cells take at most 3 units; bigger ones take MAX_UNITS.
const THREE_UNIT_CELLS: int = 16
## The only arenas where a multi-cell unit may have company.
const WARDEN_PACK_SHAPES: Array[String] = ["boss_hall", "oasis"]
## Authoring keys of one `enemies[]` entry after cleaning (chapter data).
const ENTRY_KEYS: Array[String] = ["id", "slot", "role", "required", "hp_mult", "defense_add", "tempo_mult", "traits"]
## Phase 1: keys RunConfig.from_node resolves on every entry of a match (numbers already scaled; CombatState reads
## them without any lookup): `template_id`, `max_hp`, `defense`, `brain`, `enemy`, `footprint` ([[dx, dy], ...]).
const RESOLVED_KEYS: Array[String] = ["template_id", "max_hp", "defense", "brain", "enemy", "footprint", "ai"]
## Multi-enemy Phase 3 (A2, MULTI-ENEMY-PHASE3-5-PLAN.md 1.1b / 1.2): the template AI keys every resolved entry carries
## in its `ai` block (only the keys the template / match has; numbers already scaled like unit 0's). Unit 0's block mirrors
## the resolved match; unit 1+'s comes from its own template.
const AI_KEYS: Array[String] = [
	"brain_set", "boss_think_interval_sec", "boss_reaction_sec", "movement", "boss_step_cooldown_mult", "boss_cards",
	"swing_speed_mult", "mire_immune", "combo_chance", "combo_gap_sec", "boss_min_runes", "boss_drop_interval_mult",
	"boss_root_while_swinging", "pattern_tempo_mult",
]


## Phase 3 (A2): the `ai` block of [param source] (a raw / cleaned match dictionary or a raw `ai` block): a deep copy of
## its AI_KEYS that are present, nothing else.
static func ai_block(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in AI_KEYS:
		if source.has(key):
			out[key] = source[key].duplicate(true) if (source[key] is Dictionary or source[key] is Array) else source[key]
	return out


## Cleans one `enemies[]` entry. [param templates] = the chapter's `matches` (id -> raw block). Returns {} (with a line
## in [param problems]) when the entry is not an object, has no `id`, or its id is not a match of the chapter.
static func clean_entry(raw: Variant, templates: Dictionary, where: String, problems: Array[String]) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("%s: an enemies entry is not an object" % where)
		return {}
	var src: Dictionary = raw as Dictionary
	var id: String = str(src.get("id", ""))
	if id.is_empty():
		problems.append("%s: an enemies entry has no id" % where)
		return {}
	if not templates.has(id):
		problems.append("%s: enemy '%s' is not a match of this chapter" % [where, id])
		return {}
	var entry: Dictionary = {
		"id": id, "slot": str(src.get("slot", "")), "role": "", "required": bool(src.get("required", true)),
		"hp_mult": 1.0, "defense_add": 0.0, "tempo_mult": 1.0, "traits": [],
	}
	var role: String = str(src.get("role", ""))
	if not role.is_empty():
		if ROLES.has(role):
			entry["role"] = role
		else:
			problems.append("%s: enemy '%s' role '%s' unknown (allowed %s), cleared" % [where, id, role, ", ".join(ROLES)])
	for key: String in ["hp_mult", "tempo_mult"]:
		if src.has(key):
			var v: float = float(src[key])
			if v > 0.0:
				entry[key] = v
			else:
				problems.append("%s: enemy '%s' %s must be > 0 (got %s), using 1" % [where, id, key, v])
	if src.has("defense_add"):
		entry["defense_add"] = float(src["defense_add"])
	if src.has("traits"):
		if typeof(src["traits"]) == TYPE_ARRAY:
			entry["traits"] = (src["traits"] as Array).duplicate(true)
		else:
			problems.append("%s: enemy '%s' traits must be an array, ignored" % [where, id])
	if src.has("spawn_at"):
		# Roadmap step 7 (late spawns); refused rather than silently kept so the data cannot claim a feature that
		# does not exist yet.
		problems.append("%s: enemy '%s' spawn_at is not supported in Phase 0, ignored" % [where, id])
	return entry


## Footprint offsets ([[dx, dy], ...], [[0, 0]] included) of a template (a chapter `matches` block): the `footprint`
## of its `enemy_skills.json` enemy for a pattern brain, else one cell. [param footprint_fn] = Callable(enemy id:
## String) -> Array of [dx, dy] (invalid, or an empty / malformed answer = one cell).
static func footprint_offsets(template: Dictionary, footprint_fn: Callable) -> Array:
	var one: Array = [[0, 0]]
	if str(template.get("brain", "")) != RunConfig.BRAIN_PATTERN or not footprint_fn.is_valid():
		return one
	var raw: Variant = footprint_fn.call(str(template.get("enemy", "")))
	return clean_footprint(raw, one)


## Pure: [param raw] as a list of [dx, dy] pairs (ints), or [param fallback] when it is not an array, is empty, has a
## malformed pair, a negative offset or no [0, 0].
static func clean_footprint(raw: Variant, fallback: Array) -> Array:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		return fallback.duplicate(true)
	var out: Array = []
	var has_origin: bool = false
	for pair: Variant in raw as Array:
		var dx: int
		var dy: int
		if typeof(pair) == TYPE_VECTOR2I:
			dx = (pair as Vector2i).x
			dy = (pair as Vector2i).y
		elif typeof(pair) == TYPE_ARRAY and (pair as Array).size() == 2:
			dx = int((pair as Array)[0])
			dy = int((pair as Array)[1])
		else:
			return fallback.duplicate(true)
		if dx < 0 or dy < 0:
			return fallback.duplicate(true)
		if dx == 0 and dy == 0:
			has_origin = true
		if not out.has([dx, dy]):
			out.append([dx, dy])
	return out if has_origin else fallback.duplicate(true)


## Number of board cells a template occupies (see [method footprint_offsets]).
static func footprint_cells(template: Dictionary, footprint_fn: Callable) -> int:
	return footprint_offsets(template, footprint_fn).size()


## Real cells of one half of an arena spec (a `{"shape": id, "variant": bool}` or direct `{side_cols, side_rows,
## missing_cells}` block). A seeded variant may toggle up to `rules.variant_change_max` holes, so the count is taken
## conservatively (minus that many). -1 when the spec names no known shape and is not a valid direct block.
static func half_cells(arena: Dictionary, library: ArenaLibrary) -> int:
	var shape: Dictionary = {}
	var shape_id: String = str(arena.get("shape", ""))
	if not shape_id.is_empty():
		if library == null:
			return -1
		shape = library.get_shape(shape_id)
		if shape.is_empty():
			return -1
	elif arena.has("side_cols") and arena.has("side_rows"):
		shape = arena
	else:
		return -1
	var cols: int = int(shape.get("side_cols", 0))
	var rows: int = int(shape.get("side_rows", 0))
	if cols < 1 or rows < 1:
		return -1
	var missing: int = (shape.get("missing_cells", []) as Array).size() if typeof(shape.get("missing_cells", [])) == TYPE_ARRAY else 0
	var cells: int = cols * rows - missing
	if bool(arena.get("variant", false)) and library != null:
		cells -= maxi(int(library.rules.get("variant_change_max", 0)), 0)
	return maxi(cells, 0)


## Most units a half of [param real_cells] real cells may hold (audit section 8.4 table).
static func max_units_for(real_cells: int) -> int:
	if real_cells <= SQUARE_CELLS:
		return SQUARE_MAX_UNITS
	if real_cells <= THREE_UNIT_CELLS:
		return 3
	return MAX_UNITS


## Checks the unit count and occupancy of [param entries] (cleaned entries) on an arena of [param real_cells] real
## cells per half. [param cells_of] = the occupied cells of each entry, same order. Appends the reasons to
## [param problems]; true when every rule passes. [param shape_id] is "" for a direct arena block (then a multi-cell
## unit never gets company).
static func check_layout(entries: Array[Dictionary], cells_of: Array[int], real_cells: int, shape_id: String, where: String,
		problems: Array[String]) -> bool:
	var ok: bool = true
	var units: int = entries.size()
	if units < 1:
		problems.append("%s: needs at least one enemy" % where)
		return false
	if units > MAX_UNITS:
		problems.append("%s: %d units, the cap is %d" % [where, units, MAX_UNITS])
		ok = false
	var cells: int = 0
	var multi: int = 0
	for n: int in cells_of:
		cells += n
		if n > 1:
			multi += 1
	if cells > MAX_UNIT_CELLS:
		problems.append("%s: %d occupied cells, the cap is %d" % [where, cells, MAX_UNIT_CELLS])
		ok = false
	if multi > 0 and units > 1 and not WARDEN_PACK_SHAPES.has(shape_id):
		problems.append("%s: a multi-cell unit may only have company on %s (arena '%s')" % [where, ", ".join(WARDEN_PACK_SHAPES), shape_id])
		ok = false
	if real_cells < 0:
		problems.append("%s: arena unknown, cannot check the unit count" % where)
		return false
	var cap: int = max_units_for(real_cells)
	if units > cap:
		problems.append("%s: %d units on a %d-cell half, the cap there is %d" % [where, units, real_cells, cap])
		ok = false
	if cells * 3 > real_cells:
		problems.append("%s: %d occupied cells exceed a third of the %d-cell half" % [where, cells, real_cells])
		ok = false
	if real_cells - cells < MIN_FREE_CELLS:
		problems.append("%s: only %d free cells left, at least %d needed" % [where, real_cells - cells, MIN_FREE_CELLS])
		ok = false
	var required: int = 0
	for e: Dictionary in entries:
		if bool(e.get("required", true)):
			required += 1
	if required == 0:
		problems.append("%s: no enemy is required, the fight could never be won" % where)
		ok = false
	return ok


## Cleans one formation block [param raw] with id [param fid]. [param templates] = the chapter's `matches`,
## [param library] the arenas (null = direct arena blocks only), [param footprint_fn] see [method footprint_cells].
## Returns the cleaned formation, or {} when any rule fails (every reason in [param problems]). A cleaned formation:
## {id, name_key, type, arena, attack_slots, hp_budget_mult, enemies: [entries], unit_cells}.
static func clean_formation(fid: String, raw: Variant, templates: Dictionary, library: ArenaLibrary, footprint_fn: Callable,
		chapter_id: String, problems: Array[String]) -> Dictionary:
	var where: String = "formation '%s' of '%s'" % [fid, chapter_id]
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("%s: not an object" % where)
		return {}
	var src: Dictionary = raw as Dictionary
	if templates.has(fid):
		problems.append("%s: id collides with a match of the chapter" % where)
		return {}
	var before: int = problems.size()
	var type: String = str(src.get("type", ""))
	if not TYPES.has(type):
		problems.append("%s: type '%s' unknown (allowed %s)" % [where, type, ", ".join(TYPES)])
	var entries: Array[Dictionary] = []
	var raw_enemies: Variant = src.get("enemies")
	if typeof(raw_enemies) != TYPE_ARRAY:
		problems.append("%s: enemies must be an array" % where)
	else:
		for e: Variant in raw_enemies as Array:
			var entry: Dictionary = clean_entry(e, templates, where, problems)
			if not entry.is_empty():
				entries.append(entry)
	if entries.is_empty():
		problems.append("%s: no valid enemy" % where)
		return {}
	var arena: Dictionary = {}
	if src.has("arena"):
		if typeof(src["arena"]) == TYPE_DICTIONARY:
			arena = (src["arena"] as Dictionary).duplicate(true)
		else:
			problems.append("%s: arena must be an object" % where)
	elif typeof((templates[entries[0]["id"]] as Dictionary).get("arena")) == TYPE_DICTIONARY:
		arena = ((templates[entries[0]["id"]] as Dictionary)["arena"] as Dictionary).duplicate(true)
	var cells_of: Array[int] = []
	for entry: Dictionary in entries:
		cells_of.append(footprint_cells(templates[entry["id"]] as Dictionary, footprint_fn))
	check_layout(entries, cells_of, half_cells(arena, library), str(arena.get("shape", "")), where, problems)
	var slots: int = 1
	if src.has("attack_slots"):
		slots = int(src["attack_slots"])
		if slots < 1 or slots > entries.size():
			problems.append("%s: attack_slots %d must be 1..%d (units)" % [where, slots, entries.size()])
	var budget: float = 1.0
	if src.has("hp_budget_mult"):
		budget = float(src["hp_budget_mult"])
		if budget <= 0.0:
			problems.append("%s: hp_budget_mult must be > 0" % where)
	if problems.size() > before:
		return {}
	var total: int = 0
	for n: int in cells_of:
		total += n
	return {
		"id": fid, "name_key": str(src.get("name_key", "formation.%s.name" % fid)), "type": type, "arena": arena,
		"attack_slots": slots, "hp_budget_mult": budget, "enemies": entries, "unit_cells": total,
	}


## Cleans a chapter's whole `formations` block (id -> block). Invalid formations are left out; every reason lands in
## [param problems] (and is also pushed as a warning so a data error shows in the editor log).
static func clean_block(raw: Variant, templates: Dictionary, library: ArenaLibrary, footprint_fn: Callable, chapter_id: String,
		problems: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("formations of '%s' must be an object" % chapter_id)
		push_warning("ChaptersConfig: " + problems[problems.size() - 1])
		return out
	for fid: Variant in (raw as Dictionary).keys():
		var count: int = problems.size()
		var cleaned: Dictionary = clean_formation(str(fid), (raw as Dictionary)[fid], templates, library, footprint_fn, chapter_id, problems)
		for i: int in range(count, problems.size()):
			push_warning("ChaptersConfig: " + problems[i])
		if not cleaned.is_empty():
			out[str(fid)] = cleaned
	return out


## The `enemy_skills.json` footprint lookup for [method footprint_offsets]: Callable(enemy id) -> [[dx, dy], ...]
## ([[0, 0]] for an unknown enemy).
static func skills_footprint_fn(skills: EnemySkillsConfig) -> Callable:
	return func(enemy_id: String) -> Array:
		var enemy: Dictionary = skills.get_enemy(enemy_id)
		var out: Array = []
		for o: Variant in enemy.get("footprint", []) as Array:
			if typeof(o) == TYPE_VECTOR2I:
				out.append([(o as Vector2i).x, (o as Vector2i).y])
		return out if not out.is_empty() else [[0, 0]]
