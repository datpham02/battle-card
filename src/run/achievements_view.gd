class_name AchievementsView
extends Node2D
## Achievements screen (Story 037 Part E): a 4-column grid of every achievement of
## [AchievementsConfig], opened from the title ("Thành tựu", [method GameFlow.open_achievements]). Each
## cell has a code-drawn medallion (gold star when earned, padlock when not, "?" when hidden and not
## earned), the name, the state (earned / progress "n/N" from [method UnlockRules.progress_of] / "???"
## for a hidden one) and one small glyph per reward kind (card, piece, relic, character, region). The
## grid scrolls vertically with a thumb drag and keeps its speed after the release (inertia). A tap on
## a cell opens a detail panel (condition, rewards, progress); a tap anywhere closes it. The header
## carries the "x/22" counter; "Về" sits in the bottom-left corner (left thumb reach).
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in
## [constant GameFlow.Phase.ACHIEVEMENTS]; the scroll and the open detail are its only state. Input
## dedup as in TitleView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed
## but never act). Placeholder art; every string is a TEXT_* key drawn through tr().
## DEV-ONLY user arg `--screen=achievements_detail=<id>` opens that detail on entry (captures).

## 2026-10-31 dark skin (HudSkin): screen background with the header band, earned cells as Grid Light-edged card
## faces, locked cells as Night Stone panels, outlined text; meaning colours (earned green, progress blue, medal
## gold) lightened to read on the dark field.
const BG_COLOR: Color = HudSkin.SCREEN_BG
const TITLE_COLOR: Color = HudSkin.IVORY
const CELL_BACK: Color = HudSkin.CARD_FILL
const CELL_BACK_LOCKED: Color = HudSkin.NIGHT_STONE
const CELL_OUTLINE: Color = HudSkin.MIST
const CELL_OUTLINE_EARNED: Color = HudSkin.GRID_LIGHT
const NAME_COLOR: Color = HudSkin.TEXT
const NAME_COLOR_LOCKED: Color = HudSkin.TEXT_DIM
const STATE_COLOR: Color = HudSkin.TEXT_DIM
const EARNED_COLOR: Color = HudSkin.HP_FILL
const PROGRESS_BACK: Color = HudSkin.HP_GROOVE
const PROGRESS_FILL: Color = Color("6FA8D6")
const MEDAL_EARNED: Color = Color(0.95, 0.75, 0.2)
const MEDAL_LOCKED: Color = HudSkin.NIGHT_STONE_LIGHT
## The padlock / "?" mark of a locked medallion.
const MEDAL_MARK_LOCKED: Color = HudSkin.TEXT_DIM
const GLYPH_COLOR: Color = HudSkin.TEXT_DIM
const GLYPH_EARNED_COLOR: Color = HudSkin.GRID_LIGHT
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const PANEL_BACK: Color = HudSkin.NIGHT_STONE
const PANEL_OUTLINE: Color = HudSkin.GRID_LIGHT
const OUTLINE_WIDTH: float = 3.0

const TITLE_FONT_SIZE: int = 44
const COUNTER_FONT_SIZE: int = 36
const BUTTON_FONT_SIZE: int = 28
const NAME_FONT_SIZE: int = 24
const STATE_FONT_SIZE: int = 20
const DETAIL_TITLE_FONT_SIZE: int = 34
const DETAIL_BODY_FONT_SIZE: int = 24
const DETAIL_HEAD_FONT_SIZE: int = 20
const HINT_FONT_SIZE: int = 18

## Layout as shares of the viewport (1280x720 base).
const COLUMNS: int = 4
const HEADER_BOTTOM_RATIO: float = 0.13
const FOOTER_TOP_RATIO: float = 0.865
const CELL_HEIGHT_RATIO: float = 0.215
const GAP_RATIO: float = 0.016
const BACK_WIDTH_RATIO: float = 0.1
const BACK_HEIGHT_RATIO: float = 0.09
const PANEL_RECT_RATIO: Rect2 = Rect2(0.16, 0.14, 0.68, 0.72)
## Inside a cell, shares of the cell size.
const MEDAL_SIZE_RATIO: float = 0.4
const PAD_RATIO: float = 0.06
const BAR_HEIGHT_RATIO: float = 0.06
const GLYPH_SIZE_RATIO: float = 0.2

