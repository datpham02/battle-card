class_name DemoArgs
extends Node
## DEV-ONLY capture hook: puts the screen into a deterministic state for screenshots.
## Godot user args go after "--":
##   godot --path . -- --demo=board     empty board, d-pad, empty hand (no points; time frozen)
##   godot --path . -- --demo=cooldown  player just stepped: cooldown ring visible, d-pad dimmed
##   godot --path . -- --demo=learning   BossLearning fed directly (3 early dodges, 2 interrupts): the debug line under
##                                      the boss HP bar reads "né: 3 | ngắt: 2 | giả: 15%" (with boss_brain.json numbers)
##   godot --path . -- --demo=cooldown --grid=6x6   "grid66_pace": the board-scaled step cooldown on a 6x6 half right
##                                      after a step (0.45 * (2/5)^0.75 = ~0.23 s with combat.json numbers): the ring is
##                                      visibly shorter than on 3x3 (0.45 s). Not a separate mode: the cooldown demo
##                                      takes the --grid override like every demo (verified headless)
##   godot --path . -- --demo=row_warn   Story 014: a RowBurnerTrait built by hand (TraitRegistry.create, setup with
##                                      CombatView.make_trait_ctx(), TraitHost.debug_add_trait) and ticked until it
##                                      announces the player's row with ~0.7 s of warning left: blinking amber
##                                      outline, shrinking top bar, "SẮP CHÁY" tag; the player stands in that row
##   godot --path . -- --demo=row_burning  as row_warn, ticked past the warning: the row is on fire through
##                                      StatusEffects.ignite (existing burn look), 1.0 s of burning elapsed
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
##   Story 024 piece demos (the player has a piece bag):
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
##   Story 025 boss piece demos (the boss casts puzzle pieces on the player's half and is rooted while it swings):
##   godot --path . -- --demo=boss_placing   the boss mid-swing with a 2-piece JOIN (l3 + bar2) telegraphed on the player's half;
##                                           its hand row shows the third piece, two field pieces lie on its half
##   godot --path . -- --demo=boss_ring_normal  the boss just stepped and is NOT swinging: the normal red cooldown arc, part spent
##   godot --path . -- --demo=boss_rooted    the boss swinging one piece: the ring is the solid steel-blue LOCKED ring
##   godot --path . -- --demo=boss_counter   the boss's swing running, the player casts a piece over the boss through the real path:
##                                           the player's swing resolves first: HIT "-N" on the boss and NGAT on the boss's cast
##   godot --path . -- --demo=boss_rotten    the boss's rotten_thrower (the real trait path) just threw a rotten piece onto the player's half
##   Story 027 zone demos (StatusEffects.apply_seal / apply_thorns called directly with the combat.json "zones" numbers,
##   then ZONE_DEMO_ELAPSED_RATIO of each zone's time ticked through StatusEffects.tick so the time bars show draining):
##   godot --path . -- --demo=seal_on_boss   the boss moved to the far top corner of its half, every neighbour of it
##                                           (8-neighbourhood) sealed except ONE orthogonal exit, and a pending player
##                                           swing (CutActor.begin_swing) over the exit and the boss's cell
##   godot --path . -- --demo=thorns_on_boss thorns on every orthogonal neighbour of the boss (boss half)
##   godot --path . -- --demo=boss_through_thorns  thorns on the boss's divider-side neighbour (and the cell beside it),
##                                           a player swing on the boss's cell, the boss steps into the thorns through its
##                                           real mover (dodge): thorn_entered fires (damage, Ran +1, entry flash)
##   godot --path . -- --demo=boss_seal      a seal on the player's half (every orthogonal neighbour of the player except
##                                           one exit), with a boss swing (its CutActor) telegraphed over the player and the exit
##   godot --path . -- --demo=trait_seal     the REAL SealCasterTrait: the match's own (a jailer node, e.g. --node=chX/cC/nN
##                                           landing on the ch2 miniboss) or, on any other match, one built through
##                                           TraitRegistry with the jailer's chapters.json params (warning). It is made
##                                           ready at once (ticked past its delay), the boss swings a 3-cell row that ends on
##                                           the player (label off the player), then swing + trait are ticked until seal_cast
##   godot --path . -- --demo=trait_thorns   the REAL ThornFieldTrait (frost_mage's, or built with its chapters.json params):
##                                           the boss swings a 2x2 block (4 cells) beside the player; the trait lays thorns
##                                           through BossController's swing_started -> TraitHost path
##   godot --path . -- --demo=reward_zone_cards  the card offer forced to ZONE_REWARD_CARDS (GameFlow's run pending reward +
##                                           run_changed), so RewardView shows the zone keyword lines; use with --lang=vi|en
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
##       --demo=pieces_menu --deck=kiem_khi,chan_phong,hoa_tran shows a 3-card hand with one empty slot.
##   godot --path . -- --drops-seed=N  DEV-ONLY seed of the drops RNG AND the deck shuffle bag (default 7 in
##       every demo): --demo=pieces_menu --drops-seed=1 vs --drops-seed=2 give two different hands.
##   godot --path . -- --debug         DEV overlay: sets CombatView.debug_overlay (Story 016), so the HUD draws its
##       debug text (the boss learning line "né | ngắt | giả"); hidden by default. Works with or without --demo.
##   godot --path . -- --demo=boss_downed   Story 035: GameFlow stages the first offered region's boss node; the boss is hit to 0
##       HP one frame after the intro is skipped: DOWNED (dimmed / kneeling, still drawn), time frozen so the FATE screen never opens
##   godot --path . -- --demo=final_phase2  Story 035: GameFlow stages the final match (an_dai_keeper); one huge hit is clamped at the
##       phase-2 threshold: the phase-2 banner shows, the boss invulnerable, time frozen
## Every demo freezes time (CombatView.freeze_time) so screenshots are deterministic, and
## seeds the drop RNG. No argument = normal game, this node does nothing. State is set in
## _ready, before the first frame (the seed and the grid in _enter_tree, before
## CombatView._ready). Demo cells are derived from the board, never hardcoded.

