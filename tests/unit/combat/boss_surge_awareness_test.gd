extends SceneTree
## Skill v2 Trảm Địa boss awareness (BossBrain ctx.pending_threat, SwingArbiter.pending_cells): once the Knight's swing
## has resolved, the surge still running on the clock keeps the cells the boss SAW during the swing as incoming, with the
## real time left; cells it never saw are not revealed; without a pending surge nothing changes (legacy). Also checks
## SwingArbiter.pending_cells against a real tram_dia cast.
## Run: godot --headless --path . -s res://tests/unit/combat/boss_surge_awareness_test.gd

const SEED: int = 7
const THINK_SEC: float = 1.0
const BOSS := Vector2i(4, 1)
const MASK: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	test_pending_cells_follow_the_schedule()
	test_seen_surge_keeps_the_boss_dodging()
	test_unseen_cells_are_not_revealed()
	test_no_pending_is_legacy()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _config() -> BossBrainConfig:
	return BossBrainConfig.from_dictionary({
		"step_cooldown_sec": 0.55, "think_interval_sec": 0.0, "reaction_sec": 0.0, "noise": 0.0,
		"active_set": "t",
		"sets": {"t": {
			"dodge_danger": 10.0, "idle_bias": 0.2, "retreat_bonus": 0.0, "pickup_value": 0.0,
			"combo_chance": 0.0,
			"movement": {
				"move_commitment": 1.0, "move_noise": 0.0, "reaction_sec": 0.0, "path_style": "shortest",
				"juke_chance": 0.0, "wander_when_idle": false,
			},
		}},
	})


func _world() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1.0e6, 1.0e6, Vector2i(1, 1), BOSS)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var cfg: BossBrainConfig = _config()
	var brain := BossBrain.new(cfg, grid, cc, sc, SEED)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var ctx: Dictionary = {
		"state": state, "hand": HoldSlots.create_piece_hand(3), "drops": FieldDrops.new(drops_config, grid.enemy_cells(), SEED),
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, cfg.step_cooldown_sec),
		"actor": CutActor.new(cc, CombatState.Side.ENEMY), "cooldowns": SkillCooldowns.new(),
		"player_actor": player, "status": StatusEffects.new(),
	}
	return {"brain": brain, "ctx": ctx, "state": state, "player": player}


func _decide(w: Dictionary, swinging: bool) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, swinging)
	return brain.decide(w["ctx"])


func _leaves(action: Dictionary, cells: Array[Vector2i]) -> bool:
	if str(action.get("type", "")) != "move":
		return false
	return not cells.has(BOSS + (action["direction"] as Vector2i))


func test_pending_cells_follow_the_schedule() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(5, 1))
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var arb := SwingArbiter.new(state, grid, player, CutActor.new(cc, CombatState.Side.ENEMY), cc, sc, fx)
	var piece: Piece = PieceLibrary.load_from_file().make_piece("bar3", 0)
	var pieces: Array[Piece] = [piece]
	var ctx: Dictionary = CastContext.build("tram_dia", 1, pieces, [MASK], sc.get_skill("tram_dia")["delivery"], false,
		CombatState.Side.PLAYER, Vector2i(1, 1))
	player.begin_swing(MASK, "tram_dia", true, 1, 0.5, {}, ctx)
	arb.tick(0.55)
	var p: Dictionary = arb.pending_cells(CombatState.Side.PLAYER)
	_check("after the burst: the two surge cells pending, 0.16 s to the next", (p.get("cells", []) as Array) == [Vector2i(4, 1), Vector2i(5, 1)]
		and absf(float(p.get("time_left", -1.0)) - 0.16) < 0.0001, str(p))
	_check("the enemy side has nothing pending", arb.pending_cells(CombatState.Side.ENEMY).is_empty())
	arb.tick(1.0)
	_check("after the hit: nothing pending (max_hits reached / all fired)", arb.pending_cells(CombatState.Side.PLAYER).is_empty())


func test_seen_surge_keeps_the_boss_dodging() -> void:
	var w: Dictionary = _world()
	var player: CutActor = w["player"]
	player.begin_swing(MASK, "tram_dia", true, 1, 1.0)
	var during: Dictionary = _decide(w, true)
	_check("during the swing the boss dodges the visible mask (legacy rule)", _leaves(during, MASK), str(during))
	player.cancel()
	w["ctx"]["pending_threat"] = {"cells": [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i], "time_left": 0.2}
	var after: Dictionary = _decide(w, false)
	_check("after the resolve the pending surge cells it saw are still avoided", _leaves(after, MASK), str(after))


func test_unseen_cells_are_not_revealed() -> void:
	var w: Dictionary = _world()
	w["ctx"]["pending_threat"] = {"cells": [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i], "time_left": 0.2}
	var a: Dictionary = _decide(w, false)
	_check("a surge the boss never saw (no swing seen) is ignored", not _leaves(a, MASK), str(a))


func test_no_pending_is_legacy() -> void:
	var w: Dictionary = _world()
	var player: CutActor = w["player"]
	player.begin_swing(MASK, "tram_dia", true, 1, 1.0)
	_decide(w, true)
	player.cancel()
	var a: Dictionary = _decide(w, false)
	_check("swing over and nothing pending: the boss does not keep dodging", not _leaves(a, MASK), str(a))
