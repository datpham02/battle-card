extends SceneTree
## Evidence tool (monster-cast-anim session, 2026-11-16): proves the Inferno Lord plays the NEW `windup_heavy`
## clip on its uninterruptible skill, and the ordinary `windup` on an interruptible one — in the real arena, at 1x.
##
## Run (windowed, muted):
##   godot --audio-driver Dummy --path . -s res://tools/qa/inferno_lord_heavy_footage.gd -- <out_dir>
##
## WHY IT WAITS ON STATE, NEVER ON A FRAME COUNT. `--shot-frame=N` counts RENDERED frames, not simulated seconds,
## and the mapping between them moves with machine load. A sibling session measured hero HP 175 -> 200 -> 200 -> 165
## across ASCENDING frame numbers taken in four separate processes — impossible on one timeline. So both shots here
## come from ONE process and ONE match, and each one fires when `PatternController` reports the stage we asked for.
## Nothing is ever compared across processes.
##
## WHAT WOULD MAKE IT FAIL. If `windup_heavy` were missing from the sheet, `UnitLayer._update_clip` falls back to
## `windup` SILENTLY (unit_layer.gd:999) and both shots would show the same pose. That is the defect this tool
## exists to catch, so it also prints the clip the layer actually settled on — a frame alone cannot say which clip
## drew it, and two identical-looking poses would otherwise read as "the clip works".


const CHAPTER: String = "hellfire"
const MATCH_ID: String = "inferno_lord"
const HEAVY_SKILL: String = "lord_cinder_lane"  # interruptible: false -> uninterruptible_tell() is true
const TIMEOUT_MSEC: float = 90000.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://inferno_lord_heavy"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("kiem_si")
	var rc: RunController = gf.enter_test_floor(
		RunConfig.from_node(ChaptersConfig.load_from_file(), CHAPTER, MATCH_ID, "battle", 7, 2))
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i: int in 90:
		await process_frame

	var v := rc.get_battle().get_node("CombatView") as CombatView
	var pattern: PatternController = v.pattern_of(CombatState.Side.ENEMY)
	if pattern == null:
		print("FAIL no PatternController — the match is not on the pattern brain")
		quit(1)
		return

	var want: Dictionary = {"windup": false, "heavy": false}
	var t0: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MSEC:
		await process_frame
		var stage: int = pattern.get_stage()
		var telling: bool = stage == PatternController.Stage.WINDUP or stage == PatternController.Stage.WARNING
		if not telling:
			continue
		var skill_id: String = str(pattern.get_current_skill().get("id", ""))
		var heavy: bool = pattern.uninterruptible_tell()
		var slot: String = "heavy" if heavy else "windup"
		if bool(want[slot]):
			continue
		# One extra frame so the clip the stage asked for is the one on screen.
		await process_frame
		var clip: String = _clip_now(rc.get_battle())
		var ms: int = int(Time.get_ticks_msec() - t0)
		var name: String = "%s_%s_%04dms.png" % [slot, skill_id, ms]
		root.get_texture().get_image().save_png(out.path_join(name))
		want[slot] = true
		print("SHOT %s skill=%s heavy=%s clip_on_screen=%s t=%dms" % [slot, skill_id, heavy, clip, ms])
		if bool(want["windup"]) and bool(want["heavy"]):
			break

	print("RESULT windup=%s heavy=%s" % [want["windup"], want["heavy"]])
	quit(0 if bool(want["windup"]) and bool(want["heavy"]) else 2)


## The clip the enemy's UnitLayer is actually playing, so the log can contradict the picture when the sheet
## falls back to `windup`. "?" when the layer cannot be found.
func _clip_now(battle: Node) -> String:
	var layer: Node = battle.find_child("UnitLayer", true, false)
	if layer == null:
		return "?"
	return str((layer as UnitLayer).get_current_clip(CombatState.Side.ENEMY))
