class_name GameFlow
extends Node2D
## The thin layer above one run (Story 015, Story 016): chapters/floors data, the saved progress, the floor
## being played, and ONE RunController child created when a floor is entered and freed when it
## is left. Phases: TITLE (Story 016, the first screen), CHARACTER_SELECT (Story 018, the
## CharacterSelectView child), FLOOR_SELECT (the FloorSelectView child draws and takes taps) and
## IN_FLOOR (the RunController and RunHudView take over). [method go_back] (Esc, Android back) acts
## per phase: IN_FLOOR toggles the pause, FLOOR_SELECT -> CHARACTER_SELECT, CHARACTER_SELECT ->
## TITLE, TITLE -> quit. App pause / focus loss while IN_FLOOR force-pauses the battle. Draws nothing itself. Direct child of Main in
## main.tscn, in place of the old RunController; RunHudView (a sibling) gets the controller
## through [signal controller_changed].
##
## Progress rules (written through the ProgressStore at once): entering a floor records it as
## in progress (match 0 full HP, or the resumed match); every match that enters PLAYING updates
## the record (match index, HP at match start, floor seed); winning the boss match marks the
## floor cleared and drops the record; leaving a floor (also from the lose screen) keeps it.
##
## DEV-ONLY user args (after "--"):
##   --progress=none|all|demo   memory store (never writes user://progress.json): empty / every
##                              floor unlocked / ch1 floor 1 cleared + floor 2 in progress
##   --floor=ch1/f3[:resume]    skip the floor select and enter that floor from match 1 (or
##                              resume its in-progress match)
##   --title                    show the title even with --progress=... (without it --progress alone starts
##                              at the floor select; no dev arg at all starts at the title)
##   --seed=N                   force the floor seed (reproducible arenas)
##   --lang=vi|en               UI locale for this run only (not saved; captures)
##   --character=<id>           pick the character like the select screen would (Story 018)
##   --select=character         start in CHARACTER_SELECT with a memory store (captures)
##   --match=, --run=, --demo=, --arena=  (RunController / DemoArgs args) also switch to a memory
##                              store and, without --floor, enter chapter 1 floor 1

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)
## Emitted when the RunController was created (after add_child) or is about to be freed (null).
signal controller_changed(controller: RunController)

enum Phase { TITLE, CHARACTER_SELECT, FLOOR_SELECT, IN_FLOOR }

const PROGRESS_ARG: String = "--progress="
const FLOOR_ARG: String = "--floor="
const SEED_ARG: String = "--seed="
const TITLE_ARG: String = "--title"
## DEV-ONLY (Story 018): --character=<id> picks the character like the select screen would.
const CHARACTER_ARG: String = "--character="
## DEV-ONLY: locale override for captures (never saved).
const LANG_ARG: String = "--lang="
## DEV-ONLY (Story 018): --select=character starts in CHARACTER_SELECT (memory store; captures).
const SELECT_ARG: String = "--select="
const SELECT_CHARACTER: String = "character"
## Locales the CSV ships (Story 017); the title button cycles through them in this order.
const SUPPORTED_LOCALES: Array[String] = ["vi", "en"]
## DEV-ONLY: disables the auto-pause on focus loss (windowed scratch tests run unfocused).
const NO_AUTOPAUSE_ARG: String = "--no-autopause"
## Platforms without a Quit button (Apple rules): [method can_show_quit] is false there.
const NO_QUIT_OS_NAMES: Array[String] = ["iOS"]
const RESUME_SUFFIX: String = ":resume"
const PROGRESS_NONE: String = "none"
const PROGRESS_ALL: String = "all"
const PROGRESS_DEMO: String = "demo"
## Dev args that put the game into a capture state; they always get a memory store.
const DEV_RUN_ARGS: Array[String] = ["--match=", "--run=", "--demo=", "--arena="]
const CONTROLLER_NODE: String = "RunController"
## DEV-ONLY (--progress=demo): linear floor indices and the in-progress record of the demo save.
const DEMO_CLEARED_LINEAR: int = 0
const DEMO_IN_PROGRESS_LINEAR: int = 1
const DEMO_IN_PROGRESS_MATCH: int = 2
const DEMO_IN_PROGRESS_HP: float = 30.0
const DEMO_IN_PROGRESS_SEED: int = 7
const NO_FLOOR: Vector2i = Vector2i(-1, -1)

