extends SceneTree
## Skill v2 batch 4, Dấu Tử (dau_tu) and the death mark (02-design-decisions.md §7): the card's hit marks the target
## for 3 s (mono 5 s; refreshed, never stacked; its own cast never triggers); the next damaging cast on the marked
## target executes x2 under 30 % HP and, 0.6 s after its last event, ONE echo wave of its last hit's cells lands at
## x0.6 as an echo cast (no Rạn spent or gained, no crit, no execute, no swing_resolved), the mark is gone; the mark
## expires on its own; a scheduled parent (sky drops) echoes its last hit; determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_death_mark_test.gd

const ID: String = "dau_tu"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_data()
	test_mark_applied_and_refreshed()
	test_next_cast_echoes_and_spends_the_mark()
	test_execute_under_thirty_percent()
	test_echo_ignores_ran_and_crit()
	test_mark_expires()
	test_scheduled_parent_echoes_its_last_hit()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"kind": ev["kind"], "mark": bool(ev.get("mark", false)), "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0)),
			"cells": ev["cells"]}))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(str(r.get("skill_id", "")) + ":" + str(r.get("echo", false))))
	var marks: Array = []
	fx.mark_applied.connect(func(_side: int, sec: float) -> void: marks.append("applied %.1f" % sec))
	fx.mark_triggered.connect(func(_side: int) -> void: marks.append("triggered"))
	fx.mark_expired.connect(func(_side: int) -> void: marks.append("expired"))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "done": done, "marks": marks}


func _ctx(sc: SkillConfig, id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, id: String, shape: String, cells: Array[Vector2i], sec: float = 1.0) -> void:
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, cells))
	_run(w, (w["player"] as CutActor).get_duration() + sec)


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const MONO: Array[Vector2i] = [Vector2i(5, 1)]
const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Assassin epic: min 1, dpc 2, mark 3 s x0.6 execute 30 %, mono clause 5 s, waves x1, no errors", sc.hero_of(ID) == "sat_thu"
		and int(s["min_cells"]) == 1 and is_equal_approx(float(s["damage_per_cell"]), 2.0) and is_equal_approx(float(s["mark"]["sec"]), 3.0)
		and is_equal_approx(float(s["mark"]["echo_mult"]), 0.6) and is_equal_approx(float(s["mark"]["execute_ratio"]), 0.3)
		and is_equal_approx(float(s["shape_clause"]["mark_sec"]), 5.0) and s["resolve"] == "waves" and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("every other card leaves no mark", (sc.get_skill("kiem_khi")["mark"] as Dictionary).is_empty())
	var cfg: SkillConfig = SkillConfig.from_dictionary({"cards": {"x": {"mark": {"echo_mult": 0.5}}}})
	ck("a mark without sec is dropped (warning)", (cfg.get_skill("x")["mark"] as Dictionary).is_empty())


func test_mark_applied_and_refreshed() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "mono", MONO, 0.05)
	ck("mono: the hit (2) marks the boss for 5 s; its own cast does not trigger it", is_equal_approx(_lost(w), 2.0) and fx.has_mark(CombatState.Side.ENEMY)
		and absf(float(fx.mark_at(CombatState.Side.ENEMY)["left"]) - 5.0) < 0.1 and (w["marks"] as Array) == ["applied 5.0"], str(w["marks"]))
	_run(w, 2.0)
	_cast(w, ID, "bar2", BAR2, 0.05)
	ck("bar2 re-cast: refreshed to 3 s, no stacking, not triggered by Dấu Tử itself", absf(float(fx.mark_at(CombatState.Side.ENEMY)["left"]) - 3.0) < 0.1
		and (w["marks"] as Array) == ["applied 5.0", "applied 3.0"] and (w["log"] as Array).size() == 2, str(w["marks"]))


