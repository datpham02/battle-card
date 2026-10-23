class_name GameFlow
extends Node2D
## The thin layer above one roguelike RUN (Story 015, 016, 018, 019): chapters/floors data, the
## saved progress, ONE [RunSession] while a run is live and ONE RunController child per floor of
## that run (created when the floor is entered, freed when it is left). Phases: TITLE (the first
## screen), CHARACTER_SELECT (CharacterSelectView), CHAPTER_SELECT (the chapter select view) and
## IN_FLOOR (the RunController plus the run screens take over). [method go_back] (Esc, Android
## back) acts per phase: IN_FLOOR toggles the pause (or leaves a finished run), CHAPTER_SELECT ->
## CHARACTER_SELECT, CHARACTER_SELECT -> TITLE, TITLE -> quit. App pause / focus loss while
## IN_FLOOR force-pauses the battle. Draws nothing itself. Direct child of Main in main.tscn;
## RunHudView (a sibling) gets the controller through [signal controller_changed].
##
## Run rules (Story 019, design/game-brief.md v4 "Run"): title -> character -> chapter ->
## [method start_run]: a RunSession (character, deck, chapter/floor/match, HP, seed) is saved at
## once and the first floor is entered. Every match that enters PLAYING saves the run (match,
## HP at match start, clock). A WON match (controller phase BETWEEN, or WON for the floor boss)
## heals per RunSession.apply_match_won and either ends the run (last floor's boss: the chapter
## is marked cleared, the saved run is dropped, [method get_run_result] = WON) or rolls a card
## offer ([method get_pending_reward]); the flow then WAITS for the view's
## [method reward_chosen] / [method reward_skipped] before the next match (same floor: the
## controller advances with the grown deck) or the next floor (a new controller). RunConfig
## between_sec is forced to 0 on run floors: the reward screen gates the advance, never a timer.
## Death (controller phase LOST) drops the saved run at once ([method get_run_result] = LOST);
## there is no retry. [method leave_run] (the one button of the result screens) frees everything
## and shows the title.
##
## Leaving mid-run ([method leave_floor], the pause menu button): the controller is freed, the
## run stays saved at the current match (HP at match start) and the title shows "Tiếp tục";
## death is the only thing that clears a run in progress (besides winning it).
## Resume with an unresolved offer ([method continue_requested] on a save whose pending_reward is
## not empty): the floor is spawned at the CURRENT match (already advanced when the offer was
## rolled), the controller is held in INTRO (RunController.hold_intro, battle frozen, timer not
## ticking) and the offer is exposed again; resolving it releases the intro (a chosen card
## respawns the match so the battle reads the grown deck).
##
## DEV-ONLY user args (after "--"):
##   --progress=none|all|demo   memory store (never writes user://progress.json): empty / every
##                              chapter but the last cleared / chapter 1 cleared plus a saved run
##                              in chapter 1 floor 2 match 2 (9 cards, HP 57, no pending offer)
##   --floor=ch1/f3             skip the menus and enter that floor as a throwaway run of the
##                              default character (memory store; a legacy ":resume" suffix is
##                              ignored)
##   --title                    show the title even with --progress=... (without it --progress alone
##                              starts at the chapter select; no dev arg at all starts at the title)
##   --seed=N                   force the run seed (reproducible arenas and offers)
##   --lang=vi|en               UI locale for this run only (not saved; captures)
##   --character=<id>           pick the character like the select screen would (Story 018)
##   --select=character         start in CHARACTER_SELECT with a memory store (captures)
##   --run=reward|runover|runwon  run states for captures: the card offer after match 1 of ch1/f1
##                              (HP 70), the RUN KẾT THÚC result, the RUN THẮNG result
##   --match=, --run=intro|between|won|lost, --demo=, --arena=  (RunController / DemoArgs args) also
##                              switch to a memory store and, without --floor, start a run in chapter 1

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)
## Emitted when the RunController was created (after add_child) or is about to be freed (null).
signal controller_changed(controller: RunController)
## Story 019: emitted when the run's screen-relevant state changed: an offer appeared or was
## resolved, the run ended (WON / LOST), a run was left or resumed. Views may also poll the getters.
signal run_changed()

