class_name AnhBoSignature
extends TimedSignature
## Sat thu - Anh Bo: for duration_sec the player's steps have no cooldown and a hit from a card with
## small_cells or fewer cut cells against a PINNED boss is multiplied by pinned_small_mult (applied
## last: stacks with Ghim and Quick Blade). Params: duration_sec, pinned_small_mult, small_cells.
## Implements: Story 021.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_SMALL_MULT: float = 1.0
const DEFAULT_SMALL_CELLS: int = 3


func get_id() -> String:
	return "anh_bo"


func modify_damage(_card_id: String, cells: int, damage: float, target_pinned: bool) -> float:
	if is_active() and target_pinned and cells <= param_int("small_cells", DEFAULT_SMALL_CELLS):
		return damage * maxf(param_float("pinned_small_mult", DEFAULT_SMALL_MULT), 0.0)
	return damage


func step_cooldown_scale() -> float:
	return 0.0 if is_active() else 1.0