const DEMO_PREFIX: String = "--demo="
const GRID_PREFIX: String = "--grid="
const BOSS_PREFIX: String = "--boss="
const DEBUG_ARG: String = "--debug"
const DECK_PREFIX: String = "--deck="
const DROPS_SEED_PREFIX: String = "--drops-seed="
const PIECE_PREFIX: String = "--piece="
const ARENA_PREFIX: String = "--arena="
const DEMO_SEED: int = 7
## Uid base of the boss's synthetic hand pieces.
const BOSS_UID_BASE: int = -100
## Seconds the boss piece demos fast-forward the running swing (so the countdown is mid-way).
const SWING_ELAPSED_SEC: float = 0.3
## Story 035 final_phase2: frames waited at most for the HUD to connect TraitHost.phase_changed before the hit.
const HUD_CONNECT_MAX_FRAMES: int = 30
## Story 010 / 014 demos: seconds of burning elapsed in "row_burning" and the learning events fed by
## the "learning" demo.
const BURN_ELAPSED_SEC: float = 1.0
const LEARNING_DODGES: int = 3
const LEARNING_INTERRUPTS: int = 2
## Story 014 / 024 demos: the rotten piece's field freshness (s) and its rot countdown once held (s),
## the warning left (s) when "row_warn" is captured, the step used to walk a trait to its warning, and
## the walk's bound (steps) so a misconfigured trait cannot hang.
const ROTTEN_FIELD_FRESHNESS: float = 5.0
const ROTTEN_HAND_LEFT_SEC: float = 4.2
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
const PIECE_DEMOS: Array[String] = ["boss_placing", "boss_ring_normal", "boss_rooted", "boss_counter", "boss_rotten", "pieces_hand", "placing_hit", "placing_miss", "placing_rotated", "placing_center", "placing_drag", "pieces_menu", "rotten_piece", "join_menu", "join_featured", "join_split", "formation_half", "formation_warn", "formation_complete", "signature_cooldown", "thien_hoa_fire", "thien_hoa_burning", "anh_bo_hit", "seal_on_boss", "thorns_on_boss", "boss_through_thorns", "boss_seal", "trait_seal", "trait_thorns", "reward_zone_cards"]
## Story 025 boss piece demos: the boss's hand (shape ids), how many of them each demo casts, the piece the counter-cast
## uses, the boss's field pieces as [shape id, rotation] with their freshness (s), and the share of the step cooldown
## still left in "boss_ring_normal".
const BOSS_DEMO_HAND: Array[String] = ["l3", "bar2", "square"]
const BOSS_DEMO_CAST_JOIN: int = 2
const BOSS_DEMO_CAST_SINGLE: int = 1
const BOSS_DEMO_FIELD: Array = [["t4", 0], ["bar3", 1]]
const BOSS_DEMO_FIELD_FRESHNESS: Array[float] = [6.0, 3.0]
const BOSS_DEMO_RING_LEFT: float = 0.65
const BOSS_DEMO_COUNTER_PIECE: String = "bar2"
## Story 030 demo: the piece of the "anh_bo_hit" cast (2 cells, <= Anh Bo's small_cells).
const ANH_BO_DEMO_PIECE: String = "bar2"
## Story 029 Phần D demo: share of the enemy cells lit and the cooldown seconds left (dev capture only).
const SIGNATURE_COOLDOWN_DEMO_CHARGE: float = 0.4
const SIGNATURE_COOLDOWN_DEMO_SEC: float = 9.0
## Story 030 "thien_hoa_burning" demo: seconds of burn advanced after the activation (dev capture only).
const THIEN_HOA_BURNING_DEMO_SEC: float = 1.0
## Story 027 zone demos: share of each zone's duration (combat.json "zones") already elapsed when captured.
const ZONE_DEMO_ELAPSED_RATIO: float = 0.3
## Story 027 zone demos: orthogonal steps in preference order (the first one points toward the divider on the boss half).
const ZONE_DEMO_STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT]
## Story 027 trait demos: the chapters.json matches whose trait params are used when the booted match lacks the
## trait, the cards forced into the "reward_zone_cards" offer, and the bound (steps) of the walk to seal_cast.
const CHAPTERS_PATH: String = "res://assets/data/chapters.json"
const SEAL_TRAIT_MATCH: String = "jailer"
const THORN_TRAIT_MATCH: String = "frost_mage"
const ZONE_REWARD_CARDS: Array[String] = ["ket_gioi", "tran_gai", "gai_nguyen"]
## Story 028 join demos: piece 1 and piece 2 of "join_menu" / "join_split" (--piece= overrides piece 1).
const JOIN_PIECE_1: String = "l3"
const JOIN_PIECE_2: String = "bar2"
## Slot of the second piece in the join demos' bag.
const JOIN_SLOT_2: int = 1

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _mode: String = ""


