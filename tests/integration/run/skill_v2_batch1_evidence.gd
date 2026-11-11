extends SceneTree
## Skill v2 batch 1 evidence: in a REAL ch1 battle (main.tscn, GameFlow.enter_test_floor, boss frozen) casts each of
## the 4 batch-1 cards from the bag through the card menu and saves the in-game frame right after its damaging impact
## under production/qa/evidence/skill-v2-batch1/ (coding-standards: a parse check is not a run). Modelled on
## tools/qa/impact_footage.gd. Not a test (no *_test.gd name): the suite runner skips it.
## Run (WINDOWED, not headless, muted): godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch1_evidence.gd

const OUT: String = "res://production/qa/evidence/skill-v2-batch1"
## card -> {shape, offset (anchor relative to the boss), guard (Guard given to the boss before the cast), name}.
## The enemy half of ch1 is 3 cells wide, so a bar4 never fits: t4 / bar3 carry the 4- and 3-cell cases.
const CASES: Array[Dictionary] = [
	{"id": "min_tre", "shape": "bar2", "offset": Vector2i(0, 0), "guard": 0.0, "name": "01-min-tre-detonation-push"},
	{"id": "chuoi_set", "shape": "t4", "offset": Vector2i(-1, -1), "guard": 0.0, "name": "02-chuoi-set-last-link-hit"},
	{"id": "dap_vo", "shape": "bar2", "offset": Vector2i(0, 0), "guard": 6.0, "name": "03-dap-vo-guard-break"},
	{"id": "thuong_xuyen", "shape": "bar3", "offset": Vector2i(-1, 0), "guard": 0.0, "name": "04-thuong-xuyen-pierce"},
]
## Frames drawn after the damaging impact before the capture (the HIT label and the impact visual are up).
const FRAMES_AFTER_HIT: int = 3

var _saved: Array[String] = []
var _hit: bool = false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("kiem_si")
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
			_hit = true)
	var lib := PieceLibrary.load_from_file()
	for case: Dictionary in CASES:
		# the mine pushes the boss: put it back on the centre cell before every cast
		state.set_enemy_cell(Vector2i(grid.side_cols + 1, 1))
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
	p.piece = lib.make_piece(shape, 0)
	p.label = shape
	hold.place(p, 0)
	v._deck = Deck.from_array([id, id, id, id] as Array[String], 1)
	if float(case["guard"]) > 0.0:
		v.get_status().guard(CombatState.Side.ENEMY, float(case["guard"]), 30.0)
	var state: CombatState = v.get_state()
	var boss: Vector2i = state.enemy_cell
	var hp0: float = state.enemy_hp
	var placed: bool = v.select_piece(0, false) and v.aim_at_cell(boss + (case["offset"] as Vector2i)) and v.confirm_placement()
	var opened: bool = v.press_cast()
	var flow: CutFlow = v.get_cut_flow()
	var chosen: bool = opened and flow.choose(id)
	print(id, " placed ", placed, " menu ", opened, " chosen ", chosen, " hand ", flow.get_hand())
	if not chosen:
		return
	_hit = false
	for _i: int in 600:
		await process_frame
		if _hit:
			break
	for _i: int in FRAMES_AFTER_HIT:
		await process_frame
	var path: String = OUT.path_join(str(case["name"]) + ".png")
	root.get_texture().get_image().save_png(path)
	_saved.append(path)
	print(id, " damage %.1f boss %s -> %s guard %.1f ran %d" % [hp0 - state.enemy_hp, str(boss), str(state.enemy_cell),
		v.get_status().guard_amount(CombatState.Side.ENEMY), v.get_status().fragile_stacks(CombatState.Side.ENEMY)])
	# let the cooldown and the leftover visuals pass
	for _i: int in 120:
		await process_frame
	v.get_skill_cooldowns().clear(id)
