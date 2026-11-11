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
	var reactions: Dictionary = reaction_numbers(options)
	var card_reacts: Array = skill.get("reactions", []) as Array
	if not card_reacts.is_empty():
		result["reaction"] = ""  # the reaction that fired on this hit ("" = none); batch 5: a global reaction sets the key when it fires
	# Batch 2 (Lốc Cuốn, M12 pull): a unit inside or 4-adjacent to the mask is pulled toward the mask's centre BEFORE
	# the hit is judged (the card's pull_cells, or the clause's when it holds); a blocked step is R3 (batch 5: for every
	# card when reactions.global, else for the cards that list it; the M15 ICD gates it).
	var pull: int = int(skill.get("pull_cells", 0))
	# batch 5 (Deferred 4): the first of the card's shape clauses that holds for this cast ({} = none)
	var clause: Dictionary = CastResolver.active_clause(skill, options.get("cast_context", {}) as Dictionary)
	var clause_holds: bool = not clause.is_empty()
	if clause_holds and clause.has("pull_cells"):
		pull = int(clause["pull_cells"])
	if pull > 0 and grid != null and not cells.is_empty() and not bool(options.get("target_untargetable", false)):
		var tc: Vector2i = state.cell_of(target_side)
		if state.unit_in(target_side, cells) or _adjacent_to(state, target_side, cells):
			var centre: Vector2i = ShapeTags.tags_for(cells, false, state.cell_of(side))["centre"]
			var moved: Dictionary = pull_toward(state, grid, target_side, centre, pull, options.get("target_blocked_fn", Callable()) as Callable)
			result["pulled"] = int(moved["steps"]) > 0
			result["pull_from"] = tc
			if bool(moved["blocked"]):
				_react_r3(state, status, target_side, reactions, result, skill)
			elif int(moved["steps"]) > 0:
				_r3_on_thorns(state, status, target_side, reactions, result, skill)
	var inside: bool = state.unit_in(target_side, cells) and not bool(options.get("target_untargetable", false))
	if inside and target_side == CombatState.Side.ENEMY:
		result["cell"] = state.enemy_hit_cell(cells)
	result["zone_kind"] = ""
	result["zone_cells"] = [] as Array[Vector2i]
	# Batch 3 field zones: trap (M09), ward (M10, on the cells already re-anchored on the hero), pillar (M11). They form
	# hit or miss; a trap cast on the unit's own cell fires at once. The enemy is never "hit" by a ward or a pillar.
	if effect == "trap" or effect == "ward" or effect == "pillar":
		if status == null:
			if not _warned_no_status:
				_warned_no_status = true
				push_warning("CutEffects: skill '%s' needs a StatusEffects, ignored" % skill_id)
			return result
		_form_field(state, grid, status, side, target_side, cells, effect, skill, options, result)
		return result
	# Batch 3 (Gai Nổ): detonate_zones consumes the player's thorn / trap cells inside the mask; the damage below counts
	# only the detonated cells under the target's footprint (no field = a miss), + fragile_per_cell Rạn each.
	var detonated_under: int = -1
	if bool(skill.get("detonate_zones", false)) and status != null:
		var blown: Array[Vector2i] = []
		for c: Vector2i in cells:
			var is_trap: bool = str(status.field_at(target_side, c).get("kind", "")) == StatusEffects.KIND_TRAP
			# batch 5 (Deferred 9): a fire-wall column (Hỏa Tuyến line) is a field the blast consumes too
			if not status.thorns_at(target_side, c).is_empty() or is_trap or status.is_fire_wall(c):
				blown.append(c)
		for c: Vector2i in blown:
			status.clear_thorn_cell(target_side, c)
			status.remove_field(target_side, c)
			if status.is_fire_wall(c):
				status.clear_burn([c])
		result["detonated"] = blown
		detonated_under = 0
		for c: Vector2i in state.unit_cells(target_side):
			if blown.has(c):
				detonated_under += 1
		_regrow_tips(status, target_side, cells, skill, options)
		if detonated_under <= 0:
			return result
		skill = skill.duplicate()
		skill["fragile_stacks"] = int(skill.get("fragile_per_cell", 0)) * detonated_under
		cells = blown
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
			# batch 5 (M15 R1 "is ignited on": Deferred 2 / 5): the fire lands under a unit that carries Hàn
			if inside and status.frost_stacks(target_side) > 0:
				try_r1(state, status, target_side, reactions, result, skill)
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
	if detonated_under >= 0:
		count = detonated_under
	# Batch 1 (Thương Xuyên): dpc_bonus grows damage_per_cell with the cast's cell count (SkillConfig). Cards without
	# the field get no result key (the legacy golden fixture compares whole results).
	if not (skill.get("dpc_bonus", {}) as Dictionary).is_empty():
		result["dpc_bonus"] = dpc_bonus(skill, count)
		per_cell += float(result["dpc_bonus"])
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
	# Batch 4 (02-design-decisions.md §7): options.echo = this is an echo wave (a card echo or the death mark's): it
	# neither consumes nor receives Rạn, never crits and never executes.
	var is_echo: bool = bool(options.get("echo", false))
	var crit_mult: float = CritRules.mult_for(skill, {"state": state, "status": status, "target_side": target_side,
		"wave_index": int(options.get("wave_index", -1)), "cast_context": options.get("cast_context", {}),
		"since_target_hit": float(options.get("since_target_hit", -1.0))}) if side == CombatState.Side.PLAYER and not is_echo else 1.0
	# Fix 2026-11-05: a swing whose condition held when it STARTED crits too (options.crit_mult_at_start, set by the
	# arbiter), so "cast while the foe is Frozen" crits even if the Pin ends during the swing.
	if side == CombatState.Side.PLAYER and not is_echo:
		crit_mult = maxf(crit_mult, float(options.get("crit_mult_at_start", 1.0)))
	if status != null and is_echo:
		var pin_mult_echo: float = status.damage_mult_against(target_side)
		if pin_mult_echo != 1.0:
			damage *= pin_mult_echo
			result["pin_bonus"] = true
	elif status != null:
		# Batch 2 (Băng Vỡ): fragile_timing "before" lands the card's Rạn before this hit spends one.
		if str(skill.get("fragile_timing", "after")) == "before" and int(skill.get("fragile_stacks", 0)) > 0:
			status.apply_fragile(target_side, int(skill["fragile_stacks"]))
			result["fragile_applied"] = int(skill["fragile_stacks"])
		if status.fragile_stacks(target_side) > 0 and float(skill.get("bonus_vs_fragile_mult", 1.0)) > 1.0:
			damage *= float(skill["bonus_vs_fragile_mult"])
		var pin_mult: float = status.damage_mult_against(target_side)
		if pin_mult != 1.0:
			damage *= pin_mult
			result["pin_bonus"] = true
		if status.fragile_stacks(target_side) > 0:
			# Batch 2 (R2 Vỡ Băng, cards that list it): a damage event on a Pinned unit with Rạn deals x r2.mult instead
			# of the Rạn multiplier; the stack is spent and the Pin ends at once.
			if status.is_pinned(target_side) and _reaction_ok(status, target_side, "r2", skill, reactions):
				status.consume_fragile(target_side)
				status.end_pin(target_side)
				damage *= float((reactions["r2"] as Dictionary)["mult"])
				result["reaction"] = "r2"
			else:
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
	# Batch 1 (Đập Vỡ): a guard_break card strips the target's Guard BEFORE the damage and deals x guard_break_mult when
	# Guard was present; the stripped amount leaves the flat defense of this hit (options.target_defense carries it).
	var guard_stripped: float = 0.0
	if bool(skill.get("guard_break", false)):
		result["guard_broken"] = false
		if status != null and status.guard_amount(target_side) > 0.0:
			guard_stripped = status.guard_amount(target_side)
			status.clear_guard(target_side)
			damage *= float(skill.get("guard_break_mult", 1.0))
			result["guard_broken"] = true
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
	# Batch 4 (Dấu Tử): the cast that triggers a death mark executes at the mark's ratio (never its echo).
	if not is_echo and float(options.get("mark_execute_ratio", 0.0)) > 0.0:
		ratio = maxf(ratio, float(options["mark_execute_ratio"]))
	if is_echo:
		ratio = 0.0
	if ratio > 0.0 and _hp_of(state, target_side) <= ratio * _max_hp_of(state, target_side):
		damage *= EXECUTE_MULT
		result["executed"] = true
	if damage_modifier.is_valid():
		damage = float(damage_modifier.call(count, damage))
	if signature_modifier.is_valid():
		damage = float(signature_modifier.call(
			skill_id, count, damage, status != null and status.is_pinned(target_side)))
	var defense: float = float(options.get("target_defense", 0.0)) if target_side == CombatState.Side.ENEMY else 0.0
	defense = maxf(defense - guard_stripped, 0.0)
	if defense > 0.0 and not bool(skill.get("pierce_defense", false)) and damage > 0.0:
		var after: float = maxf(damage - defense, minf(damage, MIN_DAMAGE_AFTER_DEFENSE))
		result["defense_applied"] = damage - after
		damage = after
	result["hit"] = true
	# Batch 3 (M10): the hero standing on a ward takes x damage_mult, minus the ward's Guard (a reduced hit may chill the
	# attacker); StatusEffects.ward_absorb, the same hook PatternController uses for pattern skills.
	if target_side == CombatState.Side.PLAYER and status != null:
		var absorbed: float = status.ward_absorb(target_side, damage, state)
		if absorbed < damage:
			result["warded"] = damage - absorbed
			damage = absorbed
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
		_apply_keywords(state, status, target_side, skill, result, options.get("cast_context", {}) as Dictionary)
		# Batch 4 (Dấu Tử): the card's own hit leaves the death mark (refreshed, never stacked; a clause mark_sec lengthens it).
		var mark: Dictionary = skill.get("mark", {}) as Dictionary
		if not mark.is_empty() and not is_echo:
			var sec: float = float(mark["sec"])
			if clause.has("mark_sec"):
				sec = float(clause["mark_sec"])
			status.apply_mark(target_side, sec, float(mark["echo_mult"]), float(mark["execute_ratio"]))
			result["marked"] = sec
		# Batch 2 (R1 Hơi Nước, cards that list it): this hit gave Hàn while the target stands on a burning cell.
		if int(result["frost_applied"]) > 0:
			try_r1(state, status, target_side, reactions, result, skill)
		# Batch 2 (Lốc Cuốn square): a clause pin_sec that holds pins the target on the hit.
		if clause_holds and float(clause.get("pin_sec", 0.0)) > 0.0:
			status.pin(target_side, float(clause["pin_sec"]))
			result["pinned"] = true
	_apply_featured_effect(state, status, target_side, cells, featured, result)
	# Batch 2 (Địa Chấn line): a clause push_cells that holds replaces the card's push.
	if clause_holds and clause.has("push_cells"):
		push_cells = int(clause["push_cells"])
	# Batch 3 (Khiên Thép line_v): a ward with push_immune holds the hero in place.
	if push_cells > 0 and target_side == CombatState.Side.PLAYER and status != null and status.ward_push_immune(target_side, state):
		result["pushed"] = false
		result["push_immune"] = true
		push_cells = 0
	if push_cells > 0:
		# batch 3: a push never enters a blocked cell (a pillar, a hole: options.target_blocked_fn, the target mover's test)
		var steps: int = _push(state, grid, target_side, push_cells, options.get("target_blocked_fn", Callable()) as Callable)
		result["pushed"] = steps > 0
		# Batch 2 (R3 Va Đập): a push stopped short (edge, hole, blocked cell) slams the target; batch 5: global, and a
		# push that ends on a thorn cell slams too (Deferred 5).
		if steps < push_cells and status != null and str(result.get("reaction", "")).is_empty():
			_react_r3(state, status, target_side, reactions, result, skill)
		elif steps > 0:
			_r3_on_thorns(state, status, target_side, reactions, result, skill)
	return result


