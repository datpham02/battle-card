extends SceneTree
## Story 047 Part C: CombatState.damaged(side, amount) fires exactly when HP actually dropped, with the HP
## lost (after the floor / death-hook clamps), and never for ignored damage: 0 or negative amounts, an
## invulnerable enemy, a dead unit, an enemy already at its HP floor.
## Run: godot --headless --path . -s res://tests/unit/combat/state_damaged_signal_test.gd

const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY
const MAX_HP: float = 100.0
const HIT: float = 5.0
const PLAYER_HIT: float = 7.0
const FLOOR_HP: float = 50.0
const BIG_HIT: float = 60.0
const OVERKILL: float = 10000.0
const INVULNERABLE_SEC: float = 1.0
const LOW_HP: float = 10.0

var fails: int = 0
## Recorded [side, amount] pairs of the suite under test.
var _events: Array = []


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_damage_enemy_fires_with_the_amount()
	test_damage_player_fires_with_the_amount()
	test_zero_or_negative_damage_does_not_fire()
	test_invulnerable_enemy_does_not_fire()
	test_hp_floor_clamps_the_amount_and_silences_at_the_floor()
	test_dead_units_do_not_fire()
	test_death_hook_holds_hp_and_reports_the_real_loss()
	test_damaged_fires_before_changed_and_death()
	print("FAILS=%d" % fails)
	quit(fails)


func _make_state() -> CombatState:
	_events.clear()
	var state := CombatState.new(BoardGrid.new(3, 3), MAX_HP, MAX_HP)
	state.damaged.connect(func(side: int, amount: float) -> void: _events.append([side, amount]))
	return state


func test_damage_enemy_fires_with_the_amount() -> void:
	var state: CombatState = _make_state()
	state.damage_enemy(HIT)
	_check("test_damage_enemy_fires_once_with_side_enemy_and_the_amount", _events == [[ENEMY, HIT]], str(_events))


func test_damage_player_fires_with_the_amount() -> void:
	var state: CombatState = _make_state()
	state.damage_player(PLAYER_HIT)
	_check("test_damage_player_fires_once_with_side_player_and_the_amount", _events == [[PLAYER, PLAYER_HIT]], str(_events))
	state.damage(ENEMY, HIT)
	_check("test_damage_by_side_routes_to_the_same_signal", _events == [[PLAYER, PLAYER_HIT], [ENEMY, HIT]], str(_events))


func test_zero_or_negative_damage_does_not_fire() -> void:
	var state: CombatState = _make_state()
	state.damage_enemy(0.0)
	state.damage_player(0.0)
	state.damage_enemy(-HIT)
	state.damage_player(-HIT)
	_check("test_zero_and_negative_damage_fire_nothing", _events.is_empty(), str(_events))


func test_invulnerable_enemy_does_not_fire() -> void:
	var state: CombatState = _make_state()
	state.enemy_invulnerable_left = INVULNERABLE_SEC
	state.damage_enemy(HIT)
	_check("test_invulnerable_enemy_fires_nothing_and_keeps_hp", _events.is_empty() and state.enemy_hp == MAX_HP)
	state.enemy_invulnerable_left = 0.0
	state.damage_enemy(HIT)
	_check("test_after_invulnerability_the_signal_fires_again", _events == [[ENEMY, HIT]], str(_events))


func test_hp_floor_clamps_the_amount_and_silences_at_the_floor() -> void:
	var state: CombatState = _make_state()
	state.enemy_hp_floor = FLOOR_HP
	state.damage_enemy(BIG_HIT)
	_check("test_hit_across_the_floor_reports_the_clamped_loss", _events == [[ENEMY, MAX_HP - FLOOR_HP]], str(_events))
	state.damage_enemy(HIT)
	_check("test_hit_at_the_floor_fires_nothing", _events.size() == 1, str(_events))


func test_dead_units_do_not_fire() -> void:
	var state: CombatState = _make_state()
	state.damage_enemy(OVERKILL)
	_check("test_killing_blow_reports_the_hp_that_was_left_not_the_overkill", _events == [[ENEMY, MAX_HP]], str(_events))
	state.damage_enemy(HIT)
	_check("test_dead_enemy_fires_nothing", _events.size() == 1, str(_events))
	state.damage_player(OVERKILL)
	state.damage_player(HIT)
	_check("test_dead_player_fires_once_for_the_killing_blow_only", _events == [[ENEMY, MAX_HP], [PLAYER, MAX_HP]], str(_events))


func test_death_hook_holds_hp_and_reports_the_real_loss() -> void:
	var state: CombatState = _make_state()
	state.enemy_hp = LOW_HP
	state.enemy_death_hook_fn = func() -> bool: return true
	state.damage_enemy(OVERKILL)
	_check("test_rebirth_hook_holds_at_HOLD_HP_and_reports_the_loss_down_to_it", _events == [[ENEMY, LOW_HP - CombatState.HOLD_HP]] and state.enemy_hp == CombatState.HOLD_HP, str(_events))


func test_damaged_fires_before_changed_and_death() -> void:
	var state: CombatState = _make_state()
	var order: Array[String] = []
	state.damaged.connect(func(_side: int, _amount: float) -> void: order.append("damaged"))
	state.changed.connect(func() -> void: order.append("changed"))
	state.enemy_died.connect(func() -> void: order.append("enemy_died"))
	state.damage_enemy(OVERKILL)
	_check("test_order_damaged_then_changed_then_enemy_died", order == ["damaged", "changed", "enemy_died"], str(order))
