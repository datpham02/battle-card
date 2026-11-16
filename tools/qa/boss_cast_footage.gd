extends SceneTree
## Evidence tool (monster-cast-anim session, 2026-11-16): proves one boss plays its NEW `windup_heavy` and
## `phase_shift` clips in a real match. One unit per process.
##
## Run (windowed, muted):
##   godot --audio-driver Dummy --path . -s res://tools/qa/boss_cast_footage.gd -- <out_dir> <chapter> <match_id>
##
## WHY EACH SHOT IS JUDGED ALONE, not against the other. `--shot-frame=N` counts RENDERED frames, not simulated
## seconds, so pictures taken at different moments cannot be ordered by eye. Nothing here is a before/after pair:
## each shot carries its own verdict in the log, the clip name the UnitLayer reports at that instant. That is what
## makes one process per unit safe — no claim ever spans two processes.
##
## WHAT WOULD MAKE IT FAIL. A sheet without the clip falls back to `windup` SILENTLY (unit_layer.gd:999), so a
## picture alone cannot say which clip drew it. The log line is the evidence; the picture only shows what it looks
## like. If `clip=windup` appears on a `heavy` or `phase` shot, that unit FAILED however good the frame looks.
##
## The phase shot needs the boss below its phase-2 threshold, so the harness calls `CombatState.damage_enemy`
## directly. That is the harness cheating the fight, not the game: the clip it then captures is the one the
## engine picks for a real TRANSITION stage.


const TIMEOUT_MSEC: float = 120000.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		print("FAIL usage: <out_dir> <chapter> <match_id>")
		quit(1)
		return
	var out: String = args[0]
	var chapter: String = args[1]
	var match_id: String = args[2]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("kiem_si")
	var rc: RunController = gf.enter_test_floor(
		RunConfig.from_node(ChaptersConfig.load_from_file(), chapter, match_id, "battle", 7, 2))
	for _i: int in 900:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i: int in 90:
		await process_frame

	var v := rc.get_battle().get_node("CombatView") as CombatView
	var pattern: PatternController = v.pattern_of(CombatState.Side.ENEMY)
	if pattern == null:
		print("FAIL %s: no PatternController" % match_id)
		quit(1)
		return
	var layer := rc.get_battle().find_child("UnitLayer", true, false) as UnitLayer
	var state: CombatState = v.get_state()

	# The HP drop comes FIRST, before anything is captured. For four of the six bosses the uninterruptible skill
	# exists ONLY in phase 2 (sphinx_sandfall, matriarch_toxic_croak, mist_lord_whiteout, dragon_tempest), so a
	# harness that waits for the heavy tell before dropping waits for a skill that cannot appear yet. The first
	# version of this file did exactly that and timed out on all four — it reported false rather than passing
	# silently, which is the only reason the mistake was visible.
	state.damage_enemy(state.enemy_hp * 0.6)

	# A shot is taken only when the layer is ALREADY drawing the clip we came for. `hit` outranks `phase_shift`
	# in UnitLayer.clip_for, so the damage flash above covers the transition for a moment: shooting on the stage
	# alone caught `clip=hit` and filed it as phase_shift evidence. The stage says what the engine decided; the
	# clip name says what is on screen, and the picture is only worth keeping when they agree.
	var want: Dictionary = {"heavy": false, "phase": false}
	var t0: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MSEC:
		await process_frame
		var stage: int = pattern.get_stage()
		var clip: String = layer.get_current_clip(CombatState.Side.ENEMY) if layer != null else "?"
		var slot: String = ""
		if stage == PatternController.Stage.TRANSITION and clip == "phase_shift":
			slot = "phase"
		elif (stage == PatternController.Stage.WINDUP or stage == PatternController.Stage.WARNING) \
				and pattern.uninterruptible_tell() and clip == "windup_heavy":
			slot = "heavy"
		if slot == "" or bool(want[slot]):
			continue
		var skill_id: String = str(pattern.get_current_skill().get("id", ""))
		var ms: int = int(Time.get_ticks_msec() - t0)
		root.get_texture().get_image().save_png(
			out.path_join("%s_%s_%s_%04dms.png" % [match_id, slot, skill_id, ms]))
		want[slot] = true
		print("SHOT %s %s skill=%s clip=%s t=%dms" % [match_id, slot, skill_id, clip, ms])
		if bool(want["heavy"]) and bool(want["phase"]):
			break

	print("RESULT %s heavy=%s phase=%s" % [match_id, want["heavy"], want["phase"]])
	quit(0 if bool(want["heavy"]) and bool(want["phase"]) else 2)
