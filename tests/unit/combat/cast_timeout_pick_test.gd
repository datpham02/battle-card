extends SceneTree
## 2026-11-04 (quick spec niem-dung-tran, user: "hết 4s thì sẽ đặt khối với hiện trạng lúc đó và cast random lá bài
## thỏa điều kiện"): when the cast clock runs out, CutFlow casts a RANDOM card of the hand that is available for the
## cut (cell minimum, cooldown, not a curse); only with none available the basic default card. A menu opened with no
## time left resolves on tick_real(0). The pick is deterministic with a seeded rng.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_timeout_pick_test.gd

const CUT: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)]
const CURSE: String = "oan_hon"

var fails: int = 0
var _chosen: Array[String] = []


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: SkillConfig = SkillConfig.load_from_file()
	var big: String = _card_with_min_cells_above(cfg, CUT.size())
	var curse: String = CURSE
	_check("fixture: a card needing more cells than the cut and a curse exist", not big.is_empty() and cfg.is_curse(curse), "%s %s" % [big, curse])
	test_random_pick_is_an_available_hand_card(cfg, big, curse)
	test_pick_varies_and_is_seeded(cfg)
	test_no_available_card_casts_the_default(cfg, big, curse)
	test_menu_opened_with_no_time_resolves_at_once(cfg)
	test_config_stops_the_match(cfg)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _flow(cfg: SkillConfig, seed: int) -> CutFlow:
	var flow := CutFlow.new(cfg, SkillCooldowns.new())
	flow.rng.seed = seed
	_chosen.clear()
	flow.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: _chosen.append(id))
	return flow


func test_random_pick_is_an_available_hand_card(cfg: SkillConfig, big: String, curse: String) -> void:
	var ok: bool = true
	for seed: int in 40:
		var flow: CutFlow = _flow(cfg, seed)
		flow.open_menu(["a"] as Array[String], CUT, [big, "kiem_khi", curse, "kiem_khi"] as Array[String], 1.0)
		flow.tick_real(1.5)
		ok = ok and _chosen == (["kiem_khi"] as Array[String]) and not flow.is_menu_open()
	_check("test_timeout_never_casts_a_curse_or_a_card_under_its_cell_minimum", ok)


func test_pick_varies_and_is_seeded(cfg: SkillConfig) -> void:
	var hand: Array[String] = ["kiem_khi", "hoa_tinh", "kiem_khi", "hoa_tinh"]
	_check("fixture: hoa_tinh is available on the 3-cell cut", bool(SkillAvailability.check(cfg, SkillCooldowns.new(), "hoa_tinh", CUT.size())["available"]))
	var seen: Dictionary = {}
	for seed: int in 40:
		var flow: CutFlow = _flow(cfg, seed)
		flow.open_menu(["a"] as Array[String], CUT, hand, 0.5)
		flow.tick_real(1.0)
		seen[_chosen[0] if not _chosen.is_empty() else ""] = true
	_check("test_timeout_pick_is_random_among_available_cards", seen.has("kiem_khi") and seen.has("hoa_tinh") and seen.size() == 2, str(seen.keys()))
	var a: CutFlow = _flow(cfg, 99)
	a.open_menu(["a"] as Array[String], CUT, hand, 0.0)
	var pick_a: String = a.timeout_choice()
	var b: CutFlow = _flow(cfg, 99)
	b.open_menu(["a"] as Array[String], CUT, hand, 0.0)
	_check("test_same_seed_same_pick", pick_a == b.timeout_choice() and not pick_a.is_empty(), pick_a)


func test_no_available_card_casts_the_default(cfg: SkillConfig, big: String, curse: String) -> void:
	var flow: CutFlow = _flow(cfg, 1)
	flow.open_menu(["a"] as Array[String], CUT, [big, curse, big, curse] as Array[String], 0.5)
	_check("test_no_available_card_gives_no_timeout_choice", flow.timeout_choice().is_empty())
	flow.tick_real(1.0)
	_check("test_no_available_card_casts_the_default_card", _chosen == ([cfg.default_card] as Array[String]), str(_chosen))


func test_menu_opened_with_no_time_resolves_at_once(cfg: SkillConfig) -> void:
	var flow: CutFlow = _flow(cfg, 3)
	flow.open_menu(["a"] as Array[String], CUT, ["kiem_khi"] as Array[String], 0.0)
	_check("test_menu_opened_with_zero_time_is_open", flow.is_menu_open() and flow.get_time_left() == 0.0)
	flow.tick_real(0.0)
	_check("test_tick_zero_resolves_it", not flow.is_menu_open() and _chosen == (["kiem_khi"] as Array[String]), str(_chosen))
	var full: CutFlow = _flow(cfg, 3)
	full.open_menu(["a"] as Array[String], CUT, ["kiem_khi"] as Array[String])
	_check("test_negative_time_left_uses_the_full_duration", absf(full.get_time_left() - full.get_duration()) < 0.0001)


func test_config_stops_the_match(cfg: SkillConfig) -> void:
	_check("test_cast_runs_the_match_stopped", cfg.menu_time_scale == 0.0)
	_check("test_focus_has_no_cooldown", cfg.focus_cooldown_sec == 0.0)
	_check("test_one_cast_clock_of_4_s", is_equal_approx(CutConfig.load_from_file().place_window_sec, 4.0))


func _card_with_min_cells_above(cfg: SkillConfig, n: int) -> String:
	for id: String in cfg.card_order:
		if not cfg.is_curse(id) and int(cfg.get_skill(id).get("min_cells", 1)) > n and bool(cfg.get_skill(id).get("implemented", false)):
			return id
	return ""

