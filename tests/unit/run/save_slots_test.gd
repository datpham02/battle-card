extends SceneTree
## Save slots (user 2026-11-07): SaveSlots on the memory back end (nothing touches the disk). Covers: three empty
## slots; a slot store writes / reads its own file and stamps saved_at from its clock; summaries (run, progress
## without a run, play time banked from finished runs); delete; corrupt files (bad JSON, not an object, unknown
## version) are CORRUPT, load as an empty state and are set aside as .bad (never crash); the legacy progress
## migrates into slot 1 once (old file kept as .bak, its locale moves to the settings); format helpers;
## SettingsStore.memory keeps locale / last slot without a file; a six-button title column would stay touch-sized.
## Run: godot --headless --path . -s res://tests/unit/run/save_slots_test.gd   Prints PASS/FAIL lines and FAILS=n.

const FIXED_TIME: int = 1793000000
const RUN_SEED: int = 4242
const RUN_ELAPSED: float = 125.0
const BANKED: float = 3600.0
const MIN_TOUCH_PX: float = 64.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _run_session(config: ChaptersConfig, character_id: String, seed_value: int) -> RunSession:
	var characters := CharacterConfig.load_from_file()
	var s: RunSession = RunSession.begin_world(config, characters.get_character(character_id), seed_value, 0)
	s.elapsed_sec = RUN_ELAPSED
	return s


