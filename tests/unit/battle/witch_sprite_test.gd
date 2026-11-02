extends SceneTree
## Forest Witch sprite (ASSET-020, 2026-11-02): the boss match loads her sheet (no red placeholder) and the pattern
## brain's stages pick her clips: a phase transition -> `phase_shift`, an uninterruptible skill winding up / warning ->
## `windup_heavy`, any other skill -> `windup`; a sheet without the heavy / phase clips falls back (UnitLayer).
## Run: godot --headless --path . -s res://tests/unit/battle/witch_sprite_test.gd

const MAX_FRAMES: int = 600
const ENEMY: int = CombatState.Side.ENEMY

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_clip_for_pattern_stages()
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	flow.set_character("kiem_si")
	var cfg: RunConfig = RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", "forest_witch", "boss", 7, 3)
	var rc: RunController = flow.enter_test_floor(cfg)
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView if battle != null else null
	var canvas := battle.get_child(0) as BattleCanvas if battle != null else null
	_check("test_witch_battle_spawned", combat != null and canvas != null and combat.get_pattern_controller() != null)
	if combat == null or canvas == null or combat.get_pattern_controller() == null:
		_finish()
		return
	var units: UnitLayer = canvas.get_unit_layer()
	units.set_process(false)
	_check("test_witch_unit_id", units.get_unit_id(ENEMY) == "forest_witch", units.get_unit_id(ENEMY))
	_check("test_witch_sheet_loaded_no_placeholder", units.get_sheet(ENEMY) != null and not units.is_placeholder(ENEMY))
	_check("test_witch_frame_160x130", units.get_sheet(ENEMY) != null and units.get_sheet(ENEMY).frame_size() == Vector2i(160, 130))
	# 2026-11-02 (user: the Witch should fill her 2x2 and stand in its middle): her feet sit inside the block, above the
	# feet line a unit on its front row would have, and below its back row's feet line.
	var st: CombatState = combat.get_state()
	var feet: Vector2i = units.unit_feet_art(ENEMY)
	var front: Vector2i = units.feet_art_of_cell(st.enemy_cell + Vector2i(0, st.footprint_extent().y - 1))
	var back: Vector2i = units.feet_art_of_cell(st.enemy_cell)
	_check("test_witch_feet_in_the_middle_of_her_block", feet.y < front.y and feet.y > back.y, "feet %s back %s front %s" % [feet, back, front])
	# Below 65 % the pattern brain enters phase 2 (a 1.5 s transition): her clip is phase_shift.
	var state: CombatState = combat.get_state()
	state.player_max_hp = 100000.0
	state.player_hp = 100000.0
	state.damage_enemy(state.enemy_max_hp * 0.4)
	combat.get_pattern_controller().tick(0.05)
	# Past the hit flinch the damage started (hit outranks every other clip).
	units.advance(UnitLayer.HIT_SEC + 0.05)
	_check("test_witch_phase_shift_in_transition",
		combat.get_pattern_controller().get_stage() == PatternController.Stage.TRANSITION and units.get_current_clip(ENEMY) == UnitLayer.CLIP_PHASE_SHIFT,
		"stage %d clip %s" % [combat.get_pattern_controller().get_stage(), units.get_current_clip(ENEMY)])
	# 2026-11-02 (user: the outline round her big frame read as a selection box): invulnerable in the transition, she
	# blinks white on her body; the blink is on, then off, then on; reduce motion holds a steady glow.
	_check("test_witch_invulnerable_in_transition", state.enemy_invulnerable_left > 0.0)
	_check("test_invulnerable_blink_on_off", UnitLayer.invulnerable_flash_alpha(0.0, false) > 0.0
		and UnitLayer.invulnerable_flash_alpha(UnitLayer.INVULN_BLINK_SEC * 1.5, false) == 0.0
		and UnitLayer.invulnerable_flash_alpha(UnitLayer.INVULN_BLINK_SEC * 2.5, false) > 0.0)
	_check("test_invulnerable_reduce_motion_steady", UnitLayer.invulnerable_flash_alpha(0.0, true) == UnitLayer.invulnerable_flash_alpha(UnitLayer.INVULN_BLINK_SEC * 1.5, true)
		and UnitLayer.invulnerable_flash_alpha(0.0, true) > 0.0)
	_finish()


func test_clip_for_pattern_stages() -> void:
	var base := {UnitLayer.CTX_SIDE: ENEMY}
	_check("test_enemy_idle_by_default", UnitLayer.clip_for(base) == UnitLayer.CLIP_IDLE)
	var swinging: Dictionary = base.duplicate()
	swinging[UnitLayer.CTX_SWINGING] = true
	_check("test_enemy_skill_winds_up", UnitLayer.clip_for(swinging) == UnitLayer.CLIP_WINDUP)
	var heavy: Dictionary = swinging.duplicate()
	heavy[UnitLayer.CTX_HEAVY] = true
	_check("test_enemy_heavy_skill_winds_up_heavy", UnitLayer.clip_for(heavy) == UnitLayer.CLIP_WINDUP_HEAVY)
	var phase: Dictionary = heavy.duplicate()
	phase[UnitLayer.CTX_PHASE] = true
	_check("test_enemy_phase_transition_wins", UnitLayer.clip_for(phase) == UnitLayer.CLIP_PHASE_SHIFT)
	var hit: Dictionary = phase.duplicate()
	hit[UnitLayer.CTX_HIT] = true
	_check("test_hit_still_wins_over_the_phase", UnitLayer.clip_for(hit) == UnitLayer.CLIP_HIT)


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
