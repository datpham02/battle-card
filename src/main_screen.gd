class_name MainScreen
extends Node2D
## Root of the landscape screen: draws the background and, while a floor is being played, the
## arena placeholder behind the child views. Outside a floor (GameFlow TITLE and
## CHAPTER_SELECT, Stories 015/016/019) only the background is drawn.

const BG_COLOR: Color = Color(0.96, 0.9, 0.78)
const ARENA_COLOR: Color = Color(0.85, 0.78, 0.64)
const ARENA_OUTLINE: Color = Color(0.6, 0.52, 0.4)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	var flow := get_node_or_null("GameFlow") as GameFlow
	if flow != null:
		flow.phase_changed.connect(func(_phase: int) -> void: queue_redraw())


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	var flow := get_node_or_null("GameFlow") as GameFlow
	if flow != null and flow.get_phase() != GameFlow.Phase.IN_FLOOR:
		return
	var arena: Rect2 = ScreenLayout.arena_rect(size)
	draw_rect(arena, ARENA_COLOR)
	draw_rect(arena, ARENA_OUTLINE, false, 3.0)
