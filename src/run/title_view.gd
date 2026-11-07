class_name TitleView
extends Node2D
## Title screen / Main Menu (Story 016; Main Menu pass, user 2026-11-01). The key-art scene fills the screen:
## the Misty Forest backdrop (whole-number scale), the Swordsman seen from behind on a stone ledge on the right,
## a golden Tessera cube floating over the world with small squares orbiting it, golden block pieces drifting
## down, and mist bands drifting across. The left side is darkened for the menu: the game name over the
## knife-stroke motif (top-left; no tagline and no saved-run summary line, user 2026-11-01), then one column of
## buttons — "Tiếp tục" (save slots 2026-11-07: shown when any slot has a save; opens the slot screen to pick the save
## to load, [method GameFlow.title_continue]), "Chơi" (the slot screen to pick where a new run goes,
## [method GameFlow.title_play]; the main action when there is nothing to continue), "Thành tựu", "Cài đặt" ([method GameFlow.open_settings]) and
## "Thoát" (hidden on platforms without a quit button, see [method GameFlow.can_show_quit]). Child of GameFlow
## (reads it through [member flow_path]); draws and takes taps only in [constant GameFlow.Phase.TITLE]; owns no
## state. Taps are consumed on a button only; input dedup as in RunHudView / DPadView (emulated copies —
## device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## DEV convenience: Enter / Keypad Enter / Space (pressed, not echo) trigger the FIRST button.
## All strings are TEXT_* keys drawn through tr() (Story 017). A small language button (UiButtons NEUTRAL,
## bottom-right) shows the label of the NEXT locale and cycles [method GameFlow.toggle_locale].
## Reduce motion (SettingsStore) freezes the scene's motion on its first moment.

## 2026-10-31 dark skin: the name in Ivory, the knife strokes in Grid Light
## at 60 % alpha (red is reserved for enemy telegraphs).
const NAME_COLOR: Color = HudSkin.IVORY
const STROKE_COLOR: Color = Color("FFD45C99")
const STROKE_WIDTH: float = 12.0
const NAME_FONT_SIZE: int = 96
const BUTTON_FONT_SIZE: int = 32
## Pixel buttons (Main Menu pass): label colours from the background's light ivory and gold, frame tints.
## Baseline of the name as a share of the title band height (no tagline: user 2026-11-01).
const NAME_BASELINE: float = 0.62
## Knife strokes behind the name: (from, to) pairs as shares of the title band size.
const STROKES: Array[Vector2] = [
	Vector2(0.08, 0.78), Vector2(0.18, 0.1),
	Vector2(0.3, 0.82), Vector2(0.4, 0.14),
	Vector2(0.52, 0.78), Vector2(0.62, 0.1),
]

## --- Menu background (user 2026-11-01: redrawn with PixelLab in the style of the key art and
## design/art/reference/09-world-map-01.png) ---
## A 640x360 pixel-art scene (create_image_pro, 25 gen, style reference 09-world-map-01, user-approved) drawn at
## a whole-number scale (2x at 720p, the Swordsman's own density) covering the screen; an empty rock ledge
## bottom-left carries the Swordsman (his real back view, PixelLab rotation north-east, no generation).
const KEY_ART: Texture2D = preload("res://assets/art/ui/title/menu_bg.png")
const HERO_BACK: Texture2D = preload("res://assets/art/ui/title/hero_back_ne.png")
## The hero's feet on the ledge (shares of the background: the ledge's top surface is row 295 of 360 there) and its
## whole-number scale at 720p. HERO_FEET_ROW is the sprite row the feet stand on (the 84x84 rotation canvas has
## 10 empty rows under them), so that row, not the canvas bottom, lands on the rock (user 2026-11-01: the hero was
## floating).
const HERO_FEET: Vector2 = Vector2(0.17, 0.826)
const HERO_FEET_ROW: int = 73
const HERO_SCALE_720: int = 2
## Where the golden cube of the background sits (shares of the art) and the glow / rising squares around it.
const ART_CUBE: Vector2 = Vector2(0.58, 0.17)
const GLOW: Color = Color("FFD45C")
const GLOW_RADIUS: float = 70.0
const GLOW_PULSE_SPEED: float = 1.6
const SPARK_COUNT: int = 9
const SPARK_SPEED: float = 16.0
const SPARK_SIZE: float = 5.0
## Mist bands drifting over the lower half: (y share, height share, speed px/s).
const MIST: Array[Vector3] = [Vector3(0.66, 0.05, 9.0), Vector3(0.78, 0.07, -6.0), Vector3(0.9, 0.06, 12.0)]
const MIST_COLOR: Color = Color(0.86, 0.9, 0.96, 0.06)
## Darkening behind the menu column (on the menu's side): solid over SHADE_SOLID_RATIO of the width from that edge,
## then fading out by SHADE_FADE_RATIO, in SHADE_STEPS bands; plus a soft band behind the name (top-left).
const SHADE_COLOR: Color = Color("17151D")
const SHADE_ALPHA: float = 0.7
const SHADE_SOLID_RATIO: float = 0.36
const SHADE_FADE_RATIO: float = 0.5
const SHADE_STEPS: int = 32
const NAME_SHADE_ALPHA: float = 0.4
const NAME_SHADE_FADE_RATIO: float = 0.12
## Share of the title band the name shade covers (the name only, no tagline under it).
const NAME_SHADE_HEIGHT_SHARE: float = 0.8
## DEV-ONLY user arg: --menu-variant=a (menu on the left, the art mirrored so the hero is on the right) or b
## (the art as drawn, the menu on the right; the default).
const VARIANT_ARG: String = "--menu-variant="

