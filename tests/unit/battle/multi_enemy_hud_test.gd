extends SceneTree
## Multi-enemy Phase 4 steps 1-5 (docs/design/world-map-v2/MULTI-ENEMY-PHASE3-5-PLAN.md 2.3): the presentation layer
## addresses every unit by key. Step 1 anchors (UnitLayer.unit_keys, per-unit ids and clips), step 2/3 plates and
## chips (per-unit burn stacks), step 4 feedback routing (one cut on two units = two numbers; two attackers = two
## markers; heals per unit), step 5 merged telegraphs. One enemy unit must behave exactly as before Phase 4.

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const SEED: int = 7
const DT: float = 0.05
const ARENA: Dictionary = {"side_cols": 5, "side_rows": 4, "missing_cells": []}

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _initialize() -> void:
	await process_frame
	_test_unit_ids_for()
	await _test_unit_keys_and_clips()
	await _test_hit_clip_goes_to_the_hit_unit()
	await _test_burn_stacks_per_unit()
	await _test_feedback_split_between_units()
	await _test_two_attackers_keep_their_markers()
	await _test_telegraph_states_list()
	await _test_single_unit_is_unchanged()
	await process_frame
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


# --- helpers ---------------------------------------------------------------------------------------------------

func _block(id: String, hp: float = 80.0) -> Dictionary:
	return {"id": id, "max_hp": hp, "brain": "block", "ai": {"boss_think_interval_sec": 0.3}}


func _pattern(id: String, enemy: String, hp: float = 80.0) -> Dictionary:
	return {"id": id, "max_hp": hp, "brain": "pattern", "enemy": enemy, "ai": {"boss_think_interval_sec": 0.3}}


func _params(entries: Array, slots: int = 1) -> Dictionary:
	var first: Dictionary = entries[0]
	var raw: Dictionary = {"id": str(first.get("id", "fx")), "boss_max_hp": float(first["max_hp"]), "arena": ARENA,
		"end_delay_sec": 0.0, "boss_think_interval_sec": 0.3}
	if entries.size() > 1:
		raw["enemies"] = entries
		raw["attack_slots"] = slots
	if str(first.get("brain", "")) == "pattern":
		raw["brain"] = "pattern"
		raw["enemy"] = first["enemy"]
	var m: Dictionary = RunConfig.clean_match(raw, 0)
	m["end_delay_sec"] = 0.0
	return m


func _match(params: Dictionary) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = params
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	return holder


func _view(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# A UnitLayer bound to [param v]. It is NOT added to the tree: the test only reads the key-addressed tables
# (keys, ids, clips), which need no board geometry.
func _layer(v: CombatView) -> UnitLayer:
	var layer := UnitLayer.new()
	layer.setup(v)
	return layer


# One merged player result on [param keys], each taking its own damage at its own cell (CutEffects.merge_unit_results
# shape: `unit_results` tagged with `key`, `damage` the total).
func _merged(s: CombatState, keys: Array[int], damages: Array) -> Dictionary:
	var tagged: Array = []
	var total: float = 0.0
	var cells: Array[Vector2i] = []
	for i: int in keys.size():
		var cell: Vector2i = s.cell_of(keys[i])
		cells.append(cell)
		total += float(damages[i])
		tagged.append({"key": keys[i], "hit": true, "damage": float(damages[i]), "cell": cell, "cells": [cell],
			"crit": false})
	return {"cells": cells, "hit": true, "damage": total, "cell": cells[0], "skill_id": "test",
		"unit_results": tagged, "unit_keys_hit": keys, "unit0_damage": float(damages[0])}


# --- step 1: anchors -------------------------------------------------------------------------------------------

func _test_unit_ids_for() -> void:
	var plain: Dictionary = {"id": "goblin_scout", "character": {"id": "kiem_si"}}
	var ids: Dictionary = UnitLayer.unit_ids_for(plain)
	check(ids.size() == 2 and str(ids[P]) == "kiem_si" and str(ids[E]) == "goblin_scout",
		"ids: a plain match still gives exactly the two legacy keys", str(ids))

	var formation: Dictionary = plain.duplicate(true)
	formation["enemies"] = [{"template_id": "goblin_scout"}, {"template_id": "wolf"}, {"id": "slime"}]
	var many: Dictionary = UnitLayer.unit_ids_for(formation)
	check(str(many[CombatState.unit_key(0)]) == "goblin_scout" and str(many[CombatState.unit_key(1)]) == "wolf"
		and str(many[CombatState.unit_key(2)]) == "slime",
		"ids: every unit of a formation names its own sprite (template_id, else id)", str(many))
	check(str(many[P]) == "kiem_si", "ids: the hero key is untouched by the formation", str(many))


func _test_unit_keys_and_clips() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b"), _block("c")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var layer: UnitLayer = _layer(v)
	check(layer.unit_keys() == s.all_keys(), "keys: the layer walks the player plus every unit",
		"%s vs %s" % [str(layer.unit_keys()), str(s.all_keys())])
	check(layer.unit_keys().size() == 4, "keys: three enemy units give four keys", str(layer.unit_keys()))
	check(layer.get_unit_id(CombatState.unit_key(1)) == "b" and layer.get_unit_id(CombatState.unit_key(2)) == "c",
		"keys: each unit keeps its own id", "%s / %s" % [layer.get_unit_id(CombatState.unit_key(1)),
		layer.get_unit_id(CombatState.unit_key(2))])
	# Every unit starts idle and has its own clip slot.
	var all_idle: bool = true
	for key: int in layer.unit_keys():
		if layer.get_current_clip(key) != UnitLayer.CLIP_IDLE:
			all_idle = false
	check(all_idle, "keys: every unit starts on its own idle clip")
	layer.free()
	_drop(holder)


func _test_hit_clip_goes_to_the_hit_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var layer: UnitLayer = _layer(v)
	var k1: int = CombatState.unit_key(1)
	s.damage_unit(1, 5.0)
	layer.advance(DT)
	check(layer.get_hit_left(k1) > 0.0, "hit: the damaged unit plays its own hit clip", str(layer.get_hit_left(k1)))
	check(layer.get_hit_left(E) <= 0.0, "hit: unit 0 is NOT marked as hit when unit 1 took the blow",
		str(layer.get_hit_left(E)))
	# Unit 0 still works through the legacy path exactly as before.
	s.damage_unit(0, 5.0)
	layer.advance(DT)
	check(layer.get_hit_left(E) > 0.0, "hit: unit 0 still plays its hit clip", str(layer.get_hit_left(E)))
	layer.free()
	_drop(holder)


# --- steps 2/3: plates and chips -------------------------------------------------------------------------------

func _test_burn_stacks_per_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var status: StatusEffects = v.get_status()
	var lit: Array[Vector2i] = [s.cell_of(k1)]
	status.ignite(lit, 5.0, 1.0, 1.0)
	check(v.get_burn_stacks(k1) > 0, "chips: a burn on unit 1's cell counts for unit 1", str(v.get_burn_stacks(k1)))
	check(v.get_burn_stacks(E) == 0, "chips: that burn does NOT give unit 0 a burn chip", str(v.get_burn_stacks(E)))
	check(v.get_burn_stacks() > 0, "chips: the legacy call still answers for the whole enemy half",
		str(v.get_burn_stacks()))
	_drop(holder)


# --- step 4: feedback routing ----------------------------------------------------------------------------------

func _test_feedback_split_between_units() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var keys: Array[int] = [E, k1]
	v._on_swing_resolved(P, _merged(s, keys, [7.0, 11.0]))
	var main: Dictionary = v.get_cut_feedback()
	var extra: Array[Dictionary] = v.get_unit_feedback()
	check(extra.size() == 1, "feedback: a cut on two units leaves one extra record", str(extra.size()))
	check(is_equal_approx(float(main.get("damage", 0.0)), 7.0),
		"feedback: the main marker shows unit 0's own number, not the total 18", str(main.get("damage", 0.0)))
	if extra.size() == 1:
		check(is_equal_approx(float(extra[0].get("damage", 0.0)), 11.0),
			"feedback: the second number is unit 1's own", str(extra[0].get("damage", 0.0)))
		check(extra[0].get("cell") == s.cell_of(k1),
			"feedback: the second number stands over unit 1's cell", str(extra[0].get("cell")))
		check(bool(extra[0].get("number_only", false)),
			"feedback: the second record is number-only (one HIT word per cut)")
	check(main.get("cell") == s.cell_of(E), "feedback: the marker stays on unit 0's cell", str(main.get("cell")))
	_drop(holder)


func _test_two_attackers_keep_their_markers() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var one: Dictionary = {"cells": [s.player_cell] as Array[Vector2i], "hit": true, "damage": 4.0,
		"cell": s.player_cell, "skill_id": "a"}
	var two: Dictionary = {"cells": [s.player_cell] as Array[Vector2i], "hit": true, "damage": 6.0,
		"cell": s.player_cell, "skill_id": "b"}
	v._on_swing_resolved(E, one)
	v._on_swing_resolved(k1, two)
	check(is_equal_approx(float(v.get_boss_feedback().get("damage", 0.0)), 4.0),
		"attackers: unit 0's marker survives unit 1 striking right after it", str(v.get_boss_feedback()))
	check(v.get_boss_feedback_extra().size() == 1,
		"attackers: unit 1 keeps a marker of its own", str(v.get_boss_feedback_extra().size()))
	# Heals are per unit: two units healing in one batch keep two numbers.
	s.heal_key(E, 5.0)
	s.heal_key(k1, 9.0)
	check(not s.is_key_dead(k1), "attackers: unit 1 is still alive after the heal")
	_drop(holder)


# --- step 5: telegraphs ----------------------------------------------------------------------------------------

func _test_telegraph_states_list() -> void:
	var holder: Node = await _match(_params([_pattern("p0", "dev_pattern_dummy"),
		_pattern("p1", "dev_pattern_dummy")]))
	var v: CombatView = _view(holder)
	var layer := FloorLayer.new()
	layer.setup(v)
	# Nothing is warning yet: both the single and the list answer empty, and the list never invents an entry.
	check(layer.telegraph_state().is_empty(), "telegraph: unit 0 shows nothing before a warning")
	check(layer.telegraph_states().is_empty(), "telegraph: the list is empty before any unit warns",
		str(layer.telegraph_states().size()))
	check(layer.extra_telegraph_states().is_empty(), "telegraph: the extras list is empty too",
		str(layer.extra_telegraph_states().size()))
	# Invariant checked on EVERY frame, so the result does not depend on when the units happen to warn: the extras
	# list holds exactly the units past unit 0 that are telegraphing right now. If a second unit's warning were
	# dropped (the old single-source behaviour) or counted twice, this fails.
	v.freeze_time = false
	var bad: Array[int] = [0]
	var max_seen: Array[int] = [0]
	for i: int in 400:
		v._process(DT)
		var want: int = 0
		for agent: EnemyAgent in v.get_extra_agents():
			if agent.pattern != null and not agent.pattern.telegraph_cells().is_empty():
				want += 1
		var got: int = layer.extra_telegraph_states().size()
		if got != want:
			bad[0] += 1
		max_seen[0] = maxi(max_seen[0], layer.telegraph_states().size())
		if v.get_state().is_player_dead() or v.get_state().all_required_dead():
			break
	v.freeze_time = true
	check(bad[0] == 0, "telegraph: every frame lists exactly the extra units that are telegraphing",
		"%d frames disagreed" % bad[0])
	check(max_seen[0] >= 1, "telegraph: at least one unit telegraphed while the match ran", str(max_seen[0]))
	layer.free()
	_drop(holder)


# --- the 1v1 match must be untouched ---------------------------------------------------------------------------

func _test_single_unit_is_unchanged() -> void:
	var holder: Node = await _match(_params([_block("solo")]))
	var v: CombatView = _view(holder)
	var layer: UnitLayer = _layer(v)
	check(layer.unit_keys() == [P, E], "1v1: the layer walks exactly the two legacy keys", str(layer.unit_keys()))
	check(v.get_unit_feedback().is_empty() and v.get_boss_feedback_extra().is_empty(),
		"1v1: no per-unit feedback records exist")
	var floor_layer := FloorLayer.new()
	floor_layer.setup(v)
	check(floor_layer.extra_telegraph_states().is_empty(), "1v1: there are no extra telegraphs")
	check(floor_layer.telegraph_states().size() == (0 if floor_layer.telegraph_state().is_empty() else 1),
		"1v1: the list holds unit 0's telegraph and nothing else")
	# A single result keeps the legacy shape: one number, no extras.
	var s: CombatState = v.get_state()
	v._on_swing_resolved(P, {"cells": [s.cell_of(E)] as Array[Vector2i], "hit": true, "damage": 9.0,
		"cell": s.cell_of(E), "skill_id": "solo"})
	check(is_equal_approx(float(v.get_cut_feedback().get("damage", 0.0)), 9.0),
		"1v1: the number is the result's own damage", str(v.get_cut_feedback()))
	check(v.get_unit_feedback().is_empty(), "1v1: a single-unit cut adds no extra record")
	floor_layer.free()
	layer.free()
	_drop(holder)
