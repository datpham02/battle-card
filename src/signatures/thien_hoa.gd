class_name ThienHoaSignature
extends BaseSignature
## Phap su - Thien Hoa (instant): detonates every burning cell of the enemy half. The boss takes
## detonate_mult x the total REMAINING burn damage (StatusEffects.remaining_burn_damage summed over
## all burning enemy-half cells, even those the boss does not stand on), the enemy-half burn is
## cleared and the cooldown of every card whose effect is `burn` is reset. Nothing burning: only
## the cooldown reset. Params: detonate_mult. Implements: Story 021.

## Fallback only; the real number is in characters.json.
const DEFAULT_DETONATE_MULT: float = 1.0

var _last_damage: float = 0.0


func get_id() -> String:
	return "thien_hoa"


func activate() -> void:
	_last_damage = 0.0
	var status: StatusEffects = _ctx.get("status") as StatusEffects
	var grid: BoardGrid = _ctx.get("grid") as BoardGrid
	var state: CombatState = _ctx.get("state") as CombatState
	if status != null and grid != null:
		var cells: Array[Vector2i] = []
		var total: float = 0.0
		for cell: Vector2i in status.burning_cells():
			if grid.is_enemy_cell(cell):
				cells.append(cell)
				total += status.remaining_burn_damage(cell)
		if not cells.is_empty():
			status.clear_burn(cells)
		_last_damage = total * maxf(param_float("detonate_mult", DEFAULT_DETONATE_MULT), 0.0)
		if state != null and _last_damage > 0.0:
			state.damage_enemy(_last_damage)
	_reset_burn_cooldowns()


## Damage dealt by the last [method activate] (0 before / without burn).
func last_damage() -> float:
	return _last_damage


func _reset_burn_cooldowns() -> void:
	var cooldowns: SkillCooldowns = _ctx.get("cooldowns") as SkillCooldowns
	var skills: SkillConfig = _ctx.get("skill_config") as SkillConfig
	if cooldowns == null or skills == null:
		return
	for id: String in skills.cards.keys():
		if str(skills.get_skill(id).get("effect", "")) == "burn":
			cooldowns.clear(id)


func teardown() -> void:
	_last_damage = 0.0
	super.teardown()
