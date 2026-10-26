extends SceneTree
## Story 032 Part B: each conditional relic's hook in isolation with a fake ctx (an_don, chi_khau,
## khoi_the, phan_don, huyet_an, an_chu, tam_hop). Prints PASS/FAIL lines and FAILS=n.

var _fails: int = 0
var _healed: Array[float] = []
var _hurt: Array[float] = []
var _given: Array[String] = []
var _bag_full: bool = false
var _flashes: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _cast(pieces: Array, joined: bool = false, cells: int = -1) -> Dictionary:
	return {
		"pieces": pieces,
		"cells": cells if cells >= 0 else pieces.size(),
		"joined": joined,
		"featured": false,
		"card_id": "kiem_khi",
		"hit": true,
	}


# A cast_info like [method _cast] whose swing missed the boss (`hit` false).
func _missed(pieces: Array, cells: int, joined: bool = false) -> Dictionary:
	var info: Dictionary = _cast(pieces, joined, cells)
	info["hit"] = false
	return info


func _heal(amount: float) -> void:
	_healed.append(amount)


func _hurt_player(amount: float) -> void:
	_hurt.append(amount)


func _give(shape: String) -> bool:
	if _bag_full:
		return false
	_given.append(shape)
	return true


func _on_triggered(relic_id: String) -> void:
	_flashes.append(relic_id)


func _make(id: String, ctx: Dictionary = {}) -> BaseRelic:
	var relic: BaseRelic = RelicRegistry.instantiate(id)
	relic.setup(ctx, relic.get_params())
	relic.triggered.connect(_on_triggered)
	relic.on_match_start()
	return relic


func _initialize() -> void:
	_an_don()
	_chi_khau()
	_khoi_the()
	_phan_don()
	_huyet_an()
	_an_chu()
	_tam_hop()
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _an_don() -> void:
	_flashes.clear()
	var r: BaseRelic = _make("an_don")
	_check(_near(r.modify_cast_damage(_cast(["mono"]), 10.0), 20.0), "an_don: lone mono x2")
	_check(_flashes == ["an_don"], "an_don emits triggered with its id")
	_check(_near(r.modify_cast_damage(_cast(["bar2"], false, 2), 10.0), 10.0), "an_don: lone bar2 unchanged")
	_check(_near(r.modify_cast_damage(_cast(["mono", "mono"], true), 10.0), 10.0), "an_don: two monos joined unchanged")
	_check(_near(r.modify_cast_damage(_cast([]), 10.0), 10.0), "an_don: no pieces unchanged")
	_check(_flashes.size() == 1, "an_don: no flash when it did not act")


func _chi_khau() -> void:
	_healed.clear()
	_flashes.clear()
	var r: BaseRelic = _make("chi_khau", {"heal_player": _heal})
	r.on_cast_landed(_cast(["mono"]))
	_check(_healed.is_empty(), "chi_khau: a lone cast heals nothing")
	r.on_cast_landed(_cast(["mono", "bar2"], true, 3))
	_check(_healed == [3.0] and _flashes == ["chi_khau"], "chi_khau: a joined cast heals 3 and flashes")
	for i: int in 10:
		r.on_cast_landed(_cast(["mono", "bar2"], true, 3))
	var total: float = 0.0
	for h: float in _healed:
		total += h
	_check(_near(total, 15.0) and _healed.size() == 5, "chi_khau: stops at max_heal_per_match 15 (5 heals): total %f x%d" % [total, _healed.size()])
	r.on_match_start()
	r.on_cast_landed(_cast(["mono", "bar2"], true, 3))
	_check(_healed.size() == 6, "chi_khau: the cap resets at the next match start")
	var bare: BaseRelic = _make("chi_khau")
	bare.on_cast_landed(_cast(["mono", "bar2"], true, 3))
	_check(_healed.size() == 6, "chi_khau: missing heal_player key does nothing (no crash)")
	# A cap that is not a multiple of the heal trims the last heal.
	var trimmed := ChiKhau.new()
	trimmed.setup({"heal_player": _heal}, {"heal": 4, "max_heal_per_match": 6})
	_healed.clear()
	trimmed.on_cast_landed(_cast(["a", "b"], true))
	trimmed.on_cast_landed(_cast(["a", "b"], true))
	trimmed.on_cast_landed(_cast(["a", "b"], true))
	_check(_healed == [4.0, 2.0], "chi_khau: the last heal is trimmed to the cap: %s" % str(_healed))


func _khoi_the() -> void:
	_flashes.clear()
	var r: BaseRelic = _make("khoi_the")
	_check(_near(r.modify_cast_time(_cast(["mono"]), 1.4), 0.0), "khoi_the: first cast has no windup")
	_check(_near(r.modify_cast_time(_cast(["mono"]), 1.4), 1.4), "khoi_the: the second cast is unchanged")
	_check(_flashes == ["khoi_the"], "khoi_the: flashes once")
	r.on_match_start()
	_check(_near(r.modify_cast_time(_cast(["mono"]), 1.4), 0.0), "khoi_the: applies again in the next match")


func _phan_don() -> void:
	_given.clear()
	_flashes.clear()
	_bag_full = false
	var r: BaseRelic = _make("phan_don", {"give_piece": _give})
	r.on_interrupt_by_player()
	_check(_given == ["mono"] and _flashes == ["phan_don"], "phan_don: interrupt gives a mono and flashes")
	_bag_full = true
	r.on_interrupt_by_player()
	_check(_given.size() == 1 and _flashes.size() == 1, "phan_don: full bag gives nothing and does not flash")
	var bare: BaseRelic = _make("phan_don")
	bare.on_interrupt_by_player()
	_check(_flashes.size() == 1, "phan_don: missing give_piece key does nothing")


func _huyet_an() -> void:
	_hurt.clear()
	_flashes.clear()
	var r: BaseRelic = _make("huyet_an", {"damage_player": _hurt_player})
	_check(_near(r.modify_cast_damage(_cast(["bar5"], false, 5), 10.0), 13.0), "huyet_an: 5 cells x1.3")
	_check(_near(r.modify_cast_damage(_cast(["bar4"], false, 4), 10.0), 10.0), "huyet_an: 4 cells unchanged")
	_check(_near(r.modify_cast_damage(_cast(["bar5", "mono"], true, 6), 10.0), 13.0), "huyet_an: 6 cells x1.3")
	r.on_cast_landed(_cast(["bar5"], false, 5))
	_check(_hurt.is_empty(), "huyet_an: a 5-cell hit costs no HP: %s" % str(_hurt))
	r.on_cast_landed(_missed(["bar4"], 4))
	_check(_hurt.is_empty(), "huyet_an: a 4-cell miss costs no HP: %s" % str(_hurt))
	r.on_cast_landed(_missed(["bar5"], 5))
	r.on_cast_landed(_missed(["bar5", "mono"], 6, true))
	_check(_hurt == [2.0, 2.0], "huyet_an: each 5+-cell miss costs self_damage 2: %s" % str(_hurt))
	var bare: BaseRelic = _make("huyet_an")
	bare.on_cast_landed(_missed(["bar5"], 5))
	_check(_hurt.size() == 2, "huyet_an: missing damage_player key does nothing")


func _an_chu() -> void:
	var r: BaseRelic = _make("an_chu")
	_check(_near(r.featured_mult_override(), 2.0), "an_chu: featured override 2.0")
	_flashes.clear()
	(r as AnChu).flash()
	_check(_flashes == ["an_chu"], "an_chu: flash emits triggered")
	var bare := AnChu.new()
	_check(bare.featured_mult_override() == 0.0, "an_chu: no param -> no override")


func _tam_hop() -> void:
	var r: BaseRelic = _make("tam_hop")
	_check(r.max_join_pieces() == 3, "tam_hop: max_join_pieces 3")
	_flashes.clear()
	r.on_join(_cast(["a", "b"], true))
	_check(_flashes.is_empty(), "tam_hop: a two-piece join does not flash")
	r.on_join(_cast(["a", "b", "c"], true))
	_check(_flashes == ["tam_hop"], "tam_hop: a three-piece join flashes")
	var bare := TamHop.new()
	_check(bare.max_join_pieces() == 2, "tam_hop: no param -> 2")
