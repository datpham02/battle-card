extends SceneTree
## 2026-11-14 UI style pass: a before/after mockup sheet for the two HUD pieces the user called "modern border"
## — the battle HP plate (CombatView._draw_player_panel) and the reward / shop shape tile
## (RewardView.draw_shape_tile). Nothing in the game is changed: this tool paints the current look and the
## proposed one side by side with the project's own painters (HudSkin, UiButtons plates, PixelFrame), so the
## user can judge the style before any view is edited.
## Run: godot --windowed --resolution 1280x720 --audio-driver Dummy --path . -s res://tools/qa/ui_style_mockup.gd -- --out=<png>

const WAIT_FRAMES: int = 12

var _frames: int = 0
var _out: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	var sheet := Sheet.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sheet)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WAIT_FRAMES:
		return false
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(_out)
	print("saved %s (%dx%d) err=%d" % [_out, img.get_width(), img.get_height(), err])
	quit(0 if err == OK else 1)
	return false


class Sheet:
	extends Control

	const BG: Color = Color("12151A")
	const LABEL: Color = Color("B8B0A0")
	const PANEL_SIZE: Vector2 = Vector2(260.0, 42.0)
	const TILE_SIZE: Vector2 = Vector2(300.0, 150.0)

	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vp), BG)
		_caption(Vector2(24.0, 28.0), "A. HP plate - NOW (1 px border)")
		_hp_now(Rect2(Vector2(24.0, 44.0), PANEL_SIZE))
		_caption(Vector2(24.0, 136.0), "B. stone plate, same 42 px box")
		_hp_plate(Rect2(Vector2(24.0, 152.0), PANEL_SIZE), 1)
		_caption(Vector2(24.0, 244.0), "C. stone plate x2, 60 px box (chunkier)")
		_hp_plate(Rect2(Vector2(24.0, 260.0), Vector2(PANEL_SIZE.x, 60.0)), 2)
		_caption(Vector2(24.0, 368.0), "D. sunken slab, no gold rim")
		_hp_slab(Rect2(Vector2(24.0, 384.0), PANEL_SIZE))

		_caption(Vector2(360.0, 28.0), "E. shape tile - NOW (idle / selected)")
		_tile_now(Rect2(Vector2(360.0, 44.0), TILE_SIZE), false)
		_tile_now(Rect2(Vector2(690.0, 44.0), TILE_SIZE), true)
		_caption(Vector2(360.0, 232.0), "F. stone plate, selected = gold ring (idle / selected)")
		_tile_plate(Rect2(Vector2(360.0, 256.0), TILE_SIZE), false, false)
		_tile_plate(Rect2(Vector2(690.0, 256.0), TILE_SIZE), true, false)
		_caption(Vector2(360.0, 440.0), "G. stone plate, selected = whole plate turns gold")
		_tile_plate(Rect2(Vector2(360.0, 464.0), TILE_SIZE), false, true)
		_tile_plate(Rect2(Vector2(690.0, 464.0), TILE_SIZE), true, true)

	func _caption(pos: Vector2, text: String) -> void:
		HudSkin.text(self, pos, text, 16, LABEL)

	# --- HP plate ---------------------------------------------------------

	# A copy of CombatView._draw_player_panel's painting at s = 1 (720p), so the sheet shows the real current look.
	func _hp_now(rect: Rect2) -> void:
		HudSkin.panel(self, rect, [0.0, 0.0, 20.0, 0.0], Color(HudSkin.NIGHT_STONE, 0.92), HudSkin.MIST)
		var bar := Rect2(Vector2(rect.position.x + 12.0, floorf(rect.position.y + 26.0)), Vector2(floorf(rect.size.x - 24.0 - 10.0), 10.0))
		_hp_rows(rect.position.y + 4.0, bar)
		HudSkin.hp_bar(self, bar, 0.96, 0.96, HudSkin.HP_FILL, false)

	# Proposed: the ancient stone plate (UiButtons.PLATES navy, no gems) at art scale [param s]. The plate IS the
	# frame, so the bar is only an ink groove with the fill and its 1 px shine - no second frame inside the first.
	func _hp_plate(rect: Rect2, s: int) -> void:
		PixelFrame.draw_nine_tiled(self, UiButtons.PLATES["navy_up"], rect, UiButtons.PLATE_MARGINS, s)
		var body: Rect2 = UiButtons.body_rect(rect, float(s), false)
		var content: Rect2 = body.grow(-UiButtons.PLATE_INNER_ART * s)
		var bar_h: float = 7.0 * s
		var bar := Rect2(Vector2(content.position.x, floorf(content.end.y - bar_h)), Vector2(floorf(content.size.x), bar_h))
		_hp_rows(content.position.y, bar)
		_groove_bar(bar, 0.96)

	# Proposed variant: no plate - a sunken slab (ink well, Sương outer line, no gold rim), the Slot look of art
	# bible 7.4, for the case where a raised gold plate reads as a button.
	func _hp_slab(rect: Rect2) -> void:
		HudSkin.panel(self, rect, [0.0, 0.0, 16.0, 0.0], Color("14121A"), Color("3A3644"), 4.0)
		HudSkin.panel(self, rect.grow(-3.0), [0.0, 0.0, 13.0, 0.0], Color(HudSkin.NIGHT_STONE, 0.96), Color("55505F"), 2.0)
		var content: Rect2 = rect.grow(-9.0)
		var bar := Rect2(Vector2(content.position.x, floorf(content.end.y - 7.0)), Vector2(floorf(content.size.x), 7.0))
		_hp_rows(content.position.y, bar)
		_groove_bar(bar, 0.96)

	# An HP bar with no frame of its own: ink groove, fill, 1 px lighter top row (PixelFrame.BAR_SHINE).
	func _groove_bar(rect: Rect2, ratio: float) -> void:
		draw_rect(rect, PixelFrame.BAR_GROOVE)
		var w: float = floorf(rect.size.x * clampf(ratio, 0.0, 1.0))
		if w <= 0.0:
			return
		draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), HudSkin.HP_FILL)
		draw_rect(Rect2(rect.position, Vector2(w, 1.0)), HudSkin.HP_FILL.lightened(PixelFrame.BAR_SHINE))

	# Row 1 of every variant: the name left, "192/200" right, over [param bar]'s width, its top at [param top].
	func _hp_rows(top: float, bar: Rect2) -> void:
		var hp_text: String = "192/200"
		var hp_w: float = HudSkin.text_width(hp_text, 18, true)
		var name_y: float = floorf(top + 16.0)
		HudSkin.text(self, Vector2(bar.end.x - hp_w, name_y), hp_text, 18, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		HudSkin.text(self, Vector2(bar.position.x, name_y), "Swordsman", 20, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, maxf(bar.size.x - hp_w - 8.0, 0.0))

	# --- shape tile -------------------------------------------------------

	# A copy of RewardView.draw_shape_tile's frame (HudSkin.card) plus stand-in content.
	func _tile_now(rect: Rect2, selected: bool) -> void:
		HudSkin.card(self, rect, HudSkin.MIST, selected, false)
		_tile_content(rect, selected)

	# Proposed: the ancient plate. [param gold_selected] false = navy plate + a gold selection ring (the ring
	# plate_panel already draws); true = the whole plate turns gold, as a PRIMARY button does.
	func _tile_plate(rect: Rect2, selected: bool, gold_selected: bool) -> void:
		var s: int = 2
		var key: String = "gold_up" if (selected and gold_selected) else "navy_up"
		PixelFrame.draw_nine_tiled(self, UiButtons.PLATES[key], rect, UiButtons.PLATE_MARGINS, s)
		if selected and not gold_selected:
			var out: Rect2 = rect.grow(float(s) * 2.0)
			var c: float = float(s) * 4.0
			var poly: PackedVector2Array = HudSkin.chamfer_points(out, [c, c, c, c])
			poly.append(poly[0])
			draw_polyline(poly, HudSkin.GRID_LIGHT, float(s) * 2.0, false)
		_tile_content(UiButtons.body_rect(rect, float(s), false), selected)

	# Stand-in for the tile's content: the four-cell shape, the name, four rarity diamonds and the "New" tag.
	func _tile_content(rect: Rect2, selected: bool) -> void:
		var pad: float = minf(rect.size.x, rect.size.y) * 0.1
		var inner: Rect2 = rect.grow(-pad)
		var cell: float = 26.0
		var o: Vector2 = Vector2(inner.position.x + 8.0, inner.position.y + 10.0)
		for c: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)]:
			var r := Rect2(o + c * cell, Vector2(cell - 2.0, cell - 2.0))
			draw_rect(r, Color(0.36, 0.58, 0.82))
			draw_rect(r, Color(0.06, 0.07, 0.1, 0.9), false, 2.0)
		HudSkin.text(self, Vector2(inner.end.x - 40.0, inner.position.y + 24.0), "Y", 24, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		var dot_y: float = inner.position.y + 46.0
		for i: int in 4:
			HudSkin.diamond(self, Vector2(inner.end.x - 86.0 + i * 18.0, dot_y), 7.0,
				HudSkin.GRID_LIGHT if i < (2 if selected else 0) else Color(0.49, 0.53, 0.59, 0.45), Color.TRANSPARENT, 0.0)
		HudSkin.text(self, Vector2(inner.end.x - 110.0, inner.position.y + 76.0), "New", 18, Color(0.45, 0.82, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
