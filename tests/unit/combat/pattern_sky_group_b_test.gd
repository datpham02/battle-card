extends SceneTree
## Monster Skill Phase 2 group S-B: storm_eagle, sky_sentinel and thunder_shaman — the Không Đảo
## (`sky_isles`) middle normals, on twin_isles / three_isles / islands_bridge. Hệ số: ×2,5.
## - eagle_talon_rake: three cells along the hero's row;
## - sentinel_stone_gale: ONE cell beside the hero is made to fall;
## - sentinel_spear: two cells straight down the hero's column;
## - shaman_thunder_call: three loose bolts whose shape changes, freezing the feet on a hit.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sky_group_b_test.gd
##
## THE FALLING-CELL LEG IS THE POINT OF THIS SUITE, and like the shroud in group S-A the effect had
## NEVER SHIPPED: before this region no skill anywhere used `zone {id: "fall"}`. The road is
## PatternController (`"fall"` case, :1035) -> TileHazards.drop_cells(). The design marks it "mới", so
## the first question is not "does it fall in a good place" but "does anything fall at all".
##
## AND THE LEG MUST NOT DEMAND A FALL EVERY TIME. `drop_cells` legitimately returns an empty array:
## it drops cells off the half, cells already cracking, and then applies the leave-a-path rule — and
## "nothing falls at all when it would take the last standing island of the side". On a 12-cell arena
## that is a real outcome, not a bug. A leg that demanded a fall per cast would be asserting the
## arena's safety rule away; one that accepted zero falls forever would pass against a dead wire. So:
## across seeds, at least one cast must actually crack a cell, and no cast may ever crack the hero's
## own cell (the skill ships `exclude_player`).
##
## WHAT THIS SUITE DOES NOT PROVE:
## That a hero standing on a falling cell takes the fall damage and the shove. That path is
## TileHazards -> the model -> the caller, and no fixture here wires the caller.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const RAKE: String = "eagle_talon_rake"
const GALE: String = "sentinel_stone_gale"
const SPEAR: String = "sentinel_spear"
const CALL: String = "shaman_thunder_call"

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " + name) if ok else ("FAIL " + name + (" " + extra if not extra.is_empty() else "")))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_rake_runs_the_row()
	test_stone_gale_actually_drops_a_cell()
	test_stone_gale_never_drops_the_hero_s_own_cell()
	test_spear_runs_down_the_column()
	test_thunder_call_scatters_and_freezes()
	test_thunder_call_varies_its_shape()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


