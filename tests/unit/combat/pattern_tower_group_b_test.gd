extends SceneTree
## Monster Skill Phase 2 group T-B: snow_wolf, fuse_golem and rime_archer — the Tháp Sương (`ch3`) middle
## normals, on the shipped pillars / rect / staircase grids. Hệ số vùng: ×2,0.
## - snow_wolf_hunt: a two-cell line along the hero's row, slow, and a weight that doubles on a chilled hero;
## - fuse_shard_burst: three loose cells whose SHAPE changes between casts, + 1 tầng Giá Lạnh;
## - rime_frost_arrow: a four-cell line along the hero's row, clipped to the arena;
## - rime_caltrops: a thorns zone beside the hero, never under them.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_tower_group_b_test.gd
##
## THE WEIGHT LEG IS THE POINT OF THIS SUITE, and it is the one that needs an argument.
## `snow_wolf_hunt` ships `weights: {player_status: {frost: 1.8}}` — "hunt harder once the prey is cold".
## Every other leg here passes identically if the engine ignores that block: the charge still runs the row,
## still slows, still deals its damage. A data-shape check ("the block is present") would also pass while
## the number does nothing, because presence in JSON is not behaviour. So the leg below runs the SAME wolf
## twice over many seeds — once against a clean hero, once against a chilled one — and demands the chilled
## run produce strictly more charges. That is the only form of this check that can come out false if the
## weighting is dead.
##
## WHY `min_cells` IS ASSERTED AND NOT QUIETLY LOWERED:
## `rime_frost_arrow` clips to 2 cells on a cramped arena. The temptation when a leg goes red is to drop
## `min_cells` to 1 — which turns a four-cell volley into a single dart and quietly changes the skill.
## The leg instead demands the arrow be a LINE (>= 2 cells, all sharing a row).

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

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
	test_wolf_runs_the_row_and_slows()
	test_wolf_hunts_harder_once_the_hero_is_chilled()
	test_shard_burst_scatters_and_chills()
	test_shard_burst_actually_varies_its_shape()
	test_frost_arrow_is_a_line()
	test_caltrops_land_beside_the_hero_never_under()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


func _only(ids: Array, shape: String, seed_value: int = 1, weight_override: Dictionary = {}) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weight_override.has(id):
			skills[id]["weight"] = weight_override[id]
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


func _count_resolves(w: Dictionary, skill_id: String, seconds: float) -> int:
	var ctrl: PatternController = w["ctrl"]
	var before: int = ctrl.event_log.size()
	_run(w, seconds)
	var n: int = 0
	for i: int in range(before, ctrl.event_log.size()):
		var ev: Dictionary = ctrl.event_log[i]
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
			n += 1
	return n


## [hits of skill_id, resolves of every skill] over [param seconds] — the second number is what turns a
## raw count into a share, so a cooldown ceiling cannot masquerade as "the weighting did nothing".
func _count_both(w: Dictionary, skill_id: String, seconds: float) -> Array:
	var ctrl: PatternController = w["ctrl"]
	var before: int = ctrl.event_log.size()
	_run(w, seconds)
	var mine: int = 0
	var all: int = 0
	for i: int in range(before, ctrl.event_log.size()):
		var ev: Dictionary = ctrl.event_log[i]
		if str(ev.get("event", "")) != "resolve":
			continue
		all += 1
		if str(ev.get("skill", "")) == skill_id:
			mine += 1
	return [mine, all]


func _shape_key(cells: Array) -> String:
	if cells.is_empty():
		return ""
	var min_x: int = (cells[0] as Vector2i).x
	var min_y: int = (cells[0] as Vector2i).y
	for c: Vector2i in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var norm: Array[Vector2i] = []
	for c: Vector2i in cells:
		norm.append(Vector2i(c.x - min_x, c.y - min_y))
	norm.sort()
	return str(norm)


