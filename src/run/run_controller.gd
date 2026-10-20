class_name RunController
extends Node2D
## Owns one run: a RunState, and the current battle (a fresh instance of battle.tscn per match,
## so every match starts from clean grid/hand/bag/cooldown/status/brain/learning state).
## Flow: INTRO (battle frozen, still drawn) -> PLAYING -> match_ended -> BETWEEN (next match
## after between_sec or [method advance_requested]) or WON / LOST (waits for
## [method restart_requested]). The controller draws nothing; the run screens read its getters.
## Implements: Story 011.
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

const BATTLE_SCENE_PATH: String = "res://src/battle/battle.tscn"
const COMBAT_VIEW_NODE: String = "CombatView"
const MATCH_ARG: String = "--match="
const RUN_ARG: String = "--run="
const ARENA_ARG: String = "--arena="
const ARENA_VARIANT_SUFFIX: String = ":variant"
## DEV-ONLY: stable clock value (7:42) for run screen captures.
const DEV_ELAPSED_SEC: float = 462.0

## Run structure file; tests can point it at a faster config before the node enters the tree.
@export_file("*.json") var run_config_path: String = RunConfig.DEFAULT_PATH

var _config: RunConfig
var _state: RunState
var _battle: Node = null
var _intro_left: float = 0.0
var _between_left: float = 0.0
var _last_player_hp: float = 0.0
var _frozen: bool = false
## DEV-ONLY arena override for match 1 (empty = none).
var _dev_arena: Dictionary = {}


func _ready() -> void:
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
	if _frozen:
		return
	match _state.get_phase():
		RunState.Phase.INTRO:
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


## The run logic (phase, match index, clock, carried HP).
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


## UI hook (button on the between-matches screen): goes to the next match now. Ignored
## outside BETWEEN.
func advance_requested() -> void:
	if _state.get_phase() != RunState.Phase.BETWEEN:
		return
	_state.advance()
	_start_match()


## UI hook (button on the win/lose screens): frees the battle and starts a new run at
## match 1. No scene reload.
func restart_requested() -> void:
	_frozen = false
	_state.restart()
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


func _spawn_battle() -> void:
	_free_battle()
	var battle: Node = (load(BATTLE_SCENE_PATH) as PackedScene).instantiate()
	var view := battle.get_node(COMBAT_VIEW_NODE) as CombatView
	var params: Dictionary = _state.get_match_spec()
	params["end_delay_sec"] = _config.end_delay_sec
	if not _dev_arena.is_empty() and _state.get_match_index() == 0:
		params["arena"] = _dev_arena.duplicate()
	params["player_hp"] = _state.get_carried_hp()
	params["match_label"] = "Trận %d/%d" % [_state.get_match_index() + 1, _state.get_match_count()]
	view.match_params = params
	view.match_ended.connect(_on_match_ended)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(battle)
	_battle = battle
	battle_spawned.emit(battle)


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
	_freeze_battle()
	if player_won:
		_state.on_match_won(player_hp, _get_view().get_state().player_max_hp)
		_between_left = _config.between_sec
	else:
		_state.on_match_lost()


func _freeze_battle() -> void:
	if _battle != null:
		_battle.process_mode = Node.PROCESS_MODE_DISABLED


func _get_view() -> CombatView:
	return _battle.get_node(COMBAT_VIEW_NODE) as CombatView


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
