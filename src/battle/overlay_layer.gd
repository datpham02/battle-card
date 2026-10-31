class_name OverlayLayer
extends Node2D
## Top layer of the battle art canvas (Story 047, art bible 8.6): effects drawn over the units, in
## art px of the 800x360 SubViewport. Story 048 Part B: the overlay one-shots of FloorVfx (layer "overlay",
## each <= 0.35 s): F6 hit_impact on a hit cut's cells where a unit stands, F8 interrupt on interrupted swing cells.
## Redraws only while it has events (and once more when the last one ends, to clear it).
## Implements: Story 047 Part A, Story 048 Part B.

var _floor: FloorLayer = null
## The items drawn last ([] = none); compared by value each frame.
var _drawn: Array[Dictionary] = []
var _redraws: int = 0


## Binds the layer to the battle's FloorLayer (for cell_art_rect and the CombatView). When never called, the
## sibling named "FloorLayer" is used.
func setup(floor: FloorLayer) -> void:
	_floor = floor


## Number of times `_draw` ran.
func get_redraw_count() -> int:
	return _redraws


## The overlay effects to draw now: one `{id, cell, frame}` per running one-shot; [] when unbound or none runs.
func vfx_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null:
		return out
	var vfx: FloorVfx = combat.get_floor_vfx()
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	for ev: Dictionary in vfx.active_events(FloorVfx.LAYER_OVERLAY):
		var frame: int = FloorVfx.frame_for(vfx.entry(str(ev["id"])), float(ev["age"]), reduce)
		if frame >= 0:
			out.append({"id": str(ev["id"]), "cell": ev["cell"], "frame": frame})
	return out


func _process(_delta: float) -> void:
	if _floor == null and get_parent() != null:
		_floor = get_parent().get_node_or_null("FloorLayer") as FloorLayer
	var state: Array[Dictionary] = vfx_state()
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	_redraws += 1
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null:
		return
	_drawn = vfx_state()
	var vfx: FloorVfx = combat.get_floor_vfx()
	for item: Dictionary in _drawn:
		vfx.draw(self, str(item["id"]), FloorVfx.feet_for(_floor.cell_art_rect(item["cell"])), int(item["frame"]))
