extends SceneTree
## Evidence tool (monster-cast-anim session, 2026-11-17): captures what an enemy skill's impact actually puts on
## screen, so "the boss's skills look weak" becomes a number instead of an impression.
##
## Run (windowed, muted):
##   godot --audio-driver Dummy --path . -s res://tools/qa/enemy_impact_probe.gd -- <out_dir> <chapter> <match_id> <tag> [skill_id]
##
## WITHOUT [skill_id] IT TAKES THE FIRST SKILL THAT RESOLVES, WHICH IS USUALLY NOT THE ONE YOU CAME FOR. The first
## run against the Ogre King captured `ogre_grab` while the pack under test belonged to `ogre_club`: the shot was
## real, the measurement was of another skill. Name the skill when the question is about one skill.
##
## BASELINE AND IMPACT COME FROM ONE PROCESS, ONE MATCH, ONE SKILL. The baseline is grabbed on the frame the skill
## resolves, before the impact is drawn; the impact frames follow it immediately. Measuring the effect means diffing
## those, and a diff across two processes would be measuring two different boards (a sibling session measured hero HP
## going 175 -> 200 -> 200 -> 165 across ascending frame numbers taken in separate processes).
##
## IT SHOOTS ON THE SIGNAL, NOT ON A TIMER. `PatternController.skill_resolved` is the exact moment the view is told
## to play the impact, so the frames after it are the effect. A timer would sample an arbitrary point of a 0.22 s
## effect and the number would move with machine load.
##
## WHAT IT CANNOT SAY: it measures one skill of one enemy on one arena. It says nothing about whether the effect
## READS as dangerous — only how much of the screen it changes, and how saturated that change is.


## 2026-11-17: the CHARGE beat happens during the telegraph, BEFORE skill_resolved - a probe that only shoots
## at the resolve cannot see it at all, and would report 'no charge' for a charge that plays correctly.
var _warned: bool = false
var _resolved: bool = false
var _skill_id: String = ""
var _want: String = ""
var _impact: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		print("FAIL usage: <out_dir> <chapter> <match_id> <tag>")
		quit(1)
		return
	var out: String = args[0]
	var chapter: String = args[1]
	var match_id: String = args[2]
	var tag: String = args[3]
	_want = args[4] if args.size() > 4 else ""
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
		print("FAIL no PatternController")
		quit(1)
		return
	pattern.skill_resolved.connect(_on_resolved)
	pattern.warning_started.connect(_on_warned)

	# Four of the six boss signatures exist only in phase 2 (sphinx_sandfall, matriarch_toxic_croak,
	# mist_lord_whiteout, dragon_tempest), so a probe that never drops the boss waits for a skill that cannot
	# appear. The same trap cost a run in boss_cast_footage.gd; the drop goes FIRST here for the same reason.
	v.get_state().damage_enemy(v.get_state().enemy_hp * 0.6)

	var t0: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000.0:
		await process_frame
		if _warned and not _resolved:
			# MID-telegraph, not the first frame after the signal. `root.get_texture()` hands back the frame that
			# was ALREADY rendered, so shooting one frame after warning_started captures the board as it looked
			# BEFORE the warning - no red markers, no charge - and reads as "the charge never drew".
			_warned = false
			# the charge now fires in the LAST 0.30 s of the telegraph, so the shot waits out the warning
			# instead of firing at its start. Waiting on the STAGE, not on a frame count: a frame count would
			# drift with machine load and sample a different point of a 0.30 s effect every run.
			while pattern.get_stage() == PatternController.Stage.WARNING and pattern.strike_time_left() > 0.16:
				await process_frame
			for _w: int in 3:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%s_charge.png" % [tag, _skill_id]))
			print("SHOT %s charge skill=%s" % [tag, _skill_id])
		if not _resolved:
			continue
		# frame 0 is the baseline: the signal has fired but the impact is drawn from the next frame on
		root.get_texture().get_image().save_png(out.path_join("%s_%s_base.png" % [tag, _skill_id]))
		for n: int in 6:
			await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%s_f%d.png" % [tag, _skill_id, n + 1]))
		print("SHOT %s skill=%s impact=%s" % [tag, _skill_id, _impact])
		print("RESULT %s ok" % tag)
		quit(0)
		return

	print("RESULT %s no skill resolved in 90 s" % tag)
	quit(2)


func _on_warned(skill_id: String, _cells: Array[Vector2i], _queued: Array[Vector2i], _sec: float) -> void:
	if _resolved or (not _want.is_empty() and skill_id != _want):
		return
	_skill_id = skill_id
	_warned = true


func _on_resolved(skill_id: String, result: Dictionary) -> void:
	if _resolved:
		return
	var delivery: Variant = result.get("delivery")
	var impact: String = str((delivery as Dictionary).get("impact", "")) if delivery is Dictionary else ""
	if impact.is_empty() or impact == "none":
		return
	if not _want.is_empty() and skill_id != _want:
		return
	_skill_id = skill_id
	_impact = impact
	_resolved = true
