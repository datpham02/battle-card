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
##
## Story 033: the title band carries the gold — "+N vàng" with a coin at the left when the node just
## paid gold ([method GameFlow.get_last_gold_gain] > 0), the run's total at the right. The remove list
## counts only non-curse cards against min_deck_size; a curse tile (purple) is always removable.
##
## Story 034: while [method GameFlow.has_ink_offer] the screen also carries the INK ROW under the card row
## (and under the relic row on a treasure screen): the offered shapes as tiles (shape drawn with PieceDraw,
## name, the current mult as dots, a "new shape" tag for a run-only shape not owned yet). A tap (on
## release) selects a tile; the row's own confirm button (right end of the row) ->
## [method GameFlow.choose_ink], its small skip -> [method GameFlow.skip_ink_offer]. Neither closes the
## screen. The card row (and relic row) get shorter instead of moving the bottom buttons
## (ScreenLayout.reward_ink_*): the screen's skip / confirm stay in the bottom thumb zone.

## 2026-10-31 (whole-game skin): the backdrop is the skin's screen colour, nearly opaque, so the battle HUD or the
## map behind no longer shows through the reward rows.
const DIM_COLOR: Color = Color("17151D", 0.94)
const TITLE_COLOR: Color = HudSkin.IVORY
const CARD_BACK: Color = HudSkin.CARD_FILL
const CARD_PRESSED_OUTLINE: Color = HudSkin.GRID_LIGHT
const NAME_COLOR: Color = HudSkin.IVORY
const BODY_COLOR: Color = HudSkin.TEXT_DIM
const STAT_COLOR: Color = HudSkin.TEXT
const DIVIDER_COLOR: Color = Color(0.49, 0.53, 0.59, 0.5)
## Story 020: the "Nâng cấp → +N" line (gold) and the remove-list hint.
const UPGRADE_COLOR: Color = HudSkin.GRID_LIGHT
const HINT_COLOR: Color = HudSkin.GRID_LIGHT
## Story 022: the kind subtitle under the title.
const SUBTITLE_COLOR: Color = HudSkin.TEXT_DIM
## Rarity border colours (common grey, rare blue, epic gold); unknown rarities draw as common.
const RARITY_COMMON_COLOR: Color = Color(0.55, 0.55, 0.58)
const RARITY_RARE_COLOR: Color = Color(0.25, 0.5, 0.95)
const RARITY_EPIC_COLOR: Color = Color(0.95, 0.72, 0.15)
const BORDER_WIDTH: float = 6.0
## Story 033: the gold gain line (left of the title band) and the total (right).
const GOLD_GAIN_COLOR: Color = Color(1.0, 0.82, 0.3)
## 2026-10-31: rarity text is the rarity colour lightened by this share to read on the dark card face.
const RARITY_TEXT_LIGHTEN: float = 0.25
const GOLD_FONT_SIZE: int = 30
const GOLD_COIN_GAP: float = 8.0
## Story 033: "+%d vàng".
const TEXT_GOLD_GAIN: String = "ui.gold.gain"
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
const FRAGILE_COLOR: Color = Color(0.77, 0.59, 0.93)
const FROST_COLOR: Color = Color(0.44, 0.74, 0.96)
const PIERCE_COLOR: Color = Color(0.67, 0.7, 0.75)
const EXECUTE_COLOR: Color = Color(0.84, 0.43, 0.43)
## Story 027 zone keywords: Kết giới (seal, indigo like the board's seal block) and Trận gai (thorns, thorn green).
const SEAL_COLOR: Color = Color(0.62, 0.58, 0.82)
const THORN_COLOR: Color = Color(0.51, 0.79, 0.48)
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
## Story 027 zone keywords.
const TEXT_KEYWORD_THORNS: String = "keyword.thorns"
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

## Story 032: the treasure screen with a relic row ([method GameFlow.has_relic_offer]): the card row moves
## up and gets compact cards (COMPACT_* baselines as shares of the card height), the relic row of 3 large
## cards sits under it, "Bỏ qua" bottom-left ([method GameFlow.skip_relic_offer], both rows close) and
## "Xác nhận" bottom-right ([method GameFlow.choose_relic] with the selected relic; dim until one is
## picked). A card tap still takes the card at once (both rows close). The owned-relic strip
## (RelicStrip) sits at the bottom on both layouts.
const TEXT_CARDS_ROW: String = "ui.relic.cards_row"
const TEXT_RELICS_ROW: String = "ui.relic.relics_row"
const TEXT_RELIC_CONFIRM: String = "ui.relic.confirm"
const TEXT_RELIC_SKIP: String = "ui.relic.skip"
## Story 035: the Execute relic offer (after "Giết" on the fate screen): its title and hint line.
const TEXT_FATE_OFFER_TITLE: String = "ui.fate.offer_title"
const TEXT_FATE_OFFER_HINT: String = "ui.fate.offer_hint"
const ROW_LABEL_FONT_SIZE: int = 22
const RELIC_NAME_FONT_SIZE: int = 28
const RELIC_DESC_FONT_SIZE: int = 19
const RELIC_DESC_MAX_LINES: int = 3
const RELIC_ICON_RATIO: float = 0.36
const RELIC_SELECTED_BORDER: float = 10.0
const COMPACT_NAME_FONT_SIZE: int = 22
const COMPACT_STAT_FONT_SIZE: int = 20
## The one stats line may shrink below MIN_FIT_FONT_SIZE (three facts on a short card).
const COMPACT_STAT_MIN_FONT_SIZE: int = 13
const COMPACT_DESC_FONT_SIZE: int = 18
const COMPACT_DESC_LINES: int = 3
const COMPACT_NAME_BASELINE: float = 0.15
const COMPACT_RARITY_BASELINE: float = 0.27
const COMPACT_DIVIDER: float = 0.31
const COMPACT_STATS_BASELINE: float = 0.43
const COMPACT_KEYWORD_BASELINE: float = 0.55
const COMPACT_DESC_BASELINE: float = 0.58
const COMPACT_DESC_BASELINE_KEYWORD: float = 0.68

