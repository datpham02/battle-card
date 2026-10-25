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
##   godot --path . -- --demo=rotten     Story 014: a ROTTEN point on the player's half (FieldDrops.place_rotten, the
##                                      real trait path: grey, dark X, grey tag and bar) and the hand with a rotten
##                                      point in slot 1 (grey, X, "4.2" countdown) between two normal points
##   godot --path . -- --demo=row_warn   Story 014: a RowBurnerTrait built by hand (TraitRegistry.create, setup with
##                                      CombatView.make_trait_ctx(), TraitHost.debug_add_trait) and ticked until it
##                                      announces the player's row with ~0.7 s of warning left: blinking amber
##                                      outline, shrinking top bar, "SẮP CHÁY" tag; the player stands in that row
##   godot --path . -- --demo=row_burning  as row_warn, ticked past the warning: the row is on fire through
##                                      StatusEffects.ignite (existing burn look), 1.0 s of burning elapsed
##   godot --path . -- --demo=paused     Story 016: the "swing" setup, then the run is PAUSED for real
##                                      (RunController.set_paused(true, force) after the intro is skipped):
##                                      time is NOT frozen here, the pause is what holds the swing clock,
##                                      so two captures >= 1 s apart show the same countdown under the overlay
##   godot --path . -- --demo=formation_half|formation_warn|formation_complete   Story 029: formation map half lit / cells about to fade / completed (flash + banner); skips the intro
##   godot --path . -- --demo=signature_cooldown   Story 029 Phần D: 40% of the enemy cells lit, signature cooldown ~9 s left ("Hồi 9 s"); skips the intro
##   godot --path . -- --demo=signature_ready|signature_half  Story 021: signature charge full / half (needs CombatView.debug_set_signature_charge)
##   godot --path . --character=phap_su -- --demo=thien_hoa_fire   Story 030: the boss's cell already burning (as after a burn card), the
##                                           whole enemy board lit, Thien Hoa fired through the real activate_signature(): the old burn
##                                           detonates (boss HP drop, banner), then every lit cell is set on fire (burn hatch on the whole half)
##   godot --path . --character=phap_su -- --demo=thien_hoa_burning  Story 030: as thien_hoa_fire, then the burn advanced by
##                                           THIEN_HOA_BURNING_DEMO_SEC (StatusEffects.tick): the sea of fire still burning, its DoT on the boss
##   godot --path . --character=sat_thu -- --demo=anh_bo_hit  Story 030: Anh Bo active (blue border, banner) and a 2-cell piece cast resolved on
##                                           the boss: HIT and the doubled "-N"
##   Story 024 piece demos (the label demos above no longer apply to the player: the player has a piece bag now):
##   godot --path . -- --demo=pieces_hand    three pieces lying on the player's half (mini shapes, freshness bars) and a full bag
##   godot --path . -- --demo=placing_hit    PLACING with a piece (default l4, or --piece=<id>) over the boss's cell: green ghost,
##                                           cell count + damage, Focus active (tint, bar, d-pad locked)
##   godot --path . -- --demo=placing_miss   as placing_hit with the ghost on cells that do not cover the boss: red ghost
##   godot --path . -- --demo=placing_rotated as placing_hit after one 90-degree rotation (CombatView.rotate_piece)
##   godot --path . -- --demo=placing_center a single-cell piece (default mono) on the centre cell of the boss's half
##   godot --path . -- --demo=placing_drag   mid-drag: a simulated finger holds the piece, the ghost floats drag_lift_px above it
##                                           over the boss's cell (green), the "Xoay" button fills the d-pad area
##   godot --path . -- --demo=pieces_menu    the piece placed and confirmed: card menu open (piece consumed from the bag)
##   godot --path . -- --demo=rotten_piece   a ROTTEN piece on the player's half and in the bag (grey, X, countdown)
##   godot --path . -- --piece=<id>          DEV-ONLY: the shape (pieces.json id) the placing / menu demos use
##   Story 028 join demos (the cast of two pieces; the boss stays still):
##   godot --path . -- --demo=join_menu      card menu open, piece 1 placed, piece 2 mid-drag (ghost lifted, Xoay shown)
##   godot --path . -- --demo=join_featured  two pieces joined into the match's featured shape (needs --arena=<shape>): glow + label
##   godot --path . -- --demo=join_split     two separate pieces attached, the menu shows the total cells
##   godot --path . -- --arena=<shape>       DEV-ONLY arena shape id of arenas.json (cross, u_shape, ring, ...): sets
##       match_params["arena"] before _ready, so the board and the featured-shape icon follow it. Works with or without --demo.
##   (every demo deactivates the boss: BossController.set_active(false); swings are fast-forwarded
##    through SwingArbiter.tick, the boss cuts through BossController's real cut path)
##   godot --path . -- --boss=<set>   DEV-ONLY boss weight set (balanced/aggressive/cautious, see
##       boss_brain.json); sets CombatView.boss_set_override before _ready. Works with or without --demo.
##   godot --path . -- --grid=<cols>x<rows>[:c,r;c,r...]   DEV-ONLY board override
##       <cols>x<rows> = columns x rows of ONE half; the optional list is missing cells in
##       side coordinates (col 0 = farthest from the divider; mirrored to the boss half),
##       e.g. --grid=4x3:0,0;0,2. Combines with any --demo (or none). Replaces side_cols /
##       side_rows / missing_cells of combat.json and clears the start-cell overrides.
##   godot --path . -- --deck=a,b,c    DEV-ONLY player deck (card ids of cards.json, repeats allowed) for the
##       battle: written into CombatView.match_params["deck"] before _ready (Story 017), e.g.
##       --demo=menu --deck=kiem_khi,chan_phong,hoa_tran shows a 3-card hand with one empty slot.
##   godot --path . -- --drops-seed=N  DEV-ONLY seed of the drops RNG AND the deck shuffle bag (default 7 in
##       every demo): --demo=menu --drops-seed=1 vs --drops-seed=2 give two different hands.
##   godot --path . -- --debug         DEV overlay: sets CombatView.debug_overlay (Story 016), so the HUD draws its
##       debug text (the boss learning line "né | ngắt | giả"); hidden by default. Works with or without --demo.
## Every demo freezes time (CombatView.freeze_time) so screenshots are deterministic, and
## seeds the drop RNG. No argument = normal game, this node does nothing. State is set in
## _ready, before the first frame (the seed and the grid in _enter_tree, before
## CombatView._ready). Demo cells and labels are derived from the board, never hardcoded.

