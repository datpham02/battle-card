class_name VayBatSignature
extends TimedSignature
## Tho san - Vay Bat (Story 037, reworked by design/quick-specs/o-rot-thay-tuong-2026-10-31.md): for
## duration_sec the thorns the player forms last `zone_sec_mult` times longer, each thorn card lays
## `extra_thorn_cells` extra thorn cell(s) (CutEffects.extra_thorn_cells), and each consumed Ran stack on the
## boss multiplies the hit by `fragile_mult` instead of the config's. No Wall part any more. All three are read
## through the base hooks [method zone_sec_mult], [method extra_thorn_cells] and
## [method fragile_mult_override], so they exist only while the timer runs.
## Params: duration_sec, zone_sec_mult, extra_thorn_cells, fragile_mult. Implements: Story 037 + quick spec.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_ZONE_SEC_MULT: float = 1.0
const DEFAULT_FRAGILE_MULT: float = 0.0
const DEFAULT_EXTRA_THORN_CELLS: int = 0


func get_id() -> String:
	return "vay_bat"


func zone_sec_mult() -> float:
	if not is_active():
		return 1.0
	return maxf(param_float("zone_sec_mult", DEFAULT_ZONE_SEC_MULT), 0.0)


func extra_thorn_cells() -> int:
	if not is_active():
		return 0
	return maxi(param_int("extra_thorn_cells", DEFAULT_EXTRA_THORN_CELLS), 0)


func fragile_mult_override() -> float:
	if not is_active():
		return 0.0
	return maxf(param_float("fragile_mult", DEFAULT_FRAGILE_MULT), 0.0)