## Story 032 demos: the bag size of relic_bag4 and the relics relic_flash shows (first one flashing).
const RELIC_BAG4_SLOTS: int = 4
const RELIC_FLASH_IDS: Array[String] = ["an_don", "chi_khau", "tui_rong", "huyet_an"]


func _enter_tree() -> void:
	_mode = _parse_mode()
	# Runs before any sibling _ready, so the grid and drops are created with these.
	var arena_id: String = _parse_arena()
	if not arena_id.is_empty():
		_combat().match_params["arena"] = {"shape": arena_id}
	if _mode != "":
		_combat().drops_seed = DEMO_SEED
	if _mode == "boss_downed":
		# Story 035: downing needs a region boss match; forced so the demo also works on a --match= boot.
		_combat().match_params[CombatView.PARAM_BOSS_CAN_DOWN] = true
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
		"relic_bag4":
			# Story 032: the 4-slot bag (tui_rong) as CombatView sizes it; intro skipped for the capture.
			var view := get_node(hold_slots_view_path) as HoldSlotsView
			if view.has_method("set_slot_count_override"):
				view.call("set_slot_count_override", RELIC_BAG4_SLOTS)
			_skip_intro()
		"relic_flash":
			# Story 032: the in-match relic strip with one icon mid-flash (as on a `triggered`).
			_skip_intro()
			for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
				var cut_hud := hud as CutHudView
				if cut_hud.get_relic_strip().get_relics().is_empty():
					cut_hud.debug_show_relics(RELIC_FLASH_IDS)
				cut_hud.call_deferred("_sync_relic_strip")
				cut_hud.get_relic_strip().set_relics(RELIC_FLASH_IDS)
				cut_hud.get_relic_strip().flash(RELIC_FLASH_IDS[0])
		"cooldown":
			if not combat.try_step_player(Vector2i.RIGHT):
				push_warning("DemoArgs: demo cooldown step failed")
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
		"seal_on_boss", "thorns_on_boss", "boss_through_thorns", "boss_seal":
			_zone_demo(combat, grid)
		"trait_seal":
			_trait_seal_demo(combat, grid)
		"trait_thorns":
			_trait_thorns_demo(combat, grid)
		"reward_zone_cards":
			_force_reward_offer.call_deferred()
		"boss_downed", "final_phase2":
			_final_boss_demo.call_deferred()
		"boss_placing", "boss_ring_normal", "boss_rooted", "boss_counter", "boss_rotten":
			_boss_piece_demo(combat, grid)
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


