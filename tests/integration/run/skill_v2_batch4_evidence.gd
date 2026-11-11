extends SceneTree
## Skill v2 batch 4 evidence: in a REAL ch1 battle (main.tscn, GameFlow.enter_test_floor, boss frozen, Assassin) casts
## each of the 5 batch-4 cards from the bag through the card menu and saves the in-game frame that shows the card's
## rule (the bell's echo, the pillars, the mark's echo on the next card, the bouncing daggers, the hook's drag) under
## production/qa/evidence/skill-v2-batch4/. Not a test (no *_test.gd name).
## Run (WINDOWED, not headless, muted): godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch4_evidence.gd

const OUT: String = "res://production/qa/evidence/skill-v2-batch4"
## card -> {shape, rotation, offset (anchor relative to the boss), follow (a second card cast right after, on the same
## bag slot shape), hits (damaging impacts to wait for), name}
const CASES: Array[Dictionary] = [
	{"id": "chuong_thanh", "shape": "bar3", "rotation": 0, "offset": Vector2i(-1, 0), "follow": "", "hits": 3, "name": "01-chuong-thanh-third-ring"},
	{"id": "thien_quang", "shape": "plus5", "rotation": 0, "offset": Vector2i(-1, -1), "follow": "", "hits": 1, "name": "02-thien-quang-centre-pillar"},
	{"id": "dau_tu", "shape": "mono", "rotation": 0, "offset": Vector2i(0, 0), "follow": "kiem_khi", "hits": 2, "name": "03-dau-tu-mark-echo"},
	{"id": "phi_tieu", "shape": "bar2", "rotation": 0, "offset": Vector2i(-1, 0), "follow": "", "hits": 2, "name": "04-phi-tieu-bounce"},
	{"id": "moc_keo", "shape": "bar2", "rotation": 0, "offset": Vector2i(0, 0), "follow": "", "hits": 1, "name": "05-moc-keo-drag"},
]
const FRAMES_AFTER: int = 3

var _saved: Array[String] = []
var _hits: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("sat_thu")
	var rc: RunController = gf.enter_test_floor(RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", "dire_wolf", "battle", 7, 3))
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i: int in 90:
		await process_frame
	var v := rc.get_battle().get_node("CombatView") as CombatView
	v.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	v.get_boss().set_active(false)
	var grid: BoardGrid = v.get_grid()
	var state: CombatState = v.get_state()
	v.get_arbiter().impact_resolved.connect(func(_side: int, _ev: Dictionary, hit: bool) -> void:
		if hit:
			_hits += 1)
	var lib := PieceLibrary.load_from_file()
	for case: Dictionary in CASES:
		state.set_enemy_cell(Vector2i(grid.side_cols + 1, 1))
		v.get_status().end_pin(CombatState.Side.ENEMY)
		v.get_status().clear_zones()
		v.get_status().clear_burn()
		await _cast_one(v, lib, case)
	print("SAVED ", str(_saved))
	quit(0)


func _place_and_choose(v: CombatView, lib: PieceLibrary, id: String, shape: String, rotation: int, anchor: Vector2i) -> bool:
	var hold: HoldSlots = v.get_hold()
	hold.remove(0)
	var p := FieldPoint.new()
	p.uid = -500 - _saved.size() * 2 - (1 if id != "" else 0)
	p.freshness_left = 0.0
	p.piece = lib.make_piece(shape, rotation)
	p.label = shape
	hold.place(p, 0)
	v._deck = Deck.from_array([id, id, id, id] as Array[String], 1)
	var placed: bool = v.select_piece(0, false) and v.aim_at_cell(anchor) and v.confirm_placement()
	var opened: bool = v.press_cast()
	var flow: CutFlow = v.get_cut_flow()
	var chosen: bool = opened and flow.choose(id)
	print(id, " placed ", placed, " menu ", opened, " chosen ", chosen, " hand ", flow.get_hand())
	return chosen


func _cast_one(v: CombatView, lib: PieceLibrary, case: Dictionary) -> void:
	var id: String = str(case["id"])
	var state: CombatState = v.get_state()
	var boss: Vector2i = state.enemy_cell
	var hp0: float = state.enemy_hp
	_hits = 0
	if not _place_and_choose(v, lib, id, str(case["shape"]), int(case["rotation"]), boss + (case["offset"] as Vector2i)):
		return
	while v.get_cut_actor().is_swinging():
		await process_frame
	var follow: String = str(case["follow"])
	if not follow.is_empty():
		for _i: int in 30:
			await process_frame
		v.get_skill_cooldowns().clear(follow)
		if not _place_and_choose(v, lib, follow, str(case["shape"]), int(case["rotation"]), state.enemy_cell):
			return
		while v.get_cut_actor().is_swinging():
			await process_frame
	for _i: int in 400:
		await process_frame
		if _hits >= int(case["hits"]):
			break
	for _i: int in FRAMES_AFTER:
		await process_frame
	var path: String = OUT.path_join(str(case["name"]) + ".png")
	root.get_texture().get_image().save_png(path)
	_saved.append(path)
	var fx: StatusEffects = v.get_status()
	print(id, " boss damage %.1f boss %s -> %s hits %d frost %d ran %d mark %s" % [hp0 - state.enemy_hp, str(boss), str(state.enemy_cell), _hits,
		fx.frost_stacks(CombatState.Side.ENEMY), fx.fragile_stacks(CombatState.Side.ENEMY), str(fx.has_mark(CombatState.Side.ENEMY))])
	for _i: int in 120:
		await process_frame
	v.get_skill_cooldowns().clear(id)
