class_name MainScreen
extends Node2D
## Root of the landscape battle screen: draws the background and the (empty) arena
## placeholder behind the child views. Story 003 will fill the arena area.

const BG_COLOR: Color = Color(0.96, 0.9, 0.78)
const ARENA_COLOR: Color = Color(0.85, 0.78, 0.64)
const ARENA_OUTLINE: Color = Color(0.6, 0.52, 0.4)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	var arena: Rect2 = ScreenLayout.arena_rect(size)
	draw_rect(arena, ARENA_COLOR)
	draw_rect(arena, ARENA_OUTLINE, false, 3.0)
