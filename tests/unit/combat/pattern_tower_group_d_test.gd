extends SceneTree
## Monster Skill Phase 2 group T-D: frost_mage (Elite) and mist_lord (Kẻ Gác) — the top of Tháp Sương
## (`ch3`), on the shipped diamond / pillars grids. Hệ số vùng: ×2,0.
## - frost_mage_cold_snap: one cell, +2 tầng Giá Lạnh — two connections reach the burst threshold;
## - frost_mage_rime_field: a thorns zone beside the hero, never under them;
## - frost_mage_ice_ward: a crystal + guard, once, only below half HP;
## - mist_lord: two phases, and the two-beat Whiteout.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_tower_group_d_test.gd
##
## THE CHAIN-CAP LEG IS THE REASON THIS FILE EXISTS, and it is checked in BOTH directions.
##
## The design gave Whiteout's second beat its own +1 tầng Giá Lạnh. Two beats would then leave 2 stacks,
## and the Lord's own Rime Lance (+1) completes the threshold of 3 — a 24-damage burst landing inside a
## window the player is already being asked to escape. Measured at ×2,0 that window is 48 + 24 + 24 = 96,
## or 56% of the squishiest hero's 170 HP; the user had already refused a 58% window in Hầm Ngục. The user
## approved dropping the stack from the second beat on 2026-11-15, as a decision separate from the
## multiplier, so the window caps at 72 (42%) and the burst needs a THIRD, separate strike — which is the
## counterplay §4.6 describes ("đừng ăn cả hai nhịp").
##
## A leg that only asserted "the followup carries no status" would be a data-shape check: it passes while
## the engine happily applies a stack from somewhere else, and it says nothing about what the player
## feels. A leg that only counted stacks after a cast would pass just as well if the whole followup never
## fired. So the leg below runs the SAME Lord twice — once on the shipped data, once on a copy with the
## stack put back — and demands the two runs differ. Only the comparison can come out false if the cap is
## decorative, and only the restored run proves the measurement can see a stack at all.
##
## WHAT THIS SUITE DOES NOT PROVE:
## `mist_lord_crystal_anchor` ships with an `overrides` block in phase 2 raising its count to 2. The legs
## below assert that shape in the data; they do NOT prove two crystals appear, because the marker count
## depends on free cells on the enemy half and no fixture here guarantees two.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const SNAP: String = "frost_mage_cold_snap"
const FIELD: String = "frost_mage_rime_field"
const WARD: String = "frost_mage_ice_ward"
const WHITEOUT: String = "mist_lord_whiteout"
const LANCE: String = "mist_lord_rime_lance"

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
	test_cold_snap_lays_two_stacks()
	test_two_cold_snaps_reach_the_burst()
	test_rime_field_lands_beside_the_hero()
	test_ice_ward_waits_for_half_health()
	test_lord_phases()
	test_whiteout_strikes_twice()
	test_whiteout_second_beat_lays_no_chill()   # <-- the chain cap, both directions
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


## [param patch]: id -> a Dictionary merged into that skill before the config is built, so a leg can run
## the SAME enemy against an altered rule without touching the repo.
func _only(ids: Array, shape: String, seed_value: int = 1, weights: Dictionary = {},
		patch: Dictionary = {}) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weights.has(id):
			skills[id]["weight"] = weights[id]
		if patch.has(id):
			for k: String in (patch[id] as Dictionary):
				skills[id][k] = (patch[id] as Dictionary)[k]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	w["cfg"] = cfg
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds:
		ctrl.tick(STEP)
		t += STEP


