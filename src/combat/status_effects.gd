class_name StatusEffects
extends RefCounted
## Timed board effects: burning cells (area denial, damage per unit standing on them) and
## per-side pins (the unit cannot step). Pure logic, time is injected through tick().
## Story 027 adds per-side zones: seal (cells a unit cannot step INTO) and thorns (cells that cost
## damage + Ran each time a unit enters them).
## Implements: Story 010 (Burn and Pin), Story 027 (Seal and Thorns zones).

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
## Story 039 (burn_eater): a burning cell healed the unit of [param side] by [param amount] instead of hurting it.
signal burn_healed(side: int, amount: float)

## Story 027: a zone formed or was refreshed. [param kind] is "seal" or "thorns", [param side] the side
## whose half holds the cells.
signal zone_applied(kind: String, side: int, cells: Array[Vector2i])
## Story 027: a zone cell expired (or was cleared by clear_zones). [param kind] is "seal" or "thorns".
signal zone_expired(kind: String, side: int, cell: Vector2i)
## Story 027: the unit of [param side] stepped into a thorn cell and took [param damage].
signal thorn_entered(side: int, cell: Vector2i, damage: float)

## Zone kind names (also the zone_applied / zone_expired payload).
const KIND_SEAL: String = "seal"
const KIND_THORNS: String = "thorns"

## Tolerance for float accumulation when comparing against a tick boundary.
const _EPS: float = 0.000001

# Vector2i -> {left: float, tick_acc: float, tick_sec: float, damage: float, stacks: int}
var _burning: Dictionary = {}
# CombatState.Side -> seconds left
var _pins: Dictionary = {}
# Story 027 zones: Side -> {Vector2i -> {left, total}} (seal) / {left, total, damage, fragile} (thorns).
var _seals: Dictionary = {}
var _thorns: Dictionary = {}
# Side -> the cell the unit stood on at the previous tick (thorn entry detection).
var _last_cell: Dictionary = {}
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
## Story 037 hooks of the BOSS side only (the player's signature; invalid = none, the config numbers stand):
## [member fragile_mult_fn] Callable() -> float gives the multiplier ONE consumed Ran stack applies instead of
## fragile_mult (<= 0 = use the config's); [member frost_burst_mult_fn] Callable() -> float scales a Han burst.
var fragile_mult_fn: Callable = Callable()
var frost_burst_mult_fn: Callable = Callable()
## Story 039 (burn_eater): Callable() -> float, asked at the ONE place a burning cell ticks on the BOSS (ENEMY side):
## 0 (or invalid) = the tick hurts as usual, r > 0 = the tick HEALS the boss by damage x r instead (TraitHost.burn_heal_ratio).
var burn_heal_ratio_fn: Callable = Callable()


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
	return _effective_fragile_mult(side) if fragile_stacks(side) > 0 else 1.0


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
	return _effective_fragile_mult(side)


# Story 037: the Ran multiplier of one stack on [param side]: the boss side may take it from fragile_mult_fn.
func _effective_fragile_mult(side: int) -> float:
	if side == CombatState.Side.ENEMY and fragile_mult_fn.is_valid():
		var override: float = float(fragile_mult_fn.call())
		if override > 0.0:
			return maxf(override, 1.0)
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
		var burst: float = _frost_burst_damage
		if side == CombatState.Side.ENEMY and frost_burst_mult_fn.is_valid():
			burst *= maxf(float(frost_burst_mult_fn.call()), 0.0)
		frost_burst.emit(side, burst)
		return burst
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
	_check_thorn_entries(state)
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
					var ratio: float = _burn_heal_ratio(side)
					if ratio > 0.0:
						var gained: float = state.heal_enemy(float(entry["damage"]) * ratio)
						burn_healed.emit(side, gained)
					else:
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
	_tick_zones(_seals, KIND_SEAL, delta)
	_tick_zones(_thorns, KIND_THORNS, delta)


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
	_seals.clear()
	_thorns.clear()
	_last_cell.clear()


## Story 027 Seal (Ket gioi): the [param cells] (cells of [param side]'s half) cannot be stepped INTO for
## [param duration] seconds. A unit already standing inside is not moved, but cannot re-enter after
## leaving. Re-applying a cell refreshes its time. Pure state, no damage.
func apply_seal(side: int, cells: Array[Vector2i], duration: float) -> void:
	if duration <= 0.0 or cells.is_empty():
		return
	var zone: Dictionary = _zone_of(_seals, side)
	for cell: Vector2i in cells:
		zone[cell] = {"left": duration, "total": duration}
	zone_applied.emit(KIND_SEAL, side, cells)


## Story 027 Thorns (Tran gai): the [param cells] (cells of [param side]'s half) stay steppable, but every
## time the unit of [param side] CHANGES cell into one it takes [param damage] and gets
## [param fragile_stacks] Ran, for [param duration] seconds. Re-applying a cell refreshes its time and numbers.
## Standing in a thorn cell when it forms does not trigger; leaving and re-entering does. Entries are
## detected in [method tick] (the first tick only records where each unit stands).
func apply_thorns(side: int, cells: Array[Vector2i], duration: float, damage: float, fragile_stacks: int) -> void:
	if duration <= 0.0 or cells.is_empty():
		return
	var zone: Dictionary = _zone_of(_thorns, side)
	for cell: Vector2i in cells:
		zone[cell] = {
			"left": duration, "total": duration,
			"damage": maxf(damage, 0.0), "fragile": maxi(fragile_stacks, 0),
		}
	zone_applied.emit(KIND_THORNS, side, cells)


