extends SceneTree
## 2026-11-03 (design/quick-specs/doi-hinh-rung-suong-2026-11-03.md §6, R1): three small pattern-brain additions.
## - `pattern.variants`: one skill, several cell shapes (Goblin Warlock's L / T / S); the planner offers plans of every
##   variant (tagged `variant`), so the seeded plan pick draws among the shapes; a variant that cannot fit leaves the
##   others; variants only with on_player / near_player anchors (refused elsewhere).
## - `effects.haste` {cooldown_mult, sec} on a self skill (Wolf Alpha's howl): while it lasts every finished skill's
##   cooldown is multiplied; warning_sec is never touched.
## - `interrupt_stun_sec` (skill): an interrupt (the player's cast hits the enemy in WINDUP / WARNING) also stuns the
##   enemy that long, and the self skill's effect (the haste) is never applied.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_variants_haste_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const STEP: float = 0.05
const SHAPE_L: Array = [[0, 0], [0, 1], [0, 2], [1, 2]]
const SHAPE_T: Array = [[0, 0], [1, 0], [2, 0], [1, 1]]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_variants_parse_and_refuse_row_anchor()
	test_planner_offers_every_variant()
	test_variant_that_cannot_fit_leaves_the_others()
	test_haste_halves_cooldown_not_warning()
	test_interrupt_stuns_and_skips_haste()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> Dictionary:
	var skills: Dictionary = Fx.skills()
	skills["shape"] = {"pattern": {"variants": [SHAPE_L, SHAPE_T], "anchor": "on_player"}, "windup_sec": 0.5, "warning_sec": 1.4,
		"delivery": Fx.DM, "effects": {"damage": 16}, "recovery_sec": 0.6, "cooldown_sec": 5.0}
	skills["howl"] = {"kind": "self", "windup_sec": 1.4, "delivery": Fx.DM, "interruptible": true, "interrupt_stun_sec": 1.0,
		"effects": {"haste": {"cooldown_mult": 0.5, "sec": 6.0}}, "recovery_sec": 0.2, "cooldown_sec": 12.0}
	skills["bite"] = {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.3, "warning_sec": 0.9,
		"delivery": Fx.DM, "effects": {"damage": 10}, "recovery_sec": 0.2, "cooldown_sec": 4.0}
	return {"version": 1, "skills": skills, "enemies": {
		"shaper": {"skills": ["shape"]},
		"howler": {"skills": ["howl", "bite"]},
	}}


func _cfg() -> EnemySkillsConfig:
	return EnemySkillsConfig.from_dictionary(_data())


func _tick(w: Dictionary, sec: float) -> void:
	var left: float = sec
	while left > 0.000001:
		var d: float = minf(STEP, left)
		(w["status"] as StatusEffects).tick(d, w["state"] as CombatState)
		(w["mover"] as UnitMover).tick(d)
		(w["ctrl"] as PatternController).tick(d)
		left -= d


func _until(w: Dictionary, pred: Callable, limit: float) -> bool:
	var t: float = 0.0
	while t < limit:
		if pred.call():
			return true
		_tick(w, STEP)
		t += STEP
	return bool(pred.call())


func test_variants_parse_and_refuse_row_anchor() -> void:
	var cfg: EnemySkillsConfig = _cfg()
	_check("variants: fixture loads without problems", cfg.problems.is_empty(), str(cfg.problems))
	var pattern: Dictionary = (cfg.skills.get("shape", {}) as Dictionary).get("pattern", {}) as Dictionary
	_check("variants: both shapes parsed as cell lists", (pattern.get("variants", []) as Array).size() == 2
		and ((pattern["variants"] as Array)[1] as Array).has(Vector2i(1, 1)))
	var bad: Dictionary = _data()
	(bad["skills"] as Dictionary)["row_shape"] = {"pattern": {"variants": [SHAPE_L], "anchor": "row_of_player"}, "warning_sec": 1.0,
		"delivery": Fx.DM, "effects": {"damage": 1}, "cooldown_sec": 1.0}
	var refused: EnemySkillsConfig = EnemySkillsConfig.from_dictionary(bad)
	_check("variants: refused with a row anchor", not refused.skills.has("row_shape")
		and refused.problems.any(func(p: String) -> bool: return p.contains("row_shape") and p.contains("variants")), str(refused.problems))


