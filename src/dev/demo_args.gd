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
##   godot --path . -- --demo=burn       player cut A1+C<n> (5 cells) confirmed, skill Burn chosen in the menu and resolved
##                                      (real path: hold -> confirm_selection -> CutFlow.choose -> arbiter): 5 burning
##                                      cells with time bars on the boss half, boss moved INTO one: HIT; 1.0 s of
##                                      burning elapsed (bars 2/3, boss HP ticked down)
##   godot --path . -- --demo=pin        as burn with A1+A<n>+C<n>+C1 (whole half) and skill Pin: chain ring + "GHIM" on the boss
##   godot --path . -- --demo=boss_burn  boss cut A1+C<n> with skill burn on the player's half (boss real cut path), player
##                                      standing INSIDE: 5 burning cells, HIT on the player, 1.0 s elapsed
##   godot --path . -- --demo=boss_pin   boss cut A1+A<n>+C<n>+C1 with skill pin, player inside: chain ring + "GHIM" on the player
##   godot --path . -- --demo=feint      boss 1-point cut (A1) forced to be a feint (BossController.force_next_feint, DEV-ONLY),
##                                      arbiter stepped until the controller's own _tick_feint cancels it at
##                                      feint_cancel_fraction: dashed grey "ĐÒN GIẢ!" flash on the player's half
##   godot --path . -- --demo=learning   BossLearning fed directly (3 early dodges, 2 interrupts): the debug line under
##                                      the boss HP bar reads "né: 3 | ngắt: 2 | giả: 15%" (with boss_brain.json numbers)
##   godot --path . -- --demo=focus      Story 012: hand A1,C<n>,B2 with A1 then C<n> selected and Focus ACTIVE
##                                      (FocusController.try_start + tick_real, as CombatView._update_focus would do
##                                      on the first frame) with 2.5 s left: blue-grey board tint, viewport frame,
##                                      "TẬP TRUNG 2.5 s" bar above Chốt, d-pad locked (dim), "DỪNG" tag, "5 ô" preview
##   godot --path . -- --demo=focus_timeout  as focus with 0.3 s left: the bar is orange (last quarter)
##   godot --path . -- --demo=focus_cooldown Focus just ended by Chốt (try_start, end("confirmed")) with 6 s of cooldown
##                                      left; a point is still selected to show that selecting does NOT pause now:
##                                      no tint, grey "Tập trung còn 6 s" bar filling up, d-pad normal, Chốt visible
##   godot --path . -- --demo=combo      Story 013: boss hand A1,B1,C<n>; BossController._do_cut with a "combo" entry
##                                      (slot 0 = A1 now, slot 1 = B1 queued on the actor; real path, both slash), the
##                                      player moved to the corner (0,0) so swing 1 covers it; arbiter fast-forwarded
##                                      0.3 s: solid red column 1 with its countdown box + hatched lighter-red row 1
##                                      with "2: +g s" at its bottom-right (g = combo_gap_sec, 0.5 with boss_brain.json);
##                                      the shared corner cell keeps swing 1's solid look
##   godot --path . -- --demo=combo_second  as combo, fast-forwarded past swing 1's impact: HIT "-N" on the player
##                                      (it stood in column 1) and swing 2 (row 1) is now the RUNNING swing with its
##                                      own countdown, started with the full gap when swing 1 resolved and drawn by
##                                      the normal boss-swing path (no queued layer any more)
##   godot --path . -- --demo=cooldown --grid=6x6   "grid66_pace": the board-scaled step cooldown on a 6x6 half right
##                                      after a step (0.45 * (2/5)^0.75 = ~0.23 s with combat.json numbers): the ring is
##                                      visibly shorter than on 3x3 (0.45 s). Not a separate mode: the cooldown demo
##                                      takes the --grid override like every demo (verified headless)
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
## Story 010 demos: seconds of status time elapsed after a burn / pin landed (bars and the
## "GHIM" countdown are mid-way), the arbiter step used to walk a feint to its cancel point,
## and the learning events fed by the "learning" demo.
const BURN_ELAPSED_SEC: float = 1.0
const PIN_ELAPSED_SEC: float = 0.4
const FEINT_STEP_SEC: float = 0.01
const LEARNING_DODGES: int = 3
const LEARNING_INTERRUPTS: int = 2
const SKILL_BURN: String = "burn"
const SKILL_PIN: String = "pin"
## Story 012 demos: REAL seconds of Focus left in "focus" / "focus_timeout", and of cooldown
## left in "focus_cooldown" (the totals come from skills.json through FocusController).
const FOCUS_DEMO_LEFT_SEC: float = 2.5
const FOCUS_TIMEOUT_DEMO_LEFT_SEC: float = 0.3
const FOCUS_COOLDOWN_DEMO_LEFT_SEC: float = 6.0
## Story 013 combo demos: boss hand slots of swing 1 and of the queued swing 2, and the corner
## cell the player is moved to (inside swing 1's column).
const COMBO_SWING_INDICES: Array[int] = [0]
const COMBO_QUEUED_INDICES: Array[int] = [1]
const COMBO_PLAYER_CELL: Vector2i = Vector2i.ZERO

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
		"burn":
			var n: int = grid.side_cols
			_player_skill_cut(combat, [_lbl("A", 1), _lbl("C", n)], SKILL_BURN)
			combat.get_status().tick(BURN_ELAPSED_SEC, combat.get_state())
		"pin":
			var n: int = grid.side_cols
			_player_skill_cut(combat, [_lbl("A", 1), _lbl("A", n), _lbl("C", n), _lbl("C", 1)], SKILL_PIN)
			combat.get_status().tick(PIN_ELAPSED_SEC, combat.get_state())
		"boss_burn":
			var covered3: Array[Vector2i] = _boss_cut(combat, [_lbl("A", 1), _lbl("C", grid.side_cols)], 2, SKILL_BURN)
			_place_player(combat, covered3, true)
			combat.get_arbiter().tick(combat.get_boss().get_actor().get_time_left() + 0.001)
			combat.get_status().tick(BURN_ELAPSED_SEC, combat.get_state())
		"boss_pin":
			var n: int = grid.side_cols
			var covered4: Array[Vector2i] = _boss_cut(combat, [_lbl("A", 1), _lbl("A", n), _lbl("C", n), _lbl("C", 1)], 4, SKILL_PIN)
			_place_player(combat, covered4, true)
			combat.get_arbiter().tick(combat.get_boss().get_actor().get_time_left() + 0.001)
			combat.get_status().tick(PIN_ELAPSED_SEC, combat.get_state())
		"feint":
			# The controller rolls feints from its RNG; the DEV-ONLY flag forces this one. The
			# boss is inactive, so its _tick_feint is called directly (same cancel path).
			var boss: BossController = combat.get_boss()
			boss.force_next_feint = true
			var covered5: Array[Vector2i] = _boss_cut(combat, [_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], 1)
			_place_player(combat, covered5, false)
			while boss.get_actor().is_swinging():
				combat.get_arbiter().tick(FEINT_STEP_SEC)
				boss.call("_tick_feint")
			if combat.get_feint_flash().is_empty():
				push_warning("DemoArgs: the boss swing resolved instead of feinting")
		"learning":
			var learning: BossLearning = combat.get_learning()
			var here: Vector2i = combat.get_state().player_cell
			var away: Vector2i = _other_player_cell(grid, here)
			var swing_cells: Array[Vector2i] = [here]
			for _i: int in LEARNING_DODGES:
				learning.on_boss_swing_started(swing_cells, here)
				learning.on_player_moved(away)
				learning.on_boss_swing_resolved(false)
			for _i: int in LEARNING_INTERRUPTS:
				learning.on_player_interrupted_boss()
		"focus", "focus_timeout":
			# Time is frozen, so CombatView._update_focus never runs: start Focus on the
			# controller directly (same call) and position its real-time clock.
			var n: int = grid.side_cols
			_cut_hand([_lbl("A", 1), _lbl("C", n), _lbl("B", 2)], [0, 1])
			var focus: FocusController = combat.get_focus()
			if not focus.try_start():
				push_warning("DemoArgs: Focus did not start for demo '%s'" % _mode)
			var left: float = FOCUS_DEMO_LEFT_SEC if _mode == "focus" else FOCUS_TIMEOUT_DEMO_LEFT_SEC
			focus.tick_real(maxf(focus.get_max_sec() - left, 0.0))
		"focus_cooldown":
			var n: int = grid.side_cols
			_cut_hand([_lbl("A", 1), _lbl("C", n), _lbl("B", 2)], [0, 1])
			var focus: FocusController = combat.get_focus()
			if not focus.try_start():
				push_warning("DemoArgs: Focus did not start for demo '%s'" % _mode)
			focus.end(FocusController.REASON_CONFIRMED)
			focus.tick_real(maxf(focus.get_cooldown_sec() - FOCUS_COOLDOWN_DEMO_LEFT_SEC, 0.0))
		"combo", "combo_second":
			# Real boss cut path with a "combo" entry (as BossBrain builds it): swing 1 from slot 0
			# (A1), swing 2 from slot 1 (B1) queued on the actor; the actor starts swing 2 with
			# the full gap when swing 1 resolves inside the arbiter's slices.
			var boss: BossController = combat.get_boss()
			_boss_hand([_lbl("A", 1), _lbl("B", 1), _lbl("C", grid.side_cols)])
			boss.call("_do_cut", {
				"hand_indices": COMBO_SWING_INDICES, "skill_id": SkillConfig.FALLBACK_SKILL,
				"combo": {"hand_indices": COMBO_QUEUED_INDICES, "skill_id": BossController.COMBO_SKILL},
			})
			if not boss.get_actor().has_queued():
				push_warning("DemoArgs: the boss combo did not queue for demo '%s'" % _mode)
			if not combat.get_state().set_player_cell(COMBO_PLAYER_CELL):
				push_warning("DemoArgs: could not move the player to %s" % str(COMBO_PLAYER_CELL))
			if _mode == "combo":
				combat.get_arbiter().tick(SWING_ELAPSED_SEC)
			else:
				combat.get_arbiter().tick(boss.get_actor().get_time_left() + 0.001)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)