func _only(ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	w["cfg"] = cfg
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var hazards: TileHazards = w["hazards"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	while t < seconds:
		ctrl.tick(STEP)
		if hazards != null:
			hazards.tick(STEP, state)
		t += STEP


func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
				return ev
		seen = ctrl.event_log.size()
	return {}


## True when any cell of the player half is cracking or already fallen.
func _any_dropping(w: Dictionary) -> bool:
	var hazards: TileHazards = w["hazards"]
	var grid: BoardGrid = (w["state"] as CombatState).grid
	if not hazards.fallen_cells(P).is_empty():
		return true
	for x: int in range(-1, 12):
		for y: int in range(-1, 12):
			var c: Vector2i = Vector2i(x, y)
			if grid.is_player_cell(c) and hazards.crumble_progress(P, c) > 0.0:
				return true
	return false


func _all_same_row(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var y: int = (cells[0] as Vector2i).y
	for c: Vector2i in cells:
		if c.y != y:
			return false
	return true


func _all_same_column(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var x: int = (cells[0] as Vector2i).x
	for c: Vector2i in cells:
		if c.x != x:
			return false
	return true


func _shape_key(cells: Array) -> String:
	if cells.is_empty():
		return ""
	var mx: int = (cells[0] as Vector2i).x
	var my: int = (cells[0] as Vector2i).y
	for c: Vector2i in cells:
		mx = mini(mx, c.x)
		my = mini(my, c.y)
	var norm: Array[Vector2i] = []
	for c: Vector2i in cells:
		norm.append(Vector2i(c.x - mx, c.y - my))
	norm.sort()
	return str(norm)


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["storm_eagle", "sky_sentinel", "thunder_shaman"]:
		_check("enemy %s is in enemy_skills.json" % id, not _cfg.get_enemy(id).is_empty())
	for id: String in [RAKE, GALE, SPEAR, CALL]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	if _cfg.skills.has(GALE):
		var z: Dictionary = (_cfg.skills[GALE]["effects"] as Dictionary).get("zone", {}) as Dictionary
		_check("the stone gale ships a fall zone", str(z.get("id", "")) == "fall", str(z))
		_check("and it keeps the hero's own cell out",
			bool((_cfg.skills[GALE]["pattern"] as Dictionary).get("exclude_player", false)))
		# `count` is a MARKER key; an attack carrying it silently places one cell. But this must be
		# asked of the RAW json, not of _cfg: enemy_skills_config.gd:233 normalises EVERY pattern with
		# `"count": maxi(int(d.get("count", 1)), 1)`, so the loaded dict always has the key and the
		# check would fail on correct data. The first version of this leg read _cfg and went red
		# against a file that is right — a test that cannot pass, which is as useless as one that
		# cannot fail and reads as a data defect while it does it.
		var raw_all: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
		var raw_pattern: Dictionary = (((raw_all["skills"] as Dictionary)[GALE] as Dictionary)
			["pattern"] as Dictionary)
		_check("the gale is authored with offsets, not the marker-only `count`",
			not raw_pattern.has("count"), str(raw_pattern))


func test_rake_runs_the_row() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only([RAKE], "twin_isles", seed_value)
		var ev: Dictionary = _until_resolve(w, RAKE, 12.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		_check("rake seed %d is a row of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_row(cells), str(cells))
		_check("rake seed %d deals the data damage" % seed_value,
			is_equal_approx(float(ev.get("damage", 0.0)), _dmg(RAKE)))
	_check("the rake casts on twin_isles at all", seen)


## THE FALL LEG. First skill in the project to use `zone {id: "fall"}`.
func test_stone_gale_actually_drops_a_cell() -> void:
	var dropped_on: int = -1
	var cast_seen: bool = false
	for seed_value: int in range(1, 13):
		var w: Dictionary = _only([GALE], "three_isles", seed_value)
		var ev: Dictionary = _until_resolve(w, GALE, 16.0)
		if ev.is_empty():
			continue
		cast_seen = true
		_run(w, 1.4)                      # let the crack warning start
		if _any_dropping(w):
			dropped_on = seed_value
			break
	_check("the stone gale casts at all", cast_seen)
	# Not "every cast drops": drop_cells refuses when it would take the last standing island, and on a
	# 12-cell arena that is a real outcome. One seed is enough to show the wire is live; zero across
	# twelve would mean nothing ever falls, which is what a dead wire looks like.
	_check("at least one cast across 12 seeds makes a cell crack or fall", dropped_on > 0,
		"dropped_on=%d" % dropped_on)


func test_stone_gale_never_drops_the_hero_s_own_cell() -> void:
	var checked: int = 0
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([GALE], "three_isles", seed_value)
		var ev: Dictionary = _until_resolve(w, GALE, 16.0)
		if ev.is_empty():
			continue
		checked += 1
		var hero: Vector2i = (w["state"] as CombatState).cell_of(P)
		var on_hero: bool = false
		for c: Vector2i in (ev.get("cells", []) as Array):
			if c == hero:
				on_hero = true
		_check("seed %d: the gale does not target the hero's own cell" % seed_value, not on_hero,
			"hero=%s cells=%s" % [hero, ev.get("cells", [])])
	_check("at least one cast was examined (else the legs above are vacuous)", checked > 0)


func test_spear_runs_down_the_column() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only([SPEAR], "three_isles", seed_value)
		var ev: Dictionary = _until_resolve(w, SPEAR, 12.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		# three_isles is only TWO rows tall, so a column here is exactly two cells — and a three-cell
		# column cannot exist on it at all (measured: 0 placements). The design does not ask for one.
		_check("spear seed %d is a column of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_column(cells), str(cells))
	_check("the spear casts on three_isles at all", seen)


func test_thunder_call_scatters_and_freezes() -> void:
	var hit_seen: bool = false
	for seed_value: int in range(1, 13):
		var w: Dictionary = _only([CALL], "islands_bridge", seed_value)
		var ev: Dictionary = _until_resolve(w, CALL, 14.0)
		if ev.is_empty():
			continue
		if not bool(ev.get("hit", false)):
			continue
		hit_seen = true
		_check("a connecting thunder call freezes the hero's feet",
			(w["status"] as StatusEffects).is_pinned(P))
		_check("and it deals the data damage",
			is_equal_approx(float(ev.get("damage", 0.0)), _dmg(CALL)))
		break
	_check("the thunder call connects at least once across seeds (else the legs above prove nothing)",
		hit_seen)


func test_thunder_call_varies_its_shape() -> void:
	var shapes: Dictionary = {}
	for seed_value: int in range(1, 13):
		var w: Dictionary = _only([CALL], "islands_bridge", seed_value)
		for _i: int in range(3):
			var ev: Dictionary = _until_resolve(w, CALL, 12.0)
			if ev.is_empty():
				break
			var key: String = _shape_key(ev.get("cells", []) as Array)
			if not key.is_empty():
				shapes[key] = true
	# Every other leg would pass if the engine froze on the first variant forever; only a comparison
	# across casts can tell "a shape that changes" from "a shape".
	_check("the call uses at least two distinct shapes across seeds", shapes.size() >= 2,
		"shapes=%d" % shapes.size())


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [RAKE, GALE, SPEAR, CALL]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))
