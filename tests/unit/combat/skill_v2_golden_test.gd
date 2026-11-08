extends SceneTree
## Skill v2 B1 golden baseline (docs/skill-v2/02-design-decisions.md §8, §13 "Legacy-card behaviour changes"):
## every one of the 32 player cards in cards.json `card_order`, resolved through CutEffects.apply on fixed boards and
## fixed pre-states, at levels 1 and 3, must give exactly the outcome recorded from the pre-v2 build (damage, hit,
## keywords, push, burn / thorn zones, locked cells). B1 (cast context + impact schedule) must keep it green with NO
## expectation edits; B7 migrations change only their own card's rows.
## Run:     godot --headless --path . -s res://tests/unit/combat/skill_v2_golden_test.gd
## Record:  godot --headless --path . -s res://tests/unit/combat/skill_v2_golden_test.gd -- --record
##          (writes the fixture from the CURRENT code; only on purpose, never to make a failing run pass)

const FIXTURE: String = "res://tests/unit/combat/golden/skill_v2_cut_effects.json"
const ENEMY_HP: float = 1000.0
const PLAYER_HP: float = 1000.0
const ZONE_SEED: int = 7

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	if not ok:
		fails += 1
		print("FAIL " + name + ((" " + extra) if not extra.is_empty() else ""))


func _init() -> void:
	var record: bool = OS.get_cmdline_user_args().has("--record")
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cc: CutConfig = CutConfig.load_from_file()
	var cfg: CombatConfig = CombatConfig.load_from_file()
	# The golden pins the 32 LEGACY cards (resolve instant). Skill v2 cards (Trảm Địa, resolve arrival) are not legacy:
	# they have their own tests (tram_dia_test.gd); the fixture is never re-recorded to make room for them.
	var legacy: Array[String] = []
	for id: String in sc.card_order:
		if str(sc.get_skill(id).get("resolve", "instant")) == "instant":
			legacy.append(id)
	ck("32 legacy (instant) player cards in card_order", legacy.size() == 32, str(legacy.size()))
	var out: Dictionary = {}
	for id: String in legacy:
		for level: int in [1, 3]:
			for scen: Dictionary in scenarios():
				var key: String = "%s|L%d|%s" % [id, level, str(scen["name"])]
				out[key] = run_case(id, level, scen, sc, cc, cfg)
	if record:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE.get_base_dir()))
		var f: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "\t", true))
		f.close()
		print("RECORDED %d cases -> %s" % [out.size(), FIXTURE])
	else:
		var text: String = FileAccess.get_file_as_string(FIXTURE)
		var want: Variant = JSON.parse_string(text)
		ck("fixture present", want is Dictionary)
		if want is Dictionary:
			ck("case count", (want as Dictionary).size() == out.size(), "%d vs %d" % [(want as Dictionary).size(), out.size()])
			# Compare through the same JSON round trip so float / int formatting cannot differ.
			var got: Dictionary = JSON.parse_string(JSON.stringify(out)) as Dictionary
			for key: String in (want as Dictionary).keys():
				var a: String = JSON.stringify(got.get(key, null), "", true)
				var b: String = JSON.stringify((want as Dictionary)[key], "", true)
				ck("golden " + key, a == b, "\n  got  %s\n  want %s" % [a, b])
	print("CASES %d" % out.size())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


