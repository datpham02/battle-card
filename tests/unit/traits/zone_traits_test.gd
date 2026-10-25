extends SceneTree
## Story 027 Phan C: boss traits `seal_caster` and `thorn_field`. seal_caster places a 2-3 cell seal on the
## PLAYER's half at its rhythm, only when an armed boss swing of >= min_swing_cells has lead_sec or less
## left, on escape cells (never a swing cell, never the player's cell) and obeying the leave-a-path rule
## (a cornered player keeps an exit, also with a crack blocking the other neighbour). thorn_field lays
## thorns only on swings of >= 4 cells, on escape cells touching the swing. Registry and chapters.json
## assignment are checked too. Headless; FAILS=N. Deterministic: fixed seeds, fixed steps.

const SEED: int = 11
const STEP: float = 0.1
## 3x3 per half: the player's half is x 0..2.
const SIDE_COLS: int = 3
const SIDE_ROWS: int = 3
const SEAL_PARAMS: Dictionary = {
	"interval_sec": 4.0, "first_delay_sec": 4.0, "cells_min": 2, "cells_max": 3, "lead_sec": 0.5,
	"min_swing_cells": 3, "seal_sec": 1.2,
}
const SWING_SEC: float = 1.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_registry()
	_test_seal_rhythm_and_lead()
	_test_seal_small_swing_ignored()
	_test_seal_corner_keeps_exit()
	_test_seal_corner_with_crack_keeps_exit()
	_test_thorns_only_on_big_swings()
	_test_thorns_cooldown()
	_test_chapters_assignment()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _world(player_cell: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(SIDE_COLS, SIDE_ROWS)
	var state := CombatState.new(grid, 1.0e6, 1.0e6, player_cell)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var boss := BossController.new(
		state, grid, cut_config, skill_config, BossBrainConfig.load_from_file(), drops_config,
		HoldSlotsConfig.new(), SEED
	)
	var status := StatusEffects.new()
	var mover := UnitMover.new(state, CombatState.Side.PLAYER, 0.3)
	var ctx: Dictionary = {"state": state, "grid": grid, "status": status, "boss": boss, "player_mover": mover}
	return {"grid": grid, "state": state, "status": status, "boss": boss, "mover": mover, "ctx": ctx}


func _make(id: String, w: Dictionary, params: Dictionary) -> BossTrait:
	var t: BossTrait = TraitRegistry.create(id)
	t.setup(w["ctx"], params, SEED)
	t.on_match_start()
	return t


func _swing(w: Dictionary, cells: Array[Vector2i]) -> void:
	var actor: CutActor = (w["boss"] as BossController).get_actor()
	actor.begin_swing(cells, SkillConfig.FALLBACK_SKILL, false, 1, SWING_SEC)


# Advances the boss actor and the trait by [param seconds] in STEP slices.
func _run(w: Dictionary, t: BossTrait, seconds: float) -> void:
	var actor: CutActor = (w["boss"] as BossController).get_actor()
	var n: int = roundi(seconds / STEP)
	for i: int in n:
		actor.tick(STEP)
		t.on_tick(STEP)


func _row(y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in SIDE_COLS:
		cells.append(Vector2i(x, y))
	return cells


# Player-half neighbours of the player that are not sealed and not blocked by the mover.
func _open_neighbours(w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: BoardGrid = w["grid"]
	var p: Vector2i = (w["state"] as CombatState).player_cell
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var c: Vector2i = p + dir
		if grid.is_player_cell(c) and not (w["status"] as StatusEffects).is_sealed(CombatState.Side.PLAYER, c) \
				and not (w["mover"] as UnitMover).is_cell_blocked(c):
			out.append(c)
	return out


# ------------------------------------------------------------------ tests

func _test_registry() -> void:
	_check("registry: seal_caster", TraitRegistry.create("seal_caster") is SealCasterTrait)
	_check("registry: thorn_field", TraitRegistry.create("thorn_field") is ThornFieldTrait)


func _test_seal_rhythm_and_lead() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var t: SealCasterTrait = _make("seal_caster", w, SEAL_PARAMS) as SealCasterTrait
	var status: StatusEffects = w["status"]
	# A big swing before the trait is armed: no seal.
	_run(w, t, 1.0)
	_swing(w, _row(1))
	_run(w, t, 1.5)
	_check("seal: no seal before the first interval", t.get_seal_count() == 0 and status.sealed_cells(CombatState.Side.PLAYER).is_empty())
	_run(w, t, 2.0) # t = 4.5: armed
	_check("seal: armed after interval_sec", t.is_armed())
	_swing(w, _row(1))
	_run(w, t, 0.3) # 0.7 s left > lead 0.5
	_check("seal: not placed while the swing has more than lead_sec left", t.get_seal_count() == 0)
	_run(w, t, 0.3) # 0.4 s left
	var sealed: Array[Vector2i] = status.sealed_cells(CombatState.Side.PLAYER)
	_check("seal: placed once the swing is within lead_sec", t.get_seal_count() == 1, str(sealed))
	_check("seal: 2-3 cells", sealed.size() >= 2 and sealed.size() <= 3, str(sealed))
	var ok: bool = true
	for c: Vector2i in sealed:
		ok = ok and (w["grid"] as BoardGrid).is_player_cell(c) and not _row(1).has(c) and c != Vector2i(1, 1)
	_check("seal: player half, outside the swing, never the player's cell", ok, str(sealed))
	_check("seal: the player keeps an open neighbour", not _open_neighbours(w).is_empty())
	_run(w, t, 1.0)
	_swing(w, _row(1))
	_run(w, t, 1.0)
	_check("seal: not again before the next interval", t.get_seal_count() == 1)
	_run(w, t, 2.0) # past the next arming (placed ~5.1 + 4.0)
	_swing(w, _row(0))
	_run(w, t, 1.0)
	_check("seal: placed again at the next interval", t.get_seal_count() == 2)


func _test_seal_small_swing_ignored() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var params: Dictionary = SEAL_PARAMS.duplicate()
	params["first_delay_sec"] = 0.0
	var t: SealCasterTrait = _make("seal_caster", w, params) as SealCasterTrait
	var small: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	_swing(w, small)
	_run(w, t, 1.2)
	_check("seal: a swing below min_swing_cells carries no seal", t.get_seal_count() == 0 and t.is_armed())


func _test_seal_corner_keeps_exit() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	var params: Dictionary = SEAL_PARAMS.duplicate()
	params["first_delay_sec"] = 0.0
	params["cells_min"] = 3
	var t: SealCasterTrait = _make("seal_caster", w, params) as SealCasterTrait
	_swing(w, _row(0))
	_run(w, t, 0.6)
	var sealed: Array[Vector2i] = (w["status"] as StatusEffects).sealed_cells(CombatState.Side.PLAYER)
	_check("corner: a seal was placed", t.get_seal_count() == 1, str(sealed))
	_check("corner: the player keeps an open neighbour", not _open_neighbours(w).is_empty(), str(sealed))
	var blocked: Array[Vector2i] = sealed.duplicate()
	var escape: Array[Vector2i] = EscapeAnalysis.escape_cells(w["grid"], Vector2i(0, 0), 2, true, _row(0), blocked)
	_check("corner: an escape cell outside the swing is still reachable", not escape.is_empty(), str(escape))


func _test_seal_corner_with_crack_keeps_exit() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	(w["mover"] as UnitMover).add_blocker(func(c: Vector2i) -> bool: return c == Vector2i(1, 0))
	var params: Dictionary = SEAL_PARAMS.duplicate()
	params["first_delay_sec"] = 0.0
	var t: SealCasterTrait = _make("seal_caster", w, params) as SealCasterTrait
	var swing: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_swing(w, swing)
	_run(w, t, 0.6)
	_check("corner + crack: the only exit (0,1) is never sealed",
		not (w["status"] as StatusEffects).is_sealed(CombatState.Side.PLAYER, Vector2i(0, 1)),
		str((w["status"] as StatusEffects).sealed_cells(CombatState.Side.PLAYER)))
	_check("corner + crack: open neighbour left", not _open_neighbours(w).is_empty())


func _test_thorns_only_on_big_swings() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var t: ThornFieldTrait = _make("thorn_field", w, {"min_swing_cells": 4, "max_cells": 3, "cooldown_sec": 0.0}) as ThornFieldTrait
	var status: StatusEffects = w["status"]
	var three: Array[Vector2i] = _row(1)
	t.on_boss_swing_started(three, SkillConfig.FALLBACK_SKILL)
	_check("thorns: a 3-cell swing lays nothing", t.get_field_count() == 0 and status.thorn_cells(CombatState.Side.PLAYER).is_empty())
	var four: Array[Vector2i] = _row(1)
	four.append(Vector2i(1, 0))
	t.on_boss_swing_started(four, SkillConfig.FALLBACK_SKILL)
	var thorns: Array[Vector2i] = status.thorn_cells(CombatState.Side.PLAYER)
	_check("thorns: a 4-cell swing lays a field", t.get_field_count() == 1 and not thorns.is_empty(), str(thorns))
	var ok: bool = thorns.size() <= 3
	for c: Vector2i in thorns:
		var touches: bool = false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			touches = touches or four.has(c + d)
		ok = ok and (w["grid"] as BoardGrid).is_player_cell(c) and not four.has(c) and c != Vector2i(1, 1) and touches
	_check("thorns: escape cells next to the swing, outside it, never the player's cell, <= max_cells", ok, str(thorns))
	var zones: Dictionary = CombatConfig.load_from_file().zone_numbers()
	var entry: Dictionary = status.thorns_at(CombatState.Side.PLAYER, thorns[0]) if not thorns.is_empty() else {}
	_check("thorns: combat.json numbers by default",
		not entry.is_empty() and is_equal_approx(float(entry["damage"]), float(zones["thorn_damage"]))
		and int(entry["fragile_stacks"]) == int(zones["thorn_fragile_stacks"]), str(entry))


func _test_thorns_cooldown() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var t: ThornFieldTrait = _make("thorn_field", w, {"cooldown_sec": 2.0}) as ThornFieldTrait
	var four: Array[Vector2i] = _row(1)
	four.append(Vector2i(1, 0))
	t.on_boss_swing_started(four, SkillConfig.FALLBACK_SKILL)
	t.on_boss_swing_started(four, SkillConfig.FALLBACK_SKILL)
	_check("thorns: cooldown blocks the second field", t.get_field_count() == 1)
	for i: int in 21:
		t.on_tick(STEP)
	t.on_boss_swing_started(four, SkillConfig.FALLBACK_SKILL)
	_check("thorns: after cooldown_sec a new field", t.get_field_count() == 2)


func _test_chapters_assignment() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/data/chapters.json")
	_check("chapters.json: jailer carries seal_caster", _boss_has_trait(text, "jailer", "seal_caster"))
	_check("chapters.json: frost_mage carries thorn_field", _boss_has_trait(text, "frost_mage", "thorn_field"))


# True when some object with id [param boss_id] in the parsed JSON lists trait [param trait_id].
func _boss_has_trait(text: String, boss_id: String, trait_id: String) -> bool:
	return _find(JSON.parse_string(text), boss_id, trait_id)


func _find(node: Variant, boss_id: String, trait_id: String) -> bool:
	if typeof(node) == TYPE_DICTIONARY:
		var d: Dictionary = node
		if str(d.get("id", "")) == boss_id and typeof(d.get("traits")) == TYPE_ARRAY:
			for entry: Variant in d["traits"]:
				if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == trait_id:
					return true
		for v: Variant in d.values():
			if _find(v, boss_id, trait_id):
				return true
	elif typeof(node) == TYPE_ARRAY:
		for v: Variant in node:
			if _find(v, boss_id, trait_id):
				return true
	return false
