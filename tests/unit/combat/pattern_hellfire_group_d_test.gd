extends SceneTree
## Monster Skill Phase 1 group D, the Hellfire warden Inferno Lord (MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md §5 D), on the
## shipped caldera:
## - data: tier warden, 1-cell footprint, p1 {brand, cinder_lane, stride} mechanic cinder_lane; p2 at 50 % adds
##   eruption_call (weight 0: only forced), every_nth 3, transition 1.5 s with on_enter eruption_call;
## - p1 never casts the eruption; brand 10 + Rạn; cinder lane 2-3 cells on the hero's row, 14, burns 2 s, cannot be
##   interrupted; stride moves one row;
## - the phase change: one big hit stops at the 50 % floor, 1.5 s of invulnerability with the red cleared, then the
##   eruption first (on_enter), then every 3rd counted cast (stride does not count);
## - eruption_call: 2x2 over the hero, 14; the SAME cells again >= 1 s later with their own warning, 10, then they burn
##   2 s; a hero who left after the first strike takes nothing from the second;
## - the match's own traits stay: `phase_shift` (chapters.json params) turns to phase 2 in the SAME tick as the pattern's
##   transition (one "PHA 2" banner: both announce phase 2 at the same instant) and multiplies the vent timer by 0.7;
## - the Lord never burns itself; its strings rows parse as 3 columns;
## - tuning guard (2026-11-13): no Hellfire hit, even x1.5 on a Rạn, takes half of the lowest hero max HP.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_hellfire_group_d_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const ERUPT: String = "lord_eruption_call"

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
	test_phase1_skills_and_no_eruption()
	test_brand_and_cinder_lane()
	test_phase_change_floor_invulnerability_on_enter()
	test_phase2_every_third_counted_cast_is_the_eruption()
	test_eruption_strikes_the_same_cells_twice_then_burns()
	test_eruption_second_strike_misses_a_hero_who_left()
	test_phase_shift_trait_turns_with_the_pattern()
	test_strings_rows()
	test_no_hellfire_hit_takes_half_the_lowest_hero_hp()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": "caldera"}, _library, seed_value)


func _world(seed_value: int = 1) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(seed_value), _cfg, "inferno_lord", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var state: CombatState = w["state"]
	state.player_max_hp = 2000.0  # long fights under a standing hero; the match must not end on its death
	state.player_hp = 2000.0
	return w