## Batch 5 (M15): true when reaction [param id] fires for card [param skill]: every card when [param reactions].global
## (combat.json, the default), else only a card whose `reactions` list names it.
static func reaction_enabled(skill: Dictionary, id: String, reactions: Dictionary) -> bool:
	if bool(reactions.get("global", true)):
		return true
	return (skill.get("reactions", []) as Array).has(id)


# The gate before a reaction fires: enabled for the card AND allowed by the status book (immunity, the per-unit ICD;
# StatusEffects.reaction_allowed starts the cooldown). No status book = no ICD.
static func _reaction_ok(status: StatusEffects, target_side: int, id: String, skill: Dictionary, reactions: Dictionary) -> bool:
	if not reaction_enabled(skill, id, reactions):
		return false
	if status == null:
		return true
	return status.reaction_allowed(target_side, id, float(reactions.get("icd_sec", -1.0)))


# Batch 5 (Deferred 5): a forced move that ENDED on a thorn cell slams (R3) on top of the thorn toll the entry pays.
static func _r3_on_thorns(state: CombatState, status: StatusEffects, target_side: int, reactions: Dictionary, result: Dictionary, skill: Dictionary) -> void:
	if status == null or not str(result.get("reaction", "")).is_empty():
		return
	for c: Vector2i in state.unit_cells(target_side):
		if not status.thorns_at(target_side, c).is_empty():
			_react_r3(state, status, target_side, reactions, result, skill)
			return


