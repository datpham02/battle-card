extends SceneTree
## Save slots (user 2026-11-07) through the real main scene and REAL files in a throwaway folder under
## OS.get_temp_dir() (never user://; removed at the end). Covers: the legacy progress file migrates into slot 1 on
## disk (.bak kept, locale to the settings file); the title has no slot button: "Chơi" opens the slot screen in NEW
## mode and "Tiếp tục" (only while a save exists) in LOAD mode; a run started in slot 1 is written to slot_1.json; an
## empty slot opens the character select and becomes the active slot (settings last_slot); LOAD on a slot with a run
## continues it; NEW on a slot with a run asks, then drops only the run; delete asks first (Back / "Hủy" keep the file, "Xóa" removes it, the active progress
## becomes empty); a corrupt slot file does not crash, is kept as .bad and the slot starts a new game; the locale is
## written to the settings, not to the slot; a fresh GameFlow reopens the last used slot. The slot screen's taps go
## through SaveSlotsView.tap (headless: no window needed).
## Run: godot --headless --path . -s res://tests/integration/run/save_slots_flow_test.gd   Prints PASS/FAIL and FAILS=n.

const MAIN_SCENE: String = "res://src/main.tscn"
const SETTLE_FRAMES: int = 3

var _fails: int = 0
var _tmp: String = ""


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _new_main(slots: SaveSlots, settings: SettingsStore) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	(main.get_node("GameFlow") as GameFlow).set_slots_for_test(slots, settings)
	root.add_child(main)
	await _frames(SETTLE_FRAMES)
	return main


func _drop_main(main: Node) -> void:
	root.remove_child(main)
	main.queue_free()
	await process_frame


