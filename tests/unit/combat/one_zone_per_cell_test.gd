extends SceneTree
## One zone effect per cell, new replaces old, locked cells (design/quick-specs/mot-o-mot-hieu-ung-2026-11-01.md,
## Acceptance Criteria; ADR-0001 A1: the cast's cells are the only place damage / status lands).
## Covers: thorns -> fire -> crack on one cell (never two at once, full duration on replacement, same-kind refresh, burn
## stacking kept); a cast whose cells include a cracking cell and a hole (the unit there takes no damage / status, the
## other cells hit and the damage counts only them; no zone lands on the locked cells); the boss red telegraph and the
## trait warnings drop a cell that starts cracking; locked cells unlock when the hole returns; terrain fire (lava vent)
## and unit statuses keep their behaviour; boss traits (thorn field / row burner / fuse) obey the same rule point.
## Pure logic: no file I/O (cards built with SkillConfig.from_dictionary, numbers from CombatConfig.new()).
## Run: godot --headless --path . -s res://tests/unit/combat/one_zone_per_cell_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.1
const HP: float = 100.0
const THORN_SEC: float = 3.0
const THORN_DAMAGE: float = 4.0
const BURN_SEC: float = 2.0
const BURN_TICK: float = 0.5
const BURN_DAMAGE: float = 1.0
const CARD_DAMAGE_PER_CELL: float = 10.0
## Player half cells of the 3x3-per-half fixture grid (x 0..2).
const A: Vector2i = Vector2i(1, 0)
const B: Vector2i = Vector2i(1, 1)
const C: Vector2i = Vector2i(1, 2)
const SAFE: Vector2i = Vector2i(0, 0)

var fails: int = 0
var cfg: CombatConfig = CombatConfig.new()


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_thorns_fire_crack_one_effect_at_a_time()
	test_fire_replaced_by_thorns_full_duration()
	test_same_kind_refreshes()
	test_burn_stacking_rule_kept()
	test_locked_cell_refuses_every_zone_until_it_returns()
	test_cast_skips_cracking_cell_and_hole()
	test_cast_burn_and_thorns_never_land_on_locked_cells()
	test_cast_without_locks_unchanged()
	test_telegraph_drops_cell_that_starts_cracking()
	test_trait_warnings_and_hits_skip_locked_cells()
	test_terrain_fire_and_unit_statuses_unchanged()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

func _world(player_cell: Vector2i = SAFE) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, HP, HP, player_cell, Vector2i(4, 1))
	var status := StatusEffects.new()
	cfg.configure_status(status)
	return {"grid": grid, "state": state, "status": status}


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


func _ticks(w: Dictionary, n: int) -> void:
	for i: int in n:
		(w["status"] as StatusEffects).tick(STEP, w["state"])


func _crack(status: StatusEffects, cells: Array) -> Array[Vector2i]:
	return status.apply_drop(P, _cells(cells), cfg.hole_warn_sec, cfg.seal_sec)


# Turns [param cell] into an open hole (crack, then the warning runs out with nobody on it).
func _make_hole(w: Dictionary, cell: Vector2i) -> void:
	_crack(w["status"], [cell])
	_ticks(w, roundi(cfg.hole_warn_sec / STEP) + 1)


func _skills() -> SkillConfig:
	var delivery: Dictionary = {"type": "DIRECT_MANIFESTATION", "origin": "target_cells", "travel": "none",
		"impact": "burst", "cell_mask": "block_shape"}
	return SkillConfig.from_dictionary({
		"card_order": ["hit"],
		"default_card": "hit",
		"cards": {
			"hit": {"effect": "damage", "damage_per_cell": CARD_DAMAGE_PER_CELL, "frost_stacks": 1, "fragile_stacks": 1,
				"rarity": "common", "upgrade": {}, "implemented": true, "delivery": delivery},
			"fire": {"effect": "burn", "burn_duration_sec": BURN_SEC, "burn_tick_sec": BURN_TICK,
				"burn_damage_per_tick": BURN_DAMAGE, "frost_stacks": 1, "rarity": "common", "upgrade": {},
				"implemented": true, "delivery": delivery},
			"spikes": {"effect": "thorns", "thorn_sec": THORN_SEC, "thorn_damage": THORN_DAMAGE, "thorn_fragile_stacks": 1,
				"rarity": "common", "upgrade": {}, "implemented": true, "delivery": delivery},
		},
	})


