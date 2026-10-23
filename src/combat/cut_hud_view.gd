class_name CutHudView
extends Node2D
## Cut UI (Story 008), drawn above the board and the field points, below the d-pad:
## (1) PREVIEW of the current selection on the boss half: covered cells, perimeter dots with
## labels, lines in selection order (closed for 3-4 points), cell count and expected damage;
## (2) CONFIRM button ("Chốt"), dimmed with the swing countdown while a swing runs;
## (3) SKILL MENU panel: countdown bar + one button per skill with its lock reason;
## (4) SWING overlay: covered cells red with the countdown; (5) HIT / MISS marker after a swing;
## (6) the boss's QUEUED combo swing (Story 013) as a hatched lighter-red layer under its running swing.
## It owns no game state: it reads CombatView and calls confirm_selection() / CutFlow.choose().
##
## Input is read in _input (like DPadView) and consumed, so HandInputController never sees a
## press on the confirm button or the menu panel. Dedup: with emulate_mouse_from_touch a touch
## also arrives as a mouse event, and with emulate_touch_from_mouse a click also arrives as a
## touch. Both emulated copies carry device == InputEvent.DEVICE_ID_EMULATION; they are
## consumed on a button but never act, so one physical press = one action.
## All UI strings are constants here (no localization system exists yet at this tier).

const PREVIEW_TINT: Color = Color(1.0, 0.85, 0.2, 0.35)
const PREVIEW_OUTLINE: Color = Color(1.0, 0.85, 0.2, 0.95)
const PREVIEW_LINE: Color = Color(1.0, 1.0, 1.0, 0.95)
const DOT_COLOR: Color = Color(1.0, 0.85, 0.2)
const DOT_OUTLINE: Color = Color(0.15, 0.12, 0.1)
const SWING_TINT: Color = Color(0.95, 0.12, 0.08, 0.5)
const SWING_OUTLINE: Color = Color(0.95, 0.12, 0.08)
const HIT_TINT: Color = Color(0.95, 0.12, 0.08, 0.6)
const HIT_TEXT: Color = Color(0.9, 0.1, 0.05)
const MISS_TINT: Color = Color(0.2, 0.8, 0.3, 0.5)
const MISS_TEXT: Color = Color(0.1, 0.6, 0.2)
const TEXT_DARK: Color = Color(0.15, 0.12, 0.1)
const TEXT_LIGHT: Color = Color(0.95, 0.9, 0.78)
const TEXT_OUTLINE_LIGHT: Color = Color(1.0, 1.0, 1.0, 0.9)
const BUTTON_BACK: Color = Color(0.2, 0.17, 0.15, 0.9)
const BUTTON_READY_BACK: Color = Color(0.25, 0.5, 0.3, 0.95)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PANEL_BACK: Color = Color(0.1, 0.09, 0.08, 0.85)
const BAR_BACK: Color = Color(0.3, 0.27, 0.24, 0.9)
const BAR_FILL: Color = Color(0.95, 0.6, 0.1)
## Alpha multiplier of a locked / dimmed button.
const DIM_ALPHA: float = 0.4
const OUTLINE_WIDTH: float = 4.0
const CELL_OUTLINE_WIDTH: float = 3.0
const LINE_WIDTH: float = 4.0
## Perimeter dot radius and its label offset toward the board centre (shares of cell height).
const DOT_RADIUS_RATIO: float = 0.08
const DOT_LABEL_OFFSET_RATIO: float = 0.24
const DOT_LABEL_WIDTH: float = 60.0
const DOT_LABEL_FONT_SIZE: int = 22
const BIG_FONT_SIZE: int = 44
const FONT_SIZE: int = 26
const SMALL_FONT_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 30
## Hit/miss text size as a share of cell height.
const FEEDBACK_FONT_RATIO: float = 0.4

## Interrupt flash (NGẮT) and the boss-swing label box.
const INTERRUPT_COLOR: Color = Color(1.0, 0.5, 0.0)
const INTERRUPT_TINT: Color = Color(1.0, 0.5, 0.0, 0.55)
const INTERRUPT_X_WIDTH: float = 8.0
const INTERRUPT_X_INSET_RATIO: float = 0.1
const LABEL_BIG_RATIO: float = 0.34
const LABEL_SMALL_RATIO: float = 0.2
const LABEL_PAD: float = 6.0
const LABEL_LINE_SPACING: float = 1.15

## Burning cells (Đốt, Story 010): orange fire tint with dark diagonal hatching, a flame glyph
## (two stacked triangles) and a thin shrinking time bar along the cell's bottom. Hue and
## hatching keep it apart from the red swing overlay and the red HIT tint.
const BURN_TINT: Color = Color(1.0, 0.45, 0.0, 0.4)
const BURN_OUTLINE: Color = Color(1.0, 0.4, 0.0, 0.95)
const BURN_HATCH: Color = Color(0.25, 0.08, 0.0, 0.5)
const BURN_FLAME_OUTER: Color = Color(1.0, 0.78, 0.12, 0.95)
const BURN_FLAME_INNER: Color = Color(0.95, 0.25, 0.0, 0.95)
const BURN_BAR_BACK: Color = Color(0.25, 0.08, 0.0, 0.75)
const BURN_BAR_FILL: Color = Color(1.0, 0.6, 0.05)
## Hatch spacing (share of cell height) and line width.
const BURN_HATCH_STEP_RATIO: float = 0.22
const BURN_HATCH_WIDTH: float = 2.0
## Flame glyph size (shares of cell width / height); inner flame as a share of the outer.
const BURN_FLAME_WIDTH_RATIO: float = 0.3
const BURN_FLAME_HEIGHT_RATIO: float = 0.42
const BURN_FLAME_INNER_RATIO: float = 0.55
## Time bar: height and side inset (shares of cell height), bottom gap.
const BURN_BAR_HEIGHT_RATIO: float = 0.06
const BURN_BAR_INSET_RATIO: float = 0.08
## Pin (Ghim): a thick grey ring with 4 short spokes around the pinned unit, "GHIM x.x s" above.
const PIN_RING_COLOR: Color = Color(0.58, 0.58, 0.62, 0.95)
const PIN_RING_DARK: Color = Color(0.2, 0.2, 0.22, 0.95)
const PIN_TEXT_COLOR: Color = Color(0.25, 0.25, 0.28)
const PIN_RING_RADIUS_RATIO: float = 0.42
const PIN_RING_WIDTH: float = 7.0
const PIN_RING_POINTS: int = 48
const PIN_SPOKE_LENGTH_RATIO: float = 0.12
const PIN_SPOKE_WIDTH: float = 6.0
const PIN_FONT_RATIO: float = 0.22
const PIN_TEXT_GAP_RATIO: float = 0.04
## Feint flash (ĐÒN GIẢ): dashed grey outline per cell (never red) and a fading label.
const FEINT_COLOR: Color = Color(0.5, 0.5, 0.52)
const FEINT_TINT: Color = Color(0.6, 0.6, 0.6, 0.2)
const FEINT_DASH_LENGTH: float = 10.0
const FEINT_DASH_WIDTH: float = 4.0
const FEINT_INSET: float = 4.0
## Boss learning debug line (kept in release for now): small text under the boss HP bar,
## right-aligned to the bar's right edge, baseline offset below the HUD band's bottom.
const LEARNING_FONT_SIZE: int = 14
const LEARNING_COLOR: Color = Color(0.3, 0.26, 0.22)
const LEARNING_BASELINE_OFFSET: float = 4.0
## Story 020 boss status readouts under the boss HP bar (ScreenLayout.hud_boss_status_rect):
## "Cháy ×N" in orange, "Ghim" in blue beside it; font and the gap between the two.
const STATUS_FONT_SIZE: int = 16
const STATUS_GAP: float = 16.0
const BURN_STACKS_COLOR: Color = Color(0.95, 0.5, 0.1)
const PINNED_COLOR: Color = Color(0.25, 0.5, 0.95)
## Story 020: the damage number of a hit that got the Ghim multiplier (same blue as "Ghim").
const PIN_BONUS_TEXT: Color = Color(0.2, 0.4, 0.95)
## Gap between a menu card name and its level suffix.
const LEVEL_SEPARATOR: String = " "

