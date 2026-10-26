class_name RunController
extends Node2D
## Owns one run = ONE floor: a RunState, and the current battle (a fresh instance of battle.tscn
## per match, so every match starts from clean grid/hand/bag/cooldown/status/brain/learning
## state). Flow: INTRO (battle frozen, still drawn) -> PLAYING -> match_ended -> BETWEEN (next
## match after between_sec or [method advance_requested]) or WON / LOST (waits for
## [method retry_match] / [method restart_requested] or for GameFlow to free it). The controller
## draws nothing; the run screens read its getters.
## Story 015: GameFlow spawns one controller per floor and calls [method configure] BEFORE
## add_child; without it the controller loads the flat file at [member run_config_path] (tests,
## ad-hoc floors). Story 016: PAUSE = the battle node's process_mode is DISABLED (the same freeze
## INTRO uses): all its _process/_input stop; the run clock and timers here stop too. Only PLAYING
## can be paused; the flag is cleared when the match ends or a new battle spawns. Story 019:
## [member hold_intro] keeps the INTRO timer from ticking (GameFlow holds a resumed match while
## its saved card offer is open); the run flow itself (deck growth, floors, death) lives in GameFlow.
## Implements: Story 011, Story 015, Story 016, Story 019.
##
## DEV-ONLY user args (after "--"), for screenshots; timers are frozen, nothing auto-advances:
##   --match=N                 start at match N (1-based)
##   --run=<intro|between|won|lost>   jump straight to that phase (won = last match, boss dead;
##                             lost = player dead; between = match N won; intro = match N frozen),
##                             with the clock set to [constant DEV_ELAPSED_SEC]
##   --arena=<shape_id>[:variant]   overrides the arena of match 1 (an arenas.json shape id; the
##                             ":variant" suffix asks for a seeded variant), for captures

## Emitted when the run phase changed; [param phase] is a [enum RunState.Phase] value.
signal phase_changed(phase: int)
## Emitted right after a new battle was added (before its first frame).
signal battle_spawned(battle: Node)
## Emitted when a match enters PLAYING (Story 015): GameFlow records the floor in progress.
## [param hp_at_match_start] negative = full HP.
signal match_started(match_index: int, hp_at_match_start: float)
## Emitted when the pause flag changed (Story 016).
signal paused_changed(paused: bool)

const BATTLE_SCENE_PATH: String = "res://src/battle/battle.tscn"
const COMBAT_VIEW_NODE: String = "CombatView"
const MATCH_ARG: String = "--match="
const RUN_ARG: String = "--run="
const ARENA_ARG: String = "--arena="
const ARENA_VARIANT_SUFFIX: String = ":variant"
## DEV-ONLY: --run= kinds this node handles.
const RUN_KINDS: Array[String] = ["intro", "between", "won", "lost"]
## DEV-ONLY (Story 019 / 022): --run= kinds GameFlow handles; ignored here.
const FLOW_RUN_KINDS: Array[String] = [
	"reward", "runover", "runwon", "map", "map3", "rest", "treasure", "miniboss_reward", "boss_reward",
	"world", "world3", "floorclear", "final", "shop", "gold_reward",
]
## DEV-ONLY (Story 033): prefix of the GameFlow --run=event=<id> kind; ignored here.
const FLOW_RUN_EVENT_PREFIX: String = "event="
## DEV-ONLY: stable clock value (7:42) for run screen captures.
const DEV_ELAPSED_SEC: float = 462.0
const TEXT_MATCH_LABEL: String = "ui.run.match_label"
## Match label with the floor in front: "Tầng 2 · Trận 1/4".
const TEXT_FLOOR_MATCH_LABEL: String = "ui.run.floor_match_label"

