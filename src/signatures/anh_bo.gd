class_name AnhBoSignature
extends TimedSignature
## Sat thu - Anh Bo: for duration_sec the player's steps have no cooldown and EVERY player hit from a
## card with small_cells or fewer cut cells is multiplied by small_mult (applied last: stacks with
## Ghim and Quick Blade). Story 030: the boss no longer has to be pinned.
## Params: duration_sec, small_mult, small_cells. The legacy key `pinned_small_mult` (Story 021) is
## still read when `small_mult` is absent (one push_warning per instance), used as `small_mult`.
## Implements: Story 021, Story 030.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_SMALL_MULT: float = 1.0
const DEFAULT_SMALL_CELLS: int = 3
const KEY_SMALL_MULT: String = "small_mult"
const KEY_LEGACY_SMALL_MULT: String = "pinned_small_mult"

var _legacy_warned: bool = false


func get_id() -> String:
	return "anh_bo"


func modify_damage(_card_id: String, cells: int, damage: float, _target_pinned: bool) -> float:
	if is_active() and cells <= param_int("small_cells", DEFAULT_SMALL_CELLS):
		return damage * maxf(small_mult(), 0.0)
	return damage


func step_cooldown_scale() -> float:
	return 0.0 if is_active() else 1.0


## Multiplier of a small hit: `small_mult`, else the legacy `pinned_small_mult` (warns once), else the fallback.
func small_mult() -> float:
	if _params.has(KEY_SMALL_MULT):
		return param_float(KEY_SMALL_MULT, DEFAULT_SMALL_MULT)
	if _params.has(KEY_LEGACY_SMALL_MULT):
		if not _legacy_warned:
			_legacy_warned = true
			push_warning("AnhBoSignature: param 'pinned_small_mult' is deprecated, rename it to 'small_mult'")
		return param_float(KEY_LEGACY_SMALL_MULT, DEFAULT_SMALL_MULT)
	return DEFAULT_SMALL_MULT
