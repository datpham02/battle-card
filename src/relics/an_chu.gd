class_name AnChu
extends BaseRelic
## An Chu (Story 032): the featured-shape bonus is `featured_mult` instead of the config value.
## params `{featured_mult}`. ctx keys: none (the combat wave reads [method featured_mult_override]
## where CutEffects applies the featured bonus and calls [method flash] when a featured cast used
## the override). Implements: Story 032.


func _init() -> void:
	_relic_id = "an_chu"


## The imposed featured multiplier (0.0 = none when the param is absent).
func featured_mult_override() -> float:
	return maxf(param_float("featured_mult", 0.0), 0.0)


## Emits `triggered` for the HUD flash.
func flash() -> void:
	triggered.emit(get_id())
