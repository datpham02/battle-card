extends SceneTree
## Skill v2 batch 5 (Deferred 11, 02-design-decisions.md §7 "Snapshots"): an echo wave uses the player's signature as
## it was AT THE CAST, never the live hook: the Assassin's Bóng Lướt (x1.75 on small casts) active at the cast
## multiplies the mark's echo and a card's own echo waves even once it ended; activated after the cast it adds nothing
## to them. The hook is a stub Callable here (the real AnhBoSignature is the same shape: card, cells, damage, pinned).
## Run: godot --headless --path . -s res://tests/unit/combat/swing_arbiter_signature_snapshot_test.gd

const HERO := Vector2i(1, 1)
const STEP: float = 0.01
const MULT: float = 1.75
const MONO: Array[Vector2i] = [Vector2i(5, 1)]
const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_mark_echo_keeps_the_factor_after_the_signature_ended()
	test_mark_echo_ignores_a_signature_activated_after_the_cast()
	test_scheduled_parent_snapshot()
	test_card_echo_waves_use_the_snapshot()
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
	var active: Array = [false]
	# the stub signature: x MULT on casts of 3 cells or fewer while active (AnhBoSignature.modify_damage's rule)
	arb.player_signature_modifier = func(_id: String, cells: int, dmg: float, _pinned: bool) -> float:
		return dmg * MULT if bool(active[0]) and cells <= 3 else dmg
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		if hit:
			log.append({"kind": ev["kind"], "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "active": active, "log": log}


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _ctx(sc: SkillConfig, id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


# Swings [param id]; [param flip_at_end] toggles the stub signature the moment the swing ends (before any echo).
func _cast(w: Dictionary, id: String, shape: String, cells: Array[Vector2i], after: float, flip_at_end: bool = false) -> void:
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, cells))
	_run(w, (w["player"] as CutActor).get_duration() + STEP)
	if flip_at_end:
		(w["active"] as Array)[0] = not bool((w["active"] as Array)[0])
	_run(w, after)


func _echoes(w: Dictionary) -> Array:
	var out: Array = []
	for e: Dictionary in w["log"] as Array:
		if e["kind"] == "echo":
			out.append(float(e["dmg"]))
	return out


func _mark(w: Dictionary) -> void:
	(w["fx"] as StatusEffects).apply_mark(CombatState.Side.ENEMY, 5.0, 0.6, 0.3)


func test_mark_echo_keeps_the_factor_after_the_signature_ended() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_mark(w)
	(w["active"] as Array)[0] = true
	# kiem_khi mono: 6 x 1.75 = 10.5 at the swing end; the signature ends right after; the echo 0.6 s later: 10.5 x 0.6 = 6.3
	_cast(w, "kiem_khi", "mono", MONO, 1.0, true)
	ck("the hit 10.5 (x1.75), the mark's echo 6.3 keeps the cast's x1.75 though the signature ended", _echoes(w).size() == 1 and is_equal_approx(float(_echoes(w)[0]), 6.3)
		and is_equal_approx(1000.0 - (w["state"] as CombatState).enemy_hp, 16.8), "%s %.2f" % [str(w["log"]), 1000.0 - (w["state"] as CombatState).enemy_hp])


func test_mark_echo_ignores_a_signature_activated_after_the_cast() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_mark(w)
	# inactive at the cast: 6; activated at the swing end; the echo stays 6 x 0.6 = 3.6
	_cast(w, "kiem_khi", "mono", MONO, 1.0, true)
	ck("the hit 6, the echo 3.6 (no x1.75 from a signature activated after the cast)", _echoes(w).size() == 1 and is_equal_approx(float(_echoes(w)[0]), 3.6)
		and is_equal_approx(1000.0 - (w["state"] as CombatState).enemy_hp, 9.6), "%s" % str(w["log"]))


func test_scheduled_parent_snapshot() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_mark(w)
	(w["active"] as Array)[0] = true
	# dap_vo (sky drops, scheduled) mono: the drop 6 x 1.75 = 10.5 (the live hook on the parent's own event; the signature
	# ends at the swing end, before the drop, so the parent's drop is 6 x 1 = 6); the mark's echo uses the CAST-time
	# snapshot x1.75: 6 x 1.75 x 0.6 = 6.3
	_cast(w, "dap_vo", "mono", MONO, 2.0, true)
	var echoes: Array = _echoes(w)
	ck("the scheduled parent's mark echo uses the cast-time factor: 6 x 1.75 x 0.6 = 6.3", echoes.size() == 1 and is_equal_approx(float(echoes[0]), 6.3), str(w["log"]))


func test_card_echo_waves_use_the_snapshot() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["active"] as Array)[0] = true
	# hoi_am bar3: the hit 5 x 3 x 1.75 = 26.25, then its own echo wave (shift 1, still on the boss) at 0.6 x: 15.75,
	# with the signature ended
	_cast(w, "hoi_am", "bar3", BAR3, 2.0, true)
	var echoes: Array = _echoes(w)
	var all_snapshot: bool = not echoes.is_empty()
	for d: float in echoes:
		all_snapshot = all_snapshot and is_equal_approx(d, 26.25 * 0.6)
	ck("Hồi Âm's own echo wave keeps the cast's x1.75 (15.75) after the signature ended", all_snapshot, str(w["log"]))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	var b: Dictionary = _world(Vector2i(5, 1))
	for w: Dictionary in [a, b]:
		_mark(w)
		(w["active"] as Array)[0] = true
		_cast(w, "kiem_khi", "mono", MONO, 1.0, true)
	ck("two identical runs: same log", str(a["log"]) == str(b["log"]))