## The fixed situations every card is resolved in (player casting on the enemy half of a 3x3 / 3x3 board, the enemy
## at (4,1); enemy half = columns 3..5).
static func scenarios() -> Array[Dictionary]:
	var c := func(pts: Array) -> Array[Vector2i]:
		var a: Array[Vector2i] = []
		for p: Array in pts:
			a.append(Vector2i(p[0], p[1]))
		return a
	return [
		{"name": "hit1", "cells": c.call([[4, 1]])},
		{"name": "hit3_row", "cells": c.call([[3, 1], [4, 1], [5, 1]])},
		{"name": "hit5_plus", "cells": c.call([[4, 0], [3, 1], [4, 1], [5, 1], [4, 2]])},
		{"name": "miss3_col", "cells": c.call([[3, 0], [3, 1], [3, 2]])},
		{"name": "hit3_ran_pinned", "cells": c.call([[3, 1], [4, 1], [5, 1]]), "fragile": 1, "pin": 1.0},
		{"name": "hit3_frost2", "cells": c.call([[4, 0], [4, 1], [4, 2]]), "frost": 2},
		{"name": "hit3_burning", "cells": c.call([[3, 1], [4, 1], [5, 1]]), "burn_cell": [4, 1]},
		{"name": "hit3_hole", "cells": c.call([[3, 1], [4, 1], [5, 1]]), "hole": [5, 1]},
		{"name": "boss2x2_4cells", "cells": c.call([[3, 0], [4, 0], [3, 1], [4, 1]]), "footprint": true},
		{"name": "edge_push", "cells": c.call([[5, 0], [5, 1], [5, 2]]), "enemy_at": [5, 1]},
	]


static func run_case(id: String, level: int, scen: Dictionary, sc: SkillConfig, cc: CutConfig, cfg: CombatConfig) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var enemy_at: Vector2i = Vector2i(4, 1)
	if scen.has("enemy_at"):
		enemy_at = Vector2i(scen["enemy_at"][0], scen["enemy_at"][1])
	if bool(scen.get("footprint", false)):
		enemy_at = Vector2i(3, 0)
	var state := CombatState.new(grid, PLAYER_HP, ENEMY_HP, Vector2i(1, 1), enemy_at)
	if bool(scen.get("footprint", false)):
		var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		state.set_enemy_footprint(fp)
	var fx := StatusEffects.new()
	cfg.configure_status(fx)
	var E: int = CombatState.Side.ENEMY
	if int(scen.get("fragile", 0)) > 0:
		fx.apply_fragile(E, int(scen["fragile"]))
	if float(scen.get("pin", 0.0)) > 0.0:
		fx.pin(E, float(scen["pin"]))
	if int(scen.get("frost", 0)) > 0:
		fx.apply_frost(E, int(scen["frost"]))
	if scen.has("burn_cell"):
		var bc: Array[Vector2i] = [Vector2i(scen["burn_cell"][0], scen["burn_cell"][1])]
		fx.ignite(bc, 3.0, 0.5, 1.5)
	if scen.has("hole"):
		var hc: Array[Vector2i] = [Vector2i(scen["hole"][0], scen["hole"][1])]
		fx.apply_drop(E, hc, 0.8, 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = ZONE_SEED
	var cells: Array[Vector2i] = scen["cells"]
	var r: Dictionary = CutEffects.apply(state, grid, CombatState.Side.PLAYER, cells, id, cc, sc, fx,
		Callable(), level, Callable(), Callable(), {"zone_rng": rng})
	return {
		"result": _plain(r),
		"enemy_hp": snappedf(state.enemy_hp, 0.0001),
		"player_hp": snappedf(state.player_hp, 0.0001),
		"enemy_cell": str(state.enemy_cell),
		"fragile": fx.fragile_stacks(E),
		"frost": fx.frost_stacks(E),
		"pinned": fx.is_pinned(E),
		"burning": _cells(fx.burning_cells()),
		"thorns_enemy": _cells(fx.thorn_cells(E)),
	}


# The result dict with vectors and arrays turned into stable strings (keys sorted on output).
static func _plain(r: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	for k: Variant in r.keys():
		var v: Variant = r[k]
		match typeof(v):
			TYPE_VECTOR2I:
				o[str(k)] = str(v)
			TYPE_ARRAY:
				o[str(k)] = _cells(v)
			TYPE_FLOAT:
				o[str(k)] = snappedf(v, 0.0001)
			TYPE_OBJECT:
				o[str(k)] = "<object>"
			_:
				o[str(k)] = v
	return o


static func _cells(a: Array) -> Array:
	var s: Array = []
	for v: Variant in a:
		s.append(str(v))
	s.sort()
	return s
