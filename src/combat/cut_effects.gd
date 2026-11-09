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
## Story 027 zones: effect `thorns` forms the zone ONCE on the target's half over [param cells] when the
## swing arrives, HIT OR MISS. hit = the target stands inside (like burn); a thorn card with
## damage_per_cell > 0 then deals the normal damage path on a hit, without it a hit only applies the card's
## keywords. (The `seal` effect and its Wall cards were deleted 2026-11-01, ADR-0001 Phase 1 cleanup.)
## options: zones (Dictionary, see CombatConfig.zone_numbers; a card's own thorn_sec / thorn_damage /
## thorn_fragile_stacks win), target_blocked_fn (Callable(cell) -> bool, the target mover's blockers, used to
## skip blocked extra thorn cells), zone_rng (RandomNumberGenerator, picks the Vay Bat extra thorn cells).
## The result gains zone_kind ("" / "thorns") and zone_cells (the cells actually placed).
## Story 032 relics (player swings only, through SwingArbiter): options.relic_modifier Callable(cells: int,
## damage: float) -> float is the ONE relic damage point, right after the featured multiplier: FULL order =
## card damage x conditions -> Ghim -> Ran -> featured -> RELICS (capped product) -> execute -> passive ->
## signature -> flat defense. options.zone_overrides (RelicRegistry.merge_overrides form) changes the
## player's thorn seconds (`thorn_sec`, relic Gai Dai) and thorn Ran stacks per
## entry (`thorn_ran`) AFTER the card's own number. options.zone_sec_mult (Vay Bat) multiplies the THORN
## seconds only (the Wall part was removed by the 2026-10-31 quick spec) and options.extra_thorn_cells (int,
## Vay Bat) lays that many extra thorn cells next to the cast, see [method extra_thorn_cells].
## Cast rhythm spec 2026-11-05 (design/quick-specs/nhip-ra-chieu-2026-11-05.md 1.2) CRIT: a card with `crit`
## {when, mult} whose condition holds at the moment of the hit (CritRules.holds, read BEFORE this hit applies anything)
## multiplies the damage by mult right AFTER Ran (Fragile) and before featured: FULL order = card damage x conditions ->
## Ghim -> Ran -> CRIT -> featured -> relics -> execute -> passive -> signature -> flat defense. The result gains
## crit (bool) and crit_mult. PLAYER swings only: the block-brain boss reuses player cards and never crits.
## 1.1 PARRY (block-brain boss swings): options.player_guard (a ParryGuard, ENEMY swings only, SwingArbiter): when the
## swing would damage the PLAYER through the damage path while the guard is open, ParryGuard.try_parry takes it: the
## player loses 0, no keywords / push / featured apply, the boss takes the reflect and is pinned. The result gains
## parried (bool), reflected and blocked. A swing that only ignites / pins / forms a zone (no damage path) is not parried.
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
	result["crit"] = false
	result["crit_mult"] = 1.0
	result["parried"] = false
	# Quick spec 2026-11-01 rule 3 (design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md): a cracking cell or a hole is
	# LOCKED: it leaves the cast's cells before anything resolves (no damage, no status, no zone for a unit there; the
	# other cells resolve normally and the damage counts the cells left). The rule lives in StatusEffects.unlocked_cells.
	result["locked_cells"] = [] as Array[Vector2i]
	if status != null:
		var open_cells: Array[Vector2i] = status.unlocked_cells(cells)
		if open_cells.size() != cells.size():
			var locked: Array[Vector2i] = []
			for cell: Vector2i in cells:
				if not open_cells.has(cell):
					locked.append(cell)
			result["locked_cells"] = locked
			cells = open_cells
	var featured: Dictionary = {}
	if side == CombatState.Side.PLAYER and typeof(options.get("featured_bonus")) == TYPE_DICTIONARY:
		featured = options["featured_bonus"] as Dictionary
	var skill: Dictionary = _resolve(skill_config, skill_id, level)
	if skill.is_empty() or not bool(skill["implemented"]):
		push_warning("CutEffects: skill '%s' is not implemented, using slash" % skill_id)
		skill_id = SkillConfig.FALLBACK_SKILL
		skill = _resolve(skill_config, skill_id, 1)
	var effect: String = str(skill.get("effect", "damage"))
	# Story 037: heal_self heals the CASTER (the player) when the swing lands, hit or miss, at this ONE point.
	result["healed"] = 0.0
	# Skill v2 B1.5: options.apply_heal false = the arbiter heals once per scheduled cast itself (heal_caster).
	if bool(options.get("apply_heal", true)):
		result["healed"] = heal_caster(state, side, skill)
	# Story 036: options.target_untargetable (burrowed boss) = the cast misses the unit; zones still form (Story 027).
	# P2.2b (D13 / ADR-0001 A7): the target is inside when ANY of its cells is cast on (a multi-cell boss's footprint); this
	# is one boolean, so one swing hits once and the damage below never multiplies by the footprint cells it covers.
	var inside: bool = state.unit_in(target_side, cells) and not bool(options.get("target_untargetable", false))
	if inside and target_side == CombatState.Side.ENEMY:
		result["cell"] = state.enemy_hit_cell(cells)
	result["zone_kind"] = ""
	result["zone_cells"] = [] as Array[Vector2i]
	if effect == "thorns":
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
		# A thorn card with damage_per_cell > 0 falls through to the normal damage path.
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
		# 2026-11-05 (Mage balance): a burn card with damage_per_cell > 0 also deals the normal damage path on a hit
		# (the fire lands, then the ground burns), like a thorn card with damage; that path applies the keywords.
		var burn_hits_too: bool = effect == "burn" and inside and float(skill.get("damage_per_cell", 0.0)) > 0.0
		if not burn_hits_too:
			if result["hit"]:
				_apply_keywords(state, status, target_side, skill, result)
				_apply_featured_effect(state, status, target_side, cells, featured, result)
			return result
	if not inside:
		return result
	var push_cells: int = int(skill.get("push_cells", 0))
	var per_cell: float = float(skill.get("damage_per_cell", cut_config.base_damage_per_cell * float(skill.get("damage_multiplier", 1.0))))
	# Skill v2 B1.5 (M02): options.cast_cell_count = the cast's TOTAL cell count when only some of its cells are resolved
	# in this call (one impact event); -1 / absent = the cells given (every legacy call).
	var count: int = int(options.get("cast_cell_count", -1))
	if count < 0:
		count = cells.size()
	var effective_cells: int = count
	# Skill v2 (Ngàn Kiếm): a fixed_hit card deals damage_per_cell per HIT, never x cells; the signature's cell rule
	# (Trảm x2) does not apply to it. The relic / passive / signature hooks below still see the cast's cell count.
	var fixed_hit: bool = bool(skill.get("fixed_hit", false))
	if fixed_hit:
		effective_cells = 1
	if cells_modifier.is_valid() and not fixed_hit:
		effective_cells = maxi(int(cells_modifier.call(effective_cells)), 0)
	var damage: float = per_cell * float(effective_cells)
	# Cast rhythm spec 1.2: the crit condition is read at the moment of the hit, before Ran is spent or keywords land.
	# Only the hero's swings crit: the block-brain boss reuses player cards, and its swings never crit.
	# Skill v2 M19: the hit's wave index (combo_3), its cast context (line_full) and the time since the target was last
	# hit (first_strike) when the caller knows them.
	var crit_mult: float = CritRules.mult_for(skill, {"state": state, "status": status, "target_side": target_side,
		"wave_index": int(options.get("wave_index", -1)), "cast_context": options.get("cast_context", {}),
		"since_target_hit": float(options.get("since_target_hit", -1.0))}) if side == CombatState.Side.PLAYER else 1.0
	# Fix 2026-11-05: a swing whose condition held when it STARTED crits too (options.crit_mult_at_start, set by the
	# arbiter), so "cast while the foe is Frozen" crits even if the Pin ends during the swing.
	if side == CombatState.Side.PLAYER:
		crit_mult = maxf(crit_mult, float(options.get("crit_mult_at_start", 1.0)))
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
	if crit_mult != 1.0:
		damage *= crit_mult
		result["crit"] = true
		result["crit_mult"] = crit_mult
	# Skill v2 (02-design-decisions.md §10): the impact event's shape-clause group S (burst-first, surge, wave_mults),
	# applied right after crit; 1.0 for every legacy call.
	var impact_mult: float = float(options.get("impact_mult", 1.0))
	if impact_mult != 1.0:
		damage *= impact_mult
		result["impact_mult"] = impact_mult
	if not featured.is_empty():
		var featured_mult: float = float(featured.get("damage_mult", 1.0))
		damage *= featured_mult
		result["featured_mult"] = featured_mult
	var relic_modifier: Variant = options.get("relic_modifier")
	if typeof(relic_modifier) == TYPE_CALLABLE and (relic_modifier as Callable).is_valid():
		damage = float((relic_modifier as Callable).call(count, damage))
	var ratio: float = float(skill.get("execute_ratio", 0.0))
	if ratio <= 0.0 and bool(skill.get("execute", false)):
		ratio = float(options.get("execute_ratio", 0.0))
	if ratio > 0.0 and _hp_of(state, target_side) <= ratio * _max_hp_of(state, target_side):
		damage *= EXECUTE_MULT
		result["executed"] = true
	if damage_modifier.is_valid():
		damage = float(damage_modifier.call(count, damage))
	if signature_modifier.is_valid():
		damage = float(signature_modifier.call(
			skill_id, count, damage, status != null and status.is_pinned(target_side)))
	var defense: float = float(options.get("target_defense", 0.0)) if target_side == CombatState.Side.ENEMY else 0.0
	if defense > 0.0 and not bool(skill.get("pierce_defense", false)) and damage > 0.0:
		var after: float = maxf(damage - defense, minf(damage, MIN_DAMAGE_AFTER_DEFENSE))
		result["defense_applied"] = damage - after
		damage = after
	result["hit"] = true
	var guard: ParryGuard = options.get("player_guard") as ParryGuard
	if target_side == CombatState.Side.PLAYER and guard != null and guard.is_active():
		var parry: Dictionary = guard.try_parry(state, status, damage)
		result["parried"] = true
		result["reflected"] = float(parry.get("reflected", 0.0))
		result["blocked"] = float(parry.get("blocked", 0.0))
		return result
	result["damage"] = damage
	state.damage(target_side, damage)
	if status != null:
		_apply_keywords(state, status, target_side, skill, result)
	_apply_featured_effect(state, status, target_side, cells, featured, result)
	if push_cells > 0:
		result["pushed"] = _push(state, grid, target_side, push_cells)
	return result