enum Phase { TITLE, CHARACTER_SELECT, CHAPTER_SELECT, IN_FLOOR }
## Story 019: how the live run ended; NONE while it is still going (or when there is none).
enum RunResult { NONE, WON, LOST }

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
## DEV-ONLY (Story 019): --run=<kind> values handled HERE (the others belong to RunController).
const RUN_ARG: String = "--run="
const FLOW_RUN_REWARD: String = "reward"
const FLOW_RUN_OVER: String = "runover"
const FLOW_RUN_WON: String = "runwon"
const FLOW_RUN_KINDS: Array[String] = [FLOW_RUN_REWARD, FLOW_RUN_OVER, FLOW_RUN_WON]
## DEV-ONLY: player HP the --run=reward / --run=runwon captures end the match with.
const DEV_FLOW_HP: float = 70.0
## Locales the CSV ships (Story 017); the title button cycles through them in this order.
const SUPPORTED_LOCALES: Array[String] = ["vi", "en"]
## DEV-ONLY: disables the auto-pause on focus loss (windowed scratch tests run unfocused).
const NO_AUTOPAUSE_ARG: String = "--no-autopause"
## Platforms without a Quit button (Apple rules): [method can_show_quit] is false there.
const NO_QUIT_OS_NAMES: Array[String] = ["iOS"]
## Legacy --floor suffix (Story 015); accepted and ignored.
const RESUME_SUFFIX: String = ":resume"
const PROGRESS_NONE: String = "none"
const PROGRESS_ALL: String = "all"
const PROGRESS_DEMO: String = "demo"
## Dev args that put the game into a capture state; they always get a memory store.
const DEV_RUN_ARGS: Array[String] = ["--match=", "--run=", "--demo=", "--arena="]
const CONTROLLER_NODE: String = "RunController"
## DEV-ONLY (--progress=demo): the saved demo run (chapter 0; floor / match 0-based).
const DEMO_RUN_FLOOR: int = 1
const DEMO_RUN_MATCH: int = 1
const DEMO_RUN_HP: float = 57.0
const DEMO_RUN_SEED: int = 7
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
## Selected character id (Story 018). Set by [method set_character] (the select screen, --character=,
## or the saved run on continue). Empty = none chosen yet: [method start_run] then falls back to
## CharacterConfig.default_id(), so a run is never character-less — only [method enter_test_floor]
## passes {} (plain combat.json numbers for the old tests).
var _character_id: String = ""
var _characters: CharacterConfig = null
var _cards: SkillConfig = null
var _reward_config: Dictionary = {}
## DEV-ONLY: --character= value, applied in _ready.
var _dev_character: String = ""
## Story 019: the live run; null outside a run (title, menus, test floors).
var _run: RunSession = null
var _run_result: RunResult = RunResult.NONE
## Story 019: true while a resumed run waits for its saved offer (controller held in INTRO).
var _reward_blocking: bool = false
## Run clock at the entry of the current floor (the controller's RunState clock starts at 0).
var _elapsed_base: float = 0.0


## Test hook: installs the store BEFORE the node enters the tree (wins over --progress args).
func set_store_for_test(store: ProgressStore) -> void:
	_store = store


