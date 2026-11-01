class_name UnlockToastView
extends Node2D
## "Mới mở" list (Story 037 Part E): a dimmed panel over the screen that lists what the player just unlocked
## (per row a reward glyph, the content's name and its kind: "Lá bài", "Mảnh", "Bảo vật", "Nhân vật",
## "Vùng"). An achievement without rewards still lists its own name. Tap anywhere dismisses.
## It shows only where a match is never running: the WORLD_MAP (after a region boss node, once its fate and
## reward flow ended), the ENDING screen and the defeat screen (IN_NODE with a finished run). While eligible
## and idle it asks [method GameFlow.take_new_unlocks] (achievement ids earned since the last call, queued by
## the milestone recording) once per frame; [method AchievementsConfig.rewards_of] gives the rows.
## Child of Main, LAST, so it draws over and takes input before every other screen; consumes every pointer
## event while open. Input dedup as in TitleView (emulated copies are consumed but never act). A press that
## arrives within [constant MIN_SHOW_SEC] of the list showing is ignored (a finger still on the previous
## screen's button must not dismiss it).
## DEV-ONLY user arg `--screen=unlock_toast` shows a sample list on the first eligible frame (captures).

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
## 2026-10-31 dark skin: a Night Stone panel framed in Grid Light, card-face rows, HudSkin outlined text.
const PANEL_BACK: Color = HudSkin.NIGHT_STONE
const PANEL_OUTLINE: Color = HudSkin.GRID_LIGHT
const TITLE_COLOR: Color = HudSkin.GRID_LIGHT
const NAME_COLOR: Color = HudSkin.TEXT
const KIND_COLOR: Color = HudSkin.TEXT_DIM
const HINT_COLOR: Color = HudSkin.TEXT_DIM
const ROW_BACK: Color = HudSkin.CARD_FILL
const GLYPH_COLOR: Color = HudSkin.GRID_LIGHT
const OUTLINE_WIDTH: float = 3.0

const TITLE_FONT_SIZE: int = 44
const NAME_FONT_SIZE: int = 30
const KIND_FONT_SIZE: int = 24
const HINT_FONT_SIZE: int = 20

## Panel as shares of the viewport; rows as shares of the panel height.
const PANEL_WIDTH_RATIO: float = 0.5
const PANEL_MAX_HEIGHT_RATIO: float = 0.86
const TITLE_BAND_RATIO: float = 0.2
const HINT_BAND_RATIO: float = 0.1
const ROW_HEIGHT_PX: float = 64.0
const ROW_GAP_PX: float = 8.0
## The most rows drawn; the rest collapse into a "+N" line.
const MAX_ROWS: int = 7
const MIN_SHOW_SEC: float = 0.35

const TEXT_TITLE: String = "unlock.title"
## "unlock.kind.<kind>" (format with the kind).
const KIND_LABEL_FORMAT: String = "unlock.kind.%s"
## "+%d": rows that did not fit.
const TEXT_MORE: String = "unlock.more"
const TEXT_TAP: String = "unlock.tap"
const DEV_ARG: String = "--screen=unlock_toast"
const DEV_SAMPLE_ROWS: int = 4

## Path to the GameFlow (Main/GameFlow).
@export var flow_path: NodePath = NodePath("../GameFlow")

var _flow: GameFlow
## Rows shown: [{kind, id, name (achievement name key for a reward-less one)}]; empty = closed.
var _rows: Array[Dictionary] = []
var _shown_msec: int = 0
var _dev_sample: bool = false


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow
	_dev_sample = OS.get_cmdline_user_args().has(DEV_ARG)


## True while the list is up.
func is_open() -> bool:
	return not _rows.is_empty()


## The rows being shown ([{kind, id, name_key}]).
func get_rows() -> Array[Dictionary]:
	return _rows


## Shows the unlock list of achievement [param ids] now (no GameFlow queue involved); nothing for an empty list.
func show_for(ids: Array) -> void:
	var rows: Array[Dictionary] = build_rows(AchievementsConfig.shared(), ids)
	if rows.is_empty():
		return
	_rows = rows
	_shown_msec = Time.get_ticks_msec()


