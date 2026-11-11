extends SceneTree
## Evidence tool: opens a ch1 battle against the Greycap Sporeling (boss frozen) and saves one frame every ~125 ms
## for 1.5 s, so the installed idle clip can be reviewed in the real arena at 1x.
## Run (windowed, muted): godot --audio-driver Dummy --path . -s res://tools/qa/greycap_idle_footage.gd -- <out_dir>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://greycap_idle"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("kiem_si")
	var rc: RunController = gf.enter_test_floor(RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", "greycap_sporeling", "battle", 7, 3))
	for _i in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i in 90:
		await process_frame
	var v := rc.get_battle().get_node("CombatView") as CombatView
	v.get_boss().set_active(false)
	var t0: float = Time.get_ticks_msec()
	var shot: int = 0
	while Time.get_ticks_msec() - t0 < 1500.0:
		await process_frame
		var ms: int = int(Time.get_ticks_msec() - t0)
		if ms >= shot * 125:
			root.get_texture().get_image().save_png(out.path_join("idle_%04d.png" % ms))
			shot += 1
	print("DONE ", shot, " frames")
	quit(0)
