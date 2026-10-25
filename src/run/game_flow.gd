class_name GameFlow
extends Node2D
## The thin layer above one roguelike RUN (Story 015, 016, 018, 019, 022): chapters data, the
## saved progress, ONE [RunSession] while a run is live and ONE RunController child per MAP NODE
## that plays a match (created when the node is chosen, freed when it is left). Phases: TITLE,
## CHARACTER_SELECT (CharacterSelectView), CHAPTER_SELECT (ChapterSelectView), MAP (the chapter map,
## ChapterMapView: pick a node of the current column), IN_NODE (a RunController plays the node's
## match; the run screens take over) and REST (RestView: heal or forge). [method go_back] (Esc,
## Android back) acts per phase: IN_NODE toggles the pause (or leaves a finished run), MAP / REST
## leave to the title keeping the save, CHAPTER_SELECT -> CHARACTER_SELECT, CHARACTER_SELECT ->
## TITLE, TITLE -> quit. App pause / focus loss while IN_NODE force-pauses the battle. Draws nothing
## itself. Direct child of Main in main.tscn; RunHudView (a sibling) gets the controller through
## [signal controller_changed]. Views the flow talks to are optional: a missing view node never
## breaks the flow (everything goes through signals and getters).
##
## Run rules (Story 022, design/game-brief.md v4 "Run"): title -> character -> chapter ->
## [method start_run]: the chapter MAP is generated from the run seed
## (ChaptersConfig.generate_map, tier capped while no boss was ever beaten), a RunSession
## (character, deck, map, column, HP, seed, removal tokens) is saved at once and the MAP shows.
## [method choose_node] per node kind: battle / danger / miniboss / boss spawn a RunController for
## RunConfig.from_node (one match, between_sec 0, no minimum-HP rule) and save; treasure opens a
## free card offer at once (no fight); rest opens the REST screen. A WON match completes the node
## (RunSession.complete_node: HP carried, NO automatic heal, boss grants a removal token and wins
## the run; a boss clear is also counted in the permanent progress) and rolls the offer of the
## node kind (RewardRoller.reward_for_node: offers, min_rarity, free, removal_token) with the run's
## luck; the flow then WAITS for [method reward_chosen] / [method reward_skipped] /
## [method reward_remove_requested] (the last one spends a removal token). After the offer: a won
## run marks the chapter cleared, drops the save and shows the RUN WON result
## ([method get_run_result] = WON); otherwise the controller is freed and the MAP shows the next
## column. Death (controller phase LOST) drops the saved run at once (LOST); there is no retry.
## [method leave_run] (the one button of the result screens) frees everything and shows the title.
##
## Leaving mid-run ([method leave_run_keep_save], the pause menu / map back button): the controller
## is freed, the run stays saved and the title shows "Tiếp tục". Resume ([method continue_requested])
## rebuilds the v4 save: node chosen and no offer open -> the match respawns at the saved HP; offer
## open -> MAP with the offer; nothing chosen -> MAP; a rest node chosen -> REST. A pre-v4 save
## (RunSession.needs_restart) restarts the chapter for the saved character from a fresh map and
## leaves a one-line notice in [method take_restart_notice]; cleared chapters are kept.
##
## DEV-ONLY user args (after "--"):
##   --progress=none|all|demo   memory store (never writes user://progress.json): empty / every
##                              chapter but the last cleared / chapter 1 cleared plus a v4 saved run
##                              in chapter 1 at column 3 (3 nodes cleared, 1 removal token, HP 171)
##   --node=ch1/c2/n1           skip the menus: fresh seeded run of the default character in that
##                              chapter, columns before C cleared, node N of column C chosen (a match
##                              node spawns its controller; treasure opens its offer; rest -> REST)
##   --floor=ch1/f2             legacy alias of --node=ch1/c0/n0 (warning)
##   --title                    show the title even with --progress=... (without it --progress alone
##                              starts at the chapter select; no dev arg at all starts at the title)
##   --chapter=ch2              fresh seeded run of that chapter, shown on its MAP (no node chosen)
##   --seed=N                   force the run seed (reproducible maps, arenas and offers)
##   --lang=vi|en               UI locale for this run only (not saved; captures)
##   --character=<id>           pick the character like the select screen would (Story 018)
##   --select=character         start in CHARACTER_SELECT with a memory store (captures)
##   --run=map|map3|rest|treasure|miniboss_reward|boss_reward|reward|runover|runwon
##                              run states for captures: the fresh map / 3 columns cleared (luck 3,
##                              1 token) / the REST screen / a treasure offer / the miniboss offer
##                              (rare floor) / the boss offer (token just granted) / a battle offer
##                              after the first node / the RUN KẾT THÚC result / the RUN THẮNG result
##   --match=, --run=intro|between|won|lost, --demo=, --arena=  (RunController / DemoArgs args) also
##                              switch to a memory store and, without --node, start a run in chapter 1
##                              with the first node chosen (so a controller exists for them)

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)
## Emitted when the RunController was created (after add_child) or is about to be freed (null).
signal controller_changed(controller: RunController)
## Story 019: emitted when the run's screen-relevant state changed: an offer appeared or was
## resolved, a node was chosen or completed, the run ended (WON / LOST), a run was left or resumed.
## Views may also poll the getters.
signal run_changed()