func _until(w: Dictionary, skill_id: String, want_followup: bool, limit: float = 24.0) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) != "resolve" or str(ev.get("skill", "")) != skill_id:
				continue
			if bool(ev.get("followup_strike", false)) == want_followup:
				return ev
		seen = ctrl.event_log.size()
	return {}


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["frost_mage", "mist_lord"]:
		_check("enemy %s is in enemy_skills.json" % id, not _cfg.get_enemy(id).is_empty())
	for id: String in [SNAP, FIELD, WARD, WHITEOUT, LANCE]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	if _cfg.skills.has(SNAP):
		var st: Dictionary = (_cfg.skills[SNAP]["effects"] as Dictionary).get("status", {}) as Dictionary
		_check("cold snap lays 2 tầng Giá Lạnh", str(st.get("id", "")) == "frost"
			and int(st.get("stacks", 0)) == 2, str(st))
	if _cfg.skills.has(WARD):
		var c: Dictionary = (_cfg.skills[WARD].get("conditions", {}) as Dictionary)
		_check("the ward is once-only and gated on half health",
			bool(c.get("once", false)) and is_equal_approx(float(c.get("hp_below", 0.0)), 0.5), str(c))


func test_cold_snap_lays_two_stacks() -> void:
	var w: Dictionary = _only([SNAP], "diamond")
	var ev: Dictionary = _until(w, SNAP, false)
	_check("cold snap resolves", not ev.is_empty())
	if ev.is_empty():
		return
	if not bool(ev.get("hit", false)):
		_check("cold snap's first cast connected (else the stack leg proves nothing)", false, str(ev))
		return
	_check("one connecting cold snap leaves 2 tầng",
		(w["status"] as StatusEffects).frost_stacks(P) == 2,
		str((w["status"] as StatusEffects).frost_stacks(P)))


## Two connections are 4 stacks against a threshold of 3 — the design calls this the region's
## must-dodge attack, and this leg is what makes that claim measurable rather than editorial.
func test_two_cold_snaps_reach_the_burst() -> void:
	var w: Dictionary = _only([SNAP], "diamond")
	var st: StatusEffects = w["status"]
	var hp_before: float = (w["state"] as CombatState).player_hp
	var hits: int = 0
	var t: float = 0.0
	var seen: int = 0
	while t < 30.0 and hits < 2:
		_run(w, STEP)
		t += STEP
		var ctrl: PatternController = w["ctrl"]
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == SNAP \
					and bool(ev.get("hit", false)):
				hits += 1
		seen = ctrl.event_log.size()
	_check("two cold snaps connect within 30 s", hits >= 2, "hits=%d" % hits)
	if hits < 2:
		return
	var lost: float = hp_before - (w["state"] as CombatState).player_hp
	# 2 x damage alone, versus 2 x damage PLUS the 24 burst: the gap is what proves the burst fired.
	var without_burst: float = 2.0 * _dmg(SNAP)
	_check("the hero lost more than two plain snaps' worth (the burst landed)",
		lost > without_burst + 1.0, "lost=%.1f plain=%.1f" % [lost, without_burst])
	_check("and the stacks were consumed by the burst, not left standing",
		st.frost_stacks(P) < 3, str(st.frost_stacks(P)))


