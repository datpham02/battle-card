extends SceneTree
## 2026-11-04 (user: "Viền Ngà nhấp nháy"): while the Wolf Alpha winds up its howl (an interruptible self skill with
## interrupt_stun_sec, the designed interrupt window) its cell gets a BLINKING ivory frame ("hit it now"), distinct
## from the solid ivory frame that means "cannot be interrupted" (Witch / Warlock heavy skills, Guard). Reduce motion:
## a steady dashed frame instead of the blink. The solid outline never carries the howl.
## Run: godot --headless --path . -s res://tests/unit/battle/interrupt_tell_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const FloorLayerScript := preload("res://src/battle/floor_layer.gd")
const STEP: float = 0.05

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	test_howl_windup_blinks_not_solid(cfg)
	test_uninterruptible_stays_solid(cfg)
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


func test_howl_windup_blinks_not_solid(cfg: EnemySkillsConfig) -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "wolf_alpha", 3, 300.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	while t < 40.0 and not (ctrl.get_stage() == PatternController.Stage.WINDUP and str(ctrl.get_current_skill().get("id", "")) == "alpha_howl"):
		_tick(w, STEP)
		t += STEP
	_check("test_howl_winds_up", ctrl.get_stage() == PatternController.Stage.WINDUP and str(ctrl.get_current_skill().get("id", "")) == "alpha_howl")
	_check("test_interrupt_tell_true_during_howl", ctrl.interrupt_tell())
	var on: Dictionary = FloorLayerScript.pattern_extras_state(ctrl, w["status"], state, 0.0, false)
	var off: Dictionary = FloorLayerScript.pattern_extras_state(ctrl, w["status"], state, FloorLayerScript.INTERRUPT_BLINK_SEC * 1.5, false)
	var calm: Dictionary = FloorLayerScript.pattern_extras_state(ctrl, w["status"], state, FloorLayerScript.INTERRUPT_BLINK_SEC * 1.5, true)
	var blink_on: Dictionary = on.get("blink", {}) as Dictionary
	_check("test_blink_frames_the_wolf_cell", (blink_on.get("cells", []) as Array).has(state.enemy_cell), str(blink_on))
	_check("test_blink_on_then_off", bool(blink_on.get("on", false)) and not bool((off.get("blink", {}) as Dictionary).get("on", true)))
	var calm_blink: Dictionary = calm.get("blink", {}) as Dictionary
	_check("test_reduce_motion_steady_dashed", bool(calm_blink.get("on", false)) and bool(calm_blink.get("dashed", false)))
	_check("test_howl_not_in_the_solid_outline", not (on.get("outline", []) as Array).has(state.enemy_cell), str(on.get("outline", [])))
	_check("test_hit_during_howl_interrupts", ctrl.on_enemy_hit())
	var after: Dictionary = FloorLayerScript.pattern_extras_state(ctrl, w["status"], state, 0.0, false)
	_check("test_no_blink_after_interrupt", (after.get("blink", {}) as Dictionary).is_empty() and not ctrl.interrupt_tell())


func test_uninterruptible_stays_solid(cfg: EnemySkillsConfig) -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "mistbriar_matron", 4, 300.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	# Guard (wreath) frames solid; never a blink: the Matron's skills have no interrupt window.
	var blinked: bool = false
	var t: float = 0.0
	while t < 30.0:
		_tick(w, STEP)
		t += STEP
		if state.enemy_hp > state.enemy_max_hp * 0.4:
			state.damage_enemy(state.enemy_hp - state.enemy_max_hp * 0.4)
		if not (FloorLayerScript.pattern_extras_state(ctrl, w["status"], state, 0.0, false).get("blink", {}) as Dictionary).is_empty():
			blinked = true
	_check("test_skills_without_interrupt_window_never_blink", not blinked)
