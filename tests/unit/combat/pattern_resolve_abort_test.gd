extends SceneTree
## Regression test for the crash found by the monster-skills group-E sim (kiem_si, set 2001, 2026-11-13):
## "Invalid access to 'id'" at pattern_controller.gd _resolve_cells and again in _resolve_warning.
##
## Cause: _resolve_cells damages the player, applies status, forces a move and records the result, and ANY of those
## can end the skill under it (a parried strike whose reflect crosses a phase threshold, a rebirth or burrow pause,
## a stun). _end_skill sets `_skill = {}`. The two lines that ran afterwards still read `_skill["id"]`.
##
## What this pins: the resolved skill id must survive the abort (it is read from the result, filled before anything
## else ran), and _resolve_warning must stop instead of reading an emptied `_skill`. Against the unfixed code the
## emitted id is "<null>" and the first check below fails.
##
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_resolve_abort_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const STEP: float = 0.05
const ENEMY: String = "dev_pattern_dummy"
const SEED: int = 3

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	test_skill_ended_during_resolve_does_not_crash(cfg)
	test_normal_resolve_still_reports_its_id(cfg)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _tick(w: Dictionary, sec: float) -> void:
	var left: float = sec
	while left > 0.000001:
		var d: float = minf(STEP, left)
		(w["status"] as StatusEffects).tick(d, w["state"] as CombatState)
		(w["mover"] as UnitMover).tick(d)
		(w["ctrl"] as PatternController).tick(d)
		left -= d


# Ticks until the controller is WARNING on a strike, then puts the hero on a warned cell so the resolve will hit.
# Returns the skill id, or "" when no warning came.
func _warn_on_player(w: Dictionary, budget_sec: float = 40.0) -> String:
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	while t < budget_sec:
		if ctrl.get_stage() == PatternController.Stage.WARNING and not ctrl.telegraph_cells().is_empty():
			state.player_cell = ctrl.telegraph_cells()[0]
			return str(ctrl.get_current_skill().get("id", ""))
		_tick(w, STEP)
		t += STEP
	return ""


func test_skill_ended_during_resolve_does_not_crash(cfg: EnemySkillsConfig) -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, ENEMY, SEED)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var skill_id: String = _warn_on_player(w)
	_check("abort: the enemy warns a strike on the hero", not skill_id.is_empty(), skill_id)
	if skill_id.is_empty():
		return

	var resolved: Array = []
	var cleared: Array = []
	ctrl.skill_resolved.connect(func(id: String, _r: Dictionary) -> void: resolved.append(id))
	ctrl.warning_cleared.connect(func(id: String, reason: String) -> void: cleared.append([id, reason]))
	# The real chain in one line: something inside the damage path ends the skill while _resolve_cells is still
	# running. A parry reflect crossing a phase threshold is the case that was actually seen; this reproduces the
	# state it leaves behind without needing that whole setup.
	# The id is taken from the controller at the instant of the abort, not from the warning seen earlier: that is the
	# skill whose resolve is actually in flight, whatever the brain did in between.
	var aborted: Array = [false]
	var aborted_id: Array = [""]
	state.damaged.connect(func(side: int, _amount: float) -> void:
		if side == CombatState.Side.PLAYER and not aborted[0]:
			aborted[0] = true
			aborted_id[0] = str(ctrl.get_current_skill().get("id", ""))
			ctrl._end_skill("test_abort", false))

	# Stop the moment the aborted resolve is through. Ticking on would let the enemy pick and resolve its NEXT skill,
	# whose own (correct) "resolved" would be mistaken for this one's.
	var t: float = 0.0
	while t < 3.0 and not (aborted[0] and resolved.size() >= 1):
		_tick(w, STEP)
		t += STEP

	_check("abort: a skill really was ended during its resolve", aborted[0] and not aborted_id[0].is_empty(),
		aborted_id[0])
	_check("abort: the aborted skill still reported itself", resolved.size() >= 1, str(resolved))
	if resolved.size() >= 1 and aborted[0]:
		# Against the unfixed code this read is `str(_skill["id"])` on an emptied dictionary. Observed on 2026-11-13:
		# the engine logs "Invalid access to property or key 'id'" twice and the emit carries the id of a DIFFERENT
		# skill ('dev_prick' where 'dev_bar' resolved) — the listener is told the wrong skill landed.
		_check("abort: it names the skill that actually resolved", str(resolved[0]) == aborted_id[0],
			"'%s' expected '%s'" % [str(resolved[0]), aborted_id[0]])
	# _end_skill emits warning_cleared itself with its own reason; _resolve_warning must NOT add a second
	# "resolved" one on top of it for the SAME skill.
	var reasons: Array = []
	for c: Array in cleared:
		if str(c[0]) == aborted_id[0]:
			reasons.append(str(c[1]))
	_check("abort: the aborted skill cleared with the abort reason, not with 'resolved'",
		reasons.has("test_abort") and not reasons.has("resolved"), str(reasons))
	_check("abort: the aborted skill is no longer the current one",
		str(ctrl.get_current_skill().get("id", "")) != aborted_id[0], str(ctrl.get_current_skill().get("id", "")))


func test_normal_resolve_still_reports_its_id(cfg: EnemySkillsConfig) -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, ENEMY, SEED)
	var ctrl: PatternController = w["ctrl"]
	var skill_id: String = _warn_on_player(w)
	_check("normal: the enemy warns a strike on the hero", not skill_id.is_empty(), skill_id)
	if skill_id.is_empty():
		return
	var resolved: Array = []
	var cleared: Array = []
	ctrl.skill_resolved.connect(func(id: String, _r: Dictionary) -> void: resolved.append(id))
	ctrl.warning_cleared.connect(func(id: String, reason: String) -> void: cleared.append([id, reason]))

	# Same early stop as the abort case: one resolve, not whatever three seconds of brain produces.
	var t: float = 0.0
	while t < 3.0 and resolved.is_empty():
		_tick(w, STEP)
		t += STEP

	_check("normal: skill_resolved carries a real skill id", resolved.size() >= 1 and not str(resolved[0]).is_empty()
		and str(resolved[0]) != "<null>", str(resolved))
	if resolved.is_empty():
		return
	var done_id: String = str(resolved[0])
	var reasons: Array = []
	for c: Array in cleared:
		if str(c[0]) == done_id:
			reasons.append(str(c[1]))
	_check("normal: that skill's warning cleared with 'resolved'", reasons.has("resolved"),
		"%s for '%s'" % [str(reasons), done_id])
