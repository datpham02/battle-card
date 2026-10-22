class_name RewardView
extends Node2D
## Card reward screen (Story 019, Part B): shown over the battle whenever the live run has an open
## card offer ([method GameFlow.get_pending_reward] non-empty while IN_FLOOR). Full-screen dim, a
## title, one card per offered id (ScreenLayout.reward_card_rects, offer order) with the card's
## name, its cell requirement, its cooldown, a two-line effect text and the rarity as the border
## colour (plus a small rarity word), and — only when rewards.json `allow_skip` is true — a
## "Bỏ qua" button. Tap a card -> [method GameFlow.reward_chosen]; skip ->
## [method GameFlow.reward_skipped]. While shown EVERY pointer event is swallowed (the next match
## is frozen in INTRO or waits in BETWEEN; nothing under the dim may react) and Enter / Keypad
## Enter / Space pick the FIRST card. Esc is left to GameFlow. Child of Main added AFTER
## RunHudView: canvas items draw in tree order (it covers the HUD) and _input runs last-added
## first (it sees taps before the HUD, which also steps aside while an offer is open). Reads the
## flow through [member flow_path]; owns no run state. Input dedup as in RunHudView (emulated
## copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Placeholder
## art; all strings are TEXT_* keys drawn through tr().

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const TITLE_COLOR: Color = Color(0.95, 0.9, 0.78)
const CARD_BACK: Color = Color(1.0, 0.97, 0.9)
const CARD_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const NAME_COLOR: Color = Color(0.15, 0.12, 0.1)
const BODY_COLOR: Color = Color(0.3, 0.26, 0.22)
const STAT_COLOR: Color = Color(0.2, 0.4, 0.55)
const DIVIDER_COLOR: Color = Color(0.6, 0.52, 0.4, 0.5)
## Rarity border colours (common grey, rare blue, epic gold); unknown rarities draw as common.
const RARITY_COMMON_COLOR: Color = Color(0.55, 0.55, 0.58)
const RARITY_RARE_COLOR: Color = Color(0.25, 0.5, 0.95)
const RARITY_EPIC_COLOR: Color = Color(0.95, 0.72, 0.15)
const BORDER_WIDTH: float = 6.0
const DIVIDER_WIDTH: float = 2.0

const TITLE_FONT_SIZE: int = 48
const NAME_FONT_SIZE: int = 34
const RARITY_FONT_SIZE: int = 20
const STAT_FONT_SIZE: int = 26
const DESC_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 32
## Line limit of the wrapped effect text (draw_multiline_string max_lines).
const DESC_MAX_LINES: int = 2

## Inner horizontal padding of a card as a share of its width.
const CARD_PAD_RATIO: float = 0.06
## Baselines inside a card as shares of its height (the wrapped block starts at its and grows down).
const NAME_BASELINE: float = 0.13
const RARITY_BASELINE: float = 0.21
const DIVIDER_1: float = 0.28
const CELLS_BASELINE: float = 0.4
const COOLDOWN_BASELINE: float = 0.5
const DIVIDER_2: float = 0.58
const DESC_BASELINE: float = 0.68

## Rarity ids as written in cards.json.
const RARITY_RARE: String = "rare"
const RARITY_EPIC: String = "epic"

const TEXT_TITLE: String = "ui.reward.title"
## "cần %d ô" with the card's min_cells; [constant TEXT_CELLS_ANY] when it is 1 or less.
const TEXT_CELLS: String = "ui.reward.cells"
const TEXT_CELLS_ANY: String = "ui.reward.cells_any"
## "hồi %d s" with the card's cooldown_sec (rounded); [constant TEXT_COOLDOWN_NONE] when it is 0.
const TEXT_COOLDOWN: String = "ui.reward.cooldown"
const TEXT_COOLDOWN_NONE: String = "ui.reward.cooldown_none"
const TEXT_SKIP: String = "ui.reward.skip"
const TEXT_RARITY_COMMON: String = "ui.rarity.common"
const TEXT_RARITY_RARE: String = "ui.rarity.rare"
const TEXT_RARITY_EPIC: String = "ui.rarity.epic"

## Path to the GameFlow (a sibling under Main) that owns the run.
@export var flow_path: NodePath = NodePath("../GameFlow")

var _flow: GameFlow = null


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow


func _process(_delta: float) -> void:
	queue_redraw()


## True while the screen is up: IN_FLOOR with an open offer.
func is_shown() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.IN_FLOOR and not _flow.get_pending_reward().is_empty()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_shown():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			var offer: Array[String] = _flow.get_pending_reward()
			if not offer.is_empty():
				_flow.reward_chosen(offer[0])
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _can_skip() and ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_flow.reward_skipped()
		return
	var offer: Array[String] = _flow.get_pending_reward()
	var rects: Array[Rect2] = ScreenLayout.reward_card_rects(vp, offer.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			_flow.reward_chosen(offer[i])
			return


# Position of a left mouse press or a touch press; Vector2.INF for any other event.
func _press_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return touch.position
	return Vector2.INF


func _can_skip() -> bool:
	return bool(_flow.get_reward_config().get("allow_skip", true))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_shown():
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR)
	var offer: Array[String] = _flow.get_pending_reward()
	var rects: Array[Rect2] = ScreenLayout.reward_card_rects(vp, offer.size())
	for i: int in rects.size():
		_draw_card(rects[i], offer[i])
	if _can_skip():
		var skip: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
		UiButtons.draw_button(self, skip, tr(TEXT_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, BUTTON_FONT_SIZE)


func _draw_card(rect: Rect2, id: String) -> void:
	var skill: Dictionary = _flow.get_cards().get_skill(id)
	var rarity: String = str(skill.get("rarity", ""))
	var pressed: bool = UiButtons.is_pressed_at(self, rect)
	draw_rect(rect, CARD_BACK)
	draw_rect(rect, CARD_PRESSED_OUTLINE if pressed else _rarity_color(rarity), false, BORDER_WIDTH)
	var pad: float = rect.size.x * CARD_PAD_RATIO
	var inner := Rect2(rect.position.x + pad, rect.position.y, rect.size.x - pad * 2.0, rect.size.y)
	_text(inner, _y(rect, NAME_BASELINE), tr(str(skill.get("name_key", id))), NAME_FONT_SIZE, NAME_COLOR)
	_text(inner, _y(rect, RARITY_BASELINE), tr(_rarity_key(rarity)), RARITY_FONT_SIZE, _rarity_color(rarity).darkened(0.2))
	_divider(inner, _y(rect, DIVIDER_1))
	var min_cells: int = int(skill.get("min_cells", 1))
	var cells: String = tr(TEXT_CELLS_ANY) if min_cells <= 1 else tr(TEXT_CELLS) % min_cells
	_text(inner, _y(rect, CELLS_BASELINE), cells, STAT_FONT_SIZE, STAT_COLOR)
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	var cooldown_text: String = tr(TEXT_COOLDOWN_NONE) if cooldown <= 0.0 else tr(TEXT_COOLDOWN) % roundi(cooldown)
	_text(inner, _y(rect, COOLDOWN_BASELINE), cooldown_text, STAT_FONT_SIZE, STAT_COLOR)
	_divider(inner, _y(rect, DIVIDER_2))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(inner.position.x, _y(rect, DESC_BASELINE)), tr(str(skill.get("desc_key", ""))), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, DESC_FONT_SIZE, DESC_MAX_LINES, BODY_COLOR)


# Border colour of a rarity id (common for anything unknown).
func _rarity_color(rarity: String) -> Color:
	match rarity:
		RARITY_RARE:
			return RARITY_RARE_COLOR
		RARITY_EPIC:
			return RARITY_EPIC_COLOR
	return RARITY_COMMON_COLOR


# Label key of a rarity id (common for anything unknown).
func _rarity_key(rarity: String) -> String:
	match rarity:
		RARITY_RARE:
			return TEXT_RARITY_RARE
		RARITY_EPIC:
			return TEXT_RARITY_EPIC
	return TEXT_RARITY_COMMON


# Baseline y for a share of the card height.
func _y(rect: Rect2, share: float) -> float:
	return rect.position.y + rect.size.y * share


func _divider(inner: Rect2, y: float) -> void:
	draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), DIVIDER_COLOR, DIVIDER_WIDTH)


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)