var _config: ChaptersConfig
var _store: ProgressStore = null
var _progress: ProgressState
var _phase: Phase = Phase.TITLE
var _controller: RunController = null
var _current: Vector2i = NO_FLOOR
var _floor_seed: int = 0
var _dev_seed: int = -1
## DEV-ONLY: true with --no-autopause (see [constant NO_AUTOPAUSE_ARG]).
var _no_autopause: bool = false
## Locale in use (always one of SUPPORTED_LOCALES).
var _locale: String = ProgressState.DEFAULT_LOCALE
## DEV-ONLY: --lang= value ("" = use the save).
var _dev_locale: String = ""
## Selected character id (Story 018). Set by [method set_character] (the select screen, or
## --character=<id>); every floor gets its dictionary and starter deck. Empty = none chosen yet:
## [method enter_floor] then falls back to CharacterConfig.default_id() (continue from the title,
## --progress= / --run= / --demo= captures), so a floor is never character-less — only
## [method enter_test_floor] passes {} (plain combat.json numbers for the old tests).
var _character_id: String = ""
var _characters: CharacterConfig = null
## DEV-ONLY: --character= value, applied in _ready.
var _dev_character: String = ""


## Test hook: installs the store BEFORE the node enters the tree (wins over --progress args).
func set_store_for_test(store: ProgressStore) -> void:
	_store = store


## Test hook (scratch flow tests): runs an ad-hoc single-floor RunConfig (the flat format read
## by RunConfig.load_from_file) as a floor outside the chapter list. No progress is written
## (_current stays NO_FLOOR, so the progress callbacks return early); the floor label is empty;
## the store installed by [method set_store_for_test] (or the real one) is left untouched.
func enter_test_floor(run_config: RunConfig) -> RunController:
	_free_controller()
	_current = NO_FLOOR
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.character = _character_dict()
	controller.configure(run_config, 0, -1.0)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_FLOOR)
	controller_changed.emit(controller)
	return controller