## IN_FLOOR is the Story 019 name of IN_NODE, kept for old callers and tests (same value).
enum Phase { TITLE, CHARACTER_SELECT, CHAPTER_SELECT, IN_NODE, MAP, REST, IN_FLOOR = IN_NODE }
## Story 019: how the live run ended; NONE while it is still going (or when there is none).
enum RunResult { NONE, WON, LOST }

## Deprecated alias of Phase.IN_NODE (Story 022).
const IN_FLOOR: int = Phase.IN_NODE

const PROGRESS_ARG: String = "--progress="
## DEV-ONLY (Story 022): --node=chX/cC/nN.
const NODE_ARG: String = "--node="
## DEV-ONLY (Story 023): --chapter=<id> opens a fresh run of that chapter on its MAP (captures).
const CHAPTER_ARG: String = "--chapter="
## DEV-ONLY legacy (Story 015): --floor=chX/fY, now an alias of --node=chX/c0/n0.
const FLOOR_ARG: String = "--floor="
const SEED_ARG: String = "--seed="
const TITLE_ARG: String = "--title"
## DEV-ONLY (Story 018): --character=<id> picks the character like the select screen would.
const CHARACTER_ARG: String = "--character="
## DEV-ONLY (Story 021): --signature=<id> gives the character the signature block of whichever
## character owns that id (scratch/demo captures only).
const SIGNATURE_ARG: String = "--signature="
## DEV-ONLY: locale override for captures (never saved).
const LANG_ARG: String = "--lang="
## DEV-ONLY (Story 018): --select=character starts in CHARACTER_SELECT (memory store; captures).
const SELECT_ARG: String = "--select="
const SELECT_CHARACTER: String = "character"
## DEV-ONLY (Story 019 / 022): --run=<kind> values handled HERE (the others belong to RunController).
const RUN_ARG: String = "--run="
const FLOW_RUN_REWARD: String = "reward"
const FLOW_RUN_OVER: String = "runover"
const FLOW_RUN_WON: String = "runwon"
const FLOW_RUN_MAP: String = "map"
const FLOW_RUN_MAP3: String = "map3"
const FLOW_RUN_REST: String = "rest"
const FLOW_RUN_TREASURE: String = "treasure"
const FLOW_RUN_MINIBOSS_REWARD: String = "miniboss_reward"
const FLOW_RUN_BOSS_REWARD: String = "boss_reward"
const FLOW_RUN_KINDS: Array[String] = [
	FLOW_RUN_REWARD, FLOW_RUN_OVER, FLOW_RUN_WON, FLOW_RUN_MAP, FLOW_RUN_MAP3, FLOW_RUN_REST,
	FLOW_RUN_TREASURE, FLOW_RUN_MINIBOSS_REWARD, FLOW_RUN_BOSS_REWARD,
]
## DEV-ONLY: columns --run=map3 clears.
const DEV_MAP3_COLUMNS: int = 3
## DEV-ONLY: player HP the --run=*reward / --run=runwon captures end the match with (70 % of 300).
const DEV_FLOW_HP: float = 210.0
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
## DEV-ONLY (--progress=demo): the saved demo run (chapter 0, this many columns cleared).
const DEMO_RUN_COLUMN: int = 3
const DEMO_RUN_HP: float = 171.0
const DEMO_RUN_SEED: int = 7
## Deprecated (Story 022): value of [method get_current_floor] outside a run.
const NO_FLOOR: Vector2i = Vector2i(-1, -1)
## One-line notice shown once when a pre-v4 save restarted its chapter (Story 022).
const TEXT_RESTART_OLD_SAVE: String = "run.restart.old_save"
## Node kinds that play a match (the others never spawn a controller).
const MATCH_NODE_KINDS: Array[String] = ["battle", "danger", "miniboss", "boss"]
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_BOSS: String = "boss"

var _config: ChaptersConfig
var _store: ProgressStore = null
var _progress: ProgressState
var _phase: Phase = Phase.TITLE
var _controller: RunController = null
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
## DEV-ONLY: --signature= value.
var _dev_signature: String = ""
## Story 019: the live run; null outside a run (title, menus, test floors).
var _run: RunSession = null
var _run_result: RunResult = RunResult.NONE
## Story 019: true while a resumed match is held in INTRO until its saved offer is resolved (only
## reachable from a save that has both a match node chosen and an offer open; defensive).
var _reward_blocking: bool = false
## Run clock at the entry of the current node (the controller's RunState clock starts at 0).
var _elapsed_base: float = 0.0
## Story 022: kind of the node whose offer is open ("" when none).
var _pending_node_kind: String = ""
## Story 022: translated restart notice waiting for [method take_restart_notice] ("" when none).
var _restart_notice: String = ""


