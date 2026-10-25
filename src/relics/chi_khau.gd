class_name ChiKhau
extends BaseRelic
## Chi Khau (Story 032): every cast that joined pieces heals `heal` HP, at most
## `max_heal_per_match` HP per match. params `{heal, max_heal_per_match}`.
## ctx keys: `heal_player` Callable(amount: float) -> Variant (heals the player through
## CombatState, clamped to max HP; the return value is ignored). Missing key: no heal.
## Emits `triggered` on each heal. Implements: Story 032.

var _heal: float = 0.0
var _max_heal: float = 0.0
var _healed: float = 0.0


func _init() -> void:
	_relic_id = "chi_khau"


func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_heal = param_float("heal", 0.0)
	_max_heal = param_float("max_heal_per_match", 0.0)
	_healed = 0.0


func on_match_start() -> void:
	_healed = 0.0


## Heals when the cast joined pieces (the last heal is trimmed to the per-match cap).
func on_cast_landed(cast_info: Dictionary) -> void:
	if not bool(cast_info.get("joined", false)):
		return
	var amount: float = minf(_heal, _max_heal - _healed)
	if amount <= 0.0 or not _ctx.has("heal_player"):
		return
	_healed += amount
	_call_ctx("heal_player", [amount])
	triggered.emit(get_id())


## HP healed so far this match (for tests / HUD).
func healed_total() -> float:
	return _healed