## Story 034: the ink row - label, confirm, skip, the "new shape" tag; the shape tile look (shared with the
## shop's shape picker through [method draw_shape_tile]).
const TEXT_INK_TITLE: String = "ui.piece_deck.ink_title"
const TEXT_INK_CONFIRM: String = "ui.piece_deck.ink_confirm"
const TEXT_INK_SKIP: String = "ui.piece_deck.ink_skip"
const TEXT_INK_NEW: String = "ui.piece_deck.new_shape"
const SHAPE_TILE_BORDER: Color = HudSkin.MIST
const SHAPE_FILL: Color = Color(0.36, 0.58, 0.82)
const SHAPE_OUTLINE: Color = Color(0.06, 0.07, 0.1, 0.9)
const DOT_ON: Color = HudSkin.GRID_LIGHT
const DOT_OFF: Color = Color(0.49, 0.53, 0.59, 0.45)
const NEW_TAG_COLOR: Color = Color(0.45, 0.82, 0.5)
const SHAPE_NAME_FONT_SIZE: int = 24
const SHAPE_TAG_FONT_SIZE: int = 18
## Tile padding and the dot radius as shares of the tile's short side; the largest square of a shape as a
## share of its drawing area (so a 1-cell shape does not fill the tile).
const SHAPE_TILE_PAD_RATIO: float = 0.08
const SHAPE_DOT_RADIUS_RATIO: float = 0.05
const SHAPE_MAX_UNIT_RATIO: float = 0.3
## A tile at least this much wider than tall draws the shape on its left, text on the right; else on top.
const SHAPE_TILE_WIDE_ASPECT: float = 1.3

## Path to the GameFlow (a sibling under Main) that owns the run.
@export var flow_path: NodePath = NodePath("../GameFlow")

var _flow: GameFlow = null
# Story 027: lazily loaded combat.json (see _zone_config).
var _combat_config: CombatConfig = null
## Story 020: true while the remove list covers the offer.
var _removing: bool = false
## Story 032: the relic picked on the relic row (waits for "Xác nhận"); "" = none.
var _selected_relic: String = ""
## Story 032: the owned-relic strip along the bottom (tap an icon for its card).
var _strip: RelicStrip = null
## Story 034: the shape selected on the ink row ("" = none) and the ink tile under the current press (-1).
var _selected_ink: String = ""
var _ink_press: int = -1
## Story 037: the unlocked content that showed a "Mới" badge while this screen was up ({"kind:id": [kind, id]});
## marked seen when the screen is left.
var _new_shown: Dictionary = {}
## 2026-11-01 (OSFE cards): the offer card a first tap selected ("" = none; a second tap takes it) and the
## open detail panel ("card", "relic" or "" = closed).
var _selected_card: String = ""
var _detail_kind: String = ""
const DETAIL_CARD: String = "card"
## DEV-only user arg for captures: `--pick=N` selects offer card N (`--pick=rN`: relic N) once the screen shows.
const DEV_PICK_ARG: String = "--pick="
var _dev_pick_done: bool = false
const DETAIL_RELIC: String = "relic"

## Story 037: the "Mới" badge on a card or relic the player unlocked and has not seen yet.
const TEXT_NEW: String = "unlock.new"
const NEW_BADGE_COLOR: Color = Color(0.85, 0.35, 0.1)
const NEW_BADGE_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const NEW_BADGE_FONT_SIZE: int = 18
const NEW_BADGE_SIZE: Vector2 = Vector2(58.0, 26.0)
const NEW_BADGE_INSET: float = 8.0
const UNLOCK_KIND_CARD: String = "card"
const UNLOCK_KIND_RELIC: String = "relic"


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow
	_strip = RelicStrip.new()
	add_child(_strip)


func _process(_delta: float) -> void:
	if _removing and not is_shown():
		_removing = false
	if not _new_shown.is_empty() and not is_shown():
		for entry: Variant in _new_shown.values():
			_flow.mark_unlock_seen(str((entry as Array)[0]), str((entry as Array)[1]))
		_new_shown.clear()
	if not is_shown() or not _relic_choices().has(_selected_relic):
		_selected_relic = ""
	if not is_shown() or not _flow.get_ink_offer().has(_selected_ink):
		_selected_ink = ""
	if not is_ink_row_shown():
		_ink_press = -1
	if not is_shown() or _removing or not _flow.get_pending_reward().has(_selected_card):
		_selected_card = ""
	if is_shown() and not _dev_pick_done:
		_dev_pick_done = true
		_apply_dev_pick()
	if (_detail_kind == DETAIL_CARD and _selected_card.is_empty()) or (_detail_kind == DETAIL_RELIC and _selected_relic.is_empty()):
		_detail_kind = ""
	var strip_shown: bool = is_shown() and not _removing
	if not strip_shown:
		_strip.close_tooltip()
	_strip.visible = strip_shown
	if strip_shown:
		_strip.area = ScreenLayout.reward_relic_strip_rect(get_viewport_rect().size, _dual() or _fate_offer())
		_strip.set_relics(_flow.get_relics())
	queue_redraw()


## Story 032: true while the treasure screen carries the relic row as well as the card row.
func is_relic_row_shown() -> bool:
	return is_shown() and _dual()


## Story 032: the relic selected on the relic row ("" = none).
func get_selected_relic() -> String:
	return _selected_relic


func _dual() -> bool:
	return _flow != null and _flow.has_relic_offer() and not _flow.has_fate_offer()


## Story 034: true while the screen carries the ink row ([method GameFlow.has_ink_offer]).
func is_ink_row_shown() -> bool:
	return is_shown() and not _removing and _ink()


## Story 034: the shape selected on the ink row ("" = none).
func get_selected_ink() -> String:
	return _selected_ink


func _ink() -> bool:
	return _flow != null and _flow.has_ink_offer()


