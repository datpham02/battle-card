extends SceneTree
## Story 046 Part B: combat.json `hud.hp_trail_sec` read through CombatConfig (shipped value, explicit value,
## omitted block, invalid values keep the default).

var fails: int = 0

const SHIPPED_TRAIL_SEC: float = 0.4


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	test_shipped_combat_json_has_trail_of_0_4()
	test_explicit_value_is_read()
	test_omitted_block_keeps_default()
	test_negative_value_keeps_default()
	test_non_number_keeps_default()
	test_zero_is_allowed()
	test_corner_panels_flag()
	test_hp_plate_rect()
	test_step_rings_flag()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_shipped_combat_json_has_trail_of_0_4() -> void:
	var config: CombatConfig = CombatConfig.load_from_file()
	_check("combat.json loads", config != null)
	if config != null:
		_check("shipped hp_trail_sec = 0.4", is_equal_approx(config.hud_hp_trail_sec, SHIPPED_TRAIL_SEC), str(config.hud_hp_trail_sec))


func test_explicit_value_is_read() -> void:
	var config: CombatConfig = CombatConfig.from_dictionary({"hud": {"hp_trail_sec": 0.75}})
	_check("explicit 0.75", is_equal_approx(config.hud_hp_trail_sec, 0.75), str(config.hud_hp_trail_sec))


func test_omitted_block_keeps_default() -> void:
	var config: CombatConfig = CombatConfig.from_dictionary({})
	_check("no hud block: default 0.4", is_equal_approx(config.hud_hp_trail_sec, SHIPPED_TRAIL_SEC))


func test_negative_value_keeps_default() -> void:
	var config: CombatConfig = CombatConfig.from_dictionary({"hud": {"hp_trail_sec": -1.0}})
	_check("negative: default kept", is_equal_approx(config.hud_hp_trail_sec, SHIPPED_TRAIL_SEC))


func test_non_number_keeps_default() -> void:
	var config: CombatConfig = CombatConfig.from_dictionary({"hud": {"hp_trail_sec": "slow"}})
	_check("string: default kept", is_equal_approx(config.hud_hp_trail_sec, SHIPPED_TRAIL_SEC))


func test_zero_is_allowed() -> void:
	var config: CombatConfig = CombatConfig.from_dictionary({"hud": {"hp_trail_sec": 0}})
	_check("0 = no trail", is_equal_approx(config.hud_hp_trail_sec, 0.0))


# 2026-10-31 (user): hud.corner_panels, shipped false (HP numbers under the feet, no top HP panels).
func test_corner_panels_flag() -> void:
	var shipped: CombatConfig = CombatConfig.load_from_file()
	_check("shipped corner_panels = false", shipped != null and shipped.hud_corner_panels == false)
	_check("omitted corner_panels = false", CombatConfig.from_dictionary({"hud": {}}).hud_corner_panels == false)
	_check("explicit corner_panels true", CombatConfig.from_dictionary({"hud": {"corner_panels": true}}).hud_corner_panels == true)
	_check("non-bool corner_panels keeps false", CombatConfig.from_dictionary({"hud": {"corner_panels": 1}}).hud_corner_panels == false)
	# 2026-11-03: the player's own panel (monsters keep their HP plates).
	_check("shipped player_panel = true", shipped != null and shipped.hud_player_panel == true)
	_check("omitted player_panel = true", CombatConfig.from_dictionary({"hud": {}}).hud_player_panel == true)
	_check("explicit player_panel false", CombatConfig.from_dictionary({"hud": {"player_panel": false}}).hud_player_panel == false)
	_check("non-bool player_panel keeps true", CombatConfig.from_dictionary({"hud": {"player_panel": "no"}}).hud_player_panel == true)


# The HP number's slot: centred on the feet, HP_PLATE_GAP below them, HP_PLATE_HEIGHT tall, never narrower than
# HP_PLATE_MIN_W, whole pixels.
func test_hp_plate_rect() -> void:
	var r: Rect2 = CutHudView.hp_plate_rect(Vector2(400.0, 300.0), 10.0)
	_check("hp slot min width", is_equal_approx(r.size.x, CutHudView.HP_PLATE_MIN_W), str(r))
	_check("hp slot centred on the feet", is_equal_approx(r.get_center().x, 400.0), str(r))
	_check("hp slot under the feet", is_equal_approx(r.position.y, 300.0 + CutHudView.HP_PLATE_GAP) and is_equal_approx(r.size.y, CutHudView.HP_PLATE_HEIGHT), str(r))
	var wide: Rect2 = CutHudView.hp_plate_rect(Vector2(401.0, 300.5), 41.3)
	_check("hp slot grows with the text, whole px", wide.size.x == ceilf(41.3 + CutHudView.HP_PLATE_PAD_X * 2.0) and wide.position == wide.position.floor(), str(wide))


# 2026-10-31 (user): hud.step_rings, shipped false (no step-cooldown ring after a step).
func test_step_rings_flag() -> void:
	var shipped: CombatConfig = CombatConfig.load_from_file()
	_check("shipped step_rings = false", shipped != null and shipped.hud_step_rings == false)
	_check("explicit step_rings true", CombatConfig.from_dictionary({"hud": {"step_rings": true}}).hud_step_rings == true)
	_check("non-bool step_rings keeps false", CombatConfig.from_dictionary({"hud": {"step_rings": "yes"}}).hud_step_rings == false)