## Test hook: installs the store BEFORE the node enters the tree (wins over --progress args).
func set_store_for_test(store: ProgressStore) -> void:
	_store = store


## Test hook (scratch flow tests): runs an ad-hoc single-floor RunConfig (the flat format read
## by RunConfig.load_from_file) as a throwaway match outside any run. No progress is written and no
## run exists (the run callbacks return early); the floor label is empty; the store installed by
## [method set_store_for_test] (or the real one) is left untouched.
func enter_test_floor(run_config: RunConfig) -> RunController:
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.character = _character_dict()
	controller.configure(run_config, 0, -1.0)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_NODE)
	controller_changed.emit(controller)
	return controller


func _ready() -> void:
	_config = ChaptersConfig.load_from_file()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var progress_mode: String = ""
	var node_text: String = ""
	var chapter_text: String = ""
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
		elif arg.begins_with(NODE_ARG):
			node_text = arg.trim_prefix(NODE_ARG)
		elif arg.begins_with(CHAPTER_ARG):
			chapter_text = arg.trim_prefix(CHAPTER_ARG)
		elif arg.begins_with(FLOOR_ARG):
			var floor_text: String = arg.trim_prefix(FLOOR_ARG).trim_suffix(RESUME_SUFFIX)
			node_text = "%s/c0/n0" % floor_text.get_slice("/", 0)
			push_warning("GameFlow: --floor=%s is deprecated (Story 022), using --node=%s" % [floor_text, node_text])
		elif arg.begins_with(SEED_ARG):
			_dev_seed = int(arg.trim_prefix(SEED_ARG)) & ChaptersConfig.SEED_MASK
		elif arg.begins_with(LANG_ARG):
			_dev_locale = arg.trim_prefix(LANG_ARG)
		elif arg.begins_with(CHARACTER_ARG):
			_dev_character = arg.trim_prefix(CHARACTER_ARG)
		elif arg.begins_with(SIGNATURE_ARG):
			_dev_signature = arg.trim_prefix(SIGNATURE_ARG)
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
		_store = _make_store(progress_mode, dev_run or not select_mode.is_empty() or not node_text.is_empty() or not chapter_text.is_empty())
	_progress = _load_progress(progress_mode)
	# Locale before anything draws or caches a translated name.
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
	if not node_text.is_empty():
		_apply_dev_node(node_text)
	elif not chapter_text.is_empty():
		_apply_dev_chapter(chapter_text)
	elif dev_run:
		_begin_run(0)
		if flow_run.is_empty():
			# A RunController / DemoArgs arg: it needs a controller, so the first node is taken.
			_dev_choose_first_available()
	if not flow_run.is_empty() and _run != null:
		_apply_dev_flow_run(flow_run)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _phase == Phase.IN_NODE and _controller != null and not _no_autopause:
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


## Story 019 / 022: the validated rewards.json dictionary (offer_count, rarity weights and luck
## anchors, allow_skip, allow_remove, min_deck_size, max_card_level, starting_removals, luck_*,
## rest_heal_ratio, rest_forge_levels, node_rewards); loaded once, lazily. Returned as a copy.
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
	var character: Dictionary = get_characters().get_character(_character_id)
	if not _dev_signature.is_empty():
		for other: String in get_characters().ids():
			var raw: Variant = get_characters().get_character(other).get("signature")
			if raw is Dictionary and str((raw as Dictionary).get("id", "")) == _dev_signature:
				character = character.duplicate(true)
				character["signature"] = raw
				break
	return character


## Current [enum Phase].
func get_phase() -> int:
	return _phase


## The chapters data.
func get_config() -> ChaptersConfig:
	return _config


## The saved progress (live object; GameFlow writes it through the store).
func get_progress() -> ProgressState:
	return _progress


## The controller of the node being played; null outside IN_NODE.
func get_controller() -> RunController:
	return _controller


## Deprecated (Story 022; use [method get_current_column]): (chapter, column) of the live run while
## it is on the map, in a node or at a rest; [constant NO_FLOOR] otherwise (title, menus, test floors).
func get_current_floor() -> Vector2i:
	if _run == null or not (_phase == Phase.IN_NODE or _phase == Phase.MAP or _phase == Phase.REST):
		return NO_FLOOR
	return Vector2i(_run.chapter_index, _run.column)


## Deprecated (Story 022): the run seed (arena seeds derive from it per node); 0 without a run.
func get_floor_seed() -> int:
	return 0 if _run == null else _run.run_seed


## Story 019: the live run (also after it ended, until [method leave_run]); null when none.
func get_run() -> RunSession:
	return _run


## Story 019: how the live run ended; NONE while it is going or when there is no run.
func get_run_result() -> int:
	return _run_result


