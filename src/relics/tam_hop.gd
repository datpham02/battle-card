class_name TamHop
extends BaseRelic
## Tam Hop (Story 032): up to `max_join_pieces` pieces may be joined into one cast (default 2).
## params `{max_join_pieces}`. ctx keys: none. Emits `triggered` from [method on_join] when a
## join used more than two pieces. Implements: Story 032.

const BASE_JOIN: int = BaseRelic.BASE_JOIN_PIECES


func _init() -> void:
	_relic_id = "tam_hop"


func max_join_pieces() -> int:
	return maxi(param_int("max_join_pieces", BASE_JOIN), BASE_JOIN)


func on_join(cast_info: Dictionary) -> void:
	var pieces: Array = cast_info.get("pieces", [])
	if pieces.size() > BASE_JOIN:
		triggered.emit(get_id())
