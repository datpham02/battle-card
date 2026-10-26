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


## Story 037: advances the passive's own clock by [param dt] SIMULATION seconds (CombatView calls it once per
## simulation step; default: nothing).
func tick(_dt: float) -> void:
	pass


## Story 037: the BOSS stepped onto a thorn cell of the player's zone (StatusEffects.thorn_entered on the enemy
## side), standing on [param cell]. Default: nothing.
func on_boss_thorn_step(_cell: Vector2i) -> void:
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