## True while the screen is up: IN_NODE or MAP with an open offer.
func is_shown() -> bool:
	if _fate_offer():
		return true
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
	if _fate_offer():
		_input_fate_offer(event)
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if _removing:
				_removing = false
				return
			if not _selected_relic.is_empty() and _dual():
				_flow.choose_relic(_selected_relic)
				return
			var offer: Array[String] = _flow.get_pending_reward()
			if not offer.is_empty():
				_flow.reward_chosen(offer[0])
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
	var vp: Vector2 = get_viewport_rect().size
	var release: Vector2 = _release_position(event)
	if release != Vector2.INF and event.device != InputEvent.DEVICE_ID_EMULATION:
		if is_ink_row_shown():
			_ink_release(release, vp)
		_ink_press = -1
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _removing:
		_input_remove_list(pos, vp)
		return
	if _detail_panel_rect(vp).has_point(pos):
		_close_detail()
		return
	if _ink():
		# 2026-11-01: the ink row is a step of its own, shown before the card choice.
		_input_ink_press(pos, vp, false)
		return
	var offer: Array[String] = _flow.get_pending_reward()
	var dual: bool = _dual()
	if _can_remove() and _remove_slot_rect(vp, offer.size(), dual).has_point(pos):
		_removing = true
		return
	if dual:
		if _input_relic_row(pos, vp):
			return
	elif _can_skip() and ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_flow.reward_skipped()
		return
	var rects: Array[Rect2] = _card_rects(vp, offer.size(), dual)
	for i: int in rects.size():
		if rects[i].has_point(pos):
			# 2026-11-01 (OSFE cards): the first tap selects and opens the detail panel, a tap on the selected card takes it.
			if offer[i] == _selected_card:
				_flow.reward_chosen(offer[i])
			else:
				_selected_card = offer[i]
				_detail_kind = DETAIL_CARD
			return
	_close_detail()


# Story 020, remove list: "Thôi" closes it; a tile (when the deck is above the minimum) removes
# that deck entry and closes it (the flow continues the run).
func _input_remove_list(pos: Vector2, vp: Vector2) -> void:
	if ScreenLayout.reward_skip_button_rect(vp).has_point(pos):
		_removing = false
		return
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	for i: int in rects.size():
		if rects[i].has_point(pos) and _tile_removable(entries, i):
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


# Story 034: position of a left mouse release or a touch release; Vector2.INF for any other event.
func _release_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
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


# Story 020: true when a normal card may go (Story 033: the NON-curse cards of [param entries] are above
# rewards.json min_deck_size).
func _entries_removable(entries: Array[Dictionary]) -> bool:
	return ShopView.non_curse_count(entries, _flow.get_cards()) > int(_flow.get_reward_config().get("min_deck_size", 0))


# Story 033: entry [param index] may go — a curse always, a normal card per [method _entries_removable].
func _tile_removable(entries: Array[Dictionary], index: int) -> bool:
	return _flow.get_cards().is_curse(str(entries[index].get("id", ""))) or _entries_removable(entries)