## Test hook (scratch flow tests): runs an ad-hoc single-floor RunConfig (the flat format read
## by RunConfig.load_from_file) as a floor outside any run. No progress is written and no run
## exists (the run callbacks return early); the floor label is empty; the store installed by
## [method set_store_for_test] (or the real one) is left untouched.
func enter_test_floor(run_config: RunConfig) -> RunController:
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
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
	var flow_run: String = ""
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
			if arg.begins_with(RUN_ARG) and FLOW_RUN_KINDS.has(arg.trim_prefix(RUN_ARG)):
				flow_run = arg.trim_prefix(RUN_ARG)
			for prefix: String in DEV_RUN_ARGS:
				if arg.begins_with(prefix):
					dev_run = true
	if not select_mode.is_empty() and select_mode != SELECT_CHARACTER:
		push_warning("GameFlow: unknown --select=%s (character), ignored" % select_mode)
		select_mode = ""
	if _store == null:
		_store = _make_store(progress_mode, dev_run or not select_mode.is_empty() or not floor_text.is_empty())
	_progress = _load_progress(progress_mode)
	# Locale before anything draws or caches a translated name (floor_label below).
	_apply_locale(_dev_locale if SUPPORTED_LOCALES.has(_dev_locale) else _progress.get_locale())
	if not _dev_character.is_empty():
		set_character(_dev_character)
	# Start phase: TITLE without dev args (or with --title); --progress alone -> CHAPTER_SELECT;
	# --select=character -> CHARACTER_SELECT.
	_phase = Phase.TITLE
	if select_mode == SELECT_CHARACTER:
		_phase = Phase.CHARACTER_SELECT
	elif not progress_mode.is_empty() and not force_title:
		_phase = Phase.CHAPTER_SELECT
	if not floor_text.is_empty():
		var pos: Vector2i = _config.find_floor(floor_text.trim_suffix(RESUME_SUFFIX))
		if pos == NO_FLOOR:
			push_warning("GameFlow: unknown floor '%s' (use e.g. ch1/f2)" % floor_text)
		else:
			_begin_run(pos.x, pos.y)
	elif dev_run:
		_begin_run(0, 0)
	if not flow_run.is_empty() and _run != null:
		_apply_dev_flow_run(flow_run)


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


## Story 019: the card list (cards.json; loaded once, lazily). Reward pool and save validation.
func get_cards() -> SkillConfig:
	if _cards == null:
		_cards = SkillConfig.load_from_file()
	return _cards


## Story 019: the validated rewards.json dictionary (offer_count, rarity_weights, allow_skip,
## allow_remove, min_deck_size, max_card_level, offer_upgrades, pool_excludes_defaults); loaded once, lazily. The reward view reads allow_skip.
func get_reward_config() -> Dictionary:
	if _reward_config.is_empty():
		_reward_config = RewardRoller.load_config()
	return _reward_config.duplicate(true)


## Story 018: selects the character for the next run. Unknown id: warning, selection unchanged.
## An empty id clears the selection (back to the plain, character-less test floor).
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


## Seed of the current floor (RunSession.floor_seed; arena seeds derive from it).
func get_floor_seed() -> int:
	return _floor_seed


## Story 019: the live run (also after it ended, until [method leave_run]); null when none.
func get_run() -> RunSession:
	return _run


## Story 019: how the live run ended; NONE while it is going or when there is no run.
func get_run_result() -> int:
	return _run_result


## Story 019: card ids of the offer waiting for [method reward_chosen] / [method reward_skipped];
## [] when none (no run, or the next match is already going).
func get_pending_reward() -> Array[String]:
	if _run == null:
		return []
	return _run.pending_reward.duplicate()


## Story 019: true while a resumed run holds its match in INTRO until the saved offer is resolved.
func is_reward_blocking() -> bool:
	return _reward_blocking


## Story 019: one entry per chapter, for the chapter select: {index, id, name (translated),
## cleared, unlocked, in_run (the saved run is in this chapter)}.
func get_chapter_states() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var run_chapter: String = str(_progress.get_run_dict().get("chapter", ""))
	for ci: int in _config.chapter_count():
		var id: String = _config.chapter_id(ci)
		out.append({
			"index": ci, "id": id, "name": _config.chapter_name(ci),
			"cleared": _progress.is_chapter_cleared(id),
			"unlocked": _progress.is_chapter_unlocked(_config, ci),
			"in_run": not run_chapter.is_empty() and run_chapter == id,
		})
	return out


