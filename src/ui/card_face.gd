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
## quá"): the PixelLab ancient card frame in the measured OSFE layout (design/references/osfe-card-layout.md) — a
## 1 px bronze border, a dark weathered panel — in the card layout v2 below (2026-11-02). "slim": the same layout drawn
## in code (flat panel, line diamonds). "stone": the first PixelLab frame (thick stone, carved gems).
## DEV user arg `--card-style=ancient|slim|stone` for A/B.
static var style: String = "ancient"
const STYLE_ARG: String = "--card-style="
## The ancient frame (PixelLab Pro Flash 88x128, job 3ac0f855, 6 gen), drawn at the menu's density (x2 at 720p = the
## 176x256 card face). Its small blue gem's centre (art px) is the block cards' count gem.
const ANCIENT_FRAME: Texture2D = preload("res://assets/art/ui/cards/card_frame_ancient.png")
const ANCIENT_COST_CENTER: Vector2 = Vector2(8.5, 9.0)
## The share of a 32 px picture the battle's cooldown column icon shows (its centre 28 px).
const ANCIENT_PICTURE_PX: float = 28.0
static var _style_read: bool = false

# --- Card layout v2 (user 2026-11-02: "đang trống quá nhiều làm card hơi xấu … không bị trống những diện tích
# không cần thiết") -----------------------------------------------------------------------------------------------
## The ancient face is rebuilt as a tiled nine-slice of ANCIENT_FRAME's plain parts (no carved slot, no small gems),
## so it holds at any size, and the content follows design/references/osfe-card-layout.md: a big cost gem in the
## top-left corner, the name beside it, a picture window about half the card wide right under, the rule text (keywords
## in colour) filling the middle, a big damage gem in the bottom-right corner and a small foot line (rarity / price,
## cooldown) bottom-left. All geometry in art px of ANCIENT_FRAME, drawn at the menu's density (x2 at 720p).
## Gem diamond edge (art px) — 22 art = 44 px at 720p = 0.25 W; its box sits on the visible border's corner.
const V2_GEM_ART: int = 22
## Transparent rim of ANCIENT_FRAME around its visible border [left, top, right, bottom], art px, as measured on the art
## (BLOCK_CLEAR's right value is 1; the art's right rim is 3, so the face uses its own).
const V2_CLEAR: Array[float] = [3.0, 3.0, 3.0, 4.0]
## The picture: at least V2_PICTURE_MIN_W of the card width, integer-scaled (the 32 px art cropped as little as that
## allows, by whole art px on each side).
const V2_PICTURE_MIN_W: float = 0.5
## Top of the picture frame below the card's top (art px), and the frame's thickness (dark outline + gold line).
const V2_PICTURE_TOP_ART: float = 21.0
const V2_PICTURE_FRAME_ART: float = 2.0
## Gaps (art px): picture frame -> text, text -> damage gem, text -> foot line; inner padding of the text block.
const V2_TEXT_GAP_ART: float = 2.0
const V2_GEM_GAP_ART: float = 2.0
const V2_FOOT_GAP_ART: float = 0.0
const V2_PAD_ART: float = 5.0
## Name line: beside the cost gem, ends this far before the border (art px).
const V2_NAME_RIGHT_ART: float = 3.0
## Foot line baseline above the visible border's bottom (art px).
const V2_FOOT_BASELINE_ART: float = 7.0
## Font sizes (nominal): name, gem numbers, foot line; the body starts at V2_BODY_FONT_SIZE and shrinks to
## BODY_MIN_FONT_SIZE only when the text does not fit.
const V2_NAME_FONT_SIZE: int = 16
const V2_NUMBER_FONT_SIZE: int = 21
const V2_FOOT_FONT_SIZE: int = 13
const V2_FOOT_MIN_FONT_SIZE: int = 11
const V2_PRICE_FONT_SIZE: int = 17
const V2_BODY_FONT_SIZE: int = 15
## Gem palettes (sampled from ANCIENT_FRAME's own gems): [outline, rim light, rim dark, inner line, top facet,
## left facet, right facet, bottom facet, highlight].
const GEM_BLUE: Array[Color] = [Color("081327"), Color("f5be3e"), Color("df942f"), Color("0c1b42"), Color("60c4fe"),
	Color("38a3fb"), Color("3381e8"), Color("1d5aca"), Color("baf0ff")]
const GEM_RED: Array[Color] = [Color("081327"), Color("f5be3e"), Color("df942f"), Color("621321"), Color("ed7e80"),
	Color("de545f"), Color("ce2e3d"), Color("af1727"), Color("f5aaa4")]
## The damage gem of a card without damage: an empty socket.
const GEM_DULL: Array[Color] = [Color("081327"), Color("8a7346"), Color("6e5a38"), Color("0e0c14"), Color("3a3750"),
	Color("33304a"), Color("2b2940"), Color("232136"), Color("4a4766")]
