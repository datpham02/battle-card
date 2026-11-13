extends SceneTree
## Monster Skill Phase 1 group C, the two Hellfire elites (MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md §5 C), on the shipped
## forge / caldera grids:
## - fire_eater: eater_ember_belch (column of the hero, 12, the cells burn 2.5 s, hit or miss); eater_devour (only with
##   >= 2 burning cells anywhere; swallows EVERY burning cell of both halves, +6 HP each, capped at max HP; a hit during
##   its 1.4 s windup interrupts it: 1 s stun, no heal, the fires stay); trait burn_eater (fire heals it, R1 immune);
## - ash_phoenix: phoenix_ash_dive (an L over the hero, 12 + 1 Rạn, stacking with another source up to the cap);
##   phoenix_pyre (once below 50 % HP: 3 cells beside the hero burn 4 s, never the hero's cell, an exit kept, cannot be
##   interrupted); trait rebirth (lethal blow -> held at 1 HP, PatternController paused, back at 40 %, which opens the
##   pyre; one Hàn stack makes the death final).
## Neither elite hurts itself with its own skills. Also: every strings.csv row of the Hellfire skill keys parses as
## exactly 3 columns (an unquoted comma once shifted the English column).
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_hellfire_group_c_test.gd

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
	test_belch_column_damage_and_fire()
	test_belch_fire_forms_on_a_miss()
	test_devour_needs_two_fires()
	test_devour_swallows_both_halves_and_heals()
	test_devour_heal_capped()
	test_devour_interrupted_stuns_without_heal()
	test_devour_skips_terrain_fire()
	test_burn_eater_heals_and_is_r1_immune()
	test_dive_l_damage_and_fragile_stacking()
	test_pyre_once_below_half_beside_the_hero()
	test_rebirth_pauses_and_opens_the_pyre()
	test_rebirth_frost_makes_death_final()
	test_strings_rows_have_three_columns()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _only(skill_ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
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


func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0, need_hit: bool = true, bot: String = "still") -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP, bot)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id and (bool(ev.get("hit", false)) or not need_hit):
				return ev
		seen = ctrl.event_log.size()
	return {}