## Focus (Story 012). While the match is paused: a cool blue-grey tint over the board area (both
## halves), a soft vignette of a few bands plus a thin frame around the viewport, and the
## "TẬP TRUNG" countdown bar above the CONFIRM button. On cooldown the same place shows a greyed
## bar that fills up as the cooldown recovers; when READY and nothing is selected, a faint dot.
const FOCUS_BOARD_TINT: Color = Color(0.35, 0.45, 0.65, 0.35)
const FOCUS_FRAME_COLOR: Color = Color(0.3, 0.45, 0.75, 0.9)
const FOCUS_FRAME_WIDTH: float = 6.0
## Vignette: band count, band width (px), alpha of the outermost band (fades toward the centre).
const FOCUS_VIGNETTE_BANDS: int = 3
const FOCUS_VIGNETTE_BAND_WIDTH: float = 10.0
const FOCUS_VIGNETTE_ALPHA: float = 0.3
const FOCUS_BAR_BACK: Color = Color(0.12, 0.16, 0.25, 0.9)
const FOCUS_BAR_FILL: Color = Color(0.35, 0.6, 0.95)
const FOCUS_BAR_LOW_FILL: Color = Color(0.95, 0.6, 0.1)
const FOCUS_BAR_OUTLINE: Color = Color(0.85, 0.9, 1.0)
const FOCUS_COOLDOWN_BACK: Color = Color(0.25, 0.25, 0.27, 0.8)
const FOCUS_COOLDOWN_FILL: Color = Color(0.5, 0.5, 0.53, 0.9)
const FOCUS_COOLDOWN_TEXT: Color = Color(0.9, 0.9, 0.92)
const FOCUS_READY_DOT: Color = Color(0.35, 0.6, 0.95, 0.7)
const FOCUS_READY_DOT_RADIUS: float = 6.0
const FOCUS_FONT_SIZE: int = 18
## The countdown fill turns orange when this share of the Focus time (or less) is left
## (a quarter: the last 1 s of a 4 s Focus).
const FOCUS_LOW_RATIO: float = 0.25
## "DỪNG" tag on the hand row (in the FULL-label reserve zone, top-aligned so it never touches
## the vertically centred FULL text): size, pause glyph bar size and gap, inner padding.
const FOCUS_TAG_WIDTH: float = 78.0
const FOCUS_TAG_HEIGHT: float = 26.0
const FOCUS_TAG_GLYPH_WIDTH: float = 4.0
const FOCUS_TAG_GLYPH_HEIGHT: float = 12.0
const FOCUS_TAG_GLYPH_GAP: float = 3.0
const FOCUS_TAG_PAD: float = 6.0

const TEXT_FOCUS: String = "ui.hud.focus"
const TEXT_FOCUS_COOLDOWN: String = "ui.hud.focus_cooldown"
const TEXT_FOCUS_PAUSED_TAG: String = "ui.hud.focus_paused_tag"

const TEXT_PIN: String = "ui.hud.pin"
const TEXT_FEINT: String = "ui.hud.feint"
const TEXT_FEINT_NOTE: String = "ui.hud.feint_note"
const TEXT_LEARNING: String = "ui.hud.learning"
## Skill id whose config carries the burn duration (bar ratio).
const BURN_SKILL_ID: String = "hoa_tran"

## Boss combo (Story 013): the QUEUED second swing while the first runs, on the player's half.
## Lighter red than the running swing with thin red hatching, so the two read as two layers;
## a cell covered by both keeps the running swing's solid look (it is skipped here). One small
## "2: +g s" box (g = the gap after swing 1's impact) sits at the bottom-right of the queued
## cells' bounding box, away from swing 1's countdown box which is centred on its own cells.
const COMBO_TINT: Color = Color(0.95, 0.12, 0.08, 0.18)
const COMBO_OUTLINE: Color = Color(0.95, 0.35, 0.3, 0.9)
const COMBO_HATCH: Color = Color(0.95, 0.12, 0.08, 0.55)
const COMBO_HATCH_STEP_RATIO: float = 0.18
const COMBO_HATCH_WIDTH: float = 2.0
const TEXT_COMBO_QUEUED: String = "ui.hud.combo_queued"

## Row burner warning (Story 014): while RowBurnerTrait announces a row, its cells get a faint
## amber tint, an amber outline that blinks between full and dim alpha (phase from a REAL-time
## accumulator fed in _process, so it blinks even while the simulation is frozen or slowed), a
## thin shrinking bar along the cell's TOP (the fire bar sits at the bottom) and a "SẮP CHÁY"
## tag at the top-right of the cells' bounding box. Amber (yellow-orange) and the blink keep it
## apart from the solid red boss swing and the hatched orange-red fire look that follows it.
const WARN_TINT: Color = Color(1.0, 0.7, 0.15, 0.18)
const WARN_OUTLINE: Color = Color(1.0, 0.68, 0.1, 0.95)
const WARN_BAR_BACK: Color = Color(0.35, 0.22, 0.02, 0.7)
const WARN_BAR_FILL: Color = Color(1.0, 0.75, 0.2)
const WARN_OUTLINE_WIDTH: float = 5.0
const WARN_BLINK_HZ: float = 4.0
const WARN_BLINK_DIM_ALPHA: float = 0.3
## Outline inset (px) and the top bar's height / side inset (shares of cell height).
const WARN_OUTLINE_INSET: float = 4.0
const WARN_BAR_HEIGHT_RATIO: float = 0.06
const WARN_BAR_INSET_RATIO: float = 0.08
const TEXT_ROW_WARNING: String = "ui.hud.row_warning"
## Trait param that holds the warning length (read from the trait, never a local number).
const WARN_SEC_PARAM: String = "warn_sec"

const TEXT_BOSS_SWING: String = "ui.hud.boss_swing"
const TEXT_INTERRUPT: String = "ui.hud.interrupt"
const TEXT_INTERRUPT_BOSS: String = "ui.hud.interrupt_boss"
const TEXT_INTERRUPT_PLAYER: String = "ui.hud.interrupt_player"
const TEXT_CONFIRM: String = "ui.hud.cast"
const TEXT_CELLS: String = "ui.hud.cells"
const TEXT_DAMAGE: String = "ui.hud.damage"
const TEXT_NEED_CELLS: String = "ui.hud.need_cells"
const TEXT_NOT_IMPLEMENTED: String = "ui.hud.not_implemented"
const TEXT_COOLDOWN: String = "ui.hud.cooldown"
const TEXT_READY: String = "ui.hud.ready"
const TEXT_SWING: String = "ui.hud.swing"
const TEXT_HIT: String = "ui.hud.hit"
const TEXT_MISS: String = "ui.hud.miss"
const TEXT_DAMAGE_NUMBER: String = "ui.hud.damage_number"
## Story 020: "Cháy ×%d" (burn stacks on the boss), "Ghim" (boss pinned), "+%d" after a menu card name.
const TEXT_BURN_STACKS: String = "ui.hud.burn_stacks"
## Horizontal padding inside a menu slot for the card name (Story 020: names carry "+N").
const MENU_NAME_PAD: float = 8.0
## Smallest font size the menu name shrinks to before clipping.
const MENU_NAME_MIN_FONT_SIZE: int = 18
const TEXT_PINNED: String = "ui.hud.pinned"
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"

