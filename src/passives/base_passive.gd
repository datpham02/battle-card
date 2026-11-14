class_name BasePassive
extends RefCounted
## Base class of a pluggable character passive (Story 018), the sibling of BossTrait: one
## self-contained rule a character brings into every match (characters.json
## `passive: {id, params}`). CombatView creates ONE instance per match through PassiveRegistry and
## forwards the hooks; the numbers come from `params` (the script constants are fallbacks only).
## Hooks are pure where possible: [method modify_swing_duration] and [method modify_damage] apply to
## the PLAYER's swings only (the boss never sees them).
##
## Context keys (`ctx` of [method setup]): `state` CombatState, `grid` BoardGrid, `boss`
## BossController (read-only), `status` StatusEffects, `skill_config`, `cut_config`; Story 037 adds
## `heal_player` Callable(amount: float) -> Variant (heals the player, clamped to max HP; optional).
## Implements: Story 018.

var _ctx: Dictionary = {}
var _params: Dictionary = {}
var _cue_pending: bool = false


## Stores the context and params. Called once, before [method on_match_start]. Override to cache
## params; call super first.
func setup(ctx: Dictionary, params: Dictionary) -> void:
	_ctx = ctx
	_params = params.duplicate(true)


## Stable id of this passive (the PassiveRegistry key). Subclasses override.
func get_id() -> String:
	return ""


## Called once after the match objects exist (no time has passed).
func on_match_start() -> void:
	pass


## Called once when the player won the match; returns EXTRA HP to heal on top of the run's
## between-match heal (default 0.0).
func on_match_won() -> float:
	return 0.0


## The windup [param duration] of a player swing over [param cells] cells; returns the duration
## to use (default: unchanged).
func modify_swing_duration(_cells: int, duration: float) -> float:
	return duration


## The final damage number [param damage] of a player hit over [param cells] cells; returns the
## damage to apply (default: unchanged).
func modify_damage(_cells: int, damage: float) -> float:
	return damage


## F3 (passive feedback): true when this passive's cue should play for a cast or hit covering
## [param cells] cells. The PASSIVE answers, never the view.
##
## The condition lives next to the rule it mirrors on purpose. A view that re-implemented
## `cells >= min_cells` would keep saying yes after someone tuned the number in characters.json, and
## the cue would mark the wrong casts while every test still passed — the player would be taught a
## rule the game no longer follows.
##
## Default false: a passive whose trigger is not a cell count (second_wind fires on a won match,
## hunter_mark on a thorn event, prayer on a Chill burst) has no per-cast cue and must not claim one.
func cue_for_cells(_cells: int) -> bool:
	return false


## F3 (passive feedback): raised by a subclass the moment its rule actually fires, for the passives
## whose trigger is an EVENT rather than a cell count (hunter_mark marking the boss, and any later
## passive of the same shape). [method cue_for_cells] cannot serve them: there is no cast to measure.
##
## One-shot by design. [method take_event_cue] clears it, so one firing of the rule draws exactly one
## cue; a view that polled a sticky flag would redraw the cue every frame until the next mark, which
## reads as "the passive is firing continuously" and teaches the player the wrong frequency.
func fire_event_cue() -> void:
	_cue_pending = true


## F3: true ONCE per [method fire_event_cue], then false until the rule fires again. CombatView drains
## it on each simulation step; nothing else may call it, or the cue is swallowed before it is drawn.
func take_event_cue() -> bool:
	if not _cue_pending:
		return false
	_cue_pending = false
	return true


## Story 037: advances the passive's own clock by [param dt] SIMULATION seconds (CombatView calls it once per
## simulation step; default: nothing).
func tick(_dt: float) -> void:
	pass


## Story 037: the BOSS stepped onto a thorn cell of the player's zone (StatusEffects.thorn_entered on the enemy
## side), standing on [param cell]. Default: nothing.
# Multi-enemy: [param _key] is the unit that stepped on the thorns (the mark belongs to the unit that
# caused it). Default = the old value, unit 0, so every existing caller behaves exactly as before - not
# merely parses, which is a different and weaker promise.
func on_boss_thorn_step(_cell: Vector2i, _key: int = CombatState.Side.ENEMY) -> void:
	pass


## Story 037: the player formed a zone ([param kind] "seal" or "thorns", StatusEffects.KIND_*) on the boss's half;
## [param cells] are the cells actually placed. Default: nothing.
func on_player_zone_formed(_kind: String, _cells: Array[Vector2i]) -> void:
	pass


## Story 037: a Han burst fired on the boss for [param damage]. Default: nothing.
func on_frost_burst(_damage: float) -> void:
	pass


## Drops every reference. Called when the battle leaves the tree. Override, then call super.
func teardown() -> void:
	_ctx = {}
	_params = {}
	_cue_pending = false


## The params given at setup (empty after teardown).
func get_params() -> Dictionary:
	return _params


## Float param [param key], or [param fallback] when absent or not a number.
func param_float(key: String, fallback: float) -> float:
	var value: Variant = _params.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


## Integer param [param key], or [param fallback] when absent or not a number.
func param_int(key: String, fallback: int) -> int:
	var value: Variant = _params.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return fallback