func test_next_cast_echoes_and_spends_the_mark() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "mono", MONO, 0.05)
	var lost0: float = _lost(w)
	(w["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(w, (w["player"] as CutActor).get_duration() + 0.3)
	ck("kiem_khi lands 12, the mark is spent at once, the echo is on the clock", is_equal_approx(_lost(w) - lost0, 12.0) and not fx.has_mark(CombatState.Side.ENEMY)
		and (w["arb"] as SwingArbiter).scheduled_count() == 1 and (w["marks"] as Array).has("triggered"), str(w["marks"]))
	_run(w, 0.4)
	var echo: Dictionary = (w["log"] as Array)[-1]
	ck("0.6 s later the echo wave lands on the same cells: 12 x 0.6 = 7.2, kind echo, mark", echo["kind"] == "echo" and bool(echo["mark"])
		and is_equal_approx(float(echo["dmg"]), 7.2) and (echo["cells"] as Array) == BAR2 and is_equal_approx(_lost(w) - lost0, 19.2), str(w["log"]))
	ck("the echo cast emits no swing_resolved (not a cast for the listeners)", not (w["done"] as Array).has("kiem_khi:true"), str(w["done"]))
	ck("nothing left on the clock, no second echo", (w["arb"] as SwingArbiter).scheduled_count() == 0)


func test_execute_under_thirty_percent() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["state"] as CombatState).damage_enemy(750.0)  # 25 % HP left
	_cast(w, ID, "mono", MONO, 0.05)
	var lost0: float = _lost(w)
	(w["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(w, (w["player"] as CutActor).get_duration() + 0.7)
	ck("under 30 %: the triggering cast executes x2 (24); the echo repeats the base hit without execute (12 x 0.6 = 7.2)",
		is_equal_approx(_lost(w) - lost0, 31.2), "%.1f" % (_lost(w) - lost0))
	# Dấu Tử's own hit never executes (it carries the mark, it does not trigger it)
	var w2: Dictionary = _world(Vector2i(5, 1))
	(w2["state"] as CombatState).damage_enemy(750.0)
	_cast(w2, ID, "mono", MONO, 0.05)
	ck("Dấu Tử's own hit stays 2 under 30 %", is_equal_approx(_lost(w2) - 750.0, 2.0))


func test_echo_ignores_ran_and_crit() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, ID, "mono", MONO, 0.05)
	(w["fx"] as StatusEffects).apply_fragile(CombatState.Side.ENEMY, 1)
	var lost0: float = _lost(w)
	(w["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(w, (w["player"] as CutActor).get_duration() + 0.7)
	ck("Rạn 1: the parent spends it (18), the echo is 12 x 0.6 = 7.2 (no Rạn), no stack left", is_equal_approx(_lost(w) - lost0, 25.2)
		and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 0, "%.1f" % (_lost(w) - lost0))


func test_mark_expires() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, ID, "bar2", BAR2, 0.05)
	_run(w, 3.1)
	ck("3 s later the mark expired without triggering", not (w["fx"] as StatusEffects).has_mark(CombatState.Side.ENEMY)
		and (w["marks"] as Array) == ["applied 3.0", "expired"], str(w["marks"]))
	var lost0: float = _lost(w)
	(w["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(w, (w["player"] as CutActor).get_duration() + 0.7)
	ck("a cast after the expiry: plain 12, no echo", is_equal_approx(_lost(w) - lost0, 12.0) and (w["arb"] as SwingArbiter).scheduled_count() == 0)


func test_scheduled_parent_echoes_its_last_hit() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, ID, "bar2", BAR2, 0.05)
	var lost0: float = _lost(w)
	# dap_vo: sky drops, one per cell; the hit lands on (6,1): the echo repeats that cell 0.6 s after the cast's end
	(w["player"] as CutActor).begin_swing(BAR2, "dap_vo", true, 1, -1.0, {}, _ctx(w["sc"], "dap_vo", "bar2", BAR2))
	_run(w, (w["player"] as CutActor).get_duration() + 1.5)
	var echo: Dictionary = (w["log"] as Array)[-1]
	ck("dap_vo 12 then its echo 7.2 on the hit cell (6,1)", is_equal_approx(_lost(w) - lost0, 19.2) and echo["kind"] == "echo"
		and (echo["cells"] as Array) == [Vector2i(6, 1)], "%.1f %s" % [_lost(w) - lost0, str(echo)])


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	_cast(a, ID, "mono", MONO, 0.05)
	(a["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(a, 2.0)
	var b: Dictionary = _world(Vector2i(5, 1))
	_cast(b, ID, "mono", MONO, 0.05)
	(b["player"] as CutActor).begin_swing(BAR2, "kiem_khi", true, 1, -1.0, {}, {})
	_run(b, 2.0)
	ck("two identical runs: same log and HP", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b)))
