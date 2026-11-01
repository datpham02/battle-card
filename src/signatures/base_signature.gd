class_name BaseSignature
extends RefCounted
## Base class of a pluggable character signature skill (Story 021), the sibling of BasePassive:
## one ACTIVE rule the player triggers once the formation map is complete (Story 029; characters.json
## `signature: {id, name_key, desc_key, params}`). CombatView creates ONE instance per match through
## SignatureRegistry and forwards the hooks; numbers come from `params` (script constants are
## fallbacks only).
##
## Damage order at a player hit (CutEffects.apply): card damage_per_cell x [method modify_cells]
## -> Ghim (pinned multiplier) -> passive modify_damage -> signature [method modify_damage].
## So the passive applies first, the signature last.
##
## Context keys (`ctx` of [method setup]): `state` CombatState, `grid` BoardGrid, `boss`
## BossController (read-only), `status` StatusEffects, `skill_config`, `cut_config`, `cooldowns`
## SkillCooldowns (the player's).
## Implements: Story 021.

var _ctx: Dictionary = {}
var _params: Dictionary = {}


## Stores the context and params. Called once. Override to cache params; call super first.
func setup(ctx: Dictionary, params: Dictionary) -> void:
	_ctx = ctx
	_params = params.duplicate(true)


## Stable id of this signature (the SignatureRegistry key). Subclasses override.
func get_id() -> String:
	return ""


## Triggers the skill (the signature was already ready; the host clears the ready flag). Instant skills
## do their work here; timed ones start their timer.
func activate() -> void:
	pass


## Advances the active timer by [param dt] simulation seconds.
func tick(_dt: float) -> void:
	pass


## The cell count used for card damage (the swing still covers the real [param cells]).
func modify_cells(cells: int) -> int:
	return cells


## The final damage of a player hit; [param cells] is the REAL cut size, [param target_pinned]
## whether the boss is pinned. Applied last (after Ghim and the passive).
func modify_damage(_card_id: String, _cells: int, damage: float, _target_pinned: bool) -> float:
	return damage


## Called when a player swing STARTS (the cast).
func on_cast(_card_id: String, _cells: int) -> void:
	pass


## Called after a player hit landed with [param damage] dealt to the boss.
func on_hit(_card_id: String, _damage: float) -> void:
	pass


## Multiplier of the player's step cooldown (1.0 = normal, 0.0 = free steps).
func step_cooldown_scale() -> float:
	return 1.0


## Story 037: multiplier of the duration of the thorns the PLAYER forms (1.0 = unchanged; seals are no
## longer lengthened, quick spec 2026-10-31). Read by CutEffects at the moment a zone card's swing arrives.
func zone_sec_mult() -> float:
	return 1.0


## Quick spec 2026-10-31: extra thorn cells each PLAYER thorn card lays (0 = none). Read by CutEffects
## (CutEffects.extra_thorn_cells picks the cells) at the moment the swing arrives.
func extra_thorn_cells() -> int:
	return 0


## Story 037: damage multiplier ONE consumed Ran stack of the boss gives instead of the config's fragile_mult
## (0.0 = use the config's). Read by StatusEffects.consume_fragile.
func fragile_mult_override() -> float:
	return 0.0


## Story 037: multiplier of a Han burst on the boss (1.0 = unchanged). Read by StatusEffects.apply_frost.
func frost_burst_mult() -> float:
	return 1.0


## True while a timed effect runs.
func is_active() -> bool:
	return false


## Seconds of the timed effect left (0 when inactive or instant).
func time_left() -> float:
	return 0.0


## Total length of the timed effect (0 for instant skills).
func duration() -> float:
	return 0.0


## Drops every reference. Override, then call super.
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
