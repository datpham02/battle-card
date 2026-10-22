class_name CutEffects
extends RefCounted
## Applies a resolved cut to the combat state. Stateless. Implements: Story 008 (both
## directions so Story 009's boss can reuse it).


static var _warned_no_status: bool = false


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
static func apply(
	state: CombatState,
	grid: BoardGrid,
	side: int,
	cells: Array[Vector2i],
	skill_id: String,
	cut_config: CutConfig,
	skill_config: SkillConfig,
	status: StatusEffects = null,
	damage_modifier: Callable = Callable()
) -> Dictionary:
	var target_side: int = CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER
	var target_cell: Vector2i = state.cell_of(target_side)
	var result: Dictionary = {
		"hit": false, "damage": 0.0, "pushed": false, "cell": target_cell,
		"burning": false, "pinned": false,
	}
	var skill: Dictionary = skill_config.get_skill(skill_id)
	if skill.is_empty() or not bool(skill["implemented"]):
		push_warning("CutEffects: skill '%s' is not implemented, using slash" % skill_id)
		skill_id = SkillConfig.FALLBACK_SKILL
		skill = skill_config.get_skill(skill_id)
	var effect: String = str(skill.get("effect", "damage"))
	var inside: bool = cells.has(target_cell)
	if effect == "burn" or effect == "pin":
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
		elif inside:
			status.pin(target_side, float(skill.get("pin_duration_sec", 0.0)))
			result["pinned"] = true
			result["hit"] = true
		return result
	if not inside:
		return result
	var multiplier: float = float(skill.get("damage_multiplier", 1.0))
	var push_cells: int = int(skill.get("push_cells", 0))
	var damage: float = cut_config.slash_damage(cells.size()) * multiplier
	if damage_modifier.is_valid():
		damage = float(damage_modifier.call(cells.size(), damage))
	result["hit"] = true
	result["damage"] = damage
	state.damage(target_side, damage)
	if push_cells > 0:
		result["pushed"] = _push(state, grid, target_side, push_cells)
	return result


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