# Story 025 boss piece demos. The boss hand holds BOSS_DEMO_HAND as pieces; boss_placing casts a 2-piece join through
# the real BossController._do_cut (DEV-ONLY private call) with the player OUTSIDE the cells,
# boss_rooted casts one piece, boss_ring_normal only steps the boss (no cast), boss_counter casts and then runs the
# player's real cast over the boss, boss_rotten runs the real rotten_thrower trait.
func _boss_piece_demo(combat: CombatView, grid: BoardGrid) -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var boss: BossController = combat.get_boss()
	_boss_piece_hand(boss, lib)
	for i: int in BOSS_DEMO_FIELD.size():
		var spec: Array = BOSS_DEMO_FIELD[i]
		var cell: Vector2i = _free_enemy_cell(grid, combat, i)
		boss.get_drops().debug_place_piece(lib.make_piece(str(spec[0]), int(spec[1])), cell, BOSS_DEMO_FIELD_FRESHNESS[i])
	match _mode:
		"boss_placing":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_JOIN)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"boss_rooted":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_SINGLE)
			combat.get_arbiter().tick(SWING_ELAPSED_SEC)
		"boss_ring_normal":
			var step: Vector2i = Vector2i.UP if grid.is_enemy_cell(combat.get_state().enemy_cell + Vector2i.UP) else Vector2i.DOWN
			if not boss.get_mover().try_step(step):
				push_warning("DemoArgs: the boss could not step for demo '%s'" % _mode)
			boss.get_mover().tick(boss.get_mover().get_cooldown_remaining() * (1.0 - BOSS_DEMO_RING_LEFT))
		"boss_counter":
			_boss_piece_cut(combat, grid, BOSS_DEMO_CAST_JOIN)
			_fill_bag(lib, -1)
			var held: FieldPoint = _hold().get_point(0)
			held.piece = lib.make_piece(BOSS_DEMO_COUNTER_PIECE, 0)
			held.label = BOSS_DEMO_COUNTER_PIECE
			if not combat.select_piece(0):
				push_warning("DemoArgs: select_piece failed for demo '%s'" % _mode)
				return
			_aim_hitting(combat, grid, combat.get_state().enemy_cell)
			if not combat.confirm_placement():
				push_warning("DemoArgs: confirm_placement failed for demo '%s'" % _mode)
				return
			if not combat.get_cut_flow().choose(SkillConfig.FALLBACK_SKILL):
				push_warning("DemoArgs: skill not available for demo '%s'" % _mode)
				return
			combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.001)
		"boss_rotten":
			var thrower: RottenThrowerTrait = TraitRegistry.create(RottenThrowerTrait.ID) as RottenThrowerTrait
			if thrower == null:
				push_warning("DemoArgs: TraitRegistry could not create '%s'" % RottenThrowerTrait.ID)
				return
			thrower.setup(combat.make_trait_ctx(), {"first_delay_sec": 0.0, "field_freshness_sec": ROTTEN_FIELD_FRESHNESS}, DEMO_SEED)
			thrower.on_match_start()
			combat.get_trait_host().debug_add_trait(thrower)
			thrower.on_tick(TRAIT_STEP_SEC)
			if thrower.get_throw_count() == 0:
				push_warning("DemoArgs: the rotten thrower did not throw for demo '%s'" % _mode)