## Story 022: the run's chapter map (deep copy): columns {index, tier, nodes [{kind, match_id}]};
## [] without a run.
func get_run_map() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _run == null:
		return out
	for column: Dictionary in _run.map:
		out.append(column.duplicate(true))
	return out


## Story 022: index of the column the run is at (== column count once the boss fell); -1 without a run.
func get_current_column() -> int:
	return -1 if _run == null else _run.column


## Story 022: nodes of the current column that can still be chosen, each with its "node_index"
## (the argument of [method choose_node]); [] without a run or past the last column.
func get_available_nodes() -> Array[Dictionary]:
	if _run == null:
		return []
	return _run.available_nodes()


## Story 022: the nodes already passed, {column, node_index, kind} each; [] without a run.
func get_cleared_nodes() -> Array:
	if _run == null:
		return []
	return _run.cleared_nodes.duplicate(true)


## Story 022: removal tokens of the live run (the reward view shows "Bỏ 1 lá" only above 0).
func get_removal_tokens() -> int:
	return 0 if _run == null else _run.removal_tokens


## Story 022: the run's luck (luck_start + luck_per_node x nodes cleared); 0 without a run.
func get_luck() -> float:
	return 0.0 if _run == null else _run.luck(get_reward_config())


## Story 019: card ids of the offer waiting for [method reward_chosen] / [method reward_skipped];
## [] when none.
func get_pending_reward() -> Array[String]:
	if _run == null:
		return []
	return _run.pending_reward.duplicate()


## Story 022: kind of the node the open offer belongs to (battle, danger, treasure, miniboss,
## boss); "" when no offer is open.
func get_pending_reward_kind() -> String:
	if _run == null or not _run.has_pending_reward():
		return ""
	return _pending_node_kind


## Story 022: the reward rule of the open offer (RewardRoller.reward_for_node: offers, min_rarity,
## free, removal_token); {} when no offer is open.
func get_pending_reward_info() -> Dictionary:
	var kind: String = get_pending_reward_kind()
	if kind.is_empty():
		return {}
	return RewardRoller.reward_for_node(kind, get_reward_config())


## Story 019: true while a resumed run holds its match in INTRO until the saved offer is resolved.
func is_reward_blocking() -> bool:
	return _reward_blocking


## Story 022: the restart notice of a pre-v4 save, returned ONCE (then ""); "" when there is none.
func take_restart_notice() -> String:
	var notice: String = _restart_notice
	_restart_notice = ""
	return notice


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


## Story 019 / 022: starts a run of the selected character in chapter [param ci] (fresh seeded map,
## column 0, full HP, starter deck, starting removal tokens; any saved run is replaced — confirming
## that is the view's job) and shows the MAP. Refused with a warning for an unknown or locked
## chapter. With no character chosen the default one is used.
func start_run(ci: int) -> void:
	if _config.chapter_id(ci).is_empty():
		push_warning("GameFlow: start_run(%d): no such chapter" % ci)
		return
	if not _progress.is_chapter_unlocked(_config, ci):
		push_warning("GameFlow: start_run(%d): chapter '%s' is locked" % [ci, _config.chapter_id(ci)])
		return
	_begin_run(ci)


## Story 022: the map view picked node [param node_index] of the current column. Battle / danger /
## miniboss / boss spawn the node's controller (phase IN_NODE); treasure opens its free offer at
## once (phase stays MAP); rest shows the REST screen. The run is saved. False with a warning
## outside MAP, without a run, or when RunSession.choose_node refuses (bad index, cleared node).
func choose_node(node_index: int) -> bool:
	if _run == null or _phase != Phase.MAP or _run_result != RunResult.NONE:
		push_warning("GameFlow: choose_node(%d) outside the map, ignored" % node_index)
		return false
	if not _run.choose_node(node_index):
		push_warning("GameFlow: choose_node(%d): no such node in column %d" % [node_index, _run.column])
		return false
	var kind: String = str(_run.current_node().get("kind", ""))
	if kind == KIND_TREASURE:
		_offer_reward(kind)
	elif kind == KIND_REST:
		_save_run()
		_set_phase(Phase.REST)
	else:
		_enter_current_node()
	run_changed.emit()
	return true


## Story 022: REST "Nghỉ": heals rest_heal_ratio x max HP (clamped), completes the node and shows
## the MAP. Ignored with a warning outside REST.
func rest_heal_requested() -> void:
	if _run == null or _phase != Phase.REST:
		push_warning("GameFlow: rest_heal_requested() outside a rest node, ignored")
		return
	_run.rest_heal(_player_max_hp(), get_reward_config())
	_finish_rest()


