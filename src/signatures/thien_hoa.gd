class_name ThienHoaSignature
extends BaseSignature
## Phap su - Thien Hoa (instant). Order on activate (Story 030, reordered 2026-10-25):
## 1) DETONATE the burn that ALREADY exists: the boss takes detonate_mult x the total REMAINING burn
##    damage (StatusEffects.remaining_burn_damage summed over every burning enemy-half cell, even those
##    the boss does not stand on); that enemy-half burn is cleared. The player-half burn is untouched.
## 2) the cooldown of every card whose effect is `burn` is reset;
## 3) IGNITE every lit, real enemy-half cell of the formation map (ctx `formation`.lit_cells(), read
##    BEFORE CombatView resets the map) `burn_stacks` times for `burn_duration_sec`: a lasting sea of
##    fire that ticks `burn_damage_per_tick` every `burn_tick_sec` while the boss stands in it (the boss
##    brain avoids burning cells through `burn_avoid`). This fresh fire is NOT detonated in the same use.
## No formation or no lit cell: step 3 is skipped (the old behaviour). Nothing burning: no damage.
## Params: burn_stacks, burn_duration_sec, burn_tick_sec, burn_damage_per_tick, detonate_mult.
## Context key added to the base ones: `formation` FormationMap (optional).
## Implements: Story 021, Story 030.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_DETONATE_MULT: float = 1.0
const DEFAULT_BURN_STACKS: int = 1
const DEFAULT_BURN_DURATION_SEC: float = 2.0
const DEFAULT_BURN_TICK_SEC: float = 0.5
const DEFAULT_BURN_DAMAGE_PER_TICK: float = 1.5

var _last_damage: float = 0.0
var _last_ignited: int = 0


func get_id() -> String:
	return "thien_hoa"


func activate() -> void:
	_last_damage = 0.0
	_last_ignited = 0
	var status: StatusEffects = _ctx.get("status") as StatusEffects
	var grid: BoardGrid = _ctx.get("grid") as BoardGrid
	var state: CombatState = _ctx.get("state") as CombatState
	if status != null and grid != null:
		_detonate_existing_burn(status, grid, state)
	_reset_burn_cooldowns()
	if status != null and grid != null:
		_ignite_lit_cells(status, grid)


## Detonation damage dealt by the last [method activate] (only the burn that existed before it;
## 0 before / without burn).
func last_damage() -> float:
	return _last_damage


## How many cells the last [method activate] set on fire (0 without a formation / lit cells).
func last_ignited_count() -> int:
	return _last_ignited


## Step 1: detonates and clears the burn already on the enemy half. Null-safe on [param state].
func _detonate_existing_burn(status: StatusEffects, grid: BoardGrid, state: CombatState) -> void:
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


## Step 3: ignites every lit, real enemy-half formation cell `burn_stacks` times (the lasting fire).
func _ignite_lit_cells(status: StatusEffects, grid: BoardGrid) -> void:
	var formation: FormationMap = _ctx.get("formation") as FormationMap
	if formation == null:
		return
	var cells: Array[Vector2i] = []
	for cell: Vector2i in formation.lit_cells():
		if grid.is_enemy_cell(cell):
			cells.append(cell)
	if cells.is_empty():
		return
	var duration: float = param_float("burn_duration_sec", DEFAULT_BURN_DURATION_SEC)
	var tick: float = param_float("burn_tick_sec", DEFAULT_BURN_TICK_SEC)
	var damage: float = param_float("burn_damage_per_tick", DEFAULT_BURN_DAMAGE_PER_TICK)
	var stacks: int = maxi(param_int("burn_stacks", DEFAULT_BURN_STACKS), 0)
	for _i: int in stacks:
		status.ignite(cells, duration, tick, damage)
	_last_ignited = cells.size() if (stacks > 0 and duration > 0.0) else 0


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
	_last_ignited = 0
	super.teardown()
