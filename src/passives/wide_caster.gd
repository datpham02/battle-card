class_name WideCasterPassive
extends BasePassive
## Phap su: swings over min_cells or more cells wind up faster. Params: min_cells (int),
## duration_mult (windup multiplier, 0.85 = 15 % faster). Implements: Story 018.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_MIN_CELLS: int = 5
const DEFAULT_DURATION_MULT: float = 1.0


func get_id() -> String:
	return "wide_caster"


func modify_swing_duration(cells: int, duration: float) -> float:
	if cells >= param_int("min_cells", DEFAULT_MIN_CELLS):
		return duration * maxf(param_float("duration_mult", DEFAULT_DURATION_MULT), 0.0)
	return duration
