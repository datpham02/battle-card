class_name ShopView
extends Node2D
## Shop screen (Story 033, Part D): shown in phase SHOP ([method GameFlow.get_shop], the ShopLogic state
## of the open shop). Title band: "CỬA HÀNG" centred, HP and the gold count (code-drawn coin, see
## [method draw_gold]) at the right. Middle: the card row ("Lá") over the relic row ("Bảo vật")
## (ScreenLayout.shop_card_rects / shop_relic_rects, large cards, every target >= 64 px), each item
## with its price — red when ShopLogic.can_buy refuses for lack of gold. Sold items stay in place,
## dimmed, stamped "Đã bán". Right: the two services as two big buttons (ScreenLayout.shop_service_rects:
## "Bỏ một lá", "Hồi máu", price or "Đã dùng"). Bottom-left "Rời cửa hàng" -> [method GameFlow.shop_leave].
## Touch: a tap on an item (on release) selects it — it rises with a gold outline — and the "Mua (N vàng)"
## button appears bottom-right (the right thumb) -> [method GameFlow.shop_buy]; the heal service selects
## the same way -> [method GameFlow.shop_use_service]("heal"). Holding an item for LONG_PRESS_SEC opens
## its full description (name, rarity, stats, the whole text) until the next tap. The remove service
## opens the DECK PICKER: the run's deck as a horizontally scrolling row of tiles (drag to scroll; curses
## marked in purple); a tap marks a tile (it rises, red outline), a second tap on it or the bottom-right
## "Bỏ lá này (N vàng)" -> [method GameFlow.shop_use_service]("remove_card", deck index); "Thôi" closes it.
## The line between the bottom buttons shows the last result or the refusal reason (`reason_key`).
## Enter / Keypad Enter / Space leave the shop (DEV convenience). Child of GameFlow (reads it through
## [member flow_path]); draws and takes input only in phase SHOP; owns no run state. Input dedup as in
## RunHudView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## Placeholder art drawn in code; all strings are TEXT_* keys through tr().

## Background, panels, outlines.
const BACK_COLOR: Color = Color(0.93, 0.89, 0.8)
const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const HEADER_COLOR: Color = Color(0.4, 0.35, 0.3)
const LABEL_COLOR: Color = Color(0.45, 0.38, 0.3)
const CARD_BACK: Color = Color(1.0, 0.97, 0.9)
const NAME_COLOR: Color = Color(0.15, 0.12, 0.1)
const BODY_COLOR: Color = Color(0.3, 0.26, 0.22)
const STAT_COLOR: Color = Color(0.2, 0.4, 0.55)
const UPGRADE_COLOR: Color = Color(0.72, 0.5, 0.05)
const PRICE_COLOR: Color = Color(0.55, 0.4, 0.05)
const PRICE_SHORT_COLOR: Color = Color(0.85, 0.12, 0.1)
const SELECTED_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.25)
const SOLD_COLOR: Color = Color(0.45, 0.42, 0.38)
const MESSAGE_COLOR: Color = Color(0.25, 0.2, 0.15)
const MESSAGE_BAD_COLOR: Color = Color(0.8, 0.15, 0.1)
const SERVICE_REMOVE_BACK: Color = Color(0.42, 0.22, 0.2)
const SERVICE_HEAL_BACK: Color = Color(0.16, 0.42, 0.3)
const SERVICE_TEXT: Color = Color(1.0, 0.97, 0.9)
const SERVICE_PRICE: Color = Color(1.0, 0.85, 0.35)
const SERVICE_PRICE_SHORT: Color = Color(1.0, 0.45, 0.4)
const DETAIL_DIM: Color = Color(0.0, 0.0, 0.0, 0.55)
const DETAIL_BACK: Color = Color(0.12, 0.1, 0.09, 0.97)
const DETAIL_TEXT: Color = Color(0.95, 0.9, 0.78)
const DETAIL_SUB_TEXT: Color = Color(0.75, 0.72, 0.65)
## Deck picker tiles: curse border / tag, marked outline.
const CURSE_COLOR: Color = Color(0.55, 0.2, 0.75)
const CURSE_BACK: Color = Color(0.93, 0.86, 0.97)
const MARKED_OUTLINE: Color = Color(0.85, 0.15, 0.1)
## Coin icon: rim and face (an old square-holed coin).
const COIN_RIM: Color = Color(0.6, 0.42, 0.05)
const COIN_FACE: Color = Color(1.0, 0.82, 0.25)