## Flat run structure file, used only when [method configure] was not called (scratch tests can
## point it at a faster config before the node enters the tree). Empty = built-in defaults.
@export_file("*.json") var run_config_path: String = ""
## Display name of the floor this run plays ("Tầng 2"); shown in the match label. Set by GameFlow.
@export var floor_label: String = ""
## Story 024: chapters.json id of the run's chapter ("ch1"...); becomes match_params["chapter_id"] (piece drop weights).
@export var chapter_id: String = ""
## Player deck card ids for the battles (Story 019 fills it); empty = the default deck.
@export var deck: Array[String] = []
## Story 020: the deck as {id, level} entries; empty = use [member deck] (all level 1).
@export var deck_entries: Array[Dictionary] = []
## Story 018: the chosen character (a CharacterConfig.get_character dictionary); empty = the plain
## combat.json player (old behaviour). Becomes match_params["character"]; its starter_deck is the
## deck when [member deck] is empty. Set by GameFlow BEFORE add_child.
@export var character: Dictionary = {}
## Story 032: relic ids the run owns (received order); becomes match_params["relics"]. Empty = ask the
## parent (GameFlow.get_relics) when it has one, else no relics. Set BEFORE add_child (optional).
@export var relics: Array[String] = []
## Story 033: config overrides of the run's active run modifiers (RunSession.run_modifier_overrides, the
## RelicRegistry.merge_overrides form: key -> {add, mul[, set]}, e.g. {"step_cooldown": {"add": 0.0, "mul": 1.2}});
## becomes match_params["run_modifiers"] (absent when empty). Empty = ask the parent
## (GameFlow.get_run_modifier_overrides) when it has one. Set BEFORE add_child (optional).
@export var run_modifiers: Dictionary = {}
## Story 034: the run's piece deck (RunSession.piece_deck, a PieceDeck state); becomes match_params["piece_deck"]
## (absent when empty = original drop weights). Set by GameFlow BEFORE add_child (optional).
@export var piece_deck: Dictionary = {}
## Story 019: while true the INTRO timer does not tick (the battle stays frozen and drawn).
## GameFlow sets it before add_child on a resumed run whose saved card offer is still open and
## clears it when the offer is resolved. No effect outside INTRO.
@export var hold_intro: bool = false

var _config: RunConfig
var _state: RunState
var _battle: Node = null
var _intro_left: float = 0.0
var _between_left: float = 0.0
var _last_player_hp: float = 0.0
var _frozen: bool = false
var _paused: bool = false
## DEV-ONLY arena override for match 1 (empty = none).
var _dev_arena: Dictionary = {}


## Story 015: installs the floor's config BEFORE the node enters the tree. Starts at match
## [param start_match_index] with the retry/resume HP rule when the index is > 0 or
## [param hp_at_start] is >= 0 (see [method RunState.resume_at]); otherwise a fresh run at
## match 0 with full HP.
func configure(config: RunConfig, start_match_index: int, hp_at_start: float) -> void:
	_config = config
	_state = RunState.new(_config)
	if start_match_index > 0 or hp_at_start >= 0.0:
		_state.resume_at(start_match_index, hp_at_start, get_player_max_hp(), _config.retry_min_hp_ratio)


func _ready() -> void:
	if _state == null:
		_config = RunConfig.load_from_file(run_config_path)
		_state = RunState.new(_config)
	_state.phase_changed.connect(_on_state_phase_changed)
	var dev_match: int = -1
	var dev_run: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(MATCH_ARG):
			dev_match = clampi(int(arg.trim_prefix(MATCH_ARG)), 1, _state.get_match_count()) - 1
		elif arg.begins_with(RUN_ARG):
			dev_run = arg.trim_prefix(RUN_ARG)
			if FLOW_RUN_KINDS.has(dev_run) or dev_run.begins_with(FLOW_RUN_EVENT_PREFIX):
				dev_run = ""
		elif arg.begins_with(ARENA_ARG):
			var arena_text: String = arg.trim_prefix(ARENA_ARG)
			var wants_variant: bool = arena_text.ends_with(ARENA_VARIANT_SUFFIX)
			_dev_arena = {"shape": arena_text.trim_suffix(ARENA_VARIANT_SUFFIX)}
			if wants_variant:
				_dev_arena["variant"] = true
	if dev_run.is_empty():
		if dev_match > 0:
			_state.dev_jump(dev_match, RunState.Phase.INTRO, 0.0, -1.0)
		_start_match()
	else:
		_start_dev_phase(maxi(dev_match, 0), dev_run)


func _process(delta: float) -> void:
	if _paused:
		if _state.get_phase() != RunState.Phase.PLAYING:
			_clear_pause()
		return
	if _frozen:
		return
	match _state.get_phase():
		RunState.Phase.INTRO:
			if hold_intro:
				return
			_intro_left -= delta
			if _intro_left <= 0.0:
				_begin_playing()
		RunState.Phase.PLAYING:
			_state.tick(delta)
		RunState.Phase.BETWEEN:
			if _config.between_sec > 0.0:
				_between_left -= delta
				if _between_left <= 0.0:
					advance_requested()


## True while the battle is paused (Story 016).
func is_paused() -> bool:
	return _paused


## Story 016: true when [method set_paused] would pause now: phase PLAYING, not paused, a battle
## exists and its [method CombatView.can_pause] allows it.
func can_pause() -> bool:
	if _paused or _state.get_phase() != RunState.Phase.PLAYING:
		return false
	var view: CombatView = _get_view()
	return view != null and view.can_pause()


