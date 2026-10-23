class_name TramSignature
extends TimedSignature
## Kiem si - Tram: for duration_sec every player cut counts cell_mult times its cells for damage
## (the swing still covers the real cells) and the player heals `lifesteal` x the damage dealt.
## Params: duration_sec, cell_mult, lifesteal (0.2 = 20 %). Implements: Story 021.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_CELL_MULT: float = 1.0
const DEFAULT_LIFESTEAL: float = 0.0


func get_id() -> String:
	return "tram"


func modify_cells(cells: int) -> int:
	if not is_active():
		return cells
	return int(roundf(float(cells) * maxf(param_float("cell_mult", DEFAULT_CELL_MULT), 0.0)))


func on_hit(_card_id: String, damage: float) -> void:
	if not is_active() or damage <= 0.0:
		return
	var state: CombatState = _ctx.get("state") as CombatState
	if state == null or state.is_player_dead():
		return
	var heal: float = damage * maxf(param_float("lifesteal", DEFAULT_LIFESTEAL), 0.0)
	state.set_player_hp(state.player_hp + heal)