# A config with only the named shipped skills; [param weights] overrides a skill's weight (the eruption is weight 0 in
# data, i.e. forced only, so a fixture that tests the strike alone gives it 1).
func _only(skill_ids: Array, weights: Dictionary = {}, seed_value: int = 1) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in skill_ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weights.has(id):
			(skills[id] as Dictionary)["weight"] = weights[id]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills, "enemies": {"g": {"ai": {"noise": 0.0}, "skills": skill_ids}}})
	var w: Dictionary = Fx.world(_grid(seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	return w


func _run(w: Dictionary, seconds: float, bot: String = "still") -> void:
	Fx.run(w["ctrl"], w["state"], w["status"], w["mover"], seconds, bot, STEP)


func _resolves(w: Dictionary, skill_id: String = "", followups: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) != "resolve":
			continue
		if not skill_id.is_empty() and str(ev["skill"]) != skill_id:
			continue
		if not followups and bool(ev.get("followup_strike", false)):
			continue
		out.append(ev)
	return out


func _until_stage(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit and ctrl.get_stage() != stage:
		_run(w, STEP)
		t += STEP
	return ctrl.get_stage() == stage


func test_data_shape() -> void:
	var lord: Dictionary = _cfg.get_enemy("inferno_lord")
	_check("lord: tier warden, 1-cell footprint", str(lord["tier"]) == "warden" and (lord["footprint"] as Array).size() == 1)
	var phases: Array = lord["phases"]
	_check("lord: two phases", phases.size() == 2)
	if phases.size() != 2:
		return
	var p1: Dictionary = phases[0]
	var p2: Dictionary = phases[1]
	_check("p1: brand, lane, stride; mechanic lane", (p1["skills"] as Array) == ["lord_brand", "lord_cinder_lane", "lord_stride"]
		and str(p1["mechanic"]) == "lord_cinder_lane")
	_check("p2 at 0.5: + eruption, mechanic eruption, every 3rd", is_equal_approx(float(p2["enter_hp_ratio"]), 0.5)
		and (p2["skills"] as Array).has(ERUPT) and str(p2["mechanic"]) == ERUPT
		and str(p2["every_nth"]["skill"]) == ERUPT and int(p2["every_nth"]["n"]) == 3)
	_check("p2 transition 1.5 s, on_enter eruption", is_equal_approx(float(p2["transition"]["sec"]), 1.5)
		and (p2["transition"]["on_enter"] as Array) == [ERUPT])
	_check("eruption: weight 0 (forced only), not interruptible", is_equal_approx(float(_cfg.skills[ERUPT]["weight"]), 0.0)
		and not bool(_cfg.skills[ERUPT]["interruptible"]))
	var fu: Dictionary = _cfg.skills[ERUPT]["followup"]
	_check("eruption followup: same cells, 1 s delay, 1 s warning, a hit + burn", str(fu["relative_to"]) == "same_cells"
		and is_equal_approx(float(fu["delay_sec"]), 1.0) and is_equal_approx(float(fu["warning_sec"]), 1.0)
		and float(fu["effects"]["damage"]) > 0.0 and str((fu["effects"]["zone"] as Dictionary)["id"]) == "burn")
	for id: String in ["lord_brand", "lord_cinder_lane", "lord_stride", ERUPT]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys and a delivery" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id and (s["delivery"] as Dictionary).has("type"))


func test_phase1_skills_and_no_eruption() -> void:
	var w: Dictionary = _world()
	_run(w, 40.0)
	var seen: Dictionary = {}
	for ev: Dictionary in _resolves(w):
		seen[str(ev["skill"])] = true
	_check("p1: brand, lane and stride all used in 40 s", seen.has("lord_brand") and seen.has("lord_cinder_lane") and seen.has("lord_stride"), str(seen.keys()))
	_check("p1: never the eruption", not seen.has(ERUPT))
	_check("p1: still phase 0", (w["ctrl"] as PatternController).get_phase_index() == 0)


func test_brand_and_cinder_lane() -> void:
	var wb: Dictionary = _only(["lord_brand"])
	_run(wb, 3.0)
	var brand: Array[Dictionary] = _resolves(wb, "lord_brand")
	_check("brand: data damage on the standing hero + 1 Rạn", not brand.is_empty() and is_equal_approx(float(brand[0]["damage"]), _dmg("lord_brand"))
		and (wb["status"] as StatusEffects).fragile_stacks(P) >= 1, str(brand))
	var wl: Dictionary = _only(["lord_cinder_lane"])
	var state: CombatState = wl["state"]
	var status: StatusEffects = wl["status"]
	var ctrl: PatternController = wl["ctrl"]
	_check("lane: warns", _until_stage(wl, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	var row: bool = red.size() >= 2 and red.size() <= 3 and red.has(state.player_cell)
	for c: Vector2i in red:
		row = row and c.y == state.player_cell.y
	_check("lane: 2-3 cells on the hero's row", row, str(red))
	_check("lane: cannot be interrupted (ivory tell)", ctrl.uninterruptible_tell() and not ctrl.on_enemy_hit())
	_until_stage(wl, PatternController.Stage.RECOVERY)
	var lane: Array[Dictionary] = _resolves(wl, "lord_cinder_lane")
	_check("lane: data damage", not lane.is_empty() and is_equal_approx(float(lane[0]["damage"]), _dmg("lord_cinder_lane")), str(lane))
	var lit: bool = not red.is_empty()
	for c: Vector2i in red:
		lit = lit and status.is_burning(c)
	_check("lane: the lane burns 2 s", lit and absf(status.get_burn_left(red[0]) - 2.0) < 0.11)
	_check("lane: the Lord's cell is not burning", not status.is_burning(state.enemy_cell))


func test_phase_change_floor_invulnerability_on_enter() -> void:
	var w: Dictionary = _world()
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	_run(w, 2.0)
	# One huge hit from full HP stops at the 50 % floor.
	state.damage_enemy(state.enemy_max_hp * 2.0)
	_check("phase: one hit stops at 50 %", is_equal_approx(state.enemy_hp, state.enemy_max_hp * 0.5), str(state.enemy_hp))
	_run(w, STEP)
	_check("phase: transition, phase 1 (p2)", ctrl.get_stage() == PatternController.Stage.TRANSITION and ctrl.get_phase_index() == 1)
	_check("phase: the red is cleared", ctrl.telegraph_cells().is_empty())
	var hp: float = state.enemy_hp
	state.damage_enemy(100.0)
	_check("phase: invulnerable during the 1.5 s transition", is_equal_approx(state.enemy_hp, hp))
	var first: Array = []
	var on_warning: Callable = func(id: String, _c: Array[Vector2i], _q: Array[Vector2i], _s: float) -> void:
		if first.is_empty():
			first.append(id)
	ctrl.warning_started.connect(on_warning)
	_run(w, 1.4)
	_check("phase: still transitioning at 1.45 s", ctrl.get_stage() == PatternController.Stage.TRANSITION)
	_run(w, 3.0)
	ctrl.warning_started.disconnect(on_warning)
	_check("phase: the first warning of p2 is the eruption (on_enter)", first == [ERUPT], str(first))
	state.damage_enemy(10.0)
	_check("phase: vulnerable again after the transition", state.enemy_hp < hp)


func test_phase2_every_third_counted_cast_is_the_eruption() -> void:
	var w: Dictionary = _world(3)
	var state: CombatState = w["state"]
	state.damage_enemy(state.enemy_max_hp * 0.6)
	_run(w, 60.0)
	# Counted casts after the transition: first strikes only (a followup is part of its cast), stride excluded
	# (counts_as_cast false).
	var seq: Array[String] = []
	for ev: Dictionary in _resolves(w, "", false):
		if int(ev["phase"]) == 1 and str(ev["skill"]) != "lord_stride":
			seq.append(str(ev["skill"]))
	var bad: Array[int] = []
	var eruptions: int = 0
	for i: int in seq.size():
		if seq[i] == ERUPT:
			eruptions += 1
			var n: int = i + 1
			if n != 1 and n % 3 != 0:
				bad.append(n)
	_check("p2: the first counted cast is the eruption", not seq.is_empty() and seq[0] == ERUPT, str(seq.slice(0, 6)))
	_check("p2: an eruption only at cast 1 or every 3rd cast", bad.is_empty(), "bad=%s seq=%s" % [bad, seq])
	_check("p2: at least 4 eruptions in 60 s (no starvation)", eruptions >= 4, str(eruptions))
	_check("p2: brand and lane still used", seq.has("lord_brand") or seq.has("lord_cinder_lane"))


func test_eruption_strikes_the_same_cells_twice_then_burns() -> void:
	var w: Dictionary = _only([ERUPT], {ERUPT: 1.0})
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	state.player_max_hp = 200.0
	state.player_hp = 200.0
	var warnings: Array = []
	var on_warning: Callable = func(_id: String, cells: Array[Vector2i], _q: Array[Vector2i], sec: float) -> void:
		warnings.append({"cells": cells.duplicate(), "sec": sec, "t": ctrl.event_log.size()})
	ctrl.warning_started.connect(on_warning)
	_check("eruption: warns", _until_stage(w, PatternController.Stage.WARNING))
	var first: Array[Vector2i] = ctrl.telegraph_cells()
	_check("eruption: 2x2 over the hero", first.size() == 4 and first.has(state.player_cell), str(first))
	_check("eruption: cannot be interrupted", not ctrl.on_enemy_hit())
	_until_stage(w, PatternController.Stage.FOLLOWUP_WAIT)
	_check("eruption: first strike (data)", is_equal_approx(state.player_hp, 200.0 - _dmg(ERUPT)), str(state.player_hp))
	_run(w, 0.95)
	_check("eruption: no second warning before 1 s", warnings.size() == 1)
	_until_stage(w, PatternController.Stage.WARNING, 1.0)
	_check("eruption: second warning on the SAME cells, 1 s long", warnings.size() == 2 and (warnings[1]["cells"] as Array) == (first as Array)
		and is_equal_approx(float(warnings[1]["sec"]), 1.0), str(warnings))
	_until_stage(w, PatternController.Stage.RECOVERY, 2.0)
	ctrl.warning_started.disconnect(on_warning)
	_check("eruption: second strike (data, both strikes)", is_equal_approx(state.player_hp, 200.0 - _dmg(ERUPT) - _dmg(ERUPT, true)), str(state.player_hp))
	var lit: bool = true
	for c: Vector2i in first:
		lit = lit and status.is_burning(c)
	_check("eruption: the 4 cells burn after the second strike", lit and absf(status.get_burn_left(first[0]) - 2.0) < 0.11)
	_check("eruption: the Lord is not burning", not status.is_burning(state.enemy_cell))


func test_eruption_second_strike_misses_a_hero_who_left() -> void:
	var w: Dictionary = _only([ERUPT], {ERUPT: 1.0})
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	_until_stage(w, PatternController.Stage.WARNING)
	var first: Array[Vector2i] = ctrl.telegraph_cells()
	_until_stage(w, PatternController.Stage.FOLLOWUP_WAIT)
	var hp: float = state.player_hp
	# The hero steps out to a cell outside the 2x2 (any real neighbour that is not struck) and stays there.
	var out_cell: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in state.grid.player_cells():
		if not first.has(c) and absi(c.x - state.player_cell.x) + absi(c.y - state.player_cell.y) <= 2:
			out_cell = c
			break
	_check("left: found a cell outside the eruption", out_cell != BoardGrid.NO_CELL)
	state.set_player_cell(out_cell)
	_until_stage(w, PatternController.Stage.RECOVERY, 3.0)
	_check("left: the second strike does not follow the hero (same cells, 0 damage)", is_equal_approx(state.player_hp, hp), str(state.player_hp))
	var second: Array[Dictionary] = []
	for ev: Dictionary in ctrl.event_log:
		if str(ev.get("event", "")) == "resolve" and bool(ev.get("followup_strike", false)):
			second.append(ev)
	_check("left: the second strike resolved on the first cells", second.size() == 1 and (second[0]["cells"] as Array) == (first as Array), str(second))


func test_phase_shift_trait_turns_with_the_pattern() -> void:
	# The match's own traits from chapters.json, next to the pattern brain (decision: phase_shift stays a trait).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json"))
	var match_def: Dictionary = {}
	for chapter: Variant in data["chapters"]:
		if str((chapter as Dictionary)["id"]) == "hellfire":
			match_def = (chapter["matches"] as Dictionary)["inferno_lord"]
	_check("chapters: inferno_lord runs the pattern brain with its own id", str(match_def.get("brain", "")) == "pattern"
		and str(match_def.get("enemy", "")) == "inferno_lord")
	var trait_ids: Array = (match_def.get("traits", []) as Array).map(func(t: Variant) -> String: return str((t as Dictionary)["id"]))
	_check("chapters: traits unchanged (vent_surge, phase_shift)", trait_ids == ["vent_surge", "phase_shift"], str(trait_ids))
	var w: Dictionary = _world()
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	var grid: BoardGrid = state.grid
	var hazards: TileHazards = TileHazards.new(grid, 1)
	hazards.bind_state(state)
	var hz: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": "caldera"}}, grid, _library)
	hazards.set_vents(P, hz["vents_player"] as Array)
	hazards.set_vents(E, hz["vents_enemy"] as Array)
	var timer_before: float = hazards.vent_timer_left()
	var host: TraitHost = TraitHost.new({"state": state, "grid": grid, "status": w["status"], "hazards": hazards}, match_def["traits"] as Array, 1)
	host.on_match_start()
	var banners: Array = []
	host.phase_changed.connect(func(phase: int) -> void: banners.append(phase))
	var shift: PhaseShiftTrait = host.get_trait("phase_shift") as PhaseShiftTrait
	_check("trait: phase_shift built from chapters.json", shift != null and shift.get_phase() == 1)
	_check("trait: vent_surge built too", host.get_trait("vent_surge") != null)
	# One frame as CombatView runs it: the hit, then the pattern tick, then the traits.
	state.damage_enemy(state.enemy_max_hp * 2.0)
	ctrl.tick(STEP)
	host.on_tick(STEP)
	_check("same tick: the pattern is transitioning to p2", ctrl.get_stage() == PatternController.Stage.TRANSITION and ctrl.get_phase_index() == 1)
	_check("same tick: phase_shift is in phase 2", shift != null and shift.get_phase() == 2)
	_check("same tick: phase_shift announced phase 2 once (CombatView's pattern announce is also 2: one banner)", banners == [2], str(banners))
	_check("vents: phase_shift multiplied the vent timer by 0.7", absf(hazards.vent_timer_left() - timer_before * 0.7) < 0.01,
		"%s -> %s" % [timer_before, hazards.vent_timer_left()])
	host.on_tick(STEP)
	_check("phase_shift fires once", banners == [2])
	host.teardown_all()


func test_strings_rows() -> void:
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	var keys: Array[String] = []
	for id: String in ["lord_brand", "lord_cinder_lane", "lord_stride", ERUPT]:
		keys.append("enemy_skill.%s.name" % id)
		keys.append("enemy_skill.%s.counter" % id)
	var seen: Dictionary = {}
	var bad: Array[String] = []
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 0 or keys.find(row[0]) < 0:
			continue
		seen[row[0]] = true
		if row.size() != 3 or row[1].is_empty() or row[2].is_empty():
			bad.append("%s (%d)" % [row[0], row.size()])
	_check("strings: the Lord's 8 keys exist", seen.size() == keys.size(), str(seen.keys()))
	_check("strings: each parses as key, vi, en", bad.is_empty(), str(bad))


# Tuning guard (2026-11-13, damage raised after group E): every direct hit of the 9 Hellfire enemies, x1.5 against a Rạn
# stack (the worst single hit), stays under half of the lowest hero max HP in characters.json, so no strike one-shots.
func test_no_hellfire_hit_takes_half_the_lowest_hero_hp() -> void:
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json"))
	var low: float = INF
	for c: Dictionary in (chars["characters"] as Array):
		# 2026-11-13: characters.json moved the base stats into `attributes` (the flat spelling is still accepted).
		var attrs: Dictionary = c.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", c.get("max_hp", INF))))
	_check("guard: the lowest hero max HP is read", low < INF and low > 0.0, str(low))
	var worst: float = 0.0
	var worst_id: String = ""
	for eid: String in ["imp", "ember_hound", "ash_golem", "flame_cultist", "magma_slug", "hell_knight", "fire_eater", "ash_phoenix", "inferno_lord"]:
		for sid: String in _skills_of(eid):
			for fu: bool in [false, true]:
				if fu and (_cfg.skills[sid]["followup"] as Dictionary).is_empty():
					continue
				var hit: float = 1.5 * _dmg(sid, fu)
				if hit > worst:
					worst = hit
					worst_id = sid
	_check("guard: the worst Hellfire hit (x1.5 Rạn) < half the lowest hero HP", worst > 0.0 and worst < 0.5 * low, "%s %.1f vs %.1f" % [worst_id, worst, 0.5 * low])

# Monster Skill Phase 1 tuning (2026-11-13): hit damage is read from the shipped data (set by
# production/qa/evidence/monster-skill-hellfire/tuning/scale_hellfire_damage.py); the test checks the pipeline delivers it.
func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))

# Every skill id an enemy's phases use (normalized config).
func _skills_of(eid: String) -> Array[String]:
	var out: Array[String] = []
	for ph: Dictionary in (_cfg.get_enemy(eid).get("phases", []) as Array):
		for sid: String in (ph["skills"] as Array):
			if not out.has(sid):
				out.append(sid)
	return out