const DEMO_PREFIX: String = "--demo="
const GRID_PREFIX: String = "--grid="
const BOSS_PREFIX: String = "--boss="
const DEBUG_ARG: String = "--debug"
const DECK_PREFIX: String = "--deck="
const DROPS_SEED_PREFIX: String = "--drops-seed="
const PIECE_PREFIX: String = "--piece="
const ARENA_PREFIX: String = "--arena="
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
const SKILL_BURN: String = "hoa_tran"
const SKILL_PIN: String = "bang_phong"
## Story 012 demos: REAL seconds of Focus left in "focus" / "focus_timeout", and of cooldown
## left in "focus_cooldown" (the totals come from cards.json through FocusController).
const FOCUS_DEMO_LEFT_SEC: float = 2.5
const FOCUS_TIMEOUT_DEMO_LEFT_SEC: float = 0.3
const FOCUS_COOLDOWN_DEMO_LEFT_SEC: float = 6.0
## Story 013 combo demos: boss hand slots of swing 1 and of the queued swing 2, and the corner
## cell the player is moved to (inside swing 1's column).
const COMBO_SWING_INDICES: Array[int] = [0]
const COMBO_QUEUED_INDICES: Array[int] = [1]
const COMBO_PLAYER_CELL: Vector2i = Vector2i.ZERO
## Story 014 demos: the rotten field point's freshness (s) and the held one's rot countdown (s),
## the hand slot it sits in, the warning left (s) when "row_warn" is captured, the step used to
## walk the trait to its warning, and the walk's bound (steps) so a misconfigured trait cannot hang.
const ROTTEN_FIELD_FRESHNESS: float = 5.0
const ROTTEN_HAND_LEFT_SEC: float = 4.2
const ROTTEN_HAND_SLOT: int = 1
const ROW_WARN_LEFT_SEC: float = 0.7
const TRAIT_STEP_SEC: float = 0.05
const TRAIT_MAX_STEPS: int = 10000
## Story 024 piece demos: default shape of the placing demos and of the single-cell one, the bag
## contents of the other demos as [shape id, rotation], freshness (s) of the lying pieces, the slot
## the rotten piece sits in.
const PLACING_DEFAULT_PIECE: String = "l4"
const CENTER_DEFAULT_PIECE: String = "mono"
const BAG_PIECES: Array = [["t4", 0], ["bar3", 1], ["square", 0]]
const FIELD_PIECES: Array = [["l3", 0], ["bar2", 1], ["plus5", 0]]
const FIELD_PIECE_FRESHNESS: Array[float] = [7.0, 4.5, 2.5]
const ROTTEN_PIECE_SLOT: int = 1
## Story 024 demos that also skip the match intro banner (so the board is visible for a capture).
const PIECE_DEMOS: Array[String] = ["pieces_hand", "placing_hit", "placing_miss", "placing_rotated", "placing_center", "placing_drag", "pieces_menu", "rotten_piece", "join_menu", "join_featured", "join_split", "formation_half", "formation_warn", "formation_complete", "signature_cooldown", "thien_hoa_fire", "thien_hoa_burning", "anh_bo_hit"]
## Story 030 demo: the piece of the "anh_bo_hit" cast (2 cells, <= Anh Bo's small_cells).
const ANH_BO_DEMO_PIECE: String = "bar2"
## Story 029 Phần D demo: share of the enemy cells lit and the cooldown seconds left (dev capture only).
const SIGNATURE_COOLDOWN_DEMO_CHARGE: float = 0.4
const SIGNATURE_COOLDOWN_DEMO_SEC: float = 9.0
## Story 030 "thien_hoa_burning" demo: seconds of burn advanced after the activation (dev capture only).
const THIEN_HOA_BURNING_DEMO_SEC: float = 1.0
## Story 028 join demos: piece 1 and piece 2 of "join_menu" / "join_split" (--piece= overrides piece 1).
const JOIN_PIECE_1: String = "l3"
const JOIN_PIECE_2: String = "bar2"
## Slot of the second piece in the join demos' bag.
const JOIN_SLOT_2: int = 1

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _mode: String = ""