func _cast(w: Dictionary, side: int, cells: Array, skill: String) -> Dictionary:
	return CutEffects.apply(w["state"], w["grid"], side, _cells(cells), skill, CutConfig.new(), _skills(), w["status"])


func _one_at_most(status: StatusEffects, cell: Vector2i) -> bool:
	return status.zone_kinds_at(cell).size() <= 1


# ------------------------------------------------------------------ rules 1-2

func test_thorns_fire_crack_one_effect_at_a_time() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	status.apply_thorns(P, _cells([B]), THORN_SEC, THORN_DAMAGE, 1)
	_check("rule 1: thorns alone on the cell", status.zone_kinds_at(B) == ([StatusEffects.KIND_THORNS] as Array[String]))
	_ticks(w, 5)
	var lit: Array[Vector2i] = status.ignite(_cells([B]), BURN_SEC, BURN_TICK, BURN_DAMAGE)
	_check("rule 2: fire replaces thorns (thorns gone, one effect)",
		lit == _cells([B]) and status.zone_kinds_at(B) == ([StatusEffects.KIND_BURN] as Array[String])
		and status.thorns_at(P, B).is_empty(), str(status.zone_kinds_at(B)))
	_check("rule 2: the fire starts with its full duration", is_equal_approx(status.get_burn_left(B), BURN_SEC))
	var cracked: Array[Vector2i] = _crack(status, [B])
	_check("rule 5: the crack replaces the fire (one effect)",
		cracked == _cells([B]) and status.zone_kinds_at(B) == ([StatusEffects.KIND_DROP] as Array[String])
		and not status.is_burning(B), str(status.zone_kinds_at(B)))
	_check("rule 5: the crack keeps its full 31/10 warning", is_equal_approx(status.crack_left(P, B), cfg.hole_warn_sec))
	var ok: bool = true
	for i: int in roundi((cfg.hole_warn_sec + cfg.seal_sec) / STEP) + 2:
		_ticks(w, 1)
		ok = ok and _one_at_most(status, B)
	_check("rule 1: never two effects on the cell through crack -> hole -> return", ok)


func test_fire_replaced_by_thorns_full_duration() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE)
	_ticks(w, 3)
	var placed: Array[Vector2i] = status.apply_thorns(P, _cells([A]), THORN_SEC, THORN_DAMAGE, 1)
	_check("rule 2: thorns replace fire with their full duration",
		placed == _cells([A]) and not status.is_burning(A) and is_equal_approx(status.thorn_left(P, A), THORN_SEC)
		and status.zone_kinds_at(A).size() == 1)


func test_same_kind_refreshes() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	status.apply_thorns(P, _cells([A]), THORN_SEC, THORN_DAMAGE, 1)
	_ticks(w, 10)
	status.apply_thorns(P, _cells([A]), THORN_SEC, THORN_DAMAGE, 1)
	_check("rule 2: same kind (thorns) refreshes to the full duration", is_equal_approx(status.thorn_left(P, A), THORN_SEC))


func test_burn_stacking_rule_kept() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	status.configure(0.5, 1.0, 3)
	status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE)
	status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE)
	_check("rule 2: same kind (fire) keeps the Dot stacking rule", status.stacks_at(A) == 2
		and is_equal_approx(status.get_burn_left(A), BURN_SEC + 0.5), "%d %.2f" % [status.stacks_at(A), status.get_burn_left(A)])


