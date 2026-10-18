class_name DemoArgs
extends Node
## DEV-ONLY capture hook: puts the screen into a deterministic state for screenshots.
## Godot user args go after "--":
##   godot --path . -- --demo=board     empty board, d-pad, empty hand (no points; time frozen)
##   godot --path . -- --demo=drops     points spread over the player half, decreasing freshness
##   godot --path . -- --demo=expiring  one point at 0.8 s left (red, blinking)
##   godot --path . -- --demo=full      hand holds 4 points, a 5th lies under the player showing FULL
##   godot --path . -- --demo=cooldown  player just stepped: cooldown ring visible, d-pad dimmed
##   godot --path . -- --demo=selected  hand holds 3 points, slots 0 and 2 selected
##   godot --path . -- --grid=<cols>x<rows>[:c,r;c,r...]   DEV-ONLY board override
##       <cols>x<rows> = columns x rows of ONE half; the optional list is missing cells in
##       side coordinates (col 0 = farthest from the divider; mirrored to the boss half),
##       e.g. --grid=4x3:0,0;0,2. Combines with any --demo (or none). Replaces side_cols /
##       side_rows / missing_cells of combat.json and clears the start-cell overrides.
## Every demo freezes time (CombatView.freeze_time) so screenshots are deterministic, and
## seeds the drop RNG. No argument = normal game, this node does nothing. State is set in
## _ready, before the first frame (the seed and the grid in _enter_tree, before
## CombatView._ready). Demo cells and labels are derived from the board, never hardcoded.

const DEMO_PREFIX: String = "--demo="
const GRID_PREFIX: String = "--grid="
const DEMO_SEED: int = 7
## Demo points (spread over the player half) and freshness (s) left; one entry per point.
const DROPS_FRESHNESS: Array[float] = [6.5, 4.0, 2.0, 0.8]
const EXPIRING_FRESHNESS: float = 0.8
const FULL_POINT_FRESHNESS: float = 5.0
## Points put in the hand by the "selected" demo and which of them are selected.
const SELECTED_SLOTS: Array[int] = [0, 2]
const SELECTED_HAND_COUNT: int = 3

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _mode: String = ""


func _enter_tree() -> void:
	_mode = _parse_mode()
	# Runs before any sibling _ready, so the grid and drops are created with these.
	if _mode != "":
		_combat().drops_seed = DEMO_SEED
	_combat().grid_override = _parse_grid()


func _ready() -> void:
	if _mode == "":
		return
	var combat: CombatView = _combat()
	combat.freeze_time = true
	var grid: BoardGrid = combat.get_grid()
	match _mode:
		"board":
			pass
		"drops":
			var cells: Array[Vector2i] = _spread_cells(grid, DROPS_FRESHNESS.size())
			var labels: Array[String] = _spread_labels(grid, cells.size(), 0)
			for i: int in cells.size():
				combat.get_drops().debug_place(labels[i], cells[i], DROPS_FRESHNESS[i])
		"expiring":
			# A cell next to the player's default one, toward the divider; skipped if absent.
			var cell: Vector2i = grid.default_player_cell() + Vector2i.RIGHT
			if grid.is_player_cell(cell):
				combat.get_drops().debug_place(_spread_labels(grid, 1, 1)[0], cell, EXPIRING_FRESHNESS)
			else:
				push_warning("DemoArgs: no cell next to the player's default cell, expiring demo skipped")
		"full":
			_fill_hand(_hold().get_slot_count())
			var label: String = _spread_labels(grid, 1, 2)[0]
			combat.get_drops().debug_place(label, combat.get_state().player_cell, FULL_POINT_FRESHNESS)
		"cooldown":
			if not combat.try_step_player(Vector2i.RIGHT):
				push_warning("DemoArgs: demo cooldown step failed")
		"selected":
			_fill_hand(SELECTED_HAND_COUNT)
			for index: int in SELECTED_SLOTS:
				_hold().toggle_selected(index)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)


func _parse_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEMO_PREFIX):
			return arg.substr(DEMO_PREFIX.length())
	return ""


# Parses --grid=<cols>x<rows>[:c,r;c,r...]. Returns null (warning) when absent or malformed.
func _parse_grid() -> BoardGrid:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(GRID_PREFIX):
			continue
		var spec: String = arg.substr(GRID_PREFIX.length())
		var parts: PackedStringArray = spec.split(":", false, 1)
		var dims: PackedStringArray = (parts[0] if parts.size() > 0 else "").split("x")
		if dims.size() != 2 or not dims[0].is_valid_int() or not dims[1].is_valid_int():
			push_warning("DemoArgs: bad --grid '%s', expected <cols>x<rows>[:c,r;c,r...]" % spec)
			return null
		var missing: Array[Vector2i] = []
		if parts.size() > 1:
			for item: String in parts[1].split(";", false):
				var rc: PackedStringArray = item.split(",")
				if rc.size() == 2 and rc[0].is_valid_int() and rc[1].is_valid_int():
					missing.append(Vector2i(rc[0].to_int(), rc[1].to_int()))
				else:
					push_warning("DemoArgs: bad --grid cell '%s', ignored" % item)
		return BoardGrid.new(dims[0].to_int(), dims[1].to_int(), missing)
	return null


func _combat() -> CombatView:
	return get_node(combat_view_path) as CombatView


func _hold() -> HoldSlots:
	return (get_node(hold_slots_view_path) as HoldSlotsView).get_slots()


# [param count] distinct player cells evenly spread over the player half (fewer if the half
# has fewer cells), first and last cell included.
func _spread_cells(grid: BoardGrid, count: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = grid.player_cells()
	var out: Array[Vector2i] = []
	for i: int in count:
		var index: int = 0
		if count > 1:
			index = roundi(float(all.size() - 1) * i / float(count - 1))
		if not out.has(all[index]):
			out.append(all[index])
	return out


# [param count] perimeter labels of the grid, evenly spread, starting [param offset] in.
func _spread_labels(grid: BoardGrid, count: int, offset: int) -> Array[String]:
	var all: Array[String] = grid.perimeter_labels()
	var out: Array[String] = []
	for i: int in count:
		out.append(all[(offset + roundi(float(all.size()) * i / float(count))) % all.size()])
	return out


# Puts [param count] synthetic points straight into the first hand slots.
func _fill_hand(count: int) -> void:
	var labels: Array[String] = _spread_labels(_combat().get_grid(), count, 1)
	for i: int in count:
		var point := FieldPoint.new()
		point.uid = -1 - i
		point.label = labels[i]
		point.freshness_left = 0.0
		_hold().place(point, i)