# Story 020: the level cap offers stop at (rewards.json max_card_level, else SkillConfig.MAX_LEVEL).
func _max_level() -> int:
	return int(_flow.get_reward_config().get("max_card_level", SkillConfig.MAX_LEVEL))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_shown():
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	if _fate_offer():
		_draw_fate_offer(vp)
		return
	if _removing:
		_draw_remove_list(vp)
		return
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	var kind: String = _reward_kind()
	if _ink():
		# 2026-11-01 (user: "lúc thì nhiều option, lúc thì 1 option"): the ink offer is its own step, before the
		# card choice — one decision per screen. choose_ink / skip_ink_offer keep the card choice open.
		_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_INK_TITLE).to_upper(), TITLE_FONT_SIZE, TITLE_COLOR, true)
		_draw_gold(vp, title)
		_draw_ink_row(vp, false)
		return
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE_TREASURE if kind == KIND_TREASURE else TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, true)
	_draw_gold(vp, title)
	var subtitle: String = ""
	if kind == KIND_MINIBOSS:
		subtitle = tr(TEXT_MIN_RARE)
	elif kind == KIND_BOSS:
		subtitle = tr(TEXT_TOKEN_GRANTED) % int(RunSession.cfg(_flow.get_reward_config(), CFG_BOSS_TOKENS))
	var hint: bool = not _dual() and _tap_hint_shown(vp)
	if hint:
		subtitle = tr(CardFace.TEXT_TAP_AGAIN) if subtitle.is_empty() else subtitle + RelicStrip.RARITY_SEPARATOR + tr(CardFace.TEXT_TAP_AGAIN)
	if not subtitle.is_empty():
		var strip: Rect2 = ScreenLayout.reward_subtitle_rect(vp)
		_text(strip, strip.get_center().y + SUBTITLE_FONT_SIZE * 0.35, subtitle, SUBTITLE_FONT_SIZE, HINT_COLOR if hint else SUBTITLE_COLOR)
	var offer: Array[String] = _flow.get_pending_reward()
	var with_remove: bool = _can_remove()
	var dual: bool = _dual()
	var rects: Array[Rect2] = _card_rects(vp, offer.size(), dual)
	var levels: Dictionary = _flow.get_deck_levels()
	for i: int in rects.size():
		_draw_card(rects[i], offer[i], levels)
	if dual:
		_draw_relic_row(vp)
	if with_remove:
		var slot: Rect2 = _remove_slot_rect(vp, offer.size(), dual)
		var slot_text: String = tr(TEXT_REMOVE_COUNT) % _removal_tokens()
		CardFace.draw_slot(self, slot, slot_text, UiButtons.is_pressed_at(self, slot))
	if _can_skip() and not dual:
		var skip: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
		UiButtons.draw_button(self, skip, tr(TEXT_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, BUTTON_FONT_SIZE)
	_draw_detail_panel(vp)


# --- Story 035: the Execute relic offer -------------------------------------------


## Story 035: true while the Execute relic offer is open ([method GameFlow.has_fate_offer]): the screen
## shows only the 3 relic cards of the treasure layout; a tap selects a card, a tap on the selected card
## (or "Xác nhận") takes it ([method GameFlow.choose_fate_relic]), "Bỏ qua" -> [method GameFlow.skip_fate_relic].
func is_fate_offer_shown() -> bool:
	return _fate_offer()


func _fate_offer() -> bool:
	return _flow != null and _flow.has_fate_offer()


# The relics the selection may point at: the Execute offer while it is open, else the treasure relic row.
func _relic_choices() -> Array[String]:
	return _flow.get_fate_offer() if _fate_offer() else _flow.get_relic_offer()


func _input_fate_offer(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if not _selected_relic.is_empty():
				_flow.choose_fate_relic(_selected_relic)
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _strip.visible and _strip.handle_input(event):
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _detail_panel_rect(vp).has_point(pos):
		_close_detail()
		return
	if ScreenLayout.reward_dual_skip_rect(vp).has_point(pos):
		_flow.skip_fate_relic()
		return
	if ScreenLayout.reward_dual_confirm_rect(vp).has_point(pos):
		if not _selected_relic.is_empty():
			_flow.choose_fate_relic(_selected_relic)
		return
	var relics: Array[String] = _flow.get_fate_offer()
	var rects: Array[Rect2] = ScreenLayout.reward_dual_relic_rects(vp, relics.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			if relics[i] == _selected_relic:
				_flow.choose_fate_relic(relics[i])  # tap again confirms
			else:
				_selected_relic = relics[i]
				_detail_kind = DETAIL_RELIC
			return


# Title, hint, the 3 relic cards (treasure layout, no "or" row label) and "Bỏ qua" / "Xác nhận".
func _draw_fate_offer(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	var title_text: String = tr(TEXT_FATE_OFFER_TITLE)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, title_text, _fit_font_size(title_text, vp.x * 0.9, TITLE_FONT_SIZE), TITLE_COLOR)
	var strip: Rect2 = ScreenLayout.reward_subtitle_rect(vp)
	_text(strip, strip.get_center().y + SUBTITLE_FONT_SIZE * 0.35, tr(TEXT_FATE_OFFER_HINT), SUBTITLE_FONT_SIZE, SUBTITLE_COLOR)
	var relics: Array[String] = _flow.get_fate_offer()
	var rects: Array[Rect2] = ScreenLayout.reward_dual_relic_rects(vp, relics.size())
	for i: int in rects.size():
		_draw_relic_card(rects[i], relics[i], relics[i] == _selected_relic)
	var skip: Rect2 = ScreenLayout.reward_dual_skip_rect(vp)
	UiButtons.draw_button(self, skip, tr(TEXT_RELIC_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, _fit_font_size(tr(TEXT_RELIC_SKIP), skip.size.x * 0.9, BUTTON_FONT_SIZE))
	var confirm: Rect2 = ScreenLayout.reward_dual_confirm_rect(vp)
	var enabled: bool = not _selected_relic.is_empty()
	UiButtons.draw_button(self, confirm, tr(TEXT_RELIC_CONFIRM), UiButtons.Style.PRIMARY, enabled and UiButtons.is_pressed_at(self, confirm), enabled, _fit_font_size(tr(TEXT_RELIC_CONFIRM), confirm.size.x * 0.9, BUTTON_FONT_SIZE))
	_draw_detail_panel(vp)


# --- Story 032: the relic row -------------------------------------------------


# Card rects: the plain offer layout, or the upper row of the two-row treasure screen.
func _card_rects(vp: Vector2, count: int, dual: bool) -> Array[Rect2]:
	if dual:
		return ScreenLayout.reward_dual_card_rects(vp, count, _can_remove())
	return ScreenLayout.reward_card_rects(vp, count, _can_remove())


# The "Bỏ 1 lá" slot: right of the card row (same top / height as the cards of that layout).
func _remove_slot_rect(vp: Vector2, count: int, dual: bool) -> Rect2:
	if not dual:
		return ScreenLayout.reward_remove_slot_rect(vp, count)
	var cards: Array[Rect2] = ScreenLayout.reward_dual_card_rects(vp, count, true)
	if cards.is_empty():
		return Rect2()
	var last: Rect2 = cards[cards.size() - 1]
	return Rect2(last.end.x + vp.x * ScreenLayout.REWARD_CARD_GAP_RATIO, last.position.y, last.size.x, last.size.y)


# Relic row input: a relic card selects it (tap again keeps it), "Xác nhận" takes the selected relic,
# "Bỏ qua" closes both rows. True when the press was used.
func _input_relic_row(pos: Vector2, vp: Vector2) -> bool:
	if _can_skip() and ScreenLayout.reward_dual_skip_rect(vp).has_point(pos):
		_flow.skip_relic_offer()
		return true
	if ScreenLayout.reward_dual_confirm_rect(vp).has_point(pos):
		if not _selected_relic.is_empty():
			_flow.choose_relic(_selected_relic)
		return true
	var relics: Array[String] = _flow.get_relic_offer()
	var rects: Array[Rect2] = _relic_rects(vp, relics.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			if relics[i] == _selected_relic:
				_flow.choose_relic(relics[i])  # 2026-11-01: tap again takes, as on the fate offer
			else:
				_selected_relic = relics[i]
				_detail_kind = DETAIL_RELIC
			return true
	return false


# Row labels, the 3 relic cards and the bottom buttons ("Bỏ qua" left, "Xác nhận" right, dim until a pick).
func _draw_relic_row(vp: Vector2) -> void:
	var cards_label: Rect2 = ScreenLayout.reward_dual_cards_label_rect(vp)
	var hint: bool = _tap_hint_shown(vp)
	_text(cards_label, cards_label.get_center().y + ROW_LABEL_FONT_SIZE * 0.35, tr(CardFace.TEXT_TAP_AGAIN) if hint else tr(TEXT_CARDS_ROW), ROW_LABEL_FONT_SIZE, HINT_COLOR if hint else SUBTITLE_COLOR)
	var relics_label: Rect2 = ScreenLayout.reward_dual_relics_label_rect(vp)
	_text(relics_label, relics_label.get_center().y + ROW_LABEL_FONT_SIZE * 0.35, tr(TEXT_RELICS_ROW), ROW_LABEL_FONT_SIZE, SUBTITLE_COLOR)
	var relics: Array[String] = _flow.get_relic_offer()
	var rects: Array[Rect2] = _relic_rects(vp, relics.size())
	for i: int in rects.size():
		_draw_relic_card(rects[i], relics[i], relics[i] == _selected_relic)
	if _can_skip():
		var skip: Rect2 = ScreenLayout.reward_dual_skip_rect(vp)
		UiButtons.draw_button(self, skip, tr(TEXT_RELIC_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, _fit_font_size(tr(TEXT_RELIC_SKIP), skip.size.x * 0.9, BUTTON_FONT_SIZE))
	var confirm: Rect2 = ScreenLayout.reward_dual_confirm_rect(vp)
	var enabled: bool = not _selected_relic.is_empty()
	UiButtons.draw_button(self, confirm, tr(TEXT_RELIC_CONFIRM), UiButtons.Style.PRIMARY, enabled and UiButtons.is_pressed_at(self, confirm), enabled, _fit_font_size(tr(TEXT_RELIC_CONFIRM), confirm.size.x * 0.9, BUTTON_FONT_SIZE))


# Story 034: relic rects of the treasure screen - moved up and shorter while the ink row is open.
func _relic_rects(vp: Vector2, count: int) -> Array[Rect2]:
	return ScreenLayout.reward_dual_relic_rects(vp, count)


# --- 2026-11-01: the detail panel (OSFE cards) --------------------------------


## 2026-11-01: the offer card selected by a first tap ("" = none).
func get_selected_card() -> String:
	return _selected_card


## 2026-11-01: the open detail panel's rect (zero when closed): next to the selected card or relic
## ([method CardFace.detail_rect]). Only a short face opens one; a tall face prints its text itself.
func _detail_panel_rect(vp: Vector2) -> Rect2:
	if _detail_kind == DETAIL_CARD:
		var offer: Array[String] = _flow.get_pending_reward()
		var i: int = offer.find(_selected_card)
		var rects: Array[Rect2] = _card_rects(vp, offer.size(), _dual())
		# Card layout v2: a face whose text is cut ("…") opens the panel too.
		if i >= 0 and i < rects.size():
			var skill: Dictionary = _offer_skill(_selected_card)
			if not CardFace.face_text_complete(skill, CardText.describe_resolved(skill), [], rects[i], vp.y):
				return CardFace.detail_rect(rects[i], vp)
	elif _detail_kind == DETAIL_RELIC:
		var relics: Array[String] = _relic_choices()
		var i: int = relics.find(_selected_relic)
		var rects: Array[Rect2] = ScreenLayout.reward_dual_relic_rects(vp, relics.size()) if _fate_offer() else _relic_rects(vp, relics.size())
		if i >= 0 and i < rects.size() and not CardFace.shows_text(rects[i], vp.y):
			return CardFace.detail_rect(rects[i], vp)
	return Rect2()


# DEV `--pick=N` / `--pick=rN` (see [constant DEV_PICK_ARG]).
func _apply_dev_pick() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(DEV_PICK_ARG):
			continue
		var value: String = arg.trim_prefix(DEV_PICK_ARG)
		var relics: Array[String] = _relic_choices()
		if value.begins_with("r") and int(value.substr(1)) < relics.size():
			_selected_relic = relics[int(value.substr(1))]
			_detail_kind = DETAIL_RELIC
		elif value.is_valid_int() and int(value) < _flow.get_pending_reward().size():
			_selected_card = _flow.get_pending_reward()[int(value)]
			_detail_kind = DETAIL_CARD


# 2026-11-01: true while a tall selected card (no panel) waits for its second tap: the subtitle strip (the
# treasure screen's card-row label) then reads "Chạm để chọn, chạm lại để lấy".
func _tap_hint_shown(vp: Vector2) -> bool:
	return _detail_kind == DETAIL_CARD and not _detail_panel_rect(vp).has_area()


# Closes the detail panel; a card's panel also drops the card selection (a relic stays selected for "Xác nhận").
func _close_detail() -> void:
	if _detail_kind == DETAIL_CARD:
		_selected_card = ""
	_detail_kind = ""


# The detail panel: everything the card face leaves out — rarity (+ upgrade), the stats line, the keywords and
# the whole effect text; for a relic its rarity line and rule text. The foot says a second tap takes it.
func _draw_detail_panel(vp: Vector2) -> void:
	var rect: Rect2 = _detail_panel_rect(vp)
	if not rect.has_area():
		return
	if _detail_kind == DETAIL_RELIC:
		var info: Dictionary = _flow.relic_info(_selected_relic)
		var negative: bool = RelicStrip.is_negative(info)
		var color: Color = RelicStrip.NEGATIVE_COLOR if negative else RelicStrip.rarity_color(str(info.get("rarity", "")))
		CardFace.draw_detail(self, rect, str(info.get("name", _selected_relic)), [[RelicStrip.rarity_line(info), color.lightened(RARITY_TEXT_LIGHTEN)]],
			str(info.get("desc", "")), tr(CardFace.TEXT_TAP_AGAIN))
		return
	var levels: Dictionary = _flow.get_deck_levels()
	var upgrade: bool = RewardRoller.is_upgrade(_selected_card, levels, _max_level())
	var current: int = int(levels.get(_selected_card, 0))
	var shown_level: int = current + 1 if upgrade else 1
	var skill: Dictionary = _flow.get_cards().resolved(_selected_card, shown_level)
	var rarity: String = str(skill.get("rarity", ""))
	var title: String = tr(str(skill.get("name_key", _selected_card)))
	if upgrade:
		title += LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % current
	var rarity_text: String = tr(_rarity_key(rarity))
	if upgrade:
		rarity_text += RelicStrip.RARITY_SEPARATOR + tr(TEXT_UPGRADE_TO) % shown_level
	var min_cells: int = int(skill.get("min_cells", 1))
	var stats: Array[String] = [tr(TEXT_CELLS_ANY) if min_cells <= 1 else tr(TEXT_CELLS) % min_cells]
	var damage: int = roundi(float(skill.get("damage_per_cell", 0.0)))
	if damage > 0:
		stats.append(tr(TEXT_DAMAGE) % damage)
	var cooldown: float = float(skill.get("cooldown_sec", 0.0))
	stats.append(tr(TEXT_COOLDOWN_NONE) if cooldown <= 0.0 else tr(TEXT_COOLDOWN) % roundi(cooldown))
	# Rarity (or the upgrade) and the stats share one line, so the effect text keeps the room.
	stats.push_front(rarity_text)
	var lines: Array = [[RelicStrip.RARITY_SEPARATOR.join(stats), UPGRADE_COLOR if upgrade else _rarity_color(rarity).lightened(RARITY_TEXT_LIGHTEN)]]
	var keywords: Array = _keyword_parts(skill)
	if not keywords.is_empty():
		var words: Array[String] = []
		for part: Variant in keywords:
			words.append(str((part as Array)[0]))
		lines.append([RelicStrip.RARITY_SEPARATOR.join(words), (keywords[0] as Array)[1]])
	CardFace.draw_detail(self, rect, title, lines, CardText.describe_resolved(skill), tr(CardFace.TEXT_TAP_AGAIN))


# --- Story 034: the ink row ---------------------------------------------------


# Ink row press: its skip closes the row, its confirm inks the selected shape (nothing without a pick), a
# tile press is remembered (it selects on release). True when the press was used.
func _input_ink_press(pos: Vector2, vp: Vector2, dual: bool) -> bool:
	if ScreenLayout.reward_ink_skip_rect(vp, dual).has_point(pos):
		_flow.skip_ink_offer()
		return true
	if ScreenLayout.reward_ink_confirm_rect(vp, dual).has_point(pos):
		if not _selected_ink.is_empty():
			_flow.choose_ink(_selected_ink)
		return true
	var rects: Array[Rect2] = ScreenLayout.reward_ink_tile_rects(vp, _flow.get_ink_offer().size(), dual)
	for i: int in rects.size():
		if rects[i].has_point(pos):
			_ink_press = i
			return true
	return false


# Ink row release: a release on the tile the press began on selects that shape.
func _ink_release(pos: Vector2, vp: Vector2) -> void:
	var offer: Array[String] = _flow.get_ink_offer()
	var rects: Array[Rect2] = ScreenLayout.reward_ink_tile_rects(vp, offer.size(), false)
	if _ink_press >= 0 and _ink_press < rects.size() and rects[_ink_press].has_point(pos):
		_selected_ink = offer[_ink_press]


# The ink row: label, one tile per offered shape, the small skip and the confirm (dim until a pick).
func _draw_ink_row(vp: Vector2, dual: bool) -> void:
	# 2026-11-01: no row label — the ink step's title already says "Học hình".
	var offer: Array[String] = _flow.get_ink_offer()
	var rects: Array[Rect2] = ScreenLayout.reward_ink_tile_rects(vp, offer.size(), dual)
	var rows: Dictionary = {}
	for row: Dictionary in _flow.get_piece_deck_rows():
		rows[str(row.get("id", ""))] = row
	var lib: PieceLibrary = _flow.get_piece_library()
	var max_dots: int = ceili(_flow.get_piece_deck_config().mult_max)
	for i: int in rects.size():
		var id: String = offer[i]
		var row: Dictionary = rows.get(id, {})
		var dots: int = int(row.get("dots", 0))
		var tag: String = tr(TEXT_INK_NEW) if bool(row.get("run_only", lib.is_run_only(id))) and dots <= 0 else ""
		var highlight: int = 2 if id == _selected_ink else (1 if i == _ink_press else 0)
		draw_shape_tile(self, rects[i], lib.make_piece(id), tr(lib.name_key(id)), dots, max_dots, tag, NEW_TAG_COLOR, highlight, false)
	var skip: Rect2 = ScreenLayout.reward_ink_skip_rect(vp, dual)
	UiButtons.draw_button(self, skip, tr(TEXT_INK_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, _fit_font_size(tr(TEXT_INK_SKIP), skip.size.x * 0.9, BUTTON_FONT_SIZE))
	var confirm: Rect2 = ScreenLayout.reward_ink_confirm_rect(vp, dual)
	var enabled: bool = not _selected_ink.is_empty()
	UiButtons.draw_button(self, confirm, tr(TEXT_INK_CONFIRM), UiButtons.Style.PRIMARY, enabled and UiButtons.is_pressed_at(self, confirm), enabled, _fit_font_size(tr(TEXT_INK_CONFIRM), confirm.size.x * 0.9, BUTTON_FONT_SIZE))


## Story 034: one shape tile at [param rect] - [param piece] drawn with PieceDraw, [param name], the mult as
## [param dots] filled of [param max_dots], and an optional [param tag] line in [param tag_color] (the shop
## passes a refusal reason). A wide tile puts the shape on the left and the text on the right, a tall one
## the shape on top. [param highlight]: 0 none, 1 pressed (gold outline), 2 selected (thick gold outline,
## raised). [param disabled] dims everything but the tag. Shared by the reward screen's ink row and the
## shop's shape picker.
static func draw_shape_tile(canvas: CanvasItem, rect: Rect2, piece: Piece, name: String, dots: int, max_dots: int, tag: String, tag_color: Color, highlight: int, disabled: bool) -> void:
	var r: Rect2 = rect
	var short_side: float = minf(rect.size.x, rect.size.y)
	if highlight == 2:
		canvas.draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size), ShopView.SHADOW_COLOR)
		r.position.y -= short_side * SHAPE_TILE_PAD_RATIO * 0.5
	var border: Color = SHAPE_TILE_BORDER
	var text: Color = NAME_COLOR
	var fill: Color = SHAPE_FILL
	var outline: Color = SHAPE_OUTLINE
	var on: Color = DOT_ON
	var off: Color = DOT_OFF
	if disabled:
		text.a *= UiButtons.DIM_ALPHA
		fill.a *= UiButtons.DIM_ALPHA
		outline.a *= UiButtons.DIM_ALPHA
		on.a *= UiButtons.DIM_ALPHA
		off.a *= UiButtons.DIM_ALPHA
	HudSkin.card(canvas, r, border, highlight > 0, disabled)
	var pad: float = short_side * SHAPE_TILE_PAD_RATIO
	var inner: Rect2 = r.grow(-pad)
	var shape_area: Rect2
	var text_area: Rect2
	if r.size.x >= r.size.y * SHAPE_TILE_WIDE_ASPECT:
		shape_area = Rect2(inner.position, Vector2(inner.size.y, inner.size.y))
		text_area = Rect2(shape_area.end.x + pad, inner.position.y, maxf(inner.end.x - shape_area.end.x - pad, 0.0), inner.size.y)
	else:
		shape_area = Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5))
		text_area = Rect2(inner.position.x, shape_area.end.y + pad * 0.5, inner.size.x, maxf(inner.end.y - shape_area.end.y - pad * 0.5, 0.0))
	PieceDraw.draw_shape(canvas, piece, shape_area, fill, outline, minf(shape_area.size.x, shape_area.size.y) * SHAPE_MAX_UNIT_RATIO)
	MenuFont.text(canvas, Vector2(text_area.position.x, text_area.position.y + text_area.size.y * 0.28), name, _fit_static(name, text_area.size.x, SHAPE_NAME_FONT_SIZE, true), text, HORIZONTAL_ALIGNMENT_CENTER, text_area.size.x, true)
	var radius: float = maxf(short_side * SHAPE_DOT_RADIUS_RATIO, 3.0)
	var count: int = maxi(max_dots, 1)
	var step: float = radius * 2.8
	var x0: float = text_area.get_center().x - step * (count - 1) * 0.5
	var dot_y: float = text_area.position.y + text_area.size.y * 0.55
	for i: int in count:
		HudSkin.diamond(canvas, Vector2(x0 + step * i, dot_y), radius * PieceDeckView.DOT_DIAMOND_RATIO, on if i < dots else off, Color.TRANSPARENT, 0.0)
	if not tag.is_empty():
		MenuFont.text(canvas, Vector2(text_area.position.x, text_area.position.y + text_area.size.y * 0.88), tag, _fit_static(tag, text_area.size.x, SHAPE_TAG_FONT_SIZE), tag_color, HORIZONTAL_ALIGNMENT_CENTER, text_area.size.x)


# Static twin of _fit_font_size for draw_shape_tile.
static func _fit_static(text: String, width: float, size: int, bold: bool = false) -> int:
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted


# One relic card. 2026-11-01 (OSFE cards): the CardFace relic face (glyph tile in the art window, name, rarity
# line); the rule text is in the detail panel the selection opens. The selected card gets the bright frame.
func _draw_relic_card(rect: Rect2, id: String, selected: bool) -> void:
	var info: Dictionary = _flow.relic_info(id)
	CardFace.draw_relic(self, rect, id, str(info.get("name", id)), RelicStrip.rarity_line(info), str(info.get("rarity", "")),
		RelicStrip.is_negative(info), str(info.get("desc", "")), selected, UiButtons.is_pressed_at(self, rect))
	_draw_new_badge(rect, UNLOCK_KIND_RELIC, id)


# 2026-11-01 (OSFE cards): the card row of the two-row treasure / ink screens uses the same face as the plain
# offer; the face scales to the shorter rect.
func _draw_card_compact(rect: Rect2, id: String, levels: Dictionary) -> void:
	_draw_card(rect, id, levels)


# One offer card. [param levels] is the deck's id -> highest level: a held card below max is an upgrade (title
# with its current level, a gold "+N" tag, numbers resolved at N). 2026-11-01 (user: "thẻ card đang hơi xấu, hãy
# tham khảo osfe", then an OSFE card as the target): the CardFace face — cost diamond, name, art window, the
# effect text on the card, damage diamond, cooldown. A short face (treasure / ink rows) leaves the text to the
# detail panel a first tap opens ([method _draw_detail_panel]).
func _draw_card(rect: Rect2, id: String, levels: Dictionary) -> void:
	var upgrade: bool = RewardRoller.is_upgrade(id, levels, _max_level())
	var shown_level: int = int(levels.get(id, 0)) + 1 if upgrade else 1
	var skill: Dictionary = _flow.get_cards().resolved(id, shown_level)
	# An upgrade shows the level the pick gives ("Lia ngang +2", gold).
	var title: String = tr(str(skill.get("name_key", id)))
	var tag: String = (tr(TEXT_LEVEL_SUFFIX) % shown_level) if upgrade else ""
	CardFace.draw_skill(self, rect, skill, title, tag, CardText.describe_resolved(skill), id == _selected_card, UiButtons.is_pressed_at(self, rect), false, [], id)
	_draw_new_badge(rect, UNLOCK_KIND_CARD, id)


# Offer card [param id] resolved at the level the pick gives (as [method _draw_card] shows it).
func _offer_skill(id: String) -> Dictionary:
	var levels: Dictionary = _flow.get_deck_levels()
	var upgrade: bool = RewardRoller.is_upgrade(id, levels, _max_level())
	return _flow.get_cards().resolved(id, int(levels.get(id, 0)) + 1 if upgrade else 1)


# Story 037: a small "Mới" tab on the top edge of the card at [param rect] when [param kind] / [param id] was
# unlocked by an achievement and not seen yet; remembers it so the screen marks it seen when it is left.
func _draw_new_badge(rect: Rect2, kind: String, id: String) -> void:
	var progress: ProgressState = _flow.get_progress()
	if progress == null or not progress.is_new_unlock(kind, id):
		return
	_new_shown["%s:%s" % [kind, id]] = [kind, id]
	var badge := Rect2(Vector2(rect.end.x - NEW_BADGE_SIZE.x - NEW_BADGE_INSET, rect.position.y - NEW_BADGE_SIZE.y * 0.5), NEW_BADGE_SIZE)
	HudSkin.panel(self, badge, [0.0, 0.0, 0.0, 0.0], NEW_BADGE_COLOR, HudSkin.TEXT_OUTLINE)
	MenuFont.text(self, Vector2(badge.position.x, badge.get_center().y + NEW_BADGE_FONT_SIZE * 0.35), tr(TEXT_NEW), NEW_BADGE_FONT_SIZE, NEW_BADGE_TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, true)


# Story 023: [text, colour] pairs of the keywords a resolved card carries, in a fixed order
# (Rạn stacks, Hàn stacks, pierce, execute, the Rạn bonus); empty for a plain card.
func _keyword_parts(skill: Dictionary) -> Array:
	var parts: Array = []
	# Story 027: zone cards lead with their zone keyword; thorns add the Ran per entry.
	var effect: String = str(skill.get("effect", ""))
	if effect == "thorns":
		parts.append([tr(TEXT_KEYWORD_THORNS), THORN_COLOR])
		var thorn_stacks: int = int(skill.get("thorn_fragile_stacks", _zone_config().thorn_fragile_stacks))
		if thorn_stacks > 0:
			parts.append([tr(TEXT_KEYWORD_FRAGILE_STACKS) % thorn_stacks, FRAGILE_COLOR])
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


# Story 027: combat.json numbers (the thorn Ran default of a thorns card that omits its own), loaded once.
func _zone_config() -> CombatConfig:
	if _combat_config == null:
		_combat_config = CombatConfig.load_from_file()
		if _combat_config == null:
			_combat_config = CombatConfig.new()
	return _combat_config


# One centred line of coloured [param parts] KEYWORD_GAP apart; the font shrinks (never below
# MIN_FIT_FONT_SIZE) until the whole line fits [param inner].
func _draw_keyword_line(inner: Rect2, y: float, parts: Array) -> void:
	var size: int = KEYWORD_FONT_SIZE
	while size > MIN_FIT_FONT_SIZE and _parts_width(parts, size) > inner.size.x:
		size -= 1
	var x: float = inner.get_center().x - _parts_width(parts, size) * 0.5
	for part: Array in parts:
		MenuFont.text(self, Vector2(x, y), str(part[0]), size, part[1])
		x += HudSkin.text_width(str(part[0]), size) + KEYWORD_GAP


# Width of [param parts] in a row at [param size], gaps included (none after the last).
func _parts_width(parts: Array, size: int) -> float:
	var width: float = 0.0
	for part: Array in parts:
		width += HudSkin.text_width(str(part[0]), size)
	return width + KEYWORD_GAP * maxi(parts.size() - 1, 0)


# Story 020: the remove list — title, one tile per deck entry (name + level, rarity border; dimmed
# at minimum deck size), the hint line and the "Thôi" button (in the skip button's place).
func _draw_remove_list(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_REMOVE_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, true)
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var normal_ok: bool = _entries_removable(entries)
	var rects: Array[Rect2] = ScreenLayout.reward_remove_rects(vp, entries.size())
	var cards: SkillConfig = _flow.get_cards()
	for i: int in rects.size():
		var id: String = str(entries[i].get("id", ""))
		var level: int = int(entries[i].get("level", 1))
		var skill: Dictionary = cards.resolved(id, level)
		var label: String = tr(str(skill.get("name_key", id))) + LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
		var enabled: bool = _tile_removable(entries, i)
		var pressed: bool = enabled and UiButtons.is_pressed_at(self, rects[i])
		var name_color: Color = NAME_COLOR
		if not enabled:
			name_color.a *= UiButtons.DIM_ALPHA
		HudSkin.card(self, rects[i], _rarity_color(str(skill.get("rarity", ""))), pressed, not enabled)
		_text(rects[i], rects[i].get_center().y + TILE_FONT_SIZE * 0.35, label, _fit_font_size(label, rects[i].size.x * 0.92, TILE_FONT_SIZE, MIN_FIT_FONT_SIZE, true), name_color, true)
	var hint: Rect2 = ScreenLayout.reward_remove_hint_rect(vp)
	if not normal_ok:
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_MIN_DECK), HINT_FONT_SIZE, HINT_COLOR)
	elif entries.size() > rects.size():
		_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_MORE) % (entries.size() - rects.size()), HINT_FONT_SIZE, TITLE_COLOR)
	var cancel: Rect2 = ScreenLayout.reward_skip_button_rect(vp)
	UiButtons.draw_button(self, cancel, tr(TEXT_CANCEL), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, cancel), true, BUTTON_FONT_SIZE)