const OUTLINE_WIDTH: float = 3.0
const RARITY_BORDER: float = 6.0
const SELECTED_BORDER: float = 9.0
const TILE_BORDER: float = 5.0
const TITLE_FONT_SIZE: int = 44
const HEADER_FONT_SIZE: int = 24
const GOLD_FONT_SIZE: int = 30
const LABEL_FONT_SIZE: int = 22
const NAME_FONT_SIZE: int = 26
const RARITY_FONT_SIZE: int = 18
const STAT_FONT_SIZE: int = 18
const DESC_FONT_SIZE: int = 16
const DESC_MAX_LINES: int = 3
const RELIC_DESC_MAX_LINES: int = 2
const PRICE_FONT_SIZE: int = 26
const SOLD_FONT_SIZE: int = 30
const SERVICE_NAME_FONT_SIZE: int = 28
const SERVICE_DESC_FONT_SIZE: int = 18
const SERVICE_PRICE_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 28
const MESSAGE_FONT_SIZE: int = 22
const DETAIL_NAME_FONT_SIZE: int = 34
const DETAIL_FONT_SIZE: int = 22
const DETAIL_MAX_LINES: int = 9
const TILE_NAME_FONT_SIZE: int = 22
const TILE_FONT_SIZE: int = 18
const MIN_FIT_FONT_SIZE: int = 13
## Coin radius as a share of the gold font size; gap between coin and number (px).
const COIN_RADIUS_RATIO: float = 0.45
const COIN_GAP: float = 6.0
## Hold this long on an item to open its full description.
const LONG_PRESS_SEC: float = 0.5
## A press that moves farther than this (px) is a drag, not a tap or a hold.
const TAP_SLOP: float = 16.0
## Inner padding of an item as a share of its width; baselines as shares of its height.
const PAD_RATIO: float = 0.06
const CARD_NAME_BASELINE: float = 0.13
const CARD_RARITY_BASELINE: float = 0.22
const CARD_STATS_BASELINE: float = 0.33
const CARD_DESC_TOP: float = 0.38
const PRICE_BASELINE: float = 0.93
const RELIC_ICON_SIZE_RATIO: float = 0.36
const RELIC_DESC_TOP: float = 0.5
## Service button baselines (name, description, price) as shares of its height.
const SERVICE_NAME_BASELINE: float = 0.32
const SERVICE_DESC_BASELINE: float = 0.55
const SERVICE_PRICE_BASELINE: float = 0.82
## Deck picker tile baselines.
const TILE_NAME_BASELINE: float = 0.2
const TILE_LEVEL_BASELINE: float = 0.36
const TILE_RARITY_BASELINE: float = 0.52
const TILE_TAG_BASELINE: float = 0.75
const SEPARATOR: String = " · "

const KIND_CARD: String = "card"
const KIND_RELIC: String = "relic"
const KIND_SERVICE: String = "service"
const SERVICE_REMOVE: String = "remove_card"
const SERVICE_HEAL: String = "heal"
const CFG_MIN_DECK: String = "min_deck_size"

const TEXT_TITLE: String = "ui.shop.title"
const TEXT_CARDS: String = "ui.shop.cards"
const TEXT_RELICS: String = "ui.shop.relics"
const TEXT_SERVICES: String = "ui.shop.services"
## "Mua (%d vàng)".
const TEXT_BUY: String = "ui.shop.buy"
const TEXT_LEAVE: String = "ui.shop.leave"
const TEXT_PRICE: String = "ui.shop.price"
const TEXT_SOLD: String = "ui.shop.sold"
const TEXT_USED: String = "ui.shop.used"
const TEXT_PICK_REMOVE: String = "ui.shop.pick_remove"
const TEXT_HEALED: String = "ui.shop.healed"
const TEXT_REMOVED: String = "ui.shop.removed"
const TEXT_UPGRADED: String = "ui.shop.upgraded"
## "Đã mua: %s".
const TEXT_BOUGHT: String = "ui.shop.bought"
## "Giữ để xem chi tiết".
const TEXT_HOLD_HINT: String = "ui.shop.hold_hint"
## "Bỏ lá này (%d vàng)".
const TEXT_CONFIRM_REMOVE: String = "ui.shop.confirm_remove"
const TEXT_SERVICE_REMOVE_NAME: String = "ui.shop.service.remove_card.name"
const TEXT_SERVICE_REMOVE_DESC: String = "ui.shop.service.remove_card.desc"
const TEXT_SERVICE_HEAL_NAME: String = "ui.shop.service.heal.name"
## "Hồi %d%% máu tối đa".
const TEXT_SERVICE_HEAL_DESC: String = "ui.shop.service.heal.desc"
const TEXT_REASON_NO_GOLD: String = "ui.shop.reason.no_gold"
const TEXT_REASON_MIN_DECK: String = "ui.shop.reason.min_deck"
## "Lá nguyền" tag on a curse tile; "Kéo để xem thêm" under a picker wider than the screen.
const TEXT_CURSE_TAG: String = "ui.deck.curse"
const TEXT_DRAG_HINT: String = "ui.deck.drag_hint"
## Shared keys.
const TEXT_CANCEL: String = "ui.reward.cancel"
const TEXT_HP: String = "ui.map.hp"
const TEXT_DISMISS: String = "ui.map.notice_dismiss"
const TEXT_CELLS: String = "ui.reward.cells"
const TEXT_CELLS_ANY: String = "ui.reward.cells_any"
const TEXT_DAMAGE: String = "ui.reward.damage"
const TEXT_COOLDOWN: String = "ui.reward.cooldown"
const TEXT_COOLDOWN_NONE: String = "ui.reward.cooldown_none"
const TEXT_UPGRADE_TO: String = "ui.reward.upgrade_to"
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"
const RARITY_KEY_FORMAT: String = "ui.rarity.%s"


## A horizontally scrolling row of deck tiles (shop remove service, event remove / upgrade picks).
## Owns only the scroll offset, the marked tile and the drag state; the owner draws the tiles with
## [method ShopView.draw_deck_tile] at [method tile_rects] and acts on the index [method handle] returns.
class DeckPicker extends RefCounted:
	const WHEEL_STEP: float = 60.0
	## Scroll offset in pixels (0 = first tile at the left).
	var scroll: float = 0.0
	## Index of the marked tile (-1 = none): the first tap marks, a second tap confirms.
	var marked: int = -1
	var _press_pos: Vector2 = Vector2.INF
	var _press_scroll: float = 0.0
	var _dragging: bool = false

	## Back to the first tile, nothing marked.
	func reset() -> void:
		scroll = 0.0
		marked = -1
		_press_pos = Vector2.INF
		_dragging = false

	## Tile rects of [param count] entries at the current scroll (centred when they fit the row).
	func tile_rects(vp: Vector2, count: int) -> Array[Rect2]:
		var rects: Array[Rect2] = []
		var row: Rect2 = ScreenLayout.deck_picker_row_rect(vp)
		var size: Vector2 = ScreenLayout.deck_picker_tile_size(vp)
		var gap: float = vp.x * ScreenLayout.DECK_PICKER_GAP_RATIO
		var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
		var total: float = size.x * count + gap * maxi(count - 1, 0)
		var left: float = row.position.x + maxf((row.size.x - total) * 0.5, margin) - scroll
		for i: int in count:
			rects.append(Rect2(left + (size.x + gap) * i, row.get_center().y - size.y * 0.5, size.x, size.y))
		return rects

	## How far the row can scroll (0 when every tile fits).
	func max_scroll(vp: Vector2, count: int) -> float:
		var size: Vector2 = ScreenLayout.deck_picker_tile_size(vp)
		var gap: float = vp.x * ScreenLayout.DECK_PICKER_GAP_RATIO
		var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
		return maxf(size.x * count + gap * maxi(count - 1, 0) + margin * 2.0 - vp.x, 0.0)

	## Feeds one REAL pointer event (the owner drops emulated copies). A press in the row starts a
	## tap-or-drag; moving past TAP_SLOP scrolls; a release that never dragged returns the tile index
	## under it. -1 otherwise.
	func handle(event: InputEvent, vp: Vector2, count: int) -> int:
		var row: Rect2 = ScreenLayout.deck_picker_row_rect(vp)
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT):
				scroll = clampf(scroll + WHEEL_STEP, 0.0, max_scroll(vp, count))
				return -1
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT):
				scroll = clampf(scroll - WHEEL_STEP, 0.0, max_scroll(vp, count))
				return -1
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return -1
			return _press_or_release(mb.pressed, mb.position, row, vp, count)
		if event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			return _press_or_release(st.pressed, st.position, row, vp, count)
		var pos: Vector2 = Vector2.INF
		if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pos = (event as InputEventMouseMotion).position
		elif event is InputEventScreenDrag:
			pos = (event as InputEventScreenDrag).position
		if pos != Vector2.INF and _press_pos != Vector2.INF:
			var dx: float = pos.x - _press_pos.x
			if absf(dx) > ShopView.TAP_SLOP:
				_dragging = true
			if _dragging:
				scroll = clampf(_press_scroll - dx, 0.0, max_scroll(vp, count))
		return -1

	func _press_or_release(pressed: bool, pos: Vector2, row: Rect2, vp: Vector2, count: int) -> int:
		if pressed:
			if row.has_point(pos):
				_press_pos = pos
				_press_scroll = scroll
				_dragging = false
			return -1
		if _press_pos == Vector2.INF:
			return -1
		var dragged: bool = _dragging
		_press_pos = Vector2.INF
		_dragging = false
		if dragged:
			return -1
		var rects: Array[Rect2] = tile_rects(vp, count)
		for i: int in rects.size():
			if rects[i].has_point(pos):
				return i
		return -1


## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Selected item ({"kind", "id"}; {} = none). Services use kind "service".
var _selected: Dictionary = {}
## Item the long-press panel shows ({} = closed).
var _detail: Dictionary = {}
## The press that may become a tap or a hold: the item under it, where and when it began.
var _press_item: Dictionary = {}
var _press_pos: Vector2 = Vector2.INF
var _press_msec: int = 0
## True once the current press opened the detail panel (its release does nothing).
var _press_held: bool = false
## Message line: a ready string and whether it is a refusal (red).
var _message: String = ""
var _message_bad: bool = false
## Deck picker of the remove service (open while [member _picking]).
var _picker: DeckPicker = DeckPicker.new()
var _picking: bool = false


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if not _is_active():
		_reset()
		queue_redraw()  # clear the last frame (see TitleView)
		return
	if not _press_item.is_empty() and not _press_held and _detail.is_empty():
		if Time.get_ticks_msec() - _press_msec >= int(LONG_PRESS_SEC * 1000.0):
			_detail = _press_item.duplicate()
			_press_held = true
	queue_redraw()


## The selected item ({"kind", "id"}, {} when none) — for tests and captures.
func get_selected() -> Dictionary:
	return _selected.duplicate()


## True while the remove-card deck picker is open — for tests.
func is_picking() -> bool:
	return _is_active() and _picking


## Selects an item as a tap would ({} clears) — for tests and captures.
func select_item(kind: String, id: String) -> void:
	_selected = {} if kind.is_empty() else {"kind": kind, "id": id}


