class_name StatusEffects
extends RefCounted
## Timed board effects: burning cells (area denial, damage per unit standing on them) and
## per-side pins (the unit cannot step). Pure logic, time is injected through tick().
## Implements: Story 010 (Burn and Pin).

## A cell started burning (also emitted when a burning cell is re-ignited).
signal cell_ignited(cell: Vector2i)
## A burning cell burned out.
signal cell_burned_out(cell: Vector2i)
## A unit got pinned or its pin was refreshed. [param side] = CombatState.Side.
signal pinned(side: int)
## A pin expired.
signal pin_ended(side: int)
## Story 023: the Ran (fragile) stacks of [param side] changed (applied or consumed).
signal fragile_changed(side: int)
## Story 023: the Han (frost) stacks of [param side] changed (applied, burst or cleared).
signal frost_changed(side: int)
## Story 023: the frost stacks of [param side] reached the burst threshold and dealt [param damage].
signal frost_burst(side: int, damage: float)

## Tolerance for float accumulation when comparing against a tick boundary.
const _EPS: float = 0.000001

# Vector2i -> {left: float, tick_acc: float, tick_sec: float, damage: float, stacks: int}
var _burning: Dictionary = {}
# CombatState.Side -> seconds left
var _pins: Dictionary = {}
# Keyword numbers, see configure(). Defaults = no stacking / no Ghim bonus (old behaviour).
var _burn_extend_sec: float = 0.0
var _burn_tick_bonus: float = 0.0
var _burn_max_stacks: int = 1
var _pinned_damage_mult: float = 1.0
# Story 023 keywords, per SIDE (CombatState.Side -> stacks). Defaults are inert (set by configure_keywords).
var _fragile: Dictionary = {}
var _frost: Dictionary = {}
var _fragile_mult: float = 1.0
var _fragile_max_stacks: int = 1
var _frost_stacks_to_burst: int = 0
var _frost_burst_damage: float = 0.0


## Ignites every cell in [param cells] for [param duration] seconds. A unit standing on a
## burning cell takes [param damage_per_tick] every [param tick_sec]. Story 020 (Dot): igniting a
## cell that is ALREADY burning stacks: left = max(left, duration) + extend, stacks + 1 (capped),
## damage = max(old base, new) + tick_bonus * (stacks - 1), flat per stack (the base never includes a
## bonus, so stacks go 2, 3, 4 and not 2, 3, 5). With the default (unconfigured) values
## extend = 0, bonus = 0, max stacks = 1 this is the old "reset to the full duration".
func ignite(cells: Array[Vector2i], duration: float, tick_sec: float, damage_per_tick: float) -> void:
	if duration <= 0.0:
		return
	for cell: Vector2i in cells:
		var acc: float = 0.0
		var left: float = duration
		var stacks: int = 1
		var base: float = maxf(damage_per_tick, 0.0)
		if _burning.has(cell):
			var old: Dictionary = _burning[cell] as Dictionary
			acc = float(old["tick_acc"])
			left = maxf(float(old["left"]), duration) + _burn_extend_sec
			stacks = mini(int(old["stacks"]) + 1, _burn_max_stacks)
			base = maxf(float(old.get("base", old["damage"])), base)
		var damage: float = base + _burn_tick_bonus * float(stacks - 1)
		_burning[cell] = {
			"left": left, "tick_acc": acc, "stacks": stacks, "base": base,
			"tick_sec": maxf(tick_sec, _EPS), "damage": damage,
		}
		cell_ignited.emit(cell)


## Story 020: sets the keyword numbers (from combat.json, validated by CombatConfig).
## [param extend_sec] seconds added to a re-ignited burning cell, [param tick_bonus] damage per
## extra stack, [param max_stacks] cap (>= 1), [param pinned_mult] damage multiplier against a
## pinned unit (Ghim, >= 1 means bonus; 1.0 = none).
func configure(extend_sec: float, tick_bonus: float, max_stacks: int, pinned_mult: float = 1.0) -> void:
	_burn_extend_sec = maxf(extend_sec, 0.0)
	_burn_tick_bonus = maxf(tick_bonus, 0.0)
	_burn_max_stacks = maxi(max_stacks, 1)
	_pinned_damage_mult = maxf(pinned_mult, 0.0)


