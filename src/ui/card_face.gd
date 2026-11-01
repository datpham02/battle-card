class_name CardFace
extends RefCounted
## Card faces in the OSFE layout (user 2026-11-01: "thẻ card đang hơi xấu, hãy tham khảo osfe", then an OSFE
## spell card as the target, then "nhìn như là một cái hình khác đè lên … nhờ pixellab làm khung"): the card
## frame is one PixelLab piece (assets/art/ui/cards/card_frame.png, Pro Flash job a942200e, 6 gen) with the
## gem sockets carved into its corners, so the numbers sit in the frame instead of on stickers:
## - the blue gem (top-left): the cells the card needs ("cần N ô");
## - the name strip under the top edge (Handjet), an upgrade "+N" in gold at its right end;
## - the art window: a square in the effect's colour with the effect icon, or a code-drawn glyph (slash, push);
## - the effect text under it, centred, shrunk until it fits;
## - the red gem (bottom-right): the damage per cell (the gem is dimmed for a card without damage);
## - the foot (bottom-left): the cooldown, or what the screen passes (the shop's price).
## The frame is nine-sliced at the menu's density (PixelFrame), so the corners and gems never stretch. A face
## shorter than [constant TEXT_FACE_PX] (treasure / ink rows, shop relics) has no room for the text: the window
## fills the card and the screen opens the detail panel ([method draw_detail]) on selection instead.
## Cards have no art yet: the window is drawn in code. Pure drawing, no state.

## The PixelLab card frame and its geometry in art px (98x150).
const CARD_FRAME: Texture2D = preload("res://assets/art/ui/cards/card_frame.png")
## Nine-slice margins [left, top, right, bottom]: the corners hold the gem sockets and the name strip ends.
const CARD_MARGINS: Array[int] = [18, 24, 20, 22]
## Centre of the blue gem from the top-left corner, of the red gem from the bottom-right corner; gem half-size.
const COST_GEM_CENTER: Vector2 = Vector2(9.5, 10.0)
const DAMAGE_GEM_FROM_END: Vector2 = Vector2(12.0, 13.0)
const GEM_HALF: float = 6.0
## The name strip: rows 7..16, from x 17 to 14 px before the right edge.
const NAME_STRIP_TOP: float = 7.0
const NAME_STRIP_BOTTOM: float = 16.0
const NAME_STRIP_LEFT: float = 17.0
const NAME_STRIP_RIGHT: float = 14.0
## The inner panel inside the gold line: inset left / right, top, bottom.
const INNER_X: float = 11.0
const INNER_TOP: float = 18.0
const INNER_BOTTOM: float = 12.0
## The foot line (cooldown / price): baseline this far above the bottom edge; it ends before the red gem.
const FOOT_BASELINE: float = 14.0
const FOOT_RIGHT: float = 24.0
## Per-card pictures (PixelLab, 32x32): res://assets/art/cards/<card id>.png; a card without one keeps the
## code-drawn window.
const CARD_ART_PATH: String = "res://assets/art/cards/%s.png"
static var _art_cache: Dictionary = {}
## Card style. "ancient" (default, user 2026-11-01: "vẫn giữ phong cách cổ, chỉ lấy layout", "đừng làm border to
## quá"): the PixelLab ancient card frame drawn in the measured layout (design/references/osfe-card-layout.md) — a
## 1 px bronze border, a dark weathered panel, the gems in the corners, the picture slot at the top. "slim": the same
## layout drawn in code (flat panel, line diamonds). "stone": the first PixelLab frame (thick stone, carved gems).
## DEV user arg `--card-style=ancient|slim|stone` for A/B.
static var style: String = "ancient"
const STYLE_ARG: String = "--card-style="
## The ancient frame (PixelLab Pro Flash 88x128, job 3ac0f855, 6 gen) and its geometry in art px, drawn at the
## menu's density (x2 at 720p = the 176x256 card face).
const ANCIENT_FRAME: Texture2D = preload("res://assets/art/ui/cards/card_frame_ancient.png")
const ANCIENT_COST_CENTER: Vector2 = Vector2(8.5, 9.0)
const ANCIENT_DAMAGE_CENTER: Vector2 = Vector2(77.0, 116.0)
## The picture slot's inside (a 32 px picture shows its centre 28 px there).
const ANCIENT_SLOT: Rect2 = Rect2(29.0, 14.0, 29.0, 30.0)
const ANCIENT_PICTURE_PX: float = 28.0
## Name line: from x 16 to 6 px before the right edge, baseline at y 11.5.
const ANCIENT_NAME_LEFT: float = 16.0
const ANCIENT_NAME_RIGHT: float = 6.0
const ANCIENT_NAME_BASELINE: float = 11.5
const ANCIENT_NAME_FONT_SIZE: int = 13
## Text box under the slot, and the foot line (price) at the bottom-left.
const ANCIENT_TEXT_BOX: Rect2 = Rect2(8.0, 48.0, 72.0, 58.0)
const ANCIENT_FOOT_BASELINE: float = 120.0
const ANCIENT_FOOT_WIDTH: float = 58.0
static var _style_read: bool = false
## Slim style: Tessera's own colours on a layout measured as proportions of the card
## (design/references/osfe-card-layout.md): flat panel with cut corners, a 1 px rarity edge, big diamonds whose
## outer corners the card edge cuts off, the picture square in the upper half, the text under it.
const SLIM_FILL: Color = Color("1F1D2A")
const SLIM_LINES: Dictionary = {
	"common": Color("6F6B88"),
	"rare": Color("5F8FE0"),
	"epic": Color("D8AE52"),
	"curse": Color("9D72CC"),
}
const SLIM_COST_FILL: Color = Color("3C72C4")
const SLIM_COST_LIGHT: Color = Color("5B92E2")
const SLIM_COST_LINE: Color = Color("A9CBFA")
const SLIM_DAMAGE_FILL: Color = Color("B03A55")
const SLIM_DAMAGE_LIGHT: Color = Color("D45470")
const SLIM_DAMAGE_LINE: Color = Color("F6AFC0")
const SLIM_WINDOW_LINE: Color = Color("3A3750")
## Shares of the card width (W) / height (H).
const SLIM_CORNER_CUT_W: float = 0.04
const SLIM_COST_CENTER: Vector2 = Vector2(0.18, 0.12)
const SLIM_COST_HALF_W: float = 0.155
const SLIM_DAMAGE_CENTER: Vector2 = Vector2(0.81, 0.875)
const SLIM_DAMAGE_HALF_W: float = 0.165
## Gap between a diamond's body and its ring, in W.
const SLIM_RING_GAP_W: float = 0.025
const SLIM_NAME_LEFT_W: float = 0.37
const SLIM_NAME_BASELINE_H: float = 0.085
const SLIM_WINDOW_TOP_H: float = 0.175
const SLIM_TEXT_TOP_H: float = 0.5
const SLIM_TEXT_BOTTOM_H: float = 0.84
## One body size on every card (a text shrinks only when it cannot fit at it).
const SLIM_BODY_FONT_SIZE: int = 14
const SLIM_PAD_W: float = 0.07
const SLIM_NAME_FONT_SIZE: int = 17
const SLIM_NUMBER_FONT_SIZE: int = 19
## The art window holds a 32x32 picture at the frame scale plus this border (px).
const ART_PX: float = 32.0
const ART_BORDER_PX: float = 4.0

