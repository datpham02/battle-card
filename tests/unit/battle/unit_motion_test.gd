extends SceneTree
## Unit motion pass (2026-11-13, production/qa/evidence/unit-motion/audit.md): UnitMotion profiles and pose math are
## pure and whole-pixel (squash never lifts a band, hover never sinks below the feet), every shipped sheet has a
## profile, and the layer applies them: the idle breathes per unit, a step anticipates / leans / hops / lands and
## settles while the drawn feet keep the old glide contract, a hit interrupts any pose at once, reduce motion turns
## it all off, and ticking allocates no objects.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_motion_test.gd

const MAX_FRAMES: int = 600
const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_profiles_resolve()
	test_every_sheet_has_a_profile()
	test_idle_pose_breathes_in_whole_pixels()
	test_hover_stays_above_the_feet()
	test_move_pose_anticipates_leans_and_hops()
	test_settle_pose_lands_and_settles()
	test_heavy_and_agile_differ()
	test_band_split_bounds()
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
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
	units.advance(3.0)
	test_layer_profiles(units)
	test_layer_idle_varies(units)
	test_layer_step_settles(units, combat)
	test_layer_hit_interrupts(units, combat)
	test_layer_reduce_motion(units)
	test_layer_no_object_growth(units)
	_finish()


func test_profiles_resolve() -> void:
	var data := {"archetypes": {"default": {"hop_px": 1, "breath_sec": 2.0}, "heavy": {"hop_px": 0}},
		"units": {"golem": "heavy", "odd": {"archetype": "heavy", "breath_sec": 5.0}, "bad": "nope"}}
	var g := UnitMotion.from_entry(data, "golem")
	var o := UnitMotion.from_entry(data, "odd")
	var b := UnitMotion.from_entry(data, "bad")
	var u := UnitMotion.from_entry(data, "unlisted")
	_check("test_archetype_applies", g.archetype == "heavy" and g.hop_px == 0 and is_equal_approx(g.breath_sec, 2.0))
	_check("test_override_applies", o.archetype == "heavy" and is_equal_approx(o.breath_sec, 5.0) and o.hop_px == 0)
	_check("test_unknown_archetype_is_default", b.archetype == "default" and b.hop_px == 1)
	_check("test_unlisted_id_is_default", u.archetype == "default")
	_check("test_phase_is_stable_and_bounded", UnitMotion.phase_of("x", 0) == UnitMotion.phase_of("x", 0)
		and UnitMotion.phase_of("x", 0) >= 0.0 and UnitMotion.phase_of("x", 0) < 1.0)


func test_every_sheet_has_a_profile() -> void:
	var missing: Array[String] = []
	var dir := DirAccess.open("res://assets/art/units")
	for f: String in dir.get_files():
		if f.begins_with("unit_") and f.ends_with("_sheet.json"):
			var id: String = f.trim_prefix("unit_").trim_suffix("_sheet.json")
			if UnitMotion.for_unit(id).archetype == UnitMotion.DEFAULT_ARCHETYPE:
				missing.append(id)
	_check("test_every_sheet_has_a_profile", missing.is_empty(), str(missing))


func test_idle_pose_breathes_in_whole_pixels() -> void:
	var m := UnitMotion.for_unit("goblin_scout")
	var seen: Dictionary = {}
	var ok: bool = true
	for i: int in 200:
		var p: Vector4i = m.idle_pose(i * 0.025, 1)
		ok = ok and p.w >= 0 and p.w <= m.breath_px and p.y == 0 and absi(p.z) <= m.sway_px
		seen[p.w] = true
	_check("test_idle_squash_bounded", ok)
	_check("test_idle_breathes", seen.has(0) and seen.has(m.breath_px), str(seen.keys()))
	# Two units do not breathe in step.
	var a := UnitMotion.for_unit("goblin_scout")
	var b := UnitMotion.for_unit("dire_wolf")
	var differ: bool = false
	for i: int in 120:
		if a.idle_pose(i * 0.05, 1) != b.idle_pose(i * 0.05, 1):
			differ = true
			break
	_check("test_idle_not_in_lockstep", differ)


func test_hover_stays_above_the_feet() -> void:
	var m := UnitMotion.for_unit("ghost")
	var lo: int = 0
	var hi: int = -99
	for i: int in 200:
		var p: Vector4i = m.idle_pose(i * 0.02, -1)
		lo = mini(lo, p.y)
		hi = maxi(hi, p.y)
	_check("test_hover_bobs", lo == -m.hover_px and hi == 0, "%d..%d" % [lo, hi])


func test_move_pose_anticipates_leans_and_hops() -> void:
	var m := UnitMotion.for_unit("goblin_scout")
	var right := Vector2i(1, 0)
	var start: Vector4i = m.move_pose(m.anticipate * 0.5, right)
	var mid: Vector4i = m.move_pose(0.5, right)
	var end: Vector4i = m.move_pose(1.0, right)
	_check("test_move_anticipates", start.z < 0 and start.w >= 1, str(start))
	_check("test_move_leans_into_the_move", mid.z == m.lean_px, str(mid))
	_check("test_move_hops", mid.y == -m.hop_px and end.y == 0, "%s %s" % [mid, end])
	var left: Vector4i = m.move_pose(0.5, Vector2i(-1, 0))
	_check("test_move_lean_follows_direction", left.z == -m.lean_px, str(left))
	var up: Vector4i = m.move_pose(0.5, Vector2i(0, -1))
	_check("test_vertical_move_no_lean", up.z == 0, str(up))


func test_settle_pose_lands_and_settles() -> void:
	var m := UnitMotion.for_unit("goblin_scout")
	var landed: Vector4i = m.settle_pose(0.0, Vector2i(1, 0))
	var done: Vector4i = m.settle_pose(1.0, Vector2i(1, 0))
	_check("test_settle_squashes_on_landing", landed.w == m.land_squash_px and landed.z == m.lean_px and landed.x == m.overshoot_px, str(landed))
	_check("test_settle_ends_at_rest", done == Vector4i.ZERO, str(done))


func test_heavy_and_agile_differ() -> void:
	var heavy := UnitMotion.for_unit("ogre_king")
	var agile := UnitMotion.for_unit("goblin_scout")
	_check("test_heavy_is_heavy", heavy.archetype == "heavy" and heavy.hop_px == 0 and heavy.idle_speed < 1.0
		and heavy.slide_scale > 1.0 and heavy.land_squash_px > agile.land_squash_px)
	_check("test_agile_is_light", agile.archetype == "agile" and agile.hop_px > heavy.hop_px and agile.idle_speed > 1.0
		and agile.slide_scale < 1.0 and agile.breath_sec < heavy.breath_sec)
	_check("test_windup_coils_away_from_the_foe", agile.windup_pose(-1).z > 0 and agile.windup_pose(1).z < 0)


func test_band_split_bounds() -> void:
	var s: Vector2i = UnitLayer.band_split(52, 46, Vector2i(19, 31))
	_check("test_band_split_order", s.x >= 0 and s.x <= s.y and s.y <= 52 and s == Vector2i(21, 33), str(s))
	var t: Vector2i = UnitLayer.band_split(10, 99, Vector2i(50, 80))
	_check("test_band_split_clamped", t.x >= 0 and t.x <= t.y and t.y <= 10, str(t))


func test_layer_profiles(units: UnitLayer) -> void:
	_check("test_layer_player_profile", units.motion_of(PLAYER).archetype == "hero", units.motion_of(PLAYER).archetype)
	var enemy_id: String = units.get_unit_id(ENEMY)
	_check("test_layer_enemy_profile", units.motion_of(ENEMY) == UnitMotion.for_unit(enemy_id), enemy_id)


func test_layer_idle_varies(units: UnitLayer) -> void:
	var poses: Dictionary = {}
	for _i: int in 80:
		units.advance(0.05)
		if units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE:
			poses[units.unit_pose(PLAYER)] = true
	_check("test_layer_idle_pose_changes", poses.size() >= 2, str(poses.keys()))


func test_layer_step_settles(units: UnitLayer, combat: CombatView) -> void:
	var state: CombatState = combat.get_state()
	var next: Vector2i = _neighbour(state)
	_check("test_layer_neighbour", next != state.player_cell)
	units.advance(0.0)
	var from: Vector2i = units.unit_feet_art(PLAYER)
	state.set_player_cell(next)
	var to: Vector2i = units.feet_art_of_cell(next)
	units.advance(0.0)
	_check("test_layer_glide_starts_at_old_feet", units.unit_feet_art(PLAYER) == from)
	var dir: int = signi(to.x - from.x)
	var first: Vector4i = units.unit_pose(PLAYER)
	_check("test_layer_step_anticipates", signi(first.z) == -dir, str(first))
	var slide_sec: float = units.get_slide_left(PLAYER)
	units.advance(slide_sec * 0.5)
	var mid: Vector4i = units.unit_pose(PLAYER)
	_check("test_layer_step_leans_and_hops", signi(mid.z) == dir and mid.y < 0, str(mid))
	units.advance(slide_sec * 0.5 + 0.001)
	_check("test_layer_glide_lands_exactly", units.unit_feet_art(PLAYER) == to and units.get_slide_left(PLAYER) == 0.0)
	_check("test_layer_settle_started", units.get_settle_left(PLAYER) > 0.0 and units.unit_pose(PLAYER).w >= 1, str(units.unit_pose(PLAYER)))
	units.advance(1.0)
	_check("test_layer_settle_ends", units.get_settle_left(PLAYER) == 0.0)


func test_layer_hit_interrupts(units: UnitLayer, combat: CombatView) -> void:
	var state: CombatState = combat.get_state()
	units.advance(1.0)
	state.set_player_cell(_neighbour(state))
	units.advance(0.0)
	units.advance(0.03)
	_check("test_layer_gliding_before_hit", units.get_slide_left(PLAYER) > 0.0)
	state.damaged.emit(PLAYER, 3.0)
	units.advance(0.0)
	units.advance(0.0)
	var p: Vector4i = units.unit_pose(PLAYER)
	_check("test_layer_hit_overrides_move", units.get_current_clip(PLAYER) == UnitLayer.CLIP_HIT and p.y == 0 and p.w == 0, "%s %s" % [units.get_current_clip(PLAYER), p])
	units.advance(1.0)


func test_layer_reduce_motion(units: UnitLayer) -> void:
	units.set_reduce_motion(true)
	var ok: bool = true
	for _i: int in 40:
		units.advance(0.05)
		ok = ok and units.unit_pose(PLAYER) == Vector4i.ZERO and units.unit_pose(ENEMY) == Vector4i.ZERO
	_check("test_layer_reduce_motion_no_pose", ok)
	units.set_reduce_motion(false)


func test_layer_no_object_growth(units: UnitLayer) -> void:
	units.advance(0.1)
	var before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	for _i: int in 300:
		units.advance(1.0 / 60.0)
		units.unit_pose(PLAYER)
		units.unit_pose(ENEMY)
	var after: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	_check("test_layer_no_object_growth", after <= before, "%d -> %d" % [before, after])


func _neighbour(state: CombatState) -> Vector2i:
	for dx: int in [1, -1]:
		var cell: Vector2i = state.player_cell + Vector2i(dx, 0)
		if state.grid.is_player_cell(cell) and not state.is_enemy_at(cell):
			return cell
	return state.player_cell


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
