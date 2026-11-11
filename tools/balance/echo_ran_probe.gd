extends SceneTree
## Skill v2 batch 5, Deferred 13: echo waves and Rạn. Measures, on a boss carrying Rạn stacks, the damage of the
## cards that echo (Hồi Âm's and Chuông Thánh's own echo waves, the mark's echo on Kiếm Khí) under the two readings
## of the catalog's "an echo never consumes Rạn twice in one wave":
##   A (shipped, 02-design-decisions.md §7): an echo wave neither spends Rạn nor takes the Rạn multiplier.
##   B (the looser reading): an echo wave is a damage event like any other: it spends a stack and takes x1.5.
## Pure CutEffects.apply per wave (no arbiter clock): parent wave(s) then the echo wave(s) at the card's echo mult,
## with 0 / 1 / 3 Rạn on the boss before the cast. Prints one table; the decision is written in 02-design-decisions.md.
## Run: godot --headless --path . -s res://tools/balance/echo_ran_probe.gd

const HERO := Vector2i(1, 1)
const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
## card -> {waves: parent wave mults, echoes: echo wave mults}
const CASES: Array[Dictionary] = [
	{"id": "hoi_am", "label": "Hồi Âm bar3 (hit + echo 0.6)", "waves": [1.0], "echoes": [0.6]},
	{"id": "chuong_thanh", "label": "Chuông Thánh bar3 (hit + 2 echoes 0.5)", "waves": [1.0], "echoes": [0.5, 0.5]},
	{"id": "kiem_khi", "label": "Kiếm Khí bar3 on a marked boss (hit + mark echo 0.6)", "waves": [1.0], "echoes": [0.6]},
]


func _init() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cc: CutConfig = CutConfig.load_from_file()
	var cfg: CombatConfig = CombatConfig.load_from_file()
	print("echo_ran_probe: boss 1000 HP, no defense, reactions global (combat.json), Rạn x%.2f per stack" % cfg.fragile_mult)
	print("%-52s %5s | %8s %8s %8s | %s" % ["case", "Rạn", "A total", "B total", "B / A", "stacks left A / B"])
	for case: Dictionary in CASES:
		for stacks: int in [0, 1, 3]:
			var a: Dictionary = _run(case, stacks, true, sc, cc, cfg)
			var b: Dictionary = _run(case, stacks, false, sc, cc, cfg)
			print("%-52s %5d | %8.2f %8.2f %8.3f | %d / %d" % [case["label"], stacks, a["total"], b["total"],
				float(b["total"]) / maxf(float(a["total"]), 0.001), a["left"], b["left"]])
	# the shared cards the boss may draw (Deferred 3): a smoke of the list, not a tuning
	var shared: Array[String] = []
	for id: String in ["dia_chan", "loc_cuon", "bang_vo", "hoa_bang", "hoi_am"]:
		if sc.boss_card_order().has(id):
			shared.append(id)
	print("boss_card_order holds the batch-2 shared cards: %s" % str(shared))
	quit(0)


# One case: parent waves then echo waves, each a CutEffects.apply; [param rule_a] = the echo option on the echo waves.
func _run(case: Dictionary, stacks: int, rule_a: bool, sc: SkillConfig, cc: CutConfig, cfg: CombatConfig) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, Vector2i(5, 1))
	var fx := StatusEffects.new()
	cfg.configure_status(fx)
	if stacks > 0:
		fx.apply_fragile(CombatState.Side.ENEMY, stacks)
	var id: String = str(case["id"])
	var base: Dictionary = {"reactions": cfg.reactions(), "cast_cell_count": BAR3.size()}
	for m: float in case["waves"]:
		var o: Dictionary = base.duplicate()
		o["impact_mult"] = m
		CutEffects.apply(state, grid, CombatState.Side.PLAYER, BAR3, id, cc, sc, fx, Callable(), 1, Callable(), Callable(), o)
	for m: float in case["echoes"]:
		var o: Dictionary = base.duplicate()
		o["impact_mult"] = m
		o["echo"] = rule_a
		CutEffects.apply(state, grid, CombatState.Side.PLAYER, BAR3, id, cc, sc, fx, Callable(), 1, Callable(), Callable(), o)
	return {"total": 1000.0 - state.enemy_hp, "left": fx.fragile_stacks(CombatState.Side.ENEMY)}