# Story 027 zone demos (see the header). Zones go straight through the StatusEffects API with the combat.json
# "zones" numbers; ZONE_DEMO_ELAPSED_RATIO of the duration is then ticked (time is frozen afterwards).
func _zone_demo(combat: CombatView, grid: BoardGrid) -> void:
	var status: StatusEffects = combat.get_status()
	var state: CombatState = combat.get_state()
	var cfg: CombatConfig = combat.get_config()
	var boss: BossController = combat.get_boss()
	var enemy: int = CombatState.Side.ENEMY
	match _mode:
		"seal_on_boss":
			var corner: Vector2i = state.enemy_cell
			for cell: Vector2i in grid.enemy_cells():
				if cell.x > corner.x or (cell.x == corner.x and cell.y < corner.y):
					corner = cell
			if not state.set_enemy_cell(corner):
				push_warning("DemoArgs: could not move the boss to %s" % str(corner))
			var exits: Array[Vector2i] = _zone_neighbours(grid, corner, true, false)
			if exits.is_empty():
				push_warning("DemoArgs: no exit around the boss for demo '%s'" % _mode)
				return
			var seals: Array[Vector2i] = _zone_neighbours(grid, corner, true, true)
			seals.erase(exits[0])
			status.apply_seal(enemy, seals, cfg.seal_sec)
			status.tick(cfg.seal_sec * ZONE_DEMO_ELAPSED_RATIO, state)
			if not combat.get_cut_actor().begin_swing([exits[0], corner] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, true):
				push_warning("DemoArgs: the player swing did not start for demo '%s'" % _mode)
		"thorns_on_boss":
			var around: Array[Vector2i] = _zone_neighbours(grid, state.enemy_cell, true, false)
			status.apply_thorns(enemy, around, cfg.thorn_sec, cfg.thorn_damage, cfg.thorn_fragile_stacks)
			status.tick(cfg.thorn_sec * ZONE_DEMO_ELAPSED_RATIO, state)
		"boss_through_thorns":
			var from: Vector2i = state.enemy_cell
			var around2: Array[Vector2i] = _zone_neighbours(grid, from, true, false)
			if around2.is_empty():
				push_warning("DemoArgs: no cell beside the boss for demo '%s'" % _mode)
				return
			var target: Vector2i = around2[0]
			var thorns: Array[Vector2i] = [target]
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
				if grid.is_enemy_cell(target + step) and thorns.size() < 2:
					thorns.append(target + step)
			status.apply_thorns(enemy, thorns, cfg.thorn_sec, cfg.thorn_damage, cfg.thorn_fragile_stacks)
			# First tick only records where each unit stands (StatusEffects._check_thorn_entries).
			status.tick(0.0, state)
			if not combat.get_cut_actor().begin_swing([from] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, true):
				push_warning("DemoArgs: the player swing did not start for demo '%s'" % _mode)
			if not boss.get_mover().try_step(target - from):
				push_warning("DemoArgs: the boss could not step into the thorns for demo '%s'" % _mode)
			status.tick(cfg.thorn_sec * ZONE_DEMO_ELAPSED_RATIO, state)
		"boss_seal":
			var here: Vector2i = state.player_cell
			var around3: Array[Vector2i] = _zone_neighbours(grid, here, false, false)
			if around3.size() < 2:
				push_warning("DemoArgs: not enough cells around the player for demo '%s'" % _mode)
				return
			var exit: Vector2i = around3[around3.size() - 1]
			around3.erase(exit)
			status.apply_seal(CombatState.Side.PLAYER, around3, cfg.seal_sec)
			status.tick(cfg.seal_sec * ZONE_DEMO_ELAPSED_RATIO, state)
			if not boss.get_actor().begin_swing([here, exit] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, false):
				push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)


