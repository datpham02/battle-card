class_name StatusEffects
extends RefCounted
## Timed board effects: burning cells (area denial, damage per unit standing on them) and
## per-side pins (the unit cannot step). Pure logic, time is injected through tick().
## Story 027 adds per-side thorn zones (cells that cost damage + Ran each time a unit enters them). The
## Story 027 seal zone (Wall) was removed with the Wall cards on 2026-11-01 (ADR-0001 Phase 1 cleanup).
## Drop tiles (Ô rớt, the boss trait seal_caster): crack warning -> hole -> return, see [method apply_drop].
## Implements: Story 010 (Burn and Pin), Story 027 (Thorns zones),
## design/quick-specs/o-rot-thay-tuong-2026-10-31.md (drop tiles, rules 3-6),
## design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md (one zone effect per cell, locked cells): THIS class is the single
## rule point: [method unlocked_cells] is the gate every hit resolution calls, [method _claim_zone_cell] the gate every
## zone placement passes (ignite, apply_thorns, apply_drop).

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

## Story 027: a zone formed or was refreshed. [param kind] is "thorns", [param side] the side
## whose half holds the cells.
signal zone_applied(kind: String, side: int, cells: Array[Vector2i])
## Story 027: a zone cell expired (or was cleared by clear_zones). [param kind] is "thorns".
signal zone_expired(kind: String, side: int, cell: Vector2i)
## Story 027: the unit of [param side] stepped into a thorn cell and took [param damage].
signal thorn_entered(side: int, cell: Vector2i, damage: float)
## 2026-10-31: a burning cell hurt the unit of [param side] standing on [param cell] by [param damage] (a tick, or the
## entry toll of [member burn_on_entry]); not emitted when the tick heals a burn_eater boss. The HUD pops the number.
signal burn_hurt(side: int, cell: Vector2i, damage: float)

## Drop tile (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md): [param cells] of [param side]'s half
## started cracking (warning phase; still enterable and leavable).
signal hole_cracked(side: int, cells: Array[Vector2i])
## Drop tile: the cracking [param cell] fell and is a hole now (cannot be entered). [param victim] is true when the
## unit of [param side] stood on it and fell (HP to 0 with hole_fall_lethal, else pushed off for hole_fall_damage).
signal hole_fell(side: int, cell: Vector2i, victim: bool)
## Drop tile: [param cell] is a normal cell again (the hole closed, the fall was cancelled, or clear_zones ran).
signal hole_restored(side: int, cell: Vector2i)

## Zone kind names (also the zone_applied / zone_expired payload).
const KIND_THORNS: String = "thorns"
## Drop tile phases (see [method apply_drop]).
const HOLE_PHASE_CRACK: String = "crack"
const HOLE_PHASE_HOLE: String = "hole"
## One-zone-per-cell kinds (quick spec 2026-11-01, [method zone_kinds_at]). Thorns use [constant KIND_THORNS].
const KIND_BURN: String = "burn"
const KIND_DROP: String = "drop"

## Tolerance for float accumulation when comparing against a tick boundary.
const _EPS: float = 0.000001