## Story 021 signature skill HUD. Physical key of the signature button (mirrors the DPadView dev keys;
## not in combat.json: Part 1 owns that file), button fonts, the ready pulse (cycles per second and
## brightness swing), border colour per signature id, border/timer sizes, banner duration / fade /
## font and the colours of the charge and timer bars.
## Fallback when the combat view has no config yet (the real key comes from combat.json signature_key).
const SIGNATURE_KEY_FALLBACK: Key = KEY_Q
const SIGNATURE_FONT_SIZE: int = 20
const SIGNATURE_SMALL_FONT_SIZE: int = 16
const SIGNATURE_MIN_FONT_SIZE: int = 12
const SIGNATURE_PULSE_HZ: float = 1.6
const SIGNATURE_PULSE_ALPHA: float = 0.35
const SIGNATURE_TEXT_PAD: float = 6.0
const SIGNATURE_COLORS: Dictionary = {
	"tram": Color(0.95, 0.15, 0.1),
	"thien_hoa": Color(1.0, 0.55, 0.1),
	"anh_bo": Color(0.2, 0.45, 1.0),
}
const SIGNATURE_DEFAULT_COLOR: Color = Color(0.95, 0.85, 0.3)
const SIGNATURE_BORDER_WIDTH: float = 6.0
const SIGNATURE_TIMER_BACK: Color = Color(0.1, 0.1, 0.12, 0.7)
const SIGNATURE_CHARGE_BACK: Color = Color(0.08, 0.08, 0.1, 0.85)
const SIGNATURE_CHARGE_FILL: Color = Color(0.95, 0.85, 0.3)
## Seconds the signature name stays in the middle of the board after activation, the last part
## of it fading out, the banner font and its dark backing alpha.
const SIGNATURE_BANNER_SEC: float = 0.8
const SIGNATURE_BANNER_FADE_SEC: float = 0.25
const SIGNATURE_BANNER_FONT_SIZE: int = 64
const SIGNATURE_BANNER_BACK_ALPHA: float = 0.45
const TEXT_SIGNATURE_READY: String = "ui.hud.signature_ready"
const TEXT_SIGNATURE_ACTIVE: String = "ui.hud.signature_active"
const TEXT_SIGNATURE_CHARGE: String = "ui.hud.signature_charge"

@export var combat_view_path: NodePath = NodePath("../CombatView")

var _combat: CombatView
## Real seconds since this view started: phase source of the row-warning blink.
var _blink_time: float = 0.0
## Story 021: the same node as _combat, untyped so the signature calls are dynamic (parse-safe).
var _sig: Object
## Story 021: the banner's signature id, translated name and seconds left.
var _banner_id: String = ""
var _banner_text: String = ""
var _banner_left: float = 0.0


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView
	_sig = _combat
	if _combat != null and _combat.has_signal("signature_activated"):
		_combat.connect("signature_activated", _on_signature_activated)


func _process(delta: float) -> void:
	_blink_time += delta
	_banner_left = maxf(_banner_left - delta, 0.0)
	queue_redraw()


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if _combat == null or _combat.get_cut_flow() == null:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == _signature_key():
			_try_activate_signature()
			get_viewport().set_input_as_handled()
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
	if _press_at(pos, event.device == InputEvent.DEVICE_ID_EMULATION):
		get_viewport().set_input_as_handled()


# Handles a press at [param pos]; returns true if it landed on this UI (consumed). Emulated
# duplicates are consumed but do nothing.
func _press_at(pos: Vector2, emulated: bool) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var flow: CutFlow = _combat.get_cut_flow()
	if flow.is_menu_open():
		if not ScreenLayout.skill_menu_panel_rect(vp).has_point(pos):
			return false
		if not emulated:
			var order: Array[String] = flow.get_hand()
			var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
			for i: int in rects.size():
				if rects[i].has_point(pos):
					flow.choose(order[i])
					break
		return true
	if _has_signature() and ScreenLayout.signature_button_rect(vp).has_point(pos):
		if not emulated:
			_try_activate_signature()
		return true
	if _combat.is_confirm_visible() and ScreenLayout.confirm_button_rect(vp).has_point(pos):
		if not emulated and not _combat.get_cut_actor().is_swinging():
			_combat.confirm_selection()
		return true
	return false


# --- Story 021: signature skill ------------------------------------------------


# True when CombatView exposes the signature interface and the character has a signature.
func _has_signature() -> bool:
	return _sig != null and _sig.has_method("get_signature") and _sig.get_signature() != null


func _signature_id() -> String:
	var sig: Variant = _sig.get_signature()
	return str(sig.get_id()) if sig != null else ""


func _on_signature_activated(id: String) -> void:
	_banner_id = id
	_banner_text = _sig.get_signature_name()
	_banner_left = SIGNATURE_BANNER_SEC


func _try_activate_signature() -> void:
	if _has_signature() and _sig.can_activate_signature():
		_sig.activate_signature()


# Coloured border + thin timer bar on the player's half while a signature runs.
func _draw_signature_effect(vp: Vector2) -> void:
	if not _has_signature() or not _sig.is_signature_active():
		return
	var color: Color = SIGNATURE_COLORS.get(_signature_id(), SIGNATURE_DEFAULT_COLOR)
	var grid: BoardGrid = _combat.get_grid()
	var half: Rect2 = ScreenLayout.player_half_rect(grid, vp)
	draw_rect(half.grow(-SIGNATURE_BORDER_WIDTH * 0.5), color, false, SIGNATURE_BORDER_WIDTH)
	var duration: float = _sig.get_signature_duration()
	var ratio: float = 0.0 if duration <= 0.0 else clampf(_sig.get_signature_time_left() / duration, 0.0, 1.0)
	var bar: Rect2 = ScreenLayout.signature_timer_rect(grid, vp)
	draw_rect(bar, SIGNATURE_TIMER_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)


# The signature name, large in the middle of the board, for SIGNATURE_BANNER_SEC with a short fade.
func _draw_signature_banner(vp: Vector2) -> void:
	if _banner_left <= 0.0 or _banner_text.is_empty():
		return
	var alpha: float = clampf(_banner_left / SIGNATURE_BANNER_FADE_SEC, 0.0, 1.0)
	var color: Color = SIGNATURE_COLORS.get(_banner_id, SIGNATURE_DEFAULT_COLOR)
	var band: Rect2 = ScreenLayout.signature_banner_rect(_combat.get_grid(), vp)
	draw_rect(band, Color(0.0, 0.0, 0.0, SIGNATURE_BANNER_BACK_ALPHA * alpha))
	var size: int = _fit_signature_font(_banner_text, band.size.x, SIGNATURE_BANNER_FONT_SIZE)
	var shadow := Color(0.0, 0.0, 0.0, alpha)
	_draw_centered(Rect2(band.position + Vector2.ONE * 2.0, band.size), _banner_text, size, shadow)
	_draw_centered(band, _banner_text, size, Color(color.lightened(0.35), alpha))


