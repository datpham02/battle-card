class_name SaveSlotsView
extends Node2D
## Save slot screen (user 2026-11-07): opened from the title — "Tiếp tục" = LOAD mode, header "Chọn bản lưu"; "Chơi"
## = NEW mode, header "Chơi mới" ([method GameFlow.open_save_slots]). One run in progress per slot. Three
## cards side by side, one per [SaveSlots] slot, each an ancient plate (gold for the slot in use, navy otherwise)
## with: "Ô n" and "Đang dùng" (bare gold text, no box) for the active one; for a run in progress the hero's
## idle frame, its name, "Tầng f/F · region"; for progress without a run "Chưa có hành trình", best floor and
## achievements; then the total play time and the last-save time. An empty slot says "Ô trống", a corrupt one
## "Bản lưu hỏng" (the file is kept aside when it is opened). Under each card's text: the primary plate (Tiếp tục /
## Chơi / Tạo mới / Làm lại; in NEW mode a slot with a run shows "Chơi mới", which asks before dropping that run;
## [method GameFlow.slot_open]) and, for a slot with a file, a wine "Xóa" plate that asks for a confirmation (a centred
## plate over a dimmed screen: red action / "Hủy"; Back or a tap outside cancels it). "Về" sits in the
## bottom-left corner (left thumb reach). Tapping a card outside its buttons does the primary action (big targets).
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in
## [constant GameFlow.Phase.SAVE_SLOTS]; owns no state (mode and confirmation live in GameFlow). Input dedup as in
## TitleView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).

const TITLE_COLOR: Color = HudSkin.IVORY
const LABEL_COLOR: Color = Color("F8F8D0")
const DIM_COLOR: Color = HudSkin.TEXT_DIM
## Gold of "Đang dùng" (bare emphasised text) and the danger tone of "Bản lưu hỏng".
const ACCENT_COLOR: Color = Color("F8E080")
const DANGER_COLOR: Color = Color("F8B860")
## Over a gold (active) plate the text is dark.
const DARK_TEXT: Color = Color("3A2410")
const DARK_OUTLINE: Color = Color("F5CD6C")
const DIM_ON_GOLD: Color = Color("5A3A18")
const SHADE: Color = Color(0.05, 0.04, 0.07, 0.72)
const TITLE_FONT_SIZE: int = 44
const HEAD_FONT_SIZE: int = 30
const NAME_FONT_SIZE: int = 28
const LINE_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 26
const CONFIRM_TITLE_SIZE: int = 34
const CONFIRM_BODY_SIZE: int = 24
## Layout as shares of the viewport.
const HEADER_BOTTOM_RATIO: float = 0.13
const CARDS_TOP_RATIO: float = 0.17
const CARDS_HEIGHT_RATIO: float = 0.64
const CARDS_SIDE_RATIO: float = 0.05
const CARD_GAP_RATIO: float = 0.025
const PAD_RATIO: float = 0.02
const BUTTON_HEIGHT_RATIO: float = 0.1
const PRIMARY_SHARE: float = 0.6
const BACK_WIDTH_RATIO: float = 0.14
const BACK_HEIGHT_RATIO: float = 0.09
const HERO_HEIGHT_RATIO: float = 0.2
const CONFIRM_SIZE_RATIO: Vector2 = Vector2(0.5, 0.42)
const CONFIRM_BUTTON_WIDTH_RATIO: float = 0.17
## Frame shown of the hero's sheet.
const SPRITE_CLIP: String = "idle"

const TEXT_TITLE: String = "ui.slots.title"
const TEXT_TITLE_NEW: String = "ui.slots.title_new"
const TEXT_SLOT: String = "ui.slots.slot"
const TEXT_ACTIVE: String = "ui.slots.active"
const TEXT_EMPTY: String = "ui.slots.empty"
const TEXT_CORRUPT: String = "ui.slots.corrupt"
const TEXT_CORRUPT_HINT: String = "ui.slots.corrupt_hint"
const TEXT_NO_RUN: String = "ui.slots.no_run"
const TEXT_FLOOR_REGION: String = "ui.slots.floor_region"
const TEXT_FLOOR: String = "ui.slots.floor"
const TEXT_BEST_FLOOR: String = "ui.slots.best_floor"
const TEXT_ACHIEVEMENTS: String = "ui.slots.achievements"
const TEXT_PLAY_TIME: String = "ui.slots.play_time"
const TEXT_SAVED_AT: String = "ui.slots.saved_at"
const TEXT_DELETE: String = "ui.slots.delete"
const TEXT_BACK: String = "ui.slots.back"
const TEXT_CONFIRM_TITLE: String = "ui.slots.confirm_title"
const TEXT_CONFIRM_BODY: String = "ui.slots.confirm_body"
const TEXT_CONFIRM_YES: String = "ui.slots.confirm_yes"
const TEXT_CONFIRM_NO: String = "ui.slots.confirm_no"
const TEXT_ABANDON_TITLE: String = "ui.slots.abandon_title"
const TEXT_ABANDON_BODY: String = "ui.slots.abandon_body"
const TEXT_ABANDON_YES: String = "ui.slots.abandon_yes"
## Primary button label key by GameFlow.SLOT_ACTION_* value.
const TEXT_ACTIONS: Dictionary = {"continue": "ui.slots.continue", "play": "ui.slots.play", "new": "ui.slots.new",
	"redo": "ui.slots.redo", "abandon": "ui.slots.abandon"}

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MenuFont.read_args()


func _process(_delta: float) -> void:
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.SAVE_SLOTS


# --- Layout (pure) -------------------------------------------------------------


## The [constant SaveSlots.SLOT_COUNT] card rects, left to right.
static func card_rects(vp: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var n: int = SaveSlots.SLOT_COUNT
	var gap: float = vp.x * CARD_GAP_RATIO
	var w: float = (vp.x * (1.0 - CARDS_SIDE_RATIO * 2.0) - gap * (n - 1)) / n
	for i: int in n:
		rects.append(Rect2(vp.x * CARDS_SIDE_RATIO + (w + gap) * i, vp.y * CARDS_TOP_RATIO, w, vp.y * CARDS_HEIGHT_RATIO))
	return rects


## The card's button row (bottom, inside the padding).
static func _button_row(card: Rect2, vp: Vector2) -> Rect2:
	var pad: float = vp.y * PAD_RATIO
	var h: float = vp.y * BUTTON_HEIGHT_RATIO
	return Rect2(card.position.x + pad, card.end.y - pad * 1.5 - h, card.size.x - pad * 2.0, h)


## The primary plate of [param card]; full row width when [param with_delete] is false.
static func primary_rect(card: Rect2, vp: Vector2, with_delete: bool = true) -> Rect2:
	var row: Rect2 = _button_row(card, vp)
	if not with_delete:
		return row
	return Rect2(row.position, Vector2(row.size.x * PRIMARY_SHARE, row.size.y))


## The "Xóa" plate of [param card] (right of the primary one).
static func delete_rect(card: Rect2, vp: Vector2) -> Rect2:
	var row: Rect2 = _button_row(card, vp)
	var gap: float = vp.y * PAD_RATIO
	var x: float = row.position.x + row.size.x * PRIMARY_SHARE + gap
	return Rect2(x, row.position.y, row.end.x - x, row.size.y)


## "Về" in the bottom-left corner.
static func back_rect(vp: Vector2) -> Rect2:
	var size := Vector2(vp.x * BACK_WIDTH_RATIO, vp.y * BACK_HEIGHT_RATIO)
	var margin: float = vp.y * PAD_RATIO * 1.5
	return Rect2(Vector2(margin, vp.y - margin - size.y), size)


## The delete confirmation plate (centred).
static func confirm_rect(vp: Vector2) -> Rect2:
	var size: Vector2 = vp * CONFIRM_SIZE_RATIO
	return Rect2((vp - size) * 0.5, size)


## The confirmation's "Xóa" (left) and "Hủy" (right) plates.
static func confirm_button_rects(vp: Vector2) -> Array[Rect2]:
	var box: Rect2 = confirm_rect(vp)
	var size := Vector2(vp.x * CONFIRM_BUTTON_WIDTH_RATIO, vp.y * BUTTON_HEIGHT_RATIO)
	var pad: float = vp.y * PAD_RATIO * 2.0
	var y: float = box.end.y - pad - size.y
	var gap: float = box.size.x - size.x * 2.0 - pad * 2.0
	return [Rect2(Vector2(box.position.x + pad, y), size), Rect2(Vector2(box.position.x + pad + size.x + gap, y), size)]


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
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
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	tap(pos)


## Runs what a tap at [param pos] hits (the confirmation first, when it is open; it blocks the rest).
func tap(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if not _flow.get_slot_confirm().is_empty():
		var buttons: Array[Rect2] = confirm_button_rects(vp)
		if buttons[0].has_point(pos):
			_flow.confirm_slot()
		elif buttons[1].has_point(pos) or not confirm_rect(vp).has_point(pos):
			_flow.cancel_slot_confirm()
		return
	if back_rect(vp).has_point(pos):
		_flow.close_save_slots()
		return
	var cards: Array[Rect2] = card_rects(vp)
	for i: int in cards.size():
		if not cards[i].has_point(pos):
			continue
		if _flow.get_save_slots().has_file(i) and delete_rect(cards[i], vp).has_point(pos):
			_flow.request_slot_delete(i)
		else:
			_flow.slot_open(i)
		return


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), HEADER_BOTTOM_RATIO)
	var title_key: String = TEXT_TITLE_NEW if _flow.get_slot_mode() == GameFlow.SLOT_MODE_NEW else TEXT_TITLE
	MenuFont.text(self, Vector2(0.0, vp.y * HEADER_BOTTOM_RATIO * 0.68), tr(title_key), TITLE_FONT_SIZE, TITLE_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	var cards: Array[Rect2] = card_rects(vp)
	var confirm: Dictionary = _flow.get_slot_confirm()
	var confirm_open: bool = not confirm.is_empty()
	for i: int in cards.size():
		_draw_card(cards[i], vp, _flow.slot_summary(i), confirm_open)
	var back: Rect2 = back_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.SECONDARY,
		not confirm_open and UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE)
	if confirm_open:
		_draw_confirm(vp, confirm)


func _draw_card(card: Rect2, vp: Vector2, info: Dictionary, blocked: bool) -> void:
	var active: bool = bool(info["active"])
	var s: float = UiButtons.ui_scale(self)
	UiButtons.draw_plate(self, card, UiButtons.look(UiButtons.Style.SECONDARY, false, true, active), s, false)
	var pad: float = vp.y * PAD_RATIO * 1.5
	var x: float = card.position.x + pad
	var w: float = card.size.x - pad * 2.0
	var text_c: Color = DARK_TEXT if active else LABEL_COLOR
	var dim_c: Color = DIM_ON_GOLD if active else DIM_COLOR
	var y: float = card.position.y + pad + HEAD_FONT_SIZE
	_line(x, y, w, tr(TEXT_SLOT) % (int(info["index"]) + 1), HEAD_FONT_SIZE, text_c, active, HORIZONTAL_ALIGNMENT_LEFT)
	if active:
		_line(x, y, w, tr(TEXT_ACTIVE), LINE_FONT_SIZE, DARK_TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
	var hero_area := Rect2(x, y + pad * 0.5, w, vp.y * HERO_HEIGHT_RATIO)
	y = hero_area.end.y + pad + NAME_FONT_SIZE
	var lh: float = LINE_FONT_SIZE * 1.45
	match int(info["status"]):
		SaveSlots.Status.EMPTY:
			_line(x, hero_area.get_center().y, w, tr(TEXT_EMPTY), NAME_FONT_SIZE, dim_c, active, HORIZONTAL_ALIGNMENT_CENTER)
		SaveSlots.Status.CORRUPT:
			_line(x, hero_area.get_center().y, w, tr(TEXT_CORRUPT), NAME_FONT_SIZE, DANGER_COLOR, active, HORIZONTAL_ALIGNMENT_CENTER)
			_line(x, hero_area.get_center().y + lh, w, tr(TEXT_CORRUPT_HINT), LINE_FONT_SIZE, dim_c, active, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			if bool(info["has_run"]):
				var cid: String = str(info["character_id"])
				_draw_hero(hero_area, cid)
				var character: Dictionary = _flow.get_characters().get_character(cid)
				_line(x, y, w, tr(str(character.get("name_key", cid))), NAME_FONT_SIZE, text_c, active, HORIZONTAL_ALIGNMENT_CENTER)
				var floors: int = _flow.get_config().world_floors()
				var region: String = _flow.region_name(str(info["region_id"]))
				var where: String = tr(TEXT_FLOOR) % [int(info["floor"]), floors] if region.is_empty() \
					else tr(TEXT_FLOOR_REGION) % [int(info["floor"]), floors, region]
				_line(x, y + lh, w, where, LINE_FONT_SIZE, text_c, active, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				_line(x, hero_area.get_center().y, w, tr(TEXT_NO_RUN), NAME_FONT_SIZE, dim_c, active, HORIZONTAL_ALIGNMENT_CENTER)
				_line(x, y, w, tr(TEXT_BEST_FLOOR) % int(info["best_floor"]), LINE_FONT_SIZE, text_c, active, HORIZONTAL_ALIGNMENT_CENTER)
				_line(x, y + lh, w, tr(TEXT_ACHIEVEMENTS) % int(info["achievements"]), LINE_FONT_SIZE, text_c, active, HORIZONTAL_ALIGNMENT_CENTER)
			_line(x, y + lh * 2.2, w, tr(TEXT_PLAY_TIME) % SaveSlots.format_play_time(float(info["play_time_sec"])),
				LINE_FONT_SIZE, dim_c, active, HORIZONTAL_ALIGNMENT_CENTER)
			var saved: String = SaveSlots.format_saved_at(int(info["saved_at"]), _time_bias(), _flow.get_locale())
			if not saved.is_empty():
				_line(x, y + lh * 3.2, w, tr(TEXT_SAVED_AT) % saved, LINE_FONT_SIZE, dim_c, active, HORIZONTAL_ALIGNMENT_CENTER)
	var has_file: bool = int(info["status"]) != SaveSlots.Status.EMPTY
	var primary: Rect2 = primary_rect(card, vp, has_file)
	UiButtons.draw_button(self, primary, tr(str(TEXT_ACTIONS.get(str(info["action"]), TEXT_ACTIONS["new"]))),
		UiButtons.Style.PRIMARY, not blocked and UiButtons.is_pressed_at(self, primary), true, BUTTON_FONT_SIZE)
	if has_file:
		var del: Rect2 = delete_rect(card, vp)
		UiButtons.draw_button(self, del, tr(TEXT_DELETE), UiButtons.Style.DANGER,
			not blocked and UiButtons.is_pressed_at(self, del), true, BUTTON_FONT_SIZE)


func _draw_confirm(vp: Vector2, confirm: Dictionary) -> void:
	var index: int = int(confirm["index"])
	var abandon: bool = str(confirm["kind"]) == GameFlow.SLOT_CONFIRM_ABANDON
	draw_rect(Rect2(Vector2.ZERO, vp), SHADE)
	var box: Rect2 = confirm_rect(vp)
	UiButtons.draw_plate(self, box, UiButtons.look(UiButtons.Style.SECONDARY, false), UiButtons.ui_scale(self), false)
	var pad: float = vp.y * PAD_RATIO * 2.0
	MenuFont.text(self, Vector2(box.position.x, box.position.y + pad + CONFIRM_TITLE_SIZE), tr(TEXT_ABANDON_TITLE if abandon else TEXT_CONFIRM_TITLE) % (index + 1),
		CONFIRM_TITLE_SIZE, LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	_wrapped(Rect2(box.position.x + pad, box.position.y + pad * 2.0 + CONFIRM_TITLE_SIZE, box.size.x - pad * 2.0, box.size.y * 0.4),
		tr(TEXT_ABANDON_BODY if abandon else TEXT_CONFIRM_BODY), CONFIRM_BODY_SIZE, DIM_COLOR)
	var buttons: Array[Rect2] = confirm_button_rects(vp)
	UiButtons.draw_button(self, buttons[0], tr(TEXT_ABANDON_YES if abandon else TEXT_CONFIRM_YES), UiButtons.Style.DANGER, UiButtons.is_pressed_at(self, buttons[0]),
		true, BUTTON_FONT_SIZE)
	UiButtons.draw_button(self, buttons[1], tr(TEXT_CONFIRM_NO), UiButtons.Style.SECONDARY, UiButtons.is_pressed_at(self, buttons[1]),
		true, BUTTON_FONT_SIZE)


# One line at baseline [param y]; dark with a gold outline on the active (gold) card.
func _line(x: float, y: float, w: float, text: String, size: int, color: Color, on_gold: bool, align: HorizontalAlignment) -> void:
	if on_gold:
		MenuFont.text_outlined(self, Vector2(x, y), text, size, color, DARK_OUTLINE, align, w)
	else:
		MenuFont.text(self, Vector2(x, y), text, size, color, align, w)


# Centred lines of [param text] broken on spaces to fit [param rect]'s width.
func _wrapped(rect: Rect2, text: String, size: int, color: Color) -> void:
	var font: Font = MenuFont.font()
	var lines: Array[String] = []
	var current: String = ""
	for word: String in text.split(" ", false):
		var trial: String = word if current.is_empty() else current + " " + word
		if not current.is_empty() and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuFont.size(size)).x > rect.size.x:
			lines.append(current)
			current = word
		else:
			current = trial
	if not current.is_empty():
		lines.append(current)
	for i: int in lines.size():
		MenuFont.text(self, Vector2(rect.position.x, rect.position.y + size * (1.0 + 1.35 * i)), lines[i], size, color,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


# The hero's first idle frame, whole-number scaled to fit [param area] by height, feet on its bottom, centred.
func _draw_hero(area: Rect2, id: String) -> void:
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip(SPRITE_CLIP):
		return
	var frames: Array = sheet.clip(SPRITE_CLIP).get("frames", []) as Array
	if frames.is_empty():
		return
	var src: Rect2i = frames[0]
	var k: int = maxi(floori(area.size.y / src.size.y), 1)
	var vis_w: int = mini(src.size.x, floori(area.size.x / k))
	@warning_ignore("integer_division")
	var crop := Rect2i(src.position.x + (src.size.x - vis_w) / 2, src.position.y, vis_w, src.size.y)
	var size := Vector2(crop.size) * k
	var dst := Rect2(Vector2(roundf(area.get_center().x - size.x * 0.5), roundf(area.end.y - size.y)), size)
	draw_texture_rect_region(PixelFrame.nearest(sheet.texture()), dst, Rect2(crop))


func _time_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))