func _all_same_row(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var y: int = (cells[0] as Vector2i).y
	for c: Vector2i in cells:
		if c.y != y:
			return false
	return true


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["snow_wolf", "fuse_golem", "rime_archer"]:
		_check("enemy %s is in enemy_skills.json" % id, not _cfg.get_enemy(id).is_empty())
	for id: String in ["snow_wolf_hunt", "fuse_shard_burst", "rime_frost_arrow", "rime_caltrops"]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	var hunt: Dictionary = _cfg.skills.get("snow_wolf_hunt", {})
	var weights: Dictionary = hunt.get("weights", {}) as Dictionary
	var by_status: Dictionary = weights.get("player_status", {}) as Dictionary
	_check("the wolf's frost weighting survived normalisation", by_status.has("frost"), str(weights))
	# The Wolf keeps shared_sidestep at a reduced weight; it is an override, not a skill of its own.
	var wolf: Dictionary = _cfg.get_enemy("snow_wolf")
	_check("snow_wolf is not given a sidestep skill of its own",
		not _cfg.skills.has("snow_wolf_sidestep"), str(wolf))


func test_wolf_runs_the_row_and_slows() -> void:
	var w: Dictionary = _only(["snow_wolf_hunt"], "pillars")
	var ev: Dictionary = _until_resolve(w, "snow_wolf_hunt")
	_check("wolf hunt resolves", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = ev.get("cells", []) as Array
	_check("the charge covers two cells", cells.size() == 2, str(cells))
	# row_of_player walks off.x ALONG the row. A charge drawn across rows would be a different move.
	_check("the charge runs along one row, not across rows", _all_same_row(cells), str(cells))
	_check("the charge deals the data damage",
		is_equal_approx(float(ev.get("damage", 0.0)), _dmg("snow_wolf_hunt")))
	var st: StatusEffects = w["status"]
	_check("the charge leaves the hero slowed", st.get_slow_left(P) > 0.0, str(st.get_slow_left(P)))


## THE WEIGHT LEG. Two runs of the same wolf, identical but for the hero's Giá Lạnh.
##
## The first version of this leg counted charges with the wolf's own two skills at their shipped weights,
## and got chilled=40 clean=40 — not because the weighting is dead, but because the count was SATURATED:
## with windup + warning + recovery + a 3.2 s cooldown the wolf fits about five charges into thirty
## seconds whatever its weight, so multiplying an already-winning weight cannot move the number. That is
## the mirror of a check that cannot fail — a check that cannot succeed — and it would have been read as
## "the engine ignores `weights`" by whoever saw it next.
##
## So the rival is given a weight the wolf must BEAT: sidestep at 3.0 against the hunt's 1.0. Clean, the
## hunt wins about a quarter of the picks; chilled (x1.8) about a third. Neither run is cooldown-bound,
## so the share can move, and the comparison is of SHARES, not raw counts.
func test_wolf_hunts_harder_once_the_hero_is_chilled() -> void:
	var rival: Dictionary = {"shared_sidestep": 3.0, "snow_wolf_hunt": 1.0}
	var clean_hunt: int = 0
	var clean_all: int = 0
	var chilled_hunt: int = 0
	var chilled_all: int = 0
	for seed_value: int in range(1, 9):
		var a: Dictionary = _only(["snow_wolf_hunt", "shared_sidestep"], "pillars", seed_value, rival)
		var a_counts: Array = _count_both(a, "snow_wolf_hunt", 30.0)
		clean_hunt += a_counts[0]
		clean_all += a_counts[1]
		var b: Dictionary = _only(["snow_wolf_hunt", "shared_sidestep"], "pillars", seed_value, rival)
		(b["status"] as StatusEffects).apply_frost(P, 1)
		var b_counts: Array = _count_both(b, "snow_wolf_hunt", 30.0)
		chilled_hunt += b_counts[0]
		chilled_all += b_counts[1]
	# Guard the guard: if neither run cast anything the shares are both 0 and the leg would "pass" by
	# comparing nothing. Demand real activity first.
	_check("both runs actually cast something", clean_all > 0 and chilled_all > 0,
		"clean_all=%d chilled_all=%d" % [clean_all, chilled_all])
	if clean_all == 0 or chilled_all == 0:
		return
	var clean_share: float = float(clean_hunt) / float(clean_all)
	var chilled_share: float = float(chilled_hunt) / float(chilled_all)
	_check("a chilled hero raises the hunt's share of the wolf's picks over 8 seeds",
		chilled_share > clean_share,
		"chilled=%.3f (%d/%d) clean=%.3f (%d/%d)"
			% [chilled_share, chilled_hunt, chilled_all, clean_share, clean_hunt, clean_all])


func test_shard_burst_scatters_and_chills() -> void:
	var w: Dictionary = _only(["fuse_shard_burst"], "rect")
	var ev: Dictionary = _until_resolve(w, "fuse_shard_burst")
	_check("shard burst resolves", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = ev.get("cells", []) as Array
	_check("shard burst covers at least two cells (clip keeps it castable)", cells.size() >= 2, str(cells))
	# The chill rides on a HIT, and the burst is three loose cells the hero is meant to step out of — the
	# first version of this leg asserted frost after any resolve and read 0 because that cast simply
	# missed. So: find a cast that actually connected, then demand the stack.
	var hit: Dictionary = {}
	for seed_value: int in range(1, 13):
		var w2: Dictionary = _only(["fuse_shard_burst"], "rect", seed_value)
		for _i: int in range(4):
			var ev2: Dictionary = _until_resolve(w2, "fuse_shard_burst", 12.0)
			if ev2.is_empty():
				break
			if bool(ev2.get("hit", false)):
				hit = ev2
				_check("a connecting burst leaves 1 tầng Giá Lạnh",
					(w2["status"] as StatusEffects).frost_stacks(P) >= 1,
					str((w2["status"] as StatusEffects).frost_stacks(P)))
				break
		if not hit.is_empty():
			break
	_check("the burst connects at least once across seeds (else the leg above proves nothing)",
		not hit.is_empty())


## Same hole as the bat swarm's: every other leg passes if the engine freezes on the first shape forever.
func test_shard_burst_actually_varies_its_shape() -> void:
	var shapes: Dictionary = {}
	for seed_value: int in range(1, 13):
		var w: Dictionary = _only(["fuse_shard_burst"], "rect", seed_value)
		for _i: int in range(3):
			var ev: Dictionary = _until_resolve(w, "fuse_shard_burst", 12.0)
			if ev.is_empty():
				break
			var key: String = _shape_key(ev.get("cells", []) as Array)
			if not key.is_empty():
				shapes[key] = true
	_check("the burst uses at least two distinct shapes across seeds", shapes.size() >= 2,
		"shapes=%d" % shapes.size())


func test_frost_arrow_is_a_line() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only(["rime_frost_arrow"], "staircase", seed_value)
		var ev: Dictionary = _until_resolve(w, "rime_frost_arrow", 12.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		# NOT "exactly 4": the staircase clips. But a clipped volley must still be a LINE of >= 2 —
		# lowering min_cells to 1 would make this pass while turning the skill into a single dart.
		_check("arrow seed %d is a line of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_row(cells), str(cells))
	_check("the arrow casts on the staircase at all", seen)


func test_caltrops_land_beside_the_hero_never_under() -> void:
	var w: Dictionary = _only(["rime_caltrops"], "staircase")
	var ev: Dictionary = _until_resolve(w, "rime_caltrops", 16.0)
	_check("caltrops resolve", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = ev.get("cells", []) as Array
	var hero: Vector2i = (w["state"] as CombatState).cell_of(P)
	var under_hero: bool = false
	for c: Vector2i in cells:
		if c == hero:
			under_hero = true
	_check("caltrops never land on the hero's own cell", not under_hero,
		"hero=%s cells=%s" % [hero, cells])
	_check("caltrops cover one cell", cells.size() == 1, str(cells))


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["snow_wolf_hunt", "fuse_shard_burst", "rime_frost_arrow", "rime_caltrops"]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))
