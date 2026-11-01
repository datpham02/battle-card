extends SceneTree
## Phase 2 P2.2 wiring checks (spec design/quick-specs/phase2-misty-forest-2026-11-01.md 3.1, 3.6, 3.9, F4, F6):
## RunConfig `brain` keys and pattern tempo, FloorLayer.pattern_telegraph_state without locked cells,
## StatusEffects.since_lock_ended, CombatView.trait_warning_cells on the player's half.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_wiring_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const SEED: int = 5
## Boundary values: the region normalize / floor scaling step_mult whose product is the pattern tempo.
const REGION_STEP: float = 1.05
const FLOOR_STEP: float = 1.2

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	_test_run_config_brain()
	_test_telegraph_state_skips_locked()
	_test_since_lock_ended()
	await _test_trait_warning_cells()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _match_raw(extra: Dictionary) -> Dictionary:
	var raw: Dictionary = {"id": "m", "boss_max_hp": 80}
	raw.merge(extra, true)
	return raw


func _test_run_config_brain() -> void:
	var plain: Dictionary = RunConfig.from_dictionary({"matches": [_match_raw({})]}).matches[0]
	var block: Dictionary = RunConfig.from_dictionary({"matches": [_match_raw({"brain": "block"})]}).matches[0]
	var keys: Array = plain.keys()
	keys.sort()
	_check("no brain: no brain/enemy/pattern_tempo_mult key", not plain.has("brain") and not plain.has("enemy") and not plain.has("pattern_tempo_mult"))
	var expected: Array = keys.duplicate()
	expected.append("brain")
	expected.sort()
	var got: Array = block.keys()
	got.sort()
	_check("brain block adds only `brain`", got == expected, str(got))
	# Pattern: tempo = region x floor step_mult (applied to the RAW match, as from_node does).
	var raw: Dictionary = _match_raw({"brain": "pattern", "enemy": "dev_pattern_dummy"})
	RunConfig._apply_scaling(raw, {"step_mult": REGION_STEP}, {"step_mult": FLOOR_STEP})
	var pat: Dictionary = RunConfig.from_dictionary({"matches": [raw]}).matches[0]
	_check("pattern brain + enemy carried", pat.get("brain") == "pattern" and pat.get("enemy") == "dev_pattern_dummy")
	_check("pattern_tempo_mult = region x floor step_mult", is_equal_approx(float(pat.get("pattern_tempo_mult", 0.0)), REGION_STEP * FLOOR_STEP),
		str(pat.get("pattern_tempo_mult")))
	var raw_block: Dictionary = _match_raw({})
	RunConfig._apply_scaling(raw_block, {"step_mult": REGION_STEP}, {"step_mult": FLOOR_STEP})
	_check("block match gets no tempo from scaling", not raw_block.has("pattern_tempo_mult"))
	# Unknown brain / pattern without enemy: block brain (warning printed).
	var unknown: Dictionary = RunConfig.from_dictionary({"matches": [_match_raw({"brain": "nonsense", "enemy": "x"})]}).matches[0]
	_check("unknown brain falls back to block", unknown.get("brain") == RunConfig.BRAIN_BLOCK and not unknown.has("enemy"))
	var no_enemy: Dictionary = RunConfig.from_dictionary({"matches": [_match_raw({"brain": "pattern"})]}).matches[0]
	_check("pattern without enemy falls back to block", no_enemy.get("brain") == RunConfig.BRAIN_BLOCK and not no_enemy.has("pattern_tempo_mult"))


func _test_telegraph_state_skips_locked() -> void:
	var cfg: EnemySkillsConfig = Fx.config()
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), cfg, "fx_single", SEED)
	var ctrl: PatternController = w["ctrl"]
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var cells: Array[Vector2i] = []
	for _i: int in 200:
		status.tick(0.05, state)
		ctrl.tick(0.05)
		if ctrl.get_stage() == PatternController.Stage.WARNING and ctrl.telegraph_cells().size() >= 2:
			cells = ctrl.telegraph_cells()
			break
	_check("a 2+ cell warning is showing", cells.size() >= 2, str(cells))
	if cells.size() < 2:
		return
	var before: Dictionary = FloorLayer.pattern_telegraph_state(ctrl, CombatConfig.new(), false)
	_check("state lists every red cell", (before.get("cells", []) as Array).size() == cells.size())
	var locked: Vector2i = cells[0]
	status.apply_drop(P, [locked] as Array[Vector2i], 1.0, 1.0)
	_check("drop locks the cell", status.is_locked(locked))
	var after: Dictionary = FloorLayer.pattern_telegraph_state(ctrl, CombatConfig.new(), false)
	var shown: Array = after.get("cells", [])
	_check("locked cell not drawn red", not shown.has(locked) and shown.size() == cells.size() - 1, str(shown))
	_check("no pattern = empty state", FloorLayer.pattern_telegraph_state(null, CombatConfig.new(), false).is_empty())


func _test_since_lock_ended() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var status := StatusEffects.new()
	_check("never locked = INF", is_inf(status.since_lock_ended(P)))
	status.root(P, 0.5)
	_check("0 while rooted", status.since_lock_ended(P) == 0.0)
	status.tick(0.6, state)
	var after: float = status.since_lock_ended(P)
	_check("counts after the root ends", after > 0.0 and after < 0.2, str(after))
	status.tick(0.3, state)
	_check("keeps counting", status.since_lock_ended(P) > after)
	status.clear()
	_check("clear() resets to INF", is_inf(status.since_lock_ended(P)))


func _test_trait_warning_cells() -> void:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"traits": [{"id": "row_burner", "params": {}}]}
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	_check("block match is not pattern", not v.is_pattern_brain() and v.get_pattern_controller() == null)
	var host: TraitHost = v.get_trait_host()
	var rb: RowBurnerTrait = host.get_trait("row_burner") as RowBurnerTrait if host != null else null
	_check("row_burner present", rb != null)
	if rb != null:
		rb.on_tick(1000.0)
		var cells: Array = v.trait_warning_cells()
		var all_player: bool = not cells.is_empty()
		for cell: Vector2i in cells:
			all_player = all_player and v.get_grid().is_player_cell(cell)
		_check("trait_warning_cells = the row on the player's half", all_player and cells.size() == rb.get_warning_cells().size()
			and cells.has(v.get_state().player_cell), str(cells))
	root.remove_child(holder)
	holder.free()
