extends SceneTree
## Story 025: the boss brain chooses and casts puzzle pieces (single or two joined), BossController
## validates piece casts, feint eligibility by cell count, root while swinging; the classic label
## path is unchanged. Headless; FAILS=N. Deterministic: brain noise 0, fixed seeds.

const SEED: int = 11
const PLAYER_STEP_SEC: float = 0.5
const THINK_SEC: float = 1.0

var fails: int = 0
var lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _v(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Array in list:
		out.append(Vector2i(item[0], item[1]))
	return out


func _initialize() -> void:
	lib = PieceLibrary.load_from_file()
	_test_valid_on_holes()
	_test_single_and_joined()
	_test_corner_preference()
	_test_min_runes()
	_test_scoring_cap()
	_test_combo_covers_escape()
	_test_controller_rejects()
	_test_controller_accepts_pair()
	_test_feint_eligibility()
	_test_root()
	_test_classic_labels()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _brain_config() -> BossBrainConfig:
	var config: BossBrainConfig = BossBrainConfig.load_from_file()
	config.noise = 0.0
	return config


# A pure brain world on [param grid] with a piece hand holding [param ids] (slot order).
func _world(grid: BoardGrid, ids: Array, config: BossBrainConfig = null) -> Dictionary:
	if config == null:
		config = _brain_config()
	var state := CombatState.new(grid, 1.0e6, 1.0e6)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var hand: HoldSlots = HoldSlots.create_piece_hand(3)
	for id: String in ids:
		hand.place_in_first_free(_point(id))
	var drops_config := FieldDropsConfig.new()
	drops_config.spawn_interval_sec = 1.0e9
	drops_config.initial_delay_sec = 1.0e9
	var drops := FieldDrops.new(drops_config, grid.enemy_cells(), grid.perimeter_labels(), SEED)
	var brain := BossBrain.new(config, grid, cut_config, skill_config, SEED)
	var ctx: Dictionary = {
		"state": state, "hand": hand, "drops": drops,
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, config.step_cooldown_sec),
		"actor": CutActor.new(cut_config, CombatState.Side.ENEMY),
		"cooldowns": SkillCooldowns.new(), "player_actor": CutActor.new(cut_config, CombatState.Side.PLAYER),
		"player_step_cooldown": PLAYER_STEP_SEC,
	}
	return {"grid": grid, "state": state, "hand": hand, "brain": brain, "ctx": ctx, "cut_config": cut_config}


func _point(id: String) -> FieldPoint:
	var p := FieldPoint.new()
	if id == Piece.ROTTEN_ID:
		p.piece = Piece.make_rotten()
		p.rotten = true
	else:
		p.piece = lib.make_piece(id)
	p.label = p.piece.shape_id
	return p


func _decide(w: Dictionary) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, false)
	return brain.decide(w["ctx"])


func _cells_ok(grid: BoardGrid, cells: Array) -> bool:
	if cells.is_empty():
		return false
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if not grid.is_player_cell(cell) or seen.has(cell):
			return false
		seen[cell] = true
	return true


# A controller in piece mode on a 3x3 board with [param ids] in its hand.
func _controller(ids: Array, root_on: bool = true) -> BossController:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1.0e6, 1.0e6)
	var config: BossBrainConfig = _brain_config()
	config.root_while_swinging = root_on
	var drops_config := FieldDropsConfig.new()
	drops_config.spawn_interval_sec = 1.0e9
	drops_config.initial_delay_sec = 1.0e9
	drops_config.piece_spawn_interval_sec = 1.0e9
	var boss := BossController.new(
		state, grid, CutConfig.load_from_file(), SkillConfig.load_from_file(), config, drops_config,
		HoldSlotsConfig.new(), SEED
	)
	boss.enable_pieces(lib, "", SEED, 2)
	for id: String in ids:
		boss.get_hand().place_in_first_free(_point(id))
	return boss


func _cut(indices: Array, cells: Array[Vector2i]) -> Dictionary:
	return {"type": "cut", "hand_indices": indices, "skill_id": SkillConfig.FALLBACK_SKILL, "cells": cells}


# ------------------------------------------------------------------ brain

func _test_valid_on_holes() -> void:
	var grid := BoardGrid.new(3, 3, _v([[0, 0], [1, 1]]))
	var all_ok: bool = true
	var cuts: int = 0
	for player_cell: Vector2i in grid.player_cells():
		var w: Dictionary = _world(grid, ["l3", "bar2", "t4"])
		(w["state"] as CombatState).set_player_cell(player_cell)
		var action: Dictionary = _decide(w)
		if str(action["type"]) != "cut":
			continue
		cuts += 1
		if not _cells_ok(grid, action["cells"]):
			all_ok = false
	_check("holes: every chosen cast is on distinct real player-half cells", all_ok and cuts > 0, "cuts=%d" % cuts)


func _test_single_and_joined() -> void:
	var grid := BoardGrid.new(3, 3)
	var sizes: Dictionary = {}
	var chosen_pairs: int = 0
	var pairs_ok: bool = true
	for player_cell: Vector2i in grid.player_cells():
		var w: Dictionary = _world(grid, ["bar2", "mono", "l3"])
		(w["state"] as CombatState).set_player_cell(player_cell)
		var action: Dictionary = _decide(w)
		for row: Dictionary in (w["brain"] as BossBrain).last_debug()["cut_candidates"]:
			sizes[(row["pieces"] as Array).size()] = true
		if str(action["type"]) == "cut" and (action["hand_indices"] as Array).size() == 2:
			chosen_pairs += 1
			var idx: Array = action["hand_indices"]
			if int(idx[0]) == int(idx[1]) or not _cells_ok(grid, action["cells"]):
				pairs_ok = false
	_check("candidates include single and joined casts", sizes.has(1) and sizes.has(2), str(sizes.keys()))
	_check("joined casts are chosen and never overlap / reuse a slot", chosen_pairs > 0 and pairs_ok, "pairs=%d" % chosen_pairs)
	var w1: Dictionary = _world(grid, ["bar2", "mono", "l3"])
	(w1["brain"] as BossBrain).max_pieces = 1
	_decide(w1)
	var only_single: bool = true
	for row: Dictionary in (w1["brain"] as BossBrain).last_debug()["cut_candidates"]:
		if (row["pieces"] as Array).size() != 1:
			only_single = false
	_check("max_pieces 1: single placements only", only_single)


func _test_corner_preference() -> void:
	var grid := BoardGrid.new(3, 3)
	var w: Dictionary = _world(grid, ["bar2", "l3", "mono"])
	var corner := Vector2i(0, 0)
	(w["state"] as CombatState).set_player_cell(corner)
	var action: Dictionary = _decide(w)
	var cells: Array = action.get("cells", [])
	_check("corner: the cast covers the player's corner", str(action["type"]) == "cut" and cells.has(corner), str(cells))
	var near: int = 0
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		if cells.has(cell):
			near += 1
	_check("corner: the cast also covers a neighbour escape cell", near >= 1, str(cells))


func _test_min_runes() -> void:
	var grid := BoardGrid.new(3, 3)
	var w: Dictionary = _world(grid, ["mono", "bar2", "square"])
	(w["brain"] as BossBrain).min_runes = 4
	(w["brain"] as BossBrain).max_pieces = 1
	_decide(w)
	var rows: Array = (w["brain"] as BossBrain).last_debug()["cut_candidates"]
	var all_big: bool = not rows.is_empty()
	for row: Dictionary in rows:
		if int(row["cells"]) < 4:
			all_big = false
	_check("min_runes 4: smaller casts dropped while a 4-cell one exists", all_big, "rows=%d" % rows.size())
	var w2: Dictionary = _world(grid, ["mono", "bar2"])
	(w2["brain"] as BossBrain).min_runes = 4
	_decide(w2)
	var rows2: Array = (w2["brain"] as BossBrain).last_debug()["cut_candidates"]
	_check("min_runes 4 without a big cast: small casts still scored", not rows2.is_empty())


func _test_scoring_cap() -> void:
	var grid := BoardGrid.new(3, 3)
	var config: BossBrainConfig = _brain_config()
	config.max_placements_scored = 5
	var w: Dictionary = _world(grid, ["bar2", "mono", "l3"], config)
	(w["brain"] as BossBrain).max_pieces = 1
	_decide(w)
	var rows: Array = (w["brain"] as BossBrain).last_debug()["cut_candidates"]
	_check("max_placements_scored 5 caps full scoring (singles only)", rows.size() == 5, "rows=%d" % rows.size())


func _test_combo_covers_escape() -> void:
	var grid := BoardGrid.new(3, 3)
	var w: Dictionary = _world(grid, ["l3", "bar2", "mono"])
	var brain: BossBrain = w["brain"]
	brain._weights["combo_chance"] = 1.0
	brain.max_pieces = 1
	(w["state"] as CombatState).set_player_cell(Vector2i(1, 1))
	var action: Dictionary = _decide(w)
	_check("combo: a combo is queued", str(action["type"]) == "cut" and action.has("combo"), str(action))
	if not action.has("combo"):
		return
	var first: Array[Vector2i] = []
	first.assign(action["cells"] as Array)
	var cut_config: CutConfig = w["cut_config"]
	var steps: int = EscapeAnalysis.steps_for_swing(cut_config.swing_duration(first.size()), PLAYER_STEP_SEC)
	var escape: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, Vector2i(1, 1), steps, true, first)
	var combo: Dictionary = action["combo"]
	var covered: int = 0
	for cell: Vector2i in (combo["cells"] as Array):
		if escape.has(cell):
			covered += 1
	var disjoint: bool = true
	for index: int in (combo["hand_indices"] as Array):
		if (action["hand_indices"] as Array).has(index):
			disjoint = false
	_check("combo: covers >= 1 escape cell of the first cast, other pieces, valid cells",
		covered >= 1 and disjoint and _cells_ok(grid, combo["cells"]), "covered=%d" % covered)


# ------------------------------------------------------------------ controller

func _test_controller_rejects() -> void:
	var boss: BossController = _controller(["mono", "mono", "mono"])
	boss._do_cut(_cut([0, 1, 2], _v([[0, 0], [1, 0], [2, 0]])))
	_check("_do_cut: 3-piece action refused, hand untouched", boss.get_hand().get_occupied_count() == 3 and not boss.get_actor().is_swinging())
	boss._do_cut(_cut([0, 1], _v([[0, 0], [0, 0]])))
	_check("_do_cut: overlapping union refused, hand untouched", boss.get_hand().get_occupied_count() == 3 and not boss.get_actor().is_swinging())
	boss._do_cut(_cut([0, 0], _v([[0, 0], [1, 0]])))
	_check("_do_cut: same slot twice refused", boss.get_hand().get_occupied_count() == 3 and not boss.get_actor().is_swinging())
	boss._do_cut(_cut([0], _v([[4, 0]])))
	_check("_do_cut: boss-half cell refused", boss.get_hand().get_occupied_count() == 3 and not boss.get_actor().is_swinging())
	var rotten: BossController = _controller([Piece.ROTTEN_ID, "mono"])
	rotten._do_cut(_cut([0], _v([[0, 0]])))
	rotten._do_cut(_cut([0, 1], _v([[0, 0], [1, 0]])))
	_check("_do_cut: rotten piece refused, hand untouched", rotten.get_hand().get_occupied_count() == 2 and not rotten.get_actor().is_swinging())