## Art window colour per card effect (cards.json `effect`); unknown effects use "damage".
const EFFECT_COLORS: Dictionary = {
	"damage": Color("6E7C96"),
	"burn": Color("E0702C"),
	"frost": Color("62AEE8"),
	"fragile": Color("A880D8"),
	"thorns": Color("6CB45E"),
	"pin": Color("C8A452"),
	"push": Color("9AA0AA"),
}
## Icon-sheet glyph per effect ("" = none: a code-drawn glyph, see [method _draw_glyph]).
const EFFECT_ICONS: Dictionary = {"burn": "burn", "frost": "chill", "fragile": "fragile", "pin": "frozen", "thorns": "odd"}
## Frame tint per rarity (multiplies the frame).
const RARITY_TINTS: Dictionary = {
	"common": Color(1.0, 1.0, 1.0),
	"rare": Color(0.82, 0.94, 1.25),
	"epic": Color(1.25, 1.08, 0.75),
	"curse": Color(1.1, 0.8, 1.2),
	"boss": Color(1.25, 0.82, 0.75),
}
const SELECTED_TINT: Color = Color(1.3, 1.22, 0.95)
## The selected face also gets a gold ring outside its frame (the tint alone reads too faintly).
const SELECTED_RING: Color = HudSkin.GRID_LIGHT
const SELECTED_RING_PX: float = 3.0
const PRESSED_TINT: Color = Color(0.75, 0.75, 0.8)
const DIM_TINT: Color = Color(0.55, 0.55, 0.6, 0.7)
## An unused gem (no damage, a relic's sockets) is covered by this.
const GEM_EMPTY: Color = Color("1B1824", 0.7)
const WINDOW_EDGE: Color = Color("0C0B10")
const OUTLINE: Color = HudSkin.TEXT_OUTLINE
const GLYPH_COLOR: Color = Color("F8F8D0")
const NAME_COLOR: Color = Color("F8F8D0")
const TAG_COLOR: Color = Color("F8E080")
const BODY_COLOR: Color = Color("E8E2D0")
const SUB_COLOR: Color = HudSkin.TEXT_DIM
const NUMBER_COLOR: Color = Color("FFFFFF")
const NUMBER_OUTLINE_PX: int = 3
const DETAIL_TITLE_COLOR: Color = Color("F8E080")
const DETAIL_BODY_COLOR: Color = Color("E8E2D0")
const DETAIL_HINT_COLOR: Color = HudSkin.GRID_LIGHT
const DETAIL_BACK: Color = Color("1B1824", 0.97)
## A face at least this tall (px at 720p) prints its effect text; a shorter one leaves it to the detail panel.
const TEXT_FACE_PX: float = 200.0
## Font sizes (nominal, MenuFont scales them).
const NAME_FONT_SIZE: int = 20
const BODY_FONT_SIZE: int = 16
const BODY_MIN_FONT_SIZE: int = 12
const SUB_FONT_SIZE: int = 16
## 2026-11-01 (user: "các con số đang hơi bị to so với khung"): sized to sit inside the gem.
const NUMBER_FONT_SIZE: int = 15
const DETAIL_TITLE_FONT_SIZE: int = 28
const DETAIL_LINE_FONT_SIZE: int = 19
const DETAIL_BODY_FONT_SIZE: int = 19
const DETAIL_BODY_LINES: int = 5
## Detail panel size (shares of the viewport) and its gap to the card.
const DETAIL_WIDTH_RATIO: float = 0.42
const DETAIL_HEIGHT_RATIO: float = 0.25
const DETAIL_GAP_RATIO: float = 0.015
## The panel stays clear of the title band and of the bottom button row.
const DETAIL_TOP_LIMIT_RATIO: float = 0.13
const DETAIL_BOTTOM_LIMIT_RATIO: float = 0.84

const TEXT_COOLDOWN: String = "ui.reward.cooldown"
const TEXT_COOLDOWN_NONE: String = "ui.reward.cooldown_none"
## "Chạm để chọn, chạm lại để lấy": the hint of a card that is taken with a second tap.
const TEXT_TAP_AGAIN: String = "ui.fate.offer_hint"


## Frame tint for [param rarity] in a [param selected] / [param pressed] / [param dim] state.
static func frame_tint(rarity: String, selected: bool, pressed: bool, dim: bool) -> Color:
	if dim:
		return DIM_TINT
	if pressed:
		return PRESSED_TINT
	if selected:
		return SELECTED_TINT
	return RARITY_TINTS.get(rarity, RARITY_TINTS["common"])