## Batch 2 (R1 Hơi Nước): fires R1 on [param target_side] when it stands on a burning cell and the card gave it Hàn
## (one reaction per event: skipped when [param result].reaction is already set): burst r1.burst_damage straight to its
## HP (ignores defense and Rạn), that cell's burn is put out, 1 Hàn is spent. True when it fired. Also called by
## SwingArbiter after an event's ignite payload, so a card that ignites and chills in one event (Hỏa Băng) reacts.
static func try_r1(state: CombatState, status: StatusEffects, target_side: int, reactions: Dictionary, result: Dictionary,
		skill: Dictionary = {}) -> bool:
	if not str(result.get("reaction", "")).is_empty() or status == null:
		return false
	var cell: Vector2i = state.cell_of(target_side)
	if target_side == CombatState.Side.ENEMY:
		# a multi-cell boss reacts on any burning footprint cell
		for c: Vector2i in state.enemy_footprint_cells():
			if status.is_burning(c):
				cell = c
				break
	if not status.is_burning(cell) or status.frost_stacks(target_side) <= 0:
		return false
	# batch 5 (M15): global or card-listed, then the ICD / immunity (a burn_eater boss never reacts)
	if not _reaction_ok(status, target_side, "r1", skill, reactions):
		return false
	var burst: float = float((reactions.get("r1", {}) as Dictionary).get("burst_damage", 12.0))
	status.consume_frost(target_side, 1)
	status.clear_burn([cell])
	state.damage(target_side, burst)
	result["reaction"] = "r1"
	result["reaction_damage"] = burst
	result["reaction_cell"] = cell
	return true


