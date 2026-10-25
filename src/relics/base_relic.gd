class_name BaseRelic
extends RefCounted
## Base class of a relic (Story 032): a passive rule the player carries through the whole run
## (relics.json `script` + `params`). CombatView creates one instance per relic per match through
## RelicRegistry and forwards the hooks; every default is NEUTRAL (returns its input / does nothing),
## and the numbers come from `params` (script constants are fallbacks only).
##
## `cast_info` (Dictionary, built by the combat wave, one per player cast):
##   `pieces` Array[String] shape ids of the pieces joined into the cast, `cells` int, `joined` bool
##   (two or more pieces were joined), `featured` bool (the featured-shape bonus applied),
##   `card_id` String, `hit` bool (the cut hit the boss; only meaningful in [method on_cast_landed]).
##
## Context keys (`ctx` of [method setup]) are documented in each concrete relic's header. A relic
## must tolerate a missing key (does nothing). RelicRegistry.instantiate calls `setup({}, params)`
## so [method config_overrides] works BEFORE the match objects exist; CombatView later calls
## `setup(real_ctx, relic.get_params())` again (setup is idempotent and resets per-match counters).
## Implements: Story 032.

## Emitted when the relic acts, for the in-match HUD flash (relic id).
signal triggered(relic_id: String)

## The neutral join limit (two pieces per cast).
const BASE_JOIN_PIECES: int = 2

var _ctx: Dictionary = {}
var _params: Dictionary = {}
var _relic_id: String = ""


## Stores the context and params. Override to cache params and reset per-match state; call super.
func setup(ctx: Dictionary, params: Dictionary) -> void:
	_ctx = ctx
	_params = params.duplicate(true)


## The relic's id (relics.json `id`; RelicRegistry.instantiate sets it, concrete relics have a
## default). Empty for a bare instance.
func get_id() -> String:
	return _relic_id


## Sets the relic id (used by RelicRegistry.instantiate, as one script can serve many ids).
func set_relic_id(relic_id: String) -> void:
	_relic_id = relic_id


## Called once after the match objects exist (no time has passed).
func on_match_start() -> void:
	pass


## The damage of a player cast. [param damage] is the value so far; returns the value to use
## (default: unchanged). Call once per cast; relics are expected to be multiplicative
## (see RelicRegistry.fold_damage, which caps the product).
func modify_cast_damage(_cast_info: Dictionary, damage: float) -> float:
	return damage


## The windup seconds [param sec] of a player cast; returns the seconds to use (default: unchanged).
## Called once per cast.
func modify_cast_time(_cast_info: Dictionary, sec: float) -> float:
	return sec


## Called after a player cast resolved (hit or miss, `cast_info.hit`).
func on_cast_landed(_cast_info: Dictionary) -> void:
	pass


## Called when the player joined pieces into one cast (`cast_info.joined` is true).
func on_join(_cast_info: Dictionary) -> void:
	pass


## Called when the player interrupted a boss spell.
func on_interrupt_by_player() -> void:
	pass


## Named config changes of this relic, key -> `{mul: x}` / `{add: x}` / `{add: a, mul: m}` / `{set: v}`.
## Canonical keys: seal_sec, thorn_ran, piece_freshness_sec, start_pieces, focus_sec, formation_fade,
## signature_cooldown, hold_slots, piece_spawn_interval, burn_max_stacks, han_stacks, han_damage.
## Pure function of the params (no ctx needed). Default: none.
func config_overrides() -> Dictionary:
	return {}


## How many pieces the player may join into one cast (default [constant BASE_JOIN_PIECES]).
func max_join_pieces() -> int:
	return BASE_JOIN_PIECES


## The featured-shape damage multiplier this relic imposes, or 0.0 for none (default).
func featured_mult_override() -> float:
	return 0.0


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


## String param [param key], or [param fallback] when absent or not a string.
func param_string(key: String, fallback: String) -> String:
	var value: Variant = _params.get(key)
	if typeof(value) == TYPE_STRING:
		return value as String
	return fallback


## Calls the Callable stored at `_ctx[key]` with [param args]; returns its result, or null when
## the key is missing or not callable (the relic then just does nothing).
func _call_ctx(key: String, args: Array = []) -> Variant:
	var callable: Variant = _ctx.get(key)
	if typeof(callable) != TYPE_CALLABLE or not (callable as Callable).is_valid():
		return null
	return (callable as Callable).callv(args)