func _ready() -> void:
	_config = ChaptersConfig.load_from_file()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var progress_mode: String = ""
	var floor_text: String = ""
	var dev_run: bool = false
	var force_title: bool = false
	var select_mode: String = ""
	for arg: String in args:
		if arg == TITLE_ARG:
			force_title = true
		elif arg.begins_with(SELECT_ARG):
			select_mode = arg.trim_prefix(SELECT_ARG)
		elif arg == NO_AUTOPAUSE_ARG:
			_no_autopause = true
		elif arg.begins_with(PROGRESS_ARG):
			progress_mode = arg.trim_prefix(PROGRESS_ARG)
		elif arg.begins_with(FLOOR_ARG):
			floor_text = arg.trim_prefix(FLOOR_ARG)
		elif arg.begins_with(SEED_ARG):
			_dev_seed = int(arg.trim_prefix(SEED_ARG)) & ChaptersConfig.SEED_MASK
		elif arg.begins_with(LANG_ARG):
			_dev_locale = arg.trim_prefix(LANG_ARG)
		elif arg.begins_with(CHARACTER_ARG):
			_dev_character = arg.trim_prefix(CHARACTER_ARG)
		else:
			for prefix: String in DEV_RUN_ARGS:
				if arg.begins_with(prefix):
					dev_run = true
	if not select_mode.is_empty() and select_mode != SELECT_CHARACTER:
		push_warning("GameFlow: unknown --select=%s (character), ignored" % select_mode)
		select_mode = ""
	if _store == null:
		_store = _make_store(progress_mode, dev_run or not select_mode.is_empty())
	_progress = _load_progress(progress_mode)
	# Locale before anything draws or caches a translated name (floor_label below).
	_apply_locale(_dev_locale if SUPPORTED_LOCALES.has(_dev_locale) else _progress.get_locale())
	if not _dev_character.is_empty():
		set_character(_dev_character)
	# Start phase: TITLE without dev args (or with --title); --progress alone -> FLOOR_SELECT;
	# --select=character -> CHARACTER_SELECT.
	_phase = Phase.TITLE
	if select_mode == SELECT_CHARACTER:
		_phase = Phase.CHARACTER_SELECT
	elif not progress_mode.is_empty() and not force_title:
		_phase = Phase.FLOOR_SELECT
	if not floor_text.is_empty():
		var resume: bool = floor_text.ends_with(RESUME_SUFFIX)
		var pos: Vector2i = _config.find_floor(floor_text.trim_suffix(RESUME_SUFFIX))
		if pos == NO_FLOOR:
			push_warning("GameFlow: unknown floor '%s' (use e.g. ch1/f2)" % floor_text)
		else:
			enter_floor(pos.x, pos.y, not resume)
	elif dev_run:
		enter_floor(0, 0, true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _phase == Phase.IN_FLOOR and _controller != null and not _no_autopause:
				_controller.set_paused(true, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		go_back()


## Story 018: the character list (loaded once, lazily).
func get_characters() -> CharacterConfig:
	if _characters == null:
		_characters = CharacterConfig.load_from_file()
	return _characters


## Story 018: selects the character for the next floors. Unknown id: warning, selection unchanged.
## An empty id clears the selection (back to the plain, character-less match).
func set_character(id: String) -> void:
	if id.is_empty():
		_character_id = ""
		return
	if not get_characters().has(id):
		push_warning("GameFlow: unknown character '%s' (known: %s), ignored" % [id, ", ".join(get_characters().ids())])
		return
	_character_id = id


## Story 018: the selected character id; "" when none was chosen.
func get_character_id() -> String:
	return _character_id


# The selected character's dictionary for the controller; {} when none was chosen.
func _character_dict() -> Dictionary:
	if _character_id.is_empty():
		return {}
	return get_characters().get_character(_character_id)


## Current [enum Phase].
func get_phase() -> int:
	return _phase


## The chapters/floors data.
func get_config() -> ChaptersConfig:
	return _config


## The saved progress (live object; GameFlow writes it through the store).
func get_progress() -> ProgressState:
	return _progress


## The controller of the floor being played; null outside IN_FLOOR.
func get_controller() -> RunController:
	return _controller


## (chapter, floor) being played; (-1, -1) outside IN_FLOOR.
func get_current_floor() -> Vector2i:
	return _current


## Seed of the current floor entry (arena seeds derive from it).
func get_floor_seed() -> int:
	return _floor_seed


## Enters floor (ci, fi). [param from_start] false and the saved in-progress record is this floor
## -> resumes that match (saved seed, HP rule); otherwise match 0 at full HP with a fresh seed
## (or --seed), replacing any in-progress record (confirming that is the view's job). Frees the
## previous controller first. Ignored for an unknown floor. Story 018: when no character was chosen
## (continue from the title, --progress= / dev-run captures) the default character is selected first.
func enter_floor(ci: int, fi: int, from_start: bool) -> void:
	var key: String = _config.floor_key(ci, fi)
	if key.is_empty():
		push_warning("GameFlow: enter_floor(%d, %d): no such floor" % [ci, fi])
		return
	if _character_id.is_empty():
		set_character(get_characters().default_id())
	_free_controller()
	var saved: Dictionary = _progress.get_in_progress()
	var start_index: int = 0
	var hp_at_start: float = -1.0
	if not from_start and not saved.is_empty() and str(saved["floor"]) == key:
		_floor_seed = int(saved["floor_seed"])
		start_index = int(saved["match_index"])
		hp_at_start = float(saved["hp_at_match_start"])
	else:
		_floor_seed = _dev_seed if _dev_seed >= 0 else randi() & ChaptersConfig.SEED_MASK
	_current = Vector2i(ci, fi)
	_progress.set_in_progress(key, start_index, hp_at_start, _floor_seed)
	_store.save_state(_progress)
	var run_config: RunConfig = RunConfig.from_floor(_config.resolved_floor(ci, fi, _floor_seed), _config.defaults())
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.floor_label = _config.floor_name(ci, fi)
	controller.character = _character_dict()
	controller.configure(run_config, start_index, hp_at_start)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_FLOOR)
	controller_changed.emit(controller)


## Story 016: shows the title screen; frees the controller if a floor was running (the progress
## is not changed).
func show_title() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.TITLE)