## Story 033: draws [param gold] right-aligned so the number ends at [param right_x], vertically centred
## on [param center_y], with a code-drawn coin in front of it. Returns the left x of the coin. Shared by
## the map views, the reward screen and the event screen.
static func draw_gold(canvas: CanvasItem, right_x: float, center_y: float, gold: int, font_size: int, color: Color) -> float:
	var font: Font = ThemeDB.fallback_font
	var text: String = str(gold)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, Vector2(right_x - width, center_y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	var radius: float = font_size * COIN_RADIUS_RATIO
	var center := Vector2(right_x - width - COIN_GAP - radius, center_y)
	draw_coin(canvas, center, radius)
	return center.x - radius


## Story 033: a code-drawn coin (rim, face, square hole) of [param radius] at [param center].
static func draw_coin(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, COIN_RIM)
	canvas.draw_circle(center, radius * 0.8, COIN_FACE)
	var hole: float = radius * 0.32
	canvas.draw_rect(Rect2(center - Vector2(hole, hole), Vector2(hole, hole) * 2.0), COIN_RIM, false, maxf(radius * 0.14, 1.5))


## Story 033: one deck tile (name, level, rarity; a curse tile purple with its "Lá nguyền" tag) at
## [param rect]; [param marked] raises it with a red outline, [param disabled] dims it.
static func draw_deck_tile(canvas: CanvasItem, rect: Rect2, id: String, level: int, cards: SkillConfig, marked: bool, disabled: bool) -> void:
	var curse: bool = cards.is_curse(id)
	var skill: Dictionary = cards.resolved(id, level)
	var r: Rect2 = rect
	if marked:
		canvas.draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size), SHADOW_COLOR)
		r.position.y -= rect.size.y * 0.06
	var back: Color = CURSE_BACK if curse else CARD_BACK
	var border: Color = CURSE_COLOR if curse else RelicStrip.rarity_color(str(skill.get("rarity", "common")))
	var text: Color = NAME_COLOR
	if marked:
		border = MARKED_OUTLINE
	if disabled:
		back.a *= UiButtons.DIM_ALPHA
		border.a *= UiButtons.DIM_ALPHA
		text.a *= UiButtons.DIM_ALPHA
	canvas.draw_rect(r, back)
	canvas.draw_rect(r, border, false, SELECTED_BORDER if marked else TILE_BORDER)
	var inner: float = r.size.x * (1.0 - PAD_RATIO * 2.0)
	var name: String = canvas.tr(str(skill.get("name_key", id)))
	_centred(canvas, r, r.position.y + r.size.y * TILE_NAME_BASELINE, name, _fit(name, inner, TILE_NAME_FONT_SIZE), text)
	if not curse:
		_centred(canvas, r, r.position.y + r.size.y * TILE_LEVEL_BASELINE, canvas.tr(TEXT_LEVEL_SUFFIX) % level, TILE_FONT_SIZE, text)
		var rarity: String = canvas.tr(RARITY_KEY_FORMAT % str(skill.get("rarity", "common")))
		_centred(canvas, r, r.position.y + r.size.y * TILE_RARITY_BASELINE, rarity, _fit(rarity, inner, TILE_FONT_SIZE), text)
	else:
		var tag_color: Color = CURSE_COLOR
		if disabled:
			tag_color.a *= UiButtons.DIM_ALPHA
		var tag: String = canvas.tr(TEXT_CURSE_TAG)
		_centred(canvas, r, r.position.y + r.size.y * TILE_TAG_BASELINE, tag, _fit(tag, inner, TILE_NAME_FONT_SIZE), tag_color)


## Story 033: number of non-curse entries in [param entries] (deck entries {id, level}).
static func non_curse_count(entries: Array, cards: SkillConfig) -> int:
	var count: int = 0
	for entry: Variant in entries:
		if not cards.is_curse(str((entry as Dictionary).get("id", ""))):
			count += 1
	return count


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.SHOP and _flow.get_run() != null


func _reset() -> void:
	_selected = {}
	_detail = {}
	_press_item = {}
	_press_pos = Vector2.INF
	_press_held = false
	_message = ""
	_message_bad = false
	_picking = false
	_picker.reset()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if _picking:
				_close_picker()
			else:
				_flow.shop_leave()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _picking:
		_input_picker(event, vp)
		return
	var press: Vector2 = _pointer(event, true)
	var release: Vector2 = _pointer(event, false)
	if press != Vector2.INF:
		if not _detail.is_empty():
			_detail = {}
			return
		_on_press(press, vp)
	elif release != Vector2.INF:
		_on_release(release)
	elif not _press_item.is_empty() and _drag_position(event).distance_to(_press_pos) > TAP_SLOP:
		_press_item = {}  # moved off: neither a tap nor a hold


# A real press: buttons act at once; an item waits for its release (tap) or a hold (detail).
func _on_press(pos: Vector2, vp: Vector2) -> void:
	if ScreenLayout.shop_leave_rect(vp).has_point(pos):
		_flow.shop_leave()
		return
	if not _selected.is_empty() and ScreenLayout.shop_buy_rect(vp).has_point(pos):
		_buy()
		return
	var services: Array[Rect2] = ScreenLayout.shop_service_rects(vp)
	if services[0].has_point(pos):
		_open_picker()
		return
	if services[1].has_point(pos):
		_select({"kind": KIND_SERVICE, "id": SERVICE_HEAL})
		return
	var item: Dictionary = _item_at(pos, vp)
	if not item.is_empty():
		_press_item = item
		_press_pos = pos
		_press_msec = Time.get_ticks_msec()
		_press_held = false


func _on_release(_pos: Vector2) -> void:
	var item: Dictionary = _press_item
	var held: bool = _press_held
	_press_item = {}
	_press_held = false
	if item.is_empty() or held:
		return
	_select(item)


func _select(item: Dictionary) -> void:
	var entry: Dictionary = _entry(str(item["kind"]), str(item["id"]))
	if entry.is_empty() or bool(entry.get("sold", false)) or bool(entry.get("used", false)):
		return
	_selected = item.duplicate()
	var check: Dictionary = _can_buy(str(item["kind"]), str(item["id"]))
	_message = "" if bool(check.get("ok", false)) else tr(str(check.get("reason_key", "")))
	_message_bad = not _message.is_empty()


func _buy() -> void:
	var kind: String = str(_selected.get("kind", ""))
	var id: String = str(_selected.get("id", ""))
	var result: Dictionary
	var hp_before: float = _hp()
	if kind == KIND_SERVICE:
		result = _flow.shop_use_service(id)
	else:
		result = _flow.shop_buy(kind, id)
	if not bool(result.get("ok", false)):
		_message = tr(str(result.get("reason_key", "")))
		_message_bad = true
		return
	_selected = {}
	_message_bad = false
	if kind == KIND_SERVICE:
		var healed: float = float(result.get("healed", _hp() - hp_before))
		_message = tr(TEXT_HEALED) % roundi(healed)
	elif kind == KIND_CARD and bool(result.get("upgraded", false)):
		_message = tr(TEXT_UPGRADED) % int(result.get("level", 2))
	else:
		_message = tr(TEXT_BOUGHT) % _item_name(kind, id)


# Shop item under [param pos] ({"kind", "id"}; {} when none or sold). Touch areas include the lift.
func _item_at(pos: Vector2, vp: Vector2) -> Dictionary:
	var shop: Dictionary = _flow.get_shop()
	var lift: float = ScreenLayout.shop_item_raise(vp)
	for row: Array in [[KIND_CARD, "cards"], [KIND_RELIC, "relics"]]:
		var entries: Array = shop.get(row[1], [])
		var rects: Array[Rect2] = ScreenLayout.shop_card_rects(vp, entries.size()) if row[0] == KIND_CARD else ScreenLayout.shop_relic_rects(vp, entries.size())
		for i: int in rects.size():
			var area := Rect2(rects[i].position.x, rects[i].position.y - lift, rects[i].size.x, rects[i].size.y + lift)
			if area.has_point(pos) and not bool((entries[i] as Dictionary).get("sold", false)):
				return {"kind": row[0], "id": str((entries[i] as Dictionary).get("id", ""))}
	return {}


func _open_picker() -> void:
	var check: Dictionary = _can_buy(KIND_SERVICE, SERVICE_REMOVE)
	if not bool(check.get("ok", false)):
		_message = tr(str(check.get("reason_key", "")))
		_message_bad = true
		return
	_selected = {}
	_message = ""
	_picker.reset()
	_picking = true


func _close_picker() -> void:
	_picking = false
	_picker.reset()


# Deck picker input: "Thôi" closes it, the confirm button / a second tap on the marked tile removes it.
func _input_picker(event: InputEvent, vp: Vector2) -> void:
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var press: Vector2 = _pointer(event, true)
	if press != Vector2.INF:
		if ScreenLayout.shop_leave_rect(vp).has_point(press):
			_close_picker()
			return
		if _picker.marked >= 0 and ScreenLayout.shop_buy_rect(vp).has_point(press):
			_remove(_picker.marked)
			return
	var tapped: int = _picker.handle(event, vp, entries.size())
	if tapped < 0:
		return
	if not _removable(entries, tapped):
		_message = tr(TEXT_REASON_MIN_DECK)
		_message_bad = true
		return
	if tapped == _picker.marked:
		_remove(tapped)
	else:
		_picker.marked = tapped
		_message = ""


func _remove(index: int) -> void:
	var result: Dictionary = _flow.shop_use_service(SERVICE_REMOVE, index)
	_close_picker()
	if bool(result.get("ok", false)):
		_message = tr(TEXT_REMOVED)
		_message_bad = false
	else:
		_message = tr(str(result.get("reason_key", "")))
		_message_bad = true


# A curse can always go; a normal card only while the non-curse cards stay above min_deck_size.
func _removable(entries: Array[Dictionary], index: int) -> bool:
	if index < 0 or index >= entries.size():
		return false
	var cards: SkillConfig = _flow.get_cards()
	if cards.is_curse(str(entries[index].get("id", ""))):
		return true
	return non_curse_count(entries, cards) > _min_deck()


func _min_deck() -> int:
	return int(_flow.get_shop().get(CFG_MIN_DECK, _flow.get_reward_config().get(CFG_MIN_DECK, 0)))


# Press (pressed = true) or release position of a left mouse button / touch; Vector2.INF otherwise.
func _pointer(event: InputEvent, pressed: bool) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed == pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed == pressed:
			return touch.position
	return Vector2.INF


func _drag_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return _press_pos


# --- Data helpers -------------------------------------------------------------


func _entry(kind: String, id: String) -> Dictionary:
	var shop: Dictionary = _flow.get_shop()
	if kind == KIND_SERVICE:
		return (shop.get("services", {}) as Dictionary).get(id, {})
	for entry: Variant in shop.get("cards" if kind == KIND_CARD else "relics", []):
		if str((entry as Dictionary).get("id", "")) == id:
			return entry as Dictionary
	return {}


func _can_buy(kind: String, id: String) -> Dictionary:
	return ShopLogic.can_buy(_flow.get_shop(), kind, id, _flow.get_gold())


func _short(kind: String, id: String) -> bool:
	return str(_can_buy(kind, id).get("reason", "")) == ShopLogic.REASON_NO_GOLD


func _price(kind: String, id: String) -> int:
	return int(_entry(kind, id).get("price", 0))


func _max_hp() -> float:
	var run: RunSession = _flow.get_run()
	return float(_flow.get_characters().get_character(run.character_id).get("max_hp", 1.0))


func _hp() -> float:
	var run: RunSession = _flow.get_run()
	var max_hp: float = _max_hp()
	return max_hp if run.hp < 0.0 else minf(run.hp, max_hp)


func _item_name(kind: String, id: String) -> String:
	if kind == KIND_RELIC:
		return tr(str(RelicRegistry.shared_config().get_relic(id).get("name_key", id)))
	return tr(str(_flow.get_cards().get_skill(id).get("name_key", id)))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BACK_COLOR)
	if _picking:
		_draw_picker(vp)
		return
	_draw_header(vp, tr(TEXT_TITLE))
	var shop: Dictionary = _flow.get_shop()
	var card_label: Rect2 = ScreenLayout.shop_row_label_rect(vp, false)
	_text(card_label, card_label.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_CARDS) + SEPARATOR + tr(TEXT_HOLD_HINT), LABEL_FONT_SIZE, LABEL_COLOR)
	var relic_label: Rect2 = ScreenLayout.shop_row_label_rect(vp, true)
	_text(relic_label, relic_label.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_RELICS), LABEL_FONT_SIZE, LABEL_COLOR)
	var services_label: Rect2 = ScreenLayout.shop_services_label_rect(vp)
	_text(services_label, services_label.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_SERVICES), LABEL_FONT_SIZE, LABEL_COLOR)
	var cards: Array = shop.get("cards", [])
	var card_rects: Array[Rect2] = ScreenLayout.shop_card_rects(vp, cards.size())
	for i: int in card_rects.size():
		_draw_item(vp, card_rects[i], KIND_CARD, cards[i] as Dictionary)
	var relics: Array = shop.get("relics", [])
	var relic_rects: Array[Rect2] = ScreenLayout.shop_relic_rects(vp, relics.size())
	for i: int in relic_rects.size():
		_draw_item(vp, relic_rects[i], KIND_RELIC, relics[i] as Dictionary)
	var services: Array[Rect2] = ScreenLayout.shop_service_rects(vp)
	_draw_service(services[0], SERVICE_REMOVE, SERVICE_REMOVE_BACK)
	_draw_service(services[1], SERVICE_HEAL, SERVICE_HEAL_BACK)
	var leave: Rect2 = ScreenLayout.shop_leave_rect(vp)
	UiButtons.draw_button(self, leave, tr(TEXT_LEAVE), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, leave), true, _fit(tr(TEXT_LEAVE), leave.size.x * 0.9, BUTTON_FONT_SIZE))
	if not _selected.is_empty():
		var buy: Rect2 = ScreenLayout.shop_buy_rect(vp)
		var kind: String = str(_selected["kind"])
		var id: String = str(_selected["id"])
		var ok: bool = bool(_can_buy(kind, id).get("ok", false))
		var label: String = tr(TEXT_BUY) % _price(kind, id)
		UiButtons.draw_button(self, buy, label, UiButtons.Style.PRIMARY, ok and UiButtons.is_pressed_at(self, buy), ok, _fit(label, buy.size.x * 0.9, BUTTON_FONT_SIZE))
	_draw_message(vp)
	if not _detail.is_empty():
		_draw_detail(vp)


# Title band: [param title] centred; HP and the gold count at the right.
func _draw_header(vp: Vector2, title: String) -> void:
	var band: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(band, band.get_center().y + TITLE_FONT_SIZE * 0.35, title, _fit(title, vp.x * 0.4, TITLE_FONT_SIZE), TITLE_COLOR)
	var right: float = vp.x * (1.0 - ScreenLayout.MARGIN_RATIO)
	var coin_left: float = draw_gold(self, right, band.get_center().y, _flow.get_gold(), GOLD_FONT_SIZE, TITLE_COLOR)
	var hp: String = tr(TEXT_HP) % [ceili(_hp()), ceili(_max_hp())]
	var width: float = ThemeDB.fallback_font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADER_FONT_SIZE).x
	draw_string(ThemeDB.fallback_font, Vector2(coin_left - COIN_GAP * 4.0 - width, band.get_center().y + HEADER_FONT_SIZE * 0.35), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADER_FONT_SIZE, HEADER_COLOR)


# One card / relic at rest rect [param base]: raised when selected, dimmed and stamped when sold.
func _draw_item(vp: Vector2, base: Rect2, kind: String, entry: Dictionary) -> void:
	var id: String = str(entry.get("id", ""))
	var sold: bool = bool(entry.get("sold", false))
	var selected: bool = not sold and str(_selected.get("kind", "")) == kind and str(_selected.get("id", "")) == id
	var rect: Rect2 = base
	if selected:
		draw_rect(Rect2(base.position + Vector2(6.0, 6.0), base.size), SHADOW_COLOR)
		rect.position.y -= ScreenLayout.shop_item_raise(vp)
	var rarity: String = _item_rarity(kind, id)
	var back: Color = CARD_BACK
	var border: Color = RelicStrip.rarity_color(rarity)
	var width: float = RARITY_BORDER
	if selected:
		border = SELECTED_OUTLINE
		width = SELECTED_BORDER
	elif not sold and str(_press_item.get("id", "")) == id and str(_press_item.get("kind", "")) == kind:
		border = PRESSED_OUTLINE
		width = SELECTED_BORDER
	if sold:
		back.a *= UiButtons.DIM_ALPHA
		border.a *= UiButtons.DIM_ALPHA
	draw_rect(rect, back)
	draw_rect(rect, border, false, width)
	if sold:
		_text(rect, rect.get_center().y + SOLD_FONT_SIZE * 0.35, tr(TEXT_SOLD), SOLD_FONT_SIZE, SOLD_COLOR)
		return
	if kind == KIND_CARD:
		_draw_card_body(rect, id)
	else:
		_draw_relic_body(rect, id)
	var price: String = tr(TEXT_PRICE) % int(entry.get("price", 0))
	var short: bool = _short(kind, id)
	_text(rect, rect.position.y + rect.size.y * PRICE_BASELINE, price, PRICE_FONT_SIZE, PRICE_SHORT_COLOR if short else PRICE_COLOR)


func _draw_card_body(rect: Rect2, id: String) -> void:
	var levels: Dictionary = _flow.get_deck_levels()
	var current: int = int(levels.get(id, 0))
	var shown: int = current + 1 if current > 0 else 1
	var skill: Dictionary = _flow.get_cards().resolved(id, shown)
	var inner: float = rect.size.x * (1.0 - PAD_RATIO * 2.0)
	var name: String = tr(str(skill.get("name_key", id)))
	_text(rect, rect.position.y + rect.size.y * CARD_NAME_BASELINE, name, _fit(name, inner, NAME_FONT_SIZE), NAME_COLOR)
	var line: String = tr(RARITY_KEY_FORMAT % str(skill.get("rarity", "common")))
	var line_color: Color = BODY_COLOR
	if current > 0:
		line = tr(TEXT_UPGRADE_TO) % shown
		line_color = UPGRADE_COLOR
	_text(rect, rect.position.y + rect.size.y * CARD_RARITY_BASELINE, line, _fit(line, inner, RARITY_FONT_SIZE), line_color)
	var stats: String = _stats_line(skill)
	_text(rect, rect.position.y + rect.size.y * CARD_STATS_BASELINE, stats, _fit(stats, inner, STAT_FONT_SIZE), STAT_COLOR)
	var desc: String = tr(str(skill.get("desc_key", "")))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(rect.position.x + rect.size.x * PAD_RATIO, rect.position.y + rect.size.y * CARD_DESC_TOP + DESC_FONT_SIZE), desc, HORIZONTAL_ALIGNMENT_CENTER, inner, DESC_FONT_SIZE, DESC_MAX_LINES, BODY_COLOR)


func _draw_relic_body(rect: Rect2, id: String) -> void:
	var info: Dictionary = RelicRegistry.shared_config().get_relic(id)
	var pad: float = rect.size.x * PAD_RATIO
	var icon: float = rect.size.y * RELIC_ICON_SIZE_RATIO
	RelicStrip.draw_icon(self, Rect2(rect.position + Vector2(pad, pad), Vector2(icon, icon)), id, 3.0, false, 0.0)
	var text_left: float = rect.position.x + pad * 2.0 + icon
	var text_width: float = rect.end.x - pad - text_left
	var name: String = tr(str(info.get("name_key", id)))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(text_left, rect.position.y + pad + icon * 0.45), name, HORIZONTAL_ALIGNMENT_LEFT, text_width, _fit(name, text_width, NAME_FONT_SIZE - 2), NAME_COLOR)
	var rarity: String = RelicStrip.rarity_line(info)
	draw_string(font, Vector2(text_left, rect.position.y + pad + icon * 0.9), rarity, HORIZONTAL_ALIGNMENT_LEFT, text_width, _fit(rarity, text_width, RARITY_FONT_SIZE), BODY_COLOR)
	var desc: String = tr(str(info.get("desc_key", "")))
	draw_multiline_string(font, Vector2(rect.position.x + pad, rect.position.y + rect.size.y * RELIC_DESC_TOP + DESC_FONT_SIZE), desc, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - pad * 2.0, DESC_FONT_SIZE, RELIC_DESC_MAX_LINES, BODY_COLOR)


# One service button: name, a one-line description, the price (red when short) or "Đã dùng".
func _draw_service(rect: Rect2, id: String, back: Color) -> void:
	var entry: Dictionary = _entry(KIND_SERVICE, id)
	var used: bool = bool(entry.get("used", false))
	var selected: bool = str(_selected.get("kind", "")) == KIND_SERVICE and str(_selected.get("id", "")) == id
	var fill: Color = UiButtons.PRESSED_BACK if (not used and UiButtons.is_pressed_at(self, rect)) else back
	var outline: Color = SELECTED_OUTLINE if selected else UiButtons.OUTLINE
	var text: Color = SERVICE_TEXT
	if used:
		fill.a *= UiButtons.DIM_ALPHA
		outline.a *= UiButtons.DIM_ALPHA
		text.a *= UiButtons.DIM_ALPHA
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, SELECTED_BORDER if selected else UiButtons.OUTLINE_WIDTH)
	var inner: float = rect.size.x * (1.0 - PAD_RATIO * 2.0)
	var name: String = tr(TEXT_SERVICE_REMOVE_NAME if id == SERVICE_REMOVE else TEXT_SERVICE_HEAL_NAME)
	_text(rect, rect.position.y + rect.size.y * SERVICE_NAME_BASELINE, name, _fit(name, inner, SERVICE_NAME_FONT_SIZE), text)
	var desc: String = tr(TEXT_SERVICE_REMOVE_DESC) if id == SERVICE_REMOVE else tr(TEXT_SERVICE_HEAL_DESC) % roundi(float(_flow.get_shop().get("heal_ratio", 0.0)) * 100.0)
	_text(rect, rect.position.y + rect.size.y * SERVICE_DESC_BASELINE, desc, _fit(desc, inner, SERVICE_DESC_FONT_SIZE), text)
	var price: String = tr(TEXT_USED) if used else tr(TEXT_PRICE) % int(entry.get("price", 0))
	var price_color: Color = text if used else (SERVICE_PRICE_SHORT if _short(KIND_SERVICE, id) else SERVICE_PRICE)
	_text(rect, rect.position.y + rect.size.y * SERVICE_PRICE_BASELINE, price, SERVICE_PRICE_FONT_SIZE, price_color)


func _draw_message(vp: Vector2) -> void:
	if _message.is_empty():
		return
	var rect: Rect2 = ScreenLayout.shop_message_rect(vp)
	_text(rect, rect.get_center().y + MESSAGE_FONT_SIZE * 0.35, _message, _fit(_message, rect.size.x, MESSAGE_FONT_SIZE), MESSAGE_BAD_COLOR if _message_bad else MESSAGE_COLOR)


# Long-press panel: name, rarity / upgrade line, stats, the full text, "Chạm để đóng".
func _draw_detail(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), DETAIL_DIM)
	var panel: Rect2 = ScreenLayout.shop_detail_rect(vp)
	var kind: String = str(_detail.get("kind", ""))
	var id: String = str(_detail.get("id", ""))
	draw_rect(panel, DETAIL_BACK)
	draw_rect(panel, RelicStrip.rarity_color(_item_rarity(kind, id)), false, RARITY_BORDER)
	var inner: float = panel.size.x * (1.0 - PAD_RATIO * 2.0)
	var y: float = panel.position.y + DETAIL_NAME_FONT_SIZE * 1.5
	var name: String = _item_name(kind, id)
	_text(panel, y, name, _fit(name, inner, DETAIL_NAME_FONT_SIZE), DETAIL_TEXT)
	var sub: String
	var desc: String
	if kind == KIND_RELIC:
		var info: Dictionary = RelicRegistry.shared_config().get_relic(id)
		sub = RelicStrip.rarity_line(info)
		desc = tr(str(info.get("desc_key", "")))
	else:
		var current: int = int(_flow.get_deck_levels().get(id, 0))
		var skill: Dictionary = _flow.get_cards().resolved(id, current + 1 if current > 0 else 1)
		sub = tr(RARITY_KEY_FORMAT % str(skill.get("rarity", "common"))) + SEPARATOR + _stats_line(skill)
		desc = tr(str(skill.get("desc_key", "")))
	y += DETAIL_FONT_SIZE * 1.8
	_text(panel, y, sub, _fit(sub, inner, DETAIL_FONT_SIZE), DETAIL_SUB_TEXT)
	y += DETAIL_FONT_SIZE * 1.8
	draw_multiline_string(ThemeDB.fallback_font, Vector2(panel.position.x + panel.size.x * PAD_RATIO, y), desc, HORIZONTAL_ALIGNMENT_LEFT, inner, DETAIL_FONT_SIZE, DETAIL_MAX_LINES, DETAIL_TEXT)
	_text(panel, panel.end.y - DETAIL_FONT_SIZE, tr(TEXT_DISMISS), DETAIL_FONT_SIZE, DETAIL_SUB_TEXT)


# Remove picker: title, the scrolling deck row, a hint, "Thôi" and the confirm button.
func _draw_picker(vp: Vector2) -> void:
	_draw_header(vp, tr(TEXT_PICK_REMOVE))
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var cards: SkillConfig = _flow.get_cards()
	var rects: Array[Rect2] = _picker.tile_rects(vp, entries.size())
	for i: int in rects.size():
		if rects[i].end.x < 0.0 or rects[i].position.x > vp.x:
			continue
		draw_deck_tile(self, rects[i], str(entries[i].get("id", "")), int(entries[i].get("level", 1)), cards, i == _picker.marked, not _removable(entries, i))
	if _picker.max_scroll(vp, entries.size()) > 0.0:
		var hint: Rect2 = ScreenLayout.deck_picker_hint_rect(vp)
		_text(hint, hint.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_DRAG_HINT), LABEL_FONT_SIZE, LABEL_COLOR)
	var cancel: Rect2 = ScreenLayout.shop_leave_rect(vp)
	UiButtons.draw_button(self, cancel, tr(TEXT_CANCEL), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, cancel), true, BUTTON_FONT_SIZE)
	if _picker.marked >= 0:
		var confirm: Rect2 = ScreenLayout.shop_buy_rect(vp)
		var label: String = tr(TEXT_CONFIRM_REMOVE) % _price(KIND_SERVICE, SERVICE_REMOVE)
		UiButtons.draw_button(self, confirm, label, UiButtons.Style.DANGER, UiButtons.is_pressed_at(self, confirm), true, _fit(label, confirm.size.x * 0.9, BUTTON_FONT_SIZE))
	_draw_message(vp)


func _item_rarity(kind: String, id: String) -> String:
	if kind == KIND_RELIC:
		return str(RelicRegistry.shared_config().get_relic(id).get("rarity", "common"))
	return _flow.get_cards().get_rarity(id)


# "cần 2 ô · 6 sát thương/ô · hồi 4 s".
func _stats_line(skill: Dictionary) -> String:
	var min_cells: int = int(skill.get("min_cells", 1))
	var parts: Array[String] = [tr(TEXT_CELLS_ANY) if min_cells <= 1 else tr(TEXT_CELLS) % min_cells]
	var damage: float = float(skill.get("damage_per_cell", 0.0))
	if damage > 0.0:
		parts.append(tr(TEXT_DAMAGE) % roundi(damage))
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	parts.append(tr(TEXT_COOLDOWN_NONE) if cooldown <= 0.0 else tr(TEXT_COOLDOWN) % roundi(cooldown))
	return SEPARATOR.join(parts)


func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	_centred(self, rect, y, text, size, color)


static func _centred(canvas: CanvasItem, rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	canvas.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


## Largest font size <= [param size] (not below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
static func _fit(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted
