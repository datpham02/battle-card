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

## Skill v2 batch 3 (M09): the trap cast [param cast_id] on [param side]'s half fired on [param cells] (every trap cell of
## the cast; the zone is consumed) for [param damage] to the unit of that side.
signal trap_fired(side: int, cast_id: int, cells: Array[Vector2i], damage: float)

## Skill v2 batch 4 (Dấu Tử, 02-design-decisions.md §7): the death mark on the unit of [param side] was applied or
## refreshed ([param sec] left), expired, or triggered (the next damaging cast on it echoes; the mark is gone).
signal mark_applied(side: int, sec: float)
signal mark_expired(side: int)
signal mark_triggered(side: int)
## Skill v2 batch 5 (M15, Deferred 1 / 5 / 9): a reaction the status book fired on its own: R1 when a unit with Hàn
## stepped onto a burning cell, R3 when a trap's fling was stopped short. CutEffects' reactions are reported in its result.
signal reaction_fired(side: int, id: String, damage: float)

## Zone kind names (also the zone_applied / zone_expired payload).
const KIND_THORNS: String = "thorns"
## Skill v2 batch 3 field zones (docs/skill-v2/02-mechanics-catalog.md M09 / M10 / M11, §G): a trap (armed: fires on
## the first entry, every cell of its cast at once), a ward (own half: damage x mult / Guard / heal while standing on
## it) and a pillar (solid: blocks steps). One book, [member _fields]; each is one zone of the cell (zone_kinds_at).
const KIND_TRAP: String = "trap"
const KIND_WARD: String = "ward"
const KIND_PILLAR: String = "pillar"
const FIELD_KINDS: Array[String] = [KIND_TRAP, KIND_WARD, KIND_PILLAR]
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
# Batch 3 field zones: Side -> {Vector2i -> {kind, left, total, cast_id, data}}; data = the card's numbers (trap: dpc,
# pin_sec, push_cells, r3, skill_id; ward: the card's ward numbers plus skill_id; pillar: skill_id).
var _fields: Dictionary = {}
var _field_seq: int = 0
# Batch 4 Dấu Tử: Side -> {left, total, echo_mult, execute_ratio}. A timed card status, never a Rạn stack.
var _marks: Dictionary = {}
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
## Skill v2 batch 5 (M15 rules, Deferred 1): the reaction numbers this book fires on its own (CombatConfig.reactions():
## r1 / r3 numbers, icd_sec), the per-unit per-reaction cooldown book, and the immunity hook: Callable(side, reaction
## id) -> bool, true when the unit of that side is immune to that reaction (an enemy's `immune_status` list; the HUD
## or TraitHost sets it). A burn_eater boss (burn_heal_ratio_fn > 0) is immune to R1 on its own: it heals from fire.
var reaction_numbers: Dictionary = {}
var reaction_immune_fn: Callable = Callable()
var _reaction_at: Dictionary = {}
var _time: float = 0.0
## Batch 5 (Deferred 8 / 9): a snapping trap's damage goes through the flat defense of the unit when true
## ([member defense_fn]: Callable(side) -> float, the target's flat defense now; SwingArbiter sets it), and its fling
## never enters a cell [member blocked_fn_for] refuses (Callable(side) -> Callable(cell) -> bool, the mover's blockers).
var trap_through_defense: bool = false
var defense_fn: Callable = Callable()
var blocked_fn_for: Callable = Callable()
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
# Controls v3 (buff / debuff row): "<status id>:<side>" -> the full length of the timed status last applied (the
# denominator of the HUD's remaining-time pie). Kept after the status ends; only read while it runs.
var _totals: Dictionary = {}
# P2.2b: id of the last ignite() call; every burning cell remembers the call (its "zone") that lit it last, so a
# multi-cell boss over several cells of one fire takes ONE tick per tick (see _burn_lead_cells).
var _burn_zone_seq: int = 0


## Ignites every cell in [param cells] for [param duration] seconds. A unit standing on a
## burning cell takes [param damage_per_tick] every [param tick_sec]. Story 020 (Dot): igniting a
## cell that is ALREADY burning stacks: left = max(left, duration) + extend, stacks + 1 (capped),
## damage = max(old base, new) + tick_bonus * (stacks - 1), flat per stack (the base never includes a
## bonus, so stacks go 2, 3, 4 and not 2, 3, 5). With the default (unconfigured) values
## extend = 0, bonus = 0, max stacks = 1 this is the old "reset to the full duration".
## Quick spec 2026-11-01 (one zone per cell): a skill's fire is a zone effect, so a locked cell (cracking / hole) is
## skipped and another zone on the cell (thorns) is removed first ([method _claim_zone_cell]). [param terrain] true =
## the fire of region terrain (a lava vent): not a zone effect, it keeps its old behaviour (no lock, no replacement).
## Returns the cells that burn now. Batch 3 (M11 fire wall, Hỏa Tuyến line): [param wall] true marks the cells as a
## fire wall ([method is_fire_wall]): the ENEMY's mover refuses them while they burn (CombatView / sim blockers); a
## re-ignite keeps the flag.
func ignite(
	cells: Array[Vector2i], duration: float, tick_sec: float, damage_per_tick: float, terrain: bool = false,
	wall: bool = false
) -> Array[Vector2i]:
	var lit: Array[Vector2i] = []
	if duration <= 0.0:
		return lit
	_burn_zone_seq += 1
	for cell: Vector2i in cells:
		if not terrain and not _claim_zone_cell(cell, KIND_BURN):
			continue
		var zone: bool = not terrain
		var acc: float = 0.0
		var left: float = duration
		var stacks: int = 1
		var base: float = maxf(damage_per_tick, 0.0)
		var is_wall: bool = wall
		if _burning.has(cell):
			var old: Dictionary = _burning[cell] as Dictionary
			acc = float(old["tick_acc"])
			left = maxf(float(old["left"]), duration) + _burn_extend_sec
			stacks = mini(int(old["stacks"]) + 1, _burn_max_stacks)
			base = maxf(float(old.get("base", old["damage"])), base)
			zone = zone or bool(old.get("zone", true))
			is_wall = is_wall or bool(old.get("wall", false))
		var damage: float = base + _burn_tick_bonus * float(stacks - 1)
		_burning[cell] = {
			"left": left, "total": left, "tick_acc": acc, "stacks": stacks, "base": base,
			"tick_sec": maxf(tick_sec, _EPS), "damage": damage, "zone": zone, "zone_id": _burn_zone_seq, "wall": is_wall,
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


## Batch 2 (R1 Hơi Nước): removes up to [param stacks] Han from [param side] without a burst; returns how many went.
func consume_frost(side: int, stacks: int) -> int:
	var have: int = frost_stacks(side)
	var gone: int = mini(maxi(stacks, 0), have)
	if gone <= 0:
		return 0
	if have - gone <= 0:
		_frost.erase(side)
	else:
		_frost[side] = have - gone
	frost_changed.emit(side)
	return gone


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
	_totals[_total_key(STATUS_FROZEN, side)] = duration
	pinned.emit(side)


## Advances all timers by [param delta]; burning cells hurt the units standing on them in
## [param state] once per elapsed tick, however large the delta.
func tick(delta: float, state: CombatState) -> void:
	_check_thorn_entries(state)
	if delta <= 0.0:
		return
	_time += delta
	var leads: Dictionary = _burn_lead_cells(state)
	for cell: Vector2i in _burning.keys():
		var entry: Dictionary = _burning[cell] as Dictionary
		var active: float = minf(delta, float(entry["left"]))
		var tick_sec: float = float(entry["tick_sec"])
		var acc: float = float(entry["tick_acc"])
		var victims: Array[int] = _units_on(cell, state, leads)
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
	_tick_fields(delta, state)
	for side: int in _marks.keys():
		var m: Dictionary = _marks[side] as Dictionary
		m["left"] = float(m["left"]) - delta
		if float(m["left"]) <= _EPS:
			_marks.erase(side)
			mark_expired.emit(side)
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


## Batch 2 (R2 Vỡ Băng): ends the Pin of [param side] now (the unlock bookkeeping runs as for a timed-out pin).
## Returns true when a pin was running.
func end_pin(side: int) -> bool:
	if not _pins.has(side):
		return false
	_pins.erase(side)
	_mark_unlocked(side, 0.0)
	return true


## Removes every effect without emitting signals.
func clear() -> void:
	_burning.clear()
	_pins.clear()
	_roots.clear()
	_since_unlock.clear()
	_slows.clear()
	_guards.clear()
	_totals.clear()
	_fragile.clear()
	_frost.clear()
	_thorns.clear()
	_fields.clear()
	_marks.clear()
	_holes.clear()
	_hole_fade.clear()
	_last_cell.clear()
	_reaction_at.clear()


# --- Skill v2 batch 5: reaction rules (M15 ICD / immunity) -------------------------------------------------------------

## The ONE gate every reaction passes (CutEffects, SwingArbiter and this book): true when reaction [param id] (r1 / r2
## / r3) may fire on the unit of [param side] now: it is not immune ([member reaction_immune_fn]; a burn_eater boss is
## immune to R1) and its per-unit cooldown for that id has run out ([param icd_sec] < 0 = reaction_numbers.icd_sec, 1 s
## by default). A true answer STARTS the cooldown, so ask only when the reaction fires.
func reaction_allowed(side: int, id: String, icd_sec: float = -1.0) -> bool:
	if reaction_immune_fn.is_valid() and bool(reaction_immune_fn.call(side, id)):
		return false
	if id == "r1" and side == CombatState.Side.ENEMY and burn_heal_ratio_fn.is_valid() and float(burn_heal_ratio_fn.call()) > 0.0:
		return false
	var icd: float = icd_sec if icd_sec >= 0.0 else float(reaction_numbers.get("icd_sec", 1.0))
	var key: String = "%d|%s" % [side, id]
	if _reaction_at.has(key) and _time - float(_reaction_at[key]) < icd - _EPS:
		return false
	_reaction_at[key] = _time
	return true


## Seconds left of the reaction [param id]'s cooldown on [param side] (0 when it may fire).
func reaction_cooldown_left(side: int, id: String) -> float:
	var key: String = "%d|%s" % [side, id]
	if not _reaction_at.has(key):
		return 0.0
	return maxf(float(reaction_numbers.get("icd_sec", 1.0)) - (_time - float(_reaction_at[key])), 0.0)


## The book's clock (seconds ticked), for tests and probes.
func time() -> float:
	return _time


# --- Skill v2 batch 4: Dấu Tử (death mark, 02-design-decisions.md §7) ------------------------------------------------

## Status id of the death mark (HUD / VFX).
const STATUS_MARK: String = "mark"


## Puts the death mark on the unit of [param side] for [param sec] seconds: the next damaging cast on it echoes once at
## x [param echo_mult] and executes x2 at or under [param execute_ratio] of max HP. Re-applying refreshes (no stacking).
func apply_mark(side: int, sec: float, echo_mult: float, execute_ratio: float) -> void:
	if sec <= 0.0:
		return
	_marks[side] = {"left": sec, "total": sec, "echo_mult": maxf(echo_mult, 0.0), "execute_ratio": clampf(execute_ratio, 0.0, 1.0)}
	_totals[_total_key(STATUS_MARK, side)] = sec
	mark_applied.emit(side, sec)


## The death mark on [param side]: {left, total, echo_mult, execute_ratio}; {} when none.
func mark_at(side: int) -> Dictionary:
	return (_marks[side] as Dictionary).duplicate() if _marks.has(side) else {}


## True while the unit of [param side] carries the death mark.
func has_mark(side: int) -> bool:
	return _marks.has(side)


## Spends the death mark of [param side] (a damaging cast landed on it): returns its data ({} when none) and removes it.
func consume_mark(side: int) -> Dictionary:
	if not _marks.has(side):
		return {}
	var m: Dictionary = (_marks[side] as Dictionary).duplicate()
	_marks.erase(side)
	mark_triggered.emit(side)
	return m


# --- Skill v2 batch 3 field zones: trap (M09), ward (M10), pillar (M11) ----------------------------------------------

## A fresh cast id for a field zone cast (traps fire per cast; wards / pillars are grouped by it for the HUD).
func next_field_cast_id() -> int:
	_field_seq += 1
	return _field_seq


## Places a field zone of [param kind] (FIELD_KINDS) on [param cells] of [param side]'s half for [param duration]
## seconds, grouped under [param cast_id] with the card's [param data]. Each cell passes the one-zone-per-cell gate
## ([method _claim_zone_cell]: a locked cell, an armed trap or a solid pillar of another cast refuses it; a surface
## zone is replaced); the same kind on a cell refreshes it. Returns the cells placed; emits zone_applied(kind).
func apply_field(side: int, kind: String, cells: Array[Vector2i], duration: float, cast_id: int, data: Dictionary = {}) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	if duration <= 0.0 or cells.is_empty() or not FIELD_KINDS.has(kind):
		return placed
	for cell: Vector2i in cells:
		if placed.has(cell) or not _claim_zone_cell(cell, kind):
			continue
		_zone_of(_fields, side)[cell] = {"kind": kind, "left": duration, "total": duration, "cast_id": cast_id, "data": data.duplicate(true)}
		placed.append(cell)
	if not placed.is_empty():
		zone_applied.emit(kind, side, placed)
	return placed


## The field zone on [param cell] of [param side]'s half: {kind, left, total, cast_id, data}; {} when none.
func field_at(side: int, cell: Vector2i) -> Dictionary:
	var zone: Dictionary = _fields.get(side, {}) as Dictionary
	if not zone.has(cell):
		return {}
	var e: Dictionary = zone[cell] as Dictionary
	return {"kind": str(e["kind"]), "left": float(e["left"]), "total": float(e["total"]), "cast_id": int(e["cast_id"]), "data": e["data"]}


## The cells of [param side]'s half holding a field zone of [param kind] ("" = any), sorted by x then y.
func field_cells(side: int, kind: String = "") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var zone: Dictionary = _fields.get(side, {}) as Dictionary
	for cell: Vector2i in _sorted_cells(zone):
		if kind.is_empty() or str((zone[cell] as Dictionary)["kind"]) == kind:
			out.append(cell)
	return out


## True while [param cell] of [param side]'s half is a pillar (a step there is refused: the movers' blockers).
func is_pillar(side: int, cell: Vector2i) -> bool:
	return str(field_at(side, cell).get("kind", "")) == KIND_PILLAR


## Batch 3 (M09 cap): the number of trap casts of card [param skill_id] ("" = any card) still armed on [param side]'s half.
func trap_cast_count(side: int, skill_id: String = "") -> int:
	var ids: Dictionary = {}
	var zone: Dictionary = _fields.get(side, {}) as Dictionary
	for cell: Vector2i in zone.keys():
		var e: Dictionary = zone[cell] as Dictionary
		if str(e["kind"]) == KIND_TRAP and (skill_id.is_empty() or str((e["data"] as Dictionary).get("skill_id", "")) == skill_id):
			ids[int(e["cast_id"])] = true
	return ids.size()


## Removes the field zone on [param cell] of [param side] (no fire, no reaction), emitting zone_expired. True if one was there.
func remove_field(side: int, cell: Vector2i) -> bool:
	var zone: Dictionary = _fields.get(side, {}) as Dictionary
	if not zone.has(cell):
		return false
	var kind: String = str((zone[cell] as Dictionary)["kind"])
	zone.erase(cell)
	if zone.is_empty():
		_fields.erase(side)
	zone_expired.emit(kind, side, cell)
	return true


## Batch 3 (Gai Nổ): removes the thorns on [param cell] of [param side] without a toll, emitting zone_expired. True if any.
func clear_thorn_cell(side: int, cell: Vector2i) -> bool:
	var zone: Dictionary = _thorns.get(side, {}) as Dictionary
	if not zone.has(cell):
		return false
	zone.erase(cell)
	if zone.is_empty():
		_thorns.erase(side)
	zone_expired.emit(KIND_THORNS, side, cell)
	return true


## Batch 3 (M09): fires the trap cast [param cast_id] on [param side]'s half NOW: every trap cell of the cast is
## consumed; the unit of that side (alive) takes data.dpc x the trap cells under its footprint (at least 1), is Pinned
## data.pin_sec, pushed data.push_cells away from the divider (CutEffects.push_away; a short push slams when data.r3
## holds the R3 numbers). Returns the damage dealt (0 when nothing was armed). Called by the entry check and by
## CutEffects when the cast lands on the unit's own cell.
func fire_trap(side: int, cast_id: int, state: CombatState) -> float:
	var zone: Dictionary = _fields.get(side, {}) as Dictionary
	var cells: Array[Vector2i] = []
	var data: Dictionary = {}
	for cell: Vector2i in _sorted_cells(zone):
		var e: Dictionary = zone[cell] as Dictionary
		if str(e["kind"]) == KIND_TRAP and int(e["cast_id"]) == cast_id:
			cells.append(cell)
			data = e["data"] as Dictionary
	if cells.is_empty():
		return 0.0
	var under: int = 0
	for c: Vector2i in state.unit_cells(side):
		if cells.has(c):
			under += 1
	for cell: Vector2i in cells:
		remove_field(side, cell)
	var dead: bool = state.is_player_dead() if side == CombatState.Side.PLAYER else state.is_enemy_dead()
	var damage: float = float(data.get("dpc", 0.0)) * float(maxi(under, 1))
	# batch 5 (Deferred 8): the snap is a hit, so the target's flat defense takes its share (minimum 1), unless the card
	# pierces or the config keeps the old thorn-toll rule
	if trap_through_defense and not dead and damage > 0.0 and defense_fn.is_valid() and not bool(data.get("pierce_defense", false)):
		var defense: float = maxf(float(defense_fn.call(side)), 0.0)
		if defense > 0.0:
			damage = maxf(damage - defense, minf(damage, CutEffects.MIN_DAMAGE_AFTER_DEFENSE))
	if not dead:
		state.damage(side, damage)
		if float(data.get("pin_sec", 0.0)) > 0.0:
			pin(side, float(data["pin_sec"]))
		var push_cells: int = int(data.get("push_cells", 0))
		if push_cells > 0 and state.grid != null:
			# batch 5 (Deferred 9): the fling never enters a pillar / hole (the mover's blockers); a short fling slams
			var blocked: Callable = blocked_fn_for.call(side) as Callable if blocked_fn_for.is_valid() else Callable()
			var moved: int = CutEffects.push_away(state, state.grid, side, push_cells, blocked)
			var r3: Dictionary = data.get("r3", {}) as Dictionary
			var slam: bool = moved < push_cells
			# batch 5 (Deferred 5): a fling that ends on a thorn cell slams too (the thorns fire on the entry as well)
			if not slam and moved > 0:
				for c: Vector2i in state.unit_cells(side):
					if not thorns_at(side, c).is_empty():
						slam = true
						break
			if slam and not r3.is_empty() and reaction_allowed(side, "r3", float(r3.get("icd_sec", -1.0))):
				state.damage(side, float(r3.get("damage", 0.0)))
				if float(r3.get("pin_sec", 0.0)) > 0.0:
					pin(side, float(r3["pin_sec"]))
				reaction_fired.emit(side, "r3", float(r3.get("damage", 0.0)))
	trap_fired.emit(side, cast_id, cells, damage)
	return damage


## Batch 3 (M10): the ward under the unit of [param side] ({} when it stands on none): the field's data.
func ward_at(side: int, state: CombatState) -> Dictionary:
	var f: Dictionary = field_at(side, state.cell_of(side))
	if str(f.get("kind", "")) != KIND_WARD:
		return {}
	return f["data"] as Dictionary


## Batch 3 (M10): [param damage] about to hit the unit of [param side] after its ward: x data.damage_mult, then minus
## data.guard (never below 1 when the hit was at least 1), and a reduced hit gives the attacker data.attacker_frost Hàn
## (its burst lands on the attacker through [param state]). Unchanged when the unit stands on no ward.
func ward_absorb(side: int, damage: float, state: CombatState) -> float:
	var w: Dictionary = ward_at(side, state)
	if w.is_empty() or damage <= 0.0:
		return damage
	var out: float = damage * float(w.get("damage_mult", 1.0))
	var guard: float = float(w.get("guard", 0.0))
	if guard > 0.0:
		out = maxf(out - guard, minf(out, 1.0))
	var frost: int = int(w.get("attacker_frost", 0))
	if frost > 0 and out < damage - _EPS:
		var other: int = CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER
		var burst: float = apply_frost(other, frost)
		if burst > 0.0:
			state.damage(other, burst)
	return out


## Batch 3 (M10, Khiên Thép line_v): true while the unit of [param side] stands on a ward with push_immune.
func ward_push_immune(side: int, state: CombatState) -> bool:
	return bool(ward_at(side, state).get("push_immune", false))


## Batch 3 (M11): true while [param cell] burns as a fire wall (Hỏa Tuyến line): the enemy's mover refuses it.
func is_fire_wall(cell: Vector2i) -> bool:
	return _burning.has(cell) and bool((_burning[cell] as Dictionary).get("wall", false))


## The burning cells flagged as a fire wall, sorted by x then y.
func wall_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _burning.keys():
		if bool((_burning[cell] as Dictionary).get("wall", false)):
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


# Field zones count down (zone_expired at 0); a ward heals the unit standing on it data.heal_per_sec x delta.
func _tick_fields(delta: float, state: CombatState) -> void:
	for side: int in _fields.keys():
		var zone: Dictionary = _fields[side] as Dictionary
		var standing: Vector2i = state.cell_of(side)
		for cell: Vector2i in _sorted_cells(zone):
			var entry: Dictionary = zone[cell] as Dictionary
			if str(entry["kind"]) == KIND_WARD and cell == standing and side == CombatState.Side.PLAYER and not state.is_player_dead():
				var heal: float = float((entry["data"] as Dictionary).get("heal_per_sec", 0.0)) * delta
				if heal > 0.0:
					state.set_player_hp(state.player_hp + heal)
			var left: float = float(entry["left"]) - delta
			if left <= _EPS:
				zone.erase(cell)
				zone_expired.emit(str(entry["kind"]), side, cell)
			else:
				entry["left"] = left
		if zone.is_empty():
			_fields.erase(side)


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
	# batch 3: the field zones (traps never fire on a clear, wards / pillars just go)
	for s: int in _fields.keys():
		if side != -1 and s != side:
			continue
		var book: Dictionary = _fields[s] as Dictionary
		var field_cells_of: Array[Vector2i] = _sorted_cells(book)
		_fields.erase(s)
		for cell: Vector2i in field_cells_of:
			zone_expired.emit(str((book[cell] as Dictionary)["kind"]), s, cell)
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
	for side: int in _fields.keys():
		if (_fields[side] as Dictionary).has(cell):
			out.append(str(((_fields[side] as Dictionary)[cell] as Dictionary)["kind"]))
	if is_locked(cell):
		out.append(KIND_DROP)
	return out


# THE placement gate (rules 1-3, 5): may a zone of [param kind] go on [param cell]? A locked cell refuses every zone.
# Otherwise a zone of another kind is removed at once (cell_burned_out / zone_expired, so the HUD drops it) and true is
# returned; the caller then places its zone with its full duration (same kind = the caller's own refresh rule).
func _claim_zone_cell(cell: Vector2i, kind: String) -> bool:
	if is_locked(cell):
		return false
	# batch 3 (catalog §G): an armed trap or a solid pillar is never replaced by another zone (the new zone skips the
	# cell; the same kind refreshes it, the caller's rule); a lock (KIND_DROP) removes any field, a trap without firing
	# (X3 disarm); a surface field (ward) is replaced like thorns.
	for side: int in _fields.keys():
		var book: Dictionary = _fields[side] as Dictionary
		if not book.has(cell):
			continue
		var have: String = str((book[cell] as Dictionary)["kind"])
		if have == kind:
			continue
		if (have == KIND_TRAP or have == KIND_PILLAR) and kind != KIND_DROP:
			return false
		book.erase(cell)
		if book.is_empty():
			_fields.erase(side)
		zone_expired.emit(have, side, cell)
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
		var alive: bool = not _is_dead(side, state)
		# P2.2b: a unit falls at most once per tick (a multi-cell boss over several cracks of one drop).
		var fell: bool = false
		for cell: Vector2i in _sorted_cells(book):
			if not book.has(cell):
				continue
			var entry: Dictionary = book[cell] as Dictionary
			if str(entry["phase"]) == HOLE_PHASE_CRACK:
				# P2.2b: "on the cell" = any footprint cell of a multi-cell boss (the cell itself for 1 cell).
				var on_cell: bool = alive and state.unit_at(side, cell)
				# Held while the unit stands here and was Frozen / rooted at some point since it stepped on; leaving clears it.
				entry["held"] = on_cell and (bool(entry["held"]) or _unit_stuck(side))
				entry["left"] = float(entry["left"]) - delta
				if float(entry["left"]) > _EPS:
					continue
				if bool(entry["held"]):
					entry["left"] = 0.0
					continue
				fell = _fall_hole(side, cell, -float(entry["left"]), state, fell) or fell
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
# P2.2b: a multi-cell boss is "standing there" when any footprint cell is [param cell]; it lands on a neighbouring
# anchor whose whole footprint is open; [param already_fell] true = it fell this tick already (no second fall or
# damage). Returns true when a unit fell here.
func _fall_hole(side: int, cell: Vector2i, carry: float, state: CombatState, already_fell: bool = false) -> bool:
	var book: Dictionary = _holes[side] as Dictionary
	var entry: Dictionary = book[cell] as Dictionary
	var victim: bool = not already_fell and not _is_dead(side, state) and state.unit_at(side, cell)
	if victim and not hole_fall_lethal:
		var target: Vector2i = _landing_cell(side, cell, state.grid)
		if side == CombatState.Side.ENEMY and state.enemy_footprint_size() > 1:
			target = _landing_anchor(state)
		if target == BoardGrid.NO_CELL:
			book.erase(cell)
			hole_restored.emit(side, cell)
			return false
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
	return victim


# P2.2b, non-lethal fall of a multi-cell boss: the neighbouring anchor (up, right, down, left of the current one; ties by
# x then y) whose whole footprint fits, with no cracking / hole cell and nothing refused by hole_blocked_fn.
func _landing_anchor(state: CombatState) -> Vector2i:
	var best: Vector2i = BoardGrid.NO_CELL
	var e: int = CombatState.Side.ENEMY
	var blocked: Callable = func(c: Vector2i) -> bool:
		return _hole_phase(e, c) != "" or (hole_blocked_fn.is_valid() and bool(hole_blocked_fn.call(e, c)))
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var anchor: Vector2i = state.enemy_cell + dir
		if not state.enemy_fits(anchor, blocked):
			continue
		if best == BoardGrid.NO_CELL or anchor.x < best.x or (anchor.x == best.x and anchor.y < best.y):
			best = anchor
	return best


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
		if side == CombatState.Side.ENEMY and state.enemy_footprint_size() > 1:
			cell = _entered_cell(state, last)
			if cell == BoardGrid.NO_CELL:
				continue
		_burn_entry(side, cell, state)
		_r1_entry(side, cell, state)
		# batch 3 (M09): the first entry into a trap cell fires the whole cast
		var field: Dictionary = field_at(side, cell)
		if str(field.get("kind", "")) == KIND_TRAP:
			fire_trap(side, int(field["cast_id"]), state)
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


# P2.2b: a multi-cell enemy that moved from the anchor [param last_anchor] pays ONE entry toll per step: the cell
# returned is the first footprint cell it newly covers (footprint order) that holds thorns, else the first new one
# that burns, else the first new one (nothing to pay there); NO_CELL when it covers no new cell.
func _entered_cell(state: CombatState, last_anchor: Vector2i) -> Vector2i:
	var before: Array[Vector2i] = state.footprint_cells_at(last_anchor)
	var fresh: Array[Vector2i] = []
	for c: Vector2i in state.enemy_footprint_cells():
		if not before.has(c):
			fresh.append(c)
	if fresh.is_empty():
		return BoardGrid.NO_CELL
	for c: Vector2i in fresh:
		if not thorns_at(CombatState.Side.ENEMY, c).is_empty() or str(field_at(CombatState.Side.ENEMY, c).get("kind", "")) == KIND_TRAP:
			return c
	for c: Vector2i in fresh:
		if _burning.has(c):
			return c
	return fresh[0]


# Batch 5 (M15 R1, Deferred 5): a unit carrying Hàn that steps onto a burning cell reacts at once (hit or no hit):
# r1.burst_damage straight to its HP, the cell's burn put out, 1 Hàn spent; gated by the ICD / immunity.
func _r1_entry(side: int, cell: Vector2i, state: CombatState) -> void:
	if not _burning.has(cell) or frost_stacks(side) <= 0:
		return
	var dead: bool = state.is_player_dead() if side == CombatState.Side.PLAYER else state.is_enemy_dead()
	if dead or not reaction_allowed(side, "r1"):
		return
	var burst: float = float((reaction_numbers.get("r1", {}) as Dictionary).get("burst_damage", 12.0))
	consume_frost(side, 1)
	clear_burn([cell])
	state.damage(side, burst)
	reaction_fired.emit(side, "r1", burst)


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


# Sides of the living units standing on [param cell]. P2.2b: a multi-cell enemy counts only on the LEAD cell of each
# fire zone under it ([param leads], from _burn_lead_cells), so one zone ticks it once per tick however many of its
# cells the footprint covers; a 1-cell enemy is checked exactly as before.
func _units_on(cell: Vector2i, state: CombatState, leads: Dictionary = {}) -> Array[int]:
	var out: Array[int] = []
	if not state.is_player_dead() and state.player_cell == cell:
		out.append(CombatState.Side.PLAYER)
	if not state.is_enemy_dead():
		if state.enemy_footprint_size() <= 1:
			if state.enemy_cell == cell:
				out.append(CombatState.Side.ENEMY)
		elif leads.values().has(cell):
			out.append(CombatState.Side.ENEMY)
	return out


# P2.2b: zone id -> the one burning cell under a multi-cell enemy's footprint that ticks it (the first in footprint
# order: top row first, left to right). Empty for a 1-cell or dead enemy.
func _burn_lead_cells(state: CombatState) -> Dictionary:
	var leads: Dictionary = {}
	if state.enemy_footprint_size() <= 1 or state.is_enemy_dead():
		return leads
	for cell: Vector2i in state.enemy_footprint_cells():
		if not _burning.has(cell):
			continue
		var zone_id: int = int((_burning[cell] as Dictionary).get("zone_id", 0))
		if not leads.has(zone_id):
			leads[zone_id] = cell
	return leads


# --- Phase 2 statuses: Root (D2), Slow (D4), Guard (D5) ------------------------------------------------------------

## D2 Root (Troi): the unit of [param side] cannot step for [param duration] seconds (casting stays allowed). It is the
## same lock family as Frozen (pin): a Root never lands while the unit is Frozen or already Rooted (no stacking, spec F4;
## the cc grace window is the caller's rule, FairnessCheck.cc_allowed). Returns true when it landed. Own visual id
## [constant STATUS_ROOT] (the HUD chip / unit overlay).
func root(side: int, duration: float) -> bool:
	if duration <= 0.0 or is_pinned(side) or is_rooted(side):
		return false
	_roots[side] = duration
	_totals[_total_key(STATUS_ROOT, side)] = duration
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
	_totals[_total_key(STATUS_SLOW, side)] = float((_slows[side] as Dictionary)["left"])


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
	_totals[_total_key(STATUS_GUARD, side)] = float((_guards[side] as Dictionary)["left"])


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


# --- Controls v3: the player's buff / debuff row ------------------------------------------------------------------

## Visual / status id of Frozen (Dong Bang, the pin), Burn (the unit stands on a burning cell), Ran and Han (stacks).
const STATUS_FROZEN: String = "frozen"
const STATUS_BURN: String = "burn"
const STATUS_FRAGILE: String = "fragile"
const STATUS_CHILL: String = "chill"
## Order of the HUD row: the step locks first, then the other debuffs, the buff last.
const STATUS_ORDER: Array[String] = [STATUS_FROZEN, STATUS_ROOT, STATUS_SLOW, STATUS_BURN, STATUS_FRAGILE, STATUS_CHILL, STATUS_MARK, STATUS_GUARD]


func _total_key(id: String, side: int) -> String:
	return "%s:%d" % [id, side]


## Controls v3: the statuses on the unit of [param side] standing on [param cell] right now, in STATUS_ORDER, one
## {id, left, total, stacks, buff} each. A timed status has left / total in seconds (total = the length it was last
## applied for); a stack status (Ran, Han) has left = total = 0 and its stack count. Burn = [param cell] is burning
## (its time left, the length it was lit for, its stacks). Only active statuses are listed.
func active_statuses(side: int, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in STATUS_ORDER:
		var left: float = 0.0
		var stacks: int = 0
		match id:
			STATUS_FROZEN:
				left = get_pin_left(side)
			STATUS_ROOT:
				left = get_root_left(side)
			STATUS_SLOW:
				left = get_slow_left(side)
			STATUS_GUARD:
				left = get_guard_left(side)
			STATUS_BURN:
				left = get_burn_left(cell)
				stacks = stacks_at(cell)
			STATUS_FRAGILE:
				stacks = fragile_stacks(side)
			STATUS_CHILL:
				stacks = frost_stacks(side)
			STATUS_MARK:
				# batch 5 (Deferred 10): the death mark is a timed debuff chip (ui.status.mark.*)
				left = float(mark_at(side).get("left", 0.0))
		var timed: bool = id != STATUS_FRAGILE and id != STATUS_CHILL
		if (timed and left <= _EPS) or (not timed and stacks <= 0):
			continue
		var total: float = 0.0
		if id == STATUS_BURN:
			total = float((_burning[cell] as Dictionary).get("total", left))
		elif timed:
			total = float(_totals.get(_total_key(id, side), left))
		out.append({"id": id, "left": left if timed else 0.0, "total": maxf(total, left) if timed else 0.0,
			"stacks": stacks, "buff": id == STATUS_GUARD})
	return out


## Controls v3: share of a timed status still left (1 just applied, 0 at its end); 1 for a stack status.
static func status_left_fraction(entry: Dictionary) -> float:
	var total: float = float(entry.get("total", 0.0))
	if total <= 0.0:
		return 1.0
	return clampf(float(entry.get("left", 0.0)) / total, 0.0, 1.0)