func _test_controller_accepts_pair() -> void:
	var boss: BossController = _controller(["bar2", "mono"])
	var got: Array = []
	boss.cut_started.connect(func(labels: Array[String], cells: Array[Vector2i], _k: String) -> void:
		got.append([labels.duplicate(), cells.duplicate()]))
	boss._do_cut(_cut([0, 1], _v([[0, 0], [1, 0], [0, 1]])))
	_check("_do_cut: joined 2-piece cast swings the union, both pieces spent",
		boss.get_actor().is_swinging() and boss.get_hand().get_occupied_count() == 0 and got.size() == 1
		and (got[0][0] as Array) == ["bar2", "mono"] and (got[0][1] as Array).size() == 3, str(got))
	_check("_do_cut: last cut labels = shape ids", (boss.get_last_cut()["labels"] as Array) == ["bar2", "mono"])


func _test_feint_eligibility() -> void:
	var small: BossController = _controller(["bar2"])
	small.force_next_feint = true
	small._do_cut(_cut([0], _v([[0, 0], [1, 0]])))
	_check("feint: 2-cell piece cast is feint-eligible (forced feint taken)", small._feint_pending and not small.force_next_feint)
	var big: BossController = _controller(["bar3"])
	big.force_next_feint = true
	big._do_cut(_cut([0], _v([[0, 0], [1, 0], [2, 0]])))
	_check("feint: 3-cell piece cast is not eligible (force kept)", big.get_actor().is_swinging() and not big._feint_pending and big.force_next_feint)
	var pair: BossController = _controller(["mono", "mono"])
	pair.force_next_feint = true
	pair._do_cut(_cut([0, 1], _v([[0, 0], [2, 2]])))
	_check("feint: two 1-cell pieces (2 cells) are eligible", pair._feint_pending)


func _try_any_step(boss: BossController) -> bool:
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if boss.get_mover().try_step(dir):
			return true
	return false


func _test_root() -> void:
	var boss: BossController = _controller(["bar2"], true)
	boss._do_cut(_cut([0], _v([[0, 0], [1, 0]])))
	_check("root on: locked while swinging", boss.is_step_locked() and not boss.get_mover().is_ready())
	_check("root on: mover refuses to step while swinging", not _try_any_step(boss))
	boss.get_actor().cancel()
	_check("root on: cancel/interrupt unlocks at once", not boss.is_step_locked() and _try_any_step(boss))
	var free: BossController = _controller(["bar2"], false)
	free._do_cut(_cut([0], _v([[0, 0], [1, 0]])))
	_check("root off: steps while swinging", free.get_actor().is_swinging() and not free.is_step_locked() and _try_any_step(free))


func _test_classic_labels() -> void:
	var grid := BoardGrid.new(3, 3)
	var w: Dictionary = _world(grid, [])
	var hand := HoldSlots.new(4)
	for label: String in ["A1", "C1", "B2"]:
		var p := FieldPoint.new()
		p.label = label
		hand.place_in_first_free(p)
	(w["ctx"] as Dictionary)["hand"] = hand
	var action: Dictionary = _decide(w)
	var rows: Array = (w["brain"] as BossBrain).last_debug()["cut_candidates"]
	var labels_ok: bool = not rows.is_empty()
	for row: Dictionary in rows:
		if row.has("pieces"):
			labels_ok = false
	_check("classic: label candidates (no piece rows), no cells in the action", labels_ok and not action.has("cells"), "rows=%d type=%s" % [rows.size(), action["type"]])
	var boss := BossController.new(
		CombatState.new(grid, 1.0e6, 1.0e6), grid, CutConfig.load_from_file(), SkillConfig.load_from_file(),
		_brain_config(), FieldDropsConfig.new(), HoldSlotsConfig.new(), SEED
	)
	var q := FieldPoint.new()
	q.label = "A1"
	boss.get_hand().place_in_first_free(q)
	boss._do_cut({"type": "cut", "hand_indices": [0], "skill_id": SkillConfig.FALLBACK_SKILL})
	_check("classic: controller cuts a label point", not boss.is_piece_mode() and boss.get_actor().is_swinging())
