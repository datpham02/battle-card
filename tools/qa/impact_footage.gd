extends SceneTree
## Skill v2 V1 evidence: casts a list of cards in a real ch1 battle (boss frozen) and saves the frames where the card's
## impact draws on the hit cells (CombatView.cast_travel_now: hit and 0 <= age <= 0.35 s on the first cell).
## Run (windowed, not headless): godot --path . -s res://tools/qa/impact_footage.gd -- <out_dir> <hero> <card,card,...>

const PIECE: String = "plus5"
const WINDOW_SEC: float = 0.55

var _out: String
var _frames: Dictionary = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	var hero: String = args[1] if args.size() > 1 else "sat_thu"
	var cards: PackedStringArray = (args[2] if args.size() > 2 else "bang_phong,han_tran").split(",")
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
	for card: String in cards:
		# a push card moves the boss: put it back on the centre cell before every cast
		state.set_enemy_cell(Vector2i(grid.side_cols + 1, 1))
		await _cast_one(v, lib, card.strip_edges(), state.enemy_cell)
	print("DONE ", JSON.stringify(_frames))
	quit(0)


func _cast_one(v: CombatView, lib: PieceLibrary, card: String, boss: Vector2i) -> void:
	var hold: HoldSlots = v.get_hold()
	hold.remove(0)
	var p := FieldPoint.new()
	p.uid = -500 - _frames.size()
	p.freshness_left = 0.0
	p.piece = lib.make_piece(PIECE, 0)
	p.label = PIECE
	hold.place(p, 0)
	v._deck = Deck.from_array([card, card, card, card] as Array[String], 1)
	var placed: bool = v.select_piece(0, false) and v.aim_at_cell(boss) and v.confirm_placement()
	var opened: bool = v.press_cast()
	var flow: CutFlow = v.get_cut_flow()
	var chosen: bool = opened and flow.choose(card)
	print(card, " placed ", placed, " menu ", opened, " chosen ", chosen, " hand ", flow.get_hand())
	if not chosen:
		_frames[card] = []
		return
	var saved: Array = []
	var seen_hit: bool = false
	var swing_shots: int = 0
	for _i in 400:
		await process_frame
		var tr: Dictionary = v.cast_travel_now(0.5)
		if tr.is_empty():
			if seen_hit:
				break
			continue
		# the cast glyph (CastGlyphFx) draws while the swing runs: a few frames of it, named by swing progress
		if bool(tr.get("swinging", false)) and swing_shots < 10 and (_i % 5) == 0:
			var actor: CutActor = v.get_cut_actor()
			var k: float = 1.0 - actor.get_time_left() / maxf(actor.get_duration(), 0.001) if actor != null else 0.0
			var sname: String = "%s_cast_%02d.png" % [card, roundi(k * 100.0)]
			root.get_texture().get_image().save_png(_out.path_join(sname))
			saved.append(sname)
			swing_shots += 1
			continue
		if not bool(tr.get("hit", false)):
			continue
		seen_hit = true
		var first: float = INF
		for c: Vector2i in tr["arrive"]:
			first = minf(first, float(tr["arrive"][c]))
		var age: float = float(tr["rel"]) - first
		if age >= 0.0 and age <= WINDOW_SEC:
			var name: String = "%s_%03d.png" % [card, roundi(age * 1000.0)]
			root.get_texture().get_image().save_png(_out.path_join(name))
			saved.append(name)
	_frames[card] = saved
	# let the cooldown and any leftover visuals pass
	for _i in 90:
		await process_frame