## The picture frame: outline and gold line (ANCIENT_FRAME's).
const PICTURE_OUTLINE: Color = Color("081327")
const PICTURE_GOLD: Color = Color("e3a334")
## Keyword colours in the rule text: [translation key, colour]. The status colours are StatusRow's (frozen, burn) and
## the reward keyword line's (Rạn, Giá Lạnh, Xuyên giáp, Hành quyết, Bãi Gai), so a keyword reads the same everywhere.
const KEYWORD_COLORS: Array = [
	["keyword.burn", Color("FF7A1F")],
	["ui.hud.pinned", Color("7FD4FF")],
	["keyword.fragile", Color(0.77, 0.59, 0.93)],
	["keyword.frost", Color(0.44, 0.74, 0.96)],
	["keyword.pierce", Color(0.67, 0.7, 0.75)],
	["keyword.execute", Color(0.84, 0.43, 0.43)],
	["keyword.thorns", Color(0.51, 0.79, 0.48)],
]
## Rarity names for the foot line ("ui.rarity.<rarity>").
const RARITY_KEY: String = "ui.rarity.%s"
const FOOT_SEPARATOR: String = " · "
const ELLIPSIS: String = "…"
static var _layout_cache: Dictionary = {}
const LAYOUT_CACHE_MAX: int = 96
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
## the foot (the shop's price). [param show_cooldown] false leaves the cooldown out (the in-battle card menu, where
## the cooldown column and the pie over the picture show it instead, quick spec menu-la-giua-man-hinh-2026-11-01).
static func draw_skill(canvas: CanvasItem, rect: Rect2, skill: Dictionary, title: String, tag: String, desc: String,
		selected: bool = false, pressed: bool = false, dim: bool = false, foot: Array = [], card_id: String = "",
		show_cooldown: bool = true) -> void:
	_read_style()
	if not show_cooldown and float(skill.get("cooldown_sec", 0.0)) > 0.0:
		skill = skill.duplicate()
		skill["cooldown_sec"] = 0.0
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
	var lay: Dictionary = ancient_layout(rect, vp_h)
	var s: int = int(lay["scale"])
	var alpha: float = 0.55 if dim else 1.0
	var gem_tint: Color = DIM_TINT if dim else (PRESSED_TINT if pressed else Color.WHITE)
	var full: Rect2 = lay["rect"]
	_draw_ancient_tiled(canvas, full, s, frame_tint(str(skill.get("rarity", "common")), selected, pressed, dim), true, V2_CLEAR)
	if selected and not dim:
		canvas.draw_rect(lay["border"].grow(SELECTED_RING_PX), SELECTED_RING, false, SELECTED_RING_PX)
	# Name (gold with the upgrade level) on the top line, right of the cost gem, on the gem's centre line.
	var name_box: Rect2 = lay["name"]
	var text: String = title if tag.is_empty() else title + " " + tag
	var name_size: int = MenuFont.fit_size(text, V2_NAME_FONT_SIZE, name_box.size.x)
	MenuFont.text(canvas, Vector2(name_box.position.x, roundf((lay["cost"] as Rect2).get_center().y + MenuFont.size(name_size) * 0.33)), text, name_size,
		Color(TAG_COLOR if not tag.is_empty() else NAME_COLOR, alpha), HORIZONTAL_ALIGNMENT_CENTER, name_box.size.x)
	# The picture window: the card's art integer-scaled (NEAREST), or the code-drawn effect window.
	var pic: Rect2 = lay["picture"]
	_draw_picture_frame(canvas, pic, s, alpha)
	var art: Texture2D = card_art(card_id)
	if art != null:
		var src_edge: float = minf(float(lay["picture_src"]), minf(art.get_width(), art.get_height()))
		var src := Rect2(((Vector2(art.get_size()) - Vector2.ONE * src_edge) * 0.5).floor(), Vector2.ONE * src_edge)
		canvas.draw_texture_rect_region(PixelFrame.nearest(art), pic, src, Color(1, 1, 1, alpha))
	else:
		_draw_window_art(canvas, pic, skill, str(skill.get("effect", "damage")), alpha)
	# Rule text (keywords in colour) in the middle; a short face leaves it to the detail panel.
	if shows_text(rect, vp_h):
		var foot_line: Dictionary = foot_layout(skill, foot, rect, vp_h)
		var body: String = describe_with_cooldown(desc, skill) if bool(foot_line["cooldown_in_text"]) else desc
		_draw_rich_lines(canvas, text_layout(body, rect, vp_h), alpha)
		_draw_foot_v2(canvas, lay, foot_line["parts"], alpha)
	# Gems: cells on the blue one, damage on the red one (an empty socket without damage).
	var cost: Rect2 = lay["cost"]
	_draw_pixel_gem(canvas, cost, s, GEM_BLUE, gem_tint)
	_draw_gem_number_v2(canvas, cost, str(maxi(int(skill.get("min_cells", 1)), 1)), alpha)
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	var dmg_box: Rect2 = lay["damage"]
	_draw_pixel_gem(canvas, dmg_box, s, GEM_RED if damage > 0 else GEM_DULL, gem_tint)
	if damage > 0:
		_draw_gem_number_v2(canvas, dmg_box, str(damage), alpha)