func _enter_tree() -> void:
	_mode = _parse_mode()
	# Runs before any sibling _ready, so the grid and drops are created with these.
	var arena_id: String = _parse_arena()
	if not arena_id.is_empty():
		_combat().match_params["arena"] = {"shape": arena_id}
	if _mode != "":
		_combat().drops_seed = DEMO_SEED
	_combat().grid_override = _parse_grid()
	_combat().boss_set_override = _parse_boss_set()
	_combat().debug_overlay = OS.get_cmdline_user_args().has(DEBUG_ARG)
	var deck: Array[String] = _parse_deck()
	if not deck.is_empty():
		_combat().match_params["deck"] = deck
	var drops_seed: int = _parse_drops_seed()
	if drops_seed >= 0:
		_combat().drops_seed = drops_seed


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
		"paused":
			_cut_hand([_lbl("A", 1), _lbl("B", 2), _lbl("C", grid.side_cols)], [0])
			_confirm_or_warn(combat)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
			# The pause, not the demo freeze, must hold the swing: unfreeze and pause the run once
			# the controller holds this battle (deferred: this _ready runs inside its add_child).
			combat.freeze_time = false
			_pause_run.call_deferred()
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
		"rotten":
			# Field: the real trait path (place_rotten) on a cell away from the player. Hand: two
			# normal points around a rotten one, so the grey / X / countdown contrast is visible.
			var rotten_cell: Vector2i = _other_player_cell(grid, combat.get_state().player_cell)
			if combat.get_drops().place_rotten(rotten_cell, RottenThrowerTrait.DEFAULT_LABEL, ROTTEN_FIELD_FRESHNESS, ROTTEN_HAND_LEFT_SEC) == null:
				push_warning("DemoArgs: could not place the rotten point on %s" % str(rotten_cell))
			_fill_hand(mini(ROTTEN_HAND_SLOT + 2, _hold().get_slot_count()))
			_hold().remove(ROTTEN_HAND_SLOT)
			var held := FieldPoint.new()
			held.uid = BOSS_UID_BASE - 1
			held.label = RottenThrowerTrait.DEFAULT_LABEL
			held.rotten = true
			held.rot_in_hand_sec = ROTTEN_HAND_LEFT_SEC
			if _hold().place(held, ROTTEN_HAND_SLOT) < 0:
				push_warning("DemoArgs: could not place the rotten point in hand slot %d" % ROTTEN_HAND_SLOT)
		"row_warn", "row_burning":
			var burner: RowBurnerTrait = _make_row_burner(combat)
			if burner != null:
				# Walk the trait (sim time) to its first warning; the player's row is the default pick.
				var steps: int = 0
				while burner.get_warning_cells().is_empty() and steps < TRAIT_MAX_STEPS:
					burner.on_tick(TRAIT_STEP_SEC)
					steps += 1
				if burner.get_warning_cells().is_empty():
					push_warning("DemoArgs: the row burner never warned for demo '%s'" % _mode)
				elif _mode == "row_warn":
					burner.on_tick(maxf(burner.get_warn_left() - ROW_WARN_LEFT_SEC, 0.0))
				else:
					burner.on_tick(burner.get_warn_left() + 0.001)
					combat.get_status().tick(BURN_ELAPSED_SEC, combat.get_state())
		"signature_ready", "signature_half":
			# Story 021: the signature charge bar full (ready) or half full; the dev hook is Part 1's
			# CombatView.debug_set_signature_charge(ratio).
			if combat.has_method("debug_set_signature_charge"):
				combat.call("debug_set_signature_charge", 1.0 if _mode == "signature_ready" else 0.5)
			else:
				push_warning("DemoArgs: CombatView.debug_set_signature_charge missing, signature demo skipped")
		"formation_half", "formation_warn", "formation_complete":
			_formation_demo(combat, grid)
		"signature_cooldown":
			# Story 029 Phần D: some cells lit and the signature cooldown ~9 s left ("Hồi 9 s" button).
			combat.debug_set_signature_charge(SIGNATURE_COOLDOWN_DEMO_CHARGE)
			combat.debug_set_signature_cooldown(SIGNATURE_COOLDOWN_DEMO_SEC)
		"thien_hoa_fire", "thien_hoa_burning":
			_thien_hoa_demo(combat, grid)
		"anh_bo_hit":
			_anh_bo_demo(combat, grid)
		"pieces_hand":
			var lib: PieceLibrary = PieceLibrary.load_from_file()
			var spots: Array[Vector2i] = _spread_cells(grid, FIELD_PIECES.size() + 1)
			var placed: int = 0
			for cell: Vector2i in spots:
				if cell == combat.get_state().player_cell or placed >= FIELD_PIECES.size():
					continue
				var spec: Array = FIELD_PIECES[placed]
				combat.get_drops().debug_place_piece(lib.make_piece(str(spec[0]), int(spec[1])), cell, FIELD_PIECE_FRESHNESS[placed])
				placed += 1
			_fill_bag(lib, -1)
		"placing_hit", "placing_miss", "placing_rotated", "placing_center", "placing_drag", "pieces_menu":
			_placing_demo(combat, grid)
		"join_menu", "join_featured", "join_split":
			_join_demo(combat, grid)
		"rotten_piece":
			var lib2: PieceLibrary = PieceLibrary.load_from_file()
			var rotten_cell2: Vector2i = _other_player_cell(grid, combat.get_state().player_cell)
			if combat.get_drops().place_rotten_piece(rotten_cell2, ROTTEN_FIELD_FRESHNESS, ROTTEN_HAND_LEFT_SEC) == null:
				push_warning("DemoArgs: could not place the rotten piece on %s" % str(rotten_cell2))
			_fill_bag(lib2, ROTTEN_PIECE_SLOT)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)
	if PIECE_DEMOS.has(_mode):
		_skip_intro.call_deferred()


