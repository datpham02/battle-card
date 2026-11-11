extends SceneTree
## Deferred 6 / 7 / 10 evidence (docs/skill-v2/16-mvp-matrix.md "Deferred after 60/60"): in a real ch1 battle (boss
## frozen) saves (a) the card menu with a ward card in the hand and the ward ghost around the hero, (b) Hỏa Tuyến's
## standing fire wall 1.0 s and 2.5 s after the cast, (c) the status row 1.5 s after Dấu Tử marks the boss.
## Run (windowed, muted): godot --audio-driver Dummy --path . -s res://tools/qa/deferred_vfx_footage.gd -- <out_dir>

## The piece per scene: Hỏa Tuyến only walls a LINE piece (its `line` clause).
const PIECE: String = "plus5"
const LINE_PIECE: String = "bar3"

var _out: String


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://deferred_vfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _scene("giao_si", "thanh_thuan", "06-ward-ghost-menu", [], true)
	await _scene("phap_su", "hoa_tuyen", "07-fire-wall", [1.0, 2.5], false, LINE_PIECE)
	await _scene("sat_thu", "dau_tu", "10-mark-chip", [1.5], false)
	print("DONE")
	quit(0)


## One battle: places a plus piece on the boss, opens the menu with [param card]; [param menu_only] saves the open
## menu, else chooses the card and saves a frame at each of [param at_sec] after the choice.
func _scene(hero: String, card: String, name: String, at_sec: Array, menu_only: bool, piece: String = PIECE) -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character(hero)
	var rc: RunController = gf.enter_test_floor(RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", "dire_wolf", "battle", 7, 3))
	for _i in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i in 90:
		await process_frame
	var v := rc.get_battle().get_node("CombatView") as CombatView
	v.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	v.get_boss().set_active(false)
	var grid: BoardGrid = v.get_grid()
	var state: CombatState = v.get_state()
	state.set_enemy_cell(Vector2i(grid.side_cols + 1, 1))
	var lib := PieceLibrary.load_from_file()
	var hold: HoldSlots = v.get_hold()
	hold.remove(0)
	var p := FieldPoint.new()
	p.uid = -700
	p.freshness_left = 0.0
	p.piece = lib.make_piece(piece, 0)
	p.label = piece
	hold.place(p, 0)
	v._deck = Deck.from_array([card, card, card, card] as Array[String], 1)
	var placed: bool = v.select_piece(0, false) and v.aim_at_cell(state.enemy_cell) and v.confirm_placement()
	var opened: bool = v.press_cast()
	print(name, " placed ", placed, " menu ", opened, " hand ", v.get_cut_flow().get_hand())
	for _i in 6:
		await process_frame
	if menu_only:
		root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	else:
		var chosen: bool = v.get_cut_flow().choose(card)
		print(name, " chosen ", chosen)
		var t0: float = Time.get_ticks_msec()
		var next: int = 0
		while next < at_sec.size():
			await process_frame
			if Time.get_ticks_msec() - t0 >= float(at_sec[next]) * 1000.0:
				root.get_texture().get_image().save_png(_out.path_join("%s_%03d.png" % [name, roundi(float(at_sec[next]) * 100.0)]))
				next += 1
	root.remove_child(main)
	main.queue_free()
	for _i in 10:
		await process_frame