# Story 027: the real seal_caster on the boss's swing (see the header).
func _trait_seal_demo(combat: CombatView, grid: BoardGrid) -> void:
	var seal: SealCasterTrait = _zone_trait(combat, SealCasterTrait.ID, SEAL_TRAIT_MATCH) as SealCasterTrait
	if seal == null:
		return
	# Ready at once: tick the trait past its delay with no boss swing running (nothing is cast).
	seal.on_tick(seal.get_next_seal_left() + TRAIT_STEP_SEC)
	var here: Vector2i = combat.get_state().player_cell
	var swing: Array[Vector2i] = []
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if grid.is_player_cell(here + step) and grid.is_player_cell(here + step * 2):
			swing = [here + step * 2, here + step, here] as Array[Vector2i]
			break
	# Arenas without a straight 3-cell row through the player (the jailer's U): any 3 connected cells.
	if swing.is_empty():
		for first: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			for second: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var a: Vector2i = here + first
				var b: Vector2i = a + second
				if swing.is_empty() and b != here and grid.is_player_cell(a) and grid.is_player_cell(b):
					swing = [b, a, here] as Array[Vector2i]
	if swing.is_empty():
		push_warning("DemoArgs: no 3 connected cells through the player for demo '%s'" % _mode)
		return
	var actor: CutActor = combat.get_boss().get_actor()
	if not actor.begin_swing(swing, SkillConfig.FALLBACK_SKILL, false):
		push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)
		return
	var steps: int = 0
	while seal.get_seal_count() == 0 and actor.is_swinging() and steps < TRAIT_MAX_STEPS:
		combat.get_arbiter().tick(TRAIT_STEP_SEC)
		seal.on_tick(TRAIT_STEP_SEC)
		steps += 1
	if seal.get_seal_count() == 0:
		push_warning("DemoArgs: seal_caster never cast for demo '%s'" % _mode)
	else:
		print("DemoArgs: seal_cast ", seal.get_last_cells())


# Story 027: the real thorn_field on a 4-cell boss swing beside the player (see the header).
func _trait_thorns_demo(combat: CombatView, grid: BoardGrid) -> void:
	var field: ThornFieldTrait = _zone_trait(combat, ThornFieldTrait.ID, THORN_TRAIT_MATCH) as ThornFieldTrait
	if field == null:
		return
	field.on_tick(field.get_cooldown_left() + TRAIT_STEP_SEC)
	var here: Vector2i = combat.get_state().player_cell
	var best: Array[Vector2i] = []
	var best_dist: float = INF
	for a: Vector2i in grid.player_cells():
		var block: Array[Vector2i] = [a, a + Vector2i.RIGHT, a + Vector2i.DOWN, a + Vector2i.ONE]
		var ok: bool = not block.has(here)
		for c: Vector2i in block:
			ok = ok and grid.is_player_cell(c)
		var dist: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_to(Vector2(here))
		if ok and dist < best_dist:
			best = block
			best_dist = dist
	if best.is_empty():
		push_warning("DemoArgs: no 2x2 block beside the player for demo '%s'" % _mode)
		return
	if not combat.get_boss().get_actor().begin_swing(best, SkillConfig.FALLBACK_SKILL, false):
		push_warning("DemoArgs: the boss swing did not start for demo '%s'" % _mode)
	if field.get_field_count() == 0:
		push_warning("DemoArgs: thorn_field laid nothing for demo '%s'" % _mode)
	else:
		print("DemoArgs: thorns_laid ", field.get_last_cells())


# The match's own trait [param id] when the booted match has it; else one built through TraitRegistry with the
# params chapters.json gives it in match [param match_id], set up on this battle and added to its TraitHost.
func _zone_trait(combat: CombatView, id: String, match_id: String) -> BossTrait:
	var host: TraitHost = combat.get_trait_host()
	var own: BossTrait = host.get_trait(id)
	if own != null:
		print("DemoArgs: %s from the booted match" % id)
		return own
	push_warning("DemoArgs: the match has no '%s', building one with %s's params" % [id, match_id])
	var made: BossTrait = TraitRegistry.create(id)
	if made == null:
		push_warning("DemoArgs: TraitRegistry could not create '%s'" % id)
		return null
	made.setup(combat.make_trait_ctx(), _chapter_trait_params(match_id, id), DEMO_SEED)
	made.on_match_start()
	host.debug_add_trait(made)
	return made


# Params of trait [param id] in chapters.json match [param match_id] ({} when not found).
func _chapter_trait_params(match_id: String, id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS_PATH))
	if not data is Dictionary:
		return {}
	for chapter: Variant in (data as Dictionary).get("chapters", []):
		var matches: Dictionary = (chapter as Dictionary).get("matches", {}) as Dictionary
		if not matches.has(match_id):
			continue
		for t: Variant in (matches[match_id] as Dictionary).get("traits", []):
			if str((t as Dictionary).get("id", "")) == id:
				return (t as Dictionary).get("params", {}) as Dictionary
	return {}


