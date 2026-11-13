extends SceneTree
## Monster Skill Phase 0 (design §5.3): Poison (Độc), a unit-bound DoT in StatusEffects: starts, ticks once per tick_sec
## however large the delta, ends on time, REFRESHES on a second application (never stacks: one tick per cadence, the
## larger damage, the longer time), is cleansed on death and by clear(), shows in active_statuses, and refuses bad numbers.
## Run: godot --headless --path . -s res://tests/unit/combat/status_poison_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_poison_starts_ticks_and_ends()
	test_poison_large_delta_ticks_each_cadence()
	test_poison_second_application_refreshes_without_stacking()
	test_poison_cleansed_on_death_and_clear()
	test_poison_on_enemy_respects_invulnerability()
	test_poison_bad_numbers_ignored()
	test_poison_in_active_statuses()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _state() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 100.0, 100.0)


func test_poison_starts_ticks_and_ends() -> void:
	# Arrange
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	var ended: Array = []
	status.poison_ended.connect(func(side: int) -> void: ended.append(side))
	# Act: 3 s, 2 damage every 0.5 s.
	status.poison(P, 3.0, 0.5, 2.0)
	# Assert
	_check("poison: active with 3 s left", status.is_poisoned(P) and is_equal_approx(status.get_poison_left(P), 3.0))
	status.tick(0.25, state)
	_check("poison: no damage before the first cadence", is_equal_approx(state.player_hp, 100.0))
	status.tick(0.25, state)
	_check("poison: 2 damage at 0.5 s", is_equal_approx(state.player_hp, 98.0), str(state.player_hp))
	status.tick(2.5, state)
	_check("poison: 6 ticks in 3 s = 12 damage", is_equal_approx(state.player_hp, 88.0), str(state.player_hp))
	_check("poison: ended on time, signal once", not status.is_poisoned(P) and ended == [P])
	status.tick(1.0, state)
	_check("poison: nothing after the end", is_equal_approx(state.player_hp, 88.0))


func test_poison_large_delta_ticks_each_cadence() -> void:
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	status.poison(P, 2.0, 0.5, 1.5)
	status.tick(5.0, state)
	_check("poison: one 5 s delta = 4 ticks of 1.5 = 6", is_equal_approx(state.player_hp, 94.0), str(state.player_hp))
	_check("poison: gone after the big delta", not status.is_poisoned(P))


func test_poison_second_application_refreshes_without_stacking() -> void:
	# Arrange: a 3 s / 2 dmg poison, 1 s in.
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	var applied: Array = []
	status.poisoned.connect(func(side: int) -> void: applied.append(side))
	status.poison(P, 3.0, 0.5, 2.0)
	status.tick(1.0, state)
	_check("refresh: 4 damage after 1 s", is_equal_approx(state.player_hp, 96.0))
	# Act: a weaker, longer poison lands on top.
	status.poison(P, 5.0, 0.5, 1.0)
	# Assert: one poison: the longer time, the larger damage, the same cadence; a tick is still 2, never 2 + 1.
	_check("refresh: time becomes the longer (5 s)", is_equal_approx(status.get_poison_left(P), 5.0), str(status.get_poison_left(P)))
	_check("refresh: damage keeps the larger (2)", is_equal_approx(status.poison_tick_damage(P), 2.0))
	_check("refresh: poisoned signal twice (two applications)", applied.size() == 2)
	status.tick(0.5, state)
	_check("refresh: one tick of 2 per cadence, not 3", is_equal_approx(state.player_hp, 94.0), str(state.player_hp))
	status.tick(4.5, state)
	_check("refresh: 9 more ticks of 2 = 18, then ends", is_equal_approx(state.player_hp, 76.0) and not status.is_poisoned(P), str(state.player_hp))
	# A shorter re-application never shortens.
	status.poison(P, 4.0, 0.5, 1.0)
	status.poison(P, 1.0, 0.5, 1.0)
	_check("refresh: a shorter poison never shortens the time", is_equal_approx(status.get_poison_left(P), 4.0))


func test_poison_cleansed_on_death_and_clear() -> void:
	# Arrange: 1 HP left, a lethal poison.
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	var deaths: Array = []  # a lambda captures an int by value, so count in an Array
	state.player_died.connect(func() -> void: deaths.append(true))
	state.set_player_hp(1.0)
	status.poison(P, 10.0, 0.5, 2.0)
	# Act: one cadence kills; later ticks must not keep hurting or re-fire the death.
	status.tick(0.5, state)
	_check("death: the tick killed the player once", state.is_player_dead() and deaths.size() == 1, str(deaths.size()))
	_check("death: the poison is cleansed on death", not status.is_poisoned(P))
	status.tick(2.0, state)
	_check("death: nothing after death", deaths.size() == 1 and is_equal_approx(state.player_hp, 0.0))
	# clear() wipes a live poison.
	var state2: CombatState = _state()
	status.poison(P, 10.0, 0.5, 2.0)
	status.clear()
	status.tick(1.0, state2)
	_check("clear: wipes the poison, no damage", not status.is_poisoned(P) and is_equal_approx(state2.player_hp, 100.0))
	# Cleanse ends it early.
	status.poison(P, 10.0, 0.5, 2.0)
	_check("clear_poison: true when one was there", status.clear_poison(P) and not status.is_poisoned(P))
	_check("clear_poison: false when none", not status.clear_poison(P))


func test_poison_on_enemy_respects_invulnerability() -> void:
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	status.poison(E, 2.0, 0.5, 3.0)
	status.tick(0.5, state)
	_check("enemy: poison hurts the enemy through damage_enemy", is_equal_approx(state.enemy_hp, 97.0), str(state.enemy_hp))
	state.enemy_invulnerable_left = 1.0
	status.tick(0.5, state)
	_check("enemy: an invulnerable enemy takes no poison tick", is_equal_approx(state.enemy_hp, 97.0), str(state.enemy_hp))
	_check("enemy: the player is untouched", is_equal_approx(state.player_hp, 100.0))


func test_poison_bad_numbers_ignored() -> void:
	var status: StatusEffects = StatusEffects.new()
	status.poison(P, 0.0, 0.5, 2.0)
	status.poison(P, 3.0, 0.0, 2.0)
	status.poison(P, 3.0, 0.5, 0.0)
	status.poison(P, -1.0, 0.5, 2.0)
	_check("bad numbers: nothing applied", not status.is_poisoned(P))


func test_poison_in_active_statuses() -> void:
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = _state()
	status.poison(P, 4.0, 0.5, 1.0)
	status.tick(1.0, state)
	var rows: Array[Dictionary] = status.active_statuses(P, state.player_cell)
	var found: Dictionary = {}
	for row: Dictionary in rows:
		if str(row["id"]) == StatusEffects.STATUS_POISON:
			found = row
	_check("hud: poison listed as a timed debuff", not found.is_empty() and not bool(found.get("buff", true)), str(rows))
	_check("hud: left 3 of total 4", not found.is_empty() and is_equal_approx(float(found["left"]), 3.0) and is_equal_approx(float(found["total"]), 4.0), str(found))
	_check("hud: STATUS_ORDER holds poison", StatusEffects.STATUS_ORDER.has(StatusEffects.STATUS_POISON))