func test_planner_offers_every_variant() -> void:
	var cfg: EnemySkillsConfig = _cfg()
	var grid: BoardGrid = BoardGrid.new(6, 4)
	var player: Vector2i = Vector2i(2, 1)
	var ctx: Dictionary = {"grid": grid, "player_cell": player, "enemy_cell": Vector2i(grid.side_cols + 1, 1)}
	var plans: Array[Dictionary] = PatternPlanner.plans(cfg.skills["shape"] as Dictionary, ctx)
	var seen: Dictionary = {}
	for p: Dictionary in plans:
		seen[int(p.get("variant", -1))] = true
		_check("variants: plan %s covers 4 cells" % str(p["cells"]), (p["cells"] as Array).size() == 4)
	_check("variants: plans of both shapes offered", seen.has(0) and seen.has(1), str(seen.keys()))


func test_variant_that_cannot_fit_leaves_the_others() -> void:
	var cfg: EnemySkillsConfig = _cfg()
	# 3 rows x 2 columns: the L (3 tall, rotation 0) fits; the T (3 wide) cannot.
	var grid: BoardGrid = BoardGrid.new(2, 3)
	var player: Vector2i = Vector2i(1, 0)
	var ctx: Dictionary = {"grid": grid, "player_cell": player, "enemy_cell": Vector2i(grid.side_cols, 0)}
	var plans: Array[Dictionary] = PatternPlanner.plans(cfg.skills["shape"] as Dictionary, ctx)
	_check("variants: the L still plans when the T cannot fit", not plans.is_empty()
		and plans.all(func(p: Dictionary) -> bool: return int(p.get("variant", -1)) == 0), "plans=%d" % plans.size())


func test_haste_halves_cooldown_not_warning() -> void:
	var cfg: EnemySkillsConfig = _cfg()
	var w: Dictionary = Fx.world(BoardGrid.new(4, 3), cfg, "howler", 7, 200.0)
	var ctrl: PatternController = w["ctrl"]
	var howled: bool = _until(w, func() -> bool:
		return ctrl.event_log.any(func(e: Dictionary) -> bool: return str(e.get("skill", "")) == "howl" and str(e.get("event", "")) == "resolve"), 20.0)
	_check("haste: the howl resolves", howled)
	_check("haste: lasts 6 s after the howl", ctrl.haste_left() > 5.5 and ctrl.haste_left() <= 6.0 + 0.0001, "left=%.2f" % ctrl.haste_left())
	var bit: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.WARNING and str(ctrl.get_current_skill().get("id", "")) == "bite", 6.0)
	_check("haste: the bite comes during the haste", bit)
	_check("haste: the bite's warning stays 0.9 s", is_equal_approx(ctrl.get_current_skill().get("warning_sec", 0.0), 0.9))
	_until(w, func() -> bool: return ctrl.cooldown_left("bite") > 0.0, 3.0)
	_check("haste: the bite's cooldown is 4.0 x 0.5", ctrl.cooldown_left("bite") <= 2.0 + 0.0001 and ctrl.cooldown_left("bite") > 1.8,
		"cd=%.2f" % ctrl.cooldown_left("bite"))
	_tick(w, 6.5)
	_check("haste: over after 6 s (the howl does not shorten its own cooldown)", ctrl.haste_left() <= 0.0,
		"left=%.2f howl_cd=%.2f" % [ctrl.haste_left(), ctrl.cooldown_left("howl")])


func test_interrupt_stuns_and_skips_haste() -> void:
	var cfg: EnemySkillsConfig = _cfg()
	var w: Dictionary = Fx.world(BoardGrid.new(4, 3), cfg, "howler", 7, 200.0)
	var ctrl: PatternController = w["ctrl"]
	var winding: bool = _until(w, func() -> bool:
		return ctrl.get_stage() == PatternController.Stage.WINDUP and str(ctrl.get_current_skill().get("id", "")) == "howl", 20.0)
	_check("interrupt: the howl winds up", winding)
	_check("interrupt: a hit during the howl cancels it", ctrl.on_enemy_hit())
	_check("interrupt: the enemy is stunned for 1.0 s", ctrl.get_stage() == PatternController.Stage.STUNNED)
	_tick(w, 0.9)
	_check("interrupt: still stunned at 0.9 s", ctrl.get_stage() == PatternController.Stage.STUNNED)
	_tick(w, 0.2)
	_check("interrupt: stun over after 1.0 s", ctrl.get_stage() != PatternController.Stage.STUNNED)
	_check("interrupt: no haste from a cancelled howl", ctrl.haste_left() <= 0.0)