## Pure: true when a face at [param rect] on a [param viewport_height] screen prints its effect text (tall
## enough); false for the short rows, whose text goes to the detail panel.
static func shows_text(rect: Rect2, viewport_height: float) -> bool:
	return rect.size.y >= TEXT_FACE_PX * viewport_height / 720.0


## Pure: the whole-number scale of the card frame: the menu's density (2 at 720p) on every face — one card size,
## one border (user 2026-11-01: "viền thẻ đang quá to", "mỗi ảnh một kiểu format thẻ").
static func frame_scale(_rect: Rect2, viewport_height: float) -> float:
	return float(PixelFrame.scale_for(viewport_height))


## [param desc] with the card's cooldown appended ("… (hồi 8 s)"); a card without a cooldown keeps its text.
static func describe_with_cooldown(desc: String, skill: Dictionary) -> String:
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	if cooldown <= 0.0:
		return desc
	return "%s (%s)" % [desc, TranslationServer.translate(TEXT_COOLDOWN) % roundi(cooldown)]


## Pure: the inner panel of a face at [param rect] drawn at frame scale [param s].
static func inner_rect(rect: Rect2, s: float) -> Rect2:
	return Rect2(rect.position.x + INNER_X * s, rect.position.y + INNER_TOP * s, rect.size.x - INNER_X * s * 2.0,
		rect.size.y - (INNER_TOP + INNER_BOTTOM) * s).abs()


## Pure: the art window — a centred square at the top of the inner panel ([param with_text]), or the whole
## inner panel above the foot row ([param with_foot]) on a short face.
static func window_rect(rect: Rect2, s: float, with_text: bool, with_foot: bool) -> Rect2:
	var inner: Rect2 = inner_rect(rect, s)
	var top: float = inner.position.y + 2.0 * s
	if not with_text:
		var bottom: float = rect.end.y - (FOOT_BASELINE + 8.0 if with_foot else INNER_BOTTOM + 2.0) * s
		return Rect2(inner.position.x + 2.0 * s, top, inner.size.x - 4.0 * s, maxf(bottom - top, 1.0)).abs()
	var edge: float = minf(ART_PX * s + ART_BORDER_PX * 2.0, inner.size.x)
	return Rect2(roundf(rect.get_center().x - edge * 0.5), top, edge, edge)


## Draws a skill card face. [param skill] is the resolved card (SkillConfig.resolved), [param title] its shown
## name (with the level suffix), [param tag] the upgrade tag ("" = none), [param desc] the effect text.
## The cooldown ends the effect text ("… (hồi 8 s)"); [param foot] ([text, colour, size]) is an optional line at
## the foot (the shop's price).
static func draw_skill(canvas: CanvasItem, rect: Rect2, skill: Dictionary, title: String, tag: String, desc: String,
		selected: bool = false, pressed: bool = false, dim: bool = false, foot: Array = [], card_id: String = "") -> void:
	_read_style()
	if style == "ancient":
		_draw_skill_ancient(canvas, rect, skill, title, tag, desc, selected, pressed, dim, foot, card_id)
		return
	if style == "slim":
		_draw_skill_slim(canvas, rect, skill, title, tag, desc, selected, pressed, dim, foot, card_id)
		return
	var vp_h: float = canvas.get_viewport_rect().size.y
	var s: float = frame_scale(rect, vp_h)
	var with_text: bool = shows_text(rect, vp_h)
	var alpha: float = 0.55 if dim else 1.0
	_draw_frame(canvas, rect, s, frame_tint(str(skill.get("rarity", "common")), selected, pressed, dim), selected and not dim)
	_draw_name(canvas, rect, s, title, tag, alpha)
	var window: Rect2 = window_rect(rect, s, with_text, not foot.is_empty())
	var effect: String = str(skill.get("effect", "damage"))
	var art: Texture2D = card_art(card_id)
	if art != null:
		canvas.draw_rect(window.grow(2.0), Color(WINDOW_EDGE, alpha))
		var art_size: Vector2 = Vector2(art.get_size()) * s
		canvas.draw_texture_rect(art, Rect2((window.get_center() - art_size * 0.5).round(), art_size), false, Color(1, 1, 1, alpha))
	else:
		_draw_window_art(canvas, window, skill, effect, alpha)
	if with_text:
		_draw_body(canvas, rect, s, window, describe_with_cooldown(desc, skill), alpha, not foot.is_empty())
	_draw_foot(canvas, rect, s, foot, alpha)
	_draw_gem_number(canvas, rect.position + COST_GEM_CENTER * s, s, str(maxi(int(skill.get("min_cells", 1)), 1)), alpha)
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	var damage_center: Vector2 = rect.end - DAMAGE_GEM_FROM_END * s
	if damage > 0:
		_draw_gem_number(canvas, damage_center, s, str(damage), alpha)
	else:
		_cover_gem(canvas, damage_center, s)


# Applies the DEV `--card-style=` user arg once.
static func _read_style() -> void:
	if _style_read:
		return
	_style_read = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(STYLE_ARG) and ["ancient", "slim", "stone"].has(arg.trim_prefix(STYLE_ARG)):
			style = arg.trim_prefix(STYLE_ARG)


