extends SceneTree
## P2.2b (decision D13 / ADR-0001 A7): a 2x2 boss on the boss-only 6x4 arena. Part 1 is pattern_dodge_test's check on
## boss_hall with the dev fixture `dev_pattern_boss` (footprint 2x2): the perfect-dodger bot is never hit and the
## standing-still bot is damaged, for a few seeds (PatternController with the real StatusEffects / UnitMover).
## Part 2 runs a real CombatView match (`brain: pattern`, `enemy: dev_pattern_boss`, arena boss_hall, the BossBrain moving
## the boss between skills in anchor space): every frame the footprint is 4 cells and fits the enemy half, the boss's
## mover never leaves it half-off the board, and a card the arbiter resolves over all four footprint cells takes the
## single-hit damage once.
## Run: godot --headless --path . -s res://tests/integration/run/boss_footprint_dodge_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const ENEMY: String = "dev_pattern_boss"
const ARENA: String = "boss_hall"
const SEEDS: Array[int] = [1, 2, 3]
const MATCH_SEC: float = 30.0
const START_HP: float = 100.0
const VIEW_SEED: int = 4
const VIEW_STEP: float = 0.05
const VIEW_SEC: float = 20.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_part_dodge()
	await process_frame
	await _part_combat_view()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _part_dodge() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	for s: int in SEEDS:
		var dodge: Dictionary = Fx.world(ArenaLibrary.grid_for_spec({"shape": ARENA}, library, s), cfg, ENEMY, s, START_HP)
		var dstate: CombatState = dodge["state"]
		_check("seed %d: 2x2 footprint on boss_hall" % s, dstate.enemy_footprint_size() == 4 and dstate.grid.side_cols == 6 and dstate.grid.side_rows == 4)
		Fx.run(dodge["ctrl"], dstate, dodge["status"], dodge["mover"], MATCH_SEC, "dodge")
		var resolves: int = 0
		for ev: Dictionary in (dodge["ctrl"] as PatternController).event_log:
			if str(ev.get("event", "")) == "resolve":
				resolves += 1
		_check("seed %d: dodger untouched" % s, is_equal_approx(dstate.player_hp, START_HP) and resolves > 0,
			"hp=%s resolves=%d" % [dstate.player_hp, resolves])
		var still: Dictionary = Fx.world(ArenaLibrary.grid_for_spec({"shape": ARENA}, library, s), cfg, ENEMY, s, START_HP)
		Fx.run(still["ctrl"], still["state"], still["status"], still["mover"], MATCH_SEC, "still")
		_check("seed %d: standing still is damaged" % s, (still["state"] as CombatState).player_hp < START_HP,
			"hp=%s" % (still["state"] as CombatState).player_hp)


func _part_combat_view() -> void:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"brain": RunConfig.BRAIN_PATTERN, "enemy": ENEMY, "arena": {"shape": ARENA}, "arena_seed": VIEW_SEED,
		"boss_max_hp": 400.0}
	v.drops_seed = VIEW_SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	var state: CombatState = v.get_state()
	_check("CombatView: pattern brain on boss_hall", v.is_pattern_brain() and v.get_grid().side_cols == 6 and v.get_grid().side_rows == 4)
	_check("CombatView: 2x2 footprint at the start anchor", state.enemy_footprint_size() == 4 and state.enemy_fits(state.enemy_cell), str(state.enemy_cell))
	var always_fits: bool = true
	var anchors: Dictionary = {state.enemy_cell: true}
	var t: float = 0.0
	v.freeze_time = false
	while t < VIEW_SEC and not state.is_player_dead():
		v._process(VIEW_STEP)
		t += VIEW_STEP
		always_fits = always_fits and state.enemy_footprint_size() == 4 and state.enemy_fits(state.enemy_cell)
		anchors[state.enemy_cell] = true
	v.freeze_time = true
	_check("CombatView: the footprint fits the enemy half on every frame (%d anchors visited)" % anchors.size(), always_fits, str(anchors.keys()))
	# One card over all four footprint cells through the CutEffects path the arbiter uses: one hit.
	if not state.is_enemy_dead():
		var before: float = state.enemy_hp
		var cells: Array[Vector2i] = state.enemy_footprint_cells()
		var result: Dictionary = CutEffects.apply(state, v.get_grid(), CombatState.Side.PLAYER, cells, SkillConfig.FALLBACK_SKILL,
			CutConfig.load_from_file(), SkillConfig.load_from_file(), v.get_status())
		var single: float = CutConfig.load_from_file().slash_damage(cells.size())
		_check("CombatView: a 4-cell card on the 2x2 boss hits once", bool(result["hit"]) and float(result["damage"]) > 0.0
			and is_equal_approx(before - state.enemy_hp, float(result["damage"])) and float(result["damage"]) <= single * 1.0001,
			"lost %s, damage %s, slash(4) %s" % [before - state.enemy_hp, result["damage"], single])
	root.remove_child(holder)
	holder.free()