# The button: dimmed with a charge bar and "%" while charging, PRIMARY and pulsing when ready,
# a countdown bar while the skill runs; also dimmed whenever it cannot be pressed (menu / Focus / pause).
func _draw_signature_button(vp: Vector2) -> void:
	if not _has_signature():
		return
	var rect: Rect2 = ScreenLayout.signature_button_rect(vp)
	var active: bool = _sig.is_signature_active()
	var is_ready: bool = _sig.is_signature_ready()
	var usable: bool = _sig.can_activate_signature()
	var name_text: String = _sig.get_signature_name()
	var style: int = UiButtons.Style.PRIMARY if (is_ready or active) else UiButtons.Style.SECONDARY
	if active:
		style = UiButtons.Style.DANGER
	var pressed: bool = usable and UiButtons.is_pressed_at(self, rect)
	UiButtons.draw_button(self, rect, "", style, pressed, is_ready or active)
	if is_ready and usable and not active:
		var pulse: float = 0.5 + 0.5 * sin(_blink_time * TAU * SIGNATURE_PULSE_HZ)
		draw_rect(rect, Color(1.0, 1.0, 1.0, SIGNATURE_PULSE_ALPHA * pulse))
	if is_ready and not usable and not active:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 1.0 - UiButtons.DIM_ALPHA))
	var charge_rect: Rect2 = ScreenLayout.signature_charge_rect(vp)
	var ratio: float = _sig.get_signature_charge()
	var fill_color: Color = SIGNATURE_CHARGE_FILL
	if active:
		var duration: float = _sig.get_signature_duration()
		ratio = 0.0 if duration <= 0.0 else clampf(_sig.get_signature_time_left() / duration, 0.0, 1.0)
		fill_color = SIGNATURE_COLORS.get(_signature_id(), SIGNATURE_DEFAULT_COLOR)
	draw_rect(charge_rect, SIGNATURE_CHARGE_BACK)
	draw_rect(Rect2(charge_rect.position, Vector2(charge_rect.size.x * ratio, charge_rect.size.y)), fill_color)
	var text_alpha: float = 1.0 if (usable or active) else UiButtons.DIM_ALPHA + 0.2
	var inner := Rect2(rect.position + Vector2(SIGNATURE_TEXT_PAD, 0.0), Vector2(maxf(rect.size.x - SIGNATURE_TEXT_PAD * 2.0, 0.0), rect.size.y - charge_rect.size.y))
	var name_size: int = _fit_signature_font(name_text, inner.size.x, SIGNATURE_FONT_SIZE)
	var top_line := Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5))
	_draw_centered(top_line, name_text, name_size, Color(TEXT_LIGHT, text_alpha))
	var status: String = tr(TEXT_SIGNATURE_CHARGE) % roundi(clampf(_sig.get_signature_charge(), 0.0, 1.0) * 100.0)
	if active:
		status = tr(TEXT_SIGNATURE_ACTIVE)
	elif is_ready:
		status = tr(TEXT_SIGNATURE_READY)
	var bottom_line := Rect2(inner.position + Vector2(0.0, inner.size.y * 0.5), Vector2(inner.size.x, inner.size.y * 0.5))
	_draw_centered(bottom_line, status, _fit_signature_font(status, inner.size.x, SIGNATURE_SMALL_FONT_SIZE), Color(TEXT_LIGHT, text_alpha))


# Largest font size <= [param size] (never below SIGNATURE_MIN_FONT_SIZE) at which [param text] fits [param width].
func _fit_signature_font(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > SIGNATURE_MIN_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if _combat == null or _combat.get_cut_flow() == null or _combat.get_state() == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	# Focus overlay first: the preview, markers and buttons stay fully readable above it.
	_draw_focus_overlay(vp)
	_draw_preview(vp)
	_draw_swing(vp)
	_draw_boss_queued_swing(vp)
	_draw_boss_swing(vp)
	_draw_feedback(vp)
	_draw_boss_feedback(vp)
	_draw_row_warning(vp)
	_draw_burning(vp)
	_draw_interrupt(vp)
	_draw_feint(vp)
	_draw_pins(vp)
	_draw_confirm(vp)
	_draw_focus_bar(vp)
	_draw_focus_tag(vp)
	_draw_signature_effect(vp)
	_draw_signature_button(vp)
	_draw_menu(vp)
	_draw_signature_banner(vp)
	if _combat.debug_overlay:
		_draw_learning_debug(vp)
	_draw_boss_status(vp)


# --- Story 012: Focus (pause while connecting points) ---------------------------


# Board tint, vignette bands and frame while Focus pauses the match. Nothing otherwise.
func _draw_focus_overlay(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or not focus.is_active():
		return
	draw_rect(ScreenLayout.board_area_rect(vp), FOCUS_BOARD_TINT)
	var frame := Rect2(Vector2.ZERO, vp)
	for i: int in FOCUS_VIGNETTE_BANDS:
		var alpha: float = FOCUS_VIGNETTE_ALPHA * float(FOCUS_VIGNETTE_BANDS - i) / float(FOCUS_VIGNETTE_BANDS)
		var inset: float = FOCUS_FRAME_WIDTH + FOCUS_VIGNETTE_BAND_WIDTH * (i + 0.5)
		draw_rect(frame.grow(-inset), Color(FOCUS_FRAME_COLOR, alpha), false, FOCUS_VIGNETTE_BAND_WIDTH)
	draw_rect(frame.grow(-FOCUS_FRAME_WIDTH * 0.5), FOCUS_FRAME_COLOR, false, FOCUS_FRAME_WIDTH)


# Above the CONFIRM button: ACTIVE = "TẬP TRUNG x.x s" countdown (orange in the last quarter);
# COOLDOWN = greyed bar filling up with "Tập trung còn N s"; READY with nothing selected = a
# faint dot at the bar's left. Hidden while the skill menu covers the strip.
func _draw_focus_bar(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or _combat.get_cut_flow().is_menu_open():
		return
	var bar: Rect2 = ScreenLayout.focus_bar_rect(vp)
	if focus.is_active():
		var max_sec: float = focus.get_max_sec()
		var ratio: float = 0.0 if max_sec <= 0.0 else clampf(focus.get_time_left() / max_sec, 0.0, 1.0)
		var fill: Color = FOCUS_BAR_LOW_FILL if ratio <= FOCUS_LOW_RATIO else FOCUS_BAR_FILL
		draw_rect(bar, FOCUS_BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
		draw_rect(bar, FOCUS_BAR_OUTLINE, false, 2.0)
		_draw_centered(bar, tr(TEXT_FOCUS) % focus.get_time_left(), FOCUS_FONT_SIZE, TEXT_LIGHT)
	elif focus.is_on_cooldown():
		var total: float = focus.get_cooldown_sec()
		var recovered: float = 1.0 if total <= 0.0 else clampf(1.0 - focus.get_cooldown_left() / total, 0.0, 1.0)
		draw_rect(bar, FOCUS_COOLDOWN_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * recovered, bar.size.y)), FOCUS_COOLDOWN_FILL)
		_draw_centered(bar, tr(TEXT_FOCUS_COOLDOWN) % ceili(focus.get_cooldown_left()), FOCUS_FONT_SIZE, FOCUS_COOLDOWN_TEXT)
	elif not _combat.is_confirm_visible():
		var state: CombatState = _combat.get_state()
		if state.is_player_dead() or state.is_enemy_dead():
			return
		draw_circle(Vector2(bar.position.x + FOCUS_READY_DOT_RADIUS, bar.get_center().y), FOCUS_READY_DOT_RADIUS, FOCUS_READY_DOT)


# "DỪNG" tag with a pause glyph on the hand row while Focus is ACTIVE: top-right of the zone
# reserved for the FULL label (left of the first slot), so the eye gets it near the thumb too.
func _draw_focus_tag(vp: Vector2) -> void:
	var focus: FocusController = _combat.get_focus()
	if focus == null or not focus.is_active():
		return
	var side: Rect2 = ScreenLayout.slot_side_left_rect(vp, HoldSlots.MAX_SLOTS)
	var tag := Rect2(Vector2(side.end.x - FOCUS_TAG_WIDTH, side.position.y), Vector2(FOCUS_TAG_WIDTH, FOCUS_TAG_HEIGHT))
	draw_rect(tag, FOCUS_BAR_FILL)
	draw_rect(tag, FOCUS_BAR_OUTLINE, false, 2.0)
	var glyph_top: float = tag.get_center().y - FOCUS_TAG_GLYPH_HEIGHT * 0.5
	var glyph_x: float = tag.position.x + FOCUS_TAG_PAD
	draw_rect(Rect2(glyph_x, glyph_top, FOCUS_TAG_GLYPH_WIDTH, FOCUS_TAG_GLYPH_HEIGHT), TEXT_LIGHT)
	draw_rect(Rect2(glyph_x + FOCUS_TAG_GLYPH_WIDTH + FOCUS_TAG_GLYPH_GAP, glyph_top, FOCUS_TAG_GLYPH_WIDTH, FOCUS_TAG_GLYPH_HEIGHT), TEXT_LIGHT)
	var text_left: float = glyph_x + FOCUS_TAG_GLYPH_WIDTH * 2.0 + FOCUS_TAG_GLYPH_GAP + FOCUS_TAG_PAD
	var text_rect := Rect2(text_left, tag.position.y, maxf(tag.end.x - text_left, 0.0), tag.size.y)
	_draw_centered(text_rect, tr(TEXT_FOCUS_PAUSED_TAG), FOCUS_FONT_SIZE, TEXT_LIGHT)


func _draw_cells(vp: Vector2, cells: Array[Vector2i], tint: Color, outline: Color) -> void:
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, tint)
		draw_rect(rect.grow(-2.0), outline, false, CELL_OUTLINE_WIDTH)


# Centred single-line text; [param size] is the font size.
func _draw_centered(rect: Rect2, text: String, size: int, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y + size * 0.35),
		text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color
	)