# ------------------------------------------------------------------ rule 3: locked cells

func test_locked_cell_refuses_every_zone_until_it_returns() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	_crack(status, [A])
	_check("rule 3: a cracking cell is locked", status.is_locked(A))
	_check("rule 3: no fire on a cracking cell", status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE).is_empty()
		and not status.is_burning(A))
	_check("rule 3: no thorns on a cracking cell (ZoneRules.cast_thorns too)",
		ZoneRules.cast_thorns(status, P, _cells([A, B]), THORN_SEC, THORN_DAMAGE, 1) == _cells([B])
		and status.thorns_at(P, A).is_empty())
	_check("rule 3: no second crack on a cracking cell", _crack(status, [A]).is_empty())
	_ticks(w, roundi(cfg.hole_warn_sec / STEP) + 1)
	_check("rule 3: a hole is locked and refuses fire",
		status.is_hole(P, A) and status.is_locked(A) and status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE).is_empty())
	_ticks(w, roundi(cfg.seal_sec / STEP) + 1)
	_check("rule 3: the returned cell is unlocked and takes a zone again", not status.is_locked(A)
		and status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE) == _cells([A]))


func test_cast_skips_cracking_cell_and_hole() -> void:
	var w: Dictionary = _world(B)
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	_make_hole(w, A)
	_crack(status, [B])
	var res: Dictionary = _cast(w, E, [A, B, C], "hit")
	_check("rule 3: the unit on a cracking cell takes no damage and no status",
		not bool(res["hit"]) and is_equal_approx(state.player_hp, HP)
		and status.frost_stacks(P) == 0 and status.fragile_stacks(P) == 0, str(res))
	_check("rule 3: the locked cells are reported", res["locked_cells"] == _cells([A, B]), str(res["locked_cells"]))
	state.set_player_cell(C)
	var res2: Dictionary = _cast(w, E, [A, B, C], "hit")
	_check("rule 3: the other cells hit normally (damage counts the open cells only)",
		bool(res2["hit"]) and is_equal_approx(float(res2["damage"]), CARD_DAMAGE_PER_CELL)
		and is_equal_approx(state.player_hp, HP - CARD_DAMAGE_PER_CELL) and status.frost_stacks(P) == 1,
		"%s hp=%.1f" % [str(res2["damage"]), state.player_hp])


func test_cast_burn_and_thorns_never_land_on_locked_cells() -> void:
	var w: Dictionary = _world(B)
	var status: StatusEffects = w["status"]
	_make_hole(w, A)
	_crack(status, [B])
	var res: Dictionary = _cast(w, E, [A, B, C], "fire")
	_check("rule 3: a fire cast burns only the open cell, no status for the unit on the crack",
		status.is_burning(C) and not status.is_burning(A) and not status.is_burning(B) and not bool(res["hit"])
		and status.frost_stacks(P) == 0)
	var res2: Dictionary = _cast(w, E, [A, B, C], "spikes")
	_check("rule 3 + 2: a thorn cast lays thorns only on the open cell (replacing its fire)",
		res2["zone_cells"] == _cells([C]) and status.thorns_at(P, A).is_empty() and status.thorns_at(P, B).is_empty()
		and not status.is_burning(C) and status.zone_kinds_at(C) == ([StatusEffects.KIND_THORNS] as Array[String]),
		str(res2["zone_cells"]))
	_check("rule 1: the locked cells still hold only their drop tile",
		status.zone_kinds_at(A) == ([StatusEffects.KIND_DROP] as Array[String])
		and status.zone_kinds_at(B) == ([StatusEffects.KIND_DROP] as Array[String]))


func test_cast_without_locks_unchanged() -> void:
	var w: Dictionary = _world(B)
	var res: Dictionary = _cast(w, E, [A, B, C], "hit")
	_check("no regression: a cast with no locked cell counts every cell", bool(res["hit"])
		and is_equal_approx(float(res["damage"]), CARD_DAMAGE_PER_CELL * 3.0) and (res["locked_cells"] as Array).is_empty())


