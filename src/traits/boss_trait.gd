class_name BossTrait
extends RefCounted
## Base class of a pluggable boss trait (Story 014 Part B): one self-contained mechanic that a
## match switches on from chapters.json (`traits: [{id, params}]`). A trait reads and writes the
## battle ONLY through the public APIs handed over in the context of [method setup]; it never
## touches private members and never edits BossBrain (the brain sees the consequences, burning
## cells or rotten points, through the APIs it already uses).
## Lifetime: the TraitHost owned by CombatView creates a fresh instance per match, forwards the
## hooks below, and calls [method teardown] when the battle leaves the tree. A trait must not
## keep references past teardown and must not share state across matches.
##
## Context keys (`ctx` of [method setup]):
## - `state`: CombatState (HP, unit cells, damage()).
## - `grid`: BoardGrid (halves, real cells, labels).
## - `player_drops` / `boss_drops`: FieldDrops of the player's / the boss's half.
## - `boss`: BossController (actor, hand, drops, brain; treat as read-only).
## - `status`: StatusEffects (ignite, pin, burning_cells).
## - `arbiter`: SwingArbiter (read-only).
## - `hold_getter`: Callable returning the player's HoldSlots, or null until its view is ready
##   (use [method get_player_hold]).
## - `skill_config`: SkillConfig, `cut_config`: CutConfig.
## Every tuning number comes from `params` (chapters.json) with the trait's own defaults; read them
## with [method param_float] / [method param_int] / [method param_string] / [method param_bool].
## Time reaches a trait only through [method on_tick] in SCALED simulation seconds, so Focus
## and skill-menu slow motion slow traits too; the host ticks traits after the SwingArbiter, so
## a trait sees this frame's resolutions, and not at all once either unit is dead.
## Randomness: use [member rng] only (seeded by the host from the match seed, the trait's index
## and [method seed_offset]); a negative seed means random.
## Implements: Story 014 (Part B).

## Seed distance between the RNG streams of two traits of one match (host index stride).
const SEED_STRIDE: int = 1009

## Seeded RNG of this trait; never use the global randi()/randf().
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _ctx: Dictionary = {}
var _params: Dictionary = {}
var _seed_value: int = -1


## Stores the context and params and seeds [member rng] from [param seed_value] (negative =
## random) plus [method seed_offset]. Called once by the host, before [method on_match_start].
## Override to cache params; call super first.
func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	_ctx = ctx
	_params = params.duplicate(true)
	_seed_value = seed_value
	if seed_value >= 0:
		rng.seed = seed_value + seed_offset()
	else:
		rng.randomize()


## Stable id of this trait (the TraitRegistry key). Subclasses must override.
func get_id() -> String:
	return ""


## Per-class seed offset so two different traits never share an RNG stream. Override.
func seed_offset() -> int:
	return 0


## Debug / HUD snapshot of the trait's state (any keys). Default: {id}.
func get_debug() -> Dictionary:
	return {"id": get_id()}


## Called once after all hooks are wired and the match objects exist (the battle may still be
## frozen in its intro; no time has passed).
func on_match_start() -> void:
	pass


## Called once per frame with the SCALED simulation step (seconds), after the arbiter ticked.
func on_tick(_step: float) -> void:
	pass


## The boss's cut actor started a swing over [param _cells] with [param _skill_id].
func on_boss_swing_started(_cells: Array[Vector2i], _skill_id: String) -> void:
	pass


## A boss swing resolved; [param _result] is SwingArbiter's {hit, damage, pushed, cell, cells,
## skill_id, burning, pinned}.
func on_boss_swing_resolved(_result: Dictionary) -> void:
	pass


## A player swing resolved; same shape as [method on_boss_swing_resolved].
func on_player_swing_resolved(_result: Dictionary) -> void:
	pass


## A point landed on the half of [param _side] (CombatState.Side); rotten points included
## (check `point.rotten`).
func on_point_spawned(_side: int, _point: FieldPoint) -> void:
	pass


## The boss took [param _amount] HP from a player swing. Burn ticks on the boss are NOT
## reported (StatusEffects has no damage signal); read `state.enemy_hp` in on_tick if needed.
func on_boss_damaged(_amount: float) -> void:
	pass


## Drops every reference (context, params). Called once by the host when the battle ends.
## Override to disconnect signals; call super last.
func teardown() -> void:
	_ctx = {}
	_params = {}


## The context dictionary given at setup (empty after teardown).
func get_context() -> Dictionary:
	return _ctx


## The params given at setup (a deep copy; empty after teardown).
func get_params() -> Dictionary:
	return _params


## The player's HoldSlots through the context's `hold_getter`, or null when not available.
func get_player_hold() -> HoldSlots:
	var getter: Variant = _ctx.get("hold_getter")
	if typeof(getter) != TYPE_CALLABLE or not (getter as Callable).is_valid():
		return null
	return (getter as Callable).call() as HoldSlots


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


## String param [param key], or [param fallback] when absent.
func param_string(key: String, fallback: String) -> String:
	var value: Variant = _params.get(key)
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return str(value)
	return fallback


## Boolean param [param key], or [param fallback] when absent or not a bool.
func param_bool(key: String, fallback: bool) -> bool:
	var value: Variant = _params.get(key)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback
