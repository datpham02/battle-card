class_name SecondWindPassive
extends BasePassive
## Kiem si: heals extra HP after every won match. Params: heal_after_match (HP).
## Implements: Story 018.

## Fallback only; the real number is in characters.json.
const DEFAULT_HEAL: float = 0.0


func get_id() -> String:
	return "second_wind"


func on_match_won() -> float:
	return maxf(param_float("heal_after_match", DEFAULT_HEAL), 0.0)
