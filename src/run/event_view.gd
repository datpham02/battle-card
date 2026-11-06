class_name EventView
extends Node2D
## Event screen (Story 033, Part D): shown in phase EVENT ([method GameFlow.get_event_view], the
## EventLogic.describe of the open event). Title band: the event's title, HP and the gold count (coin)
## at the right. Upper half: a parchment text box with the event's body (ScreenLayout.event_text_rect,
## wrapped, never scrolled). Lower half: 2–4 wide choice buttons stacked (ScreenLayout.event_choice_rects),
## each with its label at the left and its cost (`cost_key`) in red at the right BEFORE any tap. A choice
## whose requirements fail is dimmed, its reason (`reason_key` % `reason_args`) under the label, and does
## nothing. A choice with `needs_confirm` (HP cost, a curse) arms on the first tap: it turns red and reads
## "Chạm lần nữa để xác nhận" for CONFIRM_SEC; a second tap within that time ->
## [method GameFlow.event_choose]; a tap elsewhere or the timeout disarms it. Other choices go at once.
## After a choice the RESULT screen shows ([method GameFlow.get_event_result]): the outcome text
## (`text_key`) and one line per applied effect (gold / HP / relic / curse / swap / token / modifier;
## gains green, losses red), then the first open pending pick: `card_offer` -> a row of large cards
## (tap one -> [method GameFlow.event_complete_pick] with its id; "Bỏ qua" -> ""), `remove_card` /
## `upgrade_card` -> the deck picker (ShopView.DeckPicker; tap marks, second tap or the bottom-right
## button confirms with the deck index; "Bỏ qua" bottom-left forfeits through [method GameFlow.event_leave]).
## With no pick open, "Tiếp tục" bottom-right -> [method GameFlow.event_leave] ("Vào trận" when the
## result carries a fight that has not started). Enter / Keypad Enter / Space take the last choice
## ("Rời đi") or continue (DEV convenience). Child of GameFlow (reads it through [member flow_path]);
## draws and takes input only in phase EVENT; owns no run state. Input dedup as in RunHudView (emulated
## copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Placeholder art
## drawn in code; all strings are TEXT_* keys through tr().

## 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): the dark HudSkin palette; meaning colours (cost, loss,
## gain) kept but lightened to read on the dark fills.
const BACK_COLOR: Color = HudSkin.SCREEN_BG
const TITLE_COLOR: Color = HudSkin.IVORY
const HEADER_COLOR: Color = HudSkin.TEXT
const BOX_BACK: Color = HudSkin.CARD_FILL
const BOX_OUTLINE: Color = HudSkin.MIST
const BODY_COLOR: Color = HudSkin.TEXT
const CHOICE_BACK: Color = HudSkin.NIGHT_STONE_LIGHT
## The armed choice: the DANGER button fill of the skin (HudSkin.BUTTON_FILLS[2]).
const CHOICE_ARMED_BACK: Color = Color("4A2A24")
const CHOICE_OUTLINE: Color = HudSkin.MIST
const CHOICE_ARMED_OUTLINE: Color = HudSkin.GRID_LIGHT
const CHOICE_TEXT: Color = HudSkin.TEXT
const COST_COLOR: Color = Color(1.0, 0.55, 0.5)
const REASON_COLOR: Color = Color(1.0, 0.78, 0.45)
const GAIN_COLOR: Color = HudSkin.HP_FILL
const LOSS_COLOR: Color = Color(1.0, 0.55, 0.5)
const NEUTRAL_COLOR: Color = HudSkin.TEXT_DIM
const MESSAGE_BAD_COLOR: Color = Color(1.0, 0.55, 0.5)
const LABEL_COLOR: Color = HudSkin.TEXT_DIM
## Curse lines: ShopView.CURSE_COLOR lightened by this share to read on the dark box.
const CURSE_TEXT_LIGHTEN: float = 0.25

