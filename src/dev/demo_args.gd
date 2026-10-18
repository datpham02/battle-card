class_name DemoArgs
extends Node
## DEV-ONLY capture hook: puts the screen into a deterministic state for screenshots.
## Godot user args go after "--":
##   godot --path . -- --demo=empty        belt flowing, all slots empty
##   godot --path . -- --demo=holding      two slots filled
##   godot --path . -- --demo=full         every slot filled
##   godot --path . -- --demo=dragging     slot 0 filled, a belt card mid-drag over slot 1
##   godot --path . -- --demo=board        empty board, player and boss on their start cells from
##                                         combat_cards.json ((1,1) and (3,1) in this story), no cards
##   godot --path . -- --demo=step         player just stepped (1,1) -> (1,0): recovery lock visible
##   godot --path . -- --demo=shape_front  Strike held (pressed) in slot 0, player at (2,1): boss cell
##                                         (3,1) tinted red (would hit)
##   godot --path . -- --demo=shape_row    Cannon held: whole row ahead tinted, boss cell tinted red
##   godot --path . -- --demo=shape_wide   Wide Slash held, player at (2,1): column 3, all rows tinted,
##                                         boss cell red
##   godot --path . -- --demo=hit          Cannon just played: boss cell HIT feedback, boss HP 90,
##                                         recovery lock visible
##   godot --path . -- --demo=playing      slot 0's Cannon just played via the real play path
##   godot --path . -- --demo=shielded     slot 0's Guard just played: armor shown, lock visible
##   godot --path . -- --demo=enemy_dead   boss at 0 HP shown dead, all slots filled, no lock
##   godot --path . -- --demo=defeat       player at 0 HP, DEFEAT shown
##   godot --path . -- --demo=victory      boss at 0 HP, VICTORY shown
## Board/step/shape/hit/defeat/victory set freeze_recovery (time stops: recovery and feedback).
## Shape demos press slot 0 through the real controller path (no release) and then switch
## the controller's input off, so the real OS cursor cannot turn the frozen press into a drag.
## Forced card types are set before the card node is built, so label and colour match.
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
		"board":
			_combat().freeze_recovery = true
		"step":
			_combat().freeze_recovery = true
			_fill_slots(_slots_view().get_slots().get_slot_count(), {0: "step"})
			if not _controller().play_slot_card(0, Vector2i(1, 0)):
				push_warning("DemoArgs: demo step failed")
		"shape_front":
			_shape_demo("strike", Vector2i(2, 1))
		"shape_row":
			_shape_demo("cannon", Vector2i(1, 1))
		"shape_wide":
			_shape_demo("wide_slash", Vector2i(2, 1))
		"hit":
			_combat().freeze_recovery = true
			_fill_slots(_slots_view().get_slots().get_slot_count(), {0: "cannon"})
			if not _controller().play_slot_card(0):
				push_warning("DemoArgs: demo hit failed")
		"playing":
			_play_demo("cannon")
		"shielded":
			_play_demo("guard")
		"enemy_dead":
			_fill_slots(_slots_view().get_slots().get_slot_count())
			var state: CombatState = _combat().get_player().get_state()
			state.damage_enemy(state.enemy_max_hp)
		"defeat":
			_combat().freeze_recovery = true
			_fill_slots(_slots_view().get_slots().get_slot_count())
			var state: CombatState = _combat().get_player().get_state()
			state.damage_player(state.player_max_hp)
		"victory":
			_combat().freeze_recovery = true
			_fill_slots(_slots_view().get_slots().get_slot_count())
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


func _controller() -> CardDragController:
	return get_node(drag_controller_path) as CardDragController


# Player on [param cell], all slots filled, slot 0 built as [param type_id] and pressed at
# its slot centre (not released, no motion) so the card stays on its slot and the shape
# preview shows. Time frozen; controller input disabled so the OS cursor cannot move it.
func _shape_demo(type_id: String, cell: Vector2i) -> void:
	_combat().freeze_recovery = true
	_combat().get_player().get_state().set_player_cell(cell)
	_fill_slots(_slots_view().get_slots().get_slot_count(), {0: type_id})
	var pointer: Vector2 = _slots_view().get_slot_rect(0).get_center()
	if not _controller().start_slot_drag(0, pointer):
		push_warning("DemoArgs: demo press failed")
	_controller().set_process_unhandled_input(false)


# Fills every slot (slot 0 as [param type_id]), then plays slot 0 through the real play path.
# Recovery is frozen so the lock stays visible however late the screenshot is taken.
func _play_demo(type_id: String) -> void:
	_fill_slots(_slots_view().get_slots().get_slot_count(), {0: type_id})
	_combat().freeze_recovery = true
	if not _controller().play_slot_card(0):
		push_warning("DemoArgs: demo play failed")


# Fills the first [param count] slots with synthetic cards (negative uids never clash with
# the belt). [param overrides] maps slot index -> type id, applied before the node is built
# so label and colour match the type.
func _fill_slots(count: int, overrides: Dictionary = {}) -> void:
	var conveyor: ConveyorView = get_node(conveyor_view_path) as ConveyorView
	var type_ids: PackedStringArray = conveyor.get_card_type_ids()
	for i: int in count:
		var card := ConveyorCard.new()
		card.uid = -1 - i
		card.type_id = str(overrides.get(i, type_ids[i % type_ids.size()]))
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
	# start_drag keeps the grab offset relative to the card, so grab its centre.
	var grab_point: Vector2 = node.global_position + node.size * 0.5
	if _controller().start_drag(uid, grab_point):
		_controller().update_drag(pointer)
