extends SceneTree
## 2026-10-31 (user: crossing a debuff zone did nothing): StatusEffects.burn_on_entry — stepping onto a burning cell
## costs one tick at once and restarts that cell's tick clock; burn_hurt reports every burn hit; the shipped
## combat.json turns it on. Also the floor-damage pop helpers of CutHudView (pure).
## Run: godot --headless --path . -s res://tests/unit/combat/burn_entry_test.gd

var fails: int = 0

## Boundary values of the burn used by every case (the exact numbers are the point).
const TICK_SEC: float = 0.5
const DAMAGE: float = 2.0
const START_HP: float = 1000.0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _mk() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), START_HP, START_HP, Vector2i(1, 1), Vector2i(4, 1))


func _initialize() -> void:
	test_crossing_a_burning_cell_costs_one_tick()
	test_staying_after_entry_ticks_a_full_tick_later()
	test_entry_off_keeps_the_old_rule()
	test_standing_still_pays_no_entry()
	test_burn_hurt_signal()
	test_shipped_config_turns_it_on()
	test_dot_pop_helpers()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_crossing_a_burning_cell_costs_one_tick() -> void:
	var st := _mk()
	var fx := StatusEffects.new()
	fx.burn_on_entry = true
	fx.tick(0.0, st)  # remembers the start cell
	fx.ignite([Vector2i(0, 1)] as Array[Vector2i], 3.0, TICK_SEC, DAMAGE)
	st.set_player_cell(Vector2i(0, 1))
	fx.tick(0.1, st)
	ck("entry: one tick at once", is_equal_approx(st.player_hp, START_HP - DAMAGE), str(st.player_hp))
	st.set_player_cell(Vector2i(0, 0))
	fx.tick(0.1, st)
	ck("entry: leaving after 0.1 s costs nothing more", is_equal_approx(st.player_hp, START_HP - DAMAGE), str(st.player_hp))


func test_staying_after_entry_ticks_a_full_tick_later() -> void:
	var st := _mk()
	var fx := StatusEffects.new()
	fx.burn_on_entry = true
	fx.tick(0.0, st)
	fx.ignite([Vector2i(0, 1)] as Array[Vector2i], 3.0, TICK_SEC, DAMAGE)
	st.set_player_cell(Vector2i(0, 1))
	fx.tick(0.0, st)
	fx.tick(TICK_SEC - 0.05, st)
	ck("stay: no second tick before tick_sec", is_equal_approx(st.player_hp, START_HP - DAMAGE), str(st.player_hp))
	fx.tick(0.05, st)
	ck("stay: second tick at tick_sec after entry", is_equal_approx(st.player_hp, START_HP - DAMAGE * 2.0), str(st.player_hp))


func test_entry_off_keeps_the_old_rule() -> void:
	var st := _mk()
	var fx := StatusEffects.new()
	fx.tick(0.0, st)
	fx.ignite([Vector2i(0, 1)] as Array[Vector2i], 3.0, TICK_SEC, DAMAGE)
	st.set_player_cell(Vector2i(0, 1))
	fx.tick(0.1, st)
	st.set_player_cell(Vector2i(0, 0))
	fx.tick(0.1, st)
	ck("off: crossing in 0.1 s costs nothing (old rule)", is_equal_approx(st.player_hp, START_HP), str(st.player_hp))


func test_standing_still_pays_no_entry() -> void:
	var st := _mk()
	var fx := StatusEffects.new()
	fx.burn_on_entry = true
	fx.tick(0.0, st)
	fx.ignite([Vector2i(1, 1)] as Array[Vector2i], 3.0, TICK_SEC, DAMAGE)
	fx.tick(0.1, st)
	ck("still: a cell igniting under the unit is not an entry", is_equal_approx(st.player_hp, START_HP), str(st.player_hp))


func test_burn_hurt_signal() -> void:
	var st := _mk()
	var fx := StatusEffects.new()
	fx.burn_on_entry = true
	var got: Array = []
	fx.burn_hurt.connect(func(side: int, cell: Vector2i, damage: float) -> void: got.append([side, cell, damage]))
	fx.tick(0.0, st)
	fx.ignite([Vector2i(0, 1)] as Array[Vector2i], 3.0, TICK_SEC, DAMAGE)
	st.set_player_cell(Vector2i(0, 1))
	fx.tick(0.0, st)
	fx.tick(TICK_SEC, st)
	ck("signal: entry + one tick reported", got.size() == 2, str(got))
	ck("signal: side, cell and damage", got.size() == 2 and int(got[0][0]) == CombatState.Side.PLAYER and got[0][1] == Vector2i(0, 1) and is_equal_approx(float(got[0][2]), DAMAGE))


func test_shipped_config_turns_it_on() -> void:
	var config: CombatConfig = CombatConfig.load_from_file()
	ck("config: shipped burn_on_entry = true", config != null and config.burn_on_entry)
	var fx := StatusEffects.new()
	if config != null:
		config.configure_status(fx)
	ck("config: configure_status sets StatusEffects.burn_on_entry", fx.burn_on_entry)
	ck("config: non-bool keeps the default", CombatConfig.from_dictionary({"burn_on_entry": 1}).burn_on_entry == true)


func test_dot_pop_helpers() -> void:
	var start: Vector2 = CutHudView.dot_pop_offset(0.0, 0)
	var end: Vector2 = CutHudView.dot_pop_offset(CutHudView.DOT_POP_SEC, 0)
	ck("pop: starts DOT_POP_LIFT above the feet", is_equal_approx(start.y, -CutHudView.DOT_POP_LIFT) and is_equal_approx(start.x, 0.0))
	ck("pop: rises DOT_POP_RISE over its life", is_equal_approx(end.y - start.y, -CutHudView.DOT_POP_RISE))
	ck("pop: later pops step sideways", is_equal_approx(CutHudView.dot_pop_offset(0.0, 2).x, CutHudView.DOT_POP_STAGGER * 2.0))
	ck("pop: opaque before the fade", is_equal_approx(CutHudView.dot_pop_alpha(CutHudView.DOT_POP_SEC), 1.0))
	ck("pop: transparent at the end", is_equal_approx(CutHudView.dot_pop_alpha(0.0), 0.0))