## Pure: the v2 ancient face geometry of a card at [param rect] on a [param viewport_height] screen (screen px):
## "scale" (int), "rect" (the drawn frame), "border" (its visible border), "cost" / "damage" (gem boxes), "name",
## "picture" (the art window, a square), "picture_frame" (with its frame), "picture_src" (art px shown per edge),
## "text" (the text band: full width down to "text_full_bottom", then left of the damage gem down to its end, right
## edge "text_narrow_right"), "foot" (the foot line: left, baseline, width as a Rect2 whose position.y is the
## baseline).
static func ancient_layout(rect: Rect2, viewport_height: float) -> Dictionary:
	var s: int = PixelFrame.scale_for(viewport_height)
	var sf: float = float(s)
	var r := Rect2(rect.position.round(), rect.size.round())
	var border: Rect2 = r.grow_individual(-V2_CLEAR[0] * sf, -V2_CLEAR[1] * sf, -V2_CLEAR[2] * sf, -V2_CLEAR[3] * sf)
	var gem := Vector2.ONE * V2_GEM_ART * sf
	var cost := Rect2(border.position, gem)
	var damage := Rect2(border.end - gem, gem)
	var name_left: float = cost.end.x + sf
	# Picture: k x (an even crop of the 32 px art); k the smallest whole scale reaching V2_PICTURE_MIN_W, the crop the
	# smallest even one that still reaches it.
	var min_edge: float = r.size.x * V2_PICTURE_MIN_W
	var k: int = maxi(1, ceili(min_edge / ART_PX))
	var src: int = mini(int(ART_PX), ceili(min_edge / k / 2.0) * 2)
	var edge: float = float(src * k)
	var frame_px: float = V2_PICTURE_FRAME_ART * sf
	var pic := Rect2(roundf(border.get_center().x - edge * 0.5), r.position.y + V2_PICTURE_TOP_ART * sf + frame_px, edge, edge)
	var pic_frame: Rect2 = pic.grow(frame_px)
	# Name line: right of the cost gem, above the picture frame (the name is drawn on the gem's centre line).
	var name_top: float = border.position.y + sf
	var name := Rect2(name_left, name_top, maxf(border.end.x - V2_NAME_RIGHT_ART * sf - name_left, 1.0), maxf(pic_frame.position.y - name_top, 1.0))
	var pad: float = V2_PAD_ART * sf
	var foot_baseline: float = border.end.y - V2_FOOT_BASELINE_ART * sf
	var foot_size: int = MenuFont.size(V2_FOOT_FONT_SIZE)
	var foot_top: float = foot_baseline - roundf(foot_size * 0.75)
	var text_top: float = pic_frame.end.y + V2_TEXT_GAP_ART * sf
	var text := Rect2(border.position.x + pad, text_top, border.size.x - pad * 2.0, maxf(foot_top - V2_FOOT_GAP_ART * sf - text_top, 0.0))
	var full_bottom: float = damage.position.y - V2_GEM_GAP_ART * sf
	var narrow_right: float = damage.position.x - V2_GEM_GAP_ART * sf
	var foot := Rect2(border.position.x + pad, foot_baseline, maxf(narrow_right - border.position.x - pad, 1.0), foot_size)
	return {
		"scale": s, "rect": r, "border": border, "cost": cost, "damage": damage, "name": name, "picture": pic,
		"picture_frame": pic_frame, "picture_src": src, "text": text, "text_full_bottom": full_bottom,
		"text_narrow_right": narrow_right, "foot": foot,
	}


## Pure: the rule text of a face at [param rect] laid out (v2 ancient face): an Array of lines, each
## {"rect": Rect2 (screen px, the line's box), "baseline": float, "x": float (left of the first word), "size": int (font px),
## "segments": [[text, colour or null for the body colour], ...]}. The text starts at V2_BODY_FONT_SIZE and shrinks
## (never below BODY_MIN_FONT_SIZE) until it fits the band; a block that stays above the damage gem is centred in that
## part of the band; a text still too long at the smallest size is cut with "…".
static func text_layout(desc: String, rect: Rect2, viewport_height: float) -> Array:
	if desc.is_empty():
		return []
	var lay: Dictionary = ancient_layout(rect, viewport_height)
	var key: String = "%s|%s|%s|%s" % [desc, rect, viewport_height, TranslationServer.get_locale()]
	if _layout_cache.has(key):
		return _layout_cache[key]
	var band: Rect2 = lay["text"]
	var full_bottom: float = float(lay["text_full_bottom"])
	var narrow_right: float = float(lay["text_narrow_right"])
	var font: Font = _font()
	var words: Array = _rich_words(desc)
	var lines: Array = []
	var nominal: int = V2_BODY_FONT_SIZE
	while true:
		var size: int = MenuFont.size(nominal)
		lines = _wrap_words(words, font, size, band, full_bottom, narrow_right)
		var fits: bool = not lines.is_empty() and (lines[-1]["rect"] as Rect2).end.y <= band.end.y + 0.5
		if fits or nominal <= BODY_MIN_FONT_SIZE:
			if not fits:
				lines = _cut_lines(lines, font, size, band)
			break
		nominal -= 1
	# Centre a block that stays in the full-width part between the picture and the damage gem.
	if not lines.is_empty() and (lines[-1]["rect"] as Rect2).end.y <= full_bottom + 0.5:
		var shift: float = floorf((full_bottom - (lines[-1]["rect"] as Rect2).end.y) * 0.5)
		for line: Dictionary in lines:
			line["rect"] = (line["rect"] as Rect2).grow_individual(0.0, -shift, 0.0, shift)
			line["baseline"] = float(line["baseline"]) + shift
	if _layout_cache.size() >= LAYOUT_CACHE_MAX:
		_layout_cache.clear()
	_layout_cache[key] = lines
	return lines


# Words of [param text] split at spaces, each as [[segment, colour or null], ...]: a keyword (KEYWORD_COLORS,
# translated, any case, at a word start, coloured to the end of its word) in its colour, the rest null.
static func _rich_words(text: String) -> Array:
	var colours: Array = []
	colours.resize(text.length())
	var lower: String = text.to_lower()
	for entry: Array in KEYWORD_COLORS:
		var word: String = TranslationServer.translate(str(entry[0])).to_lower()
		if word.is_empty() or word == str(entry[0]).to_lower():
			continue
		var at: int = lower.find(word)
		while at >= 0:
			if at == 0 or not _is_letter(text[at - 1]):
				var end: int = at + word.length()
				while end < text.length() and _is_letter(text[end]):
					end += 1
				for i: int in range(at, end):
					if colours[i] == null:
						colours[i] = entry[1]
			at = lower.find(word, at + 1)
	var words: Array = []
	var segments: Array = []
	var current: String = ""
	var current_colour: Variant = null
	for i: int in text.length() + 1:
		var c: String = text[i] if i < text.length() else " "
		if c == " ":
			if not current.is_empty():
				segments.append([current, current_colour])
			if not segments.is_empty():
				words.append(segments)
			segments = []
			current = ""
			current_colour = null
			continue
		if not current.is_empty() and colours[i] != current_colour:
			segments.append([current, current_colour])
			current = ""
		current += c
		current_colour = colours[i]
	# A one-letter word ("5 s", "3 ô", "×2 s)") stays on the line of the word before it: no lone unit on a line.
	var glued: Array = []
	for word: Array in words:
		var letters: int = 0
		for seg: Array in word:
			for ch: String in str(seg[0]):
				letters += 1 if _is_letter(ch) or ch.is_valid_int() else 0
		if letters <= 1 and not glued.is_empty():
			var prev: Array = glued[-1]
			prev.append([" ", null])
			prev.append_array(word)
		else:
			glued.append(word)
	return glued


static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper()


static func _word_width(word: Array, font: Font, size: int) -> float:
	var w: float = 0.0
	for seg: Array in word:
		w += font.get_string_size(str(seg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return w


# Greedy wrap of [param words] from the top of [param band]: a line is full width while it ends above
# [param full_bottom], else it stops at [param narrow_right] (left of the damage gem). Lines are centred in their width.
static func _wrap_words(words: Array, font: Font, size: int, band: Rect2, full_bottom: float, narrow_right: float) -> Array:
	var line_h: float = font.get_height(size)
	var space: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var lines: Array = []
	var y: float = band.position.y
	var cur: Array = []
	var cur_w: float = 0.0
	var i: int = 0
	while i < words.size():
		var right: float = band.end.x if y + line_h <= full_bottom + 0.5 else narrow_right
		var max_w: float = right - band.position.x
		var w: float = _word_width(words[i], font, size)
		if cur.is_empty() or cur_w + space + w <= max_w:
			cur_w = w if cur.is_empty() else cur_w + space + w
			cur.append(words[i])
			i += 1
			continue
		lines.append(_make_line(cur, cur_w, band.position.x, right, y, line_h, font, size))
		y += line_h
		cur = []
		cur_w = 0.0
	if not cur.is_empty():
		var right_last: float = band.end.x if y + line_h <= full_bottom + 0.5 else narrow_right
		lines.append(_make_line(cur, cur_w, band.position.x, right_last, y, line_h, font, size))
	return lines


static func _make_line(words: Array, width: float, left: float, right: float, y: float, line_h: float, font: Font, size: int) -> Dictionary:
	var segments: Array = []
	for wi: int in words.size():
		if wi > 0:
			segments.append([" ", null])
		segments.append_array(words[wi])
	var x: float = roundf((left + right - width) * 0.5)
	return {"rect": Rect2(x, y, width, line_h), "baseline": roundf(y + font.get_ascent(size)), "x": x, "size": size, "segments": segments}


# Keeps the lines that end inside [param band]; the last one kept ends with "…" (words dropped until it fits).
static func _cut_lines(lines: Array, font: Font, size: int, band: Rect2) -> Array:
	var kept: Array = []
	for line: Dictionary in lines:
		if (line["rect"] as Rect2).end.y <= band.end.y + 0.5:
			kept.append(line)
	if kept.is_empty() or kept.size() == lines.size():
		return kept
	var last: Dictionary = kept[-1]
	var segs: Array = (last["segments"] as Array).duplicate()
	var limit: float = (last["rect"] as Rect2).size.x
	var r: Rect2 = last["rect"]
	limit = maxf(limit, band.size.x * 0.5)
	while not segs.is_empty() and _word_width(segs + [[ELLIPSIS, null]], font, size) > limit:
		segs.pop_back()
	while not segs.is_empty() and str(segs[-1][0]) == " ":
		segs.pop_back()
	# "burn.…" reads as a typo: the cut word loses its closing punctuation.
	if not segs.is_empty():
		var tail: String = str(segs[-1][0]).rstrip(".,;:")
		if tail.is_empty():
			segs.pop_back()
		else:
			segs[-1] = [tail, segs[-1][1]]
	segs.append([ELLIPSIS, null])
	var w: float = _word_width(segs, font, size)
	var x: float = roundf(r.get_center().x - w * 0.5)
	last["segments"] = segs
	last["x"] = x
	last["rect"] = Rect2(x, r.position.y, w, r.size.y)
	last["cut"] = true
	return kept


## Pure: true when the face of [param skill] at [param rect] prints its whole rule text ([param desc], plus the
## cooldown when the foot line has no room for it); false for a short face ([method shows_text]) or a text cut with
## "…" — the screen then opens the detail panel on selection. [param foot] as for [method draw_skill]; the slim and
## stone faces always print it.
static func face_text_complete(skill: Dictionary, desc: String, foot: Array, rect: Rect2, viewport_height: float) -> bool:
	if not shows_text(rect, viewport_height):
		return false
	_read_style()
	if style != "ancient":
		return true
	var foot_line: Dictionary = foot_layout(skill, foot, rect, viewport_height)
	var body: String = describe_with_cooldown(desc, skill) if bool(foot_line["cooldown_in_text"]) else desc
	var lines: Array = text_layout(body, rect, viewport_height)
	return lines.is_empty() or not bool((lines[-1] as Dictionary).get("cut", false))


# Draws laid-out lines ([method text_layout]) segment by segment in the body / keyword colours.
static func _draw_rich_lines(canvas: CanvasItem, lines: Array, alpha: float) -> void:
	var font: Font = _font()
	for line: Dictionary in lines:
		var x: float = float(line["x"])
		var size: int = int(line["size"])
		for seg: Array in line["segments"]:
			var t: String = str(seg[0])
			var c: Color = BODY_COLOR if seg[1] == null else seg[1] as Color
			canvas.draw_string(font, Vector2(x, float(line["baseline"])), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c, alpha))
			x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Pure: the foot line of a face (v2 ancient, bottom-left before the damage gem) as {"parts": [[text, colour, nominal
## size], ...] (a part after the first starts with FOOT_SEPARATOR), "cooldown_in_text": bool}. What it holds, by
## priority: [param foot]'s text (the shop's price, at most V2_PRICE_FONT_SIZE) or the card's rarity, then the cooldown
## ("hồi 8 s") when [param skill] has one. Everything shrinks together down to V2_FOOT_MIN_FONT_SIZE; when it still does
## not fit, the rarity is dropped, or (beside a price) the cooldown goes back to the end of the rule text.
static func foot_layout(skill: Dictionary, foot: Array, rect: Rect2, viewport_height: float) -> Dictionary:
	var box: Rect2 = ancient_layout(rect, viewport_height)["foot"]
	var lead: Array = []
	var is_price: bool = foot.size() >= 2 and not str(foot[0]).is_empty()
	if is_price:
		var nominal: int = mini(int(foot[2]) if foot.size() > 2 else V2_FOOT_FONT_SIZE, V2_PRICE_FONT_SIZE)
		lead = [str(foot[0]), Color(foot[1]), nominal]
	else:
		var rarity: String = str(skill.get("rarity", "common"))
		var label: String = TranslationServer.translate(RARITY_KEY % rarity)
		if label != RARITY_KEY % rarity:
			lead = [label, RelicStrip.rarity_color(rarity).lightened(0.25), V2_FOOT_FONT_SIZE]
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	var cd: Array = []
	if cooldown > 0.0:
		cd = [TranslationServer.translate(TEXT_COOLDOWN) % roundi(cooldown), SUB_COLOR, V2_FOOT_FONT_SIZE]
	var parts: Array = []
	if not lead.is_empty():
		parts.append(lead)
	if not cd.is_empty():
		parts.append([(FOOT_SEPARATOR if not lead.is_empty() else "") + str(cd[0]), cd[1], cd[2]])
	var fitted: Array = _fit_parts(parts, box.size.x)
	if not fitted.is_empty() or parts.size() < 2:
		return {"parts": fitted if not fitted.is_empty() else _fit_parts(parts, box.size.x, true), "cooldown_in_text": false}
	if is_price:
		return {"parts": _fit_parts([lead], box.size.x, true), "cooldown_in_text": true}
	return {"parts": _fit_parts([[str(cd[0]), cd[1], cd[2]]], box.size.x, true), "cooldown_in_text": false}


# [param parts] ([text, colour, nominal]) shrunk together, one nominal step at a time, until their row fits
# [param width]; [] when it does not fit at V2_FOOT_MIN_FONT_SIZE (unless [param force]: then at the smallest size).
static func _fit_parts(parts: Array, width: float, force: bool = false) -> Array:
	if parts.is_empty():
		return []
	var font: Font = _font()
	var step: int = 0
	while true:
		var out: Array = []
		var total: float = 0.0
		var smallest: int = 999
		for part: Array in parts:
			var n: int = maxi(int(part[2]) - step, 1)
			smallest = mini(smallest, n)
			total += font.get_string_size(str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, MenuFont.size(n)).x
			out.append([part[0], part[1], n])
		if total <= width:
			return out
		if smallest <= V2_FOOT_MIN_FONT_SIZE:
			return out if force else []
		step += 1
	return []


# Draws the foot line ([method foot_layout]) at the layout's foot baseline.
static func _draw_foot_v2(canvas: CanvasItem, lay: Dictionary, parts: Array, alpha: float) -> void:
	var box: Rect2 = lay["foot"]
	var font: Font = _font()
	var x: float = box.position.x
	for part: Array in parts:
		var t: String = str(part[0])
		MenuFont.text(canvas, Vector2(x, box.position.y), t, int(part[2]), Color(part[1] as Color, alpha))
		x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuFont.size(int(part[2]))).x


# The picture window's frame: a 1-art-px dark outline and a 1-art-px gold line, corners cut by one art px.
static func _draw_picture_frame(canvas: CanvasItem, pic: Rect2, s: int, alpha: float) -> void:
	var sf: float = float(s)
	var outer: Rect2 = pic.grow(sf * 2.0)
	var gold: Rect2 = pic.grow(sf)
	canvas.draw_rect(outer.grow_individual(-sf, 0.0, -sf, 0.0), Color(PICTURE_OUTLINE, alpha))
	canvas.draw_rect(outer.grow_individual(0.0, -sf, 0.0, -sf), Color(PICTURE_OUTLINE, alpha))
	canvas.draw_rect(gold, Color(PICTURE_GOLD, alpha))
	canvas.draw_rect(pic, Color(WINDOW_EDGE, alpha))


# A gem diamond filling the square [param box] drawn in whole art px of [param s] screen px (pixel art, no smoothing):
# a 1-art-px outline, a 2-art-px gold rim (light upper-left, dark lower-right), a dark inner line, four facets and a
# highlight.
# [param pal] = GEM_BLUE / GEM_RED / GEM_DULL; [param tint] multiplies it.
static func _draw_pixel_gem(canvas: CanvasItem, box: Rect2, s: int, pal: Array, tint: Color) -> void:
	var n: int = roundi(box.size.x / s)
	@warning_ignore("integer_division")
	var half: int = n / 2
	var sf: float = float(s)
	for j: int in n:
		var cj: int = half - 1 - j if j < half else j - half
		var run_start: int = -1
		var run_colour := Color()
		for i: int in n + 1:
			var colour: Variant = null
			if i < n:
				var ci: int = half - 1 - i if i < half else i - half
				var d: int = half - 1 - (ci + cj)
				if d >= 0:
					var up: bool = j < half
					var left: bool = i < half
					if d == 0:
						colour = pal[0]
					elif d <= 2:
						colour = pal[1] if (up and left) or (up != left and (cj >= ci) == up) else pal[2]
					elif d == 3:
						colour = pal[3]
					elif cj >= ci:
						colour = pal[4] if up else pal[7]
					else:
						colour = pal[5] if left else pal[6]
					if d >= 5 and up and left and cj >= 1 and absi(ci - cj) <= 1 and ci + cj >= half - 7 and ci + cj <= half - 5:
						colour = pal[8]
			if run_start >= 0 and (colour == null or colour != run_colour):
				canvas.draw_rect(Rect2(box.position.x + run_start * sf, box.position.y + j * sf, (i - run_start) * sf, sf), run_colour * tint)
				run_start = -1
			if colour != null and run_start < 0:
				run_start = i
				run_colour = colour


# A number centred on a v2 gem [param box]: white, outlined, sized to the gem's inner diamond.
static func _draw_gem_number_v2(canvas: CanvasItem, box: Rect2, text: String, alpha: float) -> void:
	var font: Font = _font()
	var w: float = box.size.x * 0.62
	var size: int = MenuFont.size(MenuFont.fit_size(text, V2_NUMBER_FONT_SIZE, w))
	var c: Vector2 = box.get_center()
	var pos := Vector2(roundf(c.x - box.size.x * 0.5), roundf(c.y + size * 0.36))
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size, NUMBER_OUTLINE_PX + 1, Color(OUTLINE, alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size, Color(NUMBER_COLOR, alpha))


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


## Pure: the visible outline of a skill face at [param rect] on a [param viewport_height] screen (the ancient frame's
## border inside its transparent rim; other styles: [param rect] shrunk by [param inset]) — where an opaque backing
## behind a dimmed face goes.
static func face_border(rect: Rect2, viewport_height: float, inset: float) -> Rect2:
	_read_style()
	if style == "ancient":
		return ancient_layout(rect, viewport_height)["border"]
	return rect.grow(-inset)


## Pure: the picture area of a skill face at [param rect] on a [param viewport_height] screen in the current
## [member style] (the ancient slot's picture, else the art window): where the battle menu lays its cooldown pie.
static func picture_rect(rect: Rect2, viewport_height: float) -> Rect2:
	_read_style()
	var s: float = float(PixelFrame.scale_for(viewport_height))
	if style == "ancient":
		return ancient_layout(rect, viewport_height)["picture"]
	if style == "slim":
		var edge: float = ART_PX * s
		var r := Rect2(rect.position.round(), rect.size.round())
		return Rect2(roundf(r.get_center().x - edge * 0.5), r.position.y + roundf(r.size.y * SLIM_WINDOW_TOP_H), edge, edge)
	return window_rect(rect, s, shows_text(rect, viewport_height), false)


## Draws card [param card_id]'s picture alone into the square [param rect] (the battle's cooldown column icon): the
## card's art when it has one, else the code-drawn effect window (effect colour + icon-sheet glyph), as on the face.
static func draw_picture(canvas: CanvasItem, rect: Rect2, skill: Dictionary, card_id: String, alpha: float = 1.0) -> void:
	var art: Texture2D = card_art(card_id)
	if art != null:
		canvas.draw_rect(rect.grow(2.0), Color(WINDOW_EDGE, alpha))
		var src_edge: float = minf(ANCIENT_PICTURE_PX, minf(art.get_width(), art.get_height()))
		var src := Rect2((Vector2(art.get_size()) - Vector2.ONE * src_edge) * 0.5, Vector2.ONE * src_edge)
		canvas.draw_texture_rect_region(PixelFrame.nearest(art), rect, src, Color(1, 1, 1, alpha))
	else:
		_draw_window_art(canvas, rect, skill, str(skill.get("effect", "damage")), alpha)


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
	# Card layout v2: the body's keywords in their colours, as on the face (left-aligned here).
	var top: float = body_top - font.get_ascent(body_size)
	var body_lines: Array = _wrap_words(_rich_words(body), font, body_size, Rect2(x, top, w, INF), INF, x + w)
	if body_lines.size() > lines_fit:
		body_lines = _cut_lines(body_lines, font, body_size, Rect2(x, top, w, font.get_height(body_size) * lines_fit))
	for body_line: Dictionary in body_lines:
		body_line["x"] = x
	_draw_rich_lines(canvas, body_lines, 1.0)
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


# --- Block cards (battle HUD pass 2026-11-01) -----------------------------------------------------------------
## The hold slots are "block cards": a small member of the ancient card family. The ANCIENT_FRAME is rebuilt at the
## menu's density (x2 at 720p) as a nine-slice whose middles are TILED from plain parts of the art (the picture slot
## and the red damage gem are left out): the top-left corner keeps the blue gem, which shows the block's cell count
## like a card's cost gem; the bottom-right corner is the bottom-left one mirrored. Source rects in art px.
const BLOCK_TL: Rect2 = Rect2(0.0, 0.0, 18.0, 22.0)
const BLOCK_TR: Rect2 = Rect2(70.0, 0.0, 18.0, 22.0)
const BLOCK_BL: Rect2 = Rect2(0.0, 116.0, 18.0, 12.0)
const BLOCK_TOP: Rect2 = Rect2(62.0, 0.0, 14.0, 22.0)
const BLOCK_BOTTOM: Rect2 = Rect2(20.0, 116.0, 40.0, 12.0)
const BLOCK_LEFT: Rect2 = Rect2(0.0, 50.0, 18.0, 50.0)
const BLOCK_RIGHT: Rect2 = Rect2(70.0, 50.0, 18.0, 50.0)
const BLOCK_CENTER: Rect2 = Rect2(20.0, 50.0, 40.0, 50.0)
## Transparent rim of ANCIENT_FRAME around its border [left, top, right, bottom], art px.
const BLOCK_CLEAR: Array[float] = [3.0, 3.0, 1.0, 4.0]
## The block glyph's area inside a block card: inset left / right, top (below the gem), bottom, art px.
const BLOCK_GLYPH_X: float = 7.0
const BLOCK_GLYPH_TOP: float = 17.0
const BLOCK_GLYPH_BOTTOM: float = 9.0
## Engraved socket of an empty block card: edge, art px; fill, shadow (top / left) and light (bottom / right) edges.
const BLOCK_SOCKET_ART: float = 14.0
const BLOCK_SOCKET_FILL: Color = Color("0E0C14", 0.9)
const BLOCK_SOCKET_SHADOW: Color = Color("050408")
const BLOCK_SOCKET_LIGHT: Color = Color("5A5470")


## Pure: the whole-number scale a block card at [param rect] is drawn at on a [param viewport_height] screen (the
## menu's density; 1 when the rect is too small for the corners at that scale).
static func block_scale(rect: Rect2, viewport_height: float) -> int:
	var s: int = PixelFrame.scale_for(viewport_height)
	var need := Vector2(BLOCK_TL.size.x + BLOCK_TR.size.x, BLOCK_TL.size.y + BLOCK_BL.size.y)
	while s > 1 and (rect.size.x < need.x * s or rect.size.y < need.y * s):
		s -= 1
	return s


## Draws a block card frame over [param rect] tinted by [param tint]; [param count] > 0 is printed on the blue gem
## (0 = the gem is covered: an empty socket). [param selected] adds the card selection ring (as on a selected
## card face). Whole-number scale, nearest filtering (the canvas's), the middles tiled.
static func draw_block_card(canvas: CanvasItem, rect: Rect2, count: int, tint: Color = Color.WHITE, selected: bool = false) -> void:
	var s: int = block_scale(rect, canvas.get_viewport_rect().size.y)
	var slot := Rect2(rect.position.round(), rect.size.round())
	# The art has a transparent rim (BLOCK_CLEAR): the frame is drawn that much larger so its visible border is the slot.
	var r: Rect2 = slot.grow_individual(BLOCK_CLEAR[0] * s, BLOCK_CLEAR[1] * s, BLOCK_CLEAR[2] * s, BLOCK_CLEAR[3] * s)
	_draw_ancient_tiled(canvas, r, s, tint, false, BLOCK_CLEAR)
	if selected:
		canvas.draw_rect(slot.grow(SELECTED_RING_PX), SELECTED_RING, false, SELECTED_RING_PX)
	var gem: Vector2 = r.position + ANCIENT_COST_CENTER * s
	if count > 0:
		_draw_gem_number(canvas, gem, s, str(count), tint.a)
	else:
		_cover_gem(canvas, gem, s)


# ANCIENT_FRAME rebuilt over [param r] (the full art rect, transparent rim included) at whole scale [param s]: corners
# as they are, the middles tiled from plain parts (no picture slot, no red gem; the bottom-right corner is the
# bottom-left one mirrored). [param plain_tl]: the top-left corner is the top-right one mirrored too (no small blue
# gem: the v2 card face draws its own big gem there); else the art's corner with its gem (block cards). [param clear]:
# the rim [left, top, right, bottom] the mirrored corners are lined up with.
static func _draw_ancient_tiled(canvas: CanvasItem, r: Rect2, s: int, tint: Color, plain_tl: bool, clear: Array[float]) -> void:
	var tex: Texture2D = PixelFrame.nearest(ANCIENT_FRAME)
	var l: float = BLOCK_TL.size.x * s
	var t: float = BLOCK_TL.size.y * s
	var rr: float = BLOCK_TR.size.x * s
	var b: float = BLOCK_BL.size.y * s
	var mid_w: float = r.size.x - l - rr
	var mid_h: float = r.size.y - t - b
	# The mirrored corner's clear rim is clear[0] wide, the right edge's clear[2]: shift it to line up.
	var shift: float = (clear[0] - clear[2]) * s
	PixelFrame.draw_tiled(canvas, tex, BLOCK_TOP, Rect2(r.position.x + l, r.position.y, mid_w, t), s, tint)
	PixelFrame.draw_tiled(canvas, tex, BLOCK_BOTTOM, Rect2(r.position.x + l, r.end.y - b, r.size.x - l * 2.0 + shift, b), s, tint)
	PixelFrame.draw_tiled(canvas, tex, BLOCK_LEFT, Rect2(r.position.x, r.position.y + t, l, mid_h), s, tint)
	PixelFrame.draw_tiled(canvas, tex, BLOCK_RIGHT, Rect2(r.end.x - rr, r.position.y + t, rr, mid_h), s, tint)
	PixelFrame.draw_tiled(canvas, tex, BLOCK_CENTER, Rect2(r.position.x + l, r.position.y + t, mid_w, mid_h), s, tint)
	if plain_tl:
		PixelFrame.draw_tiled(canvas, tex, BLOCK_TR, Rect2(r.position.x - shift, r.position.y, rr, t), s, tint, true)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(r.position, BLOCK_TL.size * s), BLOCK_TL, tint)
	canvas.draw_texture_rect_region(tex, Rect2(Vector2(r.end.x - rr, r.position.y), BLOCK_TR.size * s), BLOCK_TR, tint)
	canvas.draw_texture_rect_region(tex, Rect2(Vector2(r.position.x, r.end.y - b), BLOCK_BL.size * s), BLOCK_BL, tint)
	PixelFrame.draw_tiled(canvas, tex, BLOCK_BL, Rect2(r.end.x - l + shift, r.end.y - b, l, b), s, tint, true)


## Pure: where a block card at [param rect] draws its block glyph (inside the frame, below the gem row).
static func block_glyph_rect(rect: Rect2, viewport_height: float) -> Rect2:
	var s: float = float(block_scale(rect, viewport_height))
	return Rect2(rect.position.x + BLOCK_GLYPH_X * s, rect.position.y + BLOCK_GLYPH_TOP * s,
		rect.size.x - BLOCK_GLYPH_X * s * 2.0, rect.size.y - (BLOCK_GLYPH_TOP + BLOCK_GLYPH_BOTTOM) * s).abs()


## The engraved socket of an empty block card: a recessed square centred in the glyph area (dark fill, a 1-art-px
## shadow on the top / left edges and light on the bottom / right ones), at the card's scale.
static func draw_block_socket(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	var vp_h: float = canvas.get_viewport_rect().size.y
	var s: float = float(block_scale(rect, vp_h))
	var area: Rect2 = block_glyph_rect(rect, vp_h)
	var edge: float = BLOCK_SOCKET_ART * s
	var sq := Rect2((area.get_center() - Vector2(edge, edge) * 0.5).round(), Vector2(edge, edge))
	canvas.draw_rect(sq, Color(BLOCK_SOCKET_FILL, BLOCK_SOCKET_FILL.a * alpha))
	canvas.draw_rect(Rect2(sq.position, Vector2(edge, s)), Color(BLOCK_SOCKET_SHADOW, alpha))
	canvas.draw_rect(Rect2(sq.position, Vector2(s, edge)), Color(BLOCK_SOCKET_SHADOW, alpha))
	canvas.draw_rect(Rect2(Vector2(sq.position.x, sq.end.y - s), Vector2(edge, s)), Color(BLOCK_SOCKET_LIGHT, alpha))
	canvas.draw_rect(Rect2(Vector2(sq.end.x - s, sq.position.y), Vector2(s, edge)), Color(BLOCK_SOCKET_LIGHT, alpha))