# Story 027: forms the card's zone ONCE when the swing arrives, hit or miss, on the TARGET side's half
# over the cut cells. Numbers: the card's own thorn_sec / thorn_damage / thorn_fragile_stacks, else
# options.zones (CombatConfig.zone_numbers()), else the CombatConfig built-in fallbacks.
static func _form_zone(
	state: CombatState, grid: BoardGrid, status: StatusEffects, target_side: int, cells: Array[Vector2i],
	effect: String, skill: Dictionary, options: Dictionary, result: Dictionary
) -> void:
	var numbers: Dictionary = _zone_defaults(options)
	var overrides: Dictionary = {}
	if typeof(options.get("zone_overrides")) == TYPE_DICTIONARY:
		overrides = options["zone_overrides"] as Dictionary
	# Story 037 / quick spec 2026-10-31: the player's signature (Vay Bat) lengthens the THORNS it forms
	# (1.0 = unchanged) and may lay extra thorn cells.
	var sec_mult: float = maxf(float(options.get("zone_sec_mult", 1.0)), 0.0)
	var blocked: Callable = options.get("target_blocked_fn", Callable()) as Callable
	var thorn_cells: Array[Vector2i] = cells.duplicate()
	var extra: int = maxi(int(options.get("extra_thorn_cells", 0)), 0)
	if extra > 0:
		var rng: RandomNumberGenerator = options.get("zone_rng") as RandomNumberGenerator
		thorn_cells.append_array(extra_thorn_cells(state, grid, status, target_side, cells, extra, blocked, rng))
	var placed: Array[Vector2i] = ZoneRules.cast_thorns(
		status, target_side, thorn_cells,
		maxf(RelicRegistry.apply_override(float(skill.get("thorn_sec", numbers["thorn_sec"])), overrides, "thorn_sec"), 0.0) * sec_mult,
		float(skill.get("thorn_damage", numbers["thorn_damage"])),
		maxi(roundi(RelicRegistry.apply_override(
			float(skill.get("thorn_fragile_stacks", numbers["thorn_fragile_stacks"])), overrides, "thorn_ran")), 0))
	result["zone_kind"] = effect
	result["zone_cells"] = placed


