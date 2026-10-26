class_name VayBatSignature
extends TimedSignature
## Tho san - Vay Bat (Story 037): for duration_sec every zone (seal / thorns) the player forms lasts
## `zone_sec_mult` times longer and each consumed Ran stack on the boss multiplies the hit by `fragile_mult`
## instead of the config's. Both effects are read through the base hooks [method zone_sec_mult] and
## [method fragile_mult_override], so they exist only while the timer runs.
## Params: duration_sec, zone_sec_mult, fragile_mult. Implements: Story 037.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_ZONE_SEC_MULT: float = 1.0
const DEFAULT_FRAGILE_MULT: float = 0.0


func get_id() -> String:
	return "vay_bat"


func zone_sec_mult() -> float:
	if not is_active():
		return 1.0
	return maxf(param_float("zone_sec_mult", DEFAULT_ZONE_SEC_MULT), 0.0)


func fragile_mult_override() -> float:
	if not is_active():
		return 0.0
	return maxf(param_float("fragile_mult", DEFAULT_FRAGILE_MULT), 0.0)
