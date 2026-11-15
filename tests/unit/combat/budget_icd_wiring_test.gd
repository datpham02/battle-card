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

## MEASURED LATER, AND IT CORRECTS THE FIX COMMIT (40bac1ae) THAT SHIPPED BESIDE THIS FILE.
## That commit says "NO TEST CAUGHT THIS" about the BossBrainConfig defect. That is false, and the
## claim was made from reasoning rather than from a run. Measured afterwards in a separate clean
## checkout, by adding exactly the two bad lines to dac07c65 and running the only two suites that
## reach the body of CombatView._setup_pattern_brain:
##
##     baseline (clean)                  with the two bad lines
##   boss_footprint_dodge  FAILS=0 se=0    FAILS=0  se=1  exit=0   <- false green, caught by the
##                                                                     runner's SCRIPT ERROR count
##   forest_witch_flow     FAILS=0 se=0    FAILS=1  se=1  exit=1   <- the suite itself caught it
##
## So a suite DOES cover that class, and the runner covers the other half. Neither fired because no
## full run ever executed the broken code: the lines were in the tree from 17:16 to ~18:1x, the
## 16:31 run ended before that window and the next run began after it. NOT A COVERAGE HOLE - A
## TIMING ONE. The original claim explained a gap in capability using evidence that only described
## a gap in scheduling.
##
## It also did NOT hang, contrary to what was expected of a startup error: 5 s and 4 s, no timeout.
## The hang shape is real elsewhere; it did not apply here, and the figure nearly went into
## runner-known-gaps.md as a filled-in case before the run existed.
##
## The correction is recorded here rather than by amending 40bac1ae: a claim and its correction
## both belong in the record. Editing the old sentence away would leave no trace that it was ever
## believed, which is the part worth keeping.
##
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


## WHAT THIS GATE IS FOR, restated 2026-11-15 after it demanded the opposite of the design.
## It first read "the shipped number is above zero", which tied a WIRING gate to a BALANCE value
## - and §G puts that value at 0, so the gate was asking for a rebalance. The hop under test is
## data -> config -> StatusEffects. So: pin the shipped default at OFF (§G), then feed a number
## in and watch it travel. That form cannot be satisfied by a dead assignment and does not care
## what the shipped balance happens to be.
func test_config_reads_both_budgets_from_data() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	_check("§G: the shipped frost burst budget is OFF",
		is_equal_approx(cfg.frost_burst_icd_sec, 0.0), str(cfg.frost_burst_icd_sec))
	_check("§G: the shipped push budget is OFF",
		is_equal_approx(cfg.push_icd_sec, 0.0), str(cfg.push_icd_sec))
	cfg._parse_keywords({"frost_burst_icd_sec": 2.0, "push_icd_sec": 3.0})
	_check("a frost budget in data reaches the config",
		is_equal_approx(cfg.frost_burst_icd_sec, 2.0), str(cfg.frost_burst_icd_sec))
	_check("a push budget in data reaches the config",
		is_equal_approx(cfg.push_icd_sec, 3.0), str(cfg.push_icd_sec))


## The hop that was missing: CombatConfig -> StatusEffects. Nothing here sets the dictionary.
func test_frost_burst_icd_reaches_status_effects() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	cfg.frost_burst_icd_sec = 2.0
	var status: StatusEffects = StatusEffects.new()
	cfg.configure_status(status)
	_check("configure_status carries the number to the player side",
		is_equal_approx(float(status.frost_burst_icd.get(P, 0.0)), 2.0), str(status.frost_burst_icd))
	_check("and to the enemy side",
		is_equal_approx(float(status.frost_burst_icd.get(E, 0.0)), 2.0), str(status.frost_burst_icd))
	# The other direction. Without it the leg above passes against a hardcoded 2.0 just as well as
	# against a real assignment - and §G's default is exactly the value such a constant would hide.
	var off_cfg: CombatConfig = CombatConfig.load_from_file()
	var off: StatusEffects = StatusEffects.new()
	off_cfg.configure_status(off)
	_check("and the shipped config leaves it OFF (§G)",
		is_equal_approx(float(off.frost_burst_icd.get(P, 0.0)), 0.0), str(off.frost_burst_icd))


## Behaviour, not plumbing: with the SHIPPED numbers, a second burst inside the window is held.
## Two stacks are applied twice over; the first reaches the threshold and bursts, the second must
## not. The leg checks BOTH directions — a burst that never fires at all would also "hold" one.
func test_frost_burst_icd_actually_holds_a_second_burst() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	cfg.frost_burst_icd_sec = 2.0
	var status: StatusEffects = StatusEffects.new()
	cfg.configure_status(status)
	var first: float = 0.0
	for _i: int in range(cfg.frost_stacks_to_burst):
		first = maxf(first, status.apply_frost(P, 1))
	_check("the first burst fires", first > 0.0, str(first))
	var second: float = 0.0
	for _i: int in range(cfg.frost_stacks_to_burst):
		second = maxf(second, status.apply_frost(P, 1))
	_check("a second burst inside the cooldown is held", is_equal_approx(second, 0.0), str(second))
	# AND THE MIRROR, which is the whole reason three frost suites went red on 5cb8f489: at the
	# SHIPPED default the second burst MUST fire. Without this leg, "held" and "never fires at all"
	# are the same observation, and a 2.0 default would read as correct here forever.
	var off_cfg: CombatConfig = CombatConfig.load_from_file()
	var off: StatusEffects = StatusEffects.new()
	off_cfg.configure_status(off)
	var a: float = 0.0
	for _i: int in range(off_cfg.frost_stacks_to_burst):
		a = maxf(a, off.apply_frost(P, 1))
	var b: float = 0.0
	for _i: int in range(off_cfg.frost_stacks_to_burst):
		b = maxf(b, off.apply_frost(P, 1))
	_check("with the budget OFF (§G) a second burst fires back to back",
		a > 0.0 and b > 0.0, "%s then %s" % [a, b])


## The weak leg. See the header: this is a grep, and it is here because the defect was a missing
## assignment. It cannot tell a live assignment from a dead one.
func test_push_icd_is_assigned_where_the_controller_is_built() -> void:
	var src: String = FileAccess.get_file_as_string("res://src/combat/combat_view.gd")
	_check("combat_view.gd can be read", not src.is_empty())
	var count: int = src.count("push_icd_sec = ")
	# TWO places build a PatternController: the multi-enemy loop and the single-enemy match. Wiring
	# one and calling it done is its own class of mistake, so the number is pinned, not just ">0".
	_check("both PatternController sites assign the push cooldown", count == 2, "dem duoc %d" % count)