func _initialize() -> void:
	var config: ChaptersConfig = ChaptersConfig.load_from_file()
	var cid: String = CharacterConfig.load_from_file().default_id()

	# --- Empty slots.
	var slots: SaveSlots = SaveSlots.memory()
	var all_empty: bool = true
	for i: int in SaveSlots.SLOT_COUNT:
		all_empty = all_empty and slots.status(i) == SaveSlots.Status.EMPTY and not slots.has_file(i)
	_check("three fixed slots, all empty at first", SaveSlots.SLOT_COUNT == 3 and all_empty)
	_check("slot paths are user://saves/slot_N.json", slots.slot_path(0) == "user://saves/slot_1.json" and slots.slot_path(2) == "user://saves/slot_3.json")
	_check("bad indexes are rejected", not SaveSlots.is_valid_index(-1) and not SaveSlots.is_valid_index(3) and not slots.has_file(5) and not slots.delete_slot(7))
	var empty_sum: Dictionary = slots.summary(1)
	_check("empty summary", int(empty_sum["status"]) == SaveSlots.Status.EMPTY and not bool(empty_sum["has_run"]) and float(empty_sum["play_time_sec"]) == 0.0)

	# --- Write / read a slot through its store; saved_at from the clock.
	var store: ProgressStore = slots.store_for(0)
	store.clock = func() -> int: return FIXED_TIME
	var state := ProgressState.new()
	state.record_floor(3)
	state.set_run(_run_session(config, cid, RUN_SEED))
	_check("save into slot 1", store.save_state(state))
	_check("slot 1 OK, others still empty", slots.status(0) == SaveSlots.Status.OK and slots.status(1) == SaveSlots.Status.EMPTY and slots.status(2) == SaveSlots.Status.EMPTY)
	var back: ProgressState = slots.store_for(0).load_state(config)
	_check("slot 1 reloads its run and stamp", back.has_run() and back.get_best_floor() == 3 and back.get_saved_at() == FIXED_TIME)
	var sum: Dictionary = slots.summary(0)
	_check("run summary: character, floor 1, play time = run clock, saved_at",
		bool(sum["has_run"]) and str(sum["character_id"]) == cid and int(sum["floor"]) == 1
		and is_equal_approx(float(sum["play_time_sec"]), RUN_ELAPSED) and int(sum["saved_at"]) == FIXED_TIME, str(sum))

	# --- Play time: a finished run is banked; a new run (other seed) banks the old one too.
	var p := ProgressState.new()
	p.add_play_time(BANKED)
	p.set_run(_run_session(config, cid, RUN_SEED))
	p.set_run(_run_session(config, cid, RUN_SEED)) # same run saved again: not banked twice
	_check("same run re-saved is not banked twice", is_equal_approx(p.get_play_time_sec(), BANKED + RUN_ELAPSED))
	p.set_run(_run_session(config, cid, RUN_SEED + 1))
	_check("a new run banks the replaced one", is_equal_approx(p.get_play_time_sec(), BANKED + RUN_ELAPSED * 2.0))
	p.clear_run()
	_check("clear_run banks the run clock", is_equal_approx(p.get_play_time_sec(), BANKED + RUN_ELAPSED * 2.0) and not p.has_run())
	var p2: ProgressState = ProgressState.from_json(p.to_json())
	_check("play time and saved_at round-trip", is_equal_approx(p2.get_play_time_sec(), p.get_play_time_sec()) and p2.get_saved_at() == p.get_saved_at())
	_check("ProgressState stays version 8 (optional keys)", ProgressState.VERSION == 8 and int(JSON.parse_string(p.to_json())["version"]) == 8)
	var no_run := ProgressState.new()
	no_run.record_floor(4)
	slots.store_for(1).save_state(no_run)
	var sum2: Dictionary = slots.summary(1)
	_check("progress without a run: no character, best floor kept", int(sum2["status"]) == SaveSlots.Status.OK and not bool(sum2["has_run"])
		and str(sum2["character_id"]).is_empty() and int(sum2["best_floor"]) == 4)

	# --- Delete.
	_check("delete slot 2", slots.delete_slot(1) and slots.status(1) == SaveSlots.Status.EMPTY and slots.status(0) == SaveSlots.Status.OK)
	_check("deleting an empty slot is fine", slots.delete_slot(1))

	# --- Corrupt files never crash.
	for bad: String in ["{not json", "[1, 2, 3]", "{\"version\": 99}", "   "]:
		slots.memory_put(slots.slot_path(2), bad)
		var st: SaveSlots.Status = slots.status(2)
		var loaded: ProgressState = slots.load_state(2, config)
		var corrupt_sum: Dictionary = slots.summary(2)
		_check("corrupt '%s' is CORRUPT, loads empty, summary empty" % bad, st == SaveSlots.Status.CORRUPT and not loaded.has_run()
			and int(corrupt_sum["status"]) == SaveSlots.Status.CORRUPT and not bool(corrupt_sum["has_run"]))
	slots.memory_put(slots.slot_path(2), "{broken")
	_check("quarantine moves the bad file to .bad", slots.quarantine_if_corrupt(2) and slots.status(2) == SaveSlots.Status.EMPTY
		and slots.memory_get(slots.slot_path(2) + SaveSlots.BAD_SUFFIX) == "{broken")
	_check("quarantine leaves a good slot alone", not slots.quarantine_if_corrupt(0) and slots.status(0) == SaveSlots.Status.OK)
	_check("is_valid_text accepts a real save", SaveSlots.is_valid_text(ProgressState.new().to_json()))

	# --- Legacy migration.
	var mig: SaveSlots = SaveSlots.memory()
	var legacy := ProgressState.new()
	legacy.set_locale("vi")
	legacy.record_floor(2)
	var legacy_text: String = legacy.to_json()
	mig.memory_put(mig.legacy_path, legacy_text)
	var settings: SettingsStore = SettingsStore.memory()
	settings.set_last_slot(2)
	var locale: String = mig.migrate_legacy(settings)
	_check("legacy progress becomes slot 1", mig.status(0) == SaveSlots.Status.OK and mig.load_state(0).get_best_floor() == 2)
	_check("legacy file kept as .bak", mig.memory_get(mig.legacy_path).is_empty() and mig.memory_get(mig.legacy_path + SaveSlots.LEGACY_BACKUP_SUFFIX) == legacy_text)
	_check("legacy locale moves to the settings, slot 1 active", locale == "vi" and settings.get_locale() == "vi" and settings.get_last_slot() == 0)
	mig.memory_put(mig.legacy_path, "{\"version\": 8, \"locale\": \"en\"}")
	_check("no second migration over an existing slot 1", mig.migrate_legacy(settings).is_empty() and mig.load_state(0).get_best_floor() == 2 and settings.get_locale() == "vi")
	var mig2: SaveSlots = SaveSlots.memory()
	var s2: SettingsStore = SettingsStore.memory()
	s2.set_locale("en")
	mig2.memory_put(mig2.legacy_path, legacy_text)
	mig2.migrate_legacy(s2)
	_check("a locale already in the settings wins", s2.get_locale() == "en")
	var mig3: SaveSlots = SaveSlots.memory()
	mig3.memory_put(mig3.legacy_path, "{garbage")
	mig3.migrate_legacy(null)
	_check("a corrupt legacy file is copied as is (kept, shown CORRUPT)", mig3.status(0) == SaveSlots.Status.CORRUPT)
	_check("nothing to migrate = no-op", SaveSlots.memory().migrate_legacy(SettingsStore.memory()).is_empty())

	# --- Formats.
	_check("play time h:mm:ss", SaveSlots.format_play_time(3725.9) == "1:02:05" and SaveSlots.format_play_time(-4.0) == "0:00:00")
	_check("saved at vi d/m/y, en y-m-d, never empty", SaveSlots.format_saved_at(FIXED_TIME, 0, "vi") == "26/10/2026 07:33"
		and SaveSlots.format_saved_at(FIXED_TIME, 420, "en") == "2026-10-26 14:33" and SaveSlots.format_saved_at(0, 0, "vi").is_empty(),
		SaveSlots.format_saved_at(FIXED_TIME, 0, "vi"))

	# --- Settings in memory (locale, last slot) never need a file.
	var mem: SettingsStore = SettingsStore.memory()
	mem.set_locale("vi")
	mem.set_last_slot(-3)
	_check("memory settings keep locale and clamp last slot", mem.get_locale() == "vi" and mem.get_last_slot() == 0 and mem.save_file() and not mem.load_file())

	# --- Title column: even six buttons stay touch-sized on screen, clear of the language button.
	for vp: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 768)]:
		var rects: Array[Rect2] = ScreenLayout.title_button_rects(vp, 6)
		var ok: bool = rects.size() == 6 and rects[0].position.y >= 0.0 and rects[-1].end.y <= vp.y
		for r: Rect2 in rects:
			ok = ok and r.size.y >= MIN_TOUCH_PX * vp.y / 720.0 - 0.5 and not r.intersects(ScreenLayout.title_lang_button_rect(vp))
		_check("six title buttons fit at %s" % str(vp), ok, str(rects))
	_check("five buttons keep the old layout", is_equal_approx(ScreenLayout.title_button_rects(Vector2(1280, 720), 5)[0].position.y, 720.0 * ScreenLayout.TITLE_BUTTONS_TOP_RATIO))

	# --- Slot screen layout: cards apart and on screen, buttons inside, back clear.
	var v := Vector2(1280, 720)
	var cards: Array[Rect2] = SaveSlotsView.card_rects(v)
	var lay: bool = cards.size() == SaveSlots.SLOT_COUNT
	for i: int in cards.size():
		lay = lay and cards[i].end.x <= v.x and cards[i].end.y <= v.y and cards[i].encloses(SaveSlotsView.primary_rect(cards[i], v))
		lay = lay and cards[i].encloses(SaveSlotsView.delete_rect(cards[i], v)) and not SaveSlotsView.primary_rect(cards[i], v).intersects(SaveSlotsView.delete_rect(cards[i], v))
		lay = lay and SaveSlotsView.primary_rect(cards[i], v).size.y >= MIN_TOUCH_PX and not cards[i].intersects(SaveSlotsView.back_rect(v))
		if i > 0:
			lay = lay and not cards[i].intersects(cards[i - 1])
	var cb: Array[Rect2] = SaveSlotsView.confirm_button_rects(v)
	lay = lay and SaveSlotsView.confirm_rect(v).encloses(cb[0]) and SaveSlotsView.confirm_rect(v).encloses(cb[1]) and not cb[0].intersects(cb[1])
	_check("slot screen layout fits 1280x720 with touch-sized buttons", lay)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
