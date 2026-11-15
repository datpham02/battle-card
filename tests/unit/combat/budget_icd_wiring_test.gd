extends SceneTree
## The two §9.2 pack budgets are WIRED, not merely declared.
## Run: godot --headless --path . -s res://tests/unit/combat/budget_icd_wiring_test.gd
##
## WHY THIS SUITE EXISTS, and why it is shaped the way it is.
##
## `StatusEffects.frost_burst_icd` and `PatternController.push_icd_sec` were both declared, both
## read by the code that needs them, and NEITHER WAS EVER ASSIGNED by any line in the project —
## from Phase 0 until 2026-11-15. Each defaulted to 0, which is OFF, so the burst had no cooldown
## and a shove had no cooldown, while design §9.2 budgets both. Nothing reported it: "off" and
## "not needed yet" are the same value.
##
## Both already had a test, and both tests PASSED the whole time, because each test SET THE VALUE
## ITSELF before checking the behaviour:
##     pattern_phase0_bugfix_test.gd:118   status.frost_burst_icd[P] = 10.0
##     pattern_phase0_effects_test.gd:229  ctrl.push_icd_sec = 3.0
## Those suites prove the MECHANISM works. They cannot notice that nothing in the game turns it on,
## because they are the thing that turns it on. A test that supplies its own premise can only ever
## report on itself.
##
## So every leg below reads the value the SHIPPED PATH produces — load the config from the file,
## hand it to the code that is supposed to apply it, then look — and no leg assigns one.
##
## THE SOURCE-TEXT LEG IS DELIBERATE AND IS LABELLED AS WEAK. `push_icd_sec` travels from
## CombatConfig into PatternController inside CombatView, which no fixture here can build, so that
## last hop is checked by reading combat_view.gd for the assignment. That is a grep, not a
## behaviour: it would pass against an assignment that is dead code. It is here because the bug
## this suite exists for was EXACTLY a missing assignment, and a grep catches that one shape
## reliably. Do not mistake it for proof that the value reaches a live controller.

## WATCHED FAILING FIRST, and the record of that nearly got lost.
## This gate was run against the UNWIRED code before the fix and it went red; the patch was then
## applied and it went green. So its green is evidence, not decoration.
##
## A note saying the opposite stood here for a few minutes, and the reason is worth more than the
## note: THREE COPIES OF THE SAME DRIVER SCRIPT WERE RUNNING AT ONCE. `TaskStop` had stopped their
## wrappers but not the bash loops, so two "stopped" runs carried on. One of them did the honest
## sequence - red, patch, green - at 17:16:05. A second reached its own red-first step seconds
## later, found the files ALREADY PATCHED by its twin, saw green, and concluded the gate could not
## fail. It then wrote that conclusion into this file.
##
## The lesson is not about locks. A check that reads shared state can be invalidated by a COPY OF
## ITSELF, and the second copy's report is indistinguishable from a real finding. Before believing
## "the gate did not fire", ask whether something else already satisfied the condition it tests.

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " + name) if ok else ("FAIL " + name + (" " + extra if not extra.is_empty() else "")))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_config_reads_both_budgets_from_data()
	test_frost_burst_icd_reaches_status_effects()
	test_frost_burst_icd_actually_holds_a_second_burst()
	test_push_icd_is_assigned_where_the_controller_is_built()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_config_reads_both_budgets_from_data() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	_check("combat.json gives a frost burst cooldown above zero",
		cfg.frost_burst_icd_sec > 0.0, str(cfg.frost_burst_icd_sec))
	_check("combat.json gives a push cooldown above zero",
		cfg.push_icd_sec > 0.0, str(cfg.push_icd_sec))


## The hop that was missing: CombatConfig -> StatusEffects. Nothing here sets the dictionary.
func test_frost_burst_icd_reaches_status_effects() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var status: StatusEffects = StatusEffects.new()
	cfg.configure_status(status)
	_check("configure_status sets the burst cooldown for the player",
		float(status.frost_burst_icd.get(P, 0.0)) > 0.0, str(status.frost_burst_icd))
	_check("and for the enemy", float(status.frost_burst_icd.get(E, 0.0)) > 0.0,
		str(status.frost_burst_icd))
	_check("and it matches the configured number",
		is_equal_approx(float(status.frost_burst_icd.get(P, 0.0)), cfg.frost_burst_icd_sec),
		"%s vs %s" % [status.frost_burst_icd.get(P, 0.0), cfg.frost_burst_icd_sec])


## Behaviour, not plumbing: with the SHIPPED numbers, a second burst inside the window is held.
## Two stacks are applied twice over; the first reaches the threshold and bursts, the second must
## not. The leg checks BOTH directions — a burst that never fires at all would also "hold" one.
func test_frost_burst_icd_actually_holds_a_second_burst() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var status: StatusEffects = StatusEffects.new()
	cfg.configure_status(status)
	var first: float = 0.0
	for _i: int in range(cfg.frost_stacks_to_burst):
		first = maxf(first, status.apply_frost(P, 1))
	_check("the first burst fires with the shipped numbers", first > 0.0, str(first))
	var second: float = 0.0
	for _i: int in range(cfg.frost_stacks_to_burst):
		second = maxf(second, status.apply_frost(P, 1))
	_check("a second burst inside the cooldown is held", is_equal_approx(second, 0.0), str(second))


## The weak leg. See the header: this is a grep, and it is here because the defect was a missing
## assignment. It cannot tell a live assignment from a dead one.
func test_push_icd_is_assigned_where_the_controller_is_built() -> void:
	var src: String = FileAccess.get_file_as_string("res://src/combat/combat_view.gd")
	_check("combat_view.gd can be read", not src.is_empty())
	var count: int = src.count("push_icd_sec = ")
	# TWO places build a PatternController: the multi-enemy loop and the single-enemy match. Wiring
	# one and calling it done is its own class of mistake, so the number is pinned, not just ">0".
	_check("both PatternController sites assign the push cooldown", count == 2, "dem duoc %d" % count)
