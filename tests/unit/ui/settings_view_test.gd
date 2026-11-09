extends SceneTree
## Settings screen redesign (user 2026-11-09): tabs, switches, language select, volume steppers, keyboard focus,
## persistence and layout. Runs the REAL main scene headless with the settings on a temp file under user:// (never the
## real user://settings.json) and memory save slots; taps go through SettingsView.tap like a touch / click.
## Run: godot --headless --path . -s res://tests/unit/ui/settings_view_test.gd

const MAIN_SCENE: String = "res://src/main.tscn"
const TEMP_PATH: String = "user://settings_view_test_tmp.json"
const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(640, 360), Vector2(1600, 720), Vector2(1920, 1080), Vector2(1024, 768), Vector2(1280, 1280)]

var fails: int = 0
var view: SettingsView
var flow: GameFlow
var store: SettingsStore
var vp: Vector2


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_run()


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _run() -> void:
	var real_before: String = FileAccess.get_file_as_string(SettingsStore.DEFAULT_PATH)
	_clean()
	test_layout()
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	flow = main.get_node("GameFlow") as GameFlow
	store = SettingsStore.new(TEMP_PATH)
	flow.set_slots_for_test(SaveSlots.memory(), store)
	root.add_child(main)
	for i: int in 3:
		await process_frame
	flow.set_locale("vi")
	flow.open_settings()
	await process_frame
	view = main.find_children("*", "SettingsView", true, false)[0] as SettingsView
	vp = view.get_viewport_rect().size
	test_tabs()
	test_switches()
	test_language_select()
	test_volume_steppers()
	test_audio_toggles()
	test_keyboard()
	test_persistence()
	view.tap(SettingsView.back_rect(vp).get_center())
	ck("Back closes the settings", flow.get_phase() != GameFlow.Phase.SETTINGS)
	root.remove_child(main)
	main.free()
	_clean()
	ck("the real user://settings.json was not touched", FileAccess.get_file_as_string(SettingsStore.DEFAULT_PATH) == real_before)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _row(id: String) -> Rect2:
	if view.get_tab() == "audio":
		return SettingsView.audio_row_rects(vp)[SettingsView.AUDIO_ROWS.find(id)]
	return SettingsView.row_rects(vp)[SettingsView.ROWS.find(id)]


func _control(id: String) -> Rect2:
	return SettingsView.value_rect(_row(id), vp, SettingsView.kind_of(id))


func _label_point(id: String) -> Vector2:
	var r: Rect2 = _row(id)
	return Vector2(r.position.x + r.size.x * 0.15, r.get_center().y)


func test_tabs() -> void:
	ck("opens on the General tab", view.get_tab() == "general")
	var tabs: Array[Rect2] = SettingsView.tab_rects(vp)
	view.tap(tabs[1].get_center())
	ck("tapping Âm thanh shows the audio rows", view.get_tab() == "audio" and view.current_rows() == SettingsView.AUDIO_ROWS)
	view.tap(tabs[1].get_center())
	ck("tapping the selected tab again keeps it", view.get_tab() == "audio")
	view.tap(tabs[0].get_center())
	ck("tapping Chung goes back", view.get_tab() == "general")


func test_switches() -> void:
	var segs: Array[Rect2] = SettingsView.switch_segments(_control("hints"))
	view.tap(segs[1].get_center())
	ck("Bật segment turns control hints on", store.get_show_control_hints())
	view.tap(segs[1].get_center())
	ck("tapping the chosen segment again changes nothing (no double action)", store.get_show_control_hints())
	view.tap(_label_point("hints"))
	ck("tapping the rest of the row flips it", not store.get_show_control_hints())
	view.tap(SettingsView.switch_segments(_control("motion"))[1].get_center())
	ck("reduce motion on via its switch", store.get_reduce_motion())
	view.tap(SettingsView.switch_segments(_control("motion"))[0].get_center())
	ck("and off via Tắt", not store.get_reduce_motion())


