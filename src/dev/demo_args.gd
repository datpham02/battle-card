class_name DemoArgs
extends Node
## DEV-ONLY capture hook: puts the screen into a deterministic state for screenshots.
## Godot user args go after "--":
##   godot --path . -- --demo=empty      belt flowing, all slots empty
##   godot --path . -- --demo=holding    two slots filled
##   godot --path . -- --demo=full       every slot filled
##   godot --path . -- --demo=dragging   slot 0 filled, a belt card mid-drag over slot 1
##   godot --path . -- --demo=playing    slots 1-3 filled, slot 0's Dash Strike just played:
##                                       enemy HP reduced, recovery lock active (frozen at 100%)
##   godot --path . -- --demo=shielded   slots 1-3 filled, slot 0's Guard just played: player armor
##                                       shown, recovery lock active (frozen)
##   godot --path . -- --demo=enemy_dead enemy at 0 HP shown dead, all slots filled, no lock
##   godot --path . -- --demo=telegraph  enemy mid-countdown (2.0 s left, frozen): warning icon, red
##                                       stripe and countdown ring over lane row 1 (middle); player in row 0 (top)
##   godot --path . -- --demo=hit        armored player (10) in the target lane was just hit for 15:
##                                       armor 0, HP 95, HIT feedback (frozen)
##   godot --path . -- --demo=miss       player sidestepped to lane 0 (Sidestep played, recovery shown),
##                                       the attack on lane 1 just missed: MISS feedback (frozen)
##   godot --path . -- --demo=defeat     player at 0 HP, DEFEAT shown
##   godot --path . -- --demo=victory    enemy at 0 HP, VICTORY shown
## Telegraph/hit/miss/defeat/victory run the real enemy logic with injected ticks and set
## freeze_recovery (time stops: recovery, enemy and feedback).
## No argument = normal game, this node does nothing. Belt RNG is seeded when a demo is
## active so the card sequence is repeatable. State is set in _ready, before the first frame.

const DEMO_PREFIX: String = "--demo="
const DEMO_SEED: int = 7

@export var conveyor_view_path: NodePath = NodePath("../ConveyorView")
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")
@export var drag_controller_path: NodePath = NodePath("../CardDragController")

var _mode: String = ""


func _enter_tree() -> void:
	_mode = _parse_mode()
	if _mode != "":
		# Runs before any sibling _ready, so the belt is created with this seed.
		(get_node(conveyor_view_path) as ConveyorView).rng_seed = DEMO_SEED


func _ready() -> void:
	if _mode == "":
		return
	match _mode:
		"empty":
			pass
		"holding":
			_fill_slots(2)
		"full":
			_fill_slots(_slots_view().get_slots().get_slot_count())
		"dragging":
			_fill_slots(1)
			_start_demo_drag()
		"playing":
			_play_demo("dash_strike")
		"shielded":
			_play_demo("guard")
		"enemy_dead":
			_fill_slots(_slots_view().get_slots().get_slot_count())
			var state: CombatState = _combat().get_player().get_state()
			state.damage_enemy(state.enemy_max_hp)
		"telegraph":
			_start_frozen_enemy_demo(0)
			_combat().get_enemy().tick(_pattern().initial_pause_sec + 1.0)
		"hit":
			_start_frozen_enemy_demo(1)
			_combat().get_player().get_state().add_armor(10.0)
			_tick_to_resolution()
		"miss":
			_start_frozen_enemy_demo(1)
			_fill_slots(_slots_view().get_slots().get_slot_count())
			_slots_view().get_slots().get_card(0).type_id = "sidestep"
			var controller: CardDragController = get_node(drag_controller_path) as CardDragController
			if not controller.play_slot_card(0, 0):
				push_warning("DemoArgs: demo sidestep failed")
			_tick_to_resolution()
		"defeat":
			_start_frozen_enemy_demo(1)
			var state: CombatState = _combat().get_player().get_state()
			state.damage_player(state.player_max_hp)
		"victory":
			_start_frozen_enemy_demo(1)
			var state: CombatState = _combat().get_player().get_state()
			state.damage_enemy(state.enemy_max_hp)
		_:
			push_warning("DemoArgs: unknown demo mode '%s'" % _mode)


func _parse_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEMO_PREFIX):
			return arg.substr(DEMO_PREFIX.length())
	return ""


func _slots_view() -> HoldSlotsView:
	return get_node(hold_slots_view_path) as HoldSlotsView


func _combat() -> CombatView:
	return get_node(combat_view_path) as CombatView


func _pattern() -> EnemyPatternConfig:
	return _combat().get_enemy().get_config()


# Freezes time and puts the player in [param lane]; slots are filled for context.
func _start_frozen_enemy_demo(lane: int) -> void:
	_combat().freeze_recovery = true
	_combat().get_player().get_state().set_player_lane(lane)
	if _mode != "miss":
		_fill_slots(_slots_view().get_slots().get_slot_count())


# Ticks through the first telegraph and its resolution (no extra time left over).
func _tick_to_resolution() -> void:
	var enemy: EnemyLogic = _combat().get_enemy()
	enemy.tick(_pattern().initial_pause_sec)
	enemy.tick(_pattern().attacks[0].telegraph_sec)


# Fills every slot, then plays slot 0 (forced to [param type_id]) through the real play path.
# Recovery is frozen so the lock stays visible however late the screenshot is taken.
func _play_demo(type_id: String) -> void:
	_fill_slots(_slots_view().get_slots().get_slot_count())
	_slots_view().get_slots().get_card(0).type_id = type_id
	_combat().freeze_recovery = true
	var controller: CardDragController = get_node(drag_controller_path) as CardDragController
	if not controller.play_slot_card(0):
		push_warning("DemoArgs: demo play failed")


# Fills the first [param count] slots with synthetic cards (negative uids never clash with the belt).
func _fill_slots(count: int) -> void:
	var conveyor: ConveyorView = get_node(conveyor_view_path) as ConveyorView
	var type_ids: PackedStringArray = conveyor.get_card_type_ids()
	for i: int in count:
		var card := ConveyorCard.new()
		card.uid = -1 - i
		card.type_id = type_ids[i % type_ids.size()]
		_slots_view().put_card(card, conveyor.make_card_node(card), i)


# Drags the middle belt card to hover over slot 1.
func _start_demo_drag() -> void:
	var conveyor: ConveyorView = get_node(conveyor_view_path) as ConveyorView
	var uids: Array[int] = conveyor.get_card_uids()
	if uids.is_empty():
		push_warning("DemoArgs: no belt card to drag")
		return
	var uid: int = uids[int(uids.size() * 0.5)]
	var node: Control = conveyor.get_card_node(uid)
	var target: Vector2 = _slots_view().get_slot_rect(1).get_center()
	var lift: float = _slots_view().get_config().drag_lift_px
	# Pointer at the card centre; the card centre ends up over slot 1 after the lift.
	var pointer: Vector2 = target + Vector2(0.0, lift)
	var controller: CardDragController = get_node(drag_controller_path) as CardDragController
	# start_drag keeps the grab offset relative to the card, so grab its centre.
	var grab_point: Vector2 = node.global_position + node.size * 0.5
	if controller.start_drag(uid, grab_point):
		controller.update_drag(pointer)