const TEXT_NAME: String = "title.name"
const TEXT_CONTINUE: String = "ui.title.continue"
const TEXT_PLAY: String = "ui.title.play"
const TEXT_QUIT: String = "ui.title.quit"
## Story 037: the achievements screen.
const TEXT_ACHIEVEMENTS: String = "title.achievements"
## Main Menu pass: the settings screen.
const TEXT_SETTINGS: String = "ui.title.settings"
## Labels of the language button by locale code (the button shows the NEXT locale's label).
const TEXT_LANG_VI: String = "ui.title.lang.vi"
const TEXT_LANG_EN: String = "ui.title.lang.en"
const LANG_FONT_SIZE: int = 28
## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MenuFont.read_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(VARIANT_ARG):
			ScreenLayout.title_menu_right = arg.trim_prefix(VARIANT_ARG) != "a"


# Redraws every frame, also while inactive: a CanvasItem keeps its last frame until the next
# redraw, and a transparent screen drawn later (the chapter map) would show the stale title.
func _process(_delta: float) -> void:
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.TITLE


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	var labels: Array[String] = _button_labels()
	if labels.is_empty():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_activate(0)
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
	if ScreenLayout.title_lang_button_rect(get_viewport_rect().size).has_point(pos):
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_flow.toggle_locale()
		return
	var rects: Array[Rect2] = ScreenLayout.title_button_rects(get_viewport_rect().size, labels.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_activate(i)
			return


# Label KEYS of the column, top to bottom; the first is the main action (translated when drawn).
func _button_labels() -> Array[String]:
	var labels: Array[String] = []
	if _flow.has_any_save():
		labels.append(TEXT_CONTINUE)
	labels.append(TEXT_PLAY)
	labels.append(TEXT_ACHIEVEMENTS)
	labels.append(TEXT_SETTINGS)
	if _flow.can_show_quit():
		labels.append(TEXT_QUIT)
	return labels


# Style of button [param index] of [param labels]: the first is PRIMARY, "Chơi" after a
# "Tiếp tục" is SECONDARY, the others are NEUTRAL.
func _button_style(labels: Array[String], index: int) -> int:
	match labels[index]:
		TEXT_QUIT, TEXT_ACHIEVEMENTS, TEXT_SETTINGS:
			return UiButtons.Style.NEUTRAL
		TEXT_PLAY:
			return UiButtons.Style.PRIMARY if index == 0 else UiButtons.Style.SECONDARY
	return UiButtons.Style.PRIMARY


# Runs the action of button [param index].
func _activate(index: int) -> void:
	var labels: Array[String] = _button_labels()
	if index < 0 or index >= labels.size():
		return
	match labels[index]:
		TEXT_CONTINUE:
			_flow.title_continue()
		TEXT_PLAY:
			_flow.title_play()
		TEXT_ACHIEVEMENTS:
			_flow.open_achievements()
		TEXT_SETTINGS:
			_flow.open_settings()
		TEXT_QUIT:
			_flow.quit_requested()


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var t: float = 0.0 if SettingsStore.shared().get_reduce_motion() else Time.get_ticks_msec() / 1000.0
	_draw_scene(vp, t)
	var band: Rect2 = ScreenLayout.title_rect(vp)
	for i: int in range(0, STROKES.size() - 1, 2):
		draw_line(band.position + band.size * STROKES[i], band.position + band.size * STROKES[i + 1], STROKE_COLOR, STROKE_WIDTH)
	_text(band, band.position.y + band.size.y * NAME_BASELINE, tr(TEXT_NAME), NAME_FONT_SIZE, NAME_COLOR, true)
	var labels: Array[String] = _button_labels()
	var rects: Array[Rect2] = ScreenLayout.title_button_rects(vp, labels.size())
	for i: int in rects.size():
		UiButtons.draw_button(self, rects[i], tr(labels[i]), UiButtons.Style.PRIMARY if i == 0 else UiButtons.Style.SECONDARY,
			UiButtons.is_pressed_at(self, rects[i]), true, BUTTON_FONT_SIZE)
	var lang: Rect2 = ScreenLayout.title_lang_button_rect(vp)
	UiButtons.draw_button(self, lang, tr(_lang_label(_flow.next_locale())), UiButtons.Style.SECONDARY,
		UiButtons.is_pressed_at(self, lang), true, LANG_FONT_SIZE)


# The key art covering the screen (mirrored when the menu is on the left, so the hero stays clear of it), then
# the glow on its cube, sparks rising from it, mist bands, and the shades for the menu and the name.
func _draw_scene(vp: Vector2, t: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), HudSkin.SCREEN_BG)
	var art := Vector2(KEY_ART.get_size())
	# Whole-number scale that covers the screen (2x at 1280x720), centred and cropped.
	var scale: float = ceilf(maxf(vp.x / art.x, vp.y / art.y))
	var size: Vector2 = art * scale
	var origin: Vector2 = ((vp - size) * 0.5).round()
	var mirrored: bool = not ScreenLayout.title_menu_right
	if mirrored:
		draw_set_transform(Vector2(vp.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(KEY_ART, Rect2(origin, size), false)
	var hero_scale: int = maxi(1, roundi(HERO_SCALE_720 * vp.y / 720.0))
	var hero := Vector2(HERO_BACK.get_size()) * hero_scale
	var feet: Vector2 = origin + size * HERO_FEET
	var top_left := Vector2(feet.x - hero.x * 0.5, feet.y - float(HERO_FEET_ROW + 1) * hero_scale)
	draw_texture_rect(HERO_BACK, Rect2(top_left.round(), hero), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k: float = vp.y / 720.0
	var cube_art := origin + size * ART_CUBE
	var cube := Vector2(vp.x - cube_art.x, cube_art.y) if mirrored else cube_art
	var pulse: float = 0.5 + 0.5 * sin(t * GLOW_PULSE_SPEED)
	for i: int in 4:
		draw_colored_polygon(HudSkin.regular_points(cube, GLOW_RADIUS * k * (1.0 - i * 0.2), 8, -PI * 0.5 + PI / 8.0), Color(GLOW, (0.03 + 0.02 * pulse) * (i + 1)))
	for i: int in SPARK_COUNT:
		var phase: float = float(i) / float(SPARK_COUNT)
		var rise: float = fposmod(t * SPARK_SPEED + phase * 90.0, 90.0) * k
		var x: float = cube.x + sin(phase * TAU * 3.0 + t * 0.7) * 60.0 * k
		var a: float = 1.0 - rise / (90.0 * k)
		draw_rect(Rect2(Vector2(x, cube.y + 40.0 * k - rise), Vector2(SPARK_SIZE, SPARK_SIZE) * k), Color(GLOW, 0.8 * a))
	for band: Vector3 in MIST:
		var w: float = vp.x * 0.7
		var x2: float = fposmod(t * band.z, vp.x + w) - w
		draw_rect(Rect2(x2, vp.y * band.x, w, vp.y * band.y), MIST_COLOR)
	_draw_shade(vp)


# The darkened side behind the menu column (solid, then fading toward the middle) and a soft band behind the name.
func _draw_shade(vp: Vector2) -> void:
	var right: bool = ScreenLayout.title_menu_right
	var solid: float = vp.x * SHADE_SOLID_RATIO
	var fade_w: float = vp.x * (SHADE_FADE_RATIO - SHADE_SOLID_RATIO) / SHADE_STEPS
	draw_rect(Rect2(vp.x - solid if right else 0.0, 0.0, solid, vp.y), Color(SHADE_COLOR, SHADE_ALPHA))
	for i: int in SHADE_STEPS:
		var a: float = SHADE_ALPHA * (1.0 - float(i + 1) / float(SHADE_STEPS + 1))
		# Whole-pixel band edges that meet exactly (overlapping bands drew darker seams).
		var x0: float = roundf(vp.x - solid - fade_w * (i + 1)) if right else roundf(solid + fade_w * i)
		var x1: float = roundf(vp.x - solid - fade_w * i) if right else roundf(solid + fade_w * (i + 1))
		draw_rect(Rect2(x0, 0.0, x1 - x0, vp.y), Color(SHADE_COLOR, a))
	# A soft band behind the name only (the tagline is outlined): solid to the band's end, then fading out over
	# NAME_SHADE_FADE_RATIO of the width (no hard box edge); it stops before the art's cube.
	var band: Rect2 = ScreenLayout.title_rect(vp)
	band.size.y *= NAME_SHADE_HEIGHT_SHARE
	draw_rect(Rect2(0.0, band.position.y, band.end.x, band.size.y), Color(SHADE_COLOR, NAME_SHADE_ALPHA))
	var fade: float = vp.x * NAME_SHADE_FADE_RATIO / SHADE_STEPS
	for i: int in SHADE_STEPS:
		var x0: float = roundf(band.end.x + fade * i)
		var x1: float = roundf(band.end.x + fade * (i + 1))
		var a2: float = NAME_SHADE_ALPHA * (1.0 - float(i + 1) / float(SHADE_STEPS + 1))
		draw_rect(Rect2(x0, band.position.y, x1 - x0, band.size.y), Color(SHADE_COLOR, a2))


# Label key of the language button for locale [param code].
func _lang_label(code: String) -> String:
	return TEXT_LANG_EN if code == "en" else TEXT_LANG_VI


# Single-line outlined text (HudSkin) at baseline [param y], left-aligned in [param rect]; Bold when [param bold].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, _bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x)