# Story 029 formation demos (FormationMap.set_cells, freeze_time keeps the fades still). half: the first
# half of the real enemy cells lit at mixed freshness. warn: every other cell lit, about half of those
# under the warn ratio (they draw faint + dashed). complete: covers every enemy cell through the real
# completion path (CombatView._cover_formation, DEV-ONLY): ready flag, flash and banner; time is
# frozen, so the flash holds at 1.
func _formation_demo(combat: CombatView, grid: BoardGrid) -> void:
	var map: FormationMap = combat.get_formation()
	if map == null:
		push_warning("DemoArgs: no formation map (character without a signature) for demo '%s'" % _mode)
		return
	var cells: Array[Vector2i] = grid.enemy_cells()
	if _mode == "formation_complete":
		combat.call("_cover_formation", cells)
		return
	var warn: float = combat.get_config().formation_fade_warn_ratio
	var fresh: Array[float] = [1.0, 0.8, 0.55, 0.35]
	var lit: int = 0
	for i: int in cells.size():
		if _mode == "formation_half":
			if i >= (cells.size() + 1) / 2:
				break
			map.set_cells([cells[i]] as Array[Vector2i], fresh[i % fresh.size()])
		else:
			if i % 2 == 1:
				continue
			var fraction: float = 0.9 if lit % 3 == 0 else warn * 0.5
			map.set_cells([cells[i]] as Array[Vector2i], fraction)
			lit += 1


