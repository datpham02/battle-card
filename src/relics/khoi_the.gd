class_name KhoiThe
extends BaseRelic
## Khoi The (Story 032): the first `first_casts` player casts of a match have no windup.
## params `{first_casts}`. ctx keys: none. [method modify_cast_time] must be called exactly once
## per cast. Emits `triggered` when it zeroes a windup. Implements: Story 032.

var _remaining: int = 0


func _init() -> void:
	_relic_id = "khoi_the"


func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_remaining = maxi(param_int("first_casts", 0), 0)


func on_match_start() -> void:
	_remaining = maxi(param_int("first_casts", 0), 0)


## 0 for the first cast(s) of the match, unchanged afterwards.
func modify_cast_time(_cast_info: Dictionary, sec: float) -> float:
	if _remaining <= 0:
		return sec
	_remaining -= 1
	triggered.emit(get_id())
	return 0.0