## Vay Bat (quick spec o-rot-thay-tuong 2026-10-31, "rai them 1 o"): up to [param count] extra thorn cells
## for a thorn cast on [param cells]. Candidates: cells of [param target_side]'s half 4-adjacent to a cast
## cell that are not a cast cell, not the target unit's own cell (any footprint cell of a multi-cell boss, P2.2b;
## thorns formed under a unit never trigger),
## not already thorned and not blocked for the target ([param blocked_fn]: hole / crack / sand...). The pick is
## RANDOM among those candidates (user 2026-11-01: no "nearest the boss" rule), drawn from [param rng] (the match's
## seeded zone RNG, SwingArbiter.zone_rng; inject a seeded one in tests). A null [param rng] uses a fresh randomized
## one. None left = fewer cells.
static func extra_thorn_cells(
	state: CombatState, grid: BoardGrid, status: StatusEffects, target_side: int, cells: Array[Vector2i],
	count: int, blocked_fn: Callable = Callable(), rng: RandomNumberGenerator = null
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if count <= 0 or grid == null or state == null:
		return out
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in cells:
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + dir
			var on_half: bool = grid.is_enemy_cell(n) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(n)
			# P2.2b: every cell of a multi-cell boss is "the target unit's own cell".
			if not on_half or state.unit_at(target_side, n) or cells.has(n) or candidates.has(n):
				continue
			if status != null and not status.thorns_at(target_side, n).is_empty():
				continue
			if blocked_fn.is_valid() and bool(blocked_fn.call(n)):
				continue
			candidates.append(n)
	# Sorted first so a given seed always gives the same pick whatever the order of the cast cells.
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	while out.size() < count and not candidates.is_empty():
		out.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return out


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


## Story 037 heal_self of [param skill] (a level-resolved card) for a PLAYER cast by [param side]: heals the hero once,
## returns the HP actually healed (0 for the boss, a dead hero or no heal_self). Shared by apply and the arbiter.
static func heal_caster(state: CombatState, side: int, skill: Dictionary) -> float:
	var heal_self: float = float(skill.get("heal_self", 0.0))
	if side != CombatState.Side.PLAYER or heal_self <= 0.0 or state.is_player_dead():
		return 0.0
	var hp_before: float = state.player_hp
	state.set_player_hp(hp_before + heal_self)
	return state.player_hp - hp_before


## The level-resolved card [param skill_id] (the fallback card when unknown / not implemented), as apply uses it.
static func resolved_skill(skill_config: SkillConfig, skill_id: String, level: int) -> Dictionary:
	var skill: Dictionary = _resolve(skill_config, skill_id, level)
	if skill.is_empty() or not bool(skill["implemented"]):
		skill = _resolve(skill_config, SkillConfig.FALLBACK_SKILL, 1)
	return skill


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