# Story 030 Thien Hoa demos (needs --character=phap_su). The boss's cell is set burning first (the signature's own
# burn params, standing in for a burn card) so the detonation has something to blow up; the whole enemy board is
# lit on the formation map; the real activate_signature() detonates that burn, then sets every lit cell on fire.
# thien_hoa_burning then advances only the burn by THIEN_HOA_BURNING_DEMO_SEC (deterministic, time stays frozen).
func _thien_hoa_demo(combat: CombatView, grid: BoardGrid) -> void:
	var map: FormationMap = combat.get_formation()
	var sig: BaseSignature = combat.get_signature()
	if map == null or not sig is ThienHoaSignature:
		push_warning("DemoArgs: demo '%s' needs --character=phap_su (Thien Hoa signature)" % _mode)
		return
	var status: StatusEffects = combat.get_status()
	status.ignite([combat.get_state().enemy_cell] as Array[Vector2i],
		sig.param_float("burn_duration_sec", ThienHoaSignature.DEFAULT_BURN_DURATION_SEC),
		sig.param_float("burn_tick_sec", ThienHoaSignature.DEFAULT_BURN_TICK_SEC),
		sig.param_float("burn_damage_per_tick", ThienHoaSignature.DEFAULT_BURN_DAMAGE_PER_TICK))
	map.cover(grid.enemy_cells())
	_activate_signature_now(combat)
	if _mode == "thien_hoa_burning":
		status.tick(THIEN_HOA_BURNING_DEMO_SEC, combat.get_state())


# Story 030 "anh_bo_hit" (needs --character=sat_thu): Anh Bo activated (border, timer, banner), then a 2-cell
# piece cast through the real player path (select / aim / confirm / choose) resolved on the boss.
func _anh_bo_demo(combat: CombatView, grid: BoardGrid) -> void:
	if not combat.get_signature() is AnhBoSignature:
		push_warning("DemoArgs: demo '%s' needs --character=sat_thu (Anh Bo signature)" % _mode)
		return
	_activate_signature_now(combat)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var held: FieldPoint = _hold().get_point(0)
	held.piece = lib.make_piece(ANH_BO_DEMO_PIECE, 0)
	held.label = ANH_BO_DEMO_PIECE
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	_aim_hitting(combat, grid, combat.get_state().enemy_cell)
	if not combat.confirm_placement():
		push_warning("DemoArgs: confirm_placement failed for demo '%s'" % _mode)
		return
	var flow: CutFlow = combat.get_cut_flow()
	if not flow.choose(SkillConfig.FALLBACK_SKILL):
		push_warning("DemoArgs: skill '%s' not available for demo '%s'" % [SkillConfig.FALLBACK_SKILL, _mode])
		return
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)


# Marks the signature ready and activates it through CombatView.activate_signature, which refuses while the
# demo freeze is on: the freeze is lifted for this one synchronous call and restored right after.
func _activate_signature_now(combat: CombatView) -> void:
	combat.debug_set_signature_charge(1.0)
	combat.freeze_time = false
	var fired: bool = combat.activate_signature()
	combat.freeze_time = true
	if not fired:
		push_warning("DemoArgs: activate_signature refused for demo '%s'" % _mode)


# Story 024: ends the match intro (finds the RunController like _pause_run) so the banner does not cover
# the board; the demo's freeze_time keeps the simulation still. No-op without a controller above.
func _skip_intro() -> void:
	var node: Node = get_parent()
	while node != null and not node is RunController:
		node = node.get_parent()
	var controller: RunController = node as RunController
	if controller != null and controller.get_state().get_phase() == RunState.Phase.INTRO:
		controller.call("_begin_playing")


