class_name RunState
extends RefCounted
## Pure logic of one run: which match is on, the phase, HP carried between matches and the
## elapsed play time. No scene dependency. Implements: Story 011.

## Where the run is. INTRO: match shown, frozen. PLAYING: fighting (the clock runs).
## BETWEEN: won a non-final match. WON: won the boss match. LOST: player died.
enum Phase { INTRO, PLAYING, BETWEEN, WON, LOST }

## Emitted after the phase changed; [param phase] is a [enum Phase] value.
signal phase_changed(phase: int)

var _config: RunConfig
var _index: int = 0
var _phase: Phase = Phase.INTRO
var _elapsed: float = 0.0
var _carried_hp: float = -1.0


func _init(config: RunConfig) -> void:
	_config = config
	start_run()


## Starts a new run: match 0, INTRO, clock 0, no carried HP.
func start_run() -> void:
	_index = 0
	_elapsed = 0.0
	_carried_hp = -1.0
	_set_phase(Phase.INTRO)


## Same as [method start_run] (a fresh run without leaving the game).
func restart() -> void:
	start_run()


## Zero-based index of the current match.
func get_match_index() -> int:
	return _index


## Number of matches in the run.
func get_match_count() -> int:
	return _config.match_count()


## Copy of the current match entry of the config (see RunConfig.MATCH_KEYS).
func get_match_spec() -> Dictionary:
	return (_config.matches[_index] as Dictionary).duplicate()


## True on the last (boss) match.
func is_boss_match() -> bool:
	return _index == get_match_count() - 1


## Current phase.
func get_phase() -> Phase:
	return _phase


## INTRO -> PLAYING (ignored in other phases).
func begin_playing() -> void:
	if _phase == Phase.INTRO:
		_set_phase(Phase.PLAYING)


## The player won the current match: WON on the last match, otherwise BETWEEN with the HP
## carried = min(hp + heal, max). Ignored unless PLAYING.
func on_match_won(player_hp: float, player_max_hp: float) -> void:
	if _phase != Phase.PLAYING:
		return
	if is_boss_match():
		_set_phase(Phase.WON)
		return
	_carried_hp = minf(player_hp + _config.heal_between_matches, player_max_hp)
	_set_phase(Phase.BETWEEN)


## The player died: LOST. Ignored unless PLAYING.
func on_match_lost() -> void:
	if _phase == Phase.PLAYING:
		_set_phase(Phase.LOST)


## BETWEEN -> next match, INTRO (ignored in other phases).
func advance() -> void:
	if _phase != Phase.BETWEEN:
		return
	_index += 1
	_set_phase(Phase.INTRO)


## Player HP to start the current match with; negative = start at full HP.
func get_carried_hp() -> float:
	return _carried_hp


## Adds [param real_delta] to the run clock, only while PLAYING.
func tick(real_delta: float) -> void:
	if _phase == Phase.PLAYING:
		_elapsed += real_delta


## Seconds of PLAYING time so far.
func get_elapsed_sec() -> float:
	return _elapsed


## Elapsed time as m:ss (seconds floored).
func get_elapsed_text() -> String:
	var total: int = floori(_elapsed)
	var minutes: int = floori(total / 60.0)
	return "%d:%02d" % [minutes, total - minutes * 60]


## DEV-ONLY (screenshots): jumps straight to [param match_index] / [param phase] with the given
## clock and carried HP (negative = full), without emitting phase_changed.
func dev_jump(match_index: int, phase: Phase, elapsed_sec: float, carried_hp: float) -> void:
	_index = clampi(match_index, 0, get_match_count() - 1)
	_phase = phase
	_elapsed = elapsed_sec
	_carried_hp = carried_hp


func _set_phase(phase: Phase) -> void:
	_phase = phase
	phase_changed.emit(phase)