## Story 016: shows the floor select; frees the controller if a floor was running.
func show_floor_select() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.FLOOR_SELECT)


## Story 018: shows the character select; frees the controller if a floor was running.
func show_character_select() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.CHARACTER_SELECT)


## Story 018: the select screen's tap on card [param id]: selects it and moves on to the floor
## select. An unknown id (warning from [method set_character]) changes nothing.
func character_chosen(id: String) -> void:
	set_character(id)
	if not id.is_empty() and _character_id == id:
		show_floor_select()


## Story 018: floor select "Về": back to the character select (the selection is kept, so the
## cards can be re-read; tapping another card replaces it).
func back_to_character_select() -> void:
	show_character_select()


## Title "Chơi": TITLE -> CHARACTER_SELECT (Story 018). Ignored in other phases.
func start_requested() -> void:
	if _phase == Phase.TITLE:
		show_character_select()


## True when the save has an in-progress record whose floor still exists in the chapters data.
func has_continue() -> bool:
	var saved: Dictionary = _progress.get_in_progress()
	return not saved.is_empty() and _config.find_floor(str(saved["floor"])) != NO_FLOOR


## Title "Tiếp tục": resumes the in-progress floor at its saved match. Ignored without a record.
## Story 018: skips the character select; with no character chosen the floor gets the default one
## (Story 019 saves the character with the run and restores it here).
func continue_requested() -> void:
	if not has_continue():
		return
	var pos: Vector2i = _config.find_floor(str(_progress.get_in_progress()["floor"]))
	enter_floor(pos.x, pos.y, false)


## Title "Thoát": quits the game.
func quit_requested() -> void:
	get_tree().quit()


## Locale in use ("vi" / "en").
func get_locale() -> String:
	return _locale


## The locale after the current one in [constant SUPPORTED_LOCALES] (cyclic).
func next_locale() -> String:
	var index: int = SUPPORTED_LOCALES.find(_locale)
	return SUPPORTED_LOCALES[(index + 1) % SUPPORTED_LOCALES.size()]


## Story 017: switches the UI locale (TranslationServer), stores it in the progress and saves through
## the store. Unknown codes are ignored with a warning. Views draw every frame, so they follow at once;
## RunController.floor_label is cached per floor entry (the title is the only place that switches).
func set_locale(code: String) -> void:
	if not SUPPORTED_LOCALES.has(code):
		push_warning("GameFlow: unsupported locale '%s' (vi|en)" % code)
		return
	_apply_locale(code)
	_progress.set_locale(code)
	_store.save_state(_progress)


## Title VI / EN button: moves to [method next_locale].
func toggle_locale() -> void:
	set_locale(next_locale())


## False on platforms that must not show a Quit button (iOS).
func can_show_quit() -> bool:
	return not NO_QUIT_OS_NAMES.has(OS.get_name())