## Story 023: sets the Ran / Han numbers (from combat.json, validated by CombatConfig).
## [param fragile_mult] damage multiplier while a side has Ran stacks (>= 1), [param fragile_max] stack
## cap (>= 1), [param burst_stacks] Han stacks that trigger the burst (0 = no burst), [param burst_damage]
## the burst damage (ignores defense and Ran).
func configure_keywords(fragile_mult: float, fragile_max: int, burst_stacks: int, burst_damage: float) -> void:
	_fragile_mult = maxf(fragile_mult, 1.0)
	_fragile_max_stacks = maxi(fragile_max, 1)
	_frost_stacks_to_burst = maxi(burst_stacks, 0)
	_frost_burst_damage = maxf(burst_damage, 0.0)


## Story 023 Ran (fragile): adds [param stacks] to the unit of [param side], capped at the configured
## maximum. The next damage/push hits against it deal x fragile_mult, one stack each.
func apply_fragile(side: int, stacks: int) -> void:
	if stacks <= 0:
		return
	_fragile[side] = mini(int(_fragile.get(side, 0)) + stacks, _fragile_max_stacks)
	fragile_changed.emit(side)


## Ran stacks on [param side] (0 = none).
func fragile_stacks(side: int) -> int:
	return int(_fragile.get(side, 0))


## HUD alias of [method fragile_stacks].
func get_fragile_stacks(side: int) -> int:
	return fragile_stacks(side)


## Damage multiplier a hit against [param side] gets from Ran right now (peek, consumes nothing).
func fragile_mult_against(side: int) -> float:
	return _fragile_mult if fragile_stacks(side) > 0 else 1.0


## Spends one Ran stack of [param side] (a damage/push hit landed) and returns the multiplier that
## hit gets: fragile_mult while a stack existed, else 1.0.
func consume_fragile(side: int) -> float:
	var have: int = fragile_stacks(side)
	if have <= 0:
		return 1.0
	if have == 1:
		_fragile.erase(side)
	else:
		_fragile[side] = have - 1
	fragile_changed.emit(side)
	return _fragile_mult


## Story 023 Han (frost): adds [param stacks] to the unit of [param side]. Reaching the burst
## threshold clears the stacks, emits frost_burst and returns the burst damage (the CALLER applies it
## to the CombatState; it ignores defense and Ran). Returns 0.0 when no burst happened.
func apply_frost(side: int, stacks: int) -> float:
	if stacks <= 0:
		return 0.0
	var total: int = int(_frost.get(side, 0)) + stacks
	if _frost_stacks_to_burst > 0 and total >= _frost_stacks_to_burst:
		_frost.erase(side)
		frost_changed.emit(side)
		frost_burst.emit(side, _frost_burst_damage)
		return _frost_burst_damage
	_frost[side] = total
	frost_changed.emit(side)
	return 0.0


## Han stacks on [param side] (0 = none).
func frost_stacks(side: int) -> int:
	return int(_frost.get(side, 0))


## HUD alias of [method frost_stacks].
func get_frost_stacks(side: int) -> int:
	return frost_stacks(side)


## Damage multiplier for hits against the unit of [param side]: the Ghim multiplier while it is
## pinned, else 1.0.
func damage_mult_against(side: int) -> float:
	return _pinned_damage_mult if is_pinned(side) else 1.0


## Burn stacks on [param cell]; 0 when it is not burning.
func stacks_at(cell: Vector2i) -> int:
	if not _burning.has(cell):
		return 0
	return int((_burning[cell] as Dictionary)["stacks"])


