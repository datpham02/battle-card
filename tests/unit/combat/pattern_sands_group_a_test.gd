extends SceneTree
## Monster Skill Phase 2 group S-A (MONSTER-SKILL-PHASE2-PLAN.md §5): the shipped enemy_skills.json entries of
## dune_jackal / sand_beetle / dust_nomad on the shipped dunes / oasis grids.
## - jackal_pack_nip: hits for its data damage, then CHASES — the followup is `relative_to: player`, so the second
##   strike lands on the hero's cell at followup time, not on the first cells; weight x1.5 with an ally alive;
## - beetle_sand_spray: a 2-cell bar on the hero, data damage, and the struck cells are left SANDED (TileHazards).
##   Deviation from design §4.3, approved in the plan: the design sands one cell of the bar, the engine has no zone
##   subset, so both sand; FairnessCheck still refuses any zone cell that would leave the hero no exit;
## - nomad_ambush: a T that covers the hero, cast ONLY after the hero has stood still >= 1.2 s (conditions), weight 2;
## - nomad_veil_step: the Nomad steps to a far cell of its half and is untargetable (evade) for 0.6 s; it does not
##   count as a cast.
## Hit damage is read from the shipped data, not hardcoded, so a tuning pass moves the numbers without touching this.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sands_group_a_test.gd

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
	test_jackal_nip_then_chases_the_hero()
	test_jackal_weight_rises_with_an_ally()
	test_beetle_bar_damages_and_sands()
	test_nomad_ambush_waits_for_a_still_hero()
	test_nomad_ambush_is_a_t_over_the_hero()
	test_nomad_veil_step_moves_far_and_evades()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _world(enemy_id: String, shape: String, seed_value: int = 1) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(shape, seed_value), _cfg, enemy_id, seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)  # combat.json numbers
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


func _run(w: Dictionary, seconds: float, bot: String = "still") -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds - 0.000001 and not (w["state"] as CombatState).is_player_dead():
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		(w["hazards"] as TileHazards).tick(STEP, w["state"])
		(w["mover"] as UnitMover).tick(STEP)
		ctrl.tick(STEP)
		t += STEP
		if bot == "dodge":
			var red: Array[Vector2i] = ctrl.telegraph_cells()
			if red.has((w["state"] as CombatState).player_cell) and (w["mover"] as UnitMover).is_ready():
				var path: Array[Vector2i] = FairnessCheck.escape_path(w["state"].grid, (w["state"] as CombatState).player_cell,
					red, 99.0, 0.0, 0.45, 0.0, ctrl.fairness_env())
				if not path.is_empty():
					(w["mover"] as UnitMover).try_step(path[0] - (w["state"] as CombatState).player_cell)


## Damage of [param id] as the shipped data sets it (followup effects when [param followup]).
func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))


## Runs until [param skill_id] resolves (hit or miss) or [param limit] s pass. Returns the event.
func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0, bot: String = "still") -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP, bot)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
				return ev
		seen = ctrl.event_log.size()
	return {}


func _until_stage(w: Dictionary, stage: int, limit: float = 6.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["dune_jackal", "sand_beetle", "dust_nomad"]:
		_check("enemy %s loaded" % id, not _cfg.get_enemy(id).is_empty())
	var jackal: Dictionary = _cfg.get_enemy("dune_jackal")
	_check("jackal: nip + sidestep, sidestep weight 0.6 by override",
		(jackal["phases"][0]["skills"] as Array) == ["jackal_pack_nip", "shared_sidestep"]
		and is_equal_approx(float(_cfg.skill_for_phase("shared_sidestep", jackal["phases"][0])["weight"]), 0.6))
	_check("beetle: spray only", (_cfg.get_enemy("sand_beetle")["phases"][0]["skills"] as Array) == ["beetle_sand_spray"])
	_check("nomad: ambush + veil step", (_cfg.get_enemy("dust_nomad")["phases"][0]["skills"] as Array) == ["nomad_ambush", "nomad_veil_step"])
	for id: String in ["jackal_pack_nip", "beetle_sand_spray", "nomad_ambush", "nomad_veil_step"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id)
		_check("%s names its delivery" % id, (s["delivery"] as Dictionary).has("type"))
	_check("jackal followup chases the hero (relative_to player)",
		str((_cfg.skills["jackal_pack_nip"]["followup"] as Dictionary)["relative_to"]) == "player")
	_check("beetle leaves sand, not fire",
		str(((_cfg.skills["beetle_sand_spray"]["effects"] as Dictionary)["zone"] as Dictionary)["id"]) == "sand")
	_check("ambush is gated on a still hero >= 1.2 s",
		is_equal_approx(float((_cfg.skills["nomad_ambush"]["conditions"] as Dictionary).get("player_still_sec", 0.0)), 1.2))
	_check("veil step does not count as a cast", not bool(_cfg.skills["nomad_veil_step"].get("counts_as_cast", true)))
	# Tuning guard, as for Hellfire: no Sands hit, even x1.5 on a Rạn stack, reaches half the lowest hero max HP.
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json"))
	var low: float = INF
	for c: Dictionary in (chars["characters"] as Array):
		var attrs: Dictionary = c.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", c.get("max_hp", INF))))
	var worst: float = 0.0
	for sid: String in ["jackal_pack_nip", "beetle_sand_spray", "nomad_ambush"]:
		worst = maxf(worst, 1.5 * _dmg(sid))
		if not (_cfg.skills[sid]["followup"] as Dictionary).is_empty():
			worst = maxf(worst, 1.5 * _dmg(sid, true))
	_check("guard: the worst S-A hit (x1.5 Rạn) < half the lowest hero HP", worst > 0.0 and worst < 0.5 * low,
		"%.1f vs %.1f" % [worst, 0.5 * low])


func test_jackal_nip_then_chases_the_hero() -> void:
	var w: Dictionary = _world("dune_jackal", "dunes")
	var state: CombatState = w["state"]
	var ev: Dictionary = _until_resolve(w, "jackal_pack_nip")
	_check("jackal: the nip resolves", not ev.is_empty())
	_check("jackal: nip damage from data (%.0f)" % _dmg("jackal_pack_nip"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("jackal_pack_nip")), str(ev))
	# The chase: a second warning follows, and its cells sit on the hero's CURRENT cell, not the first ones.
	var ctrl: PatternController = w["ctrl"]
	_check("jackal: a second warning follows the nip", _until_stage(w, PatternController.Stage.WARNING, 3.0))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("jackal: the chase lands on the hero's cell", red.has(state.player_cell), str(red))
	var hp: float = state.player_hp
	var ev2: Dictionary = _until_resolve(w, "jackal_pack_nip", 4.0)
	_check("jackal: the chase costs its own data damage (%.0f)" % _dmg("jackal_pack_nip", true),
		not ev2.is_empty() and is_equal_approx(hp - state.player_hp, _dmg("jackal_pack_nip", true)),
		"%s -> %s" % [hp, state.player_hp])


func test_jackal_weight_rises_with_an_ally() -> void:
	var w: Dictionary = _world("dune_jackal", "dunes")
	var ctrl: PatternController = w["ctrl"]
	var skill: Dictionary = _cfg.skills["jackal_pack_nip"]
	var alone: float = PatternBrain.weight_for(skill, {}, {"player_cell": (w["state"] as CombatState).player_cell, "allies_alive": 0},
		_cfg.ai)
	var packed: float = PatternBrain.weight_for(skill, {}, {"player_cell": (w["state"] as CombatState).player_cell, "allies_alive": 1},
		_cfg.ai)
	_check("jackal: an ally alive multiplies the nip's weight by 1.5",
		packed > alone and is_equal_approx(packed, alone * 1.5), "%.2f -> %.2f" % [alone, packed])


func test_beetle_bar_damages_and_sands() -> void:
	var w: Dictionary = _world("sand_beetle", "dunes")
	var state: CombatState = w["state"]
	var hazards: TileHazards = w["hazards"]
	var ctrl: PatternController = w["ctrl"]
	_check("beetle: the spray warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("beetle: a 2-cell bar covering the hero", red.size() == 2 and red.has(state.player_cell), str(red))
	var ev: Dictionary = _until_resolve(w, "beetle_sand_spray")
	_check("beetle: spray damage from data (%.0f)" % _dmg("beetle_sand_spray"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("beetle_sand_spray")), str(ev))
	# The sand is read from TileHazards, not from the event log: PatternController._record keeps only
	# t / skill / event / cells / hit / damage / phase / followup_strike, so a zone_cells lookup there is always empty.
	# The bar is anchored ON the hero and TileHazards._schedule refuses a cell a unit stands on, so the hero's own cell
	# is never sanded and the sand lands on the REST of the bar — the design's "cell farthest from the hero" (§4.3)
	# reached by an existing engine rule rather than by a zone subset selector.
	var struck: Array = ev.get("cells", []) as Array
	var rest: Array[Vector2i] = []
	for c: Vector2i in struck:
		if c != state.player_cell:
			rest.append(c)
	_check("beetle: the bar covers a cell beside the hero", not rest.is_empty(), str(struck))
	var landed: Array[Vector2i] = []
	for c: Vector2i in rest:
		if hazards.is_sanded(P, c) or hazards.is_sand_warning(P, c):
			landed.append(c)
	_check("beetle: the rest of the bar is sand (or its warning)", landed.size() == rest.size(),
		"%s of %s" % [str(landed), str(rest)])
	_check("beetle: the hero's own cell is never sanded",
		not (hazards.is_sanded(P, state.player_cell) or hazards.is_sand_warning(P, state.player_cell)),
		str(state.player_cell))
	# F3 fairness: a zone may never take the hero's last way out, so the bar can never strand them.
	_check("beetle: the hero still has a cell to step to",
		FairnessCheck.zone_leaves_exit(state.grid, state.player_cell, landed, ctrl.fairness_env()))


func test_nomad_ambush_waits_for_a_still_hero() -> void:
	# A hero who keeps moving is never ambushed: the condition gates the skill, not just its weight.
	var w: Dictionary = _world("dust_nomad", "oasis")
	var ctrl: PatternController = w["ctrl"]
	var mover: UnitMover = w["mover"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	while t < 12.0:
		_run(w, STEP)
		t += STEP
		if mover.is_ready():  # never stand still for a second
			for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
				if mover.try_step(d):
					break
	var casts: int = 0
	for ev: Dictionary in ctrl.event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == "nomad_ambush":
			casts += 1
	_check("nomad: a hero who keeps moving is never ambushed", casts == 0, str(casts))
	# Standing still long enough brings it out.
	var w2: Dictionary = _world("dust_nomad", "oasis", 2)
	var ev: Dictionary = _until_resolve(w2, "nomad_ambush", 20.0)
	_check("nomad: a hero who stands still is ambushed", not ev.is_empty())
	_check("nomad: ambush damage from data (%.0f)" % _dmg("nomad_ambush"),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("nomad_ambush")), str(ev))


func test_nomad_ambush_is_a_t_over_the_hero() -> void:
	var w: Dictionary = _world("dust_nomad", "oasis", 2)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	var red: Array[Vector2i] = []
	while t < 20.0:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == PatternController.Stage.WARNING and str(ctrl.get_current_skill().get("id", "")) == "nomad_ambush":
			red = ctrl.telegraph_cells()
			break
	_check("nomad: the ambush warns", not red.is_empty())
	_check("nomad: the T covers the hero", red.has(state.player_cell), str(red))
	_check("nomad: the T is 4 cells or fewer on this grid", red.size() <= 4 and red.size() >= 2, str(red))


func test_nomad_veil_step_moves_far_and_evades() -> void:
	var w: Dictionary = _world("dust_nomad", "oasis", 3)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var before: Vector2i = state.cell_of(E)
	var ev: Dictionary = _until_resolve(w, "nomad_veil_step", 20.0)
	_check("nomad: the veil step resolves", not ev.is_empty())
	_check("nomad: it ends up on a different cell", state.cell_of(E) != before,
		"%s -> %s" % [before, state.cell_of(E)])
	_check("nomad: it is untargetable right after the step", ctrl.is_evading())
	_run(w, 0.8)
	_check("nomad: the evade has run out 0.8 s later", not ctrl.is_evading())


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	var keys: Array[String] = ["enemy_skill.jackal_pack_nip.name", "enemy_skill.jackal_pack_nip.counter",
		"enemy_skill.beetle_sand_spray.name", "enemy_skill.beetle_sand_spray.counter",
		"enemy_skill.nomad_ambush.name", "enemy_skill.nomad_ambush.counter",
		"enemy_skill.nomad_veil_step.name", "enemy_skill.nomad_veil_step.counter"]
	var seen: Dictionary = {}
	for line: String in raw.split("\n"):
		var row: PackedStringArray = line.strip_edges().split(",")
		if row.size() > 0 and keys.has(row[0]):
			seen[row[0]] = line.strip_edges()
	_check("strings: all 8 S-A rows exist", seen.size() == keys.size(), str(seen.keys()))
	for k: String in seen:
		var cols: PackedStringArray = (seen[k] as String).split(",")
		var quoted: bool = (seen[k] as String).contains("\"")
		_check("strings: %s parses as 3 columns" % k, quoted or cols.size() == 3, seen[k])
