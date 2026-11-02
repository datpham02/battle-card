class_name RestView
extends Node2D
## Rest site screen (Story 022, Part C): shown in phase REST, after the player took a `rest` node.
## Full-screen dim, the title "TRẠI NGHỈ" and two big choice cards (ScreenLayout.rest_card_rects):
## "Nghỉ" with "+%d máu" (rewards.json `rest_heal_ratio` x the character's max HP — read from the
## config, never a literal) -> [method GameFlow.rest_heal_requested], and "Rèn" with "+%d cấp một
## lá" (`rest_forge_levels`) which opens the FORGE LIST: the deck as tiles in deck order
## (ScreenLayout.reward_remove_rects, the Story 020 remove-list layout; name + level, rarity
## border), entries already at SkillConfig.MAX_LEVEL drawn disabled; a tap on an enabled tile ->
## [method GameFlow.rest_forge_requested] with the entry's deck index; "Thôi" returns to the two
## cards. Enter / Keypad Enter / Space = "Nghỉ" (or close the list while it is open).
## While shown EVERY pointer event is swallowed. Child of Main added AFTER RewardView (draws over
## everything; _input runs last-added first). Reads the flow through [member flow_path]; owns no
## run state (the list is a view mode that resets when the phase changes). Input dedup as in
## RunHudView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never
## act). Placeholder art; all strings are TEXT_* keys drawn through tr().

enum Mode { CHOICE, FORGE }

## 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): the dark HudSkin palette. DIM_COLOR is kept for
## reference; the screen now draws HudSkin.screen_background.
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const TITLE_COLOR: Color = HudSkin.IVORY
const CARD_BACK: Color = HudSkin.CARD_FILL
const CARD_PRESSED_OUTLINE: Color = HudSkin.GRID_LIGHT
const HEAL_OUTLINE: Color = HudSkin.HP_FILL
const FORGE_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const NAME_COLOR: Color = HudSkin.IVORY
const BODY_COLOR: Color = HudSkin.TEXT
const HINT_COLOR: Color = HudSkin.GRID_LIGHT
const GLYPH_COLOR: Color = HudSkin.TEXT_DIM
## Frame of a choice card (pressed: CARD_PRESSED_OUTLINE at PRESSED_BORDER_WIDTH, fill lightened).
const BORDER_WIDTH: float = 2.0
const PRESSED_BORDER_WIDTH: float = 3.0
const TILE_BORDER_WIDTH: float = 3.0
const GLYPH_WIDTH: float = 6.0

const TITLE_FONT_SIZE: int = 48
const NAME_FONT_SIZE: int = 48
const LINE_FONT_SIZE: int = 30
const TILE_FONT_SIZE: int = 22
const HINT_FONT_SIZE: int = 24
const BUTTON_FONT_SIZE: int = 32
## Smallest size [method _text] shrinks a line to so it fits its rect.
const MIN_FIT_FONT_SIZE: int = 14

## Baselines inside a choice card as shares of its height, and the glyph box (centre y, half size
## as a share of the card width).
const NAME_BASELINE: float = 0.62
const LINE_BASELINE: float = 0.74
const GLYPH_CENTER_Y: float = 0.35
const GLYPH_HALF: float = 0.12
## Separator between a card name and its level suffix.
const LEVEL_SEPARATOR: String = " "
## rewards.json keys of the heal share and the forge step (RunSession.cfg defaults when absent).
const CFG_HEAL_RATIO: String = "rest_heal_ratio"
const CFG_FORGE_LEVELS: String = "rest_forge_levels"

const TEXT_TITLE: String = "ui.rest.title"
const TEXT_HEAL: String = "ui.rest.heal"
## "+%d máu" with rest_heal_ratio x max HP.
const TEXT_HEAL_AMOUNT: String = "ui.rest.heal_amount"
const TEXT_FORGE: String = "ui.rest.forge"
## "+%d cấp một lá" with rest_forge_levels.
const TEXT_FORGE_HINT: String = "ui.rest.forge_hint"
const TEXT_FORGE_TITLE: String = "ui.rest.forge_title"
const TEXT_CANCEL: String = "ui.rest.cancel"
## Hint under the list when every card is at the cap, and "… và %d lá nữa" for hidden entries.
const TEXT_ALL_MAXED: String = "ui.rest.all_maxed"
const TEXT_MORE: String = "ui.rest.more"
## "+%d" after a card name (shared with the reward screen).
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"

## Path to the GameFlow (a sibling under Main) that owns the run.
@export var flow_path: NodePath = NodePath("../GameFlow")

var _flow: GameFlow = null
var _mode: Mode = Mode.CHOICE
## rewards.json (RewardRoller.load_config), read once.
var _config: Dictionary = {}


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow
	_config = RewardRoller.load_config()


func _process(_delta: float) -> void:
	if not is_shown():
		_mode = Mode.CHOICE
		queue_redraw()  # clear the last frame (see TitleView)
		return
	queue_redraw()


## True while the screen is up (phase REST with a live run).
func is_shown() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.REST and _flow.get_run() != null


## True while the forge list covers the two cards.
func is_forge_list_shown() -> bool:
	return is_shown() and _mode == Mode.FORGE


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_shown():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if _mode == Mode.FORGE:
				_mode = Mode.CHOICE
			else:
				_flow.rest_heal_requested()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _mode == Mode.FORGE:
		_input_forge_list(pos, vp)
		return
	var cards: Array[Rect2] = ScreenLayout.rest_card_rects(vp)
	if cards[0].has_point(pos):
		_flow.rest_heal_requested()
	elif cards[1].has_point(pos):
		_mode = Mode.FORGE


# Forge list: "Thôi" closes it; an enabled tile (below the level cap) forges that deck entry.
func _input_forge_list(pos: Vector2, vp: Vector2) -> void:
	if ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_mode = Mode.CHOICE
		return
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			if _can_forge(entries[i]):
				_mode = Mode.CHOICE
				_flow.rest_forge_requested(i)
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


# --- State --------------------------------------------------------------------


# True when a deck entry may still be forged (below SkillConfig.MAX_LEVEL, the cap RunSession.rest_forge applies).
func _can_forge(entry: Dictionary) -> bool:
	return int(entry.get("level", 1)) < SkillConfig.MAX_LEVEL and not _flow.get_cards().is_curse(str(entry.get("id", "")))


# HP the "Nghỉ" choice restores: rest_heal_ratio x the character's max HP.
func _heal_amount() -> int:
	var run: RunSession = _flow.get_run()
	var max_hp: float = float(_flow.get_characters().get_character(run.character_id).get("max_hp", 1.0))
	return roundi(RunSession.cfg(_config, CFG_HEAL_RATIO) * max_hp)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_shown():
		return
	var vp: Vector2 = get_viewport_rect().size
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp))
	if _mode == Mode.FORGE:
		_draw_forge_list(vp)
		return
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, true)
	var cards: Array[Rect2] = ScreenLayout.rest_card_rects(vp)
	_draw_card(cards[0], tr(TEXT_HEAL), tr(TEXT_HEAL_AMOUNT) % _heal_amount(), HEAL_OUTLINE, true)
	_draw_card(cards[1], tr(TEXT_FORGE), tr(TEXT_FORGE_HINT) % int(RunSession.cfg(_config, CFG_FORGE_LEVELS)), FORGE_OUTLINE, false)


# One choice card: back, outline (gold while pressed), a glyph (flame for rest, anvil for forge),
# the name and its one-line effect.
func _draw_card(rect: Rect2, name: String, line: String, outline: Color, heal: bool) -> void:
	var pressed: bool = UiButtons.is_pressed_at(self, rect)
	var fill: Color = CARD_BACK.lightened(HudSkin.BUTTON_PRESSED_LIGHTEN) if pressed else CARD_BACK
	HudSkin.panel(self, rect, [0.0, HudSkin.button_cut(rect), 0.0, 0.0], fill, CARD_PRESSED_OUTLINE if pressed else outline, PRESSED_BORDER_WIDTH if pressed else BORDER_WIDTH)
	var c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * GLYPH_CENTER_Y)
	var h: float = rect.size.x * GLYPH_HALF
	if heal:
		# A faceted flame (HudSkin.flame_points), twice.
		draw_polyline(HudSkin.flame_points(c, h), GLYPH_COLOR, GLYPH_WIDTH)
		draw_polyline(HudSkin.flame_points(c + Vector2(0.0, h * 0.35), h * 0.45), GLYPH_COLOR, GLYPH_WIDTH)
	else:
		# An anvil: a wide top, a narrow neck, a base.
		draw_rect(Rect2(c + Vector2(-h, -h * 0.6), Vector2(h * 2.0, h * 0.5)), GLYPH_COLOR)
		draw_rect(Rect2(c + Vector2(-h * 0.35, -h * 0.1), Vector2(h * 0.7, h * 0.5)), GLYPH_COLOR)
		draw_rect(Rect2(c + Vector2(-h * 0.8, h * 0.4), Vector2(h * 1.6, h * 0.3)), GLYPH_COLOR)
	_text(rect, rect.position.y + rect.size.y * NAME_BASELINE, name, NAME_FONT_SIZE, NAME_COLOR, true)
	_text(rect, rect.position.y + rect.size.y * LINE_BASELINE, line, LINE_FONT_SIZE, BODY_COLOR)


# The forge list — title, one tile per deck entry (name + level, rarity border; dimmed at the level
# cap), the hint line and the "Thôi" button (in the reward screen's skip button place).
func _draw_forge_list(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_FORGE_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, true)
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	var cards: SkillConfig = _flow.get_cards()
	var any_enabled: bool = false
	for i: int in rects.size():
		var id: String = str(entries[i].get("id", ""))
		var level: int = int(entries[i].get("level", 1))
		var skill: Dictionary = cards.resolved(id, level)
		var label: String = tr(str(skill.get("name_key", id))) + LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
		var enabled: bool = _can_forge(entries[i])
		any_enabled = any_enabled or enabled
		var pressed: bool = enabled and UiButtons.is_pressed_at(self, rects[i])
		var back: Color = CARD_BACK.lightened(HudSkin.BUTTON_PRESSED_LIGHTEN) if pressed else CARD_BACK
		var border: Color = CARD_PRESSED_OUTLINE if pressed else _rarity_color(str(skill.get("rarity", "")))
		var name_color: Color = NAME_COLOR
		if not enabled:
			back.a *= UiButtons.DIM_ALPHA
			border.a *= UiButtons.DIM_ALPHA
			name_color.a *= UiButtons.DIM_ALPHA
		HudSkin.panel(self, rects[i], [0.0, HudSkin.button_cut(rects[i]), 0.0, 0.0], back, border, TILE_BORDER_WIDTH if pressed else BORDER_WIDTH)
		_text(rects[i], rects[i].get_center().y + TILE_FONT_SIZE * 0.35, label, TILE_FONT_SIZE, name_color)
	var hint: Rect2 = ScreenLayout.reward_remove_hint_rect(vp)
	if not any_enabled:
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_ALL_MAXED), HINT_FONT_SIZE, HINT_COLOR)
	elif entries.size() > rects.size():
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_MORE) % (entries.size() - rects.size()), HINT_FONT_SIZE, TITLE_COLOR)
	var cancel: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
	UiButtons.draw_button(self, cancel, tr(TEXT_CANCEL), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, cancel), true, BUTTON_FONT_SIZE)


# Border colour of a rarity id (the reward screen's colours; common for anything unknown).
func _rarity_color(rarity: String) -> Color:
	match rarity:
		RewardView.RARITY_RARE:
			return RewardView.RARITY_RARE_COLOR
		RewardView.RARITY_EPIC:
			return RewardView.RARITY_EPIC_COLOR
	return RewardView.RARITY_COMMON_COLOR


# Centred single-line HudSkin outlined text at baseline [param y] over the width of [param rect]; shrunk (floor
# MIN_FIT_FONT_SIZE) until it fits the rect, Bold when [param bold].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > rect.size.x:
		fitted -= 1
	MenuFont.text(self, Vector2(rect.position.x, y), text, fitted, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)