func _file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for f: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _run() -> void:
	TranslationServer.set_locale("vi")
	_tmp = OS.get_temp_dir().path_join("tessera_save_slots_test_%d" % OS.get_process_id())
	_remove_tree(_tmp)
	DirAccess.make_dir_recursive_absolute(_tmp)
	_check(not _tmp.begins_with("user://") and DirAccess.dir_exists_absolute(_tmp), "temp folder outside user:// " + _tmp)
	var legacy_path: String = _tmp.path_join("progress.json")
	var settings_path: String = _tmp.path_join("settings.json")
	var slots := SaveSlots.new(_tmp.path_join("saves"), legacy_path)
	var settings := SettingsStore.new(settings_path)

	# --- Legacy migration on disk.
	var legacy := ProgressState.new()
	legacy.set_locale("vi")
	legacy.record_floor(2)
	var legacy_text: String = legacy.to_json()
	ProgressStore.write_atomic(legacy_path, legacy_text)
	_check(slots.migrate_legacy(settings) == "vi", "legacy migrated (locale vi)")
	_check(FileAccess.file_exists(slots.slot_path(0)) and _file_text(slots.slot_path(0)) == legacy_text, "slot_1.json holds the legacy text")
	_check(not FileAccess.file_exists(legacy_path) and _file_text(legacy_path + SaveSlots.LEGACY_BACKUP_SUFFIX) == legacy_text, "progress.json kept as progress.json.bak")
	_check(SettingsStore.new(settings_path).get_locale() == "vi", "locale written to the settings file")

	# --- Title: no slot button; "Tiếp tục" shows (slot 1 holds the migrated file); "Chơi" -> NEW mode.
	var main: Node = await _new_main(slots, settings)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	var title: TitleView = flow.get_node("TitleView") as TitleView
	var view: SaveSlotsView = flow.get_node("SaveSlotsView") as SaveSlotsView
	var vp: Vector2 = view.get_viewport_rect().size
	var cards: Array[Rect2] = SaveSlotsView.card_rects(vp)
	var hero: String = flow.get_characters().default_id()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.get_active_slot() == 0, "boots on the title, slot 1 active")
	var labels: Array[String] = title._button_labels()
	_check(labels.size() <= 5 and labels[0] == TitleView.TEXT_CONTINUE and not labels.has("ui.title.slots"), "title: Tiếp tục first, no separate slot button " + str(labels))
	_check(flow.get_progress().get_best_floor() == 2, "the migrated progress is live")
	title._activate(labels.find(TitleView.TEXT_PLAY))
	_check(flow.get_phase() == GameFlow.Phase.SAVE_SLOTS and flow.get_slot_mode() == GameFlow.SLOT_MODE_NEW, "'Chơi' -> slot screen in NEW mode")
	_check(str(flow.slot_summary(0)["action"]) == GameFlow.SLOT_ACTION_PLAY and str(flow.slot_summary(1)["action"]) == GameFlow.SLOT_ACTION_NEW,
		"NEW mode: slot 1 (progress, no run) plays, slot 2 is new")
	view.tap(SaveSlotsView.primary_rect(cards[0], vp).get_center())
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_active_slot() == 0, "slot 1 'Chơi' -> character select in slot 1")
	flow.character_chosen(hero)
	await _frames(SETTLE_FRAMES)
	_check(flow.has_continue() and bool(slots.summary(0)["has_run"]) and slots.load_state(0).get_best_floor() == 2, "the run is saved to slot_1.json, progress kept")
	flow.leave_run_keep_save()

	# --- "Tiếp tục" -> LOAD mode.
	labels = title._button_labels()
	title._activate(labels.find(TitleView.TEXT_CONTINUE))
	_check(flow.get_phase() == GameFlow.Phase.SAVE_SLOTS and flow.get_slot_mode() == GameFlow.SLOT_MODE_LOAD, "'Tiếp tục' -> slot screen in LOAD mode")
	var s0: Dictionary = flow.slot_summary(0)
	_check(bool(s0["active"]) and str(s0["action"]) == GameFlow.SLOT_ACTION_CONTINUE and str(s0["character_id"]) == hero
		and int(s0["saved_at"]) > 0, "slot 1 card: active, continue, character, saved time")
	_check(str(flow.slot_summary(1)["action"]) == GameFlow.SLOT_ACTION_NEW, "slot 2 card: new game")

	# --- An empty slot -> character select, becomes active, remembered.
	view.tap(SaveSlotsView.primary_rect(cards[1], vp, false).get_center())
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_active_slot() == 1 and not flow.has_continue(), "tap 'Tạo mới' on slot 2 -> character select, slot 2 active, no run")
	_check(SettingsStore.new(settings_path).get_last_slot() == 1, "last slot 2 written to the settings file")
	_check(not FileAccess.file_exists(slots.slot_path(1)), "nothing written to slot 2 before a save")
	flow.show_title()
	_check(title._button_labels()[0] == TitleView.TEXT_CONTINUE, "title still offers 'Tiếp tục' (slot 1 has a save)")

	# --- LOAD: slot 1 with a run -> continue.
	flow.title_continue()
	view.tap(SaveSlotsView.primary_rect(cards[0], vp).get_center())
	await _frames(SETTLE_FRAMES)
	_check(flow.get_active_slot() == 0 and flow.get_run() != null and flow.get_phase() in [GameFlow.Phase.WORLD_MAP, GameFlow.Phase.MAP],
		"tap 'Tiếp tục' on slot 1 resumes its run")
	flow.leave_run_keep_save()

	# --- NEW on a slot with a run: asks, then drops only the run.
	flow.title_play()
	_check(str(flow.slot_summary(0)["action"]) == GameFlow.SLOT_ACTION_ABANDON, "NEW mode: slot 1 (run) offers 'Chơi mới'")
	view.tap(SaveSlotsView.primary_rect(cards[0], vp).get_center())
	var conf: Dictionary = flow.get_slot_confirm()
	_check(str(conf.get("kind", "")) == GameFlow.SLOT_CONFIRM_ABANDON and int(conf.get("index", -1)) == 0 and bool(slots.summary(0)["has_run"]), "'Chơi mới' asks first (run still saved)")
	view.tap(SaveSlotsView.confirm_button_rects(vp)[1].get_center())
	_check(flow.get_slot_confirm().is_empty() and bool(slots.summary(0)["has_run"]) and flow.get_phase() == GameFlow.Phase.SAVE_SLOTS, "'Hủy' keeps the run")
	view.tap(SaveSlotsView.primary_rect(cards[0], vp).get_center())
	view.tap(SaveSlotsView.confirm_button_rects(vp)[0].get_center())
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_active_slot() == 0 and not flow.has_continue()
		and not bool(slots.summary(0)["has_run"]) and slots.load_state(0).get_best_floor() == 2, "'Bỏ run' drops the run, keeps the slot's progress, character select")
	flow.show_title()

	# --- Delete asks first.
	flow.title_continue()
	view.tap(SaveSlotsView.delete_rect(cards[0], vp).get_center())
	_check(str(flow.get_slot_confirm().get("kind", "")) == GameFlow.SLOT_CONFIRM_DELETE and FileAccess.file_exists(slots.slot_path(0)), "'Xóa' asks first (file still there)")
	view.tap(SaveSlotsView.primary_rect(cards[2], vp, false).get_center())
	_check(flow.get_phase() == GameFlow.Phase.SAVE_SLOTS and flow.get_active_slot() == 0 and flow.get_slot_confirm().is_empty()
		and FileAccess.file_exists(slots.slot_path(0)), "while asking, a tap outside the box only cancels (cards do not react)")
	view.tap(SaveSlotsView.delete_rect(cards[0], vp).get_center())
	flow.go_back()
	_check(flow.get_slot_confirm().is_empty() and flow.get_phase() == GameFlow.Phase.SAVE_SLOTS and FileAccess.file_exists(slots.slot_path(0)), "Back cancels the delete, screen stays")
	view.tap(SaveSlotsView.delete_rect(cards[0], vp).get_center())
	view.tap(SaveSlotsView.confirm_button_rects(vp)[1].get_center())
	_check(flow.get_slot_confirm().is_empty() and FileAccess.file_exists(slots.slot_path(0)), "'Hủy' keeps the file")
	view.tap(SaveSlotsView.delete_rect(cards[0], vp).get_center())
	view.tap(SaveSlotsView.confirm_button_rects(vp)[0].get_center())
	_check(not FileAccess.file_exists(slots.slot_path(0)) and not flow.has_continue() and flow.get_progress().get_best_floor() == 0,
		"'Xóa' confirmed: slot_1.json gone, the active progress is empty")
	_check(str(flow.slot_summary(0)["action"]) == GameFlow.SLOT_ACTION_NEW, "slot 1 card is empty again")
	flow.close_save_slots()
	_check(not title._button_labels().has(TitleView.TEXT_CONTINUE) and title._button_labels()[0] == TitleView.TEXT_PLAY, "no save left: the title hides 'Tiếp tục'")

	# --- A corrupt slot never crashes; kept as .bad; opens a new game.
	ProgressStore.write_atomic(slots.slot_path(2), "{this is not a save")
	flow.title_continue()
	var s2: Dictionary = flow.slot_summary(2)
	_check(int(s2["status"]) == SaveSlots.Status.CORRUPT and str(s2["action"]) == GameFlow.SLOT_ACTION_REDO, "slot 3 card: damaged save, start over")
	await _frames(SETTLE_FRAMES)
	_check(flow.get_phase() == GameFlow.Phase.SAVE_SLOTS, "the slot screen draws a corrupt slot without crashing")
	view.tap(SaveSlotsView.primary_rect(cards[2], vp).get_center())
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_active_slot() == 2 and not flow.has_continue(), "'Làm lại' -> character select on slot 3")
	_check(_file_text(slots.slot_path(2) + SaveSlots.BAD_SUFFIX) == "{this is not a save" and not FileAccess.file_exists(slots.slot_path(2)), "the bad bytes are kept as slot_3.json.bad")

	# --- Locale goes to the settings, not into the slot.
	flow.show_title()
	flow.set_locale("en")
	_check(SettingsStore.new(settings_path).get_locale() == "en" and not FileAccess.file_exists(slots.slot_path(2)), "set_locale writes the settings only")
	flow.set_locale("vi")
	await _drop_main(main)

	# --- A fresh flow reopens the last used slot.
	var store3: ProgressStore = slots.store_for(2)
	var p3 := ProgressState.new()
	p3.record_floor(5)
	store3.save_state(p3)
	var main2: Node = await _new_main(slots, SettingsStore.new(settings_path))
	var flow2: GameFlow = main2.get_node("GameFlow") as GameFlow
	_check(flow2.get_active_slot() == 2 and flow2.get_progress().get_best_floor() == 5 and flow2.get_locale() == "vi", "a new session opens slot 3 (last used) in vi")
	await _drop_main(main2)

	_remove_tree(_tmp)
	_check(not DirAccess.dir_exists_absolute(_tmp), "temp folder removed")
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)