const OUTLINE_WIDTH: float = HudSkin.PANEL_LINE_WIDTH
const ARMED_OUTLINE_WIDTH: float = 3.0
const TITLE_FONT_SIZE: int = 44
const HEADER_FONT_SIZE: int = 24
const GOLD_FONT_SIZE: int = 30
const BODY_FONT_SIZE: int = 26
const BODY_MAX_LINES: int = 7
const EFFECT_FONT_SIZE: int = 26
const CHOICE_FONT_SIZE: int = 28
const COST_FONT_SIZE: int = 24
const REASON_FONT_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 28
const LABEL_FONT_SIZE: int = 22
const MIN_FIT_FONT_SIZE: int = 14
## Second-tap window of a `needs_confirm` choice.
const CONFIRM_SEC: float = 2.0
## Text box inner padding (share of its width) and the choice text inset (share of the button width).
const BOX_PAD_RATIO: float = 0.025
const CHOICE_INSET_RATIO: float = 0.03
## Share of the choice width the label may use (the cost takes the rest).
const CHOICE_LABEL_SHARE: float = 0.55
## Baselines inside a choice as shares of its height: single line, label with reason, reason.
const CHOICE_BASELINE: float = 0.62
const CHOICE_LABEL_BASELINE: float = 0.45
const CHOICE_REASON_BASELINE: float = 0.82
const LINE_SPACING: float = 1.35
const SEPARATOR: String = " · "

const PICK_CARD_OFFER: String = "card_offer"
const PICK_REMOVE: String = "remove_card"
const PICK_UPGRADE: String = "upgrade_card"

const TEXT_CONFIRM_AGAIN: String = "ui.event.confirm_again"
const TEXT_CONTINUE: String = "ui.event.continue"
## "Vào trận": continue when the result starts an extra fight.
const TEXT_FIGHT: String = "ui.event.fight"
const TEXT_PICK_CARD: String = "ui.event.pick_card"
const TEXT_PICK_UPGRADE: String = "ui.event.pick_upgrade"
const TEXT_PICK_REMOVE: String = "ui.event.pick_remove"
## "Bỏ lá này" / "Nâng cấp lá này" on the picker's confirm button.
const TEXT_CONFIRM_REMOVE: String = "ui.event.confirm_remove"
const TEXT_CONFIRM_UPGRADE: String = "ui.event.confirm_upgrade"
const TEXT_SKIP: String = "ui.reward.skip"
const TEXT_DRAG_HINT: String = "ui.deck.drag_hint"
const TEXT_GOLD_GAIN: String = "ui.event.result.gold_gain"
const TEXT_GOLD_LOSE: String = "ui.event.result.gold_lose"
const TEXT_HP_GAIN: String = "ui.event.result.hp_gain"
const TEXT_HP_LOSE: String = "ui.event.result.hp_lose"
const TEXT_RELIC: String = "ui.event.result.relic"
const TEXT_CURSE: String = "ui.event.result.curse"
const TEXT_SWAP: String = "ui.event.result.swap"
const TEXT_TOKEN: String = "ui.event.result.token"
const TEXT_MODIFIER: String = "ui.event.result.modifier"
const TEXT_UPGRADE: String = "ui.event.result.upgrade"
const TEXT_HP: String = "ui.map.hp"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Index of the armed `needs_confirm` choice (-1 = none) and when it disarms (msec).
var _armed: int = -1
var _armed_until: int = 0
## Deck picker of a remove / upgrade pick.
var _picker: ShopView.DeckPicker = ShopView.DeckPicker.new()
## Refusal of the last pick ("" = none).
var _message: String = ""
## Translated lines of an upgrade done on this result screen (shown under the effects).
var _done_lines: Array[String] = []


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if not _is_active():
		_armed = -1
		_message = ""
		_done_lines = []
		_picker.reset()
		queue_redraw()  # clear the last frame (see TitleView)
		return
	if _armed >= 0 and Time.get_ticks_msec() >= _armed_until:
		_armed = -1
	queue_redraw()


## Index of the armed choice (-1 when none) — for tests and captures.
func get_armed_choice() -> int:
	return _armed if _is_active() else -1


## Arms choice [param index] as a first tap would — for tests and captures.
func arm_choice(index: int) -> void:
	_armed = index
	_armed_until = Time.get_ticks_msec() + int(CONFIRM_SEC * 1000.0)


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.EVENT and _flow.get_run() != null and not _flow.get_event_view().is_empty()


func _result() -> Dictionary:
	return _flow.get_event_result()


# The first open pick of the result ({} when none or when a card offer has nothing to pick).
func _pick() -> Dictionary:
	var picks: Array = _result().get("pending_picks", [])
	if picks.is_empty():
		return {}
	var pick: Dictionary = picks[0] as Dictionary
	if str(pick.get("type", "")) == PICK_CARD_OFFER and (pick.get("ids", []) as Array).is_empty():
		return {}
	return pick