func _draw_preview(vp: Vector2) -> void:
	if _combat.get_cut_flow().is_menu_open():
		return
	var labels: Array[String] = _combat.get_cut_selection_labels()
	if labels.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var cells: Array[Vector2i] = CutResolver.resolve_on_board(grid, true, labels)
	_draw_cells(vp, cells, PREVIEW_TINT, PREVIEW_OUTLINE)
	# Perimeter dots on the boss square's edge, lines in selection order.
	var cell_size: Vector2 = ScreenLayout.cell_size(grid, vp)
	var origin: Vector2 = ScreenLayout.board_rect(grid, vp).position + Vector2(cell_size.x * grid.side_cols, 0.0)
	var square_center: Vector2 = origin + Vector2(grid.side_cols, grid.side_rows) * cell_size * 0.5
	var line_points: Array[Vector2] = []
	var dots: Array[Vector2] = []
	var dot_labels: Array[String] = []
	for label: String in labels:
		var p: Vector2 = CutResolver.label_point(label, grid.side_cols, grid.side_rows)
		if p == CutResolver.INVALID_POINT:
			continue
		dots.append(origin + p * cell_size)
		dot_labels.append(label)
		line_points.append(origin + p * cell_size)
	if labels.size() == 1 and not line_points.is_empty():
		var far: Vector2 = CutResolver.label_point(CutResolver.opposite_label(labels[0], grid.side_cols, grid.side_rows), grid.side_cols, grid.side_rows)
		line_points.append(origin + far * cell_size)
	for i: int in line_points.size() - 1:
		draw_line(line_points[i], line_points[i + 1], PREVIEW_LINE, LINE_WIDTH)
	if labels.size() >= 3 and line_points.size() >= 3:
		draw_line(line_points[line_points.size() - 1], line_points[0], PREVIEW_LINE, LINE_WIDTH)
	var radius: float = cell_size.y * DOT_RADIUS_RATIO
	for i: int in dots.size():
		draw_circle(dots[i], radius, DOT_COLOR)
		draw_arc(dots[i], radius, 0.0, TAU, 20, DOT_OUTLINE, 2.0)
		var inward: Vector2 = (square_center - dots[i]).normalized() * cell_size.y * DOT_LABEL_OFFSET_RATIO
		var at: Vector2 = dots[i] + inward
		draw_string(
			ThemeDB.fallback_font, at + Vector2(-DOT_LABEL_WIDTH * 0.5, DOT_LABEL_FONT_SIZE * 0.35),
			dot_labels[i], HORIZONTAL_ALIGNMENT_CENTER, DOT_LABEL_WIDTH, DOT_LABEL_FONT_SIZE, TEXT_DARK
		)
	# Cell count and expected damage (slash numbers) in the left half of the strip.
	var info: Rect2 = ScreenLayout.cut_preview_info_rect(vp)
	var top := Rect2(info.position, Vector2(info.size.x, info.size.y * 0.5))
	var bottom := Rect2(info.position + Vector2(0.0, info.size.y * 0.5), Vector2(info.size.x, info.size.y * 0.35))
	_draw_centered(top, tr(TEXT_CELLS) % cells.size(), BIG_FONT_SIZE, TEXT_DARK)
	_draw_centered(bottom, tr(TEXT_DAMAGE) % roundi(_combat.get_cut_config().slash_damage(cells.size())), FONT_SIZE, TEXT_DARK)


func _draw_swing(vp: Vector2) -> void:
	var actor: CutActor = _combat.get_cut_actor()
	if not actor.is_swinging():
		return
	_draw_cells(vp, actor.get_cells(), SWING_TINT, SWING_OUTLINE)
	var info: Rect2 = ScreenLayout.cut_swing_info_rect(vp)
	var text: String = tr(TEXT_SWING) % [_skill_name(actor.get_skill_id()), actor.get_time_left()]
	_draw_centered(info, text, BIG_FONT_SIZE, SWING_OUTLINE)


# Boss swing on the PLAYER's half: red cells, countdown + labels/skill centred on their bounding box.
func _draw_boss_swing(vp: Vector2) -> void:
	var boss: BossController = _combat.get_boss()
	var actor: CutActor = boss.get_actor()
	if not actor.is_swinging():
		return
	var cells: Array[Vector2i] = actor.get_cells()
	_draw_cells(vp, cells, SWING_TINT, SWING_OUTLINE)
	var last: Dictionary = boss.get_last_cut()
	var labels: Array = last.get("labels", [])
	var joined: String = "+".join(PackedStringArray(labels))
	var line2: String = tr(TEXT_BOSS_SWING) % [joined, _skill_name(actor.get_skill_id())]
	_draw_cells_label(vp, cells, ("%.1f s" % actor.get_time_left()), line2, SWING_OUTLINE)