func _until_stage(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit and ctrl.get_stage() != stage:
		_run(w, STEP)
		t += STEP
	return ctrl.get_stage() == stage


func _count(w: Dictionary, skill_id: String) -> int:
	var n: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
			n += 1
	return n


func _player_fires(w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: BoardGrid = (w["state"] as CombatState).grid
	for c: Vector2i in (w["status"] as StatusEffects).burning_cells():
		if grid.is_player_cell(c):
			out.append(c)
	return out


# Two enemy-half cells away from the enemy and two player-half cells away from the hero (fires for devour).
func _fire_cells(w: Dictionary) -> Array[Vector2i]:
	var state: CombatState = w["state"]
	var out: Array[Vector2i] = []
	for c: Vector2i in state.grid.enemy_cells():
		if c != state.enemy_cell and out.size() < 2:
			out.append(c)
	for c: Vector2i in state.grid.player_cells():
		if absi(c.x - state.player_cell.x) + absi(c.y - state.player_cell.y) >= 2 and out.size() < 4:
			out.append(c)
	return out


func test_data_shape() -> void:
	var eater: Dictionary = _cfg.get_enemy("fire_eater")
	_check("eater: elite, belch + devour, mechanic devour", str(eater["tier"]) == "elite"
		and (eater["phases"][0]["skills"] as Array) == ["eater_ember_belch", "eater_devour"] and str(eater["phases"][0]["mechanic"]) == "eater_devour")
	var phoenix: Dictionary = _cfg.get_enemy("ash_phoenix")
	_check("phoenix: elite, dive + pyre", str(phoenix["tier"]) == "elite" and (phoenix["phases"][0]["skills"] as Array) == ["phoenix_ash_dive", "phoenix_pyre"])
	for id: String in ["eater_ember_belch", "eater_devour", "phoenix_ash_dive", "phoenix_pyre"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys and a delivery" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id and (s["delivery"] as Dictionary).has("type"))


func test_belch_column_damage_and_fire() -> void:
	var w: Dictionary = _only(["eater_ember_belch"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	_check("belch: warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	var column: bool = red.size() >= 2 and red.size() <= 3 and red.has(state.player_cell)
	for c: Vector2i in red:
		column = column and c.x == state.player_cell.x
	_check("belch: 2-3 cells down the hero's column", column, str(red))
	var ev: Dictionary = _until_resolve(w, "eater_ember_belch")
	_check("belch: data damage", not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("eater_ember_belch")), str(ev))
	var lit: bool = not red.is_empty()
	for c: Vector2i in red:
		lit = lit and status.is_burning(c)
	_check("belch: every struck cell burns 2.5 s", lit and absf(status.get_burn_left(red[0]) - 2.5) < 0.11)
	_check("belch: nothing on the enemy half", status.burning_cells().all(func(c: Vector2i) -> bool: return state.grid.is_player_cell(c)))


func test_belch_fire_forms_on_a_miss() -> void:
	var w: Dictionary = _only(["eater_ember_belch"], "forge")
	var state: CombatState = w["state"]
	var ev: Dictionary = _until_resolve(w, "eater_ember_belch", 20.0, false, "dodge")
	_check("belch: the dodger is missed", not ev.is_empty() and not bool(ev["hit"]) and is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	_check("belch: the column still burns after a miss", _player_fires(w).size() >= 2, str(_player_fires(w)))
	_check("belch: the dodger does not stand in the fire", not (w["status"] as StatusEffects).is_burning(state.player_cell))


func test_devour_needs_two_fires() -> void:
	var w: Dictionary = _only(["eater_devour"], "forge")
	var status: StatusEffects = w["status"]
	_run(w, 4.0)
	_check("devour: not chosen with no fire", _count(w, "eater_devour") == 0)
	status.ignite([_fire_cells(w)[0]] as Array[Vector2i], 20.0, 0.5, 0.0)
	_run(w, 4.0)
	_check("devour: not chosen with one fire", _count(w, "eater_devour") == 0)
	status.ignite([_fire_cells(w)[1]] as Array[Vector2i], 20.0, 0.5, 0.0)
	var ev: Dictionary = _until_resolve(w, "eater_devour", 6.0, false)
	_check("devour: chosen with two fires", not ev.is_empty())


func test_devour_swallows_both_halves_and_heals() -> void:
	var w: Dictionary = _only(["eater_devour"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	state.enemy_hp = 500.0
	var fires: Array[Vector2i] = _fire_cells(w)
	status.ignite(fires, 20.0, 0.5, 0.0)
	_check("devour: 4 fires lit, 2 per half", fires.size() == 4 and status.burning_cells().size() == 4, str(fires))
	var ev: Dictionary = _until_resolve(w, "eater_devour", 6.0, false)
	_check("devour: resolved", not ev.is_empty())
	_check("devour: every fire of both halves is out", status.burning_cells().is_empty(), str(status.burning_cells()))
	_check("devour: +6 HP per fire (24)", is_equal_approx(state.enemy_hp, 524.0), str(state.enemy_hp))
	_check("devour: the hero is untouched", is_equal_approx(state.player_hp, 100.0))


func test_devour_heal_capped() -> void:
	var w: Dictionary = _only(["eater_devour"], "forge")
	var state: CombatState = w["state"]
	state.enemy_hp = state.enemy_max_hp - 5.0
	(w["status"] as StatusEffects).ignite(_fire_cells(w), 20.0, 0.5, 0.0)
	_until_resolve(w, "eater_devour", 6.0, false)
	_check("devour: heal capped at max HP", is_equal_approx(state.enemy_hp, state.enemy_max_hp), str(state.enemy_hp))


func test_devour_interrupted_stuns_without_heal() -> void:
	var w: Dictionary = _only(["eater_devour"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	state.enemy_hp = 500.0
	status.ignite(_fire_cells(w), 20.0, 0.5, 0.0)
	_check("devour: winds up", _until_stage(w, PatternController.Stage.WINDUP))
	_check("devour: blinking interrupt tell", ctrl.interrupt_tell())
	_check("devour: a hit interrupts it", ctrl.on_enemy_hit())
	_check("devour: stunned", ctrl.get_stage() == PatternController.Stage.STUNNED)
	_run(w, 0.9)
	_check("devour: still stunned at 0.9 s", ctrl.get_stage() == PatternController.Stage.STUNNED)
	_check("devour: no heal, the fires stay", is_equal_approx(state.enemy_hp, 500.0) and status.burning_cells().size() == 4, str(state.enemy_hp))
	_check("devour: cooldown x cancel ratio (9 x 0.5)", absf(ctrl.cooldown_left("eater_devour") - (4.5 - 0.9)) < 0.11, str(ctrl.cooldown_left("eater_devour")))


# R11 (user-approved fix, 2026-11-13): devour only swallows fire a skill or a card lit (zone fire). A lava vent lights
# its cells through StatusEffects.ignite(terrain = true): that fire neither counts for the `burning_cells` condition nor
# feeds the heal, and it keeps burning.
func test_devour_skips_terrain_fire() -> void:
	var w: Dictionary = _only(["eater_devour"], "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	state.enemy_hp = 500.0
	var row: Array[Vector2i] = []
	for c: Vector2i in state.grid.player_cells():
		if c.y == 0:
			row.append(c)
	status.ignite(row, 20.0, 0.5, 0.0, true)
	_run(w, 4.0)
	_check("R11: a vent row alone (terrain fire) never triggers devour", _count(w, "eater_devour") == 0, str(_count(w, "eater_devour")))
	# Two zone fires on the dry row: devour now fires and eats only those two.
	var zone: Array[Vector2i] = []
	for c: Vector2i in state.grid.player_cells():
		if c.y == 2 and zone.size() < 2 and c != state.player_cell:
			zone.append(c)
	status.ignite(zone, 20.0, 0.5, 0.0)
	_until_resolve(w, "eater_devour", 6.0, false)
	_check("R11: devour fires once two zone fires burn", _count(w, "eater_devour") == 1)
	var vent_still: bool = not row.is_empty()
	for c: Vector2i in row:
		vent_still = vent_still and status.is_burning(c)
	_check("R11: the vent row keeps burning", vent_still)
	_check("R11: the zone fires are eaten", zone.all(func(c: Vector2i) -> bool: return not status.is_burning(c)))
	_check("R11: +6 per zone fire only (512)", is_equal_approx(state.enemy_hp, 500.0 + 6.0 * zone.size()), "%s zone, hp %s" % [zone.size(), state.enemy_hp])


func test_burn_eater_heals_and_is_r1_immune() -> void:
	var w: Dictionary = _world("fire_eater", "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var host: TraitHost = TraitHost.new({"status": status, "state": state}, [{"id": "burn_eater", "params": {"heal_ratio": 1.0}}], 1)
	state.enemy_hp = 500.0
	status.ignite([state.enemy_cell] as Array[Vector2i], 2.0, 0.5, 2.0)
	status.tick(1.0, state)
	_check("burn_eater: two ticks of 2 on its cell heal it (504)", is_equal_approx(state.enemy_hp, 504.0), str(state.enemy_hp))
	_check("burn_eater: R1 never fires on it", not status.reaction_allowed(E, "r1"))
	_check("burn_eater: R2 / R3 still can", status.reaction_allowed(E, "r2") and status.reaction_allowed(E, "r3"))
	host.teardown_all()


func test_dive_l_damage_and_fragile_stacking() -> void:
	var w: Dictionary = _only(["phoenix_ash_dive"], "caldera")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	_check("dive: warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("dive: an L of 3 over the hero", red.size() == 3 and red.has(state.player_cell), str(red))
	# The Imp's mark already on the hero: the dive spends it (x1.5) and leaves its own.
	status.apply_fragile(P, 1)
	var ev: Dictionary = _until_resolve(w, "phoenix_ash_dive")
	_check("dive: x1.5 against an earlier Rạn", not ev.is_empty() and is_equal_approx(float(ev["damage"]), 1.5 * _dmg("phoenix_ash_dive")), str(ev))
	_check("dive: leaves 1 Rạn", status.fragile_stacks(P) == 1, str(status.fragile_stacks(P)))
	status.apply_fragile(P, 5)
	_check("dive: Rạn never passes the cap (3)", status.fragile_stacks(P) == 3, str(status.fragile_stacks(P)))


func test_pyre_once_below_half_beside_the_hero() -> void:
	var w: Dictionary = _only(["phoenix_pyre"], "caldera")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	_run(w, 6.0)
	_check("pyre: never above 50 % HP", _count(w, "phoenix_pyre") == 0)
	state.enemy_hp = state.enemy_max_hp * 0.45
	var hp: float = state.enemy_hp
	_check("pyre: warns below 50 %", _until_stage(w, PatternController.Stage.WARNING))
	_check("pyre: the solid ivory tell (cannot be interrupted)", ctrl.uninterruptible_tell() and not ctrl.on_enemy_hit())
	_until_resolve(w, "phoenix_pyre", 4.0, false)
	var lit: Array[Vector2i] = _player_fires(w)
	_check("pyre: 1-3 cells burn (F3 may drop one), never the hero's cell", lit.size() >= 1 and lit.size() <= 3 and not lit.has(state.player_cell), str(lit))
	var near: bool = not lit.is_empty()
	for c: Vector2i in lit:
		near = near and absi(c.x - state.player_cell.x) + absi(c.y - state.player_cell.y) <= 3
	_check("pyre: the cells are around the hero", near, str(lit))
	_check("pyre: 4 s burn", not lit.is_empty() and absf(status.get_burn_left(lit[0]) - 4.0) < 0.11)
	var exit: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = state.player_cell + d
		if state.grid.is_player_cell(n) and not status.is_burning(n):
			exit = true
	_check("pyre: the hero keeps an unburnt neighbour", exit)
	_check("pyre: the hero standing still takes no damage", is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	_check("pyre: the Phoenix is not hurt by its own pyre", is_equal_approx(state.enemy_hp, hp), str(state.enemy_hp))
	_run(w, 10.0)
	_check("pyre: once only", _count(w, "phoenix_pyre") == 1, str(_count(w, "phoenix_pyre")))


func test_rebirth_pauses_and_opens_the_pyre() -> void:
	var w: Dictionary = _world("ash_phoenix", "caldera")
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	# ~20 s of a standing hero under the dive: give it room so the match does not end on the hero's death first.
	state.player_max_hp = 1000.0
	state.player_hp = 1000.0
	var rebirth: RebirthTrait = TraitRegistry.create("rebirth") as RebirthTrait
	rebirth.setup({"state": state, "status": w["status"], "pattern_getter": func() -> PatternController: return ctrl}, {"revive_ratio": 0.4, "revive_sec": 1.5}, 1)
	rebirth.on_match_start()
	state.enemy_death_hook_fn = Callable(rebirth, "on_boss_would_die")
	_run(w, 3.0)
	_check("rebirth: no pyre at full HP", _count(w, "phoenix_pyre") == 0)
	# Act: one lethal blow from full HP (the pyre never had its chance).
	state.damage_enemy(state.enemy_max_hp + 50.0)
	_check("rebirth: held at 1 HP, reviving, pattern paused", rebirth.is_reviving() and not state.is_enemy_dead() and not ctrl.is_active())
	for i: int in 30:
		_run(w, STEP)
		rebirth.on_tick(STEP)
	_check("rebirth: back at 40 %, pattern active", not rebirth.is_reviving() and is_equal_approx(state.enemy_hp, state.enemy_max_hp * 0.4) and ctrl.is_active(),
		str(state.enemy_hp))
	var ev: Dictionary = _until_resolve(w, "phoenix_pyre", 15.0, false)
	_check("rebirth: the revived Phoenix (40 % < 50 %) lights its pyre", not ev.is_empty())
	rebirth.teardown()


func test_rebirth_frost_makes_death_final() -> void:
	var w: Dictionary = _world("ash_phoenix", "caldera")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	var rebirth: RebirthTrait = TraitRegistry.create("rebirth") as RebirthTrait
	rebirth.setup({"state": state, "status": status, "pattern_getter": func() -> PatternController: return ctrl}, {}, 1)
	rebirth.on_match_start()
	state.enemy_death_hook_fn = Callable(rebirth, "on_boss_would_die")
	status.apply_frost(E, 1)
	state.damage_enemy(state.enemy_max_hp + 50.0)
	_check("rebirth: with 1 Hàn the Phoenix dies for good", state.is_enemy_dead() and not rebirth.is_reviving())
	rebirth.teardown()


func test_strings_rows_have_three_columns() -> void:
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	var bad: Array[String] = []
	var seen: Dictionary = {}
	var keys: Array[String] = ["ui.status.poison.name", "ui.status.poison.desc"]
	for id: String in _cfg.skills:
		var owner: String = str((_cfg.skills[id] as Dictionary)["owner"])
		if owner in ["shared", "imp", "ember_hound", "ash_golem", "flame_cultist", "magma_slug", "hell_knight", "fire_eater", "ash_phoenix"]:
			keys.append("enemy_skill.%s.name" % id)
			keys.append("enemy_skill.%s.counter" % id)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 0 or keys.find(row[0]) < 0:
			continue
		seen[row[0]] = true
		if row.size() != 3 or row[1].is_empty() or row[2].is_empty():
			bad.append("%s (%d columns)" % [row[0], row.size()])
	var missing: Array[String] = keys.filter(func(k: String) -> bool: return not seen.has(k))
	_check("strings: every Hellfire skill / poison key is present", missing.is_empty(), str(missing))
	_check("strings: those rows parse as exactly key, vi, en", bad.is_empty(), str(bad))


# Monster Skill Phase 1 tuning (2026-11-13): hit damage is read from the shipped data (set by
# production/qa/evidence/monster-skill-hellfire/tuning/scale_hellfire_damage.py); the test checks the pipeline delivers it.
func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))
