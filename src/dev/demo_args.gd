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
##   godot --path . -- --demo=preview2  hand A1,C<n>,B2; A1 then C<n> selected: 5-cell segment preview, "5 ô", CONFIRM
##   godot --path . -- --demo=preview4  hand A1,A<n>,C<n>,C1 all selected in that order: polygon, all cells covered
##   godot --path . -- --demo=menu      hand A1,A<n> selected and confirmed: skill menu open (slow-mo frozen)
##   godot --path . -- --demo=swing     hand A1 (+2 others) confirmed on 1 point: red column 1 of the boss half,
##                                      swing frozen 0.3 s in; the boss stays on its start cell (not forced)
##   godot --path . -- --demo=hit       as swing, boss moved INTO column 1, swing just resolved: HIT and "-N"
##   godot --path . -- --demo=miss      as swing, boss moved to the LAST column, swing just resolved: MISS
##   godot --path . -- --demo=boss_pick       boss holds 2 points (tags in the HUD), 3 boss field points of
##                                            different freshness on its half, one next to the boss
##   godot --path . -- --demo=boss_swing      boss cut of 3 cells (A1) on the player's half, frozen 0.3 s in,
##                                            player standing OUTSIDE the covered cells
##   godot --path . -- --demo=boss_hit        boss swing just resolved, player inside: HIT, "-N", HP reduced
##   godot --path . -- --demo=boss_miss       boss swing just resolved, player outside: MISS
##   godot --path . -- --demo=interrupt_player  player's cut resolves first and cancels the boss's: NGẮT on the boss's cells
##   godot --path . -- --demo=interrupt_boss  boss's cut resolves first and cancels the player's: NGẮT on the player's cells
##   (every demo deactivates the boss: BossController.set_active(false); swings are fast-forwarded
##    through SwingArbiter.tick, the boss cuts through BossController's real cut path)
##   godot --path . -- --boss=<set>   DEV-ONLY boss weight set (balanced/aggressive/cautious, see
##       boss_brain.json); sets CombatView.boss_set_override before _ready. Works with or without --demo.
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
const BOSS_PREFIX: String = "--boss="
const DEMO_SEED: int = 7
## Freshness (s) of the boss's field points in "boss_pick"; uid base of its synthetic hand points.
const BOSS_FIELD_FRESHNESS: Array[float] = [6.5, 3.5, 1.5]
const BOSS_UID_BASE: int = -100
## Head start (s) of the first cut in the interrupt demos.
const INTERRUPT_LEAD_SEC: float = 0.1
## Demo points (spread over the player half) and freshness (s) left; one entry per point.
const DROPS_FRESHNESS: Array[float] = [6.5, 4.0, 2.0, 0.8]
const EXPIRING_FRESHNESS: float = 0.8
const FULL_POINT_FRESHNESS: float = 5.0
## Points put in the hand by the "selected" demo and which of them are selected.
const SELECTED_SLOTS: Array[int] = [0, 2]
const SELECTED_HAND_COUNT: int = 3
## Seconds the "swing" demo fast-forwards the running swing (so the countdown is mid-way).
const SWING_ELAPSED_SEC: float = 0.3

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _mode: String = ""


func _enter_tree() -> void:
	_mode = _parse_mode()
	# Runs before any sibling _ready, so the grid and drops are created with these.
	if _mode != "":
		_combat().drops_seed = DEMO_SEED
	_combat().grid_override = _parse_grid()
	_combat().boss_set_override = _parse_boss_set()


func _ready() -> void:
	if _mode == "":
		return
	var combat: CombatView = _combat()
	combat.freeze_time = true
	# The boss stays still in every demo (no decisions, no clocks).
	combat.get_boss().set_active(false)
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
		"preview2":
			var n: int = grid.side_cols
			_cut_hand([_lbl("A", 1), _lbl("C", n), _lbl("B", 2)], [0, 1])
		"preview4":
			var n: int = grid.side_cols
			_cut_hand([_lbl("A", 1), _lbl("A", n), _lbl("C", n), _lbl("C", 1)], [0, 1, 2, 3])
		"menu":
			var n: int = grid.side_cols
			_cut_hand([_lbl("A", 1), _lbl("A", n)], [0, 1])
			_confirm_or_warn(combat)
		"swing":
			_cut_hand([_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], [0])
			_confirm_or_warn(combat)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"hit", "miss":
			_cut_hand([_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], [0])
			var column: int = grid.side_cols if _mode == "hit" else grid.side_cols * 2 - 1
			var target := Vector2i(column, combat.get_state().enemy_cell.y)
			if not combat.get_state().set_enemy_cell(target):
				push_warning("DemoArgs: could not move the boss to %s" % str(target))
			_confirm_or_warn(combat)
			var actor: CutActor = combat.get_cut_actor()
			combat.get_arbiter().tick(actor.get_time_left() + 0.001)
		"boss_pick":
			var boss: BossController = combat.get_boss()
			_boss_hand([_lbl("A", 1), _lbl("C", grid.side_cols)])
			var near: Vector2i = _enemy_neighbour(grid, combat.get_state().enemy_cell)
			var cells: Array[Vector2i] = [near]
			for cell: Vector2i in _spread_enemy_cells(grid, BOSS_FIELD_FRESHNESS.size() + 2):
				if cells.size() < BOSS_FIELD_FRESHNESS.size() and cell != near and cell != combat.get_state().enemy_cell:
					cells.append(cell)
			var labels: Array[String] = _spread_labels(grid, cells.size(), 1)
			for i: int in cells.size():
				boss.get_drops().debug_place(labels[i], cells[i], BOSS_FIELD_FRESHNESS[i])
		"boss_swing", "boss_hit", "boss_miss":
			var covered: Array[Vector2i] = _boss_cut(combat, [_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], 1)
			_place_player(combat, covered, _mode == "boss_hit")
			if _mode == "boss_swing":
				combat.get_arbiter().tick(SWING_ELAPSED_SEC)
			else:
				combat.get_arbiter().tick(combat.get_boss().get_actor().get_time_left() + 0.001)
		"interrupt_player":
			# The player's cut starts first, the boss's 0.1 s later: the player's resolves
			# first, hits the boss and cancels the boss's running cut.
			_boss_to_player_column(combat)
			_cut_hand([_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], [0])
			_confirm_or_warn(combat)
			combat.get_arbiter().tick(INTERRUPT_LEAD_SEC)
			_boss_cut(combat, [_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], 1)
			combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)
		"interrupt_boss":
			# Mirror: the boss's cut starts first and hits the player, cancelling the player's.
			_boss_to_player_column(combat)
			var covered2: Array[Vector2i] = _boss_cut(combat, [_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], 1)
			_place_player(combat, covered2, true)
			combat.get_arbiter().tick(INTERRUPT_LEAD_SEC)
			_cut_hand([_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], [0])
			_confirm_or_warn(combat)
			combat.get_arbiter().tick(combat.get_boss().get_actor().get_time_left() + 0.001)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)


