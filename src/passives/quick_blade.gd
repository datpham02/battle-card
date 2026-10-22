class_name QuickBladePassive
extends BasePassive
## Sat thu: hits over max_cells or fewer cells deal more damage. Params: max_cells (int),
## damage_mult (1.25 = +25 %). Implements: Story 018.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_MAX_CELLS: int = 3
const DEFAULT_DAMAGE_MULT: float = 1.0


func get_id() -> String:
	return "quick_blade"


func modify_damage(cells: int, damage: float) -> float:
	if cells <= param_int("max_cells", DEFAULT_MAX_CELLS):
		return damage * maxf(param_float("damage_mult", DEFAULT_DAMAGE_MULT), 0.0)
	return damage