# The ancient face (see [member style]): the PixelLab frame at the menu's density; name, picture, text and the
# gem numbers placed on its measured geometry.
static func _draw_skill_ancient(canvas: CanvasItem, rect: Rect2, skill: Dictionary, title: String, tag: String, desc: String,
		selected: bool, pressed: bool, dim: bool, foot: Array, card_id: String) -> void:
	var vp_h: float = canvas.get_viewport_rect().size.y
	var s: float = float(PixelFrame.scale_for(vp_h))
	var alpha: float = 0.55 if dim else 1.0
	var o: Vector2 = rect.position.round()
	canvas.draw_texture_rect(ANCIENT_FRAME, Rect2(o, Vector2(ANCIENT_FRAME.get_size()) * s), false,
		frame_tint(str(skill.get("rarity", "common")), selected, pressed, dim))
	if selected and not dim:
		canvas.draw_rect(Rect2(o, Vector2(ANCIENT_FRAME.get_size()) * s).grow(SELECTED_RING_PX), SELECTED_RING, false, SELECTED_RING_PX)
	# Name (gold with the upgrade level) on the top line, right of the blue gem.
	var text: String = title if tag.is_empty() else title + " " + tag
	var left: float = o.x + ANCIENT_NAME_LEFT * s
	var w: float = maxf(rect.size.x - (ANCIENT_NAME_LEFT + ANCIENT_NAME_RIGHT) * s, 1.0)
	MenuFont.text(canvas, Vector2(left, o.y + ANCIENT_NAME_BASELINE * s), text, MenuFont.fit_size(text, ANCIENT_NAME_FONT_SIZE, w),
		Color(TAG_COLOR if not tag.is_empty() else NAME_COLOR, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
	# The picture in the slot: the centre 28 px of a 32 px picture, or the code-drawn effect window.
	var slot := Rect2(o + ANCIENT_SLOT.position * s, ANCIENT_SLOT.size * s)
	var pic := Rect2((slot.get_center() - Vector2.ONE * ANCIENT_PICTURE_PX * s * 0.5).round(), Vector2.ONE * ANCIENT_PICTURE_PX * s)
	var art: Texture2D = card_art(card_id)
	if art != null:
		var src_edge: float = minf(ANCIENT_PICTURE_PX, minf(art.get_width(), art.get_height()))
		var src := Rect2((Vector2(art.get_size()) - Vector2.ONE * src_edge) * 0.5, Vector2.ONE * src_edge)
		canvas.draw_texture_rect_region(art, pic, src, Color(1, 1, 1, alpha))
	else:
		_draw_window_art(canvas, pic, skill, str(skill.get("effect", "damage")), alpha)
	# Effect text (with the cooldown), one size on every card.
	var box := Rect2(o + ANCIENT_TEXT_BOX.position * s, ANCIENT_TEXT_BOX.size * s)
	_draw_text_box(canvas, box, describe_with_cooldown(desc, skill), alpha, SLIM_BODY_FONT_SIZE)
	if foot.size() >= 2:
		var nominal: int = int(foot[2]) if foot.size() > 2 else SUB_FONT_SIZE
		var fw: float = ANCIENT_FOOT_WIDTH * s
		MenuFont.text(canvas, Vector2(o.x + ANCIENT_TEXT_BOX.position.x * s, o.y + ANCIENT_FOOT_BASELINE * s), str(foot[0]),
			MenuFont.fit_size(str(foot[0]), nominal, fw), Color(foot[1], alpha), HORIZONTAL_ALIGNMENT_LEFT, fw)
	# Numbers on the gems: cells on the blue one, damage on the red one (dimmed without damage).
	_draw_gem_number(canvas, o + ANCIENT_COST_CENTER * s, s, str(maxi(int(skill.get("min_cells", 1)), 1)), alpha)
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	if damage > 0:
		_draw_gem_number(canvas, o + ANCIENT_DAMAGE_CENTER * s, s, str(damage), alpha)
	else:
		_cover_gem(canvas, o + ANCIENT_DAMAGE_CENTER * s, s)


# The slim face (see [member style]): every position is a share of the card, so it holds at any size.
static func _draw_skill_slim(canvas: CanvasItem, rect: Rect2, skill: Dictionary, title: String, tag: String, desc: String,
		selected: bool, pressed: bool, dim: bool, foot: Array, card_id: String) -> void:
	var vp_h: float = canvas.get_viewport_rect().size.y
	var s: float = float(PixelFrame.scale_for(vp_h))
	var alpha: float = 0.55 if dim else 1.0
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	var w: float = r.size.x
	var h: float = r.size.y
	draw_slim_panel(canvas, r, SLIM_LINES.get(str(skill.get("rarity", "common")), SLIM_LINES["common"]), selected and not dim, pressed, alpha)
	# Name on the top line, right of the cost diamond (gold with the upgrade level).
	var text: String = title if tag.is_empty() else title + " " + tag
	var pad: float = roundf(w * SLIM_PAD_W)
	var left: float = r.position.x + roundf(w * SLIM_NAME_LEFT_W)
	var name_w: float = maxf(r.end.x - pad * 0.6 - left, 1.0)
	MenuFont.text(canvas, Vector2(left, r.position.y + roundf(h * SLIM_NAME_BASELINE_H)), text, MenuFont.fit_size(text, SLIM_NAME_FONT_SIZE, name_w),
		Color(TAG_COLOR if not tag.is_empty() else NAME_COLOR, alpha), HORIZONTAL_ALIGNMENT_LEFT, name_w)
	# The picture square: a 32 px picture at the menu's density inside a 1 px cut-corner line.
	var edge: float = ART_PX * s
	var window := Rect2(roundf(r.get_center().x - edge * 0.5), r.position.y + roundf(h * SLIM_WINDOW_TOP_H), edge, edge)
	var art: Texture2D = card_art(card_id)
	if art != null:
		canvas.draw_texture_rect(art, window, false, Color(1, 1, 1, alpha))
	else:
		_draw_window_art(canvas, window, skill, str(skill.get("effect", "damage")), alpha)
	var frame_pts: PackedVector2Array = _cut_rect(window.grow(4.0), 4.0)
	frame_pts.append(frame_pts[0])
	canvas.draw_polyline(frame_pts, Color(SLIM_WINDOW_LINE, alpha), 2.0)
	# Effect text (with the cooldown) between the picture and the damage diamond.
	var box := Rect2(r.position.x + pad, r.position.y + roundf(h * SLIM_TEXT_TOP_H), w - pad * 2.0, 0.0)
	box.size.y = r.position.y + roundf(h * SLIM_TEXT_BOTTOM_H) - box.position.y
	box.size.y -= roundf(h * 0.03) if not foot.is_empty() else 0.0
	_draw_text_box(canvas, box, describe_with_cooldown(desc, skill), alpha, SLIM_BODY_FONT_SIZE)
	if foot.size() >= 2:
		var nominal: int = int(foot[2]) if foot.size() > 2 else SUB_FONT_SIZE
		var fw: float = w * 0.55
		MenuFont.text(canvas, Vector2(r.position.x + pad, r.end.y - roundf(h * 0.05)), str(foot[0]), MenuFont.fit_size(str(foot[0]), nominal, fw),
			Color(foot[1], alpha), HORIZONTAL_ALIGNMENT_LEFT, fw)
	# Diamonds, clipped by the card edge: cost (cells) top-left, damage bottom-right (none without damage).
	var gap: float = maxf(roundf(w * SLIM_RING_GAP_W), 3.0)
	_draw_slim_diamond(canvas, r, r.position + Vector2(w, h) * SLIM_COST_CENTER, w * SLIM_COST_HALF_W, gap, SLIM_COST_FILL, SLIM_COST_LIGHT,
		SLIM_COST_LINE, str(maxi(int(skill.get("min_cells", 1)), 1)), alpha)
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	if damage > 0:
		_draw_slim_diamond(canvas, r, r.position + Vector2(w, h) * SLIM_DAMAGE_CENTER, w * SLIM_DAMAGE_HALF_W, gap, SLIM_DAMAGE_FILL, SLIM_DAMAGE_LIGHT,
			SLIM_DAMAGE_LINE, str(damage), alpha)


# The corners of [param r] with each corner cut by [param cut] px (an octagon), clockwise from the top-left.
static func _cut_rect(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		r.end - Vector2(0, cut), r.end - Vector2(cut, 0), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), r.position + Vector2(0, cut)])


