extends SceneTree
## Story 047 Part D: status overlays of UnitLayer (headless). Pure part: UnitLayer.status_kinds_for on a
## real StatusEffects (burn / frost stacks / pin / dead) and UnitLayer.overlay_frame on the shipped packs
## (frozen 100 ms, burn 83 ms, reduce motion). Scene part: the real battle (main.tscn, fast_run fixture,
## as battle_canvas_test) with the enemy half burning: active kinds, the clock fed by
## CombatView.scaled_delta (stops under freeze_time and a paused battle), a dead enemy wears nothing.
## Headless, the SubViewport may never reach _draw; the draw signal count is printed, not asserted.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_status_overlay_test.gd

const MAX_FRAMES: int = 600
const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY
## The 3x3 state of status_test.gd: player at (1,1), enemy at (4,1).
const PLAYER_CELL: Vector2i = Vector2i(1, 1)
const ENEMY_CELL: Vector2i = Vector2i(4, 1)
## Burn fixture (duration, tick, damage per tick): long and harmless so nobody dies mid-test.
const BURN_SEC: float = 30.0
const BURN_TICK_SEC: float = 0.5
const BURN_DAMAGE: float = 0.0
## Keyword fixture: Ran x1.5 up to 3, Han bursts at 3 stacks for 10.
const FRAGILE_MULT: float = 1.5
const FRAGILE_MAX: int = 3
const FROST_BURST_STACKS: int = 3
const FROST_BURST_DAMAGE: float = 10.0
const PIN_SEC: float = 1.2
## Frame times of the shipped packs (read from their manifests; the point of the frame tests).
const FROZEN_FRAME_MS: int = 100
const BURN_FRAME_MS: int = 83

var fails: int = 0
var _draw_count: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_status_kinds_burn_only_for_the_unit_on_the_burning_cell()
	test_status_kinds_chill_from_frost_stacks()
	test_status_kinds_frozen_replaces_chill_while_pinned()
	test_status_kinds_frozen_falls_back_to_chill_when_the_pin_ends()
	test_status_kinds_burn_and_frozen_together_in_draw_order()
	test_status_kinds_frost_burst_clears_chill()
	test_status_kinds_empty_when_dead_or_without_status()
	test_frame_kind_hero_for_player_goblin_for_enemy()
	test_all_six_packs_load_with_behind_and_front_textures()
	test_overlay_frame_frozen_advances_every_100_ms_and_wraps()
	test_overlay_frame_burn_advances_every_83_ms_and_wraps()
	test_overlay_frame_matches_vfx_pack_frame_at_over_a_sweep()
	test_overlay_frame_reduce_motion_holds_frame_zero()
	test_overlay_frame_null_pack_is_zero()
	await test_battle_unit_layer_with_a_burning_enemy()
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(fails)


func _make_state() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, PLAYER_CELL, ENEMY_CELL)


func _make_status() -> StatusEffects:
	var fx := StatusEffects.new()
	fx.configure_keywords(FRAGILE_MULT, FRAGILE_MAX, FROST_BURST_STACKS, FROST_BURST_DAMAGE)
	return fx


func test_status_kinds_burn_only_for_the_unit_on_the_burning_cell() -> void:
	var fx := _make_status()
	fx.ignite([ENEMY_CELL] as Array[Vector2i], BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	_check("test_enemy_on_burning_cell_gets_burn", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL) == ["burn"])
	_check("test_player_off_the_burning_cell_gets_nothing", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL).is_empty())


func test_status_kinds_chill_from_frost_stacks() -> void:
	var fx := _make_status()
	fx.apply_frost(PLAYER, 1)
	_check("test_one_frost_stack_is_chill", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL) == ["chill"])
	_check("test_frost_on_player_leaves_enemy_clean", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL).is_empty())
	fx.apply_frost(PLAYER, 1)
	_check("test_two_frost_stacks_still_chill_not_frozen", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL) == ["chill"])


func test_status_kinds_frozen_replaces_chill_while_pinned() -> void:
	var fx := _make_status()
	fx.apply_frost(ENEMY, 2)
	fx.pin(ENEMY, PIN_SEC)
	var kinds: Array[String] = UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL)
	_check("test_pin_with_frost_stacks_is_frozen_only_got_%s" % [kinds], kinds == ["frozen"])
	_check("test_never_frozen_and_chill_together", not (kinds.has("frozen") and kinds.has("chill")))
	var fx2 := _make_status()
	fx2.pin(PLAYER, PIN_SEC)
	_check("test_pin_without_frost_stacks_is_frozen", UnitLayer.status_kinds_for(fx2, PLAYER, PLAYER_CELL) == ["frozen"])


