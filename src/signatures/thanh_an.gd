class_name ThanhAnSignature
extends TimedSignature
## Giao si - Thanh An (Story 037): for duration_sec every player hit that lands on the boss adds
## `extra_frost_stacks` Han stack(s) (a burst they trigger damages the boss at once), and every Han burst on
## the boss deals `burst_mult` times its damage (read through [method frost_burst_mult]).
## Params: duration_sec, extra_frost_stacks, burst_mult. Implements: Story 037.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_EXTRA_FROST_STACKS: int = 0
const DEFAULT_BURST_MULT: float = 1.0


func get_id() -> String:
	return "thanh_an"


func on_hit(_card_id: String, _damage: float) -> void:
	if not is_active():
		return
	var extra: int = maxi(param_int("extra_frost_stacks", DEFAULT_EXTRA_FROST_STACKS), 0)
	var status: StatusEffects = _ctx.get("status") as StatusEffects
	var state: CombatState = _ctx.get("state") as CombatState
	if extra <= 0 or status == null:
		return
	var burst: float = status.apply_frost(CombatState.Side.ENEMY, extra)
	if burst > 0.0 and state != null:
		state.damage(CombatState.Side.ENEMY, burst)


func frost_burst_mult() -> float:
	if not is_active():
		return 1.0
	return maxf(param_float("burst_mult", DEFAULT_BURST_MULT), 0.0)