# Story 016 "paused" demo: finds the RunController by walking up the parents (the battle is a
# child of the controller, which is a child of GameFlow; no group or path is assumed), skips the
# intro through its private _begin_playing (DEV-ONLY, like the boss's _do_cut above) and pauses
# with force so the swing lockout cannot refuse. Warns (no pause) when no controller is above.
func _pause_run() -> void:
	var node: Node = get_parent()
	while node != null and not node is RunController:
		node = node.get_parent()
	var controller: RunController = node as RunController
	if controller == null:
		push_warning("DemoArgs: no RunController above the battle, 'paused' demo not paused")
		return
	if controller.get_state().get_phase() == RunState.Phase.INTRO:
		controller.call("_begin_playing")
	controller.set_paused(true, true)
	if not controller.is_paused():
		push_warning("DemoArgs: the run did not pause for demo '%s'" % _mode)


# A RowBurnerTrait with default params, set up with the battle's real trait context, started,
# and registered on the match's TraitHost (DEV-ONLY debug_add_trait) so the HUD sees it.
# Null + warning when the registry cannot create it.
func _make_row_burner(combat: CombatView) -> RowBurnerTrait:
	var burner: RowBurnerTrait = TraitRegistry.create(RowBurnerTrait.ID) as RowBurnerTrait
	if burner == null:
		push_warning("DemoArgs: TraitRegistry could not create '%s'" % RowBurnerTrait.ID)
		return null
	burner.setup(combat.make_trait_ctx(), {}, DEMO_SEED)
	burner.on_match_start()
	combat.get_trait_host().debug_add_trait(burner)
	return burner


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


# Parses --deck=a,b,c into card ids (empty when absent; CombatView validates the ids).
func _parse_deck() -> Array[String]:
	var ids: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DECK_PREFIX):
			for id: String in arg.substr(DECK_PREFIX.length()).split(",", false):
				ids.append(id.strip_edges())
	return ids


# Parses --drops-seed=N (negative when absent).
func _parse_drops_seed() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DROPS_SEED_PREFIX):
			return maxi(int(arg.substr(DROPS_SEED_PREFIX.length())), 0)
	return -1


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


# Story 028: --arena=<shape id>, "" when absent.
func _parse_arena() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARENA_PREFIX):
			return arg.substr(ARENA_PREFIX.length())
	return ""


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


# Story 024: bag of the piece demos: BAG_PIECES in the slots (as many as fit); [param rotten_slot] >= 0
# swaps that slot for a ROTTEN piece (grey, counting down) instead.
func _fill_bag(lib: PieceLibrary, rotten_slot: int) -> void:
	for i: int in mini(BAG_PIECES.size(), _hold().get_slot_count()):
		var point := FieldPoint.new()
		point.uid = -1 - i
		point.freshness_left = 0.0
		if i == rotten_slot:
			point.piece = Piece.make_rotten()
			point.label = Piece.ROTTEN_ID
			point.rotten = true
			point.rot_in_hand_sec = ROTTEN_HAND_LEFT_SEC
		else:
			var spec: Array = BAG_PIECES[i]
			point.piece = lib.make_piece(str(spec[0]), int(spec[1]))
			point.label = point.piece.shape_id
		_hold().place(point, i)


# Story 024: the shape the placing demos use: --piece=<id>, else [param fallback].
func _piece_id(fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PIECE_PREFIX):
			return arg.substr(PIECE_PREFIX.length())
	return fallback


