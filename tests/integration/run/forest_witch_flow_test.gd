extends SceneTree
## P2.4 Forest Witch in the real match (design/quick-specs/phase2-misty-forest-2026-11-01.md 7.1, 7.4; D13): the run's
## boss node builds a pattern-brain match on boss_hall with her 2x2 footprint and 1210 written HP (RunConfig.from_node),
## and a CombatView match of it (BossBrain moving her between skills in anchor space, three phases driven by HP) keeps,
## on EVERY frame: the footprint fitting her half, no root anchor under her (she never steps onto one, spec 7.1: the
## brain plans around them and her mover refuses them), and she does move while anchors stand.
## Run: godot --headless --path . -s res://tests/integration/run/forest_witch_flow_test.gd

const VIEW_SEED: int = 4
const VIEW_STEP: float = 0.05
const VIEW_SEC: float = 75.0
const PHASE_AT: Array[float] = [25.0, 50.0]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var params: Dictionary = RunConfig.from_node(chapters, "ch1", "forest_witch", "boss", 7, 3).matches[0]
	_check("RunConfig: pattern brain, enemy forest_witch, boss_hall", str(params.get("brain", "")) == RunConfig.BRAIN_PATTERN
		and str(params.get("enemy", "")) == "forest_witch" and str((params.get("arena", {}) as Dictionary).get("shape", "")) == "boss_hall", str(params.get("arena")))
	_check("RunConfig: HP from 1210 written (%.1f at floor 3)" % float(params["boss_max_hp"]), float(params["boss_max_hp"]) > 700.0)
	await _play(params)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _play(params: Dictionary) -> void:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	var mp: Dictionary = params.duplicate(true)
	mp["arena_seed"] = VIEW_SEED
	v.match_params = mp
	v.drops_seed = VIEW_SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	var state: CombatState = v.get_state()
	var ctrl: PatternController = v.get_pattern_controller()
	_check("CombatView: pattern brain, 6x4 halves, 2x2 footprint", v.is_pattern_brain() and ctrl != null and v.get_grid().side_cols == 6
		and v.get_grid().side_rows == 4 and state.enemy_footprint_size() == 4)
	if ctrl == null:
		root.remove_child(holder)
		holder.free()
		return
	state.player_max_hp = 100000.0
	state.player_hp = 100000.0
	var always_fits: bool = true
	var on_anchor: Array[String] = []
	var anchors_seen: int = 0
	var moves_with_anchor: int = 0
	var last_cell: Vector2i = state.enemy_cell
	var t: float = 0.0
	var next_phase: int = 0
	v.freeze_time = false
	while t < VIEW_SEC and not state.is_player_dead() and not state.is_enemy_dead():
		if next_phase < PHASE_AT.size() and t >= PHASE_AT[next_phase]:
			state.damage_enemy(state.enemy_max_hp * 10.0)
			next_phase += 1
		v._process(VIEW_STEP)
		t += VIEW_STEP
		always_fits = always_fits and state.enemy_footprint_size() == 4 and state.enemy_fits(state.enemy_cell)
		var marks: Array[Vector2i] = ctrl.marker_cells()
		anchors_seen = maxi(anchors_seen, marks.size())
		for m: Vector2i in marks:
			if state.enemy_footprint_cells().has(m):
				on_anchor.append("t %.2f anchor %s body %s" % [t, m, state.enemy_footprint_cells()])
		if state.enemy_cell != last_cell:
			if not marks.is_empty():
				moves_with_anchor += 1
			last_cell = state.enemy_cell
	v.freeze_time = true
	_check("reached phase 3 (index %d)" % ctrl.get_phase_index(), ctrl.get_phase_index() == 2)
	_check("the footprint fits her half on every frame", always_fits)
	_check("anchors were placed (up to %d at once)" % anchors_seen, anchors_seen >= 2)
	_check("she moved while anchors stood (%d moves)" % moves_with_anchor, moves_with_anchor > 0)
	_check("she never stands on a root anchor", on_anchor.is_empty(), str(on_anchor.slice(0, 3)))
	root.remove_child(holder)
	holder.free()