# Real player path for a multi-point skill cut: [param labels] into the hand, all selected,
# confirmed (menu opens), the boss moved INTO the covered cells, [param skill_id] chosen, the
# swing fast-forwarded to its resolution. Warns at every step that fails.
func _player_skill_cut(combat: CombatView, labels: Array[String], skill_id: String) -> void:
	var selected: Array[int] = []
	for i: int in labels.size():
		selected.append(i)
	_cut_hand(labels, selected)
	_confirm_or_warn(combat)
	var flow: CutFlow = combat.get_cut_flow()
	_place_boss(combat, flow.get_cells(), true)
	if not flow.choose(skill_id):
		push_warning("DemoArgs: skill '%s' not available for demo '%s'" % [skill_id, _mode])
		return
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)


# Moves the boss INTO (or, if not [param inside], OUT of) the covered cells on its half.
func _place_boss(combat: CombatView, covered: Array[Vector2i], inside: bool) -> void:
	for cell: Vector2i in combat.get_grid().enemy_cells():
		if covered.has(cell) == inside:
			if not combat.get_state().set_enemy_cell(cell):
				push_warning("DemoArgs: could not move the boss to %s" % str(cell))
			return
	push_warning("DemoArgs: no boss cell %s the player cut" % ("inside" if inside else "outside"))


# Any player cell other than [param cell] (or [param cell] itself on a one-cell half).
func _other_player_cell(grid: BoardGrid, cell: Vector2i) -> Vector2i:
	for other: Vector2i in grid.player_cells():
		if other != cell:
			return other
	return cell


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
# them and [param skill_id] through BossController's real cut path (private _do_cut: dev-only).
# Returns the covered cells on the player's half (empty + warning if the cut did not start).
func _boss_cut(combat: CombatView, labels: Array[String], use: int, skill_id: String = SkillConfig.FALLBACK_SKILL) -> Array[Vector2i]:
	var boss: BossController = combat.get_boss()
	_boss_hand(labels)
	var indices: Array[int] = []
	for i: int in use:
		indices.append(i)
	boss.call("_do_cut", {"hand_indices": indices, "skill_id": skill_id})
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
