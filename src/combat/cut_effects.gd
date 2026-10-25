class_name CutEffects
extends RefCounted
## Applies a resolved cut to the combat state. Stateless. Implements: Story 008 (both
## directions so Story 009's boss can reuse it).


static var _warned_no_status: bool = false
# Story 027: CombatConfig's built-in zone numbers, used when options.zones is missing.
static var _zone_fallback: Dictionary = {}
## Execute (Hanh quyet) damage multiplier: the rule of the keyword, not a tuning number (the threshold is).
const EXECUTE_MULT: float = 2.0
## Flat defense never takes a hit below this much damage (OSFE 9.4: minimum 1).
const MIN_DAMAGE_AFTER_DEFENSE: float = 1.0
## Story 028: fallbacks of a `burn` featured bonus that omits its own burn_* numbers (arenas.json normally supplies them).
const FEATURED_BURN_DURATION_SEC: float = 2.0
const FEATURED_BURN_TICK_SEC: float = 0.5
const FEATURED_BURN_DAMAGE_PER_TICK: float = 1.5


## Resolves a swing by the attacker [param side] (a CombatState.Side value) over
## [param cells]. Hit = the target unit's cell is in [param cells] now. Slash does
## base * cells damage; push does that times its multiplier, then pushes the target one
## step away from the divider along its row if that cell exists. Unimplemented skills fall
## back to slash (warning). Returns {hit, damage, pushed, cell} where cell is the target's
## cell at resolve time, plus booleans burning / pinned (false by default). Dispatches on the
## skill's "effect": damage/push as above; burn ignites EVERY covered cell via [param status]
## (hit = target standing inside, no direct damage); pin pins the target when inside. With a
## null [param status] burn/pin do nothing (warning once). Story 018: an optional
## [param damage_modifier] Callable(cells: int, damage: float) -> float scales the FINAL damage number
## of a damage/push hit (the attacker's passive); invalid = unchanged.
## Story 020: [param level] (card level 1..) selects the upgraded numbers through
## SkillConfig.resolved. Damage = the card's damage_per_cell * cells (fallback: the cut config's
## base_damage_per_cell), then the Ghim multiplier while the target is pinned (result "pin_bonus"
## true), then the passive modifier.
## Story 021: [param cells_modifier] Callable(cells: int) -> int gives the cell count used for the
## card damage (signature Tram); [param signature_modifier] Callable(skill_id, cells, damage,
## target_pinned) -> float scales the damage LAST (after Ghim and the passive modifier).
## Story 023: damage order of a damage/push hit = card damage x conditions (bonus_vs_fragile_mult while the
## target has Ran) -> Ghim mult (control only, 1.0) -> Ran (x fragile_mult, spends 1 stack) -> execute (x2 at or
## below the ratio) -> passive -> signature -> flat defense (options.target_defense, minimum 1; skipped
## by `pierce_defense` cards). Effects "fragile" / "frost" (and the fragile_stacks / frost_stacks fields of
## any card) apply Ran / Han to the target when its cell is inside; Han reaching the burst deals the burst
## damage (ignores defense and Ran). [param options]: {target_defense: float (applies only to hits on the
## ENEMY side), execute_ratio: float (default for cards with `execute: true`),
## featured_bonus: Dictionary (Story 028, see below)}.
## Story 028 featured shape: when the PLAYER's swing carries `options.featured_bonus` {damage_mult, effect,
## stacks, sec, optional burn_duration_sec / burn_tick_sec / burn_damage_per_tick} and it HITS, the damage is
## multiplied by damage_mult. FULL damage order of a damage/push hit: card damage x conditions -> Ghim ->
## Ran -> FEATURED (x damage_mult) -> execute -> passive -> signature -> flat defense. Then, once, the effect:
## `fragile` / `frost` x stacks (Ran / Han on the boss, a Han burst damages directly), `burn` ignites the cast
## cells `stacks` times, `pin` pins the boss for `sec`. A miss applies nothing; boss swings never apply it.
## The result gains featured (bool), featured_mult, featured_effect, featured_stacks, featured_sec.
## Story 027 zones: effect `seal` / `thorns` forms the zone ONCE on the target's half over [param cells]
## when the swing arrives, HIT OR MISS (seals through ZoneRules.cast_seal, which keeps a path open). hit =
## the target stands inside (like burn). A seal card with damage_per_cell > 0 then deals the normal damage
## path on a hit; without it a hit only applies the card's keywords. options: zones (Dictionary, see
## CombatConfig.zone_numbers; a card's own seal_sec / thorn_sec / thorn_damage / thorn_fragile_stacks win),
## target_blocked_fn (Callable(cell) -> bool, the target mover's blockers, used by the leave-a-path rule).
## The result gains zone_kind ("" / "seal" / "thorns") and zone_cells (the cells actually placed).
## Story 032 relics (player swings only, through SwingArbiter): options.relic_modifier Callable(cells: int,
## damage: float) -> float is the ONE relic damage point, right after the featured multiplier: FULL order =
## card damage x conditions -> Ghim -> Ran -> featured -> RELICS (capped product) -> execute -> passive ->
## signature -> flat defense. options.zone_overrides (RelicRegistry.merge_overrides form) changes the
## player's seal seconds (`seal_sec`) and thorn Ran stacks per entry (`thorn_ran`) AFTER the card's own number.
static func apply(
	state: CombatState,
	grid: BoardGrid,
	side: int,
	cells: Array[Vector2i],
	skill_id: String,
	cut_config: CutConfig,
	skill_config: SkillConfig,
	status: StatusEffects = null,
	damage_modifier: Callable = Callable(),
	level: int = 1,
	cells_modifier: Callable = Callable(),
	signature_modifier: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	var target_side: int = CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER
	var target_cell: Vector2i = state.cell_of(target_side)
	var result: Dictionary = {
		"hit": false, "damage": 0.0, "pushed": false, "cell": target_cell,
		"burning": false, "pinned": false,
	}
	result["pin_bonus"] = false
	result["fragile_applied"] = 0
	result["frost_applied"] = 0
	result["frost_burst"] = 0.0
	result["fragile_hit"] = false
	result["executed"] = false
	result["defense_applied"] = 0.0
	result["featured"] = false
	result["featured_mult"] = 1.0
	result["featured_effect"] = ""
	result["featured_stacks"] = 0
	result["featured_sec"] = 0.0
	var featured: Dictionary = {}
	if side == CombatState.Side.PLAYER and typeof(options.get("featured_bonus")) == TYPE_DICTIONARY:
		featured = options["featured_bonus"] as Dictionary
	var skill: Dictionary = _resolve(skill_config, skill_id, level)
	if skill.is_empty() or not bool(skill["implemented"]):
		push_warning("CutEffects: skill '%s' is not implemented, using slash" % skill_id)
		skill_id = SkillConfig.FALLBACK_SKILL
		skill = _resolve(skill_config, skill_id, 1)
	var effect: String = str(skill.get("effect", "damage"))
	var inside: bool = cells.has(target_cell)
	result["zone_kind"] = ""
	result["zone_cells"] = [] as Array[Vector2i]
	if effect == "seal" or effect == "thorns":
		if status == null:
			if not _warned_no_status:
				_warned_no_status = true
				push_warning("CutEffects: skill '%s' needs a StatusEffects, ignored" % skill_id)
			return result
		_form_zone(state, grid, status, target_side, cells, effect, skill, options, result)
		if not inside:
			return result
		if float(skill.get("damage_per_cell", 0.0)) <= 0.0:
			result["hit"] = true
			_apply_keywords(state, status, target_side, skill, result)
			_apply_featured_effect(state, status, target_side, cells, featured, result)
			return result
		# A seal card with damage_per_cell > 0 (Long an) falls through to the normal damage path.
	if effect == "burn" or effect == "pin" or effect == "fragile" or effect == "frost":
		if status == null:
			if not _warned_no_status:
				_warned_no_status = true
				push_warning("CutEffects: skill '%s' needs a StatusEffects, ignored" % skill_id)
			return result
		if effect == "burn":
			status.ignite(
				cells, float(skill.get("burn_duration_sec", 0.0)),
				float(skill.get("burn_tick_sec", 0.5)), float(skill.get("burn_damage_per_tick", 0.0)))
			result["burning"] = true
			result["hit"] = inside
		elif effect == "pin" and inside:
			status.pin(target_side, float(skill.get("pin_duration_sec", 0.0)))
			result["pinned"] = true
			result["hit"] = true
		elif inside:
			result["hit"] = true
		if result["hit"]:
			_apply_keywords(state, status, target_side, skill, result)
			_apply_featured_effect(state, status, target_side, cells, featured, result)
		return result
	if not inside:
		return result
	var push_cells: int = int(skill.get("push_cells", 0))
	var per_cell: float = float(skill.get("damage_per_cell", cut_config.base_damage_per_cell * float(skill.get("damage_multiplier", 1.0))))
	var effective_cells: int = cells.size()
	if cells_modifier.is_valid():
		effective_cells = maxi(int(cells_modifier.call(effective_cells)), 0)
	var damage: float = per_cell * float(effective_cells)
	if status != null:
		if status.fragile_stacks(target_side) > 0 and float(skill.get("bonus_vs_fragile_mult", 1.0)) > 1.0:
			damage *= float(skill["bonus_vs_fragile_mult"])
		var pin_mult: float = status.damage_mult_against(target_side)
		if pin_mult != 1.0:
			damage *= pin_mult
			result["pin_bonus"] = true
		if status.fragile_stacks(target_side) > 0:
			damage *= status.consume_fragile(target_side)
			result["fragile_hit"] = true
	if not featured.is_empty():
		var featured_mult: float = float(featured.get("damage_mult", 1.0))
		damage *= featured_mult
		result["featured_mult"] = featured_mult
	var relic_modifier: Variant = options.get("relic_modifier")
	if typeof(relic_modifier) == TYPE_CALLABLE and (relic_modifier as Callable).is_valid():
		damage = float((relic_modifier as Callable).call(cells.size(), damage))
	var ratio: float = float(skill.get("execute_ratio", 0.0))
	if ratio <= 0.0 and bool(skill.get("execute", false)):
		ratio = float(options.get("execute_ratio", 0.0))
	if ratio > 0.0 and _hp_of(state, target_side) <= ratio * _max_hp_of(state, target_side):
		damage *= EXECUTE_MULT
		result["executed"] = true
	if damage_modifier.is_valid():
		damage = float(damage_modifier.call(cells.size(), damage))
	if signature_modifier.is_valid():
		damage = float(signature_modifier.call(
			skill_id, cells.size(), damage, status != null and status.is_pinned(target_side)))
	var defense: float = float(options.get("target_defense", 0.0)) if target_side == CombatState.Side.ENEMY else 0.0
	if defense > 0.0 and not bool(skill.get("pierce_defense", false)) and damage > 0.0:
		var after: float = maxf(damage - defense, minf(damage, MIN_DAMAGE_AFTER_DEFENSE))
		result["defense_applied"] = damage - after
		damage = after
	result["hit"] = true
	result["damage"] = damage
	state.damage(target_side, damage)
	if status != null:
		_apply_keywords(state, status, target_side, skill, result)
	_apply_featured_effect(state, status, target_side, cells, featured, result)
	if push_cells > 0:
		result["pushed"] = _push(state, grid, target_side, push_cells)
	return result


# Story 027: forms the card's zone ONCE when the swing arrives, hit or miss, on the TARGET side's half
# over the cut cells. Numbers: the card's own seal_sec / thorn_sec / thorn_damage / thorn_fragile_stacks,
# else options.zones (CombatConfig.zone_numbers()), else the CombatConfig built-in fallbacks. Seals go
# through ZoneRules.cast_seal (leave-a-path rule; options.target_blocked_fn adds cracks etc.).
static func _form_zone(
	state: CombatState, grid: BoardGrid, status: StatusEffects, target_side: int, cells: Array[Vector2i],
	effect: String, skill: Dictionary, options: Dictionary, result: Dictionary
) -> void:
	var numbers: Dictionary = _zone_defaults(options)
	var overrides: Dictionary = {}
	if typeof(options.get("zone_overrides")) == TYPE_DICTIONARY:
		overrides = options["zone_overrides"] as Dictionary
	var placed: Array[Vector2i] = []
	if effect == "seal":
		var blocked: Callable = options.get("target_blocked_fn", Callable()) as Callable
		placed = ZoneRules.cast_seal(
			state, grid, status, target_side, cells,
			maxf(RelicRegistry.apply_override(float(skill.get("seal_sec", numbers["seal_sec"])), overrides, "seal_sec"), 0.0),
			blocked)
	else:
		placed = ZoneRules.cast_thorns(
			status, target_side, cells, float(skill.get("thorn_sec", numbers["thorn_sec"])),
			float(skill.get("thorn_damage", numbers["thorn_damage"])),
			maxi(roundi(RelicRegistry.apply_override(
				float(skill.get("thorn_fragile_stacks", numbers["thorn_fragile_stacks"])), overrides, "thorn_ran")), 0))
	result["zone_kind"] = effect
	result["zone_cells"] = placed


# options.zones when it is a dictionary, else the CombatConfig fallbacks (built once).
static func _zone_defaults(options: Dictionary) -> Dictionary:
	if typeof(options.get("zones")) == TYPE_DICTIONARY:
		var given: Dictionary = options["zones"] as Dictionary
		var merged: Dictionary = _fallback_zone_numbers().duplicate()
		merged.merge(given, true)
		return merged
	return _fallback_zone_numbers()


static func _fallback_zone_numbers() -> Dictionary:
	if _zone_fallback.is_empty():
		_zone_fallback = CombatConfig.new().zone_numbers()
	return _zone_fallback


# Applies the card's Ran / Han stacks to the target after a hit (a card's own hit never benefits from
# its own Ran). A Han burst damages the target directly (ignores defense and Ran).
static func _apply_keywords(state: CombatState, status: StatusEffects, target_side: int, skill: Dictionary, result: Dictionary) -> void:
	var fragile: int = int(skill.get("fragile_stacks", 0))
	if fragile > 0:
		status.apply_fragile(target_side, fragile)
		result["fragile_applied"] = fragile
	var frost: int = int(skill.get("frost_stacks", 0))
	if frost > 0:
		var burst: float = status.apply_frost(target_side, frost)
		result["frost_applied"] = frost
		if burst > 0.0:
			result["frost_burst"] = burst
			state.damage(target_side, burst)


# Story 028: applies the featured bonus effect once after a HIT (no-op for an empty bonus, an unknown
# effect, or a null status for the status effects) and fills the result's featured_* fields.
static func _apply_featured_effect(
	state: CombatState, status: StatusEffects, target_side: int, cells: Array[Vector2i],
	featured: Dictionary, result: Dictionary
) -> void:
	if featured.is_empty():
		return
	var effect: String = str(featured.get("effect", ""))
	var stacks: int = maxi(int(featured.get("stacks", 0)), 0)
	var sec: float = maxf(float(featured.get("sec", 0.0)), 0.0)
	result["featured"] = true
	result["featured_effect"] = effect
	result["featured_stacks"] = stacks
	result["featured_sec"] = sec
	if status == null:
		return
	match effect:
		"fragile":
			status.apply_fragile(target_side, stacks)
			result["fragile_applied"] = int(result["fragile_applied"]) + stacks
		"frost":
			var burst: float = status.apply_frost(target_side, stacks)
			result["frost_applied"] = int(result["frost_applied"]) + stacks
			if burst > 0.0:
				result["frost_burst"] = float(result["frost_burst"]) + burst
				state.damage(target_side, burst)
		"burn":
			for _i: int in stacks:
				status.ignite(
					cells, float(featured.get("burn_duration_sec", FEATURED_BURN_DURATION_SEC)),
					float(featured.get("burn_tick_sec", FEATURED_BURN_TICK_SEC)),
					float(featured.get("burn_damage_per_tick", FEATURED_BURN_DAMAGE_PER_TICK)))
			result["burning"] = stacks > 0
		"pin":
			status.pin(target_side, sec)
			result["pinned"] = bool(result["pinned"]) or sec > 0.0


static func _hp_of(state: CombatState, side: int) -> float:
	return state.player_hp if side == CombatState.Side.PLAYER else state.enemy_hp


static func _max_hp_of(state: CombatState, side: int) -> float:
	return state.player_max_hp if side == CombatState.Side.PLAYER else state.enemy_max_hp


# The card dict at [param level]: SkillConfig.resolved when available, else the plain entry.
static func _resolve(skill_config: SkillConfig, skill_id: String, level: int) -> Dictionary:
	if skill_config.has_method("resolved"):
		return skill_config.call("resolved", skill_id, level) as Dictionary
	return skill_config.get_skill(skill_id)


# Moves the unit up to [param steps] cells away from the divider; stops at a missing cell
# or the board edge. True if it moved at all.
static func _push(state: CombatState, grid: BoardGrid, target_side: int, steps: int) -> bool:
	var dir: int = 1 if target_side == CombatState.Side.ENEMY else -1
	var cell: Vector2i = state.cell_of(target_side)
	var moved: bool = false
	for i: int in steps:
		var next: Vector2i = Vector2i(cell.x + dir, cell.y)
		var on_half: bool = grid.is_enemy_cell(next) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(next)
		if not on_half:
			break
		var ok: bool = state.set_enemy_cell(next) if target_side == CombatState.Side.ENEMY else state.set_player_cell(next)
		if not ok:
			break
		cell = next
		moved = true
	return moved