func test_status_kinds_frozen_falls_back_to_chill_when_the_pin_ends() -> void:
	var fx := _make_status()
	var state := _make_state()
	fx.apply_frost(ENEMY, 1)
	fx.pin(ENEMY, PIN_SEC)
	fx.tick(PIN_SEC * 0.5, state)
	_check("test_half_way_through_the_pin_still_frozen", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL) == ["frozen"])
	fx.tick(PIN_SEC, state)
	_check("test_after_the_pin_the_stacks_show_as_chill", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL) == ["chill"])


func test_status_kinds_burn_and_frozen_together_in_draw_order() -> void:
	var fx := _make_status()
	fx.pin(ENEMY, PIN_SEC)
	fx.ignite([ENEMY_CELL] as Array[Vector2i], BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	_check("test_burn_then_frozen", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL) == ["burn", "frozen"])
	fx.clear()
	fx.apply_frost(ENEMY, 1)
	fx.ignite([ENEMY_CELL] as Array[Vector2i], BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	_check("test_burn_then_chill", UnitLayer.status_kinds_for(fx, ENEMY, ENEMY_CELL) == ["burn", "chill"])


func test_status_kinds_frost_burst_clears_chill() -> void:
	var fx := _make_status()
	fx.apply_frost(PLAYER, FROST_BURST_STACKS - 1)
	_check("test_below_burst_is_chill", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL) == ["chill"])
	var burst: float = fx.apply_frost(PLAYER, 1)
	_check("test_burst_happened", burst == FROST_BURST_DAMAGE)
	_check("test_after_the_burst_no_chill", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL).is_empty())


func test_status_kinds_empty_when_dead_or_without_status() -> void:
	var fx := _make_status()
	fx.pin(PLAYER, PIN_SEC)
	fx.ignite([PLAYER_CELL] as Array[Vector2i], BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	_check("test_alive_wears_burn_and_frozen", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL, true).size() == 2)
	_check("test_dead_wears_nothing", UnitLayer.status_kinds_for(fx, PLAYER, PLAYER_CELL, false).is_empty())
	_check("test_null_status_wears_nothing", UnitLayer.status_kinds_for(null, PLAYER, PLAYER_CELL).is_empty())


func test_frame_kind_hero_for_player_goblin_for_enemy() -> void:
	_check("test_player_uses_hero_packs", UnitLayer.frame_kind_of(PLAYER) == "hero")
	_check("test_enemy_uses_goblin_packs", UnitLayer.frame_kind_of(ENEMY) == "goblin")


func test_all_six_packs_load_with_behind_and_front_textures() -> void:
	for kind: String in ["burn", "frozen", "chill"]:
		for frame_kind: String in ["hero", "goblin"]:
			var pack: VfxPack = StatusPacks.pack(kind, frame_kind)
			_check("test_pack_%s_%s_loads" % [kind, frame_kind], pack != null)
			if pack == null:
				continue
			var behind: Dictionary = pack.clip(UnitLayer.CLIP_BEHIND)
			var front: Dictionary = pack.clip(UnitLayer.CLIP_FRONT)
			_check("test_pack_%s_%s_has_behind_and_front_textures" % [kind, frame_kind], not behind.is_empty() and not front.is_empty() and behind["texture"] != null and front["texture"] != null)
			_check("test_pack_%s_%s_behind_and_front_same_frame_count" % [kind, frame_kind], int(behind.get("frames", 0)) == int(front.get("frames", -1)))


func test_overlay_frame_frozen_advances_every_100_ms_and_wraps() -> void:
	var pack: VfxPack = StatusPacks.pack("frozen", "goblin")
	if pack == null:
		_check("test_frozen_goblin_pack_present", false)
		return
	_check("test_frozen_pack_frame_ms_is_%d_got_%d" % [FROZEN_FRAME_MS, pack.frame_ms()], pack.frame_ms() == FROZEN_FRAME_MS)
	var frames: int = int(pack.clip(UnitLayer.CLIP_FRONT).get("frames", 0))
	_check("test_frozen_front_has_frames", frames > 1)
	_check("test_frozen_frame_0_at_start", UnitLayer.overlay_frame(0.0, pack) == 0)
	_check("test_frozen_frame_0_before_100_ms", UnitLayer.overlay_frame(0.05, pack) == 0)
	_check("test_frozen_frame_1_at_100_ms", UnitLayer.overlay_frame(0.1, pack) == 1)
	_check("test_frozen_frame_5_at_550_ms", UnitLayer.overlay_frame(0.55, pack) == 5)
	var last_sec: float = float(frames - 1) * FROZEN_FRAME_MS / 1000.0 + 0.05
	_check("test_frozen_last_frame_before_the_wrap", UnitLayer.overlay_frame(last_sec, pack) == frames - 1)
	var wrap_sec: float = float(frames) * FROZEN_FRAME_MS / 1000.0 + 0.05
	_check("test_frozen_wraps_to_frame_0_(loop)", pack.is_loop() and UnitLayer.overlay_frame(wrap_sec, pack) == 0)


func test_overlay_frame_burn_advances_every_83_ms_and_wraps() -> void:
	var pack: VfxPack = StatusPacks.pack("burn", "goblin")
	if pack == null:
		_check("test_burn_goblin_pack_present", false)
		return
	_check("test_burn_pack_frame_ms_is_%d_got_%d" % [BURN_FRAME_MS, pack.frame_ms()], pack.frame_ms() == BURN_FRAME_MS)
	var frames: int = int(pack.clip(UnitLayer.CLIP_FRONT).get("frames", 0))
	_check("test_burn_frame_0_before_83_ms", UnitLayer.overlay_frame(0.08, pack) == 0)
	_check("test_burn_frame_1_at_90_ms", UnitLayer.overlay_frame(0.09, pack) == 1)
	_check("test_burn_frame_6_at_500_ms", UnitLayer.overlay_frame(0.5, pack) == 6)
	var wrap_sec: float = float(frames) * BURN_FRAME_MS / 1000.0 + 0.01
	_check("test_burn_wraps_to_frame_0_after_%d_frames" % frames, UnitLayer.overlay_frame(wrap_sec, pack) == 0)
	# A burn pack and a frozen pack at the same elapsed time are on different frames (83 vs 100 ms).
	var frozen: VfxPack = StatusPacks.pack("frozen", "goblin")
	_check("test_burn_runs_faster_than_frozen_at_1_s", frozen != null and UnitLayer.overlay_frame(0.95, pack) > UnitLayer.overlay_frame(0.95, frozen))


func test_overlay_frame_matches_vfx_pack_frame_at_over_a_sweep() -> void:
	var all_ok: bool = true
	for kind: String in ["burn", "frozen", "chill"]:
		var pack: VfxPack = StatusPacks.pack(kind, "hero")
		if pack == null:
			all_ok = false
			continue
		var clip_data: Dictionary = pack.clip(UnitLayer.CLIP_FRONT)
		for i: int in 40:
			var t: float = float(i) * 0.037
			if UnitLayer.overlay_frame(t, pack) != VfxPack.frame_at(clip_data, t, pack.frame_ms(), pack.is_loop()):
				all_ok = false
	_check("test_overlay_frame_equals_frame_at_for_every_hero_pack_over_a_sweep", all_ok)


func test_overlay_frame_reduce_motion_holds_frame_zero() -> void:
	var pack: VfxPack = StatusPacks.pack("burn", "hero")
	if pack == null:
		_check("test_burn_hero_pack_present", false)
		return
	_check("test_without_reduce_motion_frame_moves", UnitLayer.overlay_frame(0.5, pack, false) > 0)
	_check("test_reduce_motion_frame_0_at_500_ms", UnitLayer.overlay_frame(0.5, pack, true) == 0)
	_check("test_reduce_motion_frame_0_at_3_s", UnitLayer.overlay_frame(3.0, pack, true) == 0)


func test_overlay_frame_null_pack_is_zero() -> void:
	_check("test_null_pack_frame_0", UnitLayer.overlay_frame(1.0, null) == 0)


# The real battle: the enemy half burning, the UnitLayer's kinds and clock, freeze_time / pause stop it,
# a dead enemy wears nothing. One _process pass with an active overlay runs without a script error.
func test_battle_unit_layer_with_a_burning_enemy() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	_check("test_battle_spawned", battle != null)
	if battle == null:
		return
	var combat := battle.get_node("CombatView") as CombatView
	await process_frame
	var canvas := battle.get_child(0) as BattleCanvas
	_check("test_canvas_present", canvas != null and combat != null)
	if canvas == null or combat == null:
		return
	var units: UnitLayer = canvas.get_unit_layer()
	units.draw.connect(func() -> void: _draw_count += 1)
	var state: CombatState = combat.get_state()
	var status: StatusEffects = combat.get_status()
	_check("test_no_overlays_before_any_status", units.get_active_status_kinds(PLAYER).is_empty() and units.get_active_status_kinds(ENEMY).is_empty())
	_check("test_status_clock_idle_at_zero", units.get_status_elapsed(ENEMY, "burn") == 0.0)
	# The whole enemy half burns, so the boss stays on fire wherever it steps.
	status.ignite(combat.get_grid().enemy_cells(), BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	_check("test_enemy_wears_burn_right_after_ignite", units.get_active_status_kinds(ENEMY) == ["burn"])
	_check("test_player_still_clean", units.get_active_status_kinds(PLAYER).is_empty())
	await process_frame
	await process_frame
	var e1: float = units.get_status_elapsed(ENEMY, "burn")
	await process_frame
	var e2: float = units.get_status_elapsed(ENEMY, "burn")
	print("  status clock after ignite: %.4f -> %.4f (scaled_delta(1/60) = %.4f, freeze_time = %s, draw signals so far: %d)" % [e1, e2, combat.scaled_delta(1.0 / 60.0), combat.freeze_time, _draw_count])
	_check("test_status_clock_advances_with_match_time", e2 > e1)
	_check("test_status_clock_step_within_max_tick", e2 - e1 <= combat.get_config().max_tick_sec + 0.0001)
	# freeze_time (demo captures): the clock stops.
	combat.freeze_time = true
	await process_frame
	var e3: float = units.get_status_elapsed(ENEMY, "burn")
	await process_frame
	_check("test_freeze_time_stops_the_status_clock", units.get_status_elapsed(ENEMY, "burn") == e3 and combat.scaled_delta(1.0 / 60.0) == 0.0)
	combat.freeze_time = false
	# Paused battle (RunController sets process_mode DISABLED): no _process at all, the clock stops.
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var e4: float = units.get_status_elapsed(ENEMY, "burn")
	await process_frame
	_check("test_paused_battle_stops_the_status_clock", units.get_status_elapsed(ENEMY, "burn") == e4)
	battle.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame
	_check("test_clock_resumes_after_unpause", units.get_status_elapsed(ENEMY, "burn") > e4)
	# The frame the layer draws comes from the same clock and the real goblin pack.
	var pack: VfxPack = StatusPacks.pack("burn", "goblin")
	var elapsed: float = units.get_status_elapsed(ENEMY, "burn")
	_check("test_layer_frame_follows_the_pack_clock", pack != null and UnitLayer.overlay_frame(elapsed, pack, units.is_reduce_motion()) == VfxPack.frame_at(pack.clip("front"), elapsed, pack.frame_ms(), pack.is_loop()))
	_check("test_reduce_motion_off_by_default_from_settings", not units.is_reduce_motion())
	units.set_reduce_motion(true)
	_check("test_reduce_motion_override_holds_frame_0", units.is_reduce_motion() and UnitLayer.overlay_frame(elapsed, pack, units.is_reduce_motion()) == 0)
	units.set_reduce_motion(false)
	# Burn ends -> the kind drops and its clock resets.
	status.clear_burn()
	await process_frame
	_check("test_burn_cleared_drops_the_kind_and_clock", units.get_active_status_kinds(ENEMY).is_empty() and units.get_status_elapsed(ENEMY, "burn") == 0.0)
	status.ignite(combat.get_grid().enemy_cells(), BURN_SEC, BURN_TICK_SEC, BURN_DAMAGE)
	await process_frame
	_check("test_reignite_restarts_the_clock_from_zero", units.get_status_elapsed(ENEMY, "burn") < e4)
	# Dead enemy: no overlays (unless downed, which this fixture is not).
	state.enemy_invulnerable_left = 0.0
	state.damage(ENEMY, state.enemy_hp * 10.0)
	if state.is_enemy_dead() and not combat.is_boss_downed():
		_check("test_dead_enemy_wears_nothing_though_its_cell_burns", status.is_burning(state.enemy_cell) and units.get_active_status_kinds(ENEMY).is_empty())
	else:
		print("  note: enemy could not be killed in this fixture (hp %.1f, downed %s); dead case covered by the pure test" % [state.enemy_hp, combat.is_boss_downed()])
	await process_frame
	print("  draw signals observed headless: %d" % _draw_count)