# Story 027 "reward_zone_cards": forces the run's pending offer to ZONE_REWARD_CARDS and tells the views.
func _force_reward_offer() -> void:
	for n: Node in get_tree().root.find_children("*", "GameFlow", true, false):
		var flow: GameFlow = n as GameFlow
		if flow.get_run() == null:
			continue
		flow.get_run().set_pending_reward(ZONE_REWARD_CARDS)
		flow.run_changed.emit()
		return
	push_warning("DemoArgs: no GameFlow with a run for demo '%s'" % _mode)


# Real cells of one half ([param enemy_half]) next to [param cell]: the orthogonal ones in ZONE_DEMO_STEPS order,
# plus the diagonal ones when [param diagonal].
func _zone_neighbours(grid: BoardGrid, cell: Vector2i, enemy_half: bool, diagonal: bool) -> Array[Vector2i]:
	var steps: Array[Vector2i] = ZONE_DEMO_STEPS.duplicate()
	if diagonal:
		steps.append_array([Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)] as Array[Vector2i])
	var out: Array[Vector2i] = []
	for step: Vector2i in steps:
		var c: Vector2i = cell + step
		if grid.is_enemy_cell(c) if enemy_half else grid.is_player_cell(c):
			out.append(c)
	return out


# Fills the boss's piece hand with BOSS_DEMO_HAND (one piece per slot, as many as fit).
func _boss_piece_hand(boss: BossController, lib: PieceLibrary) -> void:
	var hand: HoldSlots = boss.get_hand()
	for i: int in mini(BOSS_DEMO_HAND.size(), hand.get_slot_count()):
		var point := FieldPoint.new()
		point.uid = BOSS_UID_BASE - i
		point.freshness_left = 0.0
		point.piece = lib.make_piece(BOSS_DEMO_HAND[i], 0)
		point.label = point.piece.shape_id
		hand.place(point, i)


# A free boss-half cell for field piece [param index], spread over the half, never the boss's own cell.
func _free_enemy_cell(grid: BoardGrid, combat: CombatView, index: int) -> Vector2i:
	var spread: Array[Vector2i] = _spread_enemy_cells(grid, BOSS_DEMO_FIELD.size() + 2)
	for k: int in spread.size():
		var cell: Vector2i = spread[(k + index * 2 + 1) % spread.size()]
		if cell != combat.get_state().enemy_cell and combat.get_boss().get_drops().is_cell_free(cell):
			return cell
	return combat.get_state().enemy_cell


# Commits the boss's cast of the first [param use] hand pieces through BossController's real cut path, over player
# cells found by _boss_piece_cells. Warns when no placement exists or the cut did not start.
func _boss_piece_cut(combat: CombatView, grid: BoardGrid, use: int) -> void:
	var boss: BossController = combat.get_boss()
	var pieces: Array[Piece] = []
	var indices: Array[int] = []
	for i: int in use:
		pieces.append(boss.get_hand().get_piece(i))
		indices.append(i)
	var cells: Array[Vector2i] = _boss_piece_cells(grid, pieces, combat.get_state().player_cell)
	if cells.is_empty():
		push_warning("DemoArgs: no boss placement for demo '%s'" % _mode)
		return
	boss.call("_do_cut", {"hand_indices": indices, "skill_id": SkillConfig.FALLBACK_SKILL, "cells": cells})
	if not boss.get_actor().is_swinging():
		push_warning("DemoArgs: the boss cut did not start for demo '%s'" % _mode)
	# On a narrow half the countdown label (centred on the cast's bounding box) would hide the player: move the
	# player to a cell outside that box when one exists.
	if _box_has(cells, combat.get_state().player_cell):
		for cell: Vector2i in grid.player_cells():
			if not _box_has(cells, cell) and combat.get_state().set_player_cell(cell):
				break