func _has_fight() -> bool:
	var fight: Variant = _result().get("pending_fight", {})
	return fight is Dictionary and not (fight as Dictionary).is_empty()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if _result().is_empty():
				var choices: Array = _flow.get_event_view().get("choices", [])
				if not choices.is_empty():
					_flow.event_choose(int((choices[choices.size() - 1] as Dictionary).get("index", choices.size() - 1)))
			elif _pick().is_empty():
				_flow.event_leave()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _result().is_empty():
		var pos: Vector2 = _press_position(event)
		if pos != Vector2.INF:
			_tap_choice(pos, vp)
		return
	var pick: Dictionary = _pick()
	var type: String = str(pick.get("type", ""))
	if type == PICK_REMOVE or type == PICK_UPGRADE:
		_input_picker(event, vp, type)
		return
	var press: Vector2 = _press_position(event)
	if press == Vector2.INF:
		return
	if type == PICK_CARD_OFFER:
		if ScreenLayout.shop_leave_rect(vp).has_point(press):
			_complete("")
			return
		var ids: Array = pick.get("ids", [])
		var rects: Array[Rect2] = ScreenLayout.event_offer_rects(vp, ids.size())
		for i: int in rects.size():
			if rects[i].has_point(press):
				_complete(str(ids[i]))
				return
		return
	if ScreenLayout.shop_buy_rect(vp).has_point(press):
		_flow.event_leave()


func _tap_choice(pos: Vector2, vp: Vector2) -> void:
	var choices: Array = _flow.get_event_view().get("choices", [])
	var rects: Array[Rect2] = ScreenLayout.event_choice_rects(vp, choices.size())
	for i: int in rects.size():
		if not rects[i].has_point(pos):
			continue
		var choice: Dictionary = choices[i] as Dictionary
		if not bool(choice.get("enabled", true)):
			_armed = -1
			return
		if bool(choice.get("needs_confirm", false)) and _armed != i:
			arm_choice(i)
			return
		_armed = -1
		_flow.event_choose(int(choice.get("index", i)))
		return
	_armed = -1


func _input_picker(event: InputEvent, vp: Vector2, type: String) -> void:
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var press: Vector2 = _press_position(event)
	if press != Vector2.INF:
		if ScreenLayout.shop_leave_rect(vp).has_point(press):
			_flow.event_leave()
			return
		if _picker.marked >= 0 and ScreenLayout.shop_buy_rect(vp).has_point(press):
			_confirm_pick(_picker.marked, type, entries)
			return
	var tapped: int = _picker.handle(event, vp, entries.size())
	if tapped < 0:
		return
	if not _pickable(entries, tapped, type):
		return
	if tapped == _picker.marked:
		_confirm_pick(tapped, type, entries)
	else:
		_picker.marked = tapped
		_message = ""


func _confirm_pick(index: int, type: String, entries: Array[Dictionary]) -> void:
	var name: String = ""
	if index >= 0 and index < entries.size():
		name = tr(str(_flow.get_cards().get_skill(str(entries[index].get("id", ""))).get("name_key", "")))
	if _complete(index) and type == PICK_UPGRADE:
		_done_lines.append(tr(TEXT_UPGRADE) + (SEPARATOR + name if not name.is_empty() else ""))
	_picker.reset()


func _complete(arg: Variant) -> bool:
	var result: Dictionary = _flow.event_complete_pick(arg)
	var ok: bool = bool(result.get("ok", false))
	_message = "" if ok else tr(str(result.get("reason_key", "")))
	return ok