## Story 019: starts a run of the selected character in chapter [param ci] (floor 1, match 1, full
## HP, starter deck; any saved run is replaced — confirming that is the view's job). Refused with a
## warning for an unknown or locked chapter. With no character chosen the default one is used.
func start_run(ci: int) -> void:
	if _config.chapter_id(ci).is_empty():
		push_warning("GameFlow: start_run(%d): no such chapter" % ci)
		return
	if not _progress.is_chapter_unlocked(_config, ci):
		push_warning("GameFlow: start_run(%d): chapter '%s' is locked" % [ci, _config.chapter_id(ci)])
		return
	_begin_run(ci, 0)


## Deprecated (Story 019; the floor select view until it becomes a chapter select): starts a run
## of the selected character AT floor (ci, fi), like --floor=. [param _from_start] is ignored.
func enter_floor(ci: int, fi: int, _from_start: bool) -> void:
	if _config.floor_key(ci, fi).is_empty():
		push_warning("GameFlow: enter_floor(%d, %d): no such floor" % [ci, fi])
		return
	_begin_run(ci, fi)


## Story 016: shows the title screen; frees the controller if a floor was running. A run that
## already ended is dropped; a run still going stays live and saved (the title offers Continue).
func show_title() -> void:
	_free_controller()
	_current = NO_FLOOR
	if _run_result != RunResult.NONE:
		_run = null
		_run_result = RunResult.NONE
	_reward_blocking = false
	_set_phase(Phase.TITLE)


## Story 019: shows the chapter select; frees the controller if a floor was running.
func show_chapter_select() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.CHAPTER_SELECT)


## Story 018: shows the character select; frees the controller if a floor was running.
func show_character_select() -> void:
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.CHARACTER_SELECT)


## Story 018: the select screen's tap on card [param id]: selects it and moves on to the chapter
## select. An unknown id (warning from [method set_character]) changes nothing.
func character_chosen(id: String) -> void:
	set_character(id)
	if not id.is_empty() and _character_id == id:
		show_chapter_select()


## Story 018: chapter select "Về": back to the character select (the selection is kept, so the
## cards can be re-read; tapping another card replaces it).
func back_to_character_select() -> void:
	show_character_select()


## Title "Chơi": TITLE -> CHARACTER_SELECT (Story 018). Ignored in other phases.
func start_requested() -> void:
	if _phase == Phase.TITLE:
		show_character_select()


## True when the save holds a run in progress (Story 019).
func has_continue() -> bool:
	return _progress.has_run()


## Title "Tiếp tục" / chapter tile of the run in progress: rebuilds the saved run (character, deck,
## position, HP, pending offer) and enters its floor at the saved match. A save that no longer
## fits the data (unknown chapter, floor, character, no known card) is dropped with a warning and
## the title stays. Ignored without a saved run. See the class doc for the pending-offer rule.
func continue_requested() -> void:
	if not has_continue():
		return
	var session: RunSession = RunSession.from_dict(_progress.get_run_dict(), _config, get_cards())
	if session == null or not get_characters().has(session.character_id):
		push_warning("GameFlow: the saved run cannot be resumed, dropped")
		_progress.clear_run()
		_store.save_state(_progress)
		show_title()
		return
	set_character(session.character_id)
	_run = session
	_run_result = RunResult.NONE
	_reward_blocking = _run.has_pending_reward()
	_enter_current_floor()
	run_changed.emit()


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


## Back / Esc by phase: IN_FLOOR toggles the pause (nothing when not pausable; leaves the run when
## it already ended), CHAPTER_SELECT -> CHARACTER_SELECT, CHARACTER_SELECT -> TITLE, TITLE -> quit
## (not on iOS).
func go_back() -> void:
	match _phase:
		Phase.IN_FLOOR:
			if _run_result != RunResult.NONE:
				leave_run()
			elif _controller != null:
				_controller.toggle_pause()
		Phase.CHAPTER_SELECT:
			show_character_select()
		Phase.CHARACTER_SELECT:
			show_title()
		Phase.TITLE:
			if can_show_quit():
				quit_requested()