# Story 024 placing demos, through the real player path: the bag, select_piece (slot 0), Focus started
# (time is frozen so _update_focus does not run), the ghost aimed with aim_at_cell, rotate_piece for
# "placing_rotated", confirm_placement for "pieces_menu".
func _placing_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var shape: String = _piece_id(CENTER_DEFAULT_PIECE if _mode == "placing_center" else PLACING_DEFAULT_PIECE)
	var held: FieldPoint = _hold().get_point(0)
	held.piece = lib.make_piece(shape, 0)
	held.label = shape
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	var focus: FocusController = combat.get_focus()
	if not focus.try_start():
		push_warning("DemoArgs: Focus did not start for demo '%s'" % _mode)
	var boss_cell: Vector2i = combat.get_state().enemy_cell
	var placement: PlacementController = combat.get_placement()
	if _mode == "placing_center":
		combat.aim_at_cell(Vector2i(grid.side_cols + int(grid.side_cols * 0.5), int(grid.rows * 0.5)))
		return
	if _mode == "placing_drag":
		# Real drag path: the finger picks slot 0 up and moves to the point whose lifted ghost aims at the boss.
		var finger: Vector2 = combat.drag_point_for_cell(boss_cell)
		if not combat.begin_drag(0, _hold_slot_centre(0)):
			push_warning("DemoArgs: begin_drag failed for demo '%s'" % _mode)
			return
		combat.drag_to(finger)
		if not placement.hits(boss_cell):
			# The snap may settle on a position that misses the aimed cell (equal distance): walk the
			# enemy cells with the finger until the lifted ghost covers the boss.
			for cell: Vector2i in grid.enemy_cells():
				combat.drag_to(combat.drag_point_for_cell(cell))
				if placement.hits(boss_cell):
					break
		if not placement.hits(boss_cell):
			push_warning("DemoArgs: the dragged ghost does not cover the boss for demo '%s'" % _mode)
		return
	var want_hit: bool = _mode != "placing_miss"
	if _mode == "placing_rotated":
		combat.rotate_piece()
	combat.aim_at_cell(boss_cell)
	if placement.hits(boss_cell) != want_hit:
		for cell: Vector2i in grid.enemy_cells():
			combat.aim_at_cell(cell)
			if placement.can_confirm() and placement.hits(boss_cell) == want_hit:
				break
	if placement.hits(boss_cell) != want_hit:
		push_warning("DemoArgs: no ghost position gives hit=%s for demo '%s'" % [want_hit, _mode])
	if _mode == "pieces_menu":
		if not combat.confirm_placement():
			push_warning("DemoArgs: confirm_placement failed for demo '%s'" % _mode)


# Centre of bag slot [param index] in viewport pixels (where a finger would pick the piece up).
func _hold_slot_centre(index: int) -> Vector2:
	return (get_node(hold_slots_view_path) as HoldSlotsView).get_slot_rect(index).get_center()


# Story 028 join demos through the real player path (select / aim / confirm, then the second piece).
# join_menu: piece 1 placed, the menu open, piece 2 mid-drag. join_split: piece 2 attached apart from
# piece 1. join_featured: the two pieces tile the match's featured shape (--arena=<shape>).
func _join_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_fill_bag(lib, -1)
	var boss_cell: Vector2i = combat.get_state().enemy_cell
	var id_a: String = _piece_id(JOIN_PIECE_1)
	var id_b: String = JOIN_PIECE_2
	var turns_a: int = 0
	var turns_b: int = 0
	var anchor_a: Vector2i = BoardGrid.NO_CELL
	var anchor_b: Vector2i = BoardGrid.NO_CELL
	if _mode == "join_featured":
		var featured: Dictionary = combat.get_featured()
		if featured.is_empty():
			push_warning("DemoArgs: join_featured needs --arena=<shape> with a featured shape that fits the board")
			return
		var plan: Dictionary = _featured_tiling(lib, grid, featured["cells"] as Array[Vector2i], boss_cell)
		if plan.is_empty():
			push_warning("DemoArgs: no two-piece tiling of the featured shape found")
			return
		id_a = str(plan["id_a"])
		id_b = str(plan["id_b"])
		turns_a = int(plan["turns_a"])
		turns_b = int(plan["turns_b"])
		anchor_a = plan["anchor_a"]
		anchor_b = plan["anchor_b"]
	var first: FieldPoint = _hold().get_point(0)
	first.piece = lib.make_piece(id_a, turns_a)
	first.label = id_a
	var second: FieldPoint = _hold().get_point(JOIN_SLOT_2)
	second.piece = lib.make_piece(id_b, turns_b)
	second.label = id_b
	if not combat.select_piece(0):
		push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
		return
	if anchor_a != BoardGrid.NO_CELL:
		_aim_anchor(combat, anchor_a)
	else:
		_aim_hitting(combat, grid, boss_cell)
	if not combat.confirm_placement():
		push_warning("DemoArgs: confirm_placement failed for demo '%s'" % _mode)
		return
	var placement: PlacementController = combat.get_placement()
	if _mode == "join_menu":
		if not combat.begin_drag(JOIN_SLOT_2, _hold_slot_centre(JOIN_SLOT_2)):
			push_warning("DemoArgs: begin_drag of the second piece failed")
			return
		for cell: Vector2i in grid.enemy_cells():
			combat.drag_to(combat.drag_point_for_cell(cell))
			if placement.can_confirm() and not combat.get_cast_plan().touches(placement.get_cells()):
				break
		return
	if not combat.select_piece(JOIN_SLOT_2):
		push_warning("DemoArgs: select_piece of the second piece failed")
		return
	if anchor_b != BoardGrid.NO_CELL:
		_aim_anchor(combat, anchor_b)
	else:
		for cell: Vector2i in grid.enemy_cells():
			combat.aim_at_cell(cell)
			if placement.can_confirm() and not combat.get_cast_plan().touches(placement.get_cells()):
				break
	if not combat.confirm_placement():
		push_warning("DemoArgs: attaching the second piece failed for demo '%s'" % _mode)