# Remove: a curse always, a normal card while the non-curse cards stay above min_deck_size.
# Upgrade: only the indices EventLogic.upgradable_indices allows.
func _pickable(entries: Array[Dictionary], index: int, type: String) -> bool:
	if index < 0 or index >= entries.size():
		return false
	var cards: SkillConfig = _flow.get_cards()
	if type == PICK_UPGRADE:
		return EventLogic.upgradable_indices(_flow.get_run(), {"cards": cards}).has(index)
	if cards.is_curse(str(entries[index].get("id", ""))):
		return true
	return ShopView.non_curse_count(entries, cards) > int(_flow.get_reward_config().get("min_deck_size", 0))


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


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp))
	var view: Dictionary = _flow.get_event_view()
	_draw_header(vp, tr(str(view.get("title_key", ""))))
	var result: Dictionary = _result()
	if result.is_empty():
		_draw_box(ScreenLayout.event_text_rect(vp), tr(str(view.get("body_key", ""))), [])
		_draw_choices(vp, view.get("choices", []))
		return
	var pick: Dictionary = _pick()
	var type: String = str(pick.get("type", ""))
	if type == PICK_REMOVE or type == PICK_UPGRADE:
		_draw_picker(vp, type)
		return
	_draw_box(ScreenLayout.event_text_rect(vp, type == PICK_CARD_OFFER), tr(str(result.get("text_key", ""))), _effect_lines(result))
	if type == PICK_CARD_OFFER:
		var ids: Array = pick.get("ids", [])
		var rects: Array[Rect2] = ScreenLayout.event_offer_rects(vp, ids.size())
		for i: int in rects.size():
			_draw_offer_card(rects[i], str(ids[i]))
		var skip: Rect2 = ScreenLayout.shop_leave_rect(vp)
		UiButtons.draw_button(self, skip, tr(TEXT_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, BUTTON_FONT_SIZE)
		var label: Rect2 = ScreenLayout.shop_message_rect(vp)
		_text(label, label.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_PICK_CARD), LABEL_FONT_SIZE, LABEL_COLOR)
		return
	var cont: Rect2 = ScreenLayout.shop_buy_rect(vp)
	var text: String = tr(TEXT_FIGHT if _has_fight() else TEXT_CONTINUE)
	UiButtons.draw_button(self, cont, text, UiButtons.Style.DANGER if _has_fight() else UiButtons.Style.PRIMARY, UiButtons.is_pressed_at(self, cont), true, _fit(text, cont.size.x * 0.9, BUTTON_FONT_SIZE))
	_draw_message(vp)


func _draw_header(vp: Vector2, title: String) -> void:
	var band: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(band, band.get_center().y + TITLE_FONT_SIZE * 0.35, title, _fit(title, vp.x * 0.45, TITLE_FONT_SIZE, true), TITLE_COLOR, true)
	var right: float = (vp.x - ScreenLayout.side_margin(vp))
	var coin_left: float = ShopView.draw_gold(self, right, band.get_center().y, _flow.get_gold(), GOLD_FONT_SIZE, TITLE_COLOR)
	var run: RunSession = _flow.get_run()
	var max_hp: float = float(_flow.get_characters().get_character(run.character_id).get("max_hp", 1.0))
	var hp: float = max_hp if run.hp < 0.0 else minf(run.hp, max_hp)
	var text: String = tr(TEXT_HP) % [ceili(hp), ceili(max_hp)]
	var width: float = HudSkin.text_width(text, HEADER_FONT_SIZE)
	MenuFont.text(self, Vector2(coin_left - ShopView.COIN_GAP * 4.0 - width, band.get_center().y + HEADER_FONT_SIZE * 0.35), text, HEADER_FONT_SIZE, HEADER_COLOR)


# The parchment box: wrapped [param body], then [param lines] ([text, colour] pairs) one per line.
func _draw_box(rect: Rect2, body: String, lines: Array) -> void:
	HudSkin.plate_panel(self, rect, "navy")
	var pad: float = rect.size.x * BOX_PAD_RATIO
	var width: float = rect.size.x - pad * 2.0
	var font: Font = HudSkin.font()
	var room: int = maxi(int((rect.size.y - pad * 2.0) / (BODY_FONT_SIZE * LINE_SPACING)) - lines.size(), 1)
	var max_lines: int = mini(BODY_MAX_LINES, room)
	var y: float = rect.position.y + pad + BODY_FONT_SIZE
	draw_multiline_string(font, Vector2(rect.position.x + pad, y), body, HORIZONTAL_ALIGNMENT_LEFT, width, BODY_FONT_SIZE, max_lines, BODY_COLOR)
	var used: int = mini(roundi(font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, width, BODY_FONT_SIZE, max_lines).y / font.get_height(BODY_FONT_SIZE)), max_lines)
	y += font.get_height(BODY_FONT_SIZE) * used + EFFECT_FONT_SIZE * 0.5
	for line: Variant in lines:
		var pair: Array = line as Array
		MenuFont.text(self, Vector2(rect.position.x + pad, y), str(pair[0]), _fit(str(pair[0]), width, EFFECT_FONT_SIZE), pair[1] as Color, HORIZONTAL_ALIGNMENT_LEFT, width)
		y += EFFECT_FONT_SIZE * LINE_SPACING


