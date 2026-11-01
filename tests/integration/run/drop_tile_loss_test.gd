extends SceneTree
## Drop tile (Ô rớt) wiring in a real CombatView (design/quick-specs/o-rot-thay-tuong-2026-10-31.md rules 3-5):
## a cracking cell stays enterable for the player's mover, an open hole blocks it, and a player standing on a cell when
## it falls dies and the match ends LOST through the existing match_ended path ("Chết là hết chuyến leo").
## Time is frozen (freeze_time) and the status model is ticked by hand, so the boss never acts. Deterministic.
## Run: godot --headless --path . -s res://tests/integration/run/drop_tile_loss_test.gd

const SEED: int = 11
const P: int = CombatState.Side.PLAYER
const STEP: float = 0.1

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	await test_hole_blocks_mover_crack_does_not()
	await test_fall_on_player_ends_match_lost()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _match() -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"end_delay_sec": 0.0}
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	return holder


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _ticks(v: CombatView, n: int) -> void:
	for i: int in n:
		v.get_status().tick(STEP, v.get_state())


func test_hole_blocks_mover_crack_does_not() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var cfg: CombatConfig = v.get_config()
	var state: CombatState = v.get_state()
	var here: Vector2i = state.player_cell
	var target: Vector2i = BoardGrid.NO_CELL
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if v.get_grid().is_player_cell(here + d):
			target = here + d
			break
	var cells: Array[Vector2i] = [target]
	v.get_status().apply_drop(P, cells, cfg.hole_warn_sec, cfg.seal_sec)
	_check("view: a cracking cell is not blocked for the player's mover", not v.get_mover().is_cell_blocked(target))
	_ticks(v, roundi(cfg.hole_warn_sec / STEP))
	_check("view: an open hole blocks the player's mover", v.get_status().is_hole(P, target) and v.get_mover().is_cell_blocked(target))
	_ticks(v, roundi(cfg.seal_sec / STEP))
	_check("view: the returned cell is steppable again", not v.get_mover().is_cell_blocked(target))
	_drop(holder)


func test_fall_on_player_ends_match_lost() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var cfg: CombatConfig = v.get_config()
	var ended: Array[bool] = []
	v.match_ended.connect(func(won: bool, _hp: float) -> void: ended.append(won))
	var cells: Array[Vector2i] = [v.get_state().player_cell]
	v.get_status().apply_drop(P, cells, cfg.hole_warn_sec, cfg.seal_sec)
	_ticks(v, roundi(cfg.hole_warn_sec / STEP))
	_check("view: the player on the falling cell is dead (combat.json hole_fall_lethal)", v.get_state().is_player_dead())
	for i: int in 10:
		if not ended.is_empty():
			break
		await process_frame
	_check("view: match_ended(won=false) through the existing loss path", ended == [false], str(ended))
	_drop(holder)
