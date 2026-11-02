class_name BattleUnitView
extends Node2D
## Draws the battle canvas's units pass (UnitLayer + OverlayLayer, [method BattleCanvas.get_unit_viewport]) over the
## art rect at the canvas's integer scale, nearest filtered. Its place in battle.tscn, after FieldDropsView and
## BossDropsView and before HoldSlotsView / CutHudView, puts the units above the field pieces and under the cut HUD,
## so a tall unit's head that rises into the cell behind it covers a piece lying there (2026-11-02).

## Path to the BattleCanvas whose unit viewport this view draws.
@export var canvas_path: NodePath = NodePath("../BattleCanvas")

var _canvas: BattleCanvas = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas = get_node_or_null(canvas_path) as BattleCanvas
	if _canvas == null:
		push_warning("BattleUnitView: no BattleCanvas at %s; the units are not drawn" % canvas_path)
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


## The BattleCanvas this view draws the units of (null when none is found).
func get_battle_canvas() -> BattleCanvas:
	return _canvas


func _draw() -> void:
	if _canvas == null or _canvas.get_unit_viewport() == null:
		return
	draw_texture_rect(_canvas.get_unit_viewport().get_texture(), ScreenLayout.art_rect(get_viewport_rect().size), false)