func test_rime_field_lands_beside_the_hero() -> void:
	var w: Dictionary = _only([FIELD], "diamond")
	var ev: Dictionary = _until(w, FIELD, false, 20.0)
	_check("rime field resolves", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = ev.get("cells", []) as Array
	var hero: Vector2i = (w["state"] as CombatState).cell_of(P)
	var under: bool = false
	for c: Vector2i in cells:
		if c == hero:
			under = true
	_check("the field never covers the hero's own cell", not under, "hero=%s cells=%s" % [hero, cells])
	_check("the field covers at least one cell", cells.size() >= 1, str(cells))


func test_ice_ward_waits_for_half_health() -> void:
	# The WHOLE mage, not a one-skill world. The first version of this leg ran the ward alone, which
	# leaves the brain with no castable candidate at all while the gate is shut — it was measuring a
	# starved controller, not the gate. The shipped wreath_guard leg (pattern_roster_mechanics_test)
	# uses the full enemy and waits 15 s after the drop; copied here rather than re-invented.
	var w: Dictionary = Fx.world(_grid("diamond", 3), _cfg, "frost_mage", 3, 155.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var ctrl: PatternController = w["ctrl"]
	_run(w, 10.0)
	_check("no ward while the mage is above half health", ctrl.marker_cells().is_empty(),
		str(ctrl.marker_cells()))
	var state: CombatState = w["state"]
	state.enemy_hp = state.enemy_max_hp * 0.45
	var placed: bool = false
	var t: float = 0.0
	while t < 15.0 and not placed:
		_run(w, STEP)
		t += STEP
		placed = not ctrl.marker_cells().is_empty()
	_check("the ward goes up once the mage drops below half", placed)
	if not placed:
		return
	var marks: Array[Dictionary] = ctrl.markers()
	_check("the marker is a crystal", marks.size() >= 1 and str(marks[0]["kind"]) == "crystal",
		str(marks))
	_check("and it leaves the mage guarded",
		(w["status"] as StatusEffects).get_guard_left(E) > 0.0,
		str((w["status"] as StatusEffects).get_guard_left(E)))


func test_lord_phases() -> void:
	var phases: Array = (_cfg.get_enemy("mist_lord").get("phases", []) as Array)
	_check("the Lord has two phases", phases.size() == 2, str(phases.size()))
	if phases.size() != 2:
		return
	var p1: Dictionary = phases[0]
	var p2: Dictionary = phases[1]
	_check("phase 1 opens at full health", is_equal_approx(float(p1["enter_hp_ratio"]), 1.0))
	_check("phase 2 opens at half", is_equal_approx(float(p2["enter_hp_ratio"]), 0.5))
	_check("the whiteout belongs to phase 2 only",
		not (p1["skills"] as Array).has(WHITEOUT) and (p2["skills"] as Array).has(WHITEOUT))
	var over: Dictionary = (p2.get("overrides", {}) as Dictionary)
	_check("phase 2 raises the crystal count to two",
		int(((over.get("mist_lord_crystal_anchor", {}) as Dictionary).get("count", 0))) == 2, str(over))


func test_whiteout_strikes_twice() -> void:
	# weight 0 in the data: it is cast by every_nth inside the phase, so a one-skill world must lift it.
	var w: Dictionary = _only([WHITEOUT], "pillars", 1, {WHITEOUT: 1.0})
	var first: Dictionary = _until(w, WHITEOUT, false)
	_check("the whiteout's first beat resolves", not first.is_empty())
	var second: Dictionary = _until(w, WHITEOUT, true, 8.0)
	_check("the whiteout's second beat resolves", not second.is_empty())
	if first.is_empty() or second.is_empty():
		return
	_check("the second beat is a separate, shifted strike",
		str(first.get("cells", [])) != str(second.get("cells", [])),
		"%s vs %s" % [first.get("cells", []), second.get("cells", [])])
	_check("the second beat hits for its own, lower number",
		float(second.get("damage", 0.0)) < float(first.get("damage", 0.0)),
		"%s vs %s" % [second.get("damage", 0.0), first.get("damage", 0.0)])


## THE CHAIN CAP, BOTH DIRECTIONS. Shipped: the second beat lays no Giá Lạnh, so the whole window stays
## below the threshold of 3. Restored: putting the stack back must visibly change the count — otherwise
## this measurement cannot see a stack at all and the shipped reading means nothing.
func test_whiteout_second_beat_lays_no_chill() -> void:
	var shipped: Dictionary = _cfg.skills[WHITEOUT].get("followup", {}) as Dictionary
	var fx: Dictionary = (shipped.get("effects", {}) as Dictionary)
	_check("data: the second beat carries no status block", not fx.has("status"), str(fx))

	# Both arms must land their SECOND beat on the SAME seed, or the two counts are not comparable.
	# Whether beat two connects depends on where the hero stands when it lands, so the seed is searched
	# rather than assumed.
	var seed_used: int = -1
	var a: Dictionary = {}
	var a1: Dictionary = {}
	var a2: Dictionary = {}
	for seed_value: int in range(1, 13):
		var probe: Dictionary = _only([WHITEOUT], "pillars", seed_value, {WHITEOUT: 1.0})
		var p1: Dictionary = _until(probe, WHITEOUT, false)
		var p2: Dictionary = _until(probe, WHITEOUT, true, 8.0)
		if bool(p2.get("hit", false)):
			seed_used = seed_value
			a = probe
			a1 = p1
			a2 = p2
			break
	_check("a seed exists where the shipped whiteout lands its second beat", seed_used > 0)
	if seed_used < 0:
		return
	var a_stacks: int = (a["status"] as StatusEffects).frost_stacks(P)
	var a_hit: bool = bool(a1.get("hit", false)) or bool(a2.get("hit", false))

	# The same Lord with the design's original rule put back.
	# Built from the RAW json, not from _cfg: _cfg holds the NORMALISED skill, and feeding a normalised
	# followup back through EnemySkillsConfig.from_dictionary() is not a round trip — the first version
	# of this leg did that and the whole skill came back refused, so the control arm cast nothing at all
	# and reported b_hit=false. A control arm that fails for its own reasons proves nothing about the
	# arm it is controlling, which is why the "both runs landed a beat" guard sits above the comparison.
	var raw_all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var raw_skill: Dictionary = ((raw_all["skills"] as Dictionary)[WHITEOUT] as Dictionary).duplicate(true)
	var restored: Dictionary = (raw_skill.get("followup", {}) as Dictionary).duplicate(true)
	var r_fx: Dictionary = (restored.get("effects", {}) as Dictionary).duplicate(true)
	r_fx["status"] = {"id": "frost", "stacks": 1}
	restored["effects"] = r_fx
	var b: Dictionary = _only([WHITEOUT], "pillars", seed_used, {WHITEOUT: 1.0},
		{WHITEOUT: {"followup": restored}})
	_check("the control arm's config is clean (a refused skill would fake a 'no chill' result)",
		(b["cfg"] as EnemySkillsConfig).problems.is_empty(), str((b["cfg"] as EnemySkillsConfig).problems))
	var b1: Dictionary = _until(b, WHITEOUT, false)
	var b2: Dictionary = _until(b, WHITEOUT, true, 8.0)
	var b_stacks: int = (b["status"] as StatusEffects).frost_stacks(P)
	var b_hit: bool = bool(b1.get("hit", false)) or bool(b2.get("hit", false))

	# Not "a beat" — the SECOND beat specifically. The restored stack rides on beat two, so a run where
	# only beat one connected shows the shipped count and looks like proof that restoring changed
	# nothing. The first version of this guard asked for `a1.hit or a2.hit` and reported shipped=1
	# restored=1 for exactly that reason: the control arm's second beat had missed.
	var a2_hit: bool = bool(a2.get("hit", false))
	var b2_hit: bool = bool(b2.get("hit", false))
	_check("both runs landed their SECOND beat (the stack rides on that one)", a2_hit and b2_hit,
		"a: first=%s second=%s | b: first=%s second=%s"
			% [a1.get("hit", false), a2_hit, b1.get("hit", false), b2_hit])
	if not (a2_hit and b2_hit):
		return
	_check("both runs connected at all", a_hit and b_hit, "a_hit=%s b_hit=%s" % [a_hit, b_hit])
	_check("restoring the stack visibly raises the count (the measurement can see a stack)",
		b_stacks > a_stacks, "shipped=%d restored=%d" % [a_stacks, b_stacks])
	_check("shipped: the whiteout window stays below the burst threshold of 3",
		a_stacks < 3, str(a_stacks))


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [SNAP, FIELD, WARD, WHITEOUT, LANCE,
			"mist_lord_frost_nail", "mist_lord_crystal_anchor", "mist_lord_ice_mantle"]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))
