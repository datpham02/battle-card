class_name ParryGuard
extends RefCounted
## The hero's parry guard (cast rhythm spec 2026-11-05 section 1.1 `parry`, design/quick-specs/nhip-ra-chieu-2026-11-05.md;
## the Knight's Do Kiem). A `parry` card opens it for parry_sec of MATCH time ([method open], called when the card is
## chosen; the cast stop freezes the match, so the window starts when the match runs again). While it is open the next
## ENEMY SKILL hit on the hero ([method try_parry]: PatternController strikes and block-brain boss swings, never burn
## ticks, thorn steps, trait blasts or relic damage) deals 0, the enemy takes reflect_mult x that hit's damage and is
## pinned parry_pin_sec (StatusEffects.pin, so `target_pinned` crit cards pay off). No hit before it closes: nothing.
## Pure logic: the clock advances only through [method tick] with the scaled match delta.

## The guard opened for [param sec] seconds.
signal opened(sec: float)
## An enemy hit was parried: [param blocked] damage it would have dealt, [param reflected] damage the enemy took,
## [param pin_sec] seconds it is pinned.
signal parried(blocked: float, reflected: float, pin_sec: float)
## The window ran out without a hit.
signal expired

var _left: float = 0.0
var _total: float = 0.0
var _reflect_mult: float = 0.0
var _pin_sec: float = 0.0
## Parries landed this match (stats, sim).
var parries: int = 0
## Guards opened this match (stats, sim).
var opens: int = 0


## Opens (or re-opens) the guard with the numbers of resolved parry card [param card]
## (parry_sec, reflect_mult, parry_pin_sec; SkillConfig.PARRY_DEFAULTS when absent). A parry_sec of 0 opens nothing.
func open_from_card(card: Dictionary) -> void:
	open(float(card.get("parry_sec", SkillConfig.PARRY_DEFAULTS["parry_sec"])),
		float(card.get("reflect_mult", SkillConfig.PARRY_DEFAULTS["reflect_mult"])),
		float(card.get("parry_pin_sec", SkillConfig.PARRY_DEFAULTS["parry_pin_sec"])))


## Opens the guard for [param sec] match seconds with [param reflect_mult] and [param pin_sec]; replaces an open one.
func open(sec: float, reflect_mult: float, pin_sec: float) -> void:
	if sec <= 0.0:
		return
	_left = sec
	_total = sec
	_reflect_mult = maxf(reflect_mult, 0.0)
	_pin_sec = maxf(pin_sec, 0.0)
	opens += 1
	opened.emit(sec)


## Advances the window by [param delta] match seconds; emits [signal expired] when it runs out unused.
func tick(delta: float) -> void:
	if _left <= 0.0 or delta <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	if _left <= 0.0:
		_total = 0.0
		expired.emit()


## True while the guard is open.
func is_active() -> bool:
	return _left > 0.0


## Seconds of guard left (0 when closed).
func get_left() -> float:
	return _left


## Share of the window still left, 1 -> 0 (0 when closed); the view's timer bar.
func fraction_left() -> float:
	return 0.0 if _total <= 0.0 else clampf(_left / _total, 0.0, 1.0)


## Closes the guard without a parry (match end, tests).
func clear() -> void:
	_left = 0.0
	_total = 0.0


## An enemy skill hit of [param damage] lands on the hero now. When the guard is open: closes it, damages the ENEMY by
## reflect_mult x [param damage] through [param state] and pins it for parry_pin_sec through [param status] (may be
## null: no pin), and returns {parried: true, blocked, reflected, pin_sec}; the CALLER deals the hero 0 and skips the
## hit's status. Closed: {parried: false}.
## Multi-enemy Phase 3: [param attacker_key] = the unit KEY that struck (1 = unit 0, the pre-Phase-3 target); the reflect
## and the pin land on that unit only.
func try_parry(state: CombatState, status: StatusEffects, damage: float, attacker_key: int = CombatState.Side.ENEMY) -> Dictionary:
	if not is_active() or state == null:
		return {"parried": false}
	var blocked: float = maxf(damage, 0.0)
	var reflect: float = blocked * _reflect_mult
	var pin_sec: float = _pin_sec
	clear()
	var hp_before: float = state.hp_of(attacker_key)
	if reflect > 0.0 and not state.is_key_dead(attacker_key):
		state.damage(attacker_key, reflect)
	var reflected: float = hp_before - state.hp_of(attacker_key)
	if status != null and pin_sec > 0.0 and not state.is_key_dead(attacker_key):
		status.pin(attacker_key, pin_sec)
	parries += 1
	parried.emit(blocked, reflected, pin_sec)
	return {"parried": true, "blocked": blocked, "reflected": reflected, "pin_sec": pin_sec}


## True while an ENEMY ATTACK telegraph is up, i.e. a parry card may be cast: [param pattern] (may be null) winds up or
## warns an attack skill, or the block-brain boss [param boss_actor] (may be null) is swinging (its telegraph shows) or
## has a queued combo swing.
static func enemy_telegraph(pattern: PatternController, boss_actor: CutActor) -> bool:
	if pattern != null and pattern.is_threatening():
		return true
	return boss_actor != null and (boss_actor.is_swinging() or boss_actor.has_queued())