## Scrolling: a drag shorter than TAP_SLOP is still a tap; after the release the speed (px/s) decays by
## FRICTION per second and stops under MIN_SPEED; speed is smoothed with VELOCITY_BLEND.
const TAP_SLOP: float = 14.0
const FRICTION: float = 3.2
const MIN_SPEED: float = 25.0
const MAX_SPEED: float = 4500.0
const VELOCITY_BLEND: float = 0.5

const TEXT_TITLE: String = "achievements.title"
## "%d/%d": earned count / total (header), progress (cell and detail).
const TEXT_COUNTER: String = "achievements.counter"
const TEXT_HIDDEN: String = "achievements.hidden"
const TEXT_HIDDEN_DESC: String = "achievements.hidden_desc"
const TEXT_EARNED: String = "achievements.earned"
const TEXT_BACK: String = "achievements.back"
const TEXT_DETAIL_CONDITION: String = "achievements.detail.condition"
const TEXT_DETAIL_REWARDS: String = "achievements.detail.rewards"
const TEXT_DETAIL_PROGRESS: String = "achievements.detail.progress"
const TEXT_DETAIL_NO_REWARD: String = "achievements.detail.no_reward"
const TEXT_DETAIL_CLOSE: String = "achievements.detail.close"
## "achievements.reward.<kind>" (format with the kind): the short kind label next to a reward glyph.
const REWARD_LABEL_FORMAT: String = "achievements.reward.%s"
const DEV_DETAIL_ARG: String = "--screen=achievements_detail="

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow
var _scroll: float = 0.0
var _velocity: float = 0.0
var _press_active: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0
var _press_moving: bool = false
var _press_stopped_inertia: bool = false
var _last_drag_msec: int = 0
var _detail_id: String = ""
var _was_active: bool = false


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node(flow_path) as GameFlow
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_DETAIL_ARG):
			_detail_id = arg.trim_prefix(DEV_DETAIL_ARG)


# Redraws every frame, also while inactive (a CanvasItem keeps its last frame until the next redraw).
func _process(delta: float) -> void:
	var active: bool = _is_active()
	if active and not _was_active and _detail_id.is_empty():
		_scroll = 0.0
	_was_active = active
	if active and not _press_active and absf(_velocity) > MIN_SPEED:
		_scroll += _velocity * delta
		_velocity *= exp(-FRICTION * delta)
		var limit: float = max_scroll(get_viewport_rect().size)
		if _scroll < 0.0 or _scroll > limit:
			_scroll = clampf(_scroll, 0.0, limit)
			_velocity = 0.0
	elif not _press_active:
		_velocity = 0.0
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.ACHIEVEMENTS


## True while the screen is up.
func is_open() -> bool:
	return _is_active()


## Scroll offset of the grid in pixels (0 = top).
func get_scroll() -> float:
	return _scroll


## Sets the scroll offset (clamped to 0..[method max_scroll]) and stops the inertia.
func set_scroll(value: float) -> void:
	_scroll = clampf(value, 0.0, max_scroll(get_viewport_rect().size))
	_velocity = 0.0


## Id of the open detail panel ("" = none).
func detail_id() -> String:
	return _detail_id


## Opens the detail panel of achievement [param id] (ignored when unknown).
func open_detail(id: String) -> void:
	if _config().has(id):
		_detail_id = id


## Closes the detail panel.
func close_detail() -> void:
	_detail_id = ""


## The grid viewport (between the header and the footer).
static func grid_rect(vp: Vector2) -> Rect2:
	var top: float = vp.y * HEADER_BOTTOM_RATIO
	return Rect2(0.0, top, vp.x, vp.y * FOOTER_TOP_RATIO - top)


## "Về": the bottom-left corner, in the left thumb's reach.
static func back_rect(vp: Vector2) -> Rect2:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	var size := Vector2(vp.x * BACK_WIDTH_RATIO, vp.y * BACK_HEIGHT_RATIO)
	return Rect2(Vector2(margin, vp.y - margin - size.y), size)


## The detail panel rectangle.
static func panel_rect(vp: Vector2) -> Rect2:
	return Rect2(vp * PANEL_RECT_RATIO.position, vp * PANEL_RECT_RATIO.size)


## Rectangle of cell [param index] (0-based, file order) of the unscrolled grid; add the scroll offset
## (subtract it) for its on-screen place. All cells share one size.
static func cell_rect(vp: Vector2, index: int) -> Rect2:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	var gap: float = vp.x * GAP_RATIO
	var width: float = (vp.x - margin * 2.0 - gap * (COLUMNS - 1)) / COLUMNS
	var height: float = vp.y * CELL_HEIGHT_RATIO
	var col: int = index % COLUMNS
	@warning_ignore("integer_division")
	var row: int = index / COLUMNS
	var top: float = vp.y * HEADER_BOTTOM_RATIO + gap
	return Rect2(margin + (width + gap) * col, top + (height + gap) * row, width, height)


## How far the grid can scroll (0 when everything fits).
func max_scroll(vp: Vector2) -> float:
	var count: int = _config().ids().size()
	if count <= 0:
		return 0.0
	var last: Rect2 = cell_rect(vp, count - 1)
	var view: Rect2 = grid_rect(vp)
	return maxf(last.end.y + vp.x * GAP_RATIO - view.end.y, 0.0)


## Index of the cell under [param pos] (-1 outside the grid area or between cells).
func cell_at(pos: Vector2, vp: Vector2) -> int:
	if not grid_rect(vp).has_point(pos):
		return -1
	var count: int = _config().ids().size()
	for i: int in count:
		var rect: Rect2 = cell_rect(vp, i)
		rect.position.y -= _scroll
		if rect.has_point(pos):
			return i
	return -1


func _config() -> AchievementsConfig:
	return AchievementsConfig.shared()


func _progress() -> ProgressState:
	return _flow.get_progress()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	var press: Vector2 = _pointer(event, true)
	var release: Vector2 = _pointer(event, false)
	if press != Vector2.INF:
		_on_press(press, vp)
	elif release != Vector2.INF:
		_on_release(release, vp)
	elif _press_active:
		_on_move(event)


func _on_press(pos: Vector2, vp: Vector2) -> void:
	_press_active = true
	_press_pos = pos
	_press_scroll = _scroll
	_press_moving = false
	_press_stopped_inertia = absf(_velocity) > MIN_SPEED
	_velocity = 0.0
	_last_drag_msec = Time.get_ticks_msec()
	if _detail_id.is_empty() and back_rect(vp).has_point(pos):
		_press_active = false
		_flow.close_achievements()


func _on_move(event: InputEvent) -> void:
	var pos: Vector2 = _pointer_position(event)
	if pos == Vector2.INF or not _detail_id.is_empty():
		return
	if not _press_moving and pos.distance_to(_press_pos) > TAP_SLOP:
		_press_moving = true
	if not _press_moving:
		return
	var before: float = _scroll
	_scroll = clampf(_press_scroll - (pos.y - _press_pos.y), 0.0, max_scroll(get_viewport_rect().size))
	var now: int = Time.get_ticks_msec()
	var dt: float = maxf(float(now - _last_drag_msec) / 1000.0, 0.001)
	_last_drag_msec = now
	var instant: float = clampf((_scroll - before) / dt, -MAX_SPEED, MAX_SPEED)
	_velocity = lerpf(_velocity, instant, VELOCITY_BLEND)


func _on_release(pos: Vector2, vp: Vector2) -> void:
	if not _press_active:
		return
	_press_active = false
	if not _detail_id.is_empty():
		_detail_id = ""
		_velocity = 0.0
		return
	if _press_moving:
		# A stalled finger before the lift-off kills the inertia.
		if Time.get_ticks_msec() - _last_drag_msec > 120:
			_velocity = 0.0
		return
	_velocity = 0.0
	if _press_stopped_inertia:
		return  # the tap only stopped the scrolling
	var index: int = cell_at(pos, vp)
	if index >= 0:
		open_detail(_config().ids()[index])


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