# Aims the selected piece's ghost until its anchor is [param anchor] (walks the enemy cells).
func _aim_anchor(combat: CombatView, anchor: Vector2i) -> bool:
	var placement: PlacementController = combat.get_placement()
	for cell: Vector2i in combat.get_grid().enemy_cells():
		combat.aim_at_cell(cell)
		if placement.get_anchor() == anchor:
			return true
	push_warning("DemoArgs: no aim reaches anchor %s" % str(anchor))
	return false


# Aims the ghost so that it covers [param boss_cell] when any position does.
func _aim_hitting(combat: CombatView, grid: BoardGrid, boss_cell: Vector2i) -> void:
	var placement: PlacementController = combat.get_placement()
	combat.aim_at_cell(boss_cell)
	if placement.hits(boss_cell):
		return
	for cell: Vector2i in grid.enemy_cells():
		combat.aim_at_cell(cell)
		if placement.hits(boss_cell):
			return


# Splits the featured shape (placed on the enemy half, covering the boss cell when possible) into two
# library pieces: {id_a, turns_a, anchor_a, id_b, turns_b, anchor_b}; {} when none tiles it.
func _featured_tiling(lib: PieceLibrary, grid: BoardGrid, featured: Array[Vector2i], boss_cell: Vector2i) -> Dictionary:
	var shape: Piece = Piece.make("featured", featured)
	var anchors: Array[Vector2i] = PiecePlacement.valid_anchors(grid, shape, true)
	if anchors.is_empty():
		return {}
	var anchor: Vector2i = anchors[anchors.size() / 2]
	for candidate: Vector2i in anchors:
		if shape.cells_at(candidate).has(boss_cell):
			anchor = candidate
			break
	var target: Array[Vector2i] = shape.cells_at(anchor)
	for pair: Array in FeaturedShape.pair_compositions(lib, featured):
		for order: int in 2:
			var id_a: String = str(pair[order])
			var id_b: String = str(pair[1 - order])
			for turns_a: int in 4:
				var piece_a: Piece = lib.make_piece(id_a, turns_a)
				var rel_a: Array[Vector2i] = piece_a.relative_cells()
				for start: Vector2i in target:
					var origin: Vector2i = start - rel_a[0]
					var placed: Array[Vector2i] = []
					for cell: Vector2i in rel_a:
						placed.append(cell + origin)
					var inside: bool = true
					for cell: Vector2i in placed:
						inside = inside and target.has(cell)
					if not inside:
						continue
					var rest: Array[Vector2i] = []
					for cell: Vector2i in target:
						if not placed.has(cell):
							rest.append(cell)
					var norm: Array[Vector2i] = FeaturedShape.normalize(rest)
					for turns_b: int in 4:
						if lib.make_piece(id_b, turns_b).relative_cells() == norm:
							return {
								"id_a": id_a, "turns_a": turns_a, "anchor_a": origin,
								"id_b": id_b, "turns_b": turns_b, "anchor_b": _min_cell(rest),
							}
	return {}


func _min_cell(cells: Array[Vector2i]) -> Vector2i:
	var out := Vector2i(1000000, 1000000)
	for cell: Vector2i in cells:
		out = Vector2i(mini(out.x, cell.x), mini(out.y, cell.y))
	return out