# Story 033: "+N vàng" (coin + text) at the left of the title band when the node paid gold; the run's
# gold total at the right.
func _draw_gold(vp: Vector2, title: Rect2) -> void:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	ShopView.draw_gold(self, vp.x - margin, title.get_center().y, _flow.get_gold(), GOLD_FONT_SIZE, TITLE_COLOR)
	var gain: int = _flow.get_last_gold_gain()
	if gain <= 0:
		return
	var radius: float = GOLD_FONT_SIZE * ShopView.COIN_RADIUS_RATIO
	ShopView.draw_coin(self, Vector2(margin + radius, title.get_center().y), radius)
	MenuFont.text(self, Vector2(margin + radius * 2.0 + GOLD_COIN_GAP, title.get_center().y + GOLD_FONT_SIZE * 0.35), tr(TEXT_GOLD_GAIN) % gain, GOLD_FONT_SIZE, GOLD_GAIN_COLOR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


# Border colour of a rarity id (common for anything unknown; Story 033: curses purple).
func _rarity_color(rarity: String) -> Color:
	match rarity:
		"curse":
			return ShopView.CURSE_COLOR
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
# 2026-10-31: HudSkin outlined text ([param bold] for names and titles).
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits in
# [param width] pixels, so a long translation ("Remove a card") shrinks instead of clipping.
func _fit_font_size(text: String, width: float, size: int, min_size: int = MIN_FIT_FONT_SIZE, bold: bool = false) -> int:
	var fitted: int = size
	while fitted > min_size and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted
