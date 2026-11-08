extends SceneTree
## Cast Commitment parity of the balance simulator (tools/balance/sim_core.gd) with CombatView, Ngàn Kiếm prototype:
## the channel is longer by channel_extend_sec, the bot cannot step while channeling or in the 0.13 s commit lock,
## steps again afterwards, and the impact times after the card choice match the game's. Other cards untouched.
## Deterministic (fixed seeds); the boss is made idle so nothing interrupts the cast.
## Run: godot --headless --path . -s res://tests/unit/balance/sim_commitment_test.gd

const SimCore = preload("res://tools/balance/sim_core.gd")
const DT: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_sim_channel_root_and_commit("ngan_kiem", true)
	test_sim_channel_root_and_commit("tram_dia", false)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _core_with_match() -> Object:
	var core = SimCore.new()
	core.apply_args(PackedStringArray())
	core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var id: String = chapters.match_ids(0)[0]
	var m: Dictionary = core.prepare_match(RunConfig.from_node(chapters, 0, id, "battle", 1, -1).matches[0] as Dictionary)
	m["chapter_id"] = chapters.chapter_id(0)
	var character: Dictionary = core.prepare_character(core.characters.get_character("kiem_si"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	core.rng = rng
	core._setup(m, character, [{"id": "ngan_kiem", "level": 1}], -1.0, 7)
	core.invulnerable = true
	core.boss.set_active(false)
	return core


func _row_cells(core: Object) -> Array[Vector2i]:
	var grid: BoardGrid = core.grid
	var out: Array[Vector2i] = []
	for r: int in [1, 0, 2]:
		for c: int in grid.total_cols:
			var cell := Vector2i(c, r)
			if grid.is_enemy_cell(cell) and out.size() < 4:
				out.append(cell)
	return out


func _free_dir(core: Object) -> Vector2i:
	var grid: BoardGrid = core.grid
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if grid.is_player_cell(core.state.player_cell + d):
			return d
	return Vector2i.ZERO


func test_sim_channel_root_and_commit(card: String, commitment: bool) -> void:
	var core: Object = _core_with_match()
	var cells: Array[Vector2i] = _row_cells(core)
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("bar4", 0)]
	var ctx: Dictionary = CastContext.build(card, 1, pieces, [cells], core.cards.get_skill(card)["delivery"], false,
		CombatState.Side.PLAYER, core.state.player_cell)
	var actor: CutActor = core.actor
	var t0: float = core.arbiter.clock()
	ck("%s: the cast starts" % card, cells.size() == 4 and actor.begin_swing(cells, card, true, 1, -1.0, {}, ctx))
	var want: float = 0.2 + 0.25 * 4.0 + (0.28 if commitment else 0.0)
	ck("%s: channel / swing %.2f s (as CombatView)" % [card, want], is_equal_approx(actor.get_duration(), want), "%.3f" % actor.get_duration())
	var dir: Vector2i = _free_dir(core)
	var start: Vector2i = core.state.player_cell
	for i: int in 50:
		core._world_tick(DT)
	ck("%s: mid-channel the bot step is %s" % [card, "refused" if commitment else "accepted"],
		core._bot_step(dir) != commitment and (core.state.player_cell == start) == commitment)
	if not commitment:
		return
	while actor.is_swinging():
		core._world_tick(DT)
	var commit_t: float = core.arbiter.clock()
	ck("%s: commit lock: rooted right after the swing end" % card, core._is_cast_rooted() and not core._bot_step(dir))
	var first_at: float = core.arbiter.first_event_at()
	ck("%s: first impact 1.70 s after the choice (0.22 after the commit)" % card, absf(first_at - t0 - 1.70) < DT + 0.0001,
		"%.3f" % (first_at - t0))
	while core._is_cast_rooted():
		core._world_tick(DT)
	ck("%s: lock ends 0.13 s after the commit" % card, absf(core.arbiter.clock() - commit_t - 0.13) < DT + 0.0001,
		"%.3f" % (core.arbiter.clock() - commit_t))
	for i: int in 60:
		core._world_tick(DT)  # the mover's own step cooldown runs out
	ck("%s: resolution: the bot steps again" % card, core._bot_step(dir) and core.state.player_cell == start + dir)