## Story 022: REST "Rèn": upgrades the deck card at [param deck_index] (+rest_forge_levels, capped
## at SkillConfig.MAX_LEVEL), completes the node and shows the MAP. A bad index or a card already at
## the cap is refused with a warning and the REST screen stays.
func rest_forge_requested(deck_index: int) -> void:
	if _run == null or _phase != Phase.REST:
		push_warning("GameFlow: rest_forge_requested(%d) outside a rest node, ignored" % deck_index)
		return
	var result: Dictionary = _run.rest_forge(deck_index, get_reward_config())
	if not bool(result.get("ok", false)):
		push_warning("GameFlow: card %d cannot be forged (out of range or at max level)" % deck_index)
		return
	_finish_rest()


## Story 016: shows the title screen; frees the controller if a node was running. A run that
## already ended is dropped; a run still going stays live and saved (the title offers Continue).
func show_title() -> void:
	_free_controller()
	if _run_result != RunResult.NONE:
		_run = null
		_run_result = RunResult.NONE
	_reward_blocking = false
	_set_phase(Phase.TITLE)


## Story 019: shows the chapter select; frees the controller if a node was running.
func show_chapter_select() -> void:
	_free_controller()
	_set_phase(Phase.CHAPTER_SELECT)


## Story 018: shows the character select; frees the controller if a node was running.
func show_character_select() -> void:
	_free_controller()
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
## map, position, HP, tokens, pending offer) and restores its phase (see the class doc). A save
## that no longer fits the data (unknown chapter, bad map, character, no known card) is dropped
## with a warning and the title stays. A pre-v4 save restarts the chapter for its character and
## leaves [method take_restart_notice]. Ignored without a saved run.
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
	if session.needs_restart:
		var key: String = session.restart_reason if not session.restart_reason.is_empty() else TEXT_RESTART_OLD_SAVE
		_restart_notice = tr(key)
		push_warning("GameFlow: pre-v4 saved run, chapter %d restarts for '%s'" % [session.chapter_index, session.character_id])
		_begin_run(session.chapter_index)
		return
	_free_controller()
	_run = session
	_run_result = RunResult.NONE
	_reward_blocking = false
	_elapsed_base = _run.elapsed_sec
	_pending_node_kind = _pending_kind_from_run()
	_resume_position()
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
## RunController.floor_label is cached per node entry (the title is the only place that switches).
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


## Back / Esc by phase: IN_NODE toggles the pause (nothing when not pausable; leaves the run when
## it already ended), MAP / REST leave to the title keeping the save, CHAPTER_SELECT ->
## CHARACTER_SELECT, CHARACTER_SELECT -> TITLE, TITLE -> quit (not on iOS).
func go_back() -> void:
	match _phase:
		Phase.IN_NODE:
			if _run_result != RunResult.NONE:
				leave_run()
			elif _controller != null:
				_controller.toggle_pause()
		Phase.MAP, Phase.REST:
			leave_run_keep_save()
		Phase.CHAPTER_SELECT:
			show_character_select()
		Phase.CHARACTER_SELECT:
			show_title()
		Phase.TITLE:
			if can_show_quit():
				quit_requested()


## Pause menu / map / rest "Về": leaves the run mid-way. The run stays saved where it is (its clock
## is updated), the controller is freed and the title shows (Continue resumes it). A run that
## already ended behaves like [method leave_run]; a test floor just returns to the title.
func leave_run_keep_save() -> void:
	if _run_result != RunResult.NONE:
		leave_run()
		return
	if _run != null:
		_save_run()
	_free_controller()
	_set_phase(Phase.TITLE)


## Deprecated name of [method leave_run_keep_save] (Story 019).
func leave_floor() -> void:
	leave_run_keep_save()


## Story 019: the one button of RUN KẾT THÚC / RUN THẮNG (also usable mid-run by dev tooling):
## frees the controller, drops the live run object (the save was already cleared by the result)
## and shows the title.
func leave_run() -> void:
	_free_controller()
	_run = null
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	_set_phase(Phase.TITLE)
	run_changed.emit()


## Story 019: the reward view picked card [param id] from the offer: it joins the deck (and the
## seen cards), the run is saved and goes on (the MAP, or the RUN THẮNG result after the boss).
## Ignored with a warning when no offer is open or the id is not in it.
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


## Story 020 / 022: the reward view asked to remove the deck card at [param index] ("Bỏ 1 lá"): spends
## one removal token (RunSession.remove_card_at). Refused with a warning with no token, below
## min_deck_size, when rewards.json allow_remove is false, or with no offer open; otherwise the
## card goes, the offer is cleared, the run is saved and goes on exactly like a skip.
func reward_remove_requested(index: int) -> void:
	if _run == null or not _run.has_pending_reward():
		push_warning("GameFlow: reward_remove_requested(%d) with no offer open, ignored" % index)
		return
	var cfg: Dictionary = get_reward_config()
	if not bool(cfg.get("allow_remove", true)):
		push_warning("GameFlow: rewards.json allow_remove is false, ignored")
		return
	if not _run.remove_card_at(index, int(cfg.get("min_deck_size", 4))):
		push_warning("GameFlow: card %d cannot be removed (no token, out of range or deck at minimum)" % index)
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


