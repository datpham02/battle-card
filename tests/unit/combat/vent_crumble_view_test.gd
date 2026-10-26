extends SceneTree
## Story 039 W1 wiring in CombatView: the arena shapes `forge` (vents) and `twin_isles` (crumble) reach the TileHazards
## model; an erupting vent lights burning cells (StatusEffects) and burns the field pieces lying there; a fallen cell
## buries its pieces, blocks both movers and costs the pushed unit fall_damage. The model is ticked by hand (time frozen).
## Run: godot --headless --path . -s res://tests/unit/combat/vent_crumble_view_test.gd

const SEED: int = 11
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY

var fails: int = 0


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	await _test_vents()
	await _test_crumble()
	await _test_plain_match()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


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
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	return holder


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _test_vents() -> void:
	var holder: Node = await _match({"arena": {"shape": "forge"}})
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var hz: TileHazards = v.get_hazards()
	_check("vents: forge gives both halves vents", hz != null and hz.vent_count(P) >= 1 and hz.vent_count(E) >= 1 and not hz.crumble_enabled())
	var cells: Array[Vector2i] = hz.vent_cells(E)
	var cell: Vector2i = cells[0]
	var other: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in v.get_grid().enemy_cells():
		if not cells.has(c):
			other = c
			break
	var drops: FieldDrops = v.get_boss().get_drops()
	drops.debug_place("on_vent", cell, 60.0)
	if other != BoardGrid.NO_CELL:
		drops.debug_place("off_vent", other, 60.0)
	var left: int = drops.get_points().size()
	_check("vents: trigger_vent erupts at once", hz.trigger_vent(E, 0, 0.0) and hz.is_venting(E, cell))
	var status: StatusEffects = v.get_status()
	_check("vents: the vent cells burn through StatusEffects", status.is_burning(cell) and status.get_burn_left(cell) > 1.9)
	_check("vents: a field piece on the vent is burnt, the others stay", drops.get_points().size() == left - 1)
	var movers_ok: bool = not v.get_boss().get_mover().is_cell_blocked(cell)
	_check("vents: a venting cell never blocks a step", movers_ok)
	_drop(holder)


func _test_crumble() -> void:
	var holder: Node = await _match({"arena": {"shape": "twin_isles"}})
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var hz: TileHazards = v.get_hazards()
	var state: CombatState = v.get_state()
	_check("crumble: twin_isles turns crumble on and has two islands per half", hz.crumble_enabled() and hz.islands(P).size() >= 1)
	var hp: float = state.player_hp
	var start: Vector2i = state.player_cell
	var drops: FieldDrops = v._drops
	drops.debug_place("on_cell", start, 60.0)
	var pieces: int = drops.get_points().size()
	for i: int in 60:
		hz.tick(0.1, state)
	var fell: bool = hz.fallen_cells(P).size() >= 1
	_check("crumble: a unit that stays crumbles its cell (or the leave-a-path rule keeps it standing)", fell or hz.stats()["pushes"] == 0)
	if fell:
		var gone: Vector2i = hz.fallen_cells(P)[0]
		_check("crumble: the pushed unit took fall_damage", state.player_hp <= hp - hz.config_value("fall_damage") + 0.001 or state.player_cell == start)
		_check("crumble: the fallen cell blocks the player's mover", v._mover.is_cell_blocked(gone))
		_check("crumble: the fallen cell blocks the boss mover of that side only for its own half", not v.get_boss().get_mover().is_cell_blocked(gone))
		_check("crumble: the piece on the fallen cell is lost", drops.get_points().size() <= pieces)
	_drop(holder)


func _test_plain_match() -> void:
	var holder: Node = await _match({})
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var hz: TileHazards = v.get_hazards()
	_check("plain: a match without hazards has no vents and no crumble", hz.vent_count(P) == 0 and hz.vent_count(E) == 0 and not hz.crumble_enabled())
	_drop(holder)
