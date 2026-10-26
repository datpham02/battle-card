class_name PrayerPassive
extends BasePassive
## Giao si - Loi nguyen (Story 037): every Han burst on the boss heals the player `heal_per_burst` HP (through
## the ctx `heal_player` Callable, which clamps to max HP). Params: heal_per_burst (float).
## Implements: Story 037.

## Fallback only; the real number is in characters.json.
const DEFAULT_HEAL_PER_BURST: float = 0.0

var _bursts: int = 0


func get_id() -> String:
	return "prayer"


func on_frost_burst(_damage: float) -> void:
	_bursts += 1
	var heal: float = maxf(param_float("heal_per_burst", DEFAULT_HEAL_PER_BURST), 0.0)
	var heal_fn: Variant = _ctx.get("heal_player")
	if heal > 0.0 and typeof(heal_fn) == TYPE_CALLABLE and (heal_fn as Callable).is_valid():
		(heal_fn as Callable).call(heal)


## Han bursts seen this match (tests / HUD).
func bursts_seen() -> int:
	return _bursts
