extends SceneTree
## hunter_mark attribution (user decision 2026-11-14: "con gây ra" - the mark belongs to the unit that caused it).
##
## Before this change `_try_mark` called `apply_fragile(CombatState.Side.ENEMY, …)`, which is unit 0's key, so a
## Ran stack earned by enemy unit 1 landed on unit 0 and the player aimed the bonus damage at the wrong enemy.
##
## Every check leads with a POSITIVE leg. "Unit 0 did not get the stack" passes just as happily against a passive
## that marks NOBODY, which is exactly what a wrong key argument produces.
##
## Run: godot --headless --path . -s res://tests/unit/combat/hunter_mark_attribution_test.gd
##
## LIMIT OF THIS SUITE (multi-enemy Phase 5): it asserts STATE, never a frame. That the dispatch reaches the
## right unit is checked here; that a PLAYER can tell which enemy a trait fired for is NOT, and cannot be -
## this harness captures no frames. The failure it is blind to is the ambiguous unit, not the wrong one.
## The Phase 5 visual gate (production/qa/evidence/) is what would retire this paragraph. Until those frames
## exist, a green run here is not evidence that the feature reads on screen.

const E: int = CombatState.Side.ENEMY
const ARENA: Dictionary = {"side_cols": 5, "side_rows": 4, "missing_cells": []}

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _initialize() -> void:
	await process_frame
	_test_thorn_step_marks_the_unit_that_stepped()
	_test_zone_marks_the_unit_it_touches()
	_test_one_zone_marks_once()
	_test_single_enemy_unchanged()
	await process_frame
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


# --- harness: state + status + the passive, no CombatView ---------------------------------------------------------

func _rig(unit_count: int) -> Dictionary:
	var status := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(status)   # the shipped Ran cap, not the class default
	var grid := BoardGrid.new(int(ARENA["side_cols"]), int(ARENA["side_rows"]))
	var state := CombatState.new(grid, 100.0, 100.0)
	# Unit 0 exists from the constructor; add_unit places each extra one at a free anchor of its half.
	for i: int in range(1, unit_count):
		var index: int = state.add_unit("u%d" % i, 100.0)
		assert(index == i, "rig: unit %d was not added" % i)
	var mark: BasePassive = PassiveRegistry.create("hunter_mark")
	mark.setup({"state": state, "status": status, "grid": grid}, {"fragile_stacks": 1, "icd_sec": 0.0})
	return {"state": state, "status": status, "mark": mark, "grid": grid}


# A cell of the enemy half belonging to [param key] and one that belongs to nobody.
func _cell_of(r: Dictionary, key: int) -> Vector2i:
	return (r["state"] as CombatState).cell_of(key)


# --- the rule ------------------------------------------------------------------------------------------------------

func _test_thorn_step_marks_the_unit_that_stepped() -> void:
	var r: Dictionary = _rig(2)
	var status: StatusEffects = r["status"]
	var k1: int = CombatState.unit_key(1)
	(r["mark"] as BasePassive).on_boss_thorn_step(_cell_of(r, k1), k1)

	# POSITIVE first: the stack must actually exist somewhere, on the unit that stepped.
	check(status.fragile_stacks(k1) >= 1, "thorn step: the unit that stepped carries the Ran stack",
		"k1=%d" % status.fragile_stacks(k1))
	check(status.fragile_stacks(E) == 0, "thorn step: unit 0 did NOT get a stack it never earned",
		"unit0=%d" % status.fragile_stacks(E))


func _test_zone_marks_the_unit_it_touches() -> void:
	var r: Dictionary = _rig(2)
	var state: CombatState = r["state"]
	var status: StatusEffects = r["status"]
	var k1: int = CombatState.unit_key(1)
	var beside: Vector2i = _cell_of(r, k1) + Vector2i(0, 1)
	(r["mark"] as BasePassive).on_player_zone_formed(StatusEffects.KIND_THORNS, [beside] as Array[Vector2i])

	check(status.fragile_stacks(k1) >= 1, "zone: thorns laid beside unit 1 mark unit 1",
		"k1=%d, cells %s vs %s" % [status.fragile_stacks(k1), str(beside), str(state.unit_cells(k1))])
	check(status.fragile_stacks(E) == 0, "zone: unit 0, nowhere near the thorns, is untouched",
		"unit0=%d" % status.fragile_stacks(E))


func _test_one_zone_marks_once() -> void:
	# The internal cooldown is the balance lever, and it is per passive, not per unit: one laying hands out one
	# stack even when it touches both. Letting it mark twice would silently make the passive worth N times more
	# in a multi-enemy match than characters.json was ever balanced for.
	var r: Dictionary = _rig(2)
	var state: CombatState = r["state"]
	var status: StatusEffects = r["status"]
	var mark: BasePassive = r["mark"]
	var both: Array[Vector2i] = []
	for key: int in state.enemy_keys():
		both.append(state.cell_of(key))
	mark.on_player_zone_formed(StatusEffects.KIND_THORNS, both)
	check((mark as HunterMarkPassive).marks_given() == 1, "one zone: a laying touching both units still marks exactly once",
		"marks=%d" % (mark as HunterMarkPassive).marks_given())


func _test_single_enemy_unchanged() -> void:
	# The 1v1 path must be byte-for-byte what it was: these are the calls sim_core.gd and four test suites make,
	# with no key argument at all.
	var r: Dictionary = _rig(1)
	var status: StatusEffects = r["status"]
	var mark: BasePassive = r["mark"]
	mark.on_boss_thorn_step(_cell_of(r, E))
	check(status.fragile_stacks(E) >= 1, "1v1: a bare one-argument call still marks the enemy",
		"unit0=%d" % status.fragile_stacks(E))
	check((mark as HunterMarkPassive).marks_given() == 1, "1v1: exactly one mark", "marks=%d" % (mark as HunterMarkPassive).marks_given())