# Vector2i -> {left: float, tick_acc: float, tick_sec: float, damage: float, stacks: int, zone: bool}
# (zone false = fire left by region terrain, a lava vent: not a zone effect, quick spec 2026-11-01)
var _burning: Dictionary = {}
# CombatState.Side -> seconds left
var _pins: Dictionary = {}
# Story 027 zones: Side -> {Vector2i -> {left, total, damage, fragile}} (thorns).
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
## 2026-10-31 (user: "đi qua vùng có debuff mà ko bị gì"): when true, a unit that steps ONTO a burning cell pays one
## tick of its damage at once (like a thorn toll) and the tick clock restarts there, so crossing a burning row in
## less than tick_sec still hurts. Default false (inert for the old tests); CombatConfig sets it from combat.json
## `burn_on_entry`.
var burn_on_entry: bool = false
## Drop tile (2026-10-31 spec rule 5): true = a unit on a cell when it falls drops to HP 0 (combat.json
## `zones.hole_fall_lethal`); false = it is pushed to an open neighbour and loses [member hole_fall_damage] (the Sky
## Isles crumble fallback). CombatConfig.configure_status sets both.
var hole_fall_lethal: bool = true
## Drop tile, hole_fall_lethal false only: HP lost by a unit that falls (combat.json `hazards.fall_damage`).
var hole_fall_damage: float = 0.0
## Drop tile (presentation only): seconds a closed hole keeps its "fades back in from white" timer
## (combat.json `zones.hole_return_fade_sec`). The cell is steppable as soon as the hole closes.
var hole_return_fade_sec: float = 0.0
## Drop tile (spec rule 6): Callable(side: int) -> bool, true while the unit of that side is rooted (cannot step:
## UnitMover.is_step_locked). Frozen (Dong Bang) is this class's own pin. Invalid = never rooted.
var step_locked_fn: Callable = Callable()
## Drop tile, non-lethal fall: Callable(side: int, cell: Vector2i) -> bool, true when the unit of that side cannot
## land on [param cell] (the mover's blockers). Cracking cells and holes are refused here anyway. Invalid = none.
var hole_blocked_fn: Callable = Callable()
# Drop tiles: Side -> {Vector2i -> {phase, left, warn, total, held}} (see apply_drop).
var _holes: Dictionary = {}
# Phase 2 (design/quick-specs/phase2-misty-forest-2026-11-01.md section 6, D2/D4/D5): Root (side -> sec left), Slow
# (side -> {left, mult}) and Guard (side -> {left, amount}).
var _roots: Dictionary = {}
var _slows: Dictionary = {}
var _guards: Dictionary = {}
## side -> seconds since that side's last step lock (Frozen pin or Root) ended (F4 cc grace; absent = never locked).
var _since_unlock: Dictionary = {}
# Drop tiles: Side -> {Vector2i -> seconds of the return fade left} (presentation only).
var _hole_fade: Dictionary = {}


## Ignites every cell in [param cells] for [param duration] seconds. A unit standing on a
## burning cell takes [param damage_per_tick] every [param tick_sec]. Story 020 (Dot): igniting a
## cell that is ALREADY burning stacks: left = max(left, duration) + extend, stacks + 1 (capped),
## damage = max(old base, new) + tick_bonus * (stacks - 1), flat per stack (the base never includes a
## bonus, so stacks go 2, 3, 4 and not 2, 3, 5). With the default (unconfigured) values
## extend = 0, bonus = 0, max stacks = 1 this is the old "reset to the full duration".
## Quick spec 2026-11-01 (one zone per cell): a skill's fire is a zone effect, so a locked cell (cracking / hole) is
## skipped and another zone on the cell (thorns) is removed first ([method _claim_zone_cell]). [param terrain] true =
## the fire of region terrain (a lava vent): not a zone effect, it keeps its old behaviour (no lock, no replacement).
## Returns the cells that burn now.
func ignite(
	cells: Array[Vector2i], duration: float, tick_sec: float, damage_per_tick: float, terrain: bool = false
) -> Array[Vector2i]:
	var lit: Array[Vector2i] = []
	if duration <= 0.0:
		return lit
	for cell: Vector2i in cells:
		if not terrain and not _claim_zone_cell(cell, KIND_BURN):
			continue
		var zone: bool = not terrain
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
			zone = zone or bool(old.get("zone", true))
		var damage: float = base + _burn_tick_bonus * float(stacks - 1)
		_burning[cell] = {
			"left": left, "tick_acc": acc, "stacks": stacks, "base": base,
			"tick_sec": maxf(tick_sec, _EPS), "damage": damage, "zone": zone,
		}
		lit.append(cell)
		cell_ignited.emit(cell)
	return lit


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
						burn_hurt.emit(side, cell, float(entry["damage"]))
		var left: float = float(entry["left"]) - delta
		if left <= _EPS:
			_burning.erase(cell)
			cell_burned_out.emit(cell)
		else:
			entry["left"] = left
			entry["tick_acc"] = acc
	for side: int in _since_unlock.keys():
		_since_unlock[side] = float(_since_unlock[side]) + delta
	for side: int in _pins.keys():
		var pin_left: float = float(_pins[side]) - delta
		if pin_left <= _EPS:
			_pins.erase(side)
			_mark_unlocked(side, pin_left)
			pin_ended.emit(side)
		else:
			_pins[side] = pin_left
	_tick_zones(_thorns, KIND_THORNS, delta)
	_tick_phase2_statuses(delta)
	_tick_holes(delta, state)


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
	_roots.clear()
	_since_unlock.clear()
	_slows.clear()
	_guards.clear()
	_fragile.clear()
	_frost.clear()
	_thorns.clear()
	_holes.clear()
	_hole_fade.clear()
	_last_cell.clear()


