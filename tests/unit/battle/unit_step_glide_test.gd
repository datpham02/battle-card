extends SceneTree
## Step glide (2026-11-02, user: "animation move của kiếm sĩ ... đang hơi cứng", OSFE dash): a unit that changes cell
## glides from where it was drawn to its new feet over hit_feel.step_slide_sec with an ease-out, instead of snapping;
## the drawn feet (UnitLayer.unit_feet_art, which the HP plate follows) start at the old feet, sit strictly between the
## two mid-glide and land exactly on the new feet; reduce motion snaps as before. UnitLayer.slide_offset is pure.
## The layer's own _process is stopped so only the explicit advance() calls move its clocks.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_step_glide_test.gd

const MAX_FRAMES: int = 600

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_slide_offset_is_pure_and_eases_out()
	test_step_clip_for_each_direction()
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	# The shipped hero, so the real sheet (with its dash clips) is drawn.
	flow.set_character("kiem_si")
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView if battle != null else null
	var canvas := battle.get_child(0) as BattleCanvas if battle != null else null
	_check("test_battle_spawned", combat != null and canvas != null and canvas.get_unit_layer() != null)
	if combat == null or canvas == null or canvas.get_unit_layer() == null:
		_finish()
		return
	combat.get_boss().set_active(false)
	var units: UnitLayer = canvas.get_unit_layer()
	units.set_process(false)
	units.set_reduce_motion(false)
	test_match_start_draws_into_the_guard(units, combat)
	test_step_glides_then_lands(units, combat)
	test_step_plays_the_directional_clip(units, combat)
	test_reduce_motion_snaps(units, combat)
	_finish()


func test_slide_offset_is_pure_and_eases_out() -> void:
	var from := Vector2i(100, 50)
	var to := Vector2i(140, 50)
	_check("test_slide_offset_full_gap_at_start", UnitLayer.slide_offset(from, to, 0.1, 0.1) == Vector2i(-40, 0))
	_check("test_slide_offset_zero_at_end", UnitLayer.slide_offset(from, to, 0.0, 0.1) == Vector2i.ZERO)
	var half: Vector2i = UnitLayer.slide_offset(from, to, 0.05, 0.1)
	# Ease-out: past the halfway point at half time (cubic: 1/8 of the gap left).
	_check("test_slide_offset_eases_out", half.x > -20 and half.x < 0, str(half))
	_check("test_slide_offset_no_glide_without_time", UnitLayer.slide_offset(from, to, 0.05, 0.0) == Vector2i.ZERO)


# 2026-11-02 guard stance (user: the knight holds the sword ready the whole battle): a freshly bound match plays the
# hero's `draw` clip once, the idle waits for it, then the guard idle loops.
func test_match_start_draws_into_the_guard(units: UnitLayer, combat: CombatView) -> void:
	var side: int = CombatState.Side.PLAYER
	units.setup(combat)
	units.set_process(false)
	units.set_reduce_motion(false)
	var anim: UnitAnimator = units.get_animator(side)
	_check("test_bind_starts_the_draw", anim != null and anim.current_clip() == UnitLayer.CLIP_DRAW, anim.current_clip() if anim != null else "-")
	units.advance(0.2)
	_check("test_idle_waits_for_the_draw", units.get_animator(side).current_clip() == UnitLayer.CLIP_DRAW)
	units.advance(1.0)
	units.advance(0.01)
	_check("test_guard_idle_after_the_draw", units.get_animator(side).current_clip() == UnitLayer.CLIP_IDLE, units.get_animator(side).current_clip())


# 2026-11-02 (user: "tiến có animation tiến, lùi có animation lùi, lên xuống cũng vậy").
func test_step_clip_for_each_direction() -> void:
	var c := Vector2i(2, 1)
	_check("test_step_clip_forward_for_a_right_facer", UnitLayer.step_clip_for(c, c + Vector2i(1, 0), true) == UnitLayer.CLIP_STEP_FORWARD)
	_check("test_step_clip_back_for_a_right_facer", UnitLayer.step_clip_for(c, c + Vector2i(-1, 0), true) == UnitLayer.CLIP_STEP_BACK)
	_check("test_step_clip_forward_for_a_left_facer", UnitLayer.step_clip_for(c, c + Vector2i(-1, 0), false) == UnitLayer.CLIP_STEP_FORWARD)
	_check("test_step_clip_up_and_down", UnitLayer.step_clip_for(c, c + Vector2i(0, -1), true) == UnitLayer.CLIP_STEP_UP
		and UnitLayer.step_clip_for(c, c + Vector2i(0, 1), true) == UnitLayer.CLIP_STEP_DOWN)


# The hero's sheet has step_forward / step_back / step_up / step_down: each step plays its own clip (a direction
# without one falls back to the plain step clip).
func test_step_plays_the_directional_clip(units: UnitLayer, combat: CombatView) -> void:
	var state: CombatState = combat.get_state()
	var side: int = CombatState.Side.PLAYER
	var sheet: SpriteSheet = units.get_sheet(side)
	_check("test_hero_sheet_has_dash_clips", sheet != null and sheet.has_clip(UnitLayer.CLIP_STEP_FORWARD)
		and sheet.has_clip(UnitLayer.CLIP_STEP_BACK) and sheet.has_clip(UnitLayer.CLIP_STEP_UP) and sheet.has_clip(UnitLayer.CLIP_STEP_DOWN))
	var mover: UnitMover = combat.get_mover()
	for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var to: Vector2i = state.player_cell + dir
		if not state.grid.is_player_cell(to):
			continue
		var want: String = UnitLayer.step_clip_for(state.player_cell, to, true)
		if not sheet.has_clip(want):
			want = UnitLayer.CLIP_STEP
		units.advance(1.0)
		mover.tick(5.0)
		var ok: bool = mover.try_step(dir)
		units.advance(0.0)
		units.advance(0.01)
		var anim: UnitAnimator = units.get_animator(side)
		_check("test_step %s plays %s" % [dir, want], ok and anim != null and anim.current_clip() == want,
			"stepped=%s clip=%s" % [ok, anim.current_clip() if anim != null else "-"])


func test_step_glides_then_lands(units: UnitLayer, combat: CombatView) -> void:
	var state: CombatState = combat.get_state()
	var side: int = CombatState.Side.PLAYER
	var slide_sec: float = float(CastVfx.hit_feel()["step_slide_sec"])
	_check("test_slide_sec_from_data", slide_sec > 0.0, str(slide_sec))
	units.advance(0.0)
	var from: Vector2i = units.unit_feet_art(side)
	var next: Vector2i = _neighbour(state)
	_check("test_neighbour_cell_found", next != state.player_cell, str(next))
	state.set_player_cell(next)
	var to: Vector2i = units.feet_art_of_cell(next)
	units.advance(0.0)
	_check("test_glide_starts_at_the_old_feet", units.unit_feet_art(side) == from and units.get_slide_left(side) > 0.0,
		"%s vs %s" % [units.unit_feet_art(side), from])
	units.advance(slide_sec * 0.5)
	var mid: Vector2i = units.unit_feet_art(side)
	var lo: int = mini(from.x, to.x)
	var hi: int = maxi(from.x, to.x)
	_check("test_glide_mid_is_between", mid.x > lo and mid.x < hi, "%s between %s and %s" % [mid, from, to])
	units.advance(slide_sec)
	_check("test_glide_lands_on_the_new_feet", units.unit_feet_art(side) == to and units.get_slide_left(side) == 0.0,
		"%s vs %s" % [units.unit_feet_art(side), to])


func test_reduce_motion_snaps(units: UnitLayer, combat: CombatView) -> void:
	var state: CombatState = combat.get_state()
	units.set_reduce_motion(true)
	units.advance(0.0)
	var next: Vector2i = _neighbour(state)
	state.set_player_cell(next)
	units.advance(0.0)
	_check("test_reduce_motion_snaps_to_the_new_feet",
		units.unit_feet_art(CombatState.Side.PLAYER) == units.feet_art_of_cell(next) and units.get_slide_left(CombatState.Side.PLAYER) == 0.0)
	units.set_reduce_motion(false)


# A free horizontal neighbour of the player's cell on the player's half.
func _neighbour(state: CombatState) -> Vector2i:
	for dx: int in [1, -1]:
		var cell: Vector2i = state.player_cell + Vector2i(dx, 0)
		if state.grid.is_player_cell(cell) and not state.is_enemy_at(cell):
			return cell
	return state.player_cell


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