## Pause menu "Về": leaves the floor mid-run. The run stays saved at the current match (its clock
## is updated), the controller is freed and the title shows (Continue resumes it). A run that
## already ended behaves like [method leave_run]; a test floor just returns to the title.
func leave_floor() -> void:
	if _run_result != RunResult.NONE:
		leave_run()
		return
	if _run != null:
		_save_run()
	_free_controller()
	_current = NO_FLOOR
	_set_phase(Phase.TITLE)


## Story 019: the one button of RUN KẾT THÚC / RUN THẮNG (also usable mid-run by dev tooling):
## frees the controller, drops the live run object (the save was already cleared by the result)
## and shows the title.
func leave_run() -> void:
	_free_controller()
	_current = NO_FLOOR
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_set_phase(Phase.TITLE)
	run_changed.emit()


## Story 019: the reward view picked card [param id] from the offer: it joins the deck (and the
## seen cards), the run is saved and the run goes on (next match with the grown deck, or the next
## floor after a floor boss). Ignored with a warning when no offer is open or the id is not in it.
func reward_chosen(id: String) -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_chosen('%s') with no offer open, ignored" % id)
		return
	if not _run.pending_reward.has(id):
		push_warning("GameFlow: reward_chosen('%s') is not in the offer %s, ignored" % [id, str(_run.pending_reward)])
		return
	_run.add_card(id, int(get_reward_config().get("max_card_level", SkillConfig.MAX_LEVEL)))
	_progress.mark_card_seen(id)
	_run.clear_pending_reward()
	_save_run()
	run_changed.emit()
	_continue_after_reward(true)


## Story 019: the reward view's "Bỏ qua": no card, the run goes on. Ignored with a warning when no
## offer is open or rewards.json has allow_skip false.
func reward_skipped() -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_skipped() with no offer open, ignored")
		return
	if not bool(get_reward_config().get("allow_skip", true)):
		push_warning("GameFlow: rewards.json allow_skip is false, the offer must be picked")
		return
	_run.clear_pending_reward()
	_save_run()
	run_changed.emit()
	_continue_after_reward(false)


## Story 020: the reward view asked to remove the deck card at [param index] ("Bỏ 1 lá"): refused with a
## warning below min_deck_size, when rewards.json allow_remove is false, or with no offer open;
## otherwise the card goes, the offer is cleared, the run is saved and goes on exactly like a skip.
func reward_remove_requested(index: int) -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_remove_requested(%d) with no offer open, ignored" % index)
		return
	var cfg: Dictionary = get_reward_config()
	if not bool(cfg.get("allow_remove", true)):
		push_warning("GameFlow: rewards.json allow_remove is false, ignored")
		return
	if not _run.remove_card_at(index, int(cfg.get("min_deck_size", 4))):
		push_warning("GameFlow: card %d cannot be removed (out of range or deck at minimum)" % index)
		return
	_run.clear_pending_reward()
	_save_run()
	run_changed.emit()
	_continue_after_reward(true)


## Story 020: the run's deck as {id, level} entries ([] with no run).
func get_run_deck_entries() -> Array[Dictionary]:
	if _run == null:
		return []
	return _run.deck_entries()


## Story 020: id -> highest copy level of the run's deck ({} with no run).
func get_deck_levels() -> Dictionary:
	if _run == null:
		return {}
	return _run.deck_levels()


## Deprecated (Story 019): there is no retry in a run; no-op with a warning (the HUD still calls it
## until the result screens are redesigned).
func retry_requested() -> void:
	push_warning("GameFlow: retry_requested() is gone (Story 019: death ends the run)")


## Deprecated (Story 019): the run moves to the next floor by itself after the boss's reward;
## no-op with a warning.
func next_floor_requested() -> void:
	push_warning("GameFlow: next_floor_requested() is gone (Story 019: the run advances after the reward)")


## The floor after the current one in linear order; (-1, -1) when none or outside IN_FLOOR.
func get_next_floor() -> Vector2i:
	if _current == NO_FLOOR:
		return NO_FLOOR
	return _config.next_floor(_current.x, _current.y)