# Boss's queued combo swing (Story 013), drawn BEFORE _draw_boss_swing so the running swing's
# solid cells and countdown box stay on top: hatched lighter red on the queued cells the running
# swing does not cover, plus a one-line "2: +g s" box (g = queued windup = the combo gap) at the
# bottom-right of the queued cells' bounding box. No double-draw: when swing 1 resolves,
# CutActor.tick clears the queue before starting swing 2, so has_queued() is false in the same
# frame the running path (above) takes over.
func _draw_boss_queued_swing(vp: Vector2) -> void:
	var actor: CutActor = _combat.get_boss().get_actor()
	if not actor.is_swinging():
		return
	var queued: Dictionary = _combat.get_boss_queued_swing()
	if queued.is_empty():
		return
	var running: Array[Vector2i] = actor.get_cells()
	var cells: Array[Vector2i] = queued["cells"]
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		if running.has(cell):
			continue
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, COMBO_TINT)
		_draw_hatching(rect, rect.size.y * COMBO_HATCH_STEP_RATIO, COMBO_HATCH, COMBO_HATCH_WIDTH)
		draw_rect(rect.grow(-2.0), COMBO_OUTLINE, false, CELL_OUTLINE_WIDTH)
	_draw_corner_label(vp, cells, tr(TEXT_COMBO_QUEUED) % float(queued["duration"]), COMBO_OUTLINE)


# One small line on a white backing, anchored to the bottom-right corner (or, with
# [param top_right], the top-right corner) of the bounding box of [param cells] and clamped
# inside the board.
func _draw_corner_label(vp: Vector2, cells: Array[Vector2i], text: String, color: Color, top_right: bool = false) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var font: Font = ThemeDB.fallback_font
	var small: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_SMALL_RATIO)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + LABEL_PAD * 2.0
	var height: float = small * LABEL_LINE_SPACING + LABEL_PAD * 2.0
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var pos: Vector2 = box.end - Vector2(width, height)
	if top_right:
		pos.y = box.position.y
	pos.x = clampf(pos.x, board.position.x, maxf(board.end.x - width, board.position.x))
	pos.y = clampf(pos.y, board.position.y, maxf(board.end.y - height, board.position.y))
	var back := Rect2(pos, Vector2(width, height))
	draw_rect(back, TEXT_OUTLINE_LIGHT)
	draw_rect(back, color, false, CELL_OUTLINE_WIDTH)
	draw_string(font, pos + Vector2(0.0, LABEL_PAD + small * 0.85), text, HORIZONTAL_ALIGNMENT_CENTER, width, small, color)


# Boss HIT / MISS on the player's half (same look as the player's feedback).
func _draw_boss_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_boss_feedback())


# NGẮT flash over the victim's cancelled swing cells: orange tint, a big X per cell, text fading out.
func _draw_interrupt(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_interrupt_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cells: Array[Vector2i] = flash["cells"]
	var grid: BoardGrid = _combat.get_grid()
	_draw_cells(vp, cells, Color(INTERRUPT_TINT, INTERRUPT_TINT.a * fade), Color(INTERRUPT_COLOR, fade))
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell).grow(-rect_inset(vp))
		draw_line(rect.position, rect.end, Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(INTERRUPT_COLOR, fade), INTERRUPT_X_WIDTH)
	var boss_victim: bool = int(flash["side"]) == CombatState.Side.ENEMY
	_draw_cells_label(vp, cells, tr(TEXT_INTERRUPT), tr(TEXT_INTERRUPT_BOSS) if boss_victim else tr(TEXT_INTERRUPT_PLAYER), INTERRUPT_COLOR, fade)


func rect_inset(vp: Vector2) -> float:
	return ScreenLayout.cell_size(_combat.get_grid(), vp).y * INTERRUPT_X_INSET_RATIO


# Two lines (big, small) on a white backing, centred on the bounding box of [param cells] and
# clamped inside the board, so it never reaches the strip under the arena.
func _draw_cells_label(vp: Vector2, cells: Array[Vector2i], line1: String, line2: String, color: Color, alpha: float = 1.0) -> void:
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var box: Rect2 = ScreenLayout.cell_rect(grid, vp, cells[0])
	for cell: Vector2i in cells:
		box = box.merge(ScreenLayout.cell_rect(grid, vp, cell))
	var font: Font = ThemeDB.fallback_font
	var big: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_BIG_RATIO)
	var small: int = int(ScreenLayout.cell_size(grid, vp).y * LABEL_SMALL_RATIO)
	var width: float = maxf(font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x, font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x) + LABEL_PAD * 2.0
	var height: float = (big + small) * LABEL_LINE_SPACING + LABEL_PAD * 2.0
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var pos: Vector2 = box.get_center() - Vector2(width, height) * 0.5
	pos.x = clampf(pos.x, board.position.x, maxf(board.end.x - width, board.position.x))
	pos.y = clampf(pos.y, board.position.y, maxf(board.end.y - height, board.position.y))
	var back := Rect2(pos, Vector2(width, height))
	draw_rect(back, Color(TEXT_OUTLINE_LIGHT, TEXT_OUTLINE_LIGHT.a * alpha))
	draw_rect(back, Color(color, alpha), false, CELL_OUTLINE_WIDTH)
	draw_string(font, pos + Vector2(0.0, LABEL_PAD + big * 0.85), line1, HORIZONTAL_ALIGNMENT_CENTER, width, big, Color(color, alpha))
	draw_string(font, pos + Vector2(0.0, LABEL_PAD + big * LABEL_LINE_SPACING + small * 0.85), line2, HORIZONTAL_ALIGNMENT_CENTER, width, small, Color(TEXT_DARK, alpha))


func _draw_feedback(vp: Vector2) -> void:
	_draw_feedback_for(vp, _combat.get_cut_feedback())


func _draw_feedback_for(vp: Vector2, fb: Dictionary) -> void:
	if fb.is_empty():
		return
	var hit: bool = bool(fb["hit"])
	var cells: Array[Vector2i] = fb["cells"]
	_draw_cells(vp, cells, HIT_TINT if hit else MISS_TINT, HIT_TEXT if hit else MISS_TEXT)
	var grid: BoardGrid = _combat.get_grid()
	var cell_rect: Rect2 = ScreenLayout.cell_rect(grid, vp, fb["cell"])
	var size: int = int(cell_rect.size.y * FEEDBACK_FONT_RATIO)
	var color: Color = HIT_TEXT if hit else MISS_TEXT
	# Burn / pin hits deal no direct damage: no "-0" line.
	var show_damage: bool = hit and float(fb["damage"]) > 0.0
	var back := Rect2(cell_rect.position, Vector2(cell_rect.size.x, size * 2.0 if show_damage else size * 1.3))
	draw_rect(back, TEXT_OUTLINE_LIGHT)
	var line1 := Rect2(back.position, Vector2(back.size.x, size * 1.2))
	_draw_centered(line1, tr(TEXT_HIT) if hit else tr(TEXT_MISS), size, color)
	if show_damage:
		var line2 := Rect2(back.position + Vector2(0.0, size * 0.9), Vector2(back.size.x, size * 1.2))
		# Story 020: a hit multiplied by Ghim shows its number in the pin blue.
		var damage_color: Color = PIN_BONUS_TEXT if bool(fb.get("pin_bonus", false)) else color
		_draw_centered(line2, tr(TEXT_DAMAGE_NUMBER) % roundi(float(fb["damage"])), size, damage_color)


# --- Story 014: row burner warning ---------------------------------------------


# The row RowBurnerTrait is announcing (nothing when the match has no row_burner or no warning
# runs): faint amber tint, blinking amber outline, shrinking top bar, "SẮP CHÁY" tag. Once the
# row ignites the trait clears its warning and _draw_burning takes over.
func _draw_row_warning(vp: Vector2) -> void:
	var host: TraitHost = _combat.get_trait_host()
	if host == null:
		return
	var burner: RowBurnerTrait = host.get_trait(RowBurnerTrait.ID) as RowBurnerTrait
	if burner == null:
		return
	var cells: Array[Vector2i] = burner.get_warning_cells()
	if cells.is_empty():
		return
	var warn_sec: float = burner.param_float(WARN_SEC_PARAM, RowBurnerTrait.DEFAULT_WARN_SEC)
	var ratio: float = 0.0 if warn_sec <= 0.0 else clampf(burner.get_warn_left() / warn_sec, 0.0, 1.0)
	var bright: bool = int(_blink_time * WARN_BLINK_HZ * 2.0) % 2 == 0
	var outline := Color(WARN_OUTLINE, WARN_OUTLINE.a * (1.0 if bright else WARN_BLINK_DIM_ALPHA))
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, WARN_TINT)
		draw_rect(rect.grow(-WARN_OUTLINE_INSET), outline, false, WARN_OUTLINE_WIDTH)
		var inset: float = rect.size.y * WARN_BAR_INSET_RATIO
		var bar_h: float = rect.size.y * WARN_BAR_HEIGHT_RATIO
		var bar := Rect2(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.size.x - inset * 2.0, bar_h))
		draw_rect(bar, WARN_BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), WARN_BAR_FILL)
	_draw_corner_label(vp, cells, tr(TEXT_ROW_WARNING), WARN_OUTLINE, true)


# --- Story 010: burning cells, pins, feint, learning debug ----------------------


# Every burning cell on either half: fire tint + dark hatching + flame glyph + time bar.
func _draw_burning(vp: Vector2) -> void:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return
	var cells: Array[Vector2i] = status.burning_cells()
	if cells.is_empty():
		return
	var grid: BoardGrid = _combat.get_grid()
	var duration: float = float(_combat.get_skill_config().get_skill(BURN_SKILL_ID).get("burn_duration_sec", 0.0))
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, BURN_TINT)
		_draw_hatching(rect, rect.size.y * BURN_HATCH_STEP_RATIO)
		draw_rect(rect.grow(-2.0), BURN_OUTLINE, false, CELL_OUTLINE_WIDTH)
		_draw_flame(rect.get_center(), rect.size)
		# Shrinking bar along the bottom: full at ignition, empty when it burns out.
		var ratio: float = 0.0 if duration <= 0.0 else clampf(status.get_burn_left(cell) / duration, 0.0, 1.0)
		var inset: float = rect.size.y * BURN_BAR_INSET_RATIO
		var bar_h: float = rect.size.y * BURN_BAR_HEIGHT_RATIO
		var bar := Rect2(Vector2(rect.position.x + inset, rect.end.y - inset - bar_h), Vector2(rect.size.x - inset * 2.0, bar_h))
		draw_rect(bar, BURN_BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), BURN_BAR_FILL)


# Diagonal hatch lines (x + y = t) clipped to [param rect], [param step] apart, in [param color]
# and [param width] (burn hatching by default; the combo layer passes its own).
func _draw_hatching(rect: Rect2, step: float, color: Color = BURN_HATCH, width: float = BURN_HATCH_WIDTH) -> void:
	if step <= 0.0:
		return
	var w: float = rect.size.x
	var h: float = rect.size.y
	var t: float = step
	while t < w + h:
		var from := Vector2(rect.position.x + minf(t, w), rect.position.y + maxf(t - w, 0.0))
		var to := Vector2(rect.position.x + maxf(t - h, 0.0), rect.position.y + minf(t, h))
		draw_line(from, to, color, width)
		t += step


# Flame glyph: an outer and an inner triangle, the inner one shifted toward the base.
func _draw_flame(center: Vector2, cell: Vector2) -> void:
	var w: float = cell.x * BURN_FLAME_WIDTH_RATIO
	var h: float = cell.y * BURN_FLAME_HEIGHT_RATIO
	var outer: PackedVector2Array = PackedVector2Array([
		center + Vector2(-w * 0.5, h * 0.5), center + Vector2(0.0, -h * 0.5), center + Vector2(w * 0.5, h * 0.5),
	])
	draw_colored_polygon(outer, BURN_FLAME_OUTER)
	var iw: float = w * BURN_FLAME_INNER_RATIO
	var ih: float = h * BURN_FLAME_INNER_RATIO
	var base: Vector2 = center + Vector2(0.0, h * 0.5)
	var inner: PackedVector2Array = PackedVector2Array([
		base + Vector2(-iw * 0.5, 0.0), base + Vector2(0.0, -ih), base + Vector2(iw * 0.5, 0.0),
	])
	draw_colored_polygon(inner, BURN_FLAME_INNER)


# Chain ring + "GHIM x.x s" over every pinned unit (player and boss).
func _draw_pins(vp: Vector2) -> void:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return
	var state: CombatState = _combat.get_state()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		if not status.is_pinned(side):
			continue
		_draw_pin_at(vp, state.cell_of(side), status.get_pin_left(side))


func _draw_pin_at(vp: Vector2, cell: Vector2i, left: float) -> void:
	var grid: BoardGrid = _combat.get_grid()
	var cell_size: Vector2 = ScreenLayout.cell_size(grid, vp)
	var c: Vector2 = ScreenLayout.cell_center(grid, vp, cell)
	var radius: float = cell_size.y * PIN_RING_RADIUS_RATIO
	draw_arc(c, radius, 0.0, TAU, PIN_RING_POINTS, PIN_RING_COLOR, PIN_RING_WIDTH)
	draw_arc(c, radius, 0.0, TAU, PIN_RING_POINTS, PIN_RING_DARK, 2.0)
	var spoke: float = cell_size.y * PIN_SPOKE_LENGTH_RATIO
	for i: int in 4:
		var dir: Vector2 = Vector2.RIGHT.rotated(TAU * i / 4.0)
		draw_line(c + dir * radius, c + dir * (radius + spoke), PIN_RING_DARK, PIN_SPOKE_WIDTH)
	# Label above the ring, clamped inside the board.
	var font: Font = ThemeDB.fallback_font
	var size: int = maxi(int(cell_size.y * PIN_FONT_RATIO), 8)
	var text: String = tr(TEXT_PIN) % left
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + LABEL_PAD * 2.0
	var height: float = size * LABEL_LINE_SPACING + LABEL_PAD
	var board: Rect2 = ScreenLayout.board_rect(grid, vp)
	var pos := Vector2(c.x - width * 0.5, c.y - radius - spoke - cell_size.y * PIN_TEXT_GAP_RATIO - height)
	pos.x = clampf(pos.x, board.position.x, maxf(board.end.x - width, board.position.x))
	pos.y = maxf(pos.y, board.position.y)
	var back := Rect2(pos, Vector2(width, height))
	draw_rect(back, TEXT_OUTLINE_LIGHT)
	draw_rect(back, PIN_RING_DARK, false, 2.0)
	draw_string(font, pos + Vector2(0.0, LABEL_PAD * 0.5 + size * 0.85), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, PIN_TEXT_COLOR)


# Feint flash on the player's half: dashed grey outlines (no red, no X) and a fading label.
func _draw_feint(vp: Vector2) -> void:
	var flash: Dictionary = _combat.get_feint_flash()
	if flash.is_empty():
		return
	var fade: float = clampf(float(flash["time_left"]) / CombatView.FEEDBACK_SEC, 0.0, 1.0)
	var cells: Array[Vector2i] = flash["cells"]
	var grid: BoardGrid = _combat.get_grid()
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
		draw_rect(rect, Color(FEINT_TINT, FEINT_TINT.a * fade))
		_draw_dashed_rect(rect.grow(-FEINT_INSET), Color(FEINT_COLOR, fade))
	_draw_cells_label(vp, cells, tr(TEXT_FEINT), tr(TEXT_FEINT_NOTE), FEINT_COLOR, fade)