## Rows for achievements [param ids]: one per reward ([param cfg] rewards_of), plus one for every achievement
## that has no reward (kind "achievement", its name_key). Pure.
static func build_rows(cfg: AchievementsConfig, ids: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for reward: Dictionary in cfg.rewards_of(ids):
		rows.append({"kind": str(reward.get("kind", "")), "id": str(reward.get("id", "")), "name_key": ""})
	for id: Variant in ids:
		var def: Dictionary = cfg.get_def(str(id))
		if def.is_empty() or not (def.get("rewards", []) as Array).is_empty():
			continue
		rows.append({"kind": "achievement", "id": str(id), "name_key": str(def.get("name_key", id))})
	return rows


## Whether the current phase is one where a match can never be running (see the class doc).
func is_eligible_phase() -> bool:
	if _flow == null:
		return false
	match _flow.get_phase():
		GameFlow.Phase.WORLD_MAP, GameFlow.Phase.ENDING:
			return true
		GameFlow.Phase.IN_NODE:
			return _flow.get_run_result() != GameFlow.RunResult.NONE
	return false


func _process(_delta: float) -> void:
	if _rows.is_empty() and is_eligible_phase():
		if _dev_sample:
			_dev_sample = false
			_rows = _sample_rows()
			_shown_msec = Time.get_ticks_msec()
		elif _flow.has_method("take_new_unlocks"):
			var ids: Array = _flow.call("take_new_unlocks")
			if not ids.is_empty():
				show_for(ids)
	elif not _rows.is_empty() and not is_eligible_phase():
		_rows = []  # the screen changed under the list (a dev jump): drop it
	queue_redraw()


# DEV sample: the rewards of the first few rewarded achievements.
func _sample_rows() -> Array[Dictionary]:
	var cfg: AchievementsConfig = AchievementsConfig.shared()
	var ids: Array = []
	for id: String in cfg.ids():
		if not (cfg.get_def(id).get("rewards", []) as Array).is_empty():
			ids.append(id)
		if ids.size() >= DEV_SAMPLE_ROWS:
			break
	return build_rows(cfg, ids)


func _input(event: InputEvent) -> void:
	if _rows.is_empty():
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return  # keys stay with GameFlow (Esc / back)
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		pressed = button.button_index == MOUSE_BUTTON_LEFT and button.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed and float(Time.get_ticks_msec() - _shown_msec) / 1000.0 >= MIN_SHOW_SEC:
		dismiss()


## Closes the list.
func dismiss() -> void:
	_rows = []


## Panel rectangle for [param row_count] drawn rows.
static func panel_rect(vp: Vector2, row_count: int) -> Rect2:
	var width: float = vp.x * PANEL_WIDTH_RATIO
	var rows_h: float = (ROW_HEIGHT_PX + ROW_GAP_PX) * row_count
	var chrome: float = 1.0 - TITLE_BAND_RATIO - HINT_BAND_RATIO
	var height: float = minf(rows_h / chrome, vp.y * PANEL_MAX_HEIGHT_RATIO)
	height = maxf(height, vp.y * 0.4)
	return Rect2((vp.x - width) * 0.5, (vp.y - height) * 0.5, width, height)


func _draw() -> void:
	if _rows.is_empty():
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var shown: int = mini(_rows.size(), MAX_ROWS)
	var panel: Rect2 = panel_rect(vp, shown + (1 if _rows.size() > MAX_ROWS else 0))
	var cut: float = HudSkin.button_cut(panel)
	HudSkin.panel(self, panel, [0.0, cut, 0.0, cut], PANEL_BACK, PANEL_OUTLINE, OUTLINE_WIDTH)
	MenuFont.text(self, Vector2(panel.position.x, panel.position.y + panel.size.y * TITLE_BAND_RATIO * 0.78), tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, true)
	var pad: float = panel.size.x * 0.05
	var y: float = panel.position.y + panel.size.y * TITLE_BAND_RATIO
	for i: int in shown:
		var row := Rect2(panel.position.x + pad, y, panel.size.x - pad * 2.0, ROW_HEIGHT_PX)
		_draw_row(row, _rows[i])
		y += ROW_HEIGHT_PX + ROW_GAP_PX
	if _rows.size() > MAX_ROWS:
		MenuFont.text(self, Vector2(panel.position.x, y + KIND_FONT_SIZE), tr(TEXT_MORE) % (_rows.size() - MAX_ROWS), KIND_FONT_SIZE, KIND_COLOR, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	MenuFont.text(self, Vector2(panel.position.x, panel.end.y - panel.size.y * HINT_BAND_RATIO * 0.35), tr(TEXT_TAP), HINT_FONT_SIZE, HINT_COLOR, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)


func _draw_row(rect: Rect2, row: Dictionary) -> void:
	HudSkin.panel(self, rect, [0.0, HudSkin.button_cut(rect), 0.0, 0.0], ROW_BACK, HudSkin.CARD_LINE)
	var kind: String = str(row.get("kind", ""))
	var glyph := Rect2(rect.position + Vector2(10.0, 10.0), Vector2.ONE * (rect.size.y - 20.0))
	if kind == "achievement":
		AchievementsView.draw_medal(self, glyph, true, false)
	else:
		AchievementsView.draw_reward_glyph(self, glyph, kind, GLYPH_COLOR)
	var name_text: String = tr(str(row.get("name_key", ""))) if kind == "achievement" else AchievementsView.reward_name(_flow, kind, str(row.get("id", "")))
	var kind_text: String = tr(KIND_LABEL_FORMAT % kind)
	var text_x: float = glyph.end.x + 14.0
	var width: float = rect.end.x - 10.0 - text_x
	var kind_w: float = HudSkin.text_width(kind_text, KIND_FONT_SIZE)
	MenuFont.text(self, Vector2(text_x, rect.get_center().y + NAME_FONT_SIZE * 0.35), name_text, NAME_FONT_SIZE, NAME_COLOR, HORIZONTAL_ALIGNMENT_LEFT, maxf(width - kind_w - 12.0, 40.0), true)
	MenuFont.text(self, Vector2(rect.end.x - 10.0 - kind_w, rect.get_center().y + KIND_FONT_SIZE * 0.35), kind_text, KIND_FONT_SIZE, KIND_COLOR, HORIZONTAL_ALIGNMENT_LEFT, kind_w + 2.0)
