extends SceneTree
## 2026-11-02 ancient buttons (user reference sheet; the riveted stone frame stays on cards only): UiButtons.look
## gives PRIMARY a gold plate with gems and a dark label, SECONDARY / NEUTRAL a navy plate, the selected state a gold
## plate without gems, disabled a grey one; a pressed plate sinks inside its hit rect; and no script outside the card
## face draws the riveted frame (PixelFrame.BUTTON_FRAME) any more.
## Reads res:// source files for the last check only. Prints PASS/FAIL lines and FAILS=n, exit code 1 on failure.
## Run: godot --headless --path . -s res://tests/unit/ui/ui_buttons_test.gd

const SCAN_DIRS: Array[String] = ["res://src/run", "res://src/ui", "res://src/hold", "res://src/combat", "res://src/battle"]
## The card face (and the frame helper itself) may keep the riveted frame.
const FRAME_ALLOWED: Array[String] = ["card_face.gd", "pixel_frame.gd"]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_primary_is_gold_with_gems_and_a_dark_label()
	test_secondary_is_navy_without_gems()
	test_selected_turns_gold_without_gems()
	test_disabled_is_grey_without_gems()
	test_pressed_darkens_the_fill()
	test_pressed_body_sinks_inside_the_hit_rect()
	test_only_cards_use_the_riveted_frame()
	test_every_look_has_its_plate_textures()
	test_small_icon_plates_drop_to_scale_1()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_primary_is_gold_with_gems_and_a_dark_label() -> void:
	var lk: Dictionary = UiButtons.look(UiButtons.Style.PRIMARY, false)
	_check("test_primary_fill_is_gold", lk["fill"] == UiButtons.GOLD_FILL)
	_check("test_primary_has_gems", bool(lk["gems"]))
	_check("test_primary_label_is_dark", (lk["text"] as Color).get_luminance() < 0.25)


func test_secondary_is_navy_without_gems() -> void:
	for style: int in [UiButtons.Style.SECONDARY, UiButtons.Style.NEUTRAL]:
		var lk: Dictionary = UiButtons.look(style, false)
		_check("test_style_%d_fill_is_navy" % style, lk["fill"] == UiButtons.NAVY_FILL)
		_check("test_style_%d_has_no_gems" % style, not bool(lk["gems"]))
		_check("test_style_%d_rim_is_gold" % style, lk["rim"] == UiButtons.GOLD_RIM)


func test_selected_turns_gold_without_gems() -> void:
	var lk: Dictionary = UiButtons.look(UiButtons.Style.SECONDARY, false, true, true)
	_check("test_selected_fill_is_gold", lk["fill"] == UiButtons.GOLD_FILL)
	_check("test_selected_has_no_gems", not bool(lk["gems"]))


func test_disabled_is_grey_without_gems() -> void:
	var lk: Dictionary = UiButtons.look(UiButtons.Style.PRIMARY, true, false)
	_check("test_disabled_fill_is_grey", lk["fill"] == UiButtons.GREY_FILL)
	_check("test_disabled_rim_is_grey", lk["rim"] == UiButtons.GREY_RIM)
	_check("test_disabled_has_no_gems", not bool(lk["gems"]))


func test_pressed_darkens_the_fill() -> void:
	for style: int in [UiButtons.Style.PRIMARY, UiButtons.Style.SECONDARY, UiButtons.Style.DANGER]:
		var up: Color = UiButtons.look(style, false)["fill"]
		var down: Color = UiButtons.look(style, true)["fill"]
		_check("test_style_%d_pressed_is_darker" % style, down.get_luminance() < up.get_luminance())


func test_pressed_body_sinks_inside_the_hit_rect() -> void:
	var rect := Rect2(100.0, 50.0, 200.0, 60.0)
	var up: Rect2 = UiButtons.body_rect(rect, 1.0, false)
	var down: Rect2 = UiButtons.body_rect(rect, 1.0, true)
	_check("test_raised_body_starts_at_the_rect_top", up.position == rect.position)
	_check("test_pressed_body_moves_down_by_the_lip", is_equal_approx(down.position.y - up.position.y, UiButtons.LIP_ART))
	_check("test_both_bodies_stay_inside_the_rect", rect.encloses(up) and rect.encloses(down))


func test_only_cards_use_the_riveted_frame() -> void:
	var hits: Array[String] = []
	for dir: String in SCAN_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd") or FRAME_ALLOWED.has(file):
				continue
			var lines: PackedStringArray = FileAccess.get_file_as_string(dir.path_join(file)).split("\n")
			for i: int in lines.size():
				if lines[i].get_slice("#", 0).contains("PixelFrame.BUTTON_FRAME"):
					hits.append("%s:%d" % [file, i + 1])
	_check("test_no_button_or_control_uses_the_riveted_frame", hits.is_empty(), str(hits))


func test_every_look_has_its_plate_textures() -> void:
	for style: int in [UiButtons.Style.PRIMARY, UiButtons.Style.SECONDARY, UiButtons.Style.DANGER, UiButtons.Style.NEUTRAL]:
		for enabled: bool in [true, false]:
			var plate: String = UiButtons.look(style, false, enabled)["plate"]
			for state: String in ["up", "down"]:
				var key: String = "%s_%s" % [plate, state]
				_check("test_plate_%s_is_loaded" % key, UiButtons.PLATES.get(key) is Texture2D)


func test_small_icon_plates_drop_to_scale_1() -> void:
	_check("test_38px_pause_tile_drops_to_scale_1", is_equal_approx(UiButtons.icon_scale(Rect2(0, 0, 38, 38), 2.0), 1.0))
	_check("test_70px_slot_keeps_scale_2", is_equal_approx(UiButtons.icon_scale(Rect2(0, 0, 70, 70), 2.0), 2.0))
