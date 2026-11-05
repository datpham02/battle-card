extends SceneTree
## Playtest bot (2026-11-05, moved from session scratch). Plays one real ch1 battle through the CombatView API the
## touch input uses and checks the cast rules of design/quick-specs/niem-dung-tran-2026-11-04.md every frame:
##  - while casting (piece held, place window, card menu) the enemy cell and its pattern stage do not change, and
##    try_step_player is refused;
##  - after the card is chosen the hero is not stuck in cast_gesture;
##  - lifting a placed piece keeps its cells; the readout damage is never 0 with a piece on the board;
##  - the cast clock running out casts a card.
## A tool, not a test: the suite never runs it. Card time is normal (4 s). Prints VIOLATION lines and one RESULT line,
## saves up to 6 screenshots to <out_dir>/<hero>-<match>-N-<what>.png. Needs a window (no --headless: screenshots).
## Run: godot --path . --fixed-fps 60 -s res://tools/qa/play_bot.gd -- <out_dir> <hero> <match> <seed> --no-autopause
## Whole matrix: tools/qa/run_bot_matrix.sh. See tools/qa/README.md.
const MAX_SEC: float = 150.0

var out: String
var tag: String
var shots: int = 0
var viol: Dictionary = {}
var saw_pause: bool = false
var stats: Dictionary = {"casts": 0, "timeouts": 0, "lifts": 0, "lift_moves": 0, "steps": 0, "step_clips": 0, "cards": {}, "stuck_cast": 0}


func _bad(key: String, extra: String = "") -> void:
	if not viol.has(key):
		viol[key] = extra
		print("VIOLATION ", key, " ", extra)