# Batch 2 (R3 Va Đập): [param reactions].r3 damage straight to the HP of [param target_side] and a Pin of pin_sec.
## Batch 5: returns true when it fired (the gate: reactions.global or the card lists r3, then the ICD / immunity).
static func _react_r3(state: CombatState, status: StatusEffects, target_side: int, reactions: Dictionary, result: Dictionary,
		skill: Dictionary = {}) -> bool:
	if not _reaction_ok(status, target_side, "r3", skill, reactions):
		return false
	var r3: Dictionary = reactions.get("r3", {}) as Dictionary
	var dmg: float = float(r3.get("damage", 8.0))
	state.damage(target_side, dmg)
	if status != null and float(r3.get("pin_sec", 0.0)) > 0.0:
		status.pin(target_side, float(r3["pin_sec"]))
		result["pinned"] = true
	result["reaction"] = "r3"
	result["reaction_damage"] = dmg
	return true


## Batch 2: the reaction numbers CutEffects uses: options.reactions (CombatConfig.reactions()) laid over the built-in
## defaults {r1: {burst_damage 12}, r2: {mult 2}, r3: {damage 8, pin_sec 0.6}}; batch 5 (M15 rules): icd_sec 1.0 (the
## per-unit per-reaction cooldown), global true (every card reacts; false = only the cards that list the reaction).
static func reaction_numbers(options: Dictionary) -> Dictionary:
	var out: Dictionary = {"r1": {"burst_damage": 12.0}, "r2": {"mult": 2.0}, "r3": {"damage": 8.0, "pin_sec": 0.6},
		"icd_sec": 1.0, "global": true}
	if typeof(options.get("reactions")) == TYPE_DICTIONARY:
		for k: Variant in (options["reactions"] as Dictionary).keys():
			var v: Variant = (options["reactions"] as Dictionary)[k]
			if out.has(k) and v is Dictionary:
				(out[k] as Dictionary).merge(v as Dictionary, true)
			elif str(k) == "icd_sec" and (v is float or v is int) and float(v) >= 0.0:
				out["icd_sec"] = float(v)
			elif str(k) == "global" and v is bool:
				out["global"] = bool(v)
	return out


