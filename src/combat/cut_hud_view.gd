class_name CutHudView
extends Node2D
## Cut UI (Story 008), drawn above the board and the field points, below the d-pad:
## (1) PREVIEW of the current selection on the boss half: covered cells, perimeter dots with
## labels, lines in selection order (closed for 3-4 points), cell count and expected damage;
## (2) CONFIRM button ("Chốt"), dimmed with the swing countdown while a swing runs;
## (3) SKILL MENU panel: countdown bar + one button per skill with its lock reason;
## (4) SWING overlay: covered cells red with the countdown; (5) HIT / MISS marker after a swing.
## It owns no game state: it reads CombatView and calls confirm_selection() / CutFlow.choose().
##
## Input is read in _input (like DPadView) and consumed, so HandInputController never sees a
## press on the confirm button or the menu panel. Dedup: with emulate_mouse_from_touch a touch
## also arrives as a mouse event, and with emulate_touch_from_mouse a click also arrives as a
## touch. Both emulated copies carry device == InputEvent.DEVICE_ID_EMULATION; they are
## consumed on a button but never act, so one physical press = one action.
## All UI strings are constants here (no localization system exists yet at this tier).

const PREVIEW_TINT: Color = Color(1.0, 0.85, 0.2, 0.35)
const PREVIEW_OUTLINE: Color = Color(1.0, 0.85, 0.2, 0.95)
const PREVIEW_LINE: Color = Color(1.0, 1.0, 1.0, 0.95)
const DOT_COLOR: Color = Color(1.0, 0.85, 0.2)
const DOT_OUTLINE: Color = Color(0.15, 0.12, 0.1)
const SWING_TINT: Color = Color(0.95, 0.12, 0.08, 0.5)
const SWING_OUTLINE: Color = Color(0.95, 0.12, 0.08)
const HIT_TINT: Color = Color(0.95, 0.12, 0.08, 0.6)
const HIT_TEXT: Color = Color(0.9, 0.1, 0.05)
const MISS_TINT: Color = Color(0.2, 0.8, 0.3, 0.5)
const MISS_TEXT: Color = Color(0.1, 0.6, 0.2)
const TEXT_DARK: Color = Color(0.15, 0.12, 0.1)
const TEXT_LIGHT: Color = Color(0.95, 0.9, 0.78)
const TEXT_OUTLINE_LIGHT: Color = Color(1.0, 1.0, 1.0, 0.9)
const BUTTON_BACK: Color = Color(0.2, 0.17, 0.15, 0.9)
const BUTTON_READY_BACK: Color = Color(0.25, 0.5, 0.3, 0.95)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PANEL_BACK: Color = Color(0.1, 0.09, 0.08, 0.85)
const BAR_BACK: Color = Color(0.3, 0.27, 0.24, 0.9)
const BAR_FILL: Color = Color(0.95, 0.6, 0.1)
## Alpha multiplier of a locked / dimmed button.
const DIM_ALPHA: float = 0.4
const OUTLINE_WIDTH: float = 4.0
const CELL_OUTLINE_WIDTH: float = 3.0
const LINE_WIDTH: float = 4.0
## Perimeter dot radius and its label offset toward the board centre (shares of cell height).
const DOT_RADIUS_RATIO: float = 0.08
const DOT_LABEL_OFFSET_RATIO: float = 0.24
const DOT_LABEL_WIDTH: float = 60.0
const DOT_LABEL_FONT_SIZE: int = 22
const BIG_FONT_SIZE: int = 44
const FONT_SIZE: int = 26
const SMALL_FONT_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 30
## Hit/miss text size as a share of cell height.
const FEEDBACK_FONT_RATIO: float = 0.4

## Interrupt flash (NGẮT) and the boss-swing label box.
const INTERRUPT_COLOR: Color = Color(1.0, 0.5, 0.0)
const INTERRUPT_TINT: Color = Color(1.0, 0.5, 0.0, 0.55)
const INTERRUPT_X_WIDTH: float = 8.0
const INTERRUPT_X_INSET_RATIO: float = 0.1
const LABEL_BIG_RATIO: float = 0.34
const LABEL_SMALL_RATIO: float = 0.2
const LABEL_PAD: float = 6.0
const LABEL_LINE_SPACING: float = 1.15

const TEXT_BOSS_SWING: String = "BOSS %s %s"
const TEXT_INTERRUPT: String = "NGẮT!"
const TEXT_INTERRUPT_BOSS: String = "boss bị hủy đòn"
const TEXT_INTERRUPT_PLAYER: String = "đòn của bạn bị hủy"
const TEXT_CONFIRM: String = "Chốt"
const TEXT_CELLS: String = "%d ô"
const TEXT_DAMAGE: String = "Sát thương %d"
const TEXT_NEED_CELLS: String = "cần %d ô"
const TEXT_NOT_IMPLEMENTED: String = "chưa có"
const TEXT_COOLDOWN: String = "%.1f s"
const TEXT_READY: String = "sẵn sàng"
const TEXT_SWING: String = "%s  %.1f s"
const TEXT_HIT: String = "HIT"
const TEXT_MISS: String = "MISS"
const TEXT_DAMAGE_NUMBER: String = "-%d"

@export var combat_view_path: NodePath = NodePath("../CombatView")

var _combat: CombatView


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView


func _process(_delta: float) -> void:
	queue_redraw()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if _combat == null or _combat.get_cut_flow() == null:
		return
	var pos: Vector2
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		pos = button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pos = touch.position
	else:
		return
	if _press_at(pos, event.device == InputEvent.DEVICE_ID_EMULATION):
		get_viewport().set_input_as_handled()


# Handles a press at [param pos]; returns true if it landed on this UI (consumed). Emulated
# duplicates are consumed but do nothing.
func _press_at(pos: Vector2, emulated: bool) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var flow: CutFlow = _combat.get_cut_flow()
	if flow.is_menu_open():
		if not ScreenLayout.skill_menu_panel_rect(vp).has_point(pos):
			return false
		if not emulated:
			var order: Array[String] = _combat.get_skill_config().skill_order
			var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
			for i: int in rects.size():
				if rects[i].has_point(pos):
					flow.choose(order[i])
					break
		return true
	if _combat.is_confirm_visible() and ScreenLayout.confirm_button_rect(vp).has_point(pos):
		if not emulated and not _combat.get_cut_actor().is_swinging():
			_combat.confirm_selection()
		return true
	return false


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if _combat == null or _combat.get_cut_flow() == null or _combat.get_state() == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_preview(vp)
	_draw_swing(vp)
	_draw_boss_swing(vp)
	_draw_feedback(vp)
	_draw_boss_feedback(vp)
	_draw_interrupt(vp)
	_draw_confirm(vp)
	_draw_menu(vp)


func _draw_cells(vp: Vector2, cells: Array[Vector2i], tint: Color, outline: Color) -> void:
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, tint)
		draw_rect(rect.grow(-2.0), outline, false, CELL_OUTLINE_WIDTH)


# Centred single-line text; [param size] is the font size.
func _draw_centered(rect: Rect2, text: String, size: int, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y + size * 0.35),
		text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color
	)


func _draw_preview(vp: Vector2) -> void:
	if _combat.get_cut_flow().is_menu_open():
		return
	var labels: Array[String] = _combat.get_cut_selection_labels()
	if labels.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var cells: Array[Vector2i] = CutResolver.resolve_on_board(grid, true, labels)
	_draw_cells(vp, cells, PREVIEW_TINT, PREVIEW_OUTLINE)
	# Perimeter dots on the boss square's edge, lines in selection order.
	var cell_size: Vector2 = ScreenLayout.cell_size(grid, vp)
	var origin: Vector2 = ScreenLayout.board_rect(grid, vp).position + Vector2(cell_size.x * grid.side_cols, 0.0)
	var square_center: Vector2 = origin + Vector2(grid.side_cols, grid.side_rows) * cell_size * 0.5
	var line_points: Array[Vector2] = []
	var dots: Array[Vector2] = []
	var dot_labels: Array[String] = []
	for label: String in labels:
		var p: Vector2 = CutResolver.label_point(label, grid.side_cols, grid.side_rows)
		if p == CutResolver.INVALID_POINT:
			continue
		dots.append(origin + p * cell_size)
		dot_labels.append(label)
		line_points.append(origin + p * cell_size)
	if labels.size() == 1 and not line_points.is_empty():
		var far: Vector2 = CutResolver.label_point(CutResolver.opposite_label(labels[0], grid.side_cols, grid.side_rows), grid.side_cols, grid.side_rows)
		line_points.append(origin + far * cell_size)
	for i: int in line_points.size() - 1:
		draw_line(line_points[i], line_points[i + 1], PREVIEW_LINE, LINE_WIDTH)
	if labels.size() >= 3 and line_points.size() >= 3:
		draw_line(line_points[line_points.size() - 1], line_points[0], PREVIEW_LINE, LINE_WIDTH)
	var radius: float = cell_size.y * DOT_RADIUS_RATIO
	for i: int in dots.size():
		draw_circle(dots[i], radius, DOT_COLOR)
		draw_arc(dots[i], radius, 0.0, TAU, 20, DOT_OUTLINE, 2.0)
		var inward: Vector2 = (square_center - dots[i]).normalized() * cell_size.y * DOT_LABEL_OFFSET_RATIO
		var at: Vector2 = dots[i] + inward
		draw_string(
			ThemeDB.fallback_font, at + Vector2(-DOT_LABEL_WIDTH * 0.5, DOT_LABEL_FONT_SIZE * 0.35),
			dot_labels[i], HORIZONTAL_ALIGNMENT_CENTER, DOT_LABEL_WIDTH, DOT_LABEL_FONT_SIZE, TEXT_DARK
		)
	# Cell count and expected damage (slash numbers) in the left half of the strip.
	var info: Rect2 = ScreenLayout.cut_preview_info_rect(vp)
	var top := Rect2(info.position, Vector2(info.size.x, info.size.y * 0.5))
	var bottom := Rect2(info.position + Vector2(0.0, info.size.y * 0.5), Vector2(info.size.x, info.size.y * 0.35))
	_draw_centered(top, TEXT_CELLS % cells.size(), BIG_FONT_SIZE, TEXT_DARK)
	_draw_centered(bottom, TEXT_DAMAGE % roundi(_combat.get_cut_config().slash_damage(cells.size())), FONT_SIZE, TEXT_DARK)


func _draw_swing(vp: Vector2) -> void:
	var actor: CutActor = _combat.get_cut_actor()
	if not actor.is_swinging():
		return
	_draw_cells(vp, actor.get_cells(), SWING_TINT, SWING_OUTLINE)
	var info: Rect2 = ScreenLayout.cut_swing_info_rect(vp)
	var text: String = TEXT_SWING % [_skill_name(actor.get_skill_id()), actor.get_time_left()]
	_draw_centered(info, text, BIG_FONT_SIZE, SWING_OUTLINE)


# Boss swing on the PLAYER's half: red cells, countdown + labels/skill centred on their bounding box.
func _draw_boss_swing(vp: Vector2) -> void:
	var boss: BossController = _combat.get_boss()
	var actor: CutActor = boss.get_actor()
	if not actor.is_swinging():
		return
	var cells: Array[Vector2i] = actor.get_cells()
	_draw_cells(vp, cells, SWING_TINT, SWING_OUTLINE)
	var last: Dictionary = boss.get_last_cut()
	var labels: Array = last.get("labels", [])
	var joined: String = "+".join(PackedStringArray(labels))
	var line2: String = TEXT_BOSS_SWING % [joined, _skill_name(actor.get_skill_id())]
	_draw_cells_label(vp, cells, ("%.1f s" % actor.get_time_left()), line2, SWING_OUTLINE)


# Boss HIT / MISS on the player's half (same look as the player's feedback).
func _draw_boss_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_boss_feedback())


# NGẮT flash over the victim's cancelled swing cells: orange tint, a big X per cell, text fading out.
func _draw_interrupt(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_interrupt_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cells: Array[Vector2i] = flash["cells"]
	var grid: BoardGrid = _combat.get_grid()
	_draw_cells(vp, cells, Color(INTERRUPT_TINT, INTERRUPT_TINT.a * fade), Color(INTERRUPT_COLOR, fade))
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell).grow(-rect_inset(vp))
		draw_line(rect.position, rect.end, Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
	var boss_victim: bool = int(flash["side"]) == CombatState.Side.ENEMY
	_draw_cells_label(vp, cells, TEXT_INTERRUPT, TEXT_INTERRUPT_BOSS if boss_victim else TEXT_INTERRUPT_PLAYER, INTERRUPT_COLOR, fade)


func rect_inset(vp: Vector2) -> float:
	return ScreenLayout.cell_size(_combat.get_grid(), vp).y * INTERRUPT_X_INSET_RATIO


# Two lines (big, small) on a white backing, centred on the bounding box of [param cells] and
# clamped inside the board, so it never reaches the strip under the arena.
func _draw_cells_label(vp: Vector2, cells: Array[Vector2i], line1: String, line2: String, color: Color, alpha: float = 1.0) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var font: Font = ThemeDB.fallback_font
	var big: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_BIG_RATIO)
	var small: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_SMALL_RATIO)
	var width: float = maxf(font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x, font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x) + LABEL_PAD * 2.0
	var height: float = (big + small) * LABEL_LINE_SPACING + LABEL_PAD * 2.0
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var pos: Vector2 = box.get_center() - Vector2(width, height) * 0.5
	pos.x = clampf(pos.x, board.position.x, maxf(board.end.x - width, board.position.x))
	pos.y = clampf(pos.y, board.position.y, maxf(board.end.y - height, board.position.y))
	var back := Rect2(pos, Vector2(width, height))
	draw_rect(back, Color(TEXT_OUTLINE_LIGHT, TEXT_OUTLINE_LIGHT.a * alpha))
	draw_rect(back, Color(color, alpha), false, CELL_OUTLINE_WIDTH)
	draw_string(font, pos + Vector2(0.0, LABEL_PAD + big * 0.85), line1, HORIZONTAL_ALIGNMENT_CENTER, width, big, Color(color, alpha))
	draw_string(font, pos + Vector2(0.0, LABEL_PAD + big * LABEL_LINE_SPACING + small * 0.85), line2, HORIZONTAL_ALIGNMENT_CENTER, width, small, Color(TEXT_DARK, alpha))


func _draw_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_cut_feedback())


func _draw_feedback_for(vp: Vector2, fb: Dictionary) -> void:
	if fb.is_empty():
		return
	var hit: bool = bool(fb["hit"])
	var cells: Array[Vector2i] = fb["cells"]
	_draw_cells(vp, cells, HIT_TINT if hit else MISS_TINT, HIT_TEXT if hit else MISS_TEXT)
	var grid: BoardGrid = _combat.get_grid()
	var cell_rect: Rect2 = ScreenLayout.cell_rect(grid, vp, fb["cell"])
	var size: int = int(cell_rect.size.y * FEEDBACK_FONT_RATIO)
	var color: Color = HIT_TEXT if hit else MISS_TEXT
	var back := Rect2(cell_rect.position, Vector2(cell_rect.size.x, size * 2.0 if hit else size * 1.3))
	draw_rect(back, TEXT_OUTLINE_LIGHT)
	var line1 := Rect2(back.position, Vector2(back.size.x, size * 1.2))
	_draw_centered(line1, TEXT_HIT if hit else TEXT_MISS, size, color)
	if hit:
		var line2 := Rect2(back.position + Vector2(0.0, size * 0.9), Vector2(back.size.x, size * 1.2))
		_draw_centered(line2, TEXT_DAMAGE_NUMBER % roundi(float(fb["damage"])), size, color)


func _draw_confirm(vp: Vector2) -> void:
	if not _combat.is_confirm_visible():
		return
	var rect: Rect2 = ScreenLayout.confirm_button_rect(vp)
	var actor: CutActor = _combat.get_cut_actor()
	var swinging: bool = actor.is_swinging()
	var alpha: float = DIM_ALPHA if swinging else 1.0
	draw_rect(rect, Color(BUTTON_READY_BACK, BUTTON_READY_BACK.a * alpha))
	draw_rect(rect, Color(BUTTON_OUTLINE, alpha), false, OUTLINE_WIDTH)
	var text: String = TEXT_CONFIRM
	if swinging:
		text = TEXT_COOLDOWN % actor.get_time_left()
	_draw_centered(rect, text, BIG_FONT_SIZE, Color(TEXT_LIGHT, alpha))


func _draw_menu(vp: Vector2) -> void:
	var flow: CutFlow = _combat.get_cut_flow()
	if not flow.is_menu_open():
		return
	var panel: Rect2 = ScreenLayout.skill_menu_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	var bar: Rect2 = ScreenLayout.skill_menu_bar_rect(vp)
	var ratio: float = 0.0 if flow.get_duration() <= 0.0 else flow.get_time_left() / flow.get_duration()
	draw_rect(bar, BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), BAR_FILL)
	draw_rect(bar, BUTTON_OUTLINE, false, 2.0)
	var config: SkillConfig = _combat.get_skill_config()
	var order: Array[String] = config.skill_order
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
	var cell_count: int = flow.get_cells().size()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var id: String = order[i]
		var status: Dictionary = _skill_status(id, cell_count)
		var available: bool = bool(status["available"])
		var alpha: float = 1.0 if available else DIM_ALPHA
		draw_rect(rect, Color(BUTTON_READY_BACK if available else BUTTON_BACK, alpha))
		draw_rect(rect, Color(BUTTON_OUTLINE, alpha), false, OUTLINE_WIDTH)
		var name_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.6))
		var note_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.45))
		_draw_centered(name_rect, _skill_name(id), BUTTON_FONT_SIZE, Color(TEXT_LIGHT, alpha))
		_draw_centered(note_rect, str(status["text"]), SMALL_FONT_SIZE, Color(TEXT_LIGHT, alpha))


# {available, text}: "cần N ô" whenever the cut covers fewer cells than the skill needs (even
# if it is also unimplemented), else "chưa có", else the cooldown seconds, else ready.
func _skill_status(id: String, cell_count: int) -> Dictionary:
	var config: SkillConfig = _combat.get_skill_config()
	var check: Dictionary = SkillAvailability.check(config, _combat.get_skill_cooldowns(), id, cell_count)
	var min_cells: int = int(check["need_cells"])
	var text: String = TEXT_READY
	if cell_count < min_cells:
		text = TEXT_NEED_CELLS % min_cells
	elif str(check["reason"]) == "not_implemented":
		text = TEXT_NOT_IMPLEMENTED
	elif str(check["reason"]) == "cooldown":
		text = TEXT_COOLDOWN % float(check["cooldown_left"])
	return {"available": bool(check["available"]), "text": text}


func _skill_name(id: String) -> String:
	return str(_combat.get_skill_config().get_skill(id).get("display_name", id))
