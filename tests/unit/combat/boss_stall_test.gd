extends SceneTree
## TD-022: the boss never stalls with a full piece hand. A FULL hand whose every candidate scores below
## min_cut_score casts its best candidate anyway (it can pick up nothing better); a PARTIAL hand still
## respects the bar. Covers the balanced and cautious sets, the learning quick_cut_bias (player hand full
## for >= full_hand_seconds) and the controller end to end. Headless; FAILS=N. Deterministic: noise 0, fixed seeds.

const SEED: int = 23
## Player step cooldown of a 4x3 half (CombatConfig.step_cooldown_for), the arena where the stall was measured.
const PLAYER_STEP_SEC: float = 0.33
const THINK_SEC: float = 1.0
const TICK_SEC: float = 0.05

var fails: int = 0
var lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	lib = PieceLibrary.load_from_file()
	_test_full_hand_of_singles_casts()
	_test_partial_hand_respects_bar()
	_test_cautious_full_hand_casts()
	_test_quick_cut_bias_full_hand_casts()
	_test_controller_full_hand_swings()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _brain_config(set_name: String = "") -> BossBrainConfig:
	var config: BossBrainConfig = BossBrainConfig.load_from_file()
	config.noise = 0.0
	if not set_name.is_empty():
		config.active_set = set_name
	return config


func _point(id: String) -> FieldPoint:
	var p := FieldPoint.new()
	p.piece = lib.make_piece(id)
	p.label = p.piece.shape_id
	return p


# A pure brain world on a 4x3 half: piece hand of 3 slots holding [param ids], standing player.
func _world(ids: Array, config: BossBrainConfig) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1.0e6, 1.0e6)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var hand: HoldSlots = HoldSlots.create_piece_hand(3)
	for id: String in ids:
		hand.place_in_first_free(_point(id))
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var drops := FieldDrops.new(drops_config, grid.enemy_cells(), SEED)
	var brain := BossBrain.new(config, grid, cut_config, skill_config, SEED)
	var ctx: Dictionary = {
		"state": state, "hand": hand, "drops": drops,
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, config.step_cooldown_sec),
		"actor": CutActor.new(cut_config, CombatState.Side.ENEMY),
		"cooldowns": SkillCooldowns.new(), "player_actor": CutActor.new(cut_config, CombatState.Side.PLAYER),
		"player_step_cooldown": PLAYER_STEP_SEC,
	}
	return {"grid": grid, "state": state, "hand": hand, "brain": brain, "ctx": ctx, "config": config}


func _decide(w: Dictionary) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, false)
	return brain.decide(w["ctx"])


# Highest candidate score of the last decision (-INF when none was scored).
func _best_candidate(w: Dictionary) -> float:
	var best: float = -INF
	for row: Dictionary in (w["brain"] as BossBrain).last_debug().get("cut_candidates", []):
		best = maxf(best, float(row["score"]))
	return best


func _min_cut(w: Dictionary) -> float:
	var config: BossBrainConfig = w["config"]
	return float(config.weights_for(config.active_set)["min_cut_score"])


# ------------------------------------------------------------------ tests

func _test_full_hand_of_singles_casts() -> void:
	var w: Dictionary = _world(["mono", "mono", "mono"], _brain_config())
	var action: Dictionary = _decide(w)
	var best: float = _best_candidate(w)
	_check("balanced, 3 singles: every candidate is below min_cut_score (the stall case)", best < _min_cut(w),
		"best=%.2f min=%.2f" % [best, _min_cut(w)])
	_check("balanced, full hand of 3 singles: the boss still casts", str(action["type"]) == "cut", str(action))
	var cells: Array = action.get("cells", [])
	var player_cell: Vector2i = (w["state"] as CombatState).player_cell
	_check("full-hand cast is the best candidate (covers the standing player)", cells.has(player_cell),
		"cells=%s player=%s" % [str(cells), str(player_cell)])
	_check("debug marks the full-hand override", bool((w["brain"] as BossBrain).last_debug().get("full_hand_override", false)))


func _test_partial_hand_respects_bar() -> void:
	var w: Dictionary = _world(["mono", "mono"], _brain_config())
	var action: Dictionary = _decide(w)
	var best: float = _best_candidate(w)
	_check("balanced, partial hand of 2 singles: candidates were scored", best > -INF)
	_check("balanced, partial hand of 2 singles: below the bar, no cast", str(action["type"]) != "cut",
		"type=%s best=%.2f min=%.2f" % [str(action["type"]), best, _min_cut(w)])
	var w1: Dictionary = _world(["mono"], _brain_config())
	_check("balanced, partial hand of 1 single: no cast", str(_decide(w1)["type"]) != "cut")


func _test_cautious_full_hand_casts() -> void:
	var w: Dictionary = _world(["mono", "mono", "mono"], _brain_config("cautious"))
	var action: Dictionary = _decide(w)
	_check("cautious (min_cut_score 4), full hand of 3 singles: the boss still casts", str(action["type"]) == "cut",
		"best=%.2f min=%.2f" % [_best_candidate(w), _min_cut(w)])
	var w2: Dictionary = _world(["mono", "mono"], _brain_config("cautious"))
	_check("cautious, partial hand of 2 singles: no cast", str(_decide(w2)["type"]) != "cut")


func _test_quick_cut_bias_full_hand_casts() -> void:
	var config: BossBrainConfig = _brain_config()
	var learning := BossLearning.new(config.learning)
	learning.tick(float(config.learning["full_hand_seconds"]) + 0.5, true)
	var bias: float = float(learning.get_modifiers()["quick_cut_bias"])
	_check("learning: player hand full >= full_hand_seconds turns quick_cut_bias on", bias > 1.0, "bias=%.2f" % bias)
	var w: Dictionary = _world(["mono", "mono", "mono"], config)
	(w["brain"] as BossBrain).set_learning(learning)
	var action: Dictionary = _decide(w)
	_check("quick_cut_bias on, full hand of 3 singles: the boss still casts", str(action["type"]) == "cut",
		"best=%.2f min=%.2f" % [_best_candidate(w), _min_cut(w)])
	var w2: Dictionary = _world(["mono", "mono"], config)
	(w2["brain"] as BossBrain).set_learning(learning)
	_check("quick_cut_bias on, partial hand of 2 singles: no cast", str(_decide(w2)["type"]) != "cut")


func _test_controller_full_hand_swings() -> void:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1.0e6, 1.0e6)
	var config: BossBrainConfig = _brain_config()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	drops_config.piece_spawn_interval_sec = 1.0e9
	var cut_config: CutConfig = CutConfig.load_from_file()
	var boss := BossController.new(
		state, grid, cut_config, SkillConfig.load_from_file(), config, drops_config, HoldSlotsConfig.new(), SEED
	)
	boss.enable_pieces(lib, "", SEED, 2)
	boss.set_player_step_cooldown(PLAYER_STEP_SEC)
	for i: int in boss.get_hand().get_slot_count():
		boss.get_hand().place_in_first_free(_point("mono"))
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var swung: bool = false
	var t: float = 0.0
	while t < 3.0 and not swung:
		boss.tick(TICK_SEC, player_actor)
		swung = boss.get_actor().is_swinging()
		t += TICK_SEC
	_check("controller, full hand of singles, standing player: a swing starts within 3 s", swung, "t=%.2f" % t)
	_check("controller: the cast spent pieces from the full hand", not boss.get_hand().is_full(),
		"held=%d" % boss.get_hand().get_occupied_count())