## True while [param cell] of [param side]'s half is sealed (cannot be stepped into).
func is_sealed(side: int, cell: Vector2i) -> bool:
	return (_seals.get(side, {}) as Dictionary).has(cell)


## The thorn on [param cell] of [param side]'s half: {left, damage, fragile_stacks}, {} when none.
func thorns_at(side: int, cell: Vector2i) -> Dictionary:
	var zone: Dictionary = _thorns.get(side, {}) as Dictionary
	if not zone.has(cell):
		return {}
	var entry: Dictionary = zone[cell] as Dictionary
	return {"left": float(entry["left"]), "damage": float(entry["damage"]), "fragile_stacks": int(entry["fragile"])}


## Sealed cells of [param side], sorted by x then y.
func sealed_cells(side: int) -> Array[Vector2i]:
	return _sorted_cells(_seals.get(side, {}) as Dictionary)


## Thorn cells of [param side], sorted by x then y.
func thorn_cells(side: int) -> Array[Vector2i]:
	return _sorted_cells(_thorns.get(side, {}) as Dictionary)


## Seconds of seal left on [param cell] (0 when not sealed).
func seal_left(side: int, cell: Vector2i) -> float:
	return _zone_value(_seals, side, cell, "left")


## Seconds of thorns left on [param cell] (0 when none).
func thorn_left(side: int, cell: Vector2i) -> float:
	return _zone_value(_thorns, side, cell, "left")


## Full duration the seal on [param cell] was set with (remaining-time bar denominator; 0 when none).
func seal_total_sec(side: int, cell: Vector2i) -> float:
	return _zone_value(_seals, side, cell, "total")


## Full duration the thorns on [param cell] were set with (0 when none).
func thorn_total_sec(side: int, cell: Vector2i) -> float:
	return _zone_value(_thorns, side, cell, "total")


## Removes the seals and thorns of [param side] (both sides when -1), emitting zone_expired per cell.
func clear_zones(side: int = -1) -> void:
	for kind: String in [KIND_SEAL, KIND_THORNS]:
		var book: Dictionary = _seals if kind == KIND_SEAL else _thorns
		for s: int in book.keys():
			if side != -1 and s != side:
				continue
			var cells: Array[Vector2i] = _sorted_cells(book[s] as Dictionary)
			book.erase(s)
			for cell: Vector2i in cells:
				zone_expired.emit(kind, s, cell)


# Zone dictionary of [param side] inside [param book], created on demand.
func _zone_of(book: Dictionary, side: int) -> Dictionary:
	if not book.has(side):
		book[side] = {}
	return book[side] as Dictionary


func _zone_value(book: Dictionary, side: int, cell: Vector2i, key: String) -> float:
	var zone: Dictionary = book.get(side, {}) as Dictionary
	if not zone.has(cell):
		return 0.0
	return float((zone[cell] as Dictionary)[key])


func _sorted_cells(zone: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in zone.keys():
		out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


# Counts the zone cells of [param book] down by [param delta]; expired ones are removed with a signal.
func _tick_zones(book: Dictionary, kind: String, delta: float) -> void:
	for side: int in book.keys():
		var zone: Dictionary = book[side] as Dictionary
		for cell: Vector2i in _sorted_cells(zone):
			var entry: Dictionary = zone[cell] as Dictionary
			var left: float = float(entry["left"]) - delta
			if left <= _EPS:
				zone.erase(cell)
				zone_expired.emit(kind, side, cell)
			else:
				entry["left"] = left
		if zone.is_empty():
			book.erase(side)


# Story 039: the burn-heal ratio asked for the BOSS side only (0 = the tick hurts).
func _burn_heal_ratio(side: int) -> float:
	if side != CombatState.Side.ENEMY or not burn_heal_ratio_fn.is_valid():
		return 0.0
	return maxf(float(burn_heal_ratio_fn.call()), 0.0)


# A unit that CHANGED cell since the last tick and now stands on a thorn cell pays the toll once.
func _check_thorn_entries(state: CombatState) -> void:
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var cell: Vector2i = state.cell_of(side)
		var had: bool = _last_cell.has(side)
		var last: Vector2i = _last_cell.get(side, cell)
		_last_cell[side] = cell
		if not had or last == cell:
			continue
		var thorn: Dictionary = thorns_at(side, cell)
		if thorn.is_empty():
			continue
		var dead: bool = state.is_player_dead() if side == CombatState.Side.PLAYER else state.is_enemy_dead()
		if dead:
			continue
		var damage: float = float(thorn["damage"])
		state.damage(side, damage)
		apply_fragile(side, int(thorn["fragile_stacks"]))
		thorn_entered.emit(side, cell, damage)


# Sides of the living units standing on [param cell].
func _units_on(cell: Vector2i, state: CombatState) -> Array[int]:
	var out: Array[int] = []
	if not state.is_player_dead() and state.player_cell == cell:
		out.append(CombatState.Side.PLAYER)
	if not state.is_enemy_dead() and state.enemy_cell == cell:
		out.append(CombatState.Side.ENEMY)
	return out
