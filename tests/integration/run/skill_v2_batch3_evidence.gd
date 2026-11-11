extends SceneTree
## Skill v2 batch 3 evidence: in a REAL ch1 battle (main.tscn, GameFlow.enter_test_floor, boss frozen, Hunter) casts
## each of the 7 batch-3 cards from the bag through the card menu and saves the in-game frame that shows the card's
## rule (the trap snapping, the thorn burst, the ward around the hero...) under production/qa/evidence/skill-v2-batch3/.
## Armed traps, wards and pillars also draw ZoneFx marks on the slab. Not a test (no *_test.gd name).
## Run (WINDOWED, not headless, muted): godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch3_evidence.gd

const OUT: String = "res://production/qa/evidence/skill-v2-batch3"
## card -> {shape, rotation, offset (anchor relative to the boss), thorns (pre-laid thorn cells relative to the boss),
## boss_after (where the boss steps after the cast, relative to its cell; NO_MOVE = stays), hits (damaging impacts to
## wait for after the step), name}
const NO_MOVE := Vector2i(99, 99)
const CASES: Array[Dictionary] = [
	{"id": "bay_kep", "shape": "bar2", "rotation": 0, "offset": Vector2i(-1, -1), "thorns": [], "boss_after": Vector2i(0, -1), "hits": 1, "name": "01-bay-kep-snap"},
	{"id": "bay_lo", "shape": "bar2", "rotation": 0, "offset": Vector2i(-1, -1), "thorns": [], "boss_after": Vector2i(0, -1), "hits": 1, "name": "02-bay-lo-fling"},
	{"id": "gai_no", "shape": "bar3", "rotation": 0, "offset": Vector2i(-1, 0), "thorns": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)], "boss_after": NO_MOVE, "hits": 1, "name": "03-gai-no-burst"},
	{"id": "thanh_thuan", "shape": "bar2", "rotation": 0, "offset": Vector2i(-1, 0), "thorns": [], "boss_after": NO_MOVE, "hits": 0, "name": "04-thanh-thuan-ward"},
	{"id": "khien_thep", "shape": "bar2", "rotation": 1, "offset": Vector2i(-1, -1), "thorns": [], "boss_after": NO_MOVE, "hits": 0, "name": "05-khien-thep-ward"},
	{"id": "tuong_da", "shape": "bar3", "rotation": 0, "offset": Vector2i(-1, -1), "thorns": [], "boss_after": NO_MOVE, "hits": 0, "name": "06-tuong-da-pillars"},
	{"id": "hoa_tuyen", "shape": "bar3", "rotation": 1, "offset": Vector2i(1, -1), "thorns": [], "boss_after": NO_MOVE, "hits": 0, "name": "07-hoa-tuyen-wall"},
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
	gf.set_character("tho_san")
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
	v.get_status().trap_fired.connect(func(_side: int, _cast_id: int, _cells: Array[Vector2i], _damage: float) -> void: _hits += 1)
	var lib := PieceLibrary.load_from_file()
	for case: Dictionary in CASES:
		state.set_enemy_cell(Vector2i(grid.side_cols + 1, 1))
		v.get_status().end_pin(CombatState.Side.ENEMY)
		v.get_status().clear_zones()
		v.get_status().clear_burn()
		await _cast_one(v, lib, case)
	print("SAVED ", str(_saved))
	quit(0)


func _cast_one(v: CombatView, lib: PieceLibrary, case: Dictionary) -> void:
	var id: String = str(case["id"])
	var shape: String = str(case["shape"])
	var hold: HoldSlots = v.get_hold()
	hold.remove(0)
	var p := FieldPoint.new()
	p.uid = -500 - _saved.size()
	p.freshness_left = 0.0
	p.piece = lib.make_piece(shape, int(case["rotation"]))
	p.label = shape
	hold.place(p, 0)
	v._deck = Deck.from_array([id, id, id, id] as Array[String], 1)
	var state: CombatState = v.get_state()
	var boss: Vector2i = state.enemy_cell
	if not (case["thorns"] as Array).is_empty():
		var cells: Array[Vector2i] = []
		for o: Variant in case["thorns"] as Array:
			cells.append(boss + (o as Vector2i))
		ZoneRules.cast_thorns(v.get_status(), CombatState.Side.ENEMY, cells, 6.0, 6.0, 1)
	var hp0: float = state.enemy_hp
	var php0: float = state.player_hp
	var placed: bool = v.select_piece(0, false) and v.aim_at_cell(boss + (case["offset"] as Vector2i)) and v.confirm_placement()
	var opened: bool = v.press_cast()
	var flow: CutFlow = v.get_cut_flow()
	var chosen: bool = opened and flow.choose(id)
	print(id, " placed ", placed, " menu ", opened, " chosen ", chosen, " hand ", flow.get_hand())
	if not chosen:
		return
	_hits = 0
	while v.get_cut_actor().is_swinging():
		await process_frame
	for _i: int in 50:
		await process_frame
	if (case["boss_after"] as Vector2i) != NO_MOVE:
		state.set_enemy_cell(boss + (case["boss_after"] as Vector2i))
	for _i: int in 300:
		await process_frame
		if _hits >= int(case["hits"]):
			break
	for _i: int in FRAMES_AFTER:
		await process_frame
	var path: String = OUT.path_join(str(case["name"]) + ".png")
	root.get_texture().get_image().save_png(path)
	_saved.append(path)
	var fx: StatusEffects = v.get_status()
	print(id, " boss damage %.1f hero hp %.1f -> %.1f boss %s -> %s pinned %s ran %d traps %d wards %d pillars %d wall %d" % [
		hp0 - state.enemy_hp, php0, state.player_hp, str(boss), str(state.enemy_cell), str(fx.is_pinned(CombatState.Side.ENEMY)),
		fx.fragile_stacks(CombatState.Side.ENEMY), fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP).size(),
		fx.field_cells(CombatState.Side.PLAYER, StatusEffects.KIND_WARD).size(), fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_PILLAR).size(),
		fx.wall_cells().size()])
	for _i: int in 120:
		await process_frame
	v.get_skill_cooldowns().clear(id)