## Story 016: pauses / resumes the battle. Pausing needs phase PLAYING and ([param force] or
## [method can_pause]); resuming is always allowed. Emits [signal paused_changed] on a change.
func set_paused(paused: bool, force: bool = false) -> void:
	if paused == _paused:
		return
	if paused:
		if _state.get_phase() != RunState.Phase.PLAYING or _battle == null:
			return
		if not force and not can_pause():
			return
		_battle.process_mode = Node.PROCESS_MODE_DISABLED
		_paused = true
	else:
		_paused = false
		if _battle != null and _state.get_phase() == RunState.Phase.PLAYING:
			_battle.process_mode = Node.PROCESS_MODE_INHERIT
	paused_changed.emit(_paused)


## Story 016: resumes when paused, else pauses when allowed.
func toggle_pause() -> void:
	set_paused(not _paused)


## The run logic (phase, match index, clock, carried HP). Null before [method configure] / _ready.
func get_state() -> RunState:
	return _state


## The current battle instance (null only before _ready).
func get_battle() -> Node:
	return _battle


## Seconds of intro left (0 outside INTRO).
func get_intro_left() -> float:
	return maxf(_intro_left, 0.0) if _state.get_phase() == RunState.Phase.INTRO else 0.0


## Seconds until the between-matches screen advances alone (0 outside BETWEEN or when
## between_sec is 0 = button only).
func get_between_left() -> float:
	return maxf(_between_left, 0.0) if _state.get_phase() == RunState.Phase.BETWEEN else 0.0


## Player HP at the end of the last finished match.
func get_last_player_hp() -> float:
	return _last_player_hp


## The loaded run config.
func get_config() -> RunConfig:
	return _config


## Player max HP: from the current battle when one exists, else from combat.json (Story 015;
## needed by the resume rule before the first battle is spawned).
func get_player_max_hp() -> float:
	var view: CombatView = _get_view()
	if view != null and view.get_state() != null:
		return view.get_state().player_max_hp
	if character.has("max_hp"):
		return maxf(float(character["max_hp"]), 1.0)
	return CombatConfig.load_from_file().player_max_hp


## UI hook (button on the between-matches screen): goes to the next match now. Ignored
## outside BETWEEN.
func advance_requested() -> void:
	if _state.get_phase() != RunState.Phase.BETWEEN:
		return
	_state.advance()
	_start_match()


## UI hook (legacy win/lose button, scratch tests): frees the battle and starts a new run at
## match 1. No scene reload.
func restart_requested() -> void:
	_frozen = false
	_state.restart()
	_start_match()


## Story 015 retry rule (lose screen "Chơi lại trận"): replays the SAME match with the same arena
## seed, boss at full HP, player HP = max(HP at match start, retry_min_hp_ratio * max). Ignored
## outside LOST.
func retry_match() -> void:
	if _state.get_phase() != RunState.Phase.LOST:
		return
	_frozen = false
	_state.retry_match(get_player_max_hp(), _config.retry_min_hp_ratio)
	_start_match()


# Spawns the battle of the current match in INTRO (frozen) and starts the intro timer.
func _start_match() -> void:
	_spawn_battle()
	_intro_left = _config.intro_sec
	_frozen = false


func _begin_playing() -> void:
	if _battle != null:
		_battle.process_mode = Node.PROCESS_MODE_INHERIT
	_state.begin_playing()
	match_started.emit(_state.get_match_index(), _state.get_hp_at_match_start())


# Story 032: [member relics], else the parent run's relics (GameFlow.get_relics), else none.
func _relic_ids() -> Array[String]:
	var ids: Array[String] = []
	if not relics.is_empty():
		ids.assign(relics)
	elif get_parent() != null and get_parent().has_method("get_relics"):
		ids.assign(get_parent().call("get_relics") as Array)
	return ids


# Story 033: [member run_modifiers], else the parent run's (GameFlow.get_run_modifier_overrides), else {}.
func _run_modifier_overrides() -> Dictionary:
	if not run_modifiers.is_empty():
		return run_modifiers.duplicate(true)
	if get_parent() != null and get_parent().has_method("get_run_modifier_overrides"):
		var raw: Variant = get_parent().call("get_run_modifier_overrides")
		if typeof(raw) == TYPE_DICTIONARY:
			return (raw as Dictionary).duplicate(true)
	return {}