## Story 027 Thorns (Tran gai): the [param cells] (cells of [param side]'s half) stay steppable, but every
## time the unit of [param side] CHANGES cell into one it takes [param damage] and gets
## [param fragile_stacks] Ran, for [param duration] seconds. Re-applying a cell refreshes its time and numbers.
## Standing in a thorn cell when it forms does not trigger; leaving and re-entering does. Entries are
## detected in [method tick] (the first tick only records where each unit stands).
## Quick spec 2026-11-01: locked cells are skipped and another zone on a cell (a skill's fire) is removed first
## ([method _claim_zone_cell]). Returns the cells that hold thorns now (zone_applied carries the same list).
func apply_thorns(
	side: int, cells: Array[Vector2i], duration: float, damage: float, fragile_stacks: int
) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	if duration <= 0.0 or cells.is_empty():
		return placed
	for cell: Vector2i in cells:
		if placed.has(cell) or not _claim_zone_cell(cell, KIND_THORNS):
			continue
		_zone_of(_thorns, side)[cell] = {
			"left": duration, "total": duration,
			"damage": maxf(damage, 0.0), "fragile": maxi(fragile_stacks, 0),
		}
		placed.append(cell)
	if not placed.is_empty():
		zone_applied.emit(KIND_THORNS, side, placed)
	return placed


## The thorn on [param cell] of [param side]'s half: {left, damage, fragile_stacks}, {} when none.
func thorns_at(side: int, cell: Vector2i) -> Dictionary:
	var zone: Dictionary = _thorns.get(side, {}) as Dictionary
	if not zone.has(cell):
		return {}
	var entry: Dictionary = zone[cell] as Dictionary
	return {"left": float(entry["left"]), "damage": float(entry["damage"]), "fragile_stacks": int(entry["fragile"])}


## Thorn cells of [param side], sorted by x then y.
func thorn_cells(side: int) -> Array[Vector2i]:
	return _sorted_cells(_thorns.get(side, {}) as Dictionary)


## Seconds of thorns left on [param cell] (0 when none).
func thorn_left(side: int, cell: Vector2i) -> float:
	return _zone_value(_thorns, side, cell, "left")


## Full duration the thorns on [param cell] were set with (0 when none).
func thorn_total_sec(side: int, cell: Vector2i) -> float:
	return _zone_value(_thorns, side, cell, "total")


