class_name GameFlow
extends Node2D
## The thin layer above one run (Story 015): chapters/floors data, the saved progress, the floor
## being played, and ONE RunController child created when a floor is entered and freed when it
## is left. Phases: FLOOR_SELECT (the FloorSelectView child draws and takes taps) and IN_FLOOR
## (the RunController and RunHudView take over). Draws nothing itself. Direct child of Main in
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
##   --seed=N                   force the floor seed (reproducible arenas)
##   --match=, --run=, --demo=, --arena=  (RunController / DemoArgs args) also switch to a memory
##                              store and, without --floor, enter chapter 1 floor 1

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)
## Emitted when the RunController was created (after add_child) or is about to be freed (null).
signal controller_changed(controller: RunController)

enum Phase { FLOOR_SELECT, IN_FLOOR }

const PROGRESS_ARG: String = "--progress="
const FLOOR_ARG: String = "--floor="
const SEED_ARG: String = "--seed="
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
var _phase: Phase = Phase.FLOOR_SELECT
var _controller: RunController = null
var _current: Vector2i = NO_FLOOR
var _floor_seed: int = 0
var _dev_seed: int = -1


## Test hook: installs the store BEFORE the node enters the tree (wins over --progress args).
func set_store_for_test(store: ProgressStore) -> void:
	_store = store


## Test hook (scratch flow tests): runs an ad-hoc single-floor RunConfig (the flat format read
## by RunConfig.load_from_file) as a floor outside the chapter list. No progress is written
## (_current stays NO_FLOOR), the floor label is empty, the store is swapped to memory.
func enter_test_floor(run_config: RunConfig) -> RunController:
	_free_controller()
	_store = ProgressStore.memory_store()
	_current = NO_FLOOR
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
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
	for arg: String in args:
		if arg.begins_with(PROGRESS_ARG):
			progress_mode = arg.trim_prefix(PROGRESS_ARG)
		elif arg.begins_with(FLOOR_ARG):
			floor_text = arg.trim_prefix(FLOOR_ARG)
		elif arg.begins_with(SEED_ARG):
			_dev_seed = int(arg.trim_prefix(SEED_ARG)) & ChaptersConfig.SEED_MASK
		else:
			for prefix: String in DEV_RUN_ARGS:
				if arg.begins_with(prefix):
					dev_run = true
	if _store == null:
		_store = _make_store(progress_mode, dev_run)
	_progress = _load_progress(progress_mode)
	if not floor_text.is_empty():
		var resume: bool = floor_text.ends_with(RESUME_SUFFIX)
		var pos: Vector2i = _config.find_floor(floor_text.trim_suffix(RESUME_SUFFIX))
		if pos == NO_FLOOR:
			push_warning("GameFlow: unknown floor '%s' (use e.g. ch1/f2)" % floor_text)
		else:
			enter_floor(pos.x, pos.y, not resume)
	elif dev_run:
		enter_floor(0, 0, true)


## Current [enum Phase].
func get_phase() -> int:
	return _phase


## The chapters/floors data.
func get_config() -> ChaptersConfig:
	return _config


## The saved progress (live object; GameFlow writes it through the store).
func get_progress() -> ProgressState:
	return _progress


## The controller of the floor being played; null in FLOOR_SELECT.
func get_controller() -> RunController:
	return _controller


## (chapter, floor) being played; (-1, -1) in FLOOR_SELECT.
func get_current_floor() -> Vector2i:
	return _current


## Seed of the current floor entry (arena seeds derive from it).
func get_floor_seed() -> int:
	return _floor_seed


## Enters floor (ci, fi). [param from_start] false and the saved in-progress record is this floor
## -> resumes that match (saved seed, HP rule); otherwise match 0 at full HP with a fresh seed
## (or --seed), replacing any in-progress record (confirming that is the view's job). Frees the
## previous controller first. Ignored for an unknown floor.
func enter_floor(ci: int, fi: int, from_start: bool) -> void:
	var key: String = _config.floor_key(ci, fi)
	if key.is_empty():
		push_warning("GameFlow: enter_floor(%d, %d): no such floor" % [ci, fi])
		return
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
	controller.configure(run_config, start_index, hp_at_start)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_FLOOR)
	controller_changed.emit(controller)


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


## The floor after the current one in linear order; (-1, -1) when none or in FLOOR_SELECT.
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