func _draw_choices(vp: Vector2, choices: Array) -> void:
	var rects: Array[Rect2] = ScreenLayout.event_choice_rects(vp, choices.size())
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var choice: Dictionary = choices[i] as Dictionary
		var enabled: bool = bool(choice.get("enabled", true))
		var armed: bool = i == _armed
		var pressed: bool = enabled and not armed and UiButtons.is_pressed_at(self, rect)
		var back: Color = CHOICE_ARMED_BACK if armed else (CHOICE_BACK.lightened(HudSkin.BUTTON_PRESSED_LIGHTEN) if pressed else CHOICE_BACK)
		var outline: Color = CHOICE_ARMED_OUTLINE if armed or pressed else CHOICE_OUTLINE
		var text: Color = CHOICE_TEXT
		var cost_color: Color = COST_COLOR
		var reason_color: Color = REASON_COLOR
		if not enabled:
			back.a *= UiButtons.DIM_ALPHA
			outline.a *= UiButtons.DIM_ALPHA
			text.a *= UiButtons.DIM_ALPHA
			cost_color.a *= UiButtons.DIM_ALPHA
		# 2026-11-07: the ancient plate (navy; grey when locked; the armed choice ringed in gold).
		var _unused: Array = [back, outline]
		HudSkin.plate_panel(self, rect, "navy" if enabled else "grey", pressed, 1.0, armed)
		var inset: float = rect.size.x * CHOICE_INSET_RATIO
		var inner: float = rect.size.x - inset * 2.0
		var label_width: float = inner * CHOICE_LABEL_SHARE
		var label: String = tr(TEXT_CONFIRM_AGAIN) if armed else tr(str(choice.get("label_key", "")))
		var reason: String = ""
		if not enabled and not str(choice.get("reason_key", "")).is_empty():
			var args: Array = choice.get("reason_args", [])
			reason = tr(str(choice["reason_key"])) % args if not args.is_empty() else tr(str(choice["reason_key"]))
		var label_y: float = rect.position.y + rect.size.y * (CHOICE_LABEL_BASELINE if not reason.is_empty() else CHOICE_BASELINE)
		MenuFont.text(self, Vector2(rect.position.x + inset, label_y), label, _fit(label, label_width if not armed else inner, CHOICE_FONT_SIZE, true), text, HORIZONTAL_ALIGNMENT_LEFT, label_width if not armed else inner, true)
		if not reason.is_empty():
			MenuFont.text(self, Vector2(rect.position.x + inset, rect.position.y + rect.size.y * CHOICE_REASON_BASELINE), reason, _fit(reason, inner, REASON_FONT_SIZE), reason_color, HORIZONTAL_ALIGNMENT_LEFT, inner)
		var cost_key: String = str(choice.get("cost_key", ""))
		if not cost_key.is_empty() and not armed:
			var cost: String = tr(cost_key)
			var cost_width: float = inner - label_width
			MenuFont.text(self, Vector2(rect.end.x - inset - cost_width, label_y), cost, _fit(cost, cost_width, COST_FONT_SIZE), cost_color, HORIZONTAL_ALIGNMENT_RIGHT, cost_width)


# Effects of the result as [text, colour] lines (picks and fights show elsewhere).
func _effect_lines(result: Dictionary) -> Array:
	var lines: Array = []
	for raw: Variant in result.get("effects_applied", []):
		var effect: Dictionary = raw as Dictionary
		match str(effect.get("type", "")):
			"gold":
				var amount: int = int(effect.get("amount", 0))
				if amount > 0:
					lines.append([tr(TEXT_GOLD_GAIN) % amount, GAIN_COLOR])
				elif amount < 0:
					lines.append([tr(TEXT_GOLD_LOSE) % -amount, LOSS_COLOR])
			"hp":
				var delta: int = roundi(float(effect.get("delta", 0.0)))
				if delta > 0:
					lines.append([tr(TEXT_HP_GAIN) % delta, GAIN_COLOR])
				elif delta < 0:
					lines.append([tr(TEXT_HP_LOSE) % -delta, LOSS_COLOR])
			"relic":
				var relic: String = str(effect.get("id", ""))
				if not relic.is_empty():
					lines.append([tr(TEXT_RELIC) % _relic_name(relic), GAIN_COLOR])
			"curse":
				lines.append([tr(TEXT_CURSE) % tr(str(_flow.get_cards().get_skill(str(effect.get("id", ""))).get("name_key", ""))), ShopView.CURSE_COLOR.lightened(CURSE_TEXT_LIGHTEN)])
			"swap_relic":
				if not str(effect.get("lost", "")).is_empty():
					lines.append([tr(TEXT_SWAP) % [_relic_name(str(effect["lost"])), _relic_name(str(effect.get("gained", "")))], NEUTRAL_COLOR])
			"remove_card":
				var tokens: int = int(effect.get("tokens", 0))
				if tokens > 0:
					lines.append([tr(TEXT_TOKEN) % tokens, GAIN_COLOR])
			"run_modifier":
				lines.append([tr(TEXT_MODIFIER) % int(effect.get("matches_left", 0)), LOSS_COLOR])
	for done: String in _done_lines:
		lines.append([done, GAIN_COLOR])
	return lines


