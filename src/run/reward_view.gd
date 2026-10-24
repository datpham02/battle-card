class_name RewardView
extends Node2D
## Card reward screen (Story 019, Part B; Story 020): shown over the battle whenever the live run
## has an open card offer ([method GameFlow.get_pending_reward] non-empty while IN_NODE — or while
## MAP: a treasure node's offer and a resumed offer open over the chapter map, Story 022).
## Full-screen dim, a title, one card per offered id (ScreenLayout.reward_card_rects, offer order)
## with the card's name, its cell requirement, its damage per cell, its cooldown, a two-line effect
## text and the rarity as the border colour (plus a small rarity word), and — only when
## rewards.json `allow_skip` is true — a "Bỏ qua" button. Tap a card ->
## [method GameFlow.reward_chosen]; skip -> [method GameFlow.reward_skipped].
##
## Story 020: a card the deck already holds below max level (RewardRoller.is_upgrade) is titled
## with its current level ("Kiếm khí +1"), carries a gold "Nâng cấp → +2" line, and shows the
## numbers RESOLVED at the level the pick gives (SkillConfig.resolved); other cards show level 1.
## With rewards.json `allow_remove` a narrower fourth slot "Bỏ 1 lá" (ScreenLayout.
## reward_remove_slot_rect) opens the REMOVE LIST: the current deck as tiles (name + level, deck
## order, ScreenLayout.reward_remove_rects; at most 12 visible, a hint counts the rest), a tap
## -> [method GameFlow.reward_remove_requested] with the entry's deck index; "Thôi" returns to the
## offer. At or below min_deck_size the tiles draw disabled with a one-line hint.
##
## While shown EVERY pointer event is swallowed (the next match is frozen in INTRO or waits in
## BETWEEN; nothing under the dim may react). Enter / Keypad Enter / Space pick the FIRST card
## (or close the remove list while it is open). Esc is left to GameFlow. Child of Main added AFTER
## RunHudView: canvas items draw in tree order (it covers the HUD) and _input runs last-added
## first (it sees taps before the HUD, which also steps aside while an offer is open). Reads the
## flow through [member flow_path]; owns no run state (the list is a view mode that resets when
## the offer closes). Input dedup as in RunHudView (emulated copies — device ==
## InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Placeholder art; all strings are
## TEXT_* keys drawn through tr().
##
## Story 022: the title follows the node kind ([method GameFlow.get_pending_reward_kind]): a
## treasure offer is titled "KHO BÁU"; a miniboss offer carries the subtitle "Lá hiếm trở lên" and a
## boss offer "+N token bỏ lá" (ScreenLayout.reward_subtitle_rect). The "Bỏ 1 lá" slot shows ONLY
## while the run holds a removal token (RunSession.removal_tokens > 0) and reads "Bỏ 1 lá (N)";
## removing spends one (the flow).

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const TITLE_COLOR: Color = Color(0.95, 0.9, 0.78)
const CARD_BACK: Color = Color(1.0, 0.97, 0.9)
const CARD_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const NAME_COLOR: Color = Color(0.15, 0.12, 0.1)
const BODY_COLOR: Color = Color(0.3, 0.26, 0.22)
const STAT_COLOR: Color = Color(0.2, 0.4, 0.55)
const DIVIDER_COLOR: Color = Color(0.6, 0.52, 0.4, 0.5)
## Story 020: the "Nâng cấp → +N" line (gold) and the remove-list hint.
const UPGRADE_COLOR: Color = Color(0.72, 0.5, 0.05)
const HINT_COLOR: Color = Color(1.0, 0.75, 0.2)
## Story 022: the kind subtitle under the title.
const SUBTITLE_COLOR: Color = Color(0.75, 0.72, 0.65)
## Rarity border colours (common grey, rare blue, epic gold); unknown rarities draw as common.
const RARITY_COMMON_COLOR: Color = Color(0.55, 0.55, 0.58)
const RARITY_RARE_COLOR: Color = Color(0.25, 0.5, 0.95)
const RARITY_EPIC_COLOR: Color = Color(0.95, 0.72, 0.15)
const BORDER_WIDTH: float = 6.0
const DIVIDER_WIDTH: float = 2.0
## Border of a remove-list tile (thinner than a card).
const TILE_BORDER_WIDTH: float = 4.0

const TITLE_FONT_SIZE: int = 48
const NAME_FONT_SIZE: int = 34
const RARITY_FONT_SIZE: int = 20
const UPGRADE_FONT_SIZE: int = 22
const STAT_FONT_SIZE: int = 26
const DESC_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 32
const TILE_FONT_SIZE: int = 22
const HINT_FONT_SIZE: int = 24
const SUBTITLE_FONT_SIZE: int = 24
const MIN_FIT_FONT_SIZE: int = 18
## Line limit of the wrapped effect text (draw_multiline_string max_lines).
const DESC_MAX_LINES: int = 4

## Inner horizontal padding of a card as a share of its width.
const CARD_PAD_RATIO: float = 0.06
## Baselines inside a card as shares of its height (the wrapped block starts at its and grows down).
const NAME_BASELINE: float = 0.13
const RARITY_BASELINE: float = 0.21
const DIVIDER_1: float = 0.27
const UPGRADE_BASELINE: float = 0.335
const CELLS_BASELINE: float = 0.41
const DAMAGE_BASELINE: float = 0.48
const COOLDOWN_BASELINE: float = 0.55
const DIVIDER_2: float = 0.61
const DESC_BASELINE: float = 0.7
## Story 023: the keyword line (each keyword in its own colour) sits between the second divider and
## the description; with it the description starts at DESC_BASELINE_KEYWORD instead.
const KEYWORD_BASELINE: float = 0.665
const DESC_BASELINE_KEYWORD: float = 0.745
const KEYWORD_FONT_SIZE: int = 20
const KEYWORD_GAP: float = 10.0
const FRAGILE_COLOR: Color = Color(0.62, 0.32, 0.88)
const FROST_COLOR: Color = Color(0.3, 0.68, 0.95)
const PIERCE_COLOR: Color = Color(0.4, 0.45, 0.55)
const EXECUTE_COLOR: Color = Color(0.75, 0.12, 0.12)
## Decimals of the "x1.5 vs Fragile" multiplier.
const MULT_DECIMALS: int = 1

## Rarity ids as written in cards.json.
const RARITY_RARE: String = "rare"
const RARITY_EPIC: String = "epic"
## Separator between a card name and its level suffix.
const LEVEL_SEPARATOR: String = " "
## Story 022: node kinds with their own title / subtitle, and the rewards.json key of the boss token grant.
const KIND_TREASURE: String = "treasure"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
const CFG_BOSS_TOKENS: String = "boss_removal_tokens"

const TEXT_TITLE: String = "ui.reward.title"
## "cần %d ô" with the card's min_cells; [constant TEXT_CELLS_ANY] when it is 1 or less.
const TEXT_CELLS: String = "ui.reward.cells"
const TEXT_CELLS_ANY: String = "ui.reward.cells_any"
## "%d sát thương/ô" with the card's damage_per_cell; skipped when it is 0 (burn / pin cards).
const TEXT_DAMAGE: String = "ui.reward.damage"
## "hồi %d s" with the card's cooldown_sec (rounded); [constant TEXT_COOLDOWN_NONE] when it is 0.
const TEXT_COOLDOWN: String = "ui.reward.cooldown"
const TEXT_COOLDOWN_NONE: String = "ui.reward.cooldown_none"
const TEXT_SKIP: String = "ui.reward.skip"
const TEXT_RARITY_COMMON: String = "ui.rarity.common"
const TEXT_RARITY_RARE: String = "ui.rarity.rare"
const TEXT_RARITY_EPIC: String = "ui.rarity.epic"
## Story 020: "+%d" after a card name, "Nâng cấp → +%d" (the level after the pick), the remove
## slot, the remove list's title / cancel / minimum-size hint and "… và %d lá nữa" for hidden entries.
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"
## Story 023 keyword line: "Rạn +N", "Hàn +N", "Xuyên giáp", "Hành quyết", "×1.5 khi Rạn".
const TEXT_KEYWORD_FRAGILE_STACKS: String = "keyword.fragile_stacks"
const TEXT_KEYWORD_FROST_STACKS: String = "keyword.frost_stacks"
const TEXT_KEYWORD_PIERCE: String = "keyword.pierce"
const TEXT_KEYWORD_EXECUTE: String = "keyword.execute"
const TEXT_KEYWORD_VS_FRAGILE: String = "keyword.vs_fragile"
const TEXT_UPGRADE_TO: String = "ui.reward.upgrade_to"
const TEXT_REMOVE: String = "ui.reward.remove"
const TEXT_REMOVE_TITLE: String = "ui.reward.remove_title"
const TEXT_CANCEL: String = "ui.reward.cancel"
const TEXT_MIN_DECK: String = "ui.reward.min_deck"
const TEXT_MORE: String = "ui.reward.more"
## Story 022: the treasure title, the miniboss / boss subtitles and "Bỏ 1 lá (%d)" with the token count.
const TEXT_TITLE_TREASURE: String = "ui.reward.title_treasure"
const TEXT_MIN_RARE: String = "ui.reward.min_rare"
const TEXT_TOKEN_GRANTED: String = "ui.reward.token_granted"
const TEXT_REMOVE_COUNT: String = "ui.reward.remove_count"

## Path to the GameFlow (a sibling under Main) that owns the run.
@export var flow_path: NodePath = NodePath("../GameFlow")

var _flow: GameFlow = null
## Story 020: true while the remove list covers the offer.
var _removing: bool = false


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if _removing and not is_shown():
		_removing = false
	queue_redraw()


## True while the screen is up: IN_NODE or MAP with an open offer.
func is_shown() -> bool:
	if _flow == null or _flow.get_pending_reward().is_empty():
		return false
	var phase: int = _flow.get_phase()
	return phase == GameFlow.Phase.IN_NODE or phase == GameFlow.Phase.MAP


## Story 020: true while the remove list is open over the offer.
func is_remove_list_shown() -> bool:
	return is_shown() and _removing


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_shown():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if _removing:
				_removing = false
				return
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
	if _removing:
		_input_remove_list(pos, vp)
		return
	var offer: Array[String] = _flow.get_pending_reward()
	if _can_remove() and ScreenLayout.reward_remove_slot_rect(vp, offer.size()).has_point(pos):
		_removing = true
		return
	if _can_skip() and ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_flow.reward_skipped()
		return
	var rects: Array[Rect2] = ScreenLayout.reward_card_rects(vp, offer.size(), _can_remove())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			_flow.reward_chosen(offer[i])
			return


# Story 020, remove list: "Thôi" closes it; a tile (when the deck is above the minimum) removes
# that deck entry and closes it (the flow continues the run).
func _input_remove_list(pos: Vector2, vp: Vector2) -> void:
	if ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_removing = false
		return
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	if not _entries_removable(entries.size()):
		return
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			_removing = false
			_flow.reward_remove_requested(i)
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


# Story 020: rewards.json allow_remove (the slot shows even at minimum size: the list explains).
# Story 022: and only while the run holds a removal token.
func _can_remove() -> bool:
	return bool(_flow.get_reward_config().get("allow_remove", false)) and _removal_tokens() > 0


# Story 022: the run's removal tokens (0 without a run).
func _removal_tokens() -> int:
	var run: RunSession = _flow.get_run()
	return 0 if run == null else run.removal_tokens


# Story 022: the node kind the open offer belongs to.
func _reward_kind() -> String:
	return _flow.get_pending_reward_kind()


# Story 020: true when a deck of [param size] may lose a card (above rewards.json min_deck_size).
func _entries_removable(size: int) -> bool:
	return size > int(_flow.get_reward_config().get("min_deck_size", 0))


# Story 020: the level cap offers stop at (rewards.json max_card_level, else SkillConfig.MAX_LEVEL).
func _max_level() -> int:
	return int(_flow.get_reward_config().get("max_card_level", SkillConfig.MAX_LEVEL))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_shown():
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	if _removing:
		_draw_remove_list(vp)
		return
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	var kind: String = _reward_kind()
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE_TREASURE if kind == KIND_TREASURE else TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR)
	var subtitle: String = ""
	if kind == KIND_MINIBOSS:
		subtitle = tr(TEXT_MIN_RARE)
	elif kind == KIND_BOSS:
		subtitle = tr(TEXT_TOKEN_GRANTED) % int(RunSession.cfg(_flow.get_reward_config(), CFG_BOSS_TOKENS))
	if not subtitle.is_empty():
		var strip: Rect2 = ScreenLayout.reward_subtitle_rect(vp)
		_text(strip, strip.get_center().y + SUBTITLE_FONT_SIZE * 0.35, subtitle, SUBTITLE_FONT_SIZE, SUBTITLE_COLOR)
	var offer: Array[String] = _flow.get_pending_reward()
	var with_remove: bool = _can_remove()
	var rects: Array[Rect2] = ScreenLayout.reward_card_rects(vp, offer.size(), with_remove)
	var levels: Dictionary = _flow.get_deck_levels()
	for i: int in rects.size():
		_draw_card(rects[i], offer[i], levels)
	if with_remove:
		var slot: Rect2 = ScreenLayout.reward_remove_slot_rect(vp, offer.size())
		var slot_text: String = tr(TEXT_REMOVE_COUNT) % _removal_tokens()
		UiButtons.draw_button(self, slot, slot_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, slot), true, _fit_font_size(slot_text, slot.size.x - slot.size.x * CARD_PAD_RATIO * 2.0, BUTTON_FONT_SIZE))
	if _can_skip():
		var skip: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
		UiButtons.draw_button(self, skip, tr(TEXT_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, BUTTON_FONT_SIZE)


# One offer card. [param levels] is the deck's id -> highest level: a held card below max is an
# upgrade (title with its current level, gold "Nâng cấp → +N", numbers resolved at N).
func _draw_card(rect: Rect2, id: String, levels: Dictionary) -> void:
	var upgrade: bool = RewardRoller.is_upgrade(id, levels, _max_level())
	var current: int = int(levels.get(id, 0))
	var shown_level: int = current + 1 if upgrade else 1
	var skill: Dictionary = _flow.get_cards().resolved(id, shown_level)
	var rarity: String = str(skill.get("rarity", ""))
	var pressed: bool = UiButtons.is_pressed_at(self, rect)
	draw_rect(rect, CARD_BACK)
	draw_rect(rect, CARD_PRESSED_OUTLINE if pressed else _rarity_color(rarity), false, BORDER_WIDTH)
	var pad: float = rect.size.x * CARD_PAD_RATIO
	var inner := Rect2(rect.position.x + pad, rect.position.y, rect.size.x - pad * 2.0, rect.size.y)
	var title: String = tr(str(skill.get("name_key", id)))
	if upgrade:
		title += LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % current
	_text(inner, _y(rect, NAME_BASELINE), title, NAME_FONT_SIZE, NAME_COLOR)
	_text(inner, _y(rect, RARITY_BASELINE), tr(_rarity_key(rarity)), RARITY_FONT_SIZE, _rarity_color(rarity).darkened(0.2))
	_divider(inner, _y(rect, DIVIDER_1))
	if upgrade:
		_text(inner, _y(rect, UPGRADE_BASELINE), tr(TEXT_UPGRADE_TO) % shown_level, UPGRADE_FONT_SIZE, UPGRADE_COLOR)
	var min_cells: int = int(skill.get("min_cells", 1))
	var cells: String = tr(TEXT_CELLS_ANY) if min_cells <= 1 else tr(TEXT_CELLS) % min_cells
	_text(inner, _y(rect, CELLS_BASELINE), cells, STAT_FONT_SIZE, STAT_COLOR)
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	if damage > 0:
		_text(inner, _y(rect, DAMAGE_BASELINE), tr(TEXT_DAMAGE) % damage, STAT_FONT_SIZE, STAT_COLOR)
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	var cooldown_text: String = tr(TEXT_COOLDOWN_NONE) if cooldown <= 0.0 else tr(TEXT_COOLDOWN) % roundi(cooldown)
	_text(inner, _y(rect, COOLDOWN_BASELINE), cooldown_text, STAT_FONT_SIZE, STAT_COLOR)
	_divider(inner, _y(rect, DIVIDER_2))
	var keywords: Array = _keyword_parts(skill)
	var desc_y: float = _y(rect, DESC_BASELINE)
	if not keywords.is_empty():
		_draw_keyword_line(inner, _y(rect, KEYWORD_BASELINE), keywords)
		desc_y = _y(rect, DESC_BASELINE_KEYWORD)
	draw_multiline_string(ThemeDB.fallback_font, Vector2(inner.position.x, desc_y), tr(str(skill.get("desc_key", ""))), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, DESC_FONT_SIZE, DESC_MAX_LINES, BODY_COLOR)


# Story 023: [text, colour] pairs of the keywords a resolved card carries, in a fixed order
# (Rạn stacks, Hàn stacks, pierce, execute, the Rạn bonus); empty for a plain card.
func _keyword_parts(skill: Dictionary) -> Array:
	var parts: Array = []
	var fragile: int = int(skill.get("fragile_stacks", 0))
	if fragile > 0:
		parts.append([tr(TEXT_KEYWORD_FRAGILE_STACKS) % fragile, FRAGILE_COLOR])
	var frost: int = int(skill.get("frost_stacks", 0))
	if frost > 0:
		parts.append([tr(TEXT_KEYWORD_FROST_STACKS) % frost, FROST_COLOR])
	if bool(skill.get("pierce_defense", false)):
		parts.append([tr(TEXT_KEYWORD_PIERCE), PIERCE_COLOR])
	if bool(skill.get("execute", false)) or float(skill.get("execute_ratio", 0.0)) > 0.0:
		parts.append([tr(TEXT_KEYWORD_EXECUTE), EXECUTE_COLOR])
	var vs_fragile: float = float(skill.get("bonus_vs_fragile_mult", 1.0))
	if vs_fragile > 1.0:
		parts.append([tr(TEXT_KEYWORD_VS_FRAGILE) % String.num(vs_fragile, MULT_DECIMALS), FRAGILE_COLOR])
	return parts


# One centred line of coloured [param parts] KEYWORD_GAP apart; the font shrinks (never below
# MIN_FIT_FONT_SIZE) until the whole line fits [param inner].
func _draw_keyword_line(inner: Rect2, y: float, parts: Array) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = KEYWORD_FONT_SIZE
	while size > MIN_FIT_FONT_SIZE and _parts_width(parts, size) > inner.size.x:
		size -= 1
	var x: float = inner.get_center().x - _parts_width(parts, size) * 0.5
	for part: Array in parts:
		draw_string(font, Vector2(x, y), str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, part[1])
		x += font.get_string_size(str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + KEYWORD_GAP


# Width of [param parts] in a row at [param size], gaps included (none after the last).
func _parts_width(parts: Array, size: int) -> float:
	var font: Font = ThemeDB.fallback_font
	var width: float = 0.0
	for part: Array in parts:
		width += font.get_string_size(str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return width + KEYWORD_GAP * maxi(parts.size() - 1, 0)


# Story 020: the remove list — title, one tile per deck entry (name + level, rarity border; dimmed
# at minimum deck size), the hint line and the "Thôi" button (in the skip button's place).
func _draw_remove_list(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_REMOVE_TITLE), TITLE_FONT_SIZE, TITLE_COLOR)
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var enabled: bool = _entries_removable(entries.size())
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	var cards: SkillConfig = _flow.get_cards()
	for i: int in rects.size():
		var id: String = str(entries[i].get("id", ""))
		var level: int = int(entries[i].get("level", 1))
		var skill: Dictionary = cards.resolved(id, level)
		var label: String = tr(str(skill.get("name_key", id))) + LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
		var pressed: bool = enabled and UiButtons.is_pressed_at(self, rects[i])
		var back: Color = CARD_BACK
		var border: Color = CARD_PRESSED_OUTLINE if pressed else _rarity_color(str(skill.get("rarity", "")))
		var name_color: Color = NAME_COLOR
		if not enabled:
			back.a *= UiButtons.DIM_ALPHA
			border.a *= UiButtons.DIM_ALPHA
			name_color.a *= UiButtons.DIM_ALPHA
		draw_rect(rects[i], back)
		draw_rect(rects[i], border, false, TILE_BORDER_WIDTH)
		_text(rects[i], rects[i].get_center().y + TILE_FONT_SIZE * 0.35, label, TILE_FONT_SIZE, name_color)
	var hint: Rect2 = ScreenLayout.reward_remove_hint_rect(vp)
	if not enabled:
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_MIN_DECK), HINT_FONT_SIZE, HINT_COLOR)
	elif entries.size() > rects.size():
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_MORE) % (entries.size() - rects.size()), HINT_FONT_SIZE, TITLE_COLOR)
	var cancel: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
	UiButtons.draw_button(self, cancel, tr(TEXT_CANCEL), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, cancel), true, BUTTON_FONT_SIZE)


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


# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits in
# [param width] pixels, so a long translation ("Remove a card") shrinks instead of clipping.
func _fit_font_size(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted
