extends SceneTree
## Story 025 / TD-017 proof: a real CombatView match (headless, sim driven by hand with a fixed step)
## where the player stands still. The boss, in piece mode, must start a swing within SIM_LIMIT_SEC
## of sim time, the swing cells must be real player-half cells, the boss must stay rooted while it
## swings (root_while_swinging) and must walk again once the swing is over.

const DT: float = 0.05
const SIM_LIMIT_SEC: float = 40.0
const MOVE_AFTER_LIMIT_SEC: float = 30.0
const BIG_HP: float = 1.0e9
const DROPS_SEED: int = 7

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	var v := CombatView.new()
	v.match_params = {"boss_max_hp": BIG_HP, "player_hp": -1.0, "boss_root_while_swinging": true}
	v.drops_seed = DROPS_SEED
	v.freeze_time = true
	root.add_child(v)
	await process_frame
	v.set_process(false)
	v.freeze_time = false
	var boss: BossController = v.get_boss()
	var state: CombatState = v.get_state()
	var grid: BoardGrid = v.get_grid()
	_check("boss wired (pieces are the only mode since Story 026)", boss.get_brain() != null and boss.get_drops() != null)
	var swings: Array = []
	boss.get_actor().swing_started.connect(func(cells: Array[Vector2i], _k: String, _d: float) -> void:
		swings.append({"cells": cells.duplicate(), "hand_had_piece": true}))
	var labels_seen: Array = []
	boss.cut_started.connect(func(labels: Array[String], _c: Array[Vector2i], _k: String) -> void:
		labels_seen.append(labels.duplicate()))
	var player_cell: Vector2i = state.player_cell
	var t: float = 0.0
	var rooted_ok: bool = true
	var lock_follows: bool = true
	var swing_cell: Vector2i = BoardGrid.NO_CELL
	var moved_after: bool = false
	var swing_seen_at: float = -1.0
	var ended_at: float = -1.0
	while t < SIM_LIMIT_SEC + MOVE_AFTER_LIMIT_SEC:
		state.set_player_hp(state.player_max_hp)
		var before: Vector2i = state.enemy_cell
		v._process(DT)
		t += DT
		var actor: CutActor = boss.get_actor()
		var swinging: bool = actor.is_swinging() or actor.has_queued()
		if v.is_boss_step_locked() != swinging:
			lock_follows = false
		if swinging:
			if swing_seen_at < 0.0:
				swing_seen_at = t
				swing_cell = before
			elif state.enemy_cell != swing_cell:
				rooted_ok = false
			ended_at = -1.0
		elif swing_seen_at >= 0.0:
			if ended_at < 0.0:
				ended_at = t
				swing_cell = state.enemy_cell
			elif state.enemy_cell != swing_cell:
				moved_after = true
				break
		elif t >= SIM_LIMIT_SEC:
			break
	# No input is sent; the player's cell may still change through a boss skill's push (CutEffects).
	print("INFO player cell %s -> %s (push effects only)" % [player_cell, state.player_cell])
	_check("boss started a swing within %.0f sim s" % SIM_LIMIT_SEC, not swings.is_empty() and swing_seen_at <= SIM_LIMIT_SEC, "first at %.2f s" % swing_seen_at)
	var cells_ok: bool = not swings.is_empty()
	for swing: Dictionary in swings:
		var cells: Array = swing["cells"]
		if cells.is_empty():
			cells_ok = false
		for cell: Vector2i in cells:
			if not grid.is_player_cell(cell):
				cells_ok = false
	_check("every swing covers only real player-half cells", cells_ok, str(swings.map(func(s: Dictionary) -> Array: return s["cells"])))
	var shape_ids: bool = not labels_seen.is_empty()
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	for labels: Array in labels_seen:
		if labels.is_empty() or labels.size() > 2:
			shape_ids = false
		for label: String in labels:
			if not lib.has_shape(label):
				shape_ids = false
	_check("cut_started labels are 1..2 shape ids", shape_ids, str(labels_seen))
	_check("boss rooted while swinging", rooted_ok)
	_check("is_boss_step_locked follows the swing", lock_follows)
	_check("boss moves again after the swing", moved_after, "swing ended at %.2f" % ended_at)
	root.remove_child(v)
	v.free()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)
