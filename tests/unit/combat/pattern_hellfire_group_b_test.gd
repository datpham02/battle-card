extends SceneTree
## Monster Skill Phase 1 group B "lửa cắt đường" (MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md §5 B): the shipped entries of
## flame_cultist / magma_slug / hell_knight on the shipped forge / caldera grids:
## - cultist_kindle: two cells BESIDE the hero burn 3 s (2 per 0.5 s), never the hero's cell, an exit always kept; the
##   zone budget `max_zone_cells {burn: 3}` holds it while >= 3 player-half cells burn and frees it when they go out;
##   shared_jab keeps hurting meanwhile (no starvation while the row_burner's row burns);
## - slug_lava_spit: 8 on the hero's cell and that cell burns 2 s afterwards (the standing hero takes the ticks);
## - slug_molten_trail: the Slug shifts a row and the cell it LEFT burns; its new cell does not;
## - knight_cleave: a 3-cell bar along the hero's row, 14, not interruptible; knight_bulwark: once below 50 % HP, Guard +5 / 4 s.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_hellfire_group_b_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_kindle_burns_two_cells_beside_the_hero()
	test_kindle_waits_for_the_burn_budget_and_jab_keeps_going()
	test_spit_hits_and_leaves_a_burning_cell()
	test_molten_trail_burns_the_cell_left()
	test_cleave_row_bar_uninterruptible()
	test_bulwark_once_below_half()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _only(skill_ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
	# A config holding only the named shipped skills (raw JSON re-read), so a test forces one behaviour.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in skill_ids:
		skills[id] = (data["skills"] as Dictionary)[id]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills, "enemies": {"g": {"ai": {"noise": 0.0}, "skills": skill_ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	return w


func _world(enemy_id: String, shape: String, seed_value: int = 1) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(shape, seed_value), _cfg, enemy_id, seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	return w


func _run(w: Dictionary, seconds: float, bot: String = "still") -> void:
	Fx.run(w["ctrl"], w["state"], w["status"], w["mover"], seconds, bot, STEP)


# Runs the standing-still bot until [param skill_id] resolves (hit or not when [param need_hit] is false). Returns the event.
func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0, need_hit: bool = true) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id and (bool(ev.get("hit", false)) or not need_hit):
				return ev
		seen = ctrl.event_log.size()
	return {}


func _burning_player_cells(w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: BoardGrid = (w["state"] as CombatState).grid
	for c: Vector2i in (w["status"] as StatusEffects).burning_cells():
		if grid.is_player_cell(c):
			out.append(c)
	return out


func test_data_shape() -> void:
	_check("cultist: kindle + jab", (_cfg.get_enemy("flame_cultist")["phases"][0]["skills"] as Array) == ["cultist_kindle", "shared_jab"])
	_check("slug: spit + trail", (_cfg.get_enemy("magma_slug")["phases"][0]["skills"] as Array) == ["slug_lava_spit", "slug_molten_trail"])
	_check("knight: cleave + bulwark", (_cfg.get_enemy("hell_knight")["phases"][0]["skills"] as Array) == ["knight_cleave", "knight_bulwark"])
	for id: String in ["shared_jab", "cultist_kindle", "slug_lava_spit", "slug_molten_trail", "knight_cleave", "knight_bulwark"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys and a delivery" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id and (s["delivery"] as Dictionary).has("type"))
	_check("kindle carries the burn budget", int(((_cfg.skills["cultist_kindle"]["conditions"] as Dictionary)["max_zone_cells"] as Dictionary)["burn"]) == 3)
	_check("trail is a self zone", str((_cfg.skills["slug_molten_trail"]["effects"]["zone"] as Dictionary)["side"]) == "self")


func test_kindle_burns_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only(["cultist_kindle"], "caldera")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "cultist_kindle", 10.0, false)
	_check("kindle: resolved", not ev.is_empty())
	var lit: Array[Vector2i] = _burning_player_cells(w)
	_check("kindle: two player-half cells burn", lit.size() == 2, str(lit))
	_check("kindle: never the hero's cell", not lit.has(state.player_cell))
	var adjacent: bool = not lit.is_empty()
	for c: Vector2i in lit:
		adjacent = adjacent and (absi(c.x - state.player_cell.x) + absi(c.y - state.player_cell.y) <= 2)
	_check("kindle: the cells are beside the hero (a 2-cell bar touching it)", adjacent, str(lit))
	_check("kindle: 3 s burn", not lit.is_empty() and absf(status.get_burn_left(lit[0]) - 3.0) < 0.11)
	_check("kindle: 0 damage to the standing hero (nothing lands on its cell)", is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	# F3: an exit stays open.
	var exit: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = state.player_cell + d
		if state.grid.is_player_cell(n) and not status.is_burning(n):
			exit = true
	_check("kindle: the hero keeps an unburnt neighbour", exit)


func test_kindle_waits_for_the_burn_budget_and_jab_keeps_going() -> void:
	# Arrange: the real Cultist (kindle + jab) on the forge; the forge's two vent rows burn (10 of 15 player cells), the
	# row_burner situation. Burning cells are terrain here (ignited directly), the hero stands on the dry row.
	var w: Dictionary = _world("flame_cultist", "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	var rows: Array[Vector2i] = []
	for c: Vector2i in state.grid.player_cells():
		if c.y != 2:
			rows.append(c)
	state.set_player_cell(Vector2i(2, 2))
	status.ignite(rows, 3.0, 0.5, 2.0)
	_check("budget: 10 cells burn", _burning_player_cells(w).size() == 10)
	# Act: 3 s of the fire: kindle must not be chosen, the jab must still warn at least once (no starvation).
	# Counters are Arrays: a GDScript lambda captures an int by value, so `n += 1` inside it never reaches this scope.
	var kindle_during: Array = []
	var jab_during: Array = []
	var on_warning: Callable = func(id: String, _c: Array[Vector2i], _q: Array[Vector2i], _s: float) -> void:
		if id == "cultist_kindle":
			kindle_during.append(id)
		elif id == "shared_jab":
			jab_during.append(id)
	ctrl.warning_started.connect(on_warning)
	_run(w, 3.0)
	ctrl.warning_started.disconnect(on_warning)
	_check("budget: kindle never chosen while 10 cells burn", kindle_during.is_empty(), str(kindle_during.size()))
	_check("budget: the jab still fires (no starvation)", jab_during.size() >= 1, "jab=%d log=%s" % [jab_during.size(), str(ctrl.event_log.slice(0, 4))])
	# After the fire: kindle comes back.
	_check("budget: the terrain fire is out", _burning_player_cells(w).is_empty())
	var ev: Dictionary = _until_resolve(w, "cultist_kindle", 12.0, false)
	_check("budget: kindle chosen once the half is below the budget", not ev.is_empty())


func test_spit_hits_and_leaves_a_burning_cell() -> void:
	var w: Dictionary = _only(["slug_lava_spit"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "slug_lava_spit")
	_check("spit: hits the standing hero for its data damage", not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("slug_lava_spit")), str(ev))
	_check("spit: the hero's cell burns 2 s afterwards", status.is_burning(state.player_cell) and absf(status.get_burn_left(state.player_cell) - 2.0) < 0.11)
	var hp_after_hit: float = state.player_hp
	_run(w, 0.5)
	_check("spit: the standing hero takes the burn tick (2)", is_equal_approx(state.player_hp, hp_after_hit - 2.0), str(state.player_hp))


func test_molten_trail_burns_the_cell_left() -> void:
	var w: Dictionary = _only(["slug_molten_trail"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var from: Vector2i = state.enemy_cell
	var ev: Dictionary = _until_resolve(w, "slug_molten_trail", 10.0, false)
	_check("trail: resolved", not ev.is_empty())
	_check("trail: the Slug moved one row", state.enemy_cell != from and state.enemy_cell.x == from.x and absi(state.enemy_cell.y - from.y) == 1, "%s -> %s" % [from, state.enemy_cell])
	_check("trail: the cell it left burns 2 s", status.is_burning(from) and absf(status.get_burn_left(from) - 2.0) < 0.11)
	_check("trail: its new cell does not burn", not status.is_burning(state.enemy_cell))
	_check("trail: nothing on the player's half", _burning_player_cells(w).is_empty())
	var hp: float = state.enemy_hp
	_run(w, 1.0)
	_check("trail: the Slug does not burn itself", is_equal_approx(state.enemy_hp, hp), str(state.enemy_hp))


func test_cleave_row_bar_uninterruptible() -> void:
	var w: Dictionary = _only(["knight_cleave"], "caldera")
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < 4.0 and ctrl.get_stage() != PatternController.Stage.WARNING:
		_run(w, STEP)
		t += STEP
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	var same_row: bool = not red.is_empty()
	for c: Vector2i in red:
		same_row = same_row and c.y == state.player_cell.y
	_check("cleave: a 2-3 cell bar on the hero's row covering it", red.size() >= 2 and red.size() <= 3 and same_row and red.has(state.player_cell), str(red))
	_check("cleave: the ivory tell (cannot be interrupted)", ctrl.uninterruptible_tell())
	_check("cleave: a hit does not interrupt", not ctrl.on_enemy_hit())
	var ev: Dictionary = _until_resolve(w, "knight_cleave", 5.0)
	_check("cleave: data damage", not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("knight_cleave")), str(ev))


func test_bulwark_once_below_half() -> void:
	var w: Dictionary = _world("hell_knight", "caldera")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	_run(w, 8.0)
	var used: int = 0
	for ev: Dictionary in ctrl.event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == "knight_bulwark":
			used += 1
	_check("bulwark: not used above 50 % HP", used == 0, str(used))
	state.enemy_hp = state.enemy_max_hp * 0.45
	var ev: Dictionary = _until_resolve(w, "knight_bulwark", 12.0, false)
	_check("bulwark: used below 50 %", not ev.is_empty())
	_check("bulwark: Guard +5 for 4 s on the enemy", is_equal_approx(status.guard_amount(E), 5.0) and status.get_guard_left(E) > 3.9 and status.get_guard_left(E) <= 4.0,
		"%s %s" % [status.guard_amount(E), status.get_guard_left(E)])
	_run(w, 15.0)
	used = 0
	for ev2: Dictionary in ctrl.event_log:
		if str(ev2.get("event", "")) == "resolve" and str(ev2.get("skill", "")) == "knight_bulwark":
			used += 1
	_check("bulwark: once only", used == 1, str(used))


# Monster Skill Phase 1 tuning (2026-11-13): hit damage is read from the shipped data (set by
# production/qa/evidence/monster-skill-hellfire/tuning/scale_hellfire_damage.py); the test checks the pipeline delivers it.
func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))