# Creates the run of the selected (or default) character at floor (ci, fi) of chapter ci with a
# fresh seed (or --seed), saves it and enters the floor.
func _begin_run(ci: int, fi: int) -> void:
	if _character_id.is_empty():
		set_character(get_characters().default_id())
	var run_seed: int = _dev_seed if _dev_seed >= 0 else randi() & ChaptersConfig.SEED_MASK
	_run = RunSession.begin(_config, _character_dict(), ci, run_seed)
	_run.floor_index = clampi(fi, 0, _config.floor_count(_run.chapter_index) - 1)
	_run_result = RunResult.NONE
	_reward_blocking = false
	_save_run()
	_enter_current_floor()
	run_changed.emit()


# Spawns the controller of the run's current floor at the run's current match / HP / deck. The
# floor's RunConfig gets between_sec 0 (the reward screen gates the advance) and no minimum-HP
# rule (retry_min_hp_ratio 0: the saved HP is the HP). A pending offer (resume) holds the intro.
func _enter_current_floor() -> void:
	_free_controller()
	var ci: int = _run.chapter_index
	var fi: int = _run.floor_index
	_current = Vector2i(ci, fi)
	_floor_seed = _run.floor_seed()
	_elapsed_base = _run.elapsed_sec
	var run_config: RunConfig = RunConfig.from_floor(_config.resolved_floor(ci, fi, _floor_seed), _config.defaults())
	run_config.between_sec = 0.0
	run_config.retry_min_hp_ratio = 0.0
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.floor_label = _config.floor_name(ci, fi)
	controller.character = _character_dict()
	controller.deck = _run.deck_ids
	controller.deck_entries = _run.deck_entries()
	controller.hold_intro = _reward_blocking
	controller.configure(run_config, _run.match_index, _run.hp)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_FLOOR)
	controller_changed.emit(controller)


# Writes the live run (clock included) into the progress and saves through the store.
func _save_run() -> void:
	_sync_elapsed()
	_progress.set_run(_run)
	_store.save_state(_progress)


# Copies the controller's clock into the run (floor entry base + this floor's PLAYING time).
func _sync_elapsed() -> void:
	if _run != null and _controller != null and _controller.get_state() != null:
		_run.elapsed_sec = _elapsed_base + _controller.get_state().get_elapsed_sec()


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


# A match entered PLAYING: the run is at that match with that HP at match start; save it.
func _on_match_started(match_index: int, hp_at_match_start: float) -> void:
	if _run == null or _run_result != RunResult.NONE:
		return
	_run.match_index = match_index
	_run.hp = hp_at_match_start
	_save_run()


func _on_run_phase_changed(phase: int) -> void:
	if _run == null or _controller == null or _run_result != RunResult.NONE:
		return
	match phase:
		RunState.Phase.LOST:
			_finish_run_lost()
		RunState.Phase.BETWEEN, RunState.Phase.WON:
			_on_match_won()


# A match was won: heal / advance the run, then end it or roll the offer.
func _on_match_won() -> void:
	var state: RunState = _controller.get_state()
	_run.match_index = state.get_match_index()
	var passive_heal: float = 0.0
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view != null:
		passive_heal = view.get_passive_heal()
	_run.apply_match_won(_controller.get_last_player_hp(), _controller.get_player_max_hp(), _config, state.is_boss_match(), passive_heal)
	if _run.is_run_won():
		_finish_run_won()
		return
	_offer_reward()


# Rolls the card offer for the run's current position (seeded by run seed + position), marks the
# cards seen, saves. An empty pool (nothing implemented) skips the offer and goes on.
func _offer_reward() -> void:
	var offer: Array[String] = RewardRoller.roll(get_cards(), get_reward_config(), _reward_seed(), [], _run.deck_levels())
	for id: String in offer:
		_progress.mark_card_seen(id)
	_run.set_pending_reward(offer)
	_save_run()
	run_changed.emit()
	if offer.is_empty():
		push_warning("GameFlow: no card to offer, continuing without a reward")
		_continue_after_reward(false)