# Cells of [param pieces] (1 or 2) on the player's half: one piece anywhere, two joined by an edge without overlap;
# the union never covers [param avoid] (the player's cell). Empty when none fits.
func _boss_piece_cells(grid: BoardGrid, pieces: Array[Piece], avoid: Vector2i) -> Array[Vector2i]:
	# First pass also keeps the player out of the cast's bounding box (the countdown label is centred on it and
	# would hide the player); the second pass only keeps the player's cell uncovered.
	var strict: Array[Vector2i] = _boss_piece_cells_pass(grid, pieces, avoid, true)
	return strict if not strict.is_empty() else _boss_piece_cells_pass(grid, pieces, avoid, false)


func _boss_piece_cells_pass(grid: BoardGrid, pieces: Array[Piece], avoid: Vector2i, keep_box_clear: bool) -> Array[Vector2i]:
	for anchor_a: Vector2i in PiecePlacement.valid_anchors(grid, pieces[0], false):
		var cells_a: Array[Vector2i] = pieces[0].cells_at(anchor_a)
		if cells_a.has(avoid):
			continue
		if pieces.size() == 1:
			if not keep_box_clear or not _box_has(cells_a, avoid):
				return cells_a
			continue
		for anchor_b: Vector2i in PiecePlacement.valid_anchors(grid, pieces[1], false):
			var cells_b: Array[Vector2i] = pieces[1].cells_at(anchor_b)
			var ok: bool = not cells_b.has(avoid)
			var touching: bool = false
			for cell: Vector2i in cells_b:
				ok = ok and not cells_a.has(cell)
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					touching = touching or cells_a.has(cell + step)
			if ok and touching:
				var union: Array[Vector2i] = cells_a.duplicate()
				union.append_array(cells_b)
				if not keep_box_clear or not _box_has(union, avoid):
					return union
	return [] as Array[Vector2i]


# True when [param cell] lies inside the bounding box of [param cells].
func _box_has(cells: Array[Vector2i], cell: Vector2i) -> bool:
	var low: Vector2i = cells[0]
	var high: Vector2i = cells[0]
	for c: Vector2i in cells:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
		high = Vector2i(maxi(high.x, c.x), maxi(high.y, c.y))
	return cell.x >= low.x and cell.x <= high.x and cell.y >= low.y and cell.y <= high.y


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


# Story 024: ends the match intro (walks up the parents to the RunController) so the banner does not cover
# the board; the demo's freeze_time keeps the simulation still. No-op without a controller above.
# Story 035 "boss_downed" / "final_phase2": intro skipped, then one huge hit on the boss: a region boss is downed at
# 0 HP; the phased final boss is clamped at its next threshold and enters phase 2 (banner, invulnerable).
func _final_boss_demo() -> void:
	_skip_intro()
	var combat: CombatView = _combat()
	if _mode == "final_phase2":
		# The HUD connects TraitHost.phase_changed in its own _process: hit only once someone listens, or the
		# phase-2 banner is missed (bounded wait so a HUD-less layout cannot hang).
		for _i: int in HUD_CONNECT_MAX_FRAMES:
			var host: TraitHost = combat.get_trait_host()
			if host != null and not host.phase_changed.get_connections().is_empty():
				break
			await get_tree().process_frame
	combat.get_state().damage(CombatState.Side.ENEMY, 999999.0)
	if _mode == "boss_downed":
		if not combat.is_boss_downed():
			push_warning("DemoArgs: boss_downed: the boss was not downed (not a region boss match?)")
		return
	var phased: bool = false
	for t: BossTrait in combat.get_trait_host().get_traits():
		if t.has_method("get_phase"):
			phased = true
			if int(t.call("get_phase")) < 2:
				t.on_tick(0.0)
	if not phased:
		push_warning("DemoArgs: final_phase2: the booted match has no boss_phases trait (not the final match?)")
		return
	var banners: int = 0
	for hud: Node in get_tree().root.find_children("*", "CutHudView", true, false):
		if float(hud.get("_phase_banner_left")) > 0.0:
			banners += 1
	if banners == 0:
		push_warning("DemoArgs: final_phase2: no HUD showed the phase banner")
	else:
		print("DemoArgs: final_phase2: phase banner shown on %d HUD(s)" % banners)


func _skip_intro() -> void:
	var node: Node = get_parent()
	while node != null and not node is RunController:
		node = node.get_parent()
	var controller: RunController = node as RunController
	if controller != null and controller.get_state().get_phase() == RunState.Phase.INTRO:
		controller.call("_begin_playing")


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