## Back / Esc by phase: IN_FLOOR toggles the pause (nothing when not pausable), FLOOR_SELECT ->
## CHARACTER_SELECT, CHARACTER_SELECT -> TITLE, TITLE -> quit (not on iOS).
func go_back() -> void:
	match _phase:
		Phase.IN_FLOOR:
			if _controller != null:
				_controller.toggle_pause()
		Phase.FLOOR_SELECT:
			show_character_select()
		Phase.CHARACTER_SELECT:
			show_title()
		Phase.TITLE:
			if can_show_quit():
				quit_requested()


## Back to the floor select; frees the controller. The progress is not changed (a floor left
## from the lose screen stays in progress at the lost match).
func leave_floor() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.FLOOR_SELECT)


## Lose screen "Chơi lại trận": replays the lost match (same seed, HP rule).
func retry_requested() -> void:
	if _controller != null:
		_controller.retry_match()


## Floor-clear screen "Tầng tiếp": enters the next floor from match 1 when it exists and is
## unlocked (it is, right after the boss win). Ignored otherwise.
func next_floor_requested() -> void:
	var next: Vector2i = get_next_floor()
	if next == NO_FLOOR or not _progress.is_unlocked(_config, next.x, next.y):
		return
	enter_floor(next.x, next.y, true)


## The floor after the current one in linear order; (-1, -1) when none or outside IN_FLOOR.
func get_next_floor() -> Vector2i:
	if _current == NO_FLOOR:
		return NO_FLOOR
	return _config.next_floor(_current.x, _current.y)


func _free_controller() -> void:
	if _controller == null:
		return
	var old: RunController = _controller
	_controller = null
	controller_changed.emit(null)
	remove_child(old)
	old.queue_free()


func _set_phase(phase: Phase) -> void:
	_phase = phase
	phase_changed.emit(phase)


func _on_match_started(match_index: int, hp_at_match_start: float) -> void:
	if _current == NO_FLOOR:
		return
	_progress.set_in_progress(_config.floor_key(_current.x, _current.y), match_index, hp_at_match_start, _floor_seed)
	_store.save_state(_progress)


func _on_run_phase_changed(phase: int) -> void:
	if phase != RunState.Phase.WON or _current == NO_FLOOR:
		return
	_progress.mark_cleared(_config.floor_key(_current.x, _current.y))
	_store.save_state(_progress)


# Sets the TranslationServer locale; an unsupported code (old or edited save) falls back to the default.
func _apply_locale(code: String) -> void:
	_locale = code if SUPPORTED_LOCALES.has(code) else ProgressState.DEFAULT_LOCALE
	TranslationServer.set_locale(_locale)


func _make_store(progress_mode: String, dev_run: bool) -> ProgressStore:
	if dev_run or not progress_mode.is_empty():
		return ProgressStore.memory_store()
	return ProgressStore.new()


func _load_progress(progress_mode: String) -> ProgressState:
	match progress_mode:
		PROGRESS_ALL:
			return ProgressState.unlocked_everything(_config)
		PROGRESS_DEMO:
			var state := ProgressState.new()
			var cleared: Vector2i = _config.floor_at_linear(DEMO_CLEARED_LINEAR)
			var playing: Vector2i = _config.floor_at_linear(DEMO_IN_PROGRESS_LINEAR)
			state.mark_cleared(_config.floor_key(cleared.x, cleared.y))
			if playing != NO_FLOOR:
				var match_index: int = mini(DEMO_IN_PROGRESS_MATCH, _config.match_count(playing.x, playing.y) - 1)
				state.set_in_progress(_config.floor_key(playing.x, playing.y), match_index, DEMO_IN_PROGRESS_HP, DEMO_IN_PROGRESS_SEED)
			return state
		_:
			if progress_mode != PROGRESS_NONE and not progress_mode.is_empty():
				push_warning("GameFlow: unknown --progress=%s (none|all|demo), starting empty" % progress_mode)
			return _store.load_state(_config)