# Creates the run of the selected (or default) character in chapter ci with a fresh seed (or
# --seed) and a freshly generated map, saves it and shows the MAP.
func _begin_run(ci: int) -> void:
	if _character_id.is_empty():
		set_character(get_characters().default_id())
	_free_controller()
	var run_seed: int = _dev_seed if _dev_seed >= 0 else randi() & ChaptersConfig.SEED_MASK
	var map: Array[Dictionary] = _config.generate_map(ci, run_seed, _progress.get_cleared_bosses())
	var starting_removals: int = int(get_reward_config().get("starting_removals", 0))
	_run = RunSession.begin(_config, _character_dict(), ci, run_seed, map, starting_removals)
	_run_result = RunResult.NONE
	_reward_blocking = false
	_pending_node_kind = ""
	_elapsed_base = 0.0
	_save_run()
	_set_phase(Phase.MAP)
	run_changed.emit()


# Spawns the controller of the run's chosen node (RunConfig.from_node: one match, the node's arena
# seed, danger traits) at the run's HP / deck. between_sec 0 (the reward screen gates the advance)
# and no minimum-HP rule (retry_min_hp_ratio 0: the saved HP is the HP). A pending offer on a
# resumed match node holds the intro.
func _enter_current_node() -> void:
	_free_controller()
	var node: Dictionary = _run.current_node()
	var kind: String = str(node.get("kind", ""))
	_elapsed_base = _run.elapsed_sec
	var run_config: RunConfig = RunConfig.from_node(_config, _run.chapter_index, str(node.get("match_id", "")), kind, _run.run_seed)
	run_config.between_sec = 0.0
	run_config.retry_min_hp_ratio = 0.0
	var controller := RunController.new()
	controller.name = CONTROLLER_NODE
	controller.floor_label = tr(_node_name_key(kind))
	controller.chapter_id = _config.chapter_id(_run.chapter_index)
	controller.character = _character_dict()
	controller.deck = _run.deck_ids
	controller.deck_entries = _run.deck_entries()
	controller.hold_intro = _reward_blocking
	controller.configure(run_config, 0, _run.hp)
	controller.match_started.connect(_on_match_started)
	controller.phase_changed.connect(_on_run_phase_changed)
	_controller = controller
	add_child(controller)
	_set_phase(Phase.IN_NODE)
	controller_changed.emit(controller)
	_save_run()


# Translation key of a node kind's display name (node.<kind>.name rows of strings.csv).
func _node_name_key(kind: String) -> String:
	return "node.%s.name" % kind


# Restores the phase of a resumed run from its position (see the class doc).
func _resume_position() -> void:
	var kind: String = str(_run.current_node().get("kind", ""))
	if kind.is_empty():
		if _run.is_run_won() and not _run.has_pending_reward():
			_finish_run_won()
			return
		_set_phase(Phase.MAP)
	elif kind == KIND_REST:
		_set_phase(Phase.REST)
	elif kind == KIND_TREASURE:
		_set_phase(Phase.MAP)
		if not _run.has_pending_reward():
			_offer_reward(kind)
	else:
		_reward_blocking = _run.has_pending_reward()
		_enter_current_node()


# Kind of the node an open offer belongs to, derived from the save: the chosen node (treasure) or
# the node completed last.
func _pending_kind_from_run() -> String:
	if not _run.has_pending_reward():
		return ""
	var chosen: String = str(_run.current_node().get("kind", ""))
	if not chosen.is_empty():
		return chosen
	if _run.cleared_nodes.is_empty():
		return ""
	return str((_run.cleared_nodes[_run.cleared_nodes.size() - 1] as Dictionary).get("kind", ""))


# Player max HP for the run rules outside a battle: the live controller, else the character, else
# combat.json.
func _player_max_hp() -> float:
	if _controller != null:
		return _controller.get_player_max_hp()
	return _character_max_hp(_character_dict())


static func _character_max_hp(character: Dictionary) -> float:
	if character.has("max_hp"):
		return maxf(float(character["max_hp"]), 1.0)
	return CombatConfig.load_from_file().player_max_hp


# Writes the live run (clock included) into the progress and saves through the store.
func _save_run() -> void:
	_sync_elapsed()
	_progress.set_run(_run)
	_store.save_state(_progress)


# Copies the controller's clock into the run (node entry base + this node's PLAYING time).
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


# A match entered PLAYING: the run is at that node with that HP at match start; save it.
func _on_match_started(_match_index: int, hp_at_match_start: float) -> void:
	if _run == null or _run_result != RunResult.NONE:
		return
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


# The node's match was won: complete the node (HP carried, boss token / clear) and roll its offer.
func _on_match_won() -> void:
	var passive_heal: float = 0.0
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view != null:
		passive_heal = view.get_passive_heal()
	_complete_match_node(_controller.get_last_player_hp(), _controller.get_player_max_hp(), passive_heal)


# Completes the chosen match node with the given end HP, counts a boss clear, opens the offer.
func _complete_match_node(hp_end: float, max_hp: float, passive_heal: float) -> void:
	var kind: String = str(_run.current_node().get("kind", ""))
	_run.complete_node(hp_end, max_hp, kind, get_reward_config(), passive_heal)
	if kind == KIND_BOSS:
		_progress.record_boss_clear()
	_offer_reward(kind)


# Rolls the offer of a node kind (RewardRoller.reward_for_node: count and rarity floor) with the
# run's luck, seeded by run seed + position, marks the cards seen, saves. offers 0 or an empty
# pool skips the offer and goes on.
func _offer_reward(kind: String) -> void:
	var cfg: Dictionary = get_reward_config()
	var info: Dictionary = RewardRoller.reward_for_node(kind, cfg)
	_pending_node_kind = kind
	var offers: int = int(info.get("offers", 0))
	if offers <= 0:
		_run.clear_pending_reward()
		_continue_after_reward(false)
		return
	cfg["offer_count"] = offers
	var offer: Array[String] = RewardRoller.roll(get_cards(), cfg, _reward_seed(), [], _run.deck_levels(),
		_run.luck(cfg), str(info.get("min_rarity", "common")))
	for id: String in offer:
		_progress.mark_card_seen(id)
	_run.set_pending_reward(offer)
	_save_run()
	run_changed.emit()
	if offer.is_empty():
		push_warning("GameFlow: no card to offer, continuing without a reward")
		_continue_after_reward(false)


# Deterministic offer seed: run seed and the position (chapter, column, nodes cleared).
func _reward_seed() -> int:
	return hash([_run.run_seed, _run.chapter_index, _run.column, _run.cleared_nodes.size()]) & ChaptersConfig.SEED_MASK


# The offer was resolved: release a held intro (defensive resume case), complete a fight-less node
# (treasure), then end a won run or go back to the MAP.
func _continue_after_reward(deck_changed: bool) -> void:
	if _run == null:
		return
	if _reward_blocking and _controller != null:
		_reward_blocking = false
		if deck_changed:
			_enter_current_node()
		else:
			_controller.hold_intro = false
		return
	if _run.node_index >= 0:
		_run.complete_node(_run.hp, _player_max_hp(), "", get_reward_config(), 0.0)
	_pending_node_kind = ""
	if _run.is_run_won():
		_finish_run_won()
		return
	_return_to_map()


# The rest choice was made: complete the node and go back to the MAP.
func _finish_rest() -> void:
	_run.complete_node(_run.hp, _player_max_hp(), KIND_REST, get_reward_config(), 0.0)
	if _run.is_run_won():
		_finish_run_won()
		return
	_return_to_map()


# Frees the node's controller (clock synced first), shows the MAP and saves.
func _return_to_map() -> void:
	_sync_elapsed()
	_free_controller()
	_set_phase(Phase.MAP)
	_save_run()
	run_changed.emit()


# The boss fell and its offer was resolved: the chapter is cleared, the saved run is dropped,
# result WON. The RUN THẮNG panel lives on the IN_NODE screens.
func _finish_run_won() -> void:
	_sync_elapsed()
	_progress.mark_chapter_cleared(_config.chapter_id(_run.chapter_index))
	_progress.clear_run()
	_store.save_state(_progress)
	_run_result = RunResult.WON
	if _phase != Phase.IN_NODE:
		_set_phase(Phase.IN_NODE)
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
			var cfg: Dictionary = get_reward_config()
			var map: Array[Dictionary] = _config.generate_map(0, DEMO_RUN_SEED, state.get_cleared_bosses())
			var session: RunSession = RunSession.begin(_config, character, 0, DEMO_RUN_SEED, map, int(cfg.get("starting_removals", 0)))
			for _c: int in DEMO_RUN_COLUMN:
				var nodes: Array[Dictionary] = session.available_nodes()
				if nodes.is_empty():
					break
				session.choose_node(int(nodes[0]["node_index"]))
				session.complete_node(session.hp, _character_max_hp(character), "", cfg, 0.0)
			session.hp = DEMO_RUN_HP
			for id: String in RewardRoller.roll(get_cards(), cfg, DEMO_RUN_SEED, [], session.deck_levels(), session.luck(cfg)):
				session.add_card(id)
			state.set_run(session)
			return state
		_:
			if progress_mode != PROGRESS_NONE and not progress_mode.is_empty():
				push_warning("GameFlow: unknown --progress=%s (none|all|demo), starting empty" % progress_mode)
			return _store.load_state(_config)


# DEV-ONLY (--chapter=<id>): fresh run of that chapter on its MAP (unknown id: warning, no run).
func _apply_dev_chapter(id: String) -> void:
	for i: int in _config.chapter_count():
		if _config.chapter_id(i) == id:
			_begin_run(i)
			return
	push_warning("GameFlow: unknown chapter in --chapter=%s" % id)