## Batch 2: true when a resolve of [param skill] on [param cells] can touch the unit of [param target_side] now: it
## stands inside, or the card pulls (pull_cells, or a pull clause) and it stands 4-adjacent. SwingArbiter gates its
## scheduled events with this (an instant swing always calls apply). Batch 3: a field-zone card (trap / ward /
## pillar) or a detonating card always resolves (the zone forms, hit or miss).
static func can_affect(state: CombatState, skill: Dictionary, target_side: int, cells: Array[Vector2i]) -> bool:
	if state.unit_in(target_side, cells):
		return true
	var effect: String = str(skill.get("effect", ""))
	if effect == "trap" or effect == "ward" or effect == "pillar" or bool(skill.get("detonate_zones", false)):
		return true
	var pulls: bool = int(skill.get("pull_cells", 0)) > 0
	for c: Dictionary in CastResolver.shape_clauses(skill):
		if c.has("pull_cells"):
			pulls = true
	return pulls and _adjacent_to(state, target_side, cells)


# True when a cell of [param target_side]'s unit is 4-adjacent to a cell of [param cells] (not inside).
static func _adjacent_to(state: CombatState, target_side: int, cells: Array[Vector2i]) -> bool:
	for u: Vector2i in state.unit_cells(target_side):
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(u + d):
				return true
	return false