# ------------------------------------------------------------------ rule 4: the warning matches the hit

func test_telegraph_drops_cell_that_starts_cracking() -> void:
	var w: Dictionary = _world()
	var status: StatusEffects = w["status"]
	var actor := CutActor.new(CutConfig.new(), E)
	actor.begin_swing(_cells([A, B]), "kiem_khi", false)
	actor.queue_swing(_cells([C]), "kiem_khi", false, 1.0)
	var before: Dictionary = TelegraphPainter.state_for(actor, cfg, false, status)
	_check("rule 4: before the crack the red covers the swing", before["cells"] == _cells([A, B])
		and before["queued"] == _cells([C]), str(before))
	_crack(status, [B, C])
	var after: Dictionary = TelegraphPainter.state_for(actor, cfg, false, status)
	_check("rule 4: the cell that starts cracking loses its red at once (running and queued)",
		after["cells"] == _cells([A]) and (after["queued"] as Array).is_empty(), str(after))
	var plain: Dictionary = TelegraphPainter.state_for(actor, cfg, false)
	_check("no regression: without a status the telegraph is the swing", plain["cells"] == _cells([A, B]))


func test_trait_warnings_and_hits_skip_locked_cells() -> void:
	var w: Dictionary = _world(B)
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var ctx: Dictionary = {"status": status, "state": state, "grid": w["grid"]}
	var burner := RowBurnerTrait.new()
	burner.setup(ctx, {}, 1)
	burner._warning_cells = _cells([A, B, C])
	var fuse := FuseCannonTrait.new()
	fuse.setup(ctx, {}, 1)
	fuse._warning_cells = _cells([A, B, C])
	_crack(status, [B])
	_check("rule 4: the row burner warning drops the cracking cell", burner.get_warning_cells() == _cells([A, C]))
	_check("rule 4: the fuse warning drops the cracking cell", fuse.get_warning_cells() == _cells([A, C]))
	_check("rule 3: BossTrait.hittable_cells is the StatusEffects gate", burner.hittable_cells(_cells([A, B, C])) == _cells([A, C]))
	fuse._resolve()
	_check("rule 3: the fuse blast does not hit the unit on the cracking cell", is_equal_approx(state.player_hp, HP))
	burner._ignite()
	_check("rule 3: the row burner ignites only the open cells", status.is_burning(A) and status.is_burning(C)
		and not status.is_burning(B) and burner.get_last_burned_cells() == _cells([A, C]))


# ------------------------------------------------------------------ not zone effects

func test_terrain_fire_and_unit_statuses_unchanged() -> void:
	var w: Dictionary = _world(B)
	var status: StatusEffects = w["status"]
	status.apply_thorns(P, _cells([A]), THORN_SEC, THORN_DAMAGE, 1)
	status.ignite(_cells([A]), BURN_SEC, BURN_TICK, BURN_DAMAGE, true)
	_check("terrain: a vent's fire is not a zone effect (thorns stay, no replacement)",
		status.is_burning(A) and not status.thorns_at(P, A).is_empty()
		and status.zone_kinds_at(A) == ([StatusEffects.KIND_THORNS] as Array[String]))
	_crack(status, [C])
	_check("terrain: a vent still erupts on a cracking cell (old behaviour)",
		status.ignite(_cells([C]), BURN_SEC, BURN_TICK, BURN_DAMAGE, true) == _cells([C]) and status.is_cracking(P, C))
	_crack(status, [B])
	status.apply_frost(P, 1)
	status.apply_fragile(P, 1)
	status.pin(P, 1.0)
	_check("unit statuses: Han / Ran / Frozen stack on the unit as before (not cell effects)",
		status.frost_stacks(P) == 1 and status.fragile_stacks(P) == 1 and status.is_pinned(P))
