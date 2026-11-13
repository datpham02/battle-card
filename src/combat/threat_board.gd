class_name ThreatBoard
extends RefCounted
## Multi-enemy Phase 3 (D1, docs/design/world-map-v2/MULTI-ENEMY-PHASE3-5-PLAN.md 1.1b): the ONE threat book of a match,
## shared by every enemy unit's agent.
## - Attack tokens: at most [member attack_slots] units may be in an attack at once (a block-brain swing from its start to
##   its resolve / cancel, a pattern skill from its windup to its recovery). A unit asks with [method request] before it
##   starts and gives the token back with [method release].
## - F2 (shared red cap): [method red_cells] is the union of every OTHER unit's red / queued cells plus the trait warnings,
##   the "other red" a PatternController counts against `max_red_ratio`.
## - F5 (shared warning gap): [method note_warning] stamps any unit's new warning; [method since_warning] is the time since
##   the last one, whoever made it.
## With ONE enemy unit the board never refuses ([member shared] false): the single-enemy match runs exactly as before.

## Most units attacking at once (formation `attack_slots`; >= 1).
var attack_slots: int = 1
## True with two or more enemy units: tokens and the shared F5 apply. False = every request succeeds and the pattern
## controllers keep their own F5 clock (the pre-Phase-3 behaviour).
var shared: bool = false
## Callable() -> Array: warning cells of the traits (CombatView.trait_warning_cells); invalid = none.
var extra_red_fn: Callable = Callable()

var _holders: Dictionary = {}  # unit key -> true
var _red_sources: Dictionary = {}  # unit key -> Callable() -> Array (that unit's red + queued cells now)
var _since_warning: float = 1000.0


## [param slots] attack tokens for [param unit_count] enemy units (shared when 2+).
func _init(slots: int = 1, unit_count: int = 1) -> void:
	attack_slots = maxi(slots, 1)
	shared = unit_count > 1


## Asks a token for the unit of [param key]: true when it already holds one or one is free (always true when not
## [member shared]); the token is then held until [method release].
func request(key: int) -> bool:
	if not shared:
		return true
	if _holders.has(key):
		return true
	if _holders.size() >= attack_slots:
		return false
	_holders[key] = true
	return true


## Gives the token of [param key] back (no-op when it holds none).
func release(key: int) -> void:
	_holders.erase(key)


## True while the unit of [param key] holds a token.
func holds(key: int) -> bool:
	return _holders.has(key)


## Number of tokens held now.
func holder_count() -> int:
	return _holders.size()


## Registers the red-cell source of the unit of [param key] (Callable() -> Array of Vector2i).
func register_red(key: int, source: Callable) -> void:
	_red_sources[key] = source


## The cells red or queued now by every unit except [param exclude_key] (-1 = none excluded), plus the trait warnings;
## each cell once, source order.
func red_cells(exclude_key: int = -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if extra_red_fn.is_valid():
		for c: Variant in extra_red_fn.call() as Array:
			if not out.has(c as Vector2i):
				out.append(c as Vector2i)
	var keys: Array = _red_sources.keys()
	keys.sort()
	for key: Variant in keys:
		if int(key) == exclude_key:
			continue
		var source: Callable = _red_sources[key] as Callable
		if not source.is_valid():
			continue
		for c: Variant in source.call() as Array:
			if not out.has(c as Vector2i):
				out.append(c as Vector2i)
	return out


## Stamps a new warning (any unit): resets the shared F5 clock.
func note_warning() -> void:
	_since_warning = 0.0


## Seconds since the last warning of any unit (1000 before the first).
func since_warning() -> float:
	return _since_warning


## Advances the shared F5 clock by [param delta] (scaled simulation seconds; CombatView ticks it once per frame).
func tick(delta: float) -> void:
	if delta > 0.0:
		_since_warning += delta


## Drops every token (match end, a unit removed).
func clear() -> void:
	_holders.clear()