func _spawn_battle() -> void:
	_free_battle()
	_clear_pause()
	var battle: Node = (load(BATTLE_SCENE_PATH) as PackedScene).instantiate()
	var view := battle.get_node(COMBAT_VIEW_NODE) as CombatView
	# The match spec already carries "arena" and "arena_seed" (RunConfig.from_node).
	var params: Dictionary = _state.get_match_spec()
	params["end_delay_sec"] = _config.end_delay_sec
	if not _dev_arena.is_empty() and _state.get_match_index() == 0:
		params["arena"] = _dev_arena.duplicate()
	params["player_hp"] = _state.get_carried_hp()
	params["floor_label"] = floor_label
	params["chapter_id"] = chapter_id
	if not character.is_empty():
		params["character"] = character.duplicate(true)
	var relic_ids: Array[String] = _relic_ids()
	if not relic_ids.is_empty():
		params["relics"] = relic_ids
	var modifier_overrides: Dictionary = _run_modifier_overrides()
	if not modifier_overrides.is_empty():
		params["run_modifiers"] = modifier_overrides
	if not piece_deck.is_empty():
		params["piece_deck"] = piece_deck.duplicate(true)
	if not deck_entries.is_empty():
		params["deck"] = deck_entries.duplicate(true)
	elif not deck.is_empty():
		params["deck"] = deck.duplicate()
	elif character.has("starter_deck"):
		params["deck"] = (character["starter_deck"] as Array).duplicate()
	params["match_label"] = _match_label()
	view.match_params = params
	view.match_ended.connect(_on_match_ended)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(battle)
	_battle = battle
	battle_spawned.emit(battle)


func _match_label() -> String:
	var index: int = _state.get_match_index() + 1
	var count: int = _state.get_match_count()
	if floor_label.is_empty():
		return tr(TEXT_MATCH_LABEL) % [index, count]
	return tr(TEXT_FLOOR_MATCH_LABEL) % [floor_label, index, count]


# Drops the pause flag (emits when it was set); does not touch process_mode.
func _clear_pause() -> void:
	if _paused:
		_paused = false
		paused_changed.emit(false)


func _free_battle() -> void:
	if _battle == null:
		return
	remove_child(_battle)
	_battle.queue_free()
	_battle = null


func _on_match_ended(player_won: bool, player_hp: float) -> void:
	if _state.get_phase() != RunState.Phase.PLAYING:
		return
	_last_player_hp = player_hp
	_clear_pause()
	_freeze_battle()
	if player_won:
		var view: CombatView = _get_view()
		var passive_heal: float = view.get_passive_heal() if view != null else 0.0
		_state.on_match_won(player_hp + passive_heal, get_player_max_hp())
		_between_left = _config.between_sec
	else:
		_state.on_match_lost()


func _freeze_battle() -> void:
	if _battle != null:
		_battle.process_mode = Node.PROCESS_MODE_DISABLED


# The current battle's CombatView, or null when no battle is spawned.
func _get_view() -> CombatView:
	if _battle == null:
		return null
	return _battle.get_node_or_null(COMBAT_VIEW_NODE) as CombatView


func _on_state_phase_changed(phase: int) -> void:
	phase_changed.emit(phase)


# DEV-ONLY: builds the battle for the match and puts the run into [param kind]; frozen.
func _start_dev_phase(match_index: int, kind: String) -> void:
	var last: int = _state.get_match_count() - 1
	var index: int = last if kind == "won" else match_index
	_state.dev_jump(index, RunState.Phase.PLAYING, DEV_ELAPSED_SEC, -1.0)
	_spawn_battle()
	_frozen = true
	var view: CombatView = _get_view()
	match kind:
		"intro":
			_state.dev_jump(index, RunState.Phase.INTRO, DEV_ELAPSED_SEC, -1.0)
			_intro_left = _config.intro_sec
		"between":
			view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
			_last_player_hp = view.get_player_hp()
			_state.on_match_won(_last_player_hp, view.get_state().player_max_hp)
			_between_left = _config.between_sec
		"won":
			view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
			_last_player_hp = view.get_player_hp()
			_state.on_match_won(_last_player_hp, view.get_state().player_max_hp)
		"lost":
			view.get_state().damage(CombatState.Side.PLAYER, 999999.0)
			_last_player_hp = 0.0
			_state.on_match_lost()
		_:
			push_warning("RunController: unknown --run=%s (intro|between|won|lost)" % kind)
			_frozen = false
			_state.dev_jump(match_index, RunState.Phase.INTRO, 0.0, -1.0)
			_intro_left = _config.intro_sec