## Highest burn stack among [param cells] (0 when none burns).
func max_stacks_on(cells: Array[Vector2i]) -> int:
	var best: int = 0
	for cell: Vector2i in cells:
		best = maxi(best, stacks_at(cell))
	return best


## Pins the unit of [param side] for [param duration] seconds; a pin already running is
## refreshed to the full duration.
func pin(side: int, duration: float) -> void:
	if duration <= 0.0:
		return
	_pins[side] = duration
	pinned.emit(side)


## Advances all timers by [param delta]; burning cells hurt the units standing on them in
## [param state] once per elapsed tick, however large the delta.
func tick(delta: float, state: CombatState) -> void:
	if delta <= 0.0:
		return
	for cell: Vector2i in _burning.keys():
		var entry: Dictionary = _burning[cell] as Dictionary
		var active: float = minf(delta, float(entry["left"]))
		var tick_sec: float = float(entry["tick_sec"])
		var acc: float = float(entry["tick_acc"])
		var victims: Array[int] = _units_on(cell, state)
		if victims.is_empty():
			acc = 0.0
		else:
			acc += active
			while acc >= tick_sec - _EPS:
				acc -= tick_sec
				for side: int in victims:
					state.damage(side, float(entry["damage"]))
		var left: float = float(entry["left"]) - delta
		if left <= _EPS:
			_burning.erase(cell)
			cell_burned_out.emit(cell)
		else:
			entry["left"] = left
			entry["tick_acc"] = acc
	for side: int in _pins.keys():
		var pin_left: float = float(_pins[side]) - delta
		if pin_left <= _EPS:
			_pins.erase(side)
			pin_ended.emit(side)
		else:
			_pins[side] = pin_left


## True while [param cell] is burning.
func is_burning(cell: Vector2i) -> bool:
	return _burning.has(cell)


## All burning cells.
func burning_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _burning.keys():
		out.append(cell)
	return out


## Seconds of burning left on [param cell]; 0 if it is not burning.
func get_burn_left(cell: Vector2i) -> float:
	if not _burning.has(cell):
		return 0.0
	return float((_burning[cell] as Dictionary)["left"])


## Story 021: damage the burning [param cell] still has to deal if a unit stood on it until it burns
## out: (seconds left / tick seconds) x damage per tick (stacks are already folded into the damage).
## 0 when the cell is not burning.
func remaining_burn_damage(cell: Vector2i) -> float:
	if not _burning.has(cell):
		return 0.0
	var entry: Dictionary = _burning[cell] as Dictionary
	return float(entry["left"]) / float(entry["tick_sec"]) * float(entry["damage"])


## Story 021: stops the burning of [param cells] (every burning cell when empty), emitting
## cell_burned_out for each. Returns how many cells were cleared.
func clear_burn(cells: Array[Vector2i] = []) -> int:
	var targets: Array[Vector2i] = cells if not cells.is_empty() else burning_cells()
	var cleared: int = 0
	for cell: Vector2i in targets:
		if _burning.erase(cell):
			cleared += 1
			cell_burned_out.emit(cell)
	return cleared


## True while the unit of [param side] is pinned.
func is_pinned(side: int) -> bool:
	return _pins.has(side)


## Seconds of pin left for [param side]; 0 if not pinned.
func get_pin_left(side: int) -> float:
	return float(_pins.get(side, 0.0))


## Removes every effect without emitting signals.
func clear() -> void:
	_burning.clear()
	_pins.clear()
	_fragile.clear()
	_frost.clear()


# Sides of the living units standing on [param cell].
func _units_on(cell: Vector2i, state: CombatState) -> Array[int]:
	var out: Array[int] = []
	if not state.is_player_dead() and state.player_cell == cell:
		out.append(CombatState.Side.PLAYER)
	if not state.is_enemy_dead() and state.enemy_cell == cell:
		out.append(CombatState.Side.ENEMY)
	return out