# Dashed rectangle outline (manual dashes: no engine API dependency).
func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a).normalized()
		var d: float = 0.0
		while d < length:
			var e: float = minf(d + FEINT_DASH_LENGTH, length)
			draw_line(a + dir * d, a + dir * e, color, FEINT_DASH_WIDTH)
			d += FEINT_DASH_LENGTH * 2.0


# "né: N | ngắt: N | giả: N%" under the boss HP bar, right-aligned to the bar's right edge
# (hud.end.x - CombatView.PAD), in the gap between the HUD band and the board's top.
func _draw_learning_debug(vp: Vector2) -> void:
	var learning: BossLearning = _combat.get_learning()
	if learning == null:
		return
	var hud: Rect2 = ScreenLayout.hud_rect(vp)
	var chance: float = float(learning.get_modifiers().get("feint_chance", 0.0))
	var text: String = tr(TEXT_LEARNING) % [learning.get_dodge_streak(), learning.get_interrupt_count(), roundi(chance * 100.0)]
	var width: float = hud.size.x * 0.5
	var pos := Vector2(hud.end.x - CombatView.PAD - width, hud.end.y + LEARNING_BASELINE_OFFSET + LEARNING_FONT_SIZE * 0.85)
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, width, LEARNING_FONT_SIZE, LEARNING_COLOR)


# Story 020: "Cháy ×N" (orange) while the boss's half has burning cells, "Ghim" (blue) right
# after it while the boss is pinned; left-aligned under the boss HP bar (clear of the right-aligned
# learning line). Nothing while the boss is dead or nothing applies.
func _draw_boss_status(vp: Vector2) -> void:
	if _combat.get_state().is_enemy_dead():
		return
	var stacks: int = _combat.get_burn_stacks()
	var pinned: bool = _combat.is_boss_pinned()
	if stacks <= 0 and not pinned:
		return
	var rect: Rect2 = ScreenLayout.hud_boss_status_rect(vp)
	var font: Font = ThemeDB.fallback_font
	var pos := Vector2(rect.position.x, rect.get_center().y + STATUS_FONT_SIZE * 0.35)
	if stacks > 0:
		var text: String = tr(TEXT_BURN_STACKS) % stacks
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, STATUS_FONT_SIZE, BURN_STACKS_COLOR)
		pos.x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, STATUS_FONT_SIZE).x + STATUS_GAP
	if pinned:
		draw_string(font, pos, tr(TEXT_PINNED), HORIZONTAL_ALIGNMENT_LEFT, -1.0, STATUS_FONT_SIZE, PINNED_COLOR)


func _draw_confirm(vp: Vector2) -> void:
	if not _combat.is_confirm_visible():
		return
	var rect: Rect2 = ScreenLayout.confirm_button_rect(vp)
	var actor: CutActor = _combat.get_cut_actor()
	var swinging: bool = actor.is_swinging()
	var alpha: float = DIM_ALPHA if swinging else 1.0
	draw_rect(rect, Color(BUTTON_READY_BACK, BUTTON_READY_BACK.a * alpha))
	draw_rect(rect, Color(BUTTON_OUTLINE, alpha), false, OUTLINE_WIDTH)
	var text: String = tr(TEXT_CONFIRM)
	if swinging:
		text = tr(TEXT_COOLDOWN) % actor.get_time_left()
	_draw_centered(rect, text, BIG_FONT_SIZE, Color(TEXT_LIGHT, alpha))


func _draw_menu(vp: Vector2) -> void:
	var flow: CutFlow = _combat.get_cut_flow()
	if not flow.is_menu_open():
		return
	var panel: Rect2 = ScreenLayout.skill_menu_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	var bar: Rect2 = ScreenLayout.skill_menu_bar_rect(vp)
	var ratio: float = 0.0 if flow.get_duration() <= 0.0 else flow.get_time_left() / flow.get_duration()
	draw_rect(bar, BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), BAR_FILL)
	draw_rect(bar, BUTTON_OUTLINE, false, 2.0)
	var config: SkillConfig = _combat.get_skill_config()
	var order: Array[String] = flow.get_hand()
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, order.size())
	var cell_count: int = flow.get_cells().size()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var id: String = order[i]
		var status: Dictionary = _skill_status(id, cell_count)
		var available: bool = bool(status["available"])
		var alpha: float = 1.0 if available else DIM_ALPHA
		draw_rect(rect, Color(BUTTON_READY_BACK if available else BUTTON_BACK, alpha))
		draw_rect(rect, Color(BUTTON_OUTLINE, alpha), false, OUTLINE_WIDTH)
		var name_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.6))
		var note_rect := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.45))
		var menu_name: String = _menu_skill_name(id)
		_draw_centered(name_rect, menu_name, _fit_font_size(menu_name, name_rect.size.x - MENU_NAME_PAD * 2.0, BUTTON_FONT_SIZE), Color(TEXT_LIGHT, alpha))
		_draw_centered(note_rect, str(status["text"]), SMALL_FONT_SIZE, Color(TEXT_LIGHT, alpha))


# {available, text}: "cần N ô" whenever the cut covers fewer cells than the skill needs (even
# if it is also unimplemented), else "chưa có", else the cooldown seconds, else ready.
func _skill_status(id: String, cell_count: int) -> Dictionary:
	var config: SkillConfig = _combat.get_skill_config()
	var check: Dictionary = SkillAvailability.check(config, _combat.get_skill_cooldowns(), id, cell_count, _combat.get_card_level(id))
	var min_cells: int = int(check["need_cells"])
	var text: String = tr(TEXT_READY)
	if cell_count < min_cells:
		text = tr(TEXT_NEED_CELLS) % min_cells
	elif str(check["reason"]) == "not_implemented":
		text = tr(TEXT_NOT_IMPLEMENTED)
	elif str(check["reason"]) == "cooldown":
		text = tr(TEXT_COOLDOWN) % float(check["cooldown_left"])
	return {"available": bool(check["available"]), "text": text}


func _skill_name(id: String) -> String:
	return tr(str(_combat.get_skill_config().get_skill(id).get("name_key", id)))


# Story 020: the menu card name with the player's level suffix ("Kiếm khí +2") above level 1.
func _menu_skill_name(id: String) -> String:
	var level: int = _combat.get_card_level(id)
	if level > 1:
		return _skill_name(id) + LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
	return _skill_name(id)


# Largest font size <= [param size] (never below MENU_NAME_MIN_FONT_SIZE) at which [param text]
# fits in [param width] pixels (Story 020: "Chấn phong +3" must not clip in a menu slot).
func _fit_font_size(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MENU_NAME_MIN_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted


# The signature hotkey from combat.json (`signature_key`), SIGNATURE_KEY_FALLBACK without a config.
func _signature_key() -> Key:
	if _combat == null or not _combat.has_method("get_config"):
		return SIGNATURE_KEY_FALLBACK
	var config: CombatConfig = _combat.get_config()
	if config == null:
		return SIGNATURE_KEY_FALLBACK
	var code: Key = OS.find_keycode_from_string(config.signature_key)
	return code if code != KEY_NONE else SIGNATURE_KEY_FALLBACK