# Sutherland-Hodgman: [param poly] (convex) clipped to [param r].
static func _clip_to_rect(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var out: PackedVector2Array = poly
	for side: int in 4:
		var src: PackedVector2Array = out
		out = PackedVector2Array()
		if src.is_empty():
			break
		for i: int in src.size():
			var a: Vector2 = src[i]
			var b: Vector2 = src[(i + 1) % src.size()]
			var a_in: bool = _inside(a, r, side)
			var b_in: bool = _inside(b, r, side)
			if a_in:
				out.append(a)
			if a_in != b_in:
				out.append(_cross(a, b, r, side))
	return out


static func _inside(p: Vector2, r: Rect2, side: int) -> bool:
	match side:
		0:
			return p.x >= r.position.x
		1:
			return p.x <= r.end.x
		2:
			return p.y >= r.position.y
	return p.y <= r.end.y


static func _cross(a: Vector2, b: Vector2, r: Rect2, side: int) -> Vector2:
	var t: float = 0.0
	match side:
		0:
			t = (r.position.x - a.x) / (b.x - a.x)
		1:
			t = (r.end.x - a.x) / (b.x - a.x)
		2:
			t = (r.position.y - a.y) / (b.y - a.y)
		_:
			t = (r.end.y - a.y) / (b.y - a.y)
	return a.lerp(b, t)


# A diamond of half-diagonal [param half] centred on [param center], clipped by the card [param card]: [param fill]
# body with a [param light] upper facet, a [param line] ring [param gap] px outside it, [param text] at the centre
# of the part that shows.
static func _draw_slim_diamond(canvas: CanvasItem, card: Rect2, center: Vector2, half: float, gap: float, fill: Color, light: Color,
		line: Color, text: String, alpha: float) -> void:
	var c: Vector2 = center.round()
	var h: float = roundf(half)
	var o: float = h + gap
	var ring_pts: PackedVector2Array = _clip_to_rect(PackedVector2Array([c + Vector2(0, -o), c + Vector2(o, 0), c + Vector2(0, o), c + Vector2(-o, 0)]), card)
	var body: PackedVector2Array = _clip_to_rect(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), card)
	var facet: PackedVector2Array = _clip_to_rect(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c, c + Vector2(-h, 0)]), card)
	if ring_pts.size() >= 3:
		canvas.draw_colored_polygon(ring_pts, Color(SLIM_FILL, alpha))
		var ring_line := PackedVector2Array(ring_pts)
		ring_line.append(ring_pts[0])
		canvas.draw_polyline(ring_line, Color(line, alpha), 2.0)
	if body.size() >= 3:
		canvas.draw_colored_polygon(body, Color(fill, alpha))
	if facet.size() >= 3:
		canvas.draw_colored_polygon(facet, Color(light, alpha))
	if body.size() < 3:
		return
	var mid := Vector2.ZERO
	for pt: Vector2 in body:
		mid += pt
	mid /= body.size()
	var font: Font = _font()
	var size: int = MenuFont.size(MenuFont.fit_size(text, SLIM_NUMBER_FONT_SIZE, h * 1.1))
	var pos := Vector2(roundf(mid.x - h), roundf(mid.y + size * 0.33))
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, size, 4, Color(OUTLINE, alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, size, Color(NUMBER_COLOR, alpha))


## The slim card panel at [param rect]: flat fill, cut corners, a 1 px [param line] edge (2 px gold when
## [param selected]); [param pressed] darkens the fill. Shared by the card faces, relic tiles and card-row slots.
static func draw_slim_panel(canvas: CanvasItem, rect: Rect2, line: Color, selected: bool, pressed: bool, alpha: float = 1.0) -> void:
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	var shape: PackedVector2Array = _cut_rect(r, roundf(r.size.x * SLIM_CORNER_CUT_W))
	canvas.draw_colored_polygon(shape, Color(SLIM_FILL.darkened(0.25) if pressed else SLIM_FILL, alpha))
	var edge := PackedVector2Array(shape)
	edge.append(shape[0])
	canvas.draw_polyline(edge, Color(SELECTED_RING if selected else line, alpha), 2.0 if selected else 1.0)