func _shot(name: String) -> void:
	if shots >= 6:
		return
	shots += 1
	root.get_texture().get_image().save_png("%s/%s-%d-%s.png" % [out, tag, shots, name])


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var hero: String = a[1]
	var match_id: String = a[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a[3])
	tag = "%s-%s" % [hero, match_id]
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character(hero)
	var rc: RunController = gf.enter_test_floor(RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", match_id, "battle", 7, 3))
	for _i in 900:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING: break
		await process_frame
	var v := rc.get_battle().get_node("CombatView") as CombatView
	v.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	v.get_cut_flow().rng.seed = int(a[3])
	var st: CombatState = v.get_state()
	var layer: UnitLayer = v.get_battle_canvas().get_unit_layer()
	var lib := PieceLibrary.load_from_file()
	var shapes: Array[String] = ["mono", "bar2", "bar3", "l3", "square", "t4", "l4", "plus5"]
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	var next_action: float = 1.0
	var mode: String = ""
	var mode_t: float = 0.0
	var e_cell0: Vector2i
	var drop_fresh0: float = -1.0
	var pat_stage0: int = -1
	var after_cast_clips: Dictionary = {}
	var watching_after: float = 0.0
	var e_moves: int = 0
	var last_e: Vector2i = st.enemy_cell
	var was_casting: bool = false
	while t < MAX_SEC and not st.is_player_dead() and not st.is_enemy_dead():
		await process_frame
		t += dt
		if st.enemy_cell != last_e:
			e_moves += 1
			last_e = st.enemy_cell
		var casting: bool = v.is_casting()
		saw_pause = saw_pause or paused
		var pat: PatternController = v.get_pattern_controller()
		var drops: Array = v.get_drops().get_points() if v.get_drops().has_method("get_points") else []
		# --- rule: nothing moves while casting
		if casting and was_casting:
			if st.enemy_cell != e_cell0:
				_bad("enemy_moved_while_casting", "%s -> %s mode %s" % [e_cell0, st.enemy_cell, mode])
			if pat != null and pat.get_stage() != pat_stage0:
				_bad("pattern_stage_changed_while_casting", "%d -> %d mode %s" % [pat_stage0, pat.get_stage(), mode])
			if v.try_step_player(Vector2i(1 if rng.randf() < 0.5 else -1, 0)):
				_bad("hero_stepped_while_casting", mode)
			var lbl_cells: int = v.get_cast_plan().total_cells() + (v.get_placement().get_cells().size() if v.is_placing() else 0)
			if lbl_cells > 0 and CutHudView.preview_damage_cells(v.get_cast_plan().total_cells(), v.get_placement().get_cells().size() if v.is_placing() else 0) == 0:
				_bad("readout_zero_with_a_piece")
		if casting and not was_casting:
			e_cell0 = st.enemy_cell
			pat_stage0 = pat.get_stage() if pat != null else -1
		was_casting = casting
		# --- rule: after a cast the hero is not stuck in cast_gesture
		if watching_after > 0.0 and (v.get_cut_actor().is_swinging() or v.is_casting()):
			pass
		elif watching_after > 0.0:
			watching_after -= dt
			after_cast_clips[layer.get_current_clip(CombatState.Side.PLAYER)] = true
			if watching_after <= 0.0:
				if after_cast_clips.size() == 1 and after_cast_clips.has("cast_gesture"):
					stats["stuck_cast"] += 1
					_bad("stuck_in_cast_gesture")
		# --- bot actions
		if mode == "":
			if t < next_action:
				# walk around between casts
				if rng.randf() < 0.04 and not v.is_movement_locked():
					var d: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]
					if v.try_step_player(d):
						stats["steps"] += 1
				continue
			if v.get_cut_actor().is_swinging():
				continue
			var hold: HoldSlots = v.get_hold()
			if hold.get_piece(0) == null:
				var p := FieldPoint.new()
				p.uid = -1000 - int(t * 10)
				p.freshness_left = 0.0
				p.piece = lib.make_piece(shapes[rng.randi_range(0, shapes.size() - 1)], rng.randi_range(0, 3))
				p.label = "bot"
				hold.place(p, 0)
			var ok_sel: bool = v.select_piece(0, false)
			var ok_aim: bool = ok_sel and v.aim_at_cell(st.enemy_cell)
			for _r in 3:
				if ok_aim or not ok_sel:
					break
				v.rotate_piece()
				ok_aim = v.aim_at_cell(st.enemy_cell)
			var ok_conf: bool = ok_aim and v.confirm_placement()
			if not ok_conf:
				if int(stats.get("fail_log", 0)) < 6:
					stats["fail_log"] = int(stats.get("fail_log", 0)) + 1
					print("PLACE FAIL t=%.1f sel %s aim %s conf %s piece %s placed %s menu %s swing %s e %s" % [t, ok_sel, ok_aim, ok_conf, hold.get_piece(0).shape_id if hold.get_piece(0) else "-", v.is_placed(), v.get_cut_flow().is_menu_open(), v.get_cut_actor().is_swinging(), st.enemy_cell])
				v.cancel_placement()
				next_action = t + 0.5
				continue
			var r: float = rng.randf()
			mode = "lift" if r < 0.35 else ("timeout" if r < 0.55 else "choose")
			mode_t = t
			if shots == 0:
				_shot("placed")
		elif mode == "lift":
			if t - mode_t > 0.4:
				var before: Array[Vector2i] = v.get_cast_plan().piece_cells(0)
				before.sort()
				if v.lift_placed_piece(0):
					stats["lifts"] += 1
					var now: Array[Vector2i] = v.get_placement().get_cells()
					now.sort()
					if now != before:
						_bad("lift_changed_cells", "%s vs %s" % [before, now])
					v.rotate_piece()
					var target: Vector2i = st.enemy_cell + Vector2i(0, rng.randi_range(-1, 1))
					v.aim_at_cell(target)
					if shots < 3:
						_shot("lifted")
					if v.can_confirm_placement() and v.confirm_placement():
						stats["lift_moves"] += 1
				mode = "choose"
				mode_t = t
		elif mode == "choose":
			if t - mode_t > 0.6:
				if v.is_placing():
					v.cancel_placement()
				if v.is_placed() and v.press_cast():
					if shots < 4:
						_shot("menu")
					var flow: CutFlow = v.get_cut_flow()
					var picked: String = ""
					for id: String in flow.get_hand():
						if bool(SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), id, flow.get_cells().size())["available"]):
							picked = id
							break
					if picked != "" and flow.choose(picked):
						stats["casts"] += 1
						(stats["cards"] as Dictionary)[picked] = int((stats["cards"] as Dictionary).get(picked, 0)) + 1
					elif flow.is_menu_open():
						flow.tick_real(99.0)
						stats["casts"] += 1
				mode = ""
				after_cast_clips = {}
				watching_after = 1.0
				next_action = t + 1.2 + rng.randf()
		elif mode == "timeout":
			if not v.is_casting():
				var actor: CutActor = v.get_cut_actor()
				if actor.is_swinging():
					stats["timeouts"] += 1
					stats["casts"] += 1
					var id: String = actor.get_skill_id()
					(stats["cards"] as Dictionary)[id] = int((stats["cards"] as Dictionary).get(id, 0)) + 1
					if not bool(SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), id, actor.get_cells().size())["available"]) and id != v.get_skill_config().default_card:
						pass
				else:
					_bad("timeout_did_not_cast", "skill %s cells %s placed %s plan %d paused %s hp %.0f" % [actor.get_skill_id(), actor.get_cells(), v.is_placed(), v.get_cast_plan().piece_count(), saw_pause, st.enemy_hp])
				mode = ""
				after_cast_clips = {}
				watching_after = 1.0
				next_action = t + 1.2 + rng.randf()
			elif t - mode_t > 6.0:
				_bad("cast_clock_never_ran_out", "tree_paused_seen %s %.1f s placed %s left %.2f menu %s menu_left %.2f placing %s swing %s unlimited %s plan %d sig %s dead %s/%s" % [saw_pause, t - mode_t, v.is_placed(), v.get_place_time_left(), v.get_cut_flow().is_menu_open(), v.get_cut_flow().get_time_left(), v.is_placing(), v.get_cut_actor().is_swinging(), v.is_place_unlimited(), v.get_cast_plan().piece_count(), v.is_signature_active(), st.is_player_dead(), st.is_enemy_dead()])
				v.cancel_placement()
				mode = ""
		if watching_after > 0.0 and not v.is_movement_locked() and rng.randf() < 0.05:
			if v.try_step_player([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]):
				stats["steps"] += 1
	_shot("end")
	var result: String = "WIN" if st.is_enemy_dead() else ("LOSS" if st.is_player_dead() else "TIMEUP")
	print("RESULT %s %s %.0fs hp %.0f/%.0f enemy %.0f/%.0f enemy_moves %d stats %s violations %s" % [tag, result, t, st.player_hp, st.player_max_hp, st.enemy_hp, st.enemy_max_hp, e_moves, JSON.stringify(stats), JSON.stringify(viol)])
	quit()