func _parse_boss_set() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(BOSS_PREFIX):
			return arg.substr(BOSS_PREFIX.length())
	return ""


# Puts synthetic points with [param labels] into the boss's first hand slots.
func _boss_hand(labels: Array[String]) -> void:
	var hand: HoldSlots = _combat().get_boss().get_hand()
	for i: int in mini(labels.size(), hand.get_slot_count()):
		var point := FieldPoint.new()
		point.uid = BOSS_UID_BASE - i
		point.label = labels[i]
		point.freshness_left = 0.0
		hand.place(point, i)


# Fills the boss's hand with [param labels] and commits a cut with the first [param use] of
# them through BossController's real cut path (private _do_cut: dev-only). Returns the covered
# cells on the player's half (empty + warning if the cut did not start).
func _boss_cut(combat: CombatView, labels: Array[String], use: int) -> Array[Vector2i]:
	var boss: BossController = combat.get_boss()
	_boss_hand(labels)
	var indices: Array[int] = []
	for i: int in use:
		indices.append(i)
	boss.call("_do_cut", {"hand_indices": indices, "skill_id": SkillConfig.FALLBACK_SKILL})
	if not boss.get_actor().is_swinging():
		push_warning("DemoArgs: the boss cut did not start for demo '%s'" % _mode)
	return boss.get_actor().get_cells()


# Moves the player INTO (or, if not [param inside], OUT of) the covered cells.
func _place_player(combat: CombatView, covered: Array[Vector2i], inside: bool) -> void:
	for cell: Vector2i in combat.get_grid().player_cells():
		if covered.has(cell) == inside:
			if not combat.get_state().set_player_cell(cell):
				push_warning("DemoArgs: could not move the player to %s" % str(cell))
			return
	push_warning("DemoArgs: no player cell %s the boss cut" % ("inside" if inside else "outside"))


# Boss into the first column of its half (where the player's A1 cut lands) on its own row.
func _boss_to_player_column(combat: CombatView) -> void:
	var target := Vector2i(combat.get_grid().side_cols, combat.get_state().enemy_cell.y)
	if not combat.get_state().set_enemy_cell(target):
		push_warning("DemoArgs: could not move the boss to %s" % str(target))


# A boss-half cell next to [param cell] (any direction), or [param cell] itself if none.
func _enemy_neighbour(grid: BoardGrid, cell: Vector2i) -> Vector2i:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		if grid.is_enemy_cell(cell + direction):
			return cell + direction
	return cell


# Like _spread_cells, over the boss's half.
func _spread_enemy_cells(grid: BoardGrid, count: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = grid.enemy_cells()
	var out: Array[Vector2i] = []
	for i: int in count:
		var index: int = 0
		if count > 1:
			index = roundi(float(all.size() - 1) * i / float(count - 1))
		if not out.has(all[index]):
			out.append(all[index])
	return out


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


func _lbl(edge: String, index: int) -> String:
	return "%s%d" % [edge, index]


# Puts synthetic points with [param labels] into the first slots (as many as fit), then
# selects the slots [param selected] in that order.
func _cut_hand(labels: Array[String], selected: Array[int]) -> void:
	for i: int in mini(labels.size(), _hold().get_slot_count()):
		var point := FieldPoint.new()
		point.uid = -1 - i
		point.label = labels[i]
		point.freshness_left = 0.0
		_hold().place(point, i)
	for index: int in selected:
		_hold().toggle_selected(index)


func _confirm_or_warn(combat: CombatView) -> void:
	if not combat.confirm_selection():
		push_warning("DemoArgs: confirm_selection failed for demo '%s'" % _mode)


# Puts [param count] synthetic points straight into the first hand slots.
func _fill_hand(count: int) -> void:
	var labels: Array[String] = _spread_labels(_combat().get_grid(), count, 1)
	for i: int in count:
		var point := FieldPoint.new()
		point.uid = -1 - i
		point.label = labels[i]
		point.freshness_left = 0.0
		_hold().place(point, i)