# DEV-ONLY (--node=chX/cC/nN): fresh run of that chapter, columns before C cleared with their
# first node, node N of column C chosen (out of range: the first available, warning).
func _apply_dev_node(text: String) -> void:
	var parts: PackedStringArray = text.split("/")
	var ci: int = -1
	for i: int in _config.chapter_count():
		if parts.size() > 0 and _config.chapter_id(i) == parts[0]:
			ci = i
	if ci < 0:
		push_warning("GameFlow: unknown chapter in --node=%s (use e.g. ch1/c2/n1)" % text)
		return
	var column: int = int(parts[1].trim_prefix("c")) if parts.size() > 1 else 0
	var n: int = int(parts[2].trim_prefix("n")) if parts.size() > 2 else 0
	_begin_run(ci)
	_dev_clear_columns(column)
	var nodes: Array[Dictionary] = _run.available_nodes()
	if nodes.is_empty():
		push_warning("GameFlow: --node=%s: column %d has no node" % [text, column])
		return
	if n < 0 or n >= nodes.size():
		push_warning("GameFlow: --node=%s: node %d out of range (column has %d), using n0" % [text, n, nodes.size()])
		n = 0
	choose_node(int(nodes[n]["node_index"]))


# DEV-ONLY: clears the next [param count] columns of the live run with their first available
# node (no fight, HP untouched) and saves.
func _dev_clear_columns(count: int) -> void:
	var cfg: Dictionary = get_reward_config()
	for _c: int in count:
		var nodes: Array[Dictionary] = _run.available_nodes()
		if nodes.is_empty():
			break
		_run.choose_node(int(nodes[0]["node_index"]))
		_run.complete_node(_run.hp, _player_max_hp(), "", cfg, 0.0)
	_save_run()


# DEV-ONLY: chooses the first available node of the current column (false when none).
func _dev_choose_first_available() -> bool:
	var nodes: Array[Dictionary] = _run.available_nodes()
	if nodes.is_empty():
		return false
	return choose_node(int(nodes[0]["node_index"]))


# DEV-ONLY: walks the map forward (clearing columns with their first node) until a node of
# [param kind] is available, then chooses it. False with a warning when the map has none.
func _dev_advance_to_kind(kind: String) -> bool:
	while _run.column < _run.map.size():
		for node: Dictionary in _run.available_nodes():
			if str(node.get("kind", "")) == kind:
				return choose_node(int(node["node_index"]))
		_dev_clear_columns(1)
	push_warning("GameFlow: --run=: this map has no '%s' node (try another --seed)" % kind)
	return false


# DEV-ONLY: the chosen match node is won on the spot (boss dead, phase WON, HP DEV_FLOW_HP);
# with [param offer] the node completes and its offer opens, else it completes and the run is
# finished as won (the RUN THẮNG capture).
func _dev_win_current_match(offer: bool) -> void:
	if _controller == null:
		return
	var state: RunState = _controller.get_state()
	var battle: Node = _controller.get_battle()
	var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view != null:
		view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
	state.dev_jump(0, RunState.Phase.WON, RunController.DEV_ELAPSED_SEC, -1.0)
	if offer:
		_complete_match_node(DEV_FLOW_HP, _controller.get_player_max_hp(), 0.0)
		return
	var kind: String = str(_run.current_node().get("kind", ""))
	_run.complete_node(DEV_FLOW_HP, _controller.get_player_max_hp(), kind, get_reward_config(), 0.0)
	if kind == KIND_BOSS:
		_progress.record_boss_clear()
	_finish_run_won()


# DEV-ONLY (--run=<flow kind>): puts the freshly started run into a capture state.
func _apply_dev_flow_run(kind: String) -> void:
	match kind:
		FLOW_RUN_MAP:
			pass
		FLOW_RUN_MAP3:
			_dev_clear_columns(DEV_MAP3_COLUMNS)
			run_changed.emit()
		FLOW_RUN_REST:
			_dev_advance_to_kind(KIND_REST)
		FLOW_RUN_TREASURE:
			_dev_advance_to_kind(KIND_TREASURE)
		FLOW_RUN_MINIBOSS_REWARD:
			if _dev_advance_to_kind("miniboss"):
				_dev_win_current_match(true)
		FLOW_RUN_BOSS_REWARD:
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(true)
		FLOW_RUN_REWARD:
			if _dev_choose_first_available():
				_dev_win_current_match(true)
		FLOW_RUN_OVER:
			if _dev_choose_first_available() and _controller != null:
				var battle: Node = _controller.get_battle()
				var view: CombatView = null if battle == null else battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
				if view != null:
					view.get_state().damage(CombatState.Side.PLAYER, 999999.0)
				_controller.get_state().dev_jump(0, RunState.Phase.LOST, RunController.DEV_ELAPSED_SEC, -1.0)
				_finish_run_lost()
		FLOW_RUN_WON:
			if _dev_advance_to_kind(KIND_BOSS):
				_dev_win_current_match(false)