## Batch 2 (Lốc Cuốn, M12 pull): moves the unit of [param target_side] up to [param steps] cells TOWARD [param to]
## (the mask's centre), one axis step at a time (the larger offset first, ties the row), never onto a cell of the
## wrong half, a blocked cell ([param blocked_fn]) or one the footprint does not fit; stops on [param to].
## Returns {steps (moved), blocked (true when a wanted step was refused)}.
static func pull_toward(state: CombatState, grid: BoardGrid, target_side: int, to: Vector2i, steps: int,
		blocked_fn: Callable = Callable()) -> Dictionary:
	var moved: int = 0
	var blocked: bool = false
	var cell: Vector2i = state.cell_of(target_side)
	for i: int in steps:
		var d: Vector2i = to - cell
		if d == Vector2i.ZERO:
			break
		var dir: Vector2i = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var next: Vector2i = cell + dir
		var on_half: bool = grid.is_enemy_cell(next) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(next)
		var fits: bool = on_half and not (blocked_fn.is_valid() and bool(blocked_fn.call(next)))
		if fits and target_side == CombatState.Side.ENEMY:
			fits = state.enemy_fits(next, blocked_fn)
		var ok: bool = fits and (state.set_enemy_cell(next) if target_side == CombatState.Side.ENEMY else state.set_player_cell(next))
		if not ok:
			blocked = true
			break
		cell = next
		moved += 1
	return {"steps": moved, "blocked": blocked}


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
# its own Ran). A Han burst damages the target directly (ignores defense and Ran). Batch 1: a shape_clause
# `fragile_stacks` that holds for [param context] (CastContext; {} = never) adds its Rạn (Đập Vỡ compact).
static func _apply_keywords(state: CombatState, status: StatusEffects, target_side: int, skill: Dictionary, result: Dictionary,
		context: Dictionary = {}) -> void:
	# batch 2: a fragile_timing "before" card landed its Rạn before the hit (apply), never again here
	var fragile: int = 0 if str(skill.get("fragile_timing", "after")) == "before" else int(skill.get("fragile_stacks", 0))
	var clause: Dictionary = CastResolver.active_clause(skill, context) if not context.is_empty() else {}
	if clause.has("fragile_stacks"):
		fragile += int(clause["fragile_stacks"])
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


## Batch 1 (Thương Xuyên): the damage_per_cell bonus of [param skill] (its `dpc_bonus`, SkillConfig) for a cast of
## [param cells] cells: min((cells - from_cells) x per_cell, cap), never below 0; 0 for a card without one. The balance
## sim reads the same rule.
static func dpc_bonus(skill: Dictionary, cells: int) -> float:
	var b: Dictionary = skill.get("dpc_bonus", {}) as Dictionary
	if b.is_empty():
		return 0.0
	var extra: float = float(maxi(cells - int(b.get("from_cells", 0)), 0)) * float(b.get("per_cell", 0.0))
	return minf(extra, float(b.get("cap", 0.0)))


## Batch 1 (Mìn Trễ, event payload `push`): moves the unit of [param target_side] up to [param steps] cells AWAY from
## [param from] (the mask's centre): along the axis of the larger offset between the unit's cell and [param from]
## (ties: the row), and away from the divider when the unit stands on [param from]. Stops at the half's edge, at a
## cell the footprint does not fit or that [param blocked_fn] (Callable(cell) -> bool, the target mover's blockers)
## refuses. True if it moved at all.
static func push_from(state: CombatState, grid: BoardGrid, target_side: int, from: Vector2i, steps: int,
		blocked_fn: Callable = Callable()) -> bool:
	var cell: Vector2i = state.cell_of(target_side)
	var d: Vector2i = cell - from
	var dir: Vector2i
	if d == Vector2i.ZERO:
		dir = Vector2i(1, 0) if target_side == CombatState.Side.ENEMY else Vector2i(-1, 0)
	elif absi(d.x) >= absi(d.y):
		dir = Vector2i(signi(d.x), 0)
	else:
		dir = Vector2i(0, signi(d.y))
	var moved: bool = false
	for i: int in steps:
		var next: Vector2i = cell + dir
		var on_half: bool = grid.is_enemy_cell(next) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(next)
		if not on_half or (blocked_fn.is_valid() and bool(blocked_fn.call(next))):
			break
		if target_side == CombatState.Side.ENEMY and not state.enemy_fits(next, blocked_fn):
			break
		var ok: bool = state.set_enemy_cell(next) if target_side == CombatState.Side.ENEMY else state.set_player_cell(next)
		if not ok:
			break
		cell = next
		moved = true
	return moved