# Deterministic offer seed: run seed and the position (chapter, floor, match) the offer leads to.
func _reward_seed() -> int:
	return hash([_run.run_seed, _run.chapter_index, _run.floor_index, _run.match_index]) & ChaptersConfig.SEED_MASK


# The offer was resolved: resume a held intro (respawning the match when the deck grew), enter the
# next floor after a floor boss, or advance the controller to the next match with the grown deck.
func _continue_after_reward(deck_changed: bool) -> void:
	if _controller == null:
		return
	if _reward_blocking:
		_reward_blocking = false
		if deck_changed:
			_enter_current_floor()
		else:
			_controller.hold_intro = false
		return
	if _controller.get_state().get_phase() == RunState.Phase.WON:
		_enter_current_floor()
		return
	_controller.deck = _run.deck_ids
	_controller.deck_entries = _run.deck_entries()
	_controller.advance_requested()


# The last floor's boss fell: the chapter is cleared, the saved run is dropped, result WON.
func _finish_run_won() -> void:
	_sync_elapsed()
	_progress.mark_chapter_cleared(_config.chapter_id(_run.chapter_index))
	_progress.clear_run()
	_store.save_state(_progress)
	_run_result = RunResult.WON
	run_changed.emit()


# The player died: the saved run is dropped at once, result LOST (no retry).
func _finish_run_lost() -> void:
	_sync_elapsed()
	_progress.clear_run()
	_store.save_state(_progress)
	_run_result = RunResult.LOST
	run_changed.emit()


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
			state.mark_chapter_cleared(_config.chapter_id(0))
			var character: Dictionary = get_characters().get_character(get_characters().default_id())
			var session: RunSession = RunSession.begin(_config, character, 0, DEMO_RUN_SEED)
			session.floor_index = clampi(DEMO_RUN_FLOOR, 0, _config.floor_count(0) - 1)
			session.match_index = clampi(DEMO_RUN_MATCH, 0, _config.match_count(0, session.floor_index) - 1)
			session.hp = DEMO_RUN_HP
			for id: String in RewardRoller.roll(get_cards(), get_reward_config(), DEMO_RUN_SEED, [], session.deck_levels()):
				session.add_card(id)
			state.set_run(session)
			return state
		_:
			if progress_mode != PROGRESS_NONE and not progress_mode.is_empty():
				push_warning("GameFlow: unknown --progress=%s (none|all|demo), starting empty" % progress_mode)
			return _store.load_state(_config)


# DEV-ONLY (--run=reward|runover|runwon): puts the freshly started run into a capture state.
func _apply_dev_flow_run(kind: String) -> void:
	var state: RunState = _controller.get_state()
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	match kind:
		FLOW_RUN_REWARD:
			# Match 1 won with DEV_FLOW_HP: the offer is open and the next match is held in INTRO.
			_run.apply_match_won(DEV_FLOW_HP, _controller.get_player_max_hp(), _config, false, 0.0)
			_offer_reward()
			_reward_blocking = _run.has_pending_reward()
			_enter_current_floor()
		FLOW_RUN_OVER:
			if view != null:
				view.get_state().damage(CombatState.Side.PLAYER, 999999.0)
			state.dev_jump(state.get_match_index(), RunState.Phase.LOST, RunController.DEV_ELAPSED_SEC, -1.0)
			_finish_run_lost()
		FLOW_RUN_WON:
			_run.floor_index = _config.floor_count(_run.chapter_index) - 1
			_run.match_index = _config.match_count(_run.chapter_index, _run.floor_index) - 1
			_run.hp = DEV_FLOW_HP
			_enter_current_floor()
			state = _controller.get_state()
			battle = _controller.get_battle()
			view = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
			if view != null:
				view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
			state.dev_jump(_run.match_index, RunState.Phase.WON, RunController.DEV_ELAPSED_SEC, -1.0)
			_run.apply_match_won(DEV_FLOW_HP, _controller.get_player_max_hp(), _config, true, 0.0)
			_finish_run_won()