func test_language_select() -> void:
	ck("the select lists every supported language, Vietnamese first", SettingsView.language_options() == ["vi", "en"]
		and GameFlow.SUPPORTED_LOCALES.size() == SettingsView.language_options().size())
	view.tap(_control("language").get_center())
	ck("tapping the select opens the list", view.is_language_open())
	view.tap(Vector2(5, 5))
	ck("a tap elsewhere closes it without changing the language", not view.is_language_open() and flow.get_locale() == "vi")
	view.tap(_label_point("language"))
	ck("tapping the row opens it too", view.is_language_open())
	var opts: Array[Rect2] = SettingsView.language_option_rects(_control("language"), vp)
	var opts_ok: bool = opts.size() == 2
	for r: Rect2 in opts:
		opts_ok = opts_ok and Rect2(Vector2.ZERO, vp).encloses(r) and not r.intersects(_control("language")) 			and r.size.y >= 48.0 * SettingsView.unit(vp) - 0.5
	ck("the options sit on screen, clear of the select box, each >= 48 design px tall", opts_ok)
	view.tap(opts[1].get_center())
	ck("picking English switches the UI and saves the locale", flow.get_locale() == "en" and TranslationServer.get_locale().begins_with("en")
		and store.get_locale() == "en" and not view.is_language_open())
	view.handle_nav(_action("ui_down"))
	view.handle_nav(_action("ui_down"))
	view.handle_nav(_action("ui_down"))
	view.handle_nav(_action("ui_left"))
	ck("ui_left on the focused language row cycles back to Tiếng Việt", flow.get_locale() == "vi")
	view.set_tab("audio")
	view.set_tab("general")
	ck("switching tabs resets the focus", view.get_focus() == -1)


func test_volume_steppers() -> void:
	view.tap(SettingsView.tab_rects(vp)[1].get_center())
	var parts: Array[Rect2] = SettingsView.stepper_parts(_control("vol_Master"), vp)
	view.tap(parts[0].get_center())
	ck("- lowers Master by 10", store.get_volume("Master") == 70)
	view.tap(Vector2(parts[2].get_center().x, _row("vol_Master").position.y + 2.0))
	ck("+ is hit at the very top of the row (full-height target)", store.get_volume("Master") == 80)
	view.tap(Vector2(parts[1].position.x + 1.0, parts[1].get_center().y))
	ck("the meter's left end sets 0 %", store.get_volume("Master") == 0)
	view.tap(parts[0].get_center())
	ck("- at 0 % stays at 0 (no wrap)", store.get_volume("Master") == 0)
	view.tap(Vector2(parts[1].end.x - 1.0, parts[1].get_center().y))
	ck("the meter's right end sets 100 %", store.get_volume("Master") == 100)
	view.tap(parts[2].get_center())
	ck("+ at 100 % stays at 100 (no wrap)", store.get_volume("Master") == 100)
	view.tap(_label_point("vol_Music"))
	ck("a tap on the label side changes nothing", store.get_volume("Music") == 80)
	var music: Array[Rect2] = SettingsView.stepper_parts(_control("vol_Music"), vp)
	view.tap(Vector2(music[1].position.x + music[1].size.x * 0.5, music[1].get_center().y))
	ck("the meter's middle sets 50 %", store.get_volume("Music") == 50)
	ck("the readout shows the percent", view.audio_value_text("vol_Music") == "50%")


func test_audio_toggles() -> void:
	view.tap(SettingsView.switch_segments(_control("reduced_audio"))[1].get_center())
	view.tap(SettingsView.switch_segments(_control("vibration"))[0].get_center())
	ck("reduced audio on, vibration off via their switches", store.get_reduced_audio() and not store.get_vibration())
	var rig: AudioRig = AudioRig.of(flow)
	ck("the audio director follows the settings", rig != null and rig.director.reduced_audio and not rig.director.vibration_enabled)


func test_keyboard() -> void:
	ck("no focus ring before a key press", view.get_focus() == -1)
	view.handle_nav(_action("ui_down"))
	ck("ui_down focuses the first row", view.get_focus() == 0)
	view.handle_nav(_action("ui_down"))
	view.handle_nav(_action("ui_right"))
	ck("ui_right on the focused Music row raises it", store.get_volume("Music") == 60)
	view.handle_nav(_action("ui_focus_next"))
	ck("ui_focus_next switches the tab", view.get_tab() == "general")
	view.handle_nav(_action("ui_focus_next"))


func test_persistence() -> void:
	var again := SettingsStore.new(TEMP_PATH)
	ck("everything persisted to the settings file", again.get_volume("Master") == 100 and again.get_volume("Music") == 60
		and again.get_reduced_audio() and not again.get_vibration() and not again.get_show_control_hints()
		and not again.get_reduce_motion() and again.get_locale() == "vi")


func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func test_layout() -> void:
	for size: Vector2 in VIEWPORTS:
		var tag: String = "%dx%d" % [int(size.x), int(size.y)]
		var u: float = SettingsView.unit(size)
		var screen := Rect2(Vector2.ZERO, size)
		var tabs: Array[Rect2] = SettingsView.tab_rects(size)
		var back: Rect2 = SettingsView.back_rect(size)
		var gen_panel: Rect2 = SettingsView.panel_rect(size, 3, SettingsView.GENERAL_ROW_H_PX)
		var aud_panel: Rect2 = SettingsView.panel_rect(size, 7, SettingsView.AUDIO_ROW_H_PX)
		var ok: bool = screen.encloses(aud_panel) and screen.encloses(back) and not back.intersects(tabs[-1])
		for t: Rect2 in tabs:
			ok = ok and t.size.y >= 64.0 * u - 0.5 and not t.intersects(aud_panel)
		ok = ok and back.size.y >= 64.0 * u - 0.5 and not back.intersects(aud_panel)
		ck("%s: tabs, Back and panels on screen, touch-sized, apart" % tag, ok)
		var rows_ok: bool = true
		for set: Array in [[SettingsView.row_rects(size), SettingsView.ROWS], [SettingsView.audio_row_rects(size), SettingsView.AUDIO_ROWS]]:
			var rects: Array[Rect2] = set[0]
			for i: int in rects.size():
				var c: Rect2 = SettingsView.value_rect(rects[i], size, SettingsView.kind_of(set[1][i]))
				rows_ok = rows_ok and rects[i].size.y >= 64.0 * u - 0.5 and rects[i].encloses(c)
				rows_ok = rows_ok and c.position.x - rects[i].position.x >= 200.0 * u
				if i > 0:
					rows_ok = rows_ok and not rects[i].intersects(rects[i - 1])
		ck("%s: rows >= 64 design px, apart, control inside, >= 200 px of label room" % tag, rows_ok)
		var c2: Rect2 = SettingsView.value_rect(SettingsView.audio_row_rects(size)[0], size, SettingsView.KIND_VOLUME)
		var parts: Array[Rect2] = SettingsView.stepper_parts(c2, size)
		ck("%s: stepper -, meter, + apart and in order, buttons >= 56 design px" % tag, parts[0].end.x < parts[1].position.x
			and parts[1].end.x < parts[2].position.x and parts[0].size.y >= 56.0 * u - 0.5 and parts[0].size.x >= 64.0 * u - 0.5)
		var aligned: bool = true
		for r: Rect2 in [tabs[0], back, aud_panel, c2]:
			aligned = aligned and r.position == r.position.round() and r.size == r.size.round()
		ck("%s: pixel-aligned rects (whole px)" % tag, aligned)
	ck("1600x720: the group stays capped and centred on a wide screen", SettingsView.group_rect(Vector2(1600, 720)).size.x <= 1200.0
		and absf(SettingsView.group_rect(Vector2(1600, 720)).get_center().x - 800.0) <= 1.0)
	_label_fit("vi")
	_label_fit("en")


# Every label and description fits its row at full size (no shrink, no clipping) in [param locale] at 1280x720.
func _label_fit(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var size := Vector2(1280, 720)
	var worst: String = ""
	var tr_of := func(k: String) -> String: return TranslationServer.translate(k)
	for set: Array in [[SettingsView.row_rects(size), SettingsView.ROWS], [SettingsView.audio_row_rects(size), SettingsView.AUDIO_ROWS]]:
		var rects: Array[Rect2] = set[0]
		for i: int in rects.size():
			var id: String = set[1][i]
			var c: Rect2 = SettingsView.value_rect(rects[i], size, SettingsView.kind_of(id))
			var room: float = c.position.x - rects[i].position.x - 2.0 * SettingsView.ROW_PAD_X_PX
			var keys: Dictionary = {"hints": ["ui.settings.hints", "ui.settings.hints_hint"], "motion": ["ui.settings.reduce_motion",
				"ui.settings.reduce_motion_hint"], "language": ["ui.settings.language", "ui.settings.language_hint"]}
			var label_key: String = keys[id][0] if keys.has(id) else str(SettingsView.TEXT_AUDIO_LABELS[id])
			if MenuFont.fit_size(tr_of.call(label_key), SettingsView.LABEL_FONT_SIZE, room) < SettingsView.LABEL_FONT_SIZE:
				worst += " " + id
			if keys.has(id) and MenuFont.fit_size(tr_of.call(keys[id][1]), SettingsView.HINT_FONT_SIZE, room) < SettingsView.HINT_FONT_SIZE:
				worst += " " + id + "_hint"
	ck("%s: every label and description fits at full size" % locale, worst.is_empty(), worst)