# Batch 3: forms a field zone (trap / ward / pillar) when the swing arrives, hit or miss.
#   trap:   the cells on the target's half become one trap cast (trap_sec; data dpc / pin_sec (clause pin) / push /
#           r3 / skill_id); the target standing on one fires it at once (result hit, damage).
#   ward:   [param cells] are already the hero's own-half cells (WardAnchor.remap): ward_sec with the card's `ward`
#           numbers (+ clause attacker_frost / push_immune). Never a hit.
#   pillar: the empty cells (no unit, not locked) become pillars for pillar_sec (clause may lengthen it); ZoneRules
#           .fit_cells keeps the target one exit. Never a hit.
static func _form_field(state: CombatState, grid: BoardGrid, status: StatusEffects, side: int, target_side: int,
		cells: Array[Vector2i], effect: String, skill: Dictionary, options: Dictionary, result: Dictionary) -> void:
	var clause: Dictionary = CastResolver.active_clause(skill, options.get("cast_context", {}) as Dictionary)
	var holds: bool = not clause.is_empty()
	var cast_id: int = status.next_field_cast_id()
	result["field_cast_id"] = cast_id
	match effect:
		"trap":
			# batch 5: the R3 numbers ride on the trap when the reaction is enabled for the card (global or listed); the
			# book's ICD gates the slam when the fling fires; pierce_defense skips the defense of the snap (Deferred 8)
			var numbers: Dictionary = reaction_numbers(options)
			var r3: Dictionary = {}
			if reaction_enabled(skill, "r3", numbers):
				r3 = (numbers["r3"] as Dictionary).duplicate()
				r3["icd_sec"] = float(numbers["icd_sec"])
			var data: Dictionary = {"dpc": float(skill.get("damage_per_cell", 0.0)),
				"pin_sec": float(clause.get("trap_pin_sec", skill.get("trap_pin_sec", 0.0))) if holds else float(skill.get("trap_pin_sec", 0.0)),
				"push_cells": int(skill.get("trap_push_cells", 0)), "skill_id": str(skill.get("id", options.get("skill_id", ""))),
				"r3": r3, "pierce_defense": bool(skill.get("pierce_defense", false))}
			var wanted: Array[Vector2i] = []
			for c: Vector2i in cells:
				var on_half: bool = grid.is_enemy_cell(c) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(c)
				if on_half:
					wanted.append(c)
			var placed: Array[Vector2i] = status.apply_field(target_side, StatusEffects.KIND_TRAP, wanted, float(skill.get("trap_sec", 0.0)), cast_id, data)
			result["zone_kind"] = "trap"
			result["zone_cells"] = placed
			if not placed.is_empty() and state.unit_in(target_side, placed) and not bool(options.get("target_untargetable", false)):
				var dmg: float = status.fire_trap(target_side, cast_id, state)
				result["hit"] = true
				result["damage"] = dmg
				result["cell"] = state.enemy_hit_cell(placed) if target_side == CombatState.Side.ENEMY else state.cell_of(target_side)
				result["pinned"] = status.is_pinned(target_side)
		"ward":
			var data: Dictionary = (skill.get("ward", {}) as Dictionary).duplicate()
			data["skill_id"] = str(skill.get("id", options.get("skill_id", "")))
			if holds:
				if clause.has("attacker_frost"):
					data["attacker_frost"] = int(clause["attacker_frost"])
				if clause.has("push_immune"):
					data["push_immune"] = bool(clause["push_immune"])
			var own: Array[Vector2i] = []
			for c: Vector2i in cells:
				var on_half: bool = grid.is_player_cell(c) if side == CombatState.Side.PLAYER else grid.is_enemy_cell(c)
				if on_half:
					own.append(c)
			var placed: Array[Vector2i] = status.apply_field(side, StatusEffects.KIND_WARD, own, float(skill.get("ward_sec", 0.0)), cast_id, data)
			result["zone_kind"] = "ward"
			result["zone_cells"] = placed
		"pillar":
			var sec: float = float(clause.get("pillar_sec", skill.get("pillar_sec", 0.0))) if holds else float(skill.get("pillar_sec", 0.0))
			var empty: Array[Vector2i] = []
			for c: Vector2i in cells:
				var on_half: bool = grid.is_enemy_cell(c) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(c)
				if on_half and not state.unit_at(target_side, c) and not state.unit_at(side, c) and not status.is_locked(c):
					empty.append(c)
			var blocked: Callable = options.get("target_blocked_fn", Callable()) as Callable
			var blocked_all: Callable = func(c: Vector2i) -> bool:
				return status.is_pillar(target_side, c) or (blocked.is_valid() and bool(blocked.call(c)))
			var kept: Array[Vector2i] = ZoneRules.fit_cells(grid, target_side, state.cell_of(target_side), empty, blocked_all)
			var placed: Array[Vector2i] = status.apply_field(target_side, StatusEffects.KIND_PILLAR, kept, sec, cast_id, {"skill_id": str(skill.get("id", options.get("skill_id", "")))})
			result["zone_kind"] = "pillar"
			result["zone_cells"] = placed