func _pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.INF


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var cfg: AchievementsConfig = _config()
	var progress: ProgressState = _progress()
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), HEADER_BOTTOM_RATIO)
	var ids: Array[String] = cfg.ids()
	var view: Rect2 = grid_rect(vp)
	for i: int in ids.size():
		var rect: Rect2 = cell_rect(vp, i)
		rect.position.y -= _scroll
		if rect.end.y < view.position.y or rect.position.y > view.end.y:
			continue
		_draw_cell(rect, ids[i], cfg, progress)
	# Bands over the cells that scrolled past the grid edges.
	draw_rect(Rect2(0.0, 0.0, vp.x, view.position.y), HudSkin.SCREEN_BAND)
	draw_rect(Rect2(0.0, view.end.y, vp.x, vp.y - view.end.y), BG_COLOR)
	var title := Rect2(0.0, 0.0, vp.x, view.position.y)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER, true)
	var counter := Rect2(vp.x * 0.7, 0.0, vp.x * (1.0 - ScreenLayout.MARGIN_RATIO) - vp.x * 0.7, view.position.y)
	_text(counter, counter.get_center().y + COUNTER_FONT_SIZE * 0.35, tr(TEXT_COUNTER) % [earned_count(), ids.size()], COUNTER_FONT_SIZE, EARNED_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_draw_scroll_bar(vp, view)
	var back: Rect2 = back_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	if not _detail_id.is_empty():
		_draw_detail(vp, cfg, progress)


## How many achievements the save has earned.
func earned_count() -> int:
	var count: int = 0
	var progress: ProgressState = _progress()
	for id: String in _config().ids():
		if progress.has_achievement(id):
			count += 1
	return count


func _draw_scroll_bar(vp: Vector2, view: Rect2) -> void:
	var limit: float = max_scroll(vp)
	if limit <= 0.0:
		return
	var track_h: float = view.size.y
	var bar_h: float = maxf(track_h * view.size.y / (view.size.y + limit), 40.0)
	var y: float = view.position.y + (track_h - bar_h) * (_scroll / limit)
	draw_rect(Rect2(vp.x - 8.0, y, 5.0, bar_h), Color(CELL_OUTLINE, 0.7))


func _draw_cell(rect: Rect2, id: String, cfg: AchievementsConfig, progress: ProgressState) -> void:
	var def: Dictionary = cfg.get_def(id)
	var earned: bool = progress.has_achievement(id)
	var hidden: bool = bool(def.get("hidden", false)) and not earned
	HudSkin.panel(self, rect, [0.0, HudSkin.button_cut(rect), 0.0, 0.0], CELL_BACK if earned else CELL_BACK_LOCKED, CELL_OUTLINE_EARNED if earned else CELL_OUTLINE, 2.0 if earned else HudSkin.PANEL_LINE_WIDTH)
	var pad: float = rect.size.x * PAD_RATIO
	var medal_edge: float = minf(rect.size.y * MEDAL_SIZE_RATIO * 1.4, rect.size.x * MEDAL_SIZE_RATIO * 0.6)
	var medal := Rect2(rect.position + Vector2(pad, pad), Vector2(medal_edge, medal_edge))
	draw_medal(self, medal, earned, hidden)
	var text_x: float = medal.end.x + pad
	var text_w: float = rect.end.x - pad - text_x
	var name_text: String = tr(TEXT_HIDDEN) if hidden else tr(str(def.get("name_key", id)))
	var name_size: int = NAME_FONT_SIZE
	_multiline(Vector2(text_x, rect.position.y + pad + name_size), name_text, HORIZONTAL_ALIGNMENT_LEFT, text_w, name_size, 2, NAME_COLOR if earned else NAME_COLOR_LOCKED, true)
	var bar_h: float = rect.size.y * BAR_HEIGHT_RATIO
	var state_y: float = rect.end.y - pad - bar_h - 6.0
	if earned:
		_text(Rect2(text_x, 0.0, text_w, 0.0), state_y, tr(TEXT_EARNED), STATE_FONT_SIZE, EARNED_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	elif hidden:
		_text(Rect2(text_x, 0.0, text_w, 0.0), state_y, tr(TEXT_HIDDEN), STATE_FONT_SIZE, STATE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		var info: Dictionary = UnlockRules.progress_of(cfg, id, progress)
		var cur: int = int(info.get("current", 0))
		var target: int = maxi(int(info.get("target", 1)), 1)
		_text(Rect2(text_x, 0.0, text_w, 0.0), state_y, tr(TEXT_COUNTER) % [cur, target], STATE_FONT_SIZE, STATE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Rect2(rect.position.x + pad, rect.end.y - pad - bar_h, rect.size.x - pad * 2.0, bar_h)
		draw_rect(bar, PROGRESS_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(cur) / float(target), 0.0, 1.0), bar.size.y)), PROGRESS_FILL)
	# Reward kind glyphs, right-aligned on the state row.
	var kinds: Array[String] = reward_kinds(def)
	var glyph: float = rect.size.y * GLYPH_SIZE_RATIO
	var gx: float = rect.end.x - pad - glyph
	for i: int in range(kinds.size() - 1, -1, -1):
		draw_reward_glyph(self, Rect2(gx, state_y - glyph * 0.85, glyph, glyph), kinds[i], GLYPH_EARNED_COLOR if earned else GLYPH_COLOR)
		gx -= glyph * 1.2


## Distinct reward kinds of an achievement definition, in reward order.
static func reward_kinds(def: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for reward: Variant in def.get("rewards", []) as Array:
		var kind: String = str((reward as Dictionary).get("kind", ""))
		if not kind.is_empty() and not kinds.has(kind):
			kinds.append(kind)
	return kinds


func _draw_detail(vp: Vector2, cfg: AchievementsConfig, progress: ProgressState) -> void:
	var id: String = _detail_id
	var def: Dictionary = cfg.get_def(id)
	if def.is_empty():
		return
	var earned: bool = progress.has_achievement(id)
	var hidden: bool = bool(def.get("hidden", false)) and not earned
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = panel_rect(vp)
	var cut: float = HudSkin.button_cut(panel)
	HudSkin.panel(self, panel, [0.0, cut, 0.0, cut], PANEL_BACK, PANEL_OUTLINE, OUTLINE_WIDTH)
	var pad: float = panel.size.x * 0.04
	var medal := Rect2(panel.position + Vector2(pad, pad), Vector2.ONE * panel.size.y * 0.16)
	draw_medal(self, medal, earned, hidden)
	var text_x: float = medal.end.x + pad
	var text_w: float = panel.end.x - pad - text_x
	var title_text: String = tr(TEXT_HIDDEN) if hidden else tr(str(def.get("name_key", id)))
	_text(Rect2(text_x, 0.0, text_w, 0.0), medal.position.y + DETAIL_TITLE_FONT_SIZE, title_text, _fit_font_size(title_text, text_w, DETAIL_TITLE_FONT_SIZE, 20, true), HudSkin.IVORY, HORIZONTAL_ALIGNMENT_LEFT, true)
	var info: Dictionary = UnlockRules.progress_of(cfg, id, progress)
	var cur: int = int(info.get("current", 0))
	var target: int = maxi(int(info.get("target", 1)), 1)
	var state_text: String = tr(TEXT_EARNED) if earned else tr(TEXT_DETAIL_PROGRESS) % [cur, target]
	if hidden:
		state_text = tr(TEXT_HIDDEN)
	_text(Rect2(text_x, 0.0, text_w, 0.0), medal.end.y - 6.0, state_text, DETAIL_BODY_FONT_SIZE, EARNED_COLOR if earned else STATE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	var inner_w: float = panel.size.x - pad * 2.0
	var y: float = medal.end.y + pad * 1.6
	_text(Rect2(panel.position.x + pad, 0.0, inner_w, 0.0), y, tr(TEXT_DETAIL_CONDITION), DETAIL_HEAD_FONT_SIZE, PROGRESS_FILL, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += DETAIL_BODY_FONT_SIZE + 6.0
	var condition: String = tr(TEXT_HIDDEN_DESC) if hidden else tr(str(def.get("desc_key", "")))
	_multiline(Vector2(panel.position.x + pad, y), condition, HORIZONTAL_ALIGNMENT_LEFT, inner_w, DETAIL_BODY_FONT_SIZE, 3, HudSkin.TEXT)
	y += (DETAIL_BODY_FONT_SIZE + 6.0) * 3.0 + pad * 0.6
	_text(Rect2(panel.position.x + pad, 0.0, inner_w, 0.0), y, tr(TEXT_DETAIL_REWARDS), DETAIL_HEAD_FONT_SIZE, PROGRESS_FILL, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += DETAIL_BODY_FONT_SIZE + 10.0
	var rewards: Array = def.get("rewards", []) as Array
	if rewards.is_empty():
		_text(Rect2(panel.position.x + pad, 0.0, inner_w, 0.0), y, tr(TEXT_DETAIL_NO_REWARD), DETAIL_BODY_FONT_SIZE, STATE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	for reward: Variant in rewards:
		var kind: String = str((reward as Dictionary).get("kind", ""))
		var reward_id: String = str((reward as Dictionary).get("id", ""))
		var glyph := Rect2(panel.position.x + pad, y - DETAIL_BODY_FONT_SIZE, DETAIL_BODY_FONT_SIZE * 1.2, DETAIL_BODY_FONT_SIZE * 1.2)
		draw_reward_glyph(self, glyph, kind, GLYPH_EARNED_COLOR)
		var line: String = "%s: %s" % [tr(REWARD_LABEL_FORMAT % kind), tr(TEXT_HIDDEN) if hidden else reward_name(_flow, kind, reward_id)]
		_text(Rect2(glyph.end.x + pad * 0.5, 0.0, panel.end.x - pad - glyph.end.x, 0.0), y, line, DETAIL_BODY_FONT_SIZE, NAME_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		y += DETAIL_BODY_FONT_SIZE * 1.6
	_text(Rect2(panel.position.x, 0.0, panel.size.x, 0.0), panel.end.y - pad * 0.6, tr(TEXT_DETAIL_CLOSE), HINT_FONT_SIZE, STATE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)


# --- Shared helpers (the unlock toast uses them too) ---------------------------


## Player-facing name of reward [param id] of [param kind] (card, piece, relic, character, region); the id
## itself when it is unknown.
static func reward_name(flow: GameFlow, kind: String, id: String) -> String:
	match kind:
		"card":
			var skill: Dictionary = flow.get_cards().get_skill(id)
			return TranslationServer.translate(str(skill.get("name_key", id)))
		"piece":
			return TranslationServer.translate("piece.%s.name" % id)
		"relic":
			return str(flow.relic_info(id).get("name", id))
		"character":
			var character: Dictionary = flow.get_characters().get_character(id)
			return TranslationServer.translate(str(character.get("name_key", id)))
		"region":
			var name_text: String = flow.region_name(id)
			return id if name_text.is_empty() else name_text
	return id


## Code-drawn medallion: gold with a star when [param earned], grey with a padlock when not, grey with a
## "?" when [param hidden].
static func draw_medal(canvas: CanvasItem, rect: Rect2, earned: bool, hidden: bool) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	# A flat-topped octagon (no circles in the UI).
	var rim: PackedVector2Array = HudSkin.regular_points(center, radius, 8, -PI * 0.5 + PI / 8.0)
	canvas.draw_colored_polygon(rim, MEDAL_EARNED if earned else MEDAL_LOCKED)
	canvas.draw_polyline(HudSkin.perimeter_trace(rim, 1.0), CELL_OUTLINE_EARNED if earned else CELL_OUTLINE, 2.0)
	if earned:
		var points := PackedVector2Array()
		for i: int in 10:
			var r: float = radius * (0.62 if i % 2 == 0 else 0.26)
			var a: float = -PI * 0.5 + TAU * float(i) / 10.0
			points.append(center + Vector2(cos(a), sin(a)) * r)
		canvas.draw_colored_polygon(points, Color(1.0, 0.97, 0.85))
	elif hidden:
		var size: int = roundi(radius * 1.3)
		MenuFont.text(canvas, Vector2(center.x - radius, center.y + size * 0.35), "?", size, MEDAL_MARK_LOCKED, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, true)
	else:
		var body := Rect2(center + Vector2(-radius * 0.34, -radius * 0.02), Vector2(radius * 0.68, radius * 0.5))
		canvas.draw_rect(body, MEDAL_MARK_LOCKED)
		canvas.draw_polyline(HudSkin.shackle_points(center.x, body.position.y, radius * 0.24), MEDAL_MARK_LOCKED, 4.0)


## Code-drawn glyph of a reward [param kind] inside [param rect]: card (a tall rectangle), piece (an L of squares),
## relic (a diamond), character (a hexagon head over chamfered shoulders), region (two peaks and a flag); all angular.
static func draw_reward_glyph(canvas: CanvasItem, rect: Rect2, kind: String, color: Color) -> void:
	var c: Vector2 = rect.get_center()
	var s: float = minf(rect.size.x, rect.size.y)
	match kind:
		"card":
			canvas.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.45), Vector2(s * 0.6, s * 0.9)), color, false, maxf(s * 0.1, 2.0))
			canvas.draw_line(c + Vector2(-s * 0.15, -s * 0.12), c + Vector2(s * 0.15, -s * 0.12), color, maxf(s * 0.08, 2.0))
			canvas.draw_line(c + Vector2(-s * 0.15, s * 0.1), c + Vector2(s * 0.15, s * 0.1), color, maxf(s * 0.08, 2.0))
		"piece":
			var cell: float = s * 0.3
			var origin: Vector2 = c - Vector2(cell * 1.5, cell * 1.5)
			for p: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 2), Vector2(2, 2)]:
				canvas.draw_rect(Rect2(origin + p * cell, Vector2.ONE * (cell - 1.5)), color)
		"relic":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.4, 0), c + Vector2(0, s * 0.5), c + Vector2(-s * 0.4, 0)]), color)
		"character":
			canvas.draw_colored_polygon(HudSkin.regular_points(c + Vector2(0, -s * 0.22), s * 0.2, 6), color)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, s * 0.5), c + Vector2(-s * 0.42, s * 0.3),
				c + Vector2(-s * 0.22, s * 0.1), c + Vector2(s * 0.22, s * 0.1), c + Vector2(s * 0.42, s * 0.3), c + Vector2(s * 0.42, s * 0.5)]), color)
		"region":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.4), c + Vector2(-s * 0.15, -s * 0.2), c + Vector2(s * 0.1, s * 0.4)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, s * 0.4), c + Vector2(s * 0.25, -s * 0.05), c + Vector2(s * 0.5, s * 0.4)]), color.darkened(0.2))
			canvas.draw_line(c + Vector2(s * 0.25, -s * 0.05), c + Vector2(s * 0.25, -s * 0.5), color, maxf(s * 0.07, 2.0))
		_:
			HudSkin.diamond(canvas, c, s * 0.35, color, Color.TRANSPARENT, 0.0)


# Largest font size from [param base] down to [param minimum] whose one-line [param text] fits [param width]
# (measured in the HudSkin font, Bold when [param bold]).
func _fit_font_size(text: String, width: float, base: int, minimum: int = 12, bold: bool = false) -> int:
	var size: int = base
	while size > minimum and HudSkin.text_width(text, size, bold) > width:
		size -= 1
	return size


# Single-line outlined text (HudSkin) at baseline [param y] aligned inside the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, align: HorizontalAlignment, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, align, rect.size.x, bold)


# Word-wrapped outlined text in the HudSkin font (the multi-line twin of HudSkin.text).
func _multiline(pos: Vector2, text: String, align: HorizontalAlignment, width: float, size: int, max_lines: int, color: Color, bold: bool = false) -> void:
	if text.is_empty():
		return
	var f: Font = HudSkin.font(bold)
	draw_multiline_string_outline(f, pos, text, align, width, size, max_lines, HudSkin.TEXT_OUTLINE_PX, Color(HudSkin.TEXT_OUTLINE, color.a))
	draw_multiline_string(f, pos, text, align, width, size, max_lines, color)