## A card-sized slot in the card row (the reward's "Bỏ 1 lá"): the slim panel with [param label] centred.
static func draw_slot(canvas: CanvasItem, rect: Rect2, label: String, pressed: bool) -> void:
	_read_style()
	if style != "slim":
		UiButtons.draw_button(canvas, rect, label, UiButtons.Style.NEUTRAL, pressed, true, MenuFont.fit_size(label, 28, rect.size.x * 0.8))
		return
	draw_slim_panel(canvas, rect, SLIM_LINES["common"], false, pressed)
	var w: float = rect.size.x * 0.8
	var size: int = MenuFont.fit_size(label, 22, w)
	MenuFont.text(canvas, Vector2(rect.position.x + rect.size.x * 0.1, rect.get_center().y + MenuFont.size(size) * 0.33), label, size, NAME_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, w)


# Centred multiline text in [param box], the font shrinking (never below BODY_MIN_FONT_SIZE) until it fits.
static func _draw_text_box(canvas: CanvasItem, box: Rect2, text: String, alpha: float, start_size: int = BODY_FONT_SIZE) -> void:
	if text.is_empty() or box.size.y <= 0.0:
		return
	var font: Font = _font()
	var nominal: int = start_size
	var size: int = MenuFont.size(nominal)
	while nominal > BODY_MIN_FONT_SIZE and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size).y > box.size.y:
		nominal -= 1
		size = MenuFont.size(nominal)
	var lines: int = maxi(int(box.size.y / font.get_height(size)), 1)
	canvas.draw_multiline_string(font, Vector2(box.position.x, box.position.y + font.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x, size, lines, Color(BODY_COLOR, alpha))


## The picture of card [param card_id] (null when it has none yet).
static func card_art(card_id: String) -> Texture2D:
	if card_id.is_empty():
		return null
	if not _art_cache.has(card_id):
		var path: String = CARD_ART_PATH % card_id
		_art_cache[card_id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art_cache[card_id]


# The code-drawn window of a card without a picture: the effect colour and its icon or glyph.
static func _draw_window_art(canvas: CanvasItem, window: Rect2, skill: Dictionary, effect: String, alpha: float) -> void:
	_draw_window(canvas, window, EFFECT_COLORS.get(effect, EFFECT_COLORS["damage"]), alpha)
	var icon_name: String = str(EFFECT_ICONS.get(effect, ""))
	if icon_name.is_empty() and int(skill.get("fragile_stacks", 0)) > 0:
		icon_name = "fragile"
	elif icon_name.is_empty() and int(skill.get("frost_stacks", 0)) > 0:
		icon_name = "chill"
	var icon_scale: float = floorf(minf(window.size.x, window.size.y) / 55.0)
	if not icon_name.is_empty() and icon_scale >= 1.0:
		HudSkin.icon(canvas, icon_name, window.get_center().round(), icon_scale, Color(1, 1, 1, alpha))
	else:
		_draw_glyph(canvas, window, effect, alpha)


## Draws a relic tile (2026-11-01: relics are not cards, so they no longer borrow the card frame with covered
## gems): the menu's stone frame, the relic's glyph tile on the left, the name and the rarity line beside it,
## [param foot] ([text, colour, size]) under them (the shop's price). The rule text [param desc] is printed under
## the icon row when the tile is tall enough, else it is the detail panel's job.
static func draw_relic(canvas: CanvasItem, rect: Rect2, relic_id: String, name: String, rarity_text: String,
		rarity: String, negative: bool, desc: String, selected: bool = false, pressed: bool = false, dim: bool = false,
		foot: Array = []) -> void:
	var vp_h: float = canvas.get_viewport_rect().size.y
	var s: float = float(PixelFrame.scale_for(vp_h))
	var alpha: float = 0.55 if dim else 1.0
	_read_style()
	if style == "slim":
		draw_slim_panel(canvas, rect, SLIM_LINES.get("curse" if negative else rarity, SLIM_LINES["common"]), selected and not dim, pressed, alpha)
	else:
		PixelFrame.draw(canvas, PixelFrame.BUTTON_FRAME, rect, PixelFrame.BUTTON_MARGIN, int(s), frame_tint("boss" if negative else rarity, selected, pressed, dim))
		if selected and not dim:
			canvas.draw_rect(rect.grow(SELECTED_RING_PX + 1.0), SELECTED_RING, false, SELECTED_RING_PX)
	var pad: float = roundf(PixelFrame.BUTTON_MARGIN * s * 0.8)
	var edge: float = roundf(minf(rect.size.y * 0.42, RelicStrip.MAX_ICON))
	var icon := Rect2(rect.position + Vector2(pad, pad), Vector2(edge, edge))
	RelicStrip.draw_icon(canvas, icon, relic_id, RelicStrip.BORDER_WIDTH, false, 0.0)
	var color: Color = RelicStrip.NEGATIVE_COLOR if negative else RelicStrip.rarity_color(rarity)
	var x: float = icon.end.x + pad * 0.6
	var w: float = maxf(rect.end.x - pad - x, 1.0)
	MenuFont.text(canvas, Vector2(x, icon.position.y + edge * 0.42), name, MenuFont.fit_size(name, NAME_FONT_SIZE + 2, w), Color(NAME_COLOR, alpha), HORIZONTAL_ALIGNMENT_LEFT, w)
	MenuFont.text(canvas, Vector2(x, icon.position.y + edge * 0.9), rarity_text, MenuFont.fit_size(rarity_text, SUB_FONT_SIZE, w), Color(color.lightened(0.25), alpha), HORIZONTAL_ALIGNMENT_LEFT, w)
	if foot.size() >= 2:
		var nominal: int = int(foot[2]) if foot.size() > 2 else SUB_FONT_SIZE
		var fw: float = rect.size.x - pad * 2.0
		MenuFont.text(canvas, Vector2(rect.position.x + pad, rect.end.y - pad * 0.9), str(foot[0]), MenuFont.fit_size(str(foot[0]), nominal, fw),
			Color(foot[1], alpha), HORIZONTAL_ALIGNMENT_LEFT, fw)


## Pure: where the detail panel of the card at [param card] goes on a [param viewport_size] screen — under the
## card when it fits above the bottom button row, else over it when it fits under the title band, else beside
## it (right when there is room, else left). Clamped inside the screen.
static func detail_rect(card: Rect2, viewport_size: Vector2) -> Rect2:
	var size := Vector2(maxf(viewport_size.x * DETAIL_WIDTH_RATIO, card.size.x), viewport_size.y * DETAIL_HEIGHT_RATIO)
	var gap: float = viewport_size.y * DETAIL_GAP_RATIO
	var top_limit: float = viewport_size.y * DETAIL_TOP_LIMIT_RATIO
	var bottom_limit: float = viewport_size.y * DETAIL_BOTTOM_LIMIT_RATIO
	var pos := Vector2(card.get_center().x - size.x * 0.5, 0.0)
	if card.end.y + gap + size.y <= bottom_limit:
		pos.y = card.end.y + gap
	elif card.position.y - gap - size.y >= top_limit:
		pos.y = card.position.y - gap - size.y
	else:
		pos.y = clampf(card.position.y, top_limit, maxf(bottom_limit - size.y, top_limit))
		pos.x = card.end.x + gap if card.end.x + gap + size.x <= viewport_size.x else card.position.x - gap - size.x
	pos.x = clampf(pos.x, gap, maxf(viewport_size.x - size.x - gap, gap))
	return Rect2(pos.round(), size.round())


## Draws the detail panel at [param rect]: [param title], one line per [param lines] entry ([text, colour]),
## the [param body] paragraph and the [param hint] at the foot ("" = none).
static func draw_detail(canvas: CanvasItem, rect: Rect2, title: String, lines: Array, body: String, hint: String) -> void:
	var vp_h: float = canvas.get_viewport_rect().size.y
	canvas.draw_rect(Rect2(rect.position + Vector2(6.0, 6.0), rect.size), Color(0, 0, 0, 0.45))
	_read_style()
	if style == "slim":
		draw_slim_panel(canvas, rect, SELECTED_RING, false, false)
	else:
		canvas.draw_rect(rect.grow(-4.0), DETAIL_BACK)
		PixelFrame.draw(canvas, PixelFrame.BUTTON_FRAME, rect, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp_h), SELECTED_TINT)
	var pad: float = roundf(rect.size.y * 0.1)
	var x: float = rect.position.x + pad
	var w: float = rect.size.x - pad * 2.0
	var y: float = rect.position.y + pad + MenuFont.size(DETAIL_TITLE_FONT_SIZE) * 0.7
	MenuFont.text(canvas, Vector2(x, y), title, MenuFont.fit_size(title, DETAIL_TITLE_FONT_SIZE, w), DETAIL_TITLE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, w)
	for line: Variant in lines:
		var entry: Array = line as Array
		var text: String = str(entry[0])
		if text.is_empty():
			continue
		y += MenuFont.size(DETAIL_LINE_FONT_SIZE) * 1.1
		MenuFont.text(canvas, Vector2(x, y), text, MenuFont.fit_size(text, DETAIL_LINE_FONT_SIZE, w), entry[1], HORIZONTAL_ALIGNMENT_LEFT, w)
	var font: Font = _font()
	var body_size: int = MenuFont.size(DETAIL_BODY_FONT_SIZE)
	var hint_h: float = 0.0 if hint.is_empty() else body_size * 1.2
	var body_top: float = y + body_size * 1.25
	var lines_fit: int = clampi(int((rect.end.y - pad * 0.4 - hint_h - body_top + body_size * 0.8) / font.get_height(body_size)), 1, DETAIL_BODY_LINES)
	canvas.draw_multiline_string(font, Vector2(x, body_top), body, HORIZONTAL_ALIGNMENT_LEFT, w, body_size, lines_fit, DETAIL_BODY_COLOR)
	if not hint.is_empty():
		MenuFont.text(canvas, Vector2(x, rect.end.y - pad * 0.7), hint, MenuFont.fit_size(hint, DETAIL_LINE_FONT_SIZE, w), DETAIL_HINT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, w)


static func _font() -> Font:
	return MenuFont.font() if MenuFont.font() != null else HudSkin.font()


# The PixelLab frame nine-sliced over [param rect] at scale [param s], plus the gold ring when [param ring].
static func _draw_frame(canvas: CanvasItem, rect: Rect2, s: float, tint: Color, ring: bool) -> void:
	PixelFrame.draw_margins(canvas, CARD_FRAME, rect, CARD_MARGINS, int(s), tint)
	if ring:
		canvas.draw_rect(rect.grow(SELECTED_RING_PX + 1.0), SELECTED_RING, false, SELECTED_RING_PX)


# The name in the strip under the top edge (centred); with an upgrade [param tag] ("+2") the name and tag in gold.
static func _draw_name(canvas: CanvasItem, rect: Rect2, s: float, name: String, tag: String, alpha: float) -> void:
	var left: float = rect.position.x + NAME_STRIP_LEFT * s
	var right: float = rect.end.x - NAME_STRIP_RIGHT * s
	var center_y: float = rect.position.y + (NAME_STRIP_TOP + NAME_STRIP_BOTTOM) * 0.5 * s
	# 2026-11-01 (user: "số +2 là gì?"): an upgrade is no corner tag — the name itself reads "Lia ngang +2" in gold.
	var text: String = name if tag.is_empty() else name + " " + tag
	var color: Color = NAME_COLOR if tag.is_empty() else TAG_COLOR
	var w: float = maxf(right - left, 1.0)
	var max_size: int = floori((NAME_STRIP_BOTTOM - NAME_STRIP_TOP) * s * 1.55 / MenuFont.size(1))
	var size: int = MenuFont.fit_size(text, mini(NAME_FONT_SIZE, max_size), w)
	MenuFont.text(canvas, Vector2(left, center_y + MenuFont.size(size) * 0.33), text, size, Color(color, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)


# The foot line (bottom-left, before the red gem): [param foot] = [text, colour] or [text, colour, nominal size];
# nothing when empty.
static func _draw_foot(canvas: CanvasItem, rect: Rect2, s: float, foot: Array, alpha: float) -> void:
	if foot.size() < 2 or str(foot[0]).is_empty():
		return
	var left: float = rect.position.x + (INNER_X + 1.0) * s
	var w: float = maxf(rect.end.x - FOOT_RIGHT * s - left, 1.0)
	var text: String = str(foot[0])
	var nominal: int = int(foot[2]) if foot.size() > 2 else SUB_FONT_SIZE
	MenuFont.text(canvas, Vector2(left, rect.end.y - FOOT_BASELINE * s), text, MenuFont.fit_size(text, nominal, w),
		Color(foot[1], alpha * (foot[1] as Color).a), HORIZONTAL_ALIGNMENT_LEFT, w)


# A number on a gem socket centred on [param center]: white, outlined, sized to the gem.
static func _draw_gem_number(canvas: CanvasItem, center: Vector2, s: float, text: String, alpha: float) -> void:
	var half: float = GEM_HALF * s
	var size: int = MenuFont.size(MenuFont.fit_size(text, NUMBER_FONT_SIZE, half * 1.5))
	var font: Font = _font()
	var pos := Vector2(roundf(center.x - half * 2.0), roundf(center.y + size * 0.33))
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, half * 4.0, size, NUMBER_OUTLINE_PX, Color(OUTLINE, alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, half * 4.0, size, Color(NUMBER_COLOR, alpha))


# Dims an unused gem socket (a card without damage, a relic) so it reads as empty.
static func _cover_gem(canvas: CanvasItem, center: Vector2, s: float) -> void:
	var h: float = roundf(GEM_HALF * s)
	var c: Vector2 = center.round()
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), GEM_EMPTY)


# The effect text in the box between the window and the foot, centred; the font shrinks (never below
# BODY_MIN_FONT_SIZE) until every line fits.
static func _draw_body(canvas: CanvasItem, rect: Rect2, s: float, window: Rect2, desc: String, alpha: float, with_foot: bool = false) -> void:
	if desc.is_empty():
		return
	var inner: Rect2 = inner_rect(rect, s)
	var box := Rect2(inner.position.x + 2.0 * s, window.end.y + 4.0 * s, inner.size.x - 4.0 * s, 0.0)
	box.size.y = rect.end.y - ((FOOT_BASELINE + 9.0) if with_foot else (INNER_BOTTOM + 3.0)) * s - box.position.y
	if box.size.y <= 0.0:
		return
	var font: Font = _font()
	var nominal: int = BODY_FONT_SIZE
	var size: int = MenuFont.size(nominal)
	while nominal > BODY_MIN_FONT_SIZE and font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size).y > box.size.y:
		nominal -= 1
		size = MenuFont.size(nominal)
	var lines: int = maxi(int(box.size.y / font.get_height(size)), 1)
	canvas.draw_multiline_string(font, Vector2(box.position.x, box.position.y + font.get_ascent(size)), desc, HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x, size, lines, Color(BODY_COLOR, alpha))


# The art window: a recessed square painted in the effect colour — whole-pixel horizontal bands, lightest at the
# top, a floor band at the foot and a 2 px shine line under the top edge.
static func _draw_window(canvas: CanvasItem, window: Rect2, color: Color, alpha: float) -> void:
	canvas.draw_rect(window.grow(2.0), Color(WINDOW_EDGE, alpha))
	var bands: Array[float] = [0.38, 0.46, 0.54, 0.62, 0.7]
	var band_h: float = floorf(window.size.y * 0.78 / bands.size())
	for i: int in bands.size():
		canvas.draw_rect(Rect2(window.position.x, window.position.y + band_h * i, window.size.x, band_h), Color(color.darkened(bands[i]), alpha))
	var floor_top: float = window.position.y + band_h * bands.size()
	canvas.draw_rect(Rect2(window.position.x, floor_top, window.size.x, window.end.y - floor_top), Color(color.darkened(0.8), alpha))
	canvas.draw_rect(Rect2(window.position.x, floor_top, window.size.x, 2.0), Color(color.darkened(0.25), alpha))
	canvas.draw_rect(Rect2(window.position.x, window.position.y + 2.0, window.size.x, 2.0), Color(color.lightened(0.25), 0.5 * alpha))


# Code-drawn art for an effect with no sheet icon: three slash marks (damage) or a double chevron (push).
static func _draw_glyph(canvas: CanvasItem, window: Rect2, effect: String, alpha: float) -> void:
	var c: Vector2 = window.get_center().round()
	var r: float = roundf(minf(window.size.x, window.size.y) * 0.3)
	var width: float = maxf(roundf(r * 0.22), 3.0)
	var strokes: Array = []
	if effect == "push":
		for dx: float in [-0.45, 0.25]:
			strokes.append([c + Vector2(r * dx - r * 0.25, -r * 0.6), c + Vector2(r * dx + r * 0.3, 0.0)])
			strokes.append([c + Vector2(r * dx + r * 0.3, 0.0), c + Vector2(r * dx - r * 0.25, r * 0.6)])
	else:
		for dx: float in [-0.5, 0.0, 0.5]:
			strokes.append([c + Vector2(r * dx + r * 0.45, -r * 0.8), c + Vector2(r * dx - r * 0.45, r * 0.8)])
	for st: Variant in strokes:
		canvas.draw_line((st as Array)[0], (st as Array)[1], Color(OUTLINE, alpha), width + 4.0)
	for st: Variant in strokes:
		canvas.draw_line((st as Array)[0], (st as Array)[1], Color(GLYPH_COLOR, alpha), width)
