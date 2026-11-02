extends Node
## Windowed UI tests drive the game with pushed input events. The real OS cursor resting over the test window adds
## its own mouse events, and one stray real move between a pushed press and its release turns a tap on a bag slot
## into a drag (HandInputController correctly treats any real mouse motion as the same pointer). This node keeps
## itself the LAST child of the root, so its _input runs before every game node, and swallows each mouse event that
## is neither the test's own (marked with TEST_DEVICE) nor Godot's touch-to-mouse emulation.
## Usage: root.add_child(RealMouseGuard.new()) after the game scene is added; set ev.device = RealMouseGuard.TEST_DEVICE
## on every InputEventMouseButton / InputEventMouseMotion the test pushes.

## Device id the tests put on their pushed mouse events (any id the OS never uses for a real mouse).
const TEST_DEVICE: int = 9701

## Real mouse events swallowed so far (a test may print it when diagnosing input).
var swallowed: int = 0


func _ready() -> void:
	get_parent().child_entered_tree.connect(_on_sibling_added)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device != TEST_DEVICE and event.device != InputEvent.DEVICE_ID_EMULATION:
		swallowed += 1
		get_viewport().set_input_as_handled()


func _on_sibling_added(node: Node) -> void:
	if node != self:
		get_parent().move_child.call_deferred(self, -1)