# Batch 3 (Gai Nổ branched clause): after the blast the branch-tip cells of the mask (one neighbour inside it) grow
# thorns back for regrow_sec with the match's thorn numbers.
static func _regrow_tips(status: StatusEffects, target_side: int, cells: Array[Vector2i], skill: Dictionary, options: Dictionary) -> void:
	var clause: Dictionary = CastResolver.active_clause(skill, options.get("cast_context", {}) as Dictionary)
	if not clause.has("regrow_sec"):
		return
	var tips: Array[Vector2i] = []
	for c: Vector2i in cells:
		var n: int = 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(c + d):
				n += 1
		if n <= 1:
			tips.append(c)
	var numbers: Dictionary = _zone_defaults(options)
	ZoneRules.cast_thorns(status, target_side, tips, float(clause["regrow_sec"]), float(numbers["thorn_damage"]),
		int(numbers["thorn_fragile_stacks"]))


## Batch 4 (Thiên Quang keyword_hits_max): applies only the keywords of [param skill] (Rạn / Hàn, a Hàn burst damages)
## to [param target_side], as a drop that finds the unit after the cast's damage hits are spent. Returns the result
## fields {fragile_applied, frost_applied, frost_burst}.
static func apply_keywords_only(state: CombatState, status: StatusEffects, target_side: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"fragile_applied": 0, "frost_applied": 0, "frost_burst": 0.0}
	if status != null:
		_apply_keywords(state, status, target_side, skill, result, context)
	return result


## Batch 3: the push away from the divider as a public step (StatusEffects.fire_trap); returns the cells moved. Batch 5:
## [param blocked_fn] (Callable(cell) -> bool) stops the fling at a pillar / hole like a card's push.
static func push_away(state: CombatState, grid: BoardGrid, target_side: int, steps: int, blocked_fn: Callable = Callable()) -> int:
	return _push(state, grid, target_side, steps, blocked_fn)


# Moves the unit up to [param steps] cells away from the divider; stops at a missing cell, the board edge or a cell
# [param blocked_fn] (Callable(cell) -> bool) refuses (batch 3: pillars, holes). Returns the number of cells moved
# (batch 2: a short move is an R3 slam for cards that list it).
static func _push(state: CombatState, grid: BoardGrid, target_side: int, steps: int, blocked_fn: Callable = Callable()) -> int:
	var dir: int = 1 if target_side == CombatState.Side.ENEMY else -1
	var cell: Vector2i = state.cell_of(target_side)
	var moved: int = 0
	for i: int in steps:
		var next: Vector2i = Vector2i(cell.x + dir, cell.y)
		var on_half: bool = grid.is_enemy_cell(next) if target_side == CombatState.Side.ENEMY else grid.is_player_cell(next)
		if not on_half or (blocked_fn.is_valid() and bool(blocked_fn.call(next))):
			break
		if target_side == CombatState.Side.ENEMY and not state.enemy_fits(next, blocked_fn):
			break
		var ok: bool = state.set_enemy_cell(next) if target_side == CombatState.Side.ENEMY else state.set_player_cell(next)
		if not ok:
			break
		cell = next
		moved += 1
	return moved