func _relic_name(id: String) -> String:
	return tr(str(RelicRegistry.shared_config().get_relic(id).get("name_key", id)))


# One offered card of a card_offer pick: rarity border, name, rarity, stats, the effect text.
func _draw_offer_card(rect: Rect2, id: String) -> void:
	var skill: Dictionary = _flow.get_cards().resolved(id, 1)
	var pressed: bool = UiButtons.is_pressed_at(self, rect)
	HudSkin.card(self, rect, RelicStrip.rarity_color(str(skill.get("rarity", "common"))), pressed)
	var inner: float = rect.size.x * 0.88
	var name: String = tr(str(skill.get("name_key", id)))
	_text(rect, rect.position.y + rect.size.y * 0.14, name, _fit(name, inner, 30, true), TITLE_COLOR, true)
	_text(rect, rect.position.y + rect.size.y * 0.25, tr(ShopView.RARITY_KEY_FORMAT % str(skill.get("rarity", "common"))), 20, NEUTRAL_COLOR)
	draw_multiline_string(HudSkin.font(), Vector2(rect.position.x + rect.size.x * 0.06, rect.position.y + rect.size.y * 0.38), CardText.describe_resolved(skill), HORIZONTAL_ALIGNMENT_CENTER, inner, 20, 6, NEUTRAL_COLOR)


func _draw_picker(vp: Vector2, type: String) -> void:
	var entries: Array[Dictionary] = _flow.get_run_deck_entries()
	var cards: SkillConfig = _flow.get_cards()
	var title: Rect2 = ScreenLayout.reward_subtitle_rect(vp)
	var title_text: String = tr(TEXT_PICK_UPGRADE if type == PICK_UPGRADE else TEXT_PICK_REMOVE)
	_text(title, title.get_center().y + LABEL_FONT_SIZE * 0.6, title_text, _fit(title_text, title.size.x, LABEL_FONT_SIZE + 4, true), TITLE_COLOR, true)
	var rects: Array[Rect2] = _picker.tile_rects(vp, entries.size())
	for i: int in rects.size():
		if rects[i].end.x < 0.0 or rects[i].position.x > vp.x:
			continue
		ShopView.draw_deck_tile(self, rects[i], str(entries[i].get("id", "")), int(entries[i].get("level", 1)), cards, i == _picker.marked, not _pickable(entries, i, type))
	if _picker.max_scroll(vp, entries.size()) > 0.0:
		var hint: Rect2 = ScreenLayout.deck_picker_hint_rect(vp)
		_text(hint, hint.get_center().y + LABEL_FONT_SIZE * 0.35, tr(TEXT_DRAG_HINT), LABEL_FONT_SIZE, LABEL_COLOR)
	var skip: Rect2 = ScreenLayout.shop_leave_rect(vp)
	UiButtons.draw_button(self, skip, tr(TEXT_SKIP), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, skip), true, BUTTON_FONT_SIZE)
	if _picker.marked >= 0:
		var confirm: Rect2 = ScreenLayout.shop_buy_rect(vp)
		var label: String = tr(TEXT_CONFIRM_UPGRADE if type == PICK_UPGRADE else TEXT_CONFIRM_REMOVE)
		UiButtons.draw_button(self, confirm, label, UiButtons.Style.PRIMARY if type == PICK_UPGRADE else UiButtons.Style.DANGER, UiButtons.is_pressed_at(self, confirm), true, _fit(label, confirm.size.x * 0.9, BUTTON_FONT_SIZE))
	_draw_message(vp)


func _draw_message(vp: Vector2) -> void:
	if _message.is_empty():
		return
	var rect: Rect2 = ScreenLayout.shop_message_rect(vp)
	_text(rect, rect.get_center().y + LABEL_FONT_SIZE * 0.35, _message, _fit(_message, rect.size.x, LABEL_FONT_SIZE), MESSAGE_BAD_COLOR)


# HudSkin outlined text centred over [param rect] at baseline [param y] (Bold when [param bold]).
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Largest size <= [param size] (floor MIN_FIT_FONT_SIZE) at which [param text] fits [param width] in the HudSkin font.
func _fit(text: String, width: float, size: int, bold: bool = false) -> int:
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted
