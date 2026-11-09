extends SceneTree
## Hỏa Lôi parity of the balance simulator (tools/balance/sim_core.gd) with CombatView (docs/skill-v2/09-hoa-loi-design.md):
## the fixed 0.45 s cast, the bot rooted for the cast only and free during the fuse, the detonation 1.5 s after the swing
## end on the same arbiter, the whole-field damage, the burn left on every armed cell, the armed-field menu rules and
## the fz_ metrics. Deterministic (fixed seed); the boss is made idle so it neither moves nor attacks.
## Run: godot --headless --path . -s res://tests/unit/balance/sim_hoa_loi_test.gd

const SimCore = preload("res://tools/balance/sim_core.gd")
const DT: float = 0.01
const ID: String = "hoa_loi"

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_sim_cast_lock_fuse_and_burn()
	test_sim_menu_rules()
	test_predict_estimate()
	test_sim_square_clause_and_model_c()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _core() -> Object:
	var core = SimCore.new()
	core.apply_args(PackedStringArray())
	core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var id: String = chapters.match_ids(0)[0]
	var m: Dictionary = core.prepare_match(RunConfig.from_node(chapters, 0, id, "battle", 1, -1).matches[0] as Dictionary)
	m["chapter_id"] = chapters.chapter_id(0)
	var character: Dictionary = core.prepare_character(core.characters.get_character("phap_su"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	core.rng = rng
	core._setup(m, character, [{"id": ID, "level": 1}], -1.0, 7)
	core.invulnerable = true
	core.boss.set_active(false)
	if core.pattern != null:
		core.pattern = null
	return core


func _free_dir(core: Object) -> Vector2i:
	var grid: BoardGrid = core.grid
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if grid.is_player_cell(core.state.player_cell + d):
			return d
	return Vector2i.ZERO


func _bar2_on_boss(core: Object) -> Array[Vector2i]:
	var grid: BoardGrid = core.grid
	var b: Vector2i = core.state.enemy_cell
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.is_enemy_cell(b + d):
			return [b, b + d] as Array[Vector2i]
	return [b] as Array[Vector2i]


func test_sim_cast_lock_fuse_and_burn() -> void:
	var core: Object = _core()
	var cells: Array[Vector2i] = _bar2_on_boss(core)
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("bar2", 0)]
	var ctx: Dictionary = CastContext.build(ID, 1, pieces, [cells], core.cards.get_skill(ID)["delivery"], false,
		CombatState.Side.PLAYER, core.state.player_cell)
	var actor: CutActor = core.actor
	var hp0: float = core.state.enemy_hp
	var t0: float = core.arbiter.clock()
	ck("the cast starts", cells.size() == 2 and actor.begin_swing(cells, ID, true, 1, -1.0, {}, ctx))
	ck("sim cast time 0.45 s (cast_time_sec, as CombatView)", is_equal_approx(actor.get_duration(), 0.45), "%.3f" % actor.get_duration())
	var dir: Vector2i = _free_dir(core)
	var start: Vector2i = core.state.player_cell
	for i: int in 20:
		core._world_tick(DT)
	ck("mid-cast: the bot step is refused (lock profile)", core._is_cast_rooted() and not core._bot_step(dir) and core.state.player_cell == start)
	while actor.is_swinging():
		core._world_tick(DT)
	ck("swing end at 0.45 s; the hero is free (no commit lock)", absf(core.arbiter.clock() - t0 - 0.45) < DT + 0.0001
		and not core._is_cast_rooted())
	var first_at: float = core.arbiter.first_event_at()
	ck("detonation 1.95 s after the choice (0.45 + 1.5)", absf(first_at - t0 - 1.95) < DT + 0.0001, "%.3f" % (first_at - t0))
	for i: int in 70:
		core._world_tick(DT)
	ck("the bot steps during the fuse", core._bot_step(dir))
	while core.arbiter.clock() < first_at + 0.02:
		core._world_tick(DT)
	var want: float = maxf(6.0 * 2.0 * 2.0 - core.arbiter.boss_defense, 1.0)
	ck("whole-field damage 6 x 2 x 2.0 (minus the boss defense)", absf(hp0 - core.state.enemy_hp - want) < 0.01,
		"lost %.2f want %.2f" % [hp0 - core.state.enemy_hp, want])
	ck("every armed cell burns", core.status.burning_cells().size() == 2)
	ck("fz metrics: 1 blast, 1 hit, 2 cells, record k=1+", int(core.ms["fz_events"]) == 1 and int(core.ms["fz_hits"]) == 1
		and int(core.ms["fz_cells"]) == 2 and int(((core.ms["fz_log"] as Array)[0] as Dictionary)["k"]) >= 1)


func test_sim_menu_rules() -> void:
	var core: Object = _core()
	var cells: Array[Vector2i] = _bar2_on_boss(core)
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("bar2", 0)]
	var ctx: Dictionary = CastContext.build(ID, 1, pieces, [cells], core.cards.get_skill(ID)["delivery"], false,
		CombatState.Side.PLAYER, core.state.player_cell)
	core.actor.begin_swing(cells, ID, true, 1, -1.0, {}, ctx)
	while core.actor.is_swinging():
		core._world_tick(DT)
	var c: Dictionary = core.availability_context()
	var count_fn: Callable = c[SkillAvailability.CTX_ARMED_COUNT_FN]
	ck("sim availability context counts the armed field", int(count_fn.call(ID)) == 1)
	var open: Array[Vector2i] = SkillAvailability.delayed_open_cells(cells, core.arbiter.armed_cells(CombatState.Side.PLAYER), core.status)
	ck("sim: the same cells have nothing left to arm", open.is_empty())


# Evaluation-only predictive policy: the production default stays "baseline"; the estimate rates a field covering the
# boss and all its open exits far above a lone cell beside it.
func test_predict_estimate() -> void:
	var core: Object = _core()
	ck("the sim bot's fuse policy defaults to baseline", str(core.bot.get("fuse_policy", "")) == "baseline")
	var b: Vector2i = core.state.enemy_cell
	var full: Array[Vector2i] = [b]
	full.append_array(core._boss_open_exits())
	var lone: Array[Vector2i] = [b]
	var pf: float = core.fuse_hit_estimate(full, "hoa_loi")
	var pl: float = core.fuse_hit_estimate(lone, "hoa_loi")
	ck("predict estimate: full cover >= 0.85 > lone cell", pf >= 0.85 and pl < 0.4, "full %.2f lone %.2f" % [pf, pl])


# Parity fix 2026-11-09: the sim's own cast path (_on_skill_chosen) carries the CastContext, so the square clause holds
# (1.8 s, x2.4) exactly as in CombatView, and the damage follows the card's damage_cells_rule (Model C: a 1-cell boss
# counts min(4, 1 + 1) = 2 cells).
func test_sim_square_clause_and_model_c() -> void:
	var core: Object = _core()
	var grid: BoardGrid = core.grid
	var b: Vector2i = core.state.enemy_cell
	var piece: Piece = PieceLibrary.load_from_file().make_piece("square", 0)
	var cells: Array[Vector2i] = []
	for anchor: Vector2i in [b, b - Vector2i(1, 0), b - Vector2i(0, 1), b - Vector2i(1, 1)]:
		var c: Array[Vector2i] = piece.cells_at(anchor)
		var ok: bool = c.has(b)
		for x: Vector2i in c:
			ok = ok and grid.is_enemy_cell(x)
		if ok:
			cells = c
			break
	ck("a 2x2 placement over the boss exists", cells.size() == 4)
	core.plan.init(2, 0)
	core.plan.add_piece(0, piece, cells)
	var hp0: float = core.state.enemy_hp
	var t0: float = core.arbiter.clock()
	core._on_skill_chosen(ID, [] as Array[String], cells)
	while core.actor.is_swinging():
		core._world_tick(DT)
	var at: float = core.arbiter.first_event_at()
	ck("sim square: fuse 1.8 s after the 0.45 s cast (clause holds in the sim)", absf(at - t0 - 2.25) < DT + 0.0001, "%.3f" % (at - t0))
	while core.arbiter.clock() < at + 0.02:
		core._world_tick(DT)
	var want: float = maxf(6.0 * 2.0 * 2.4 - core.arbiter.boss_defense, 1.0)
	ck("sim Model C square on a 1-cell boss: 6 x 2 x 2.4 (= game)", absf(hp0 - core.state.enemy_hp - want) < 0.01,
		"lost %.2f want %.2f" % [hp0 - core.state.enemy_hp, want])