## Removes the thorns of [param side] (both sides when -1), emitting zone_expired per cell.
func clear_zones(side: int = -1) -> void:
	for s: int in _thorns.keys():
		if side != -1 and s != side:
			continue
		var thorn_cells_of: Array[Vector2i] = _sorted_cells(_thorns[s] as Dictionary)
		_thorns.erase(s)
		for cell: Vector2i in thorn_cells_of:
			zone_expired.emit(KIND_THORNS, s, cell)
	# Drop tiles of that side close too (a dead boss leaves no crack that could still kill the player).
	for s: int in _holes.keys():
		if side != -1 and s != side:
			continue
		var cells: Array[Vector2i] = _sorted_cells(_holes[s] as Dictionary)
		_holes.erase(s)
		for cell: Vector2i in cells:
			hole_restored.emit(s, cell)


# --- one zone per cell, locked cells (design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md) ----------------------

## Rule 3: true while [param cell] is LOCKED: it cracks or is an open hole (drop tile) on either half. A locked cell
## takes nothing from any skill (no damage, no status, no new zone) until it returns.
func is_locked(cell: Vector2i) -> bool:
	for side: int in _holes.keys():
		if (_holes[side] as Dictionary).has(cell):
			return true
	return false


## THE gate of every hit (rule 3): [param cells] without the locked cells, input order kept. CutEffects.apply resolves
## a cast over this list only (SkillDelivery.damage_cells gives the mask, this removes the locked cells from it), the
## boss traits that hit cells go through [method BossTrait.hittable_cells], and the enemy warnings are drawn over the
## same list (rule 4: a warning shows exactly the cells that will be hit).
func unlocked_cells(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not is_locked(cell):
			out.append(cell)
	return out


## Rule 1: the zone effect on [param cell] (either half): "" none, [constant KIND_BURN] (a skill's fire; a lava vent's
## terrain fire does not count), [constant KIND_THORNS] or [constant KIND_DROP] (cracking or hole).
func zone_kind_at(cell: Vector2i) -> String:
	var kinds: Array[String] = zone_kinds_at(cell)
	return kinds[0] if not kinds.is_empty() else ""


## Every zone effect on [param cell]; rule 1 keeps this at most one long (tests assert it).
func zone_kinds_at(cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if _burning.has(cell) and bool((_burning[cell] as Dictionary).get("zone", true)):
		out.append(KIND_BURN)
	for side: int in _thorns.keys():
		if (_thorns[side] as Dictionary).has(cell):
			out.append(KIND_THORNS)
	if is_locked(cell):
		out.append(KIND_DROP)
	return out


# THE placement gate (rules 1-3, 5): may a zone of [param kind] go on [param cell]? A locked cell refuses every zone.
# Otherwise a zone of another kind is removed at once (cell_burned_out / zone_expired, so the HUD drops it) and true is
# returned; the caller then places its zone with its full duration (same kind = the caller's own refresh rule).
func _claim_zone_cell(cell: Vector2i, kind: String) -> bool:
	if is_locked(cell):
		return false
	if kind != KIND_BURN and _burning.has(cell) and bool((_burning[cell] as Dictionary).get("zone", true)):
		_burning.erase(cell)
		cell_burned_out.emit(cell)
	if kind != KIND_THORNS:
		for side: int in _thorns.keys():
			var zone: Dictionary = _thorns[side] as Dictionary
			if not zone.has(cell):
				continue
			zone.erase(cell)
			if zone.is_empty():
				_thorns.erase(side)
			zone_expired.emit(KIND_THORNS, side, cell)
	return true


# --- drop tiles (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md) ---------------------------------------

## Drop tile (spec rules 3-4): [param cells] of [param side]'s half crack for [param warn_sec] (combat.json
## `zones.hole_warn_sec`; still enterable and leavable), then fall and stay a hole for [param hole_sec]
## (`zones.seal_sec`; cannot be entered), then return. Cells already cracking or open (locked) are skipped; another
## zone on a chosen cell (thorns, a skill's fire) is replaced by the crack (quick spec 2026-11-01 rule 5, through
## [method _claim_zone_cell]). The fairness rules are NOT checked here: callers go through [method ZoneRules.cast_drop],
## the single drop rule point. Returns the cells that started cracking.
func apply_drop(side: int, cells: Array[Vector2i], warn_sec: float, hole_sec: float) -> Array[Vector2i]:
	var started: Array[Vector2i] = []
	if hole_sec <= 0.0:
		return started
	var book: Dictionary = _zone_of(_holes, side)
	for cell: Vector2i in cells:
		if started.has(cell) or not _claim_zone_cell(cell, KIND_DROP):
			continue
		book[cell] = {"phase": HOLE_PHASE_CRACK, "left": maxf(warn_sec, 0.0), "warn": maxf(warn_sec, 0.0),
			"total": hole_sec, "held": false}
		started.append(cell)
	if book.is_empty():
		_holes.erase(side)
	if not started.is_empty():
		hole_cracked.emit(side, started)
	return started


## True while [param cell] of [param side] cracks (warning phase: enterable).
func is_cracking(side: int, cell: Vector2i) -> bool:
	return _hole_phase(side, cell) == HOLE_PHASE_CRACK


## True while [param cell] of [param side] is an open hole (cannot be entered).
func is_hole(side: int, cell: Vector2i) -> bool:
	return _hole_phase(side, cell) == HOLE_PHASE_HOLE


## Cracking cells of [param side], sorted by x then y.
func crack_cells(side: int) -> Array[Vector2i]:
	return _hole_cells_in(side, HOLE_PHASE_CRACK)


## Open holes of [param side], sorted by x then y.
func hole_cells(side: int) -> Array[Vector2i]:
	return _hole_cells_in(side, HOLE_PHASE_HOLE)


## Seconds of crack warning left on [param cell] (0 when it does not crack, or when its fall is held).
func crack_left(side: int, cell: Vector2i) -> float:
	return maxf(_zone_value(_holes, side, cell, "left"), 0.0) if is_cracking(side, cell) else 0.0


## 0..1 how far the crack warning of [param cell] has run (1 = due / held); 0 when it does not crack.
func crack_progress(side: int, cell: Vector2i) -> float:
	if not is_cracking(side, cell):
		return 0.0
	var warn: float = _zone_value(_holes, side, cell, "warn")
	if warn <= 0.0:
		return 1.0
	return clampf(1.0 - crack_left(side, cell) / warn, 0.0, 1.0)


## True while the crack under a Frozen or rooted unit is held (spec rule 6: it keeps cracking and does not fall until
## the unit leaves the cell).
func is_crack_held(side: int, cell: Vector2i) -> bool:
	return is_cracking(side, cell) and bool((_holes[side][cell] as Dictionary)["held"])


## Seconds the hole on [param cell] stays open (0 when it is not a hole).
func hole_left(side: int, cell: Vector2i) -> float:
	return maxf(_zone_value(_holes, side, cell, "left"), 0.0) if is_hole(side, cell) else 0.0


## Full seconds the hole on [param cell] was set with (cracking or open; 0 when neither).
func hole_total_sec(side: int, cell: Vector2i) -> float:
	return _zone_value(_holes, side, cell, "total")


## Cells of [param side] that closed less than hole_return_fade_sec ago (presentation: they fade in from white).
func returning_cells(side: int) -> Array[Vector2i]:
	return _sorted_cells(_hole_fade.get(side, {}) as Dictionary)


## 1 = the cell has just come back (full white), 0 = the fade is over. 0 for a cell that is not returning.
func hole_return_fraction(side: int, cell: Vector2i) -> float:
	var fades: Dictionary = _hole_fade.get(side, {}) as Dictionary
	if not fades.has(cell) or hole_return_fade_sec <= 0.0:
		return 0.0
	return clampf(float(fades[cell]) / hole_return_fade_sec, 0.0, 1.0)


func _hole_phase(side: int, cell: Vector2i) -> String:
	var book: Dictionary = _holes.get(side, {}) as Dictionary
	if not book.has(cell):
		return ""
	return str((book[cell] as Dictionary)["phase"])


func _hole_cells_in(side: int, phase: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _sorted_cells(_holes.get(side, {}) as Dictionary):
		if _hole_phase(side, cell) == phase:
			out.append(cell)
	return out


# True when the unit of [param side] cannot step at all: Frozen (pinned), Root or rooted (step_locked_fn).
func _unit_stuck(side: int) -> bool:
	return is_pinned(side) or is_rooted(side) or (step_locked_fn.is_valid() and bool(step_locked_fn.call(side)))


func _is_dead(side: int, state: CombatState) -> bool:
	return state.is_player_dead() if side == CombatState.Side.PLAYER else state.is_enemy_dead()


# Drop tiles: runs the crack clocks (a crack under a Frozen / rooted unit is held, spec rule 6), turns due cracks into
# holes (the unit standing there falls, rule 5), closes holes and runs the return fades. Called by tick() only, so the
# clock runs on the match's scaled time: Focus (time scale 0) stops it.
func _tick_holes(delta: float, state: CombatState) -> void:
	for side: int in _hole_fade.keys():
		var fades: Dictionary = _hole_fade[side] as Dictionary
		for cell: Vector2i in _sorted_cells(fades):
			var left: float = float(fades[cell]) - delta
			if left <= _EPS:
				fades.erase(cell)
			else:
				fades[cell] = left
		if fades.is_empty():
			_hole_fade.erase(side)
	for side: int in _holes.keys():
		var book: Dictionary = _holes[side] as Dictionary
		var unit_cell: Vector2i = state.cell_of(side)
		var alive: bool = not _is_dead(side, state)
		for cell: Vector2i in _sorted_cells(book):
			if not book.has(cell):
				continue
			var entry: Dictionary = book[cell] as Dictionary
			if str(entry["phase"]) == HOLE_PHASE_CRACK:
				var on_cell: bool = alive and unit_cell == cell
				# Held while the unit stands here and was Frozen / rooted at some point since it stepped on; leaving clears it.
				entry["held"] = on_cell and (bool(entry["held"]) or _unit_stuck(side))
				entry["left"] = float(entry["left"]) - delta
				if float(entry["left"]) > _EPS:
					continue
				if bool(entry["held"]):
					entry["left"] = 0.0
					continue
				_fall_hole(side, cell, -float(entry["left"]), state)
			else:
				entry["left"] = float(entry["left"]) - delta
				if float(entry["left"]) <= _EPS:
					book.erase(cell)
					_start_return_fade(side, cell)
					hole_restored.emit(side, cell)
		if book.is_empty():
			_holes.erase(side)


# The crack of [param cell] ran out: it becomes a hole for its total minus the overshoot [param carry]. A unit standing
# there falls: HP 0 (hole_fall_lethal), else it is pushed to an open neighbour and loses hole_fall_damage; with no
# landing cell the non-lethal fall is cancelled (the cell returns at once), as a Sky Isles crumble does.
func _fall_hole(side: int, cell: Vector2i, carry: float, state: CombatState) -> void:
	var book: Dictionary = _holes[side] as Dictionary
	var entry: Dictionary = book[cell] as Dictionary
	var victim: bool = not _is_dead(side, state) and state.cell_of(side) == cell
	if victim and not hole_fall_lethal:
		var target: Vector2i = _landing_cell(side, cell, state.grid)
		if target == BoardGrid.NO_CELL:
			book.erase(cell)
			hole_restored.emit(side, cell)
			return
		if side == CombatState.Side.PLAYER:
			state.set_player_cell(target)
		else:
			state.set_enemy_cell(target)
		_last_cell[side] = target
	entry["phase"] = HOLE_PHASE_HOLE
	entry["held"] = false
	entry["left"] = maxf(float(entry["total"]) - carry, _EPS)
	if victim:
		if hole_fall_lethal:
			var hp: float = state.player_hp if side == CombatState.Side.PLAYER else state.enemy_hp
			state.damage(side, hp)
		else:
			state.damage(side, hole_fall_damage)
	hole_fell.emit(side, cell, victim)


# Non-lethal fall: the 4-neighbour of [param from] on the same half the unit lands on: not cracking, not a hole, not
# refused by hole_blocked_fn; ties broken by x then y. NO_CELL when none.
func _landing_cell(side: int, from: Vector2i, grid: BoardGrid) -> Vector2i:
	var best: Vector2i = BoardGrid.NO_CELL
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var cell: Vector2i = from + dir
		var on_half: bool = grid.is_player_cell(cell) if side == CombatState.Side.PLAYER else grid.is_enemy_cell(cell)
		if not on_half or _hole_phase(side, cell) != "":
			continue
		if hole_blocked_fn.is_valid() and bool(hole_blocked_fn.call(side, cell)):
			continue
		if best == BoardGrid.NO_CELL or cell.x < best.x or (cell.x == best.x and cell.y < best.y):
			best = cell
	return best


func _start_return_fade(side: int, cell: Vector2i) -> void:
	if hole_return_fade_sec <= 0.0:
		return
	_zone_of(_hole_fade, side)[cell] = hole_return_fade_sec


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


# A unit that CHANGED cell since the last tick and now stands on a thorn cell pays the toll once; with
# [member burn_on_entry], one that stepped onto a burning cell pays one burn tick at once (2026-10-31).
func _check_thorn_entries(state: CombatState) -> void:
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var cell: Vector2i = state.cell_of(side)
		var had: bool = _last_cell.has(side)
		var last: Vector2i = _last_cell.get(side, cell)
		_last_cell[side] = cell
		if not had or last == cell:
			continue
		_burn_entry(side, cell, state)
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


# 2026-10-31: the entry toll of a burning [param cell] for the unit of [param side] that just stepped onto it: one tick
# of the cell's damage now (healing a burn_eater boss instead, as a tick does) and the cell's tick clock restarted, so
# the next tick lands a full tick_sec later.
func _burn_entry(side: int, cell: Vector2i, state: CombatState) -> void:
	if not burn_on_entry or not _burning.has(cell):
		return
	var dead: bool = state.is_player_dead() if side == CombatState.Side.PLAYER else state.is_enemy_dead()
	if dead:
		return
	var entry: Dictionary = _burning[cell] as Dictionary
	entry["tick_acc"] = 0.0
	var damage: float = float(entry["damage"])
	var ratio: float = _burn_heal_ratio(side)
	if ratio > 0.0:
		burn_healed.emit(side, state.heal_enemy(damage * ratio))
		return
	state.damage(side, damage)
	burn_hurt.emit(side, cell, damage)


# Sides of the living units standing on [param cell].
func _units_on(cell: Vector2i, state: CombatState) -> Array[int]:
	var out: Array[int] = []
	if not state.is_player_dead() and state.player_cell == cell:
		out.append(CombatState.Side.PLAYER)
	if not state.is_enemy_dead() and state.enemy_cell == cell:
		out.append(CombatState.Side.ENEMY)
	return out


# --- Phase 2 statuses: Root (D2), Slow (D4), Guard (D5) ------------------------------------------------------------

## D2 Root (Troi): the unit of [param side] cannot step for [param duration] seconds (casting stays allowed). It is the
## same lock family as Frozen (pin): a Root never lands while the unit is Frozen or already Rooted (no stacking, spec F4;
## the cc grace window is the caller's rule, FairnessCheck.cc_allowed). Returns true when it landed. Own visual id
## [constant STATUS_ROOT] (the HUD chip / unit overlay).
func root(side: int, duration: float) -> bool:
	if duration <= 0.0 or is_pinned(side) or is_rooted(side):
		return false
	_roots[side] = duration
	return true


## Visual / status id of Root (D2).
const STATUS_ROOT: String = "root"
## Status id of Slow (D4).
const STATUS_SLOW: String = "slow"
## Status id of Guard (D5).
const STATUS_GUARD: String = "guard"


## True while the unit of [param side] is Rooted.
func is_rooted(side: int) -> bool:
	return _roots.has(side)


## Seconds of Root left for [param side]; 0 when not rooted.
func get_root_left(side: int) -> float:
	return float(_roots.get(side, 0.0))


## Seconds the unit of [param side] stays step-locked by a status (max of Frozen and Root); 0 = free.
func lock_left(side: int) -> float:
	return maxf(get_pin_left(side), get_root_left(side))


## Seconds since the last step lock (Frozen or Root) of [param side] ended, counted by this class's own clock so a lock
## that starts and ends between two reads still counts (F4 cc grace). INF when the side was never locked; 0 while locked.
func since_lock_ended(side: int) -> float:
	if lock_left(side) > _EPS:
		return 0.0
	return float(_since_unlock.get(side, INF))


# A lock of [param side] ended this tick; [param left] (<= 0) is how far into the tick it ended.
func _mark_unlocked(side: int, left: float) -> void:
	if lock_left(side) > _EPS:
		return
	_since_unlock[side] = maxf(-left, 0.0)


## D4 Slow: the steps of [param side] cost [param step_mult] x their cooldown for [param duration] seconds
## (enemy_skills.json `statuses.slow`). Re-applying refreshes the time and keeps the larger multiplier.
func slow(side: int, duration: float, step_mult: float) -> void:
	if duration <= 0.0 or step_mult <= 0.0:
		return
	var prev: Dictionary = _slows.get(side, {}) as Dictionary
	_slows[side] = {"left": maxf(duration, float(prev.get("left", 0.0))), "mult": maxf(step_mult, float(prev.get("mult", 0.0)))}


## Step cooldown multiplier of [param side] from Slow (1.0 when not slowed). UnitMover folds it into every step.
func step_mult(side: int) -> float:
	return float((_slows[side] as Dictionary)["mult"]) if _slows.has(side) else 1.0


## Seconds of Slow left for [param side].
func get_slow_left(side: int) -> float:
	return float((_slows[side] as Dictionary)["left"]) if _slows.has(side) else 0.0


## D5 Guard: [param amount] temporary flat armor on the unit of [param side] for [param duration] seconds, added to the
## match's boss_defense by SwingArbiter; Pierce (`pierce_defense` cards) ignores ALL of it. Re-applying keeps the larger
## amount and refreshes the time; [method clear_guard] ends it early (the marker that fed it broke).
func guard(side: int, amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	var prev: Dictionary = _guards.get(side, {}) as Dictionary
	_guards[side] = {"left": maxf(duration, float(prev.get("left", 0.0))), "amount": maxf(amount, float(prev.get("amount", 0.0)))}


## Guard armor of [param side] right now (0 when none).
func guard_amount(side: int) -> float:
	return float((_guards[side] as Dictionary)["amount"]) if _guards.has(side) else 0.0


## Seconds of Guard left for [param side].
func get_guard_left(side: int) -> float:
	return float((_guards[side] as Dictionary)["left"]) if _guards.has(side) else 0.0


## Ends the Guard of [param side] now.
func clear_guard(side: int) -> void:
	_guards.erase(side)


func _tick_phase2_statuses(delta: float) -> void:
	for side: int in _roots.keys():
		var left: float = float(_roots[side]) - delta
		if left <= _EPS:
			_roots.erase(side)
			_mark_unlocked(side, left)
		else:
			_roots[side] = left
	for book: Dictionary in [_slows, _guards]:
		for side: int in book.keys():
			var entry: Dictionary = book[side] as Dictionary
			entry["left"] = float(entry["left"]) - delta
			if float(entry["left"]) <= _EPS:
				book.erase(side)
