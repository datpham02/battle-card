extends SceneTree
## Headless mini-world test of Story 014 Part B (traits). PASS/FAIL lines + FAILS=N.

const DT: float = 0.05

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _world(seed_value: int) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	var hold_config := HoldSlotsConfig.new()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 100000.0
	var player_drops := FieldDrops.new(drops_config, grid.player_cells(), seed_value)
	var boss := BossController.new(state, grid, cut_config, skill_config, brain_config, drops_config, hold_config, seed_value + 1)
	boss.set_active(false)
	var status := StatusEffects.new()
	boss.set_status(status)
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var arbiter := SwingArbiter.new(state, grid, player_actor, boss.get_actor(), cut_config, skill_config, status)
	var hold := HoldSlots.new(4)
	var mover := UnitMover.new(state, CombatState.Side.PLAYER, 0.0)
	var ctx: Dictionary = {
		"state": state, "grid": grid, "player_drops": player_drops, "boss_drops": boss.get_drops(),
		"boss": boss, "status": status, "arbiter": arbiter, "hold_getter": func() -> HoldSlots: return hold,
		"skill_config": skill_config, "cut_config": cut_config, "player_mover": mover,
	}
	return {"ctx": ctx, "state": state, "grid": grid, "status": status, "drops": player_drops, "hold": hold, "arbiter": arbiter, "mover": mover, "boss": boss}


func _tick(w: Dictionary, host: TraitHost, step: float) -> void:
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var drops: FieldDrops = w["drops"]
	var hold: HoldSlots = w["hold"]
	status.tick(step, state)
	drops.set_blocked_cells(status.burning_cells())
	drops.tick(step, state.player_cell, hold.get_occupied_count())
	(w["arbiter"] as SwingArbiter).tick(step)
	hold.tick_rot(step)
	host.on_tick(step)


func _run_until(w: Dictionary, host: TraitHost, t: Array, until: float) -> void:
	while t[0] < until - 0.000001:
		t[0] += DT
		_tick(w, host, DT)


func _same_cells(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for c: Vector2i in a:
		if not b.has(c):
			return false
	return true


func _init() -> void:
	_test_registry()
	_test_step_reactor()
	_test_fuse()
	_test_slam()
	_test_frost()
	_test_phase()
	_test_defaults_teardown()
	print("FAILS=%d" % fails)
	quit(fails)


func _host(w: Dictionary, specs: Array, seed_value: int = 5) -> TraitHost:
	var host := TraitHost.new(w["ctx"], specs, seed_value)
	host.on_match_start()
	return host


func _step(w: Dictionary, host: TraitHost, dir: Vector2i) -> bool:
	var mover: UnitMover = w["mover"]
	var state: CombatState = w["state"]
	var from: Vector2i = state.player_cell
	mover.tick(10.0)
	var ok: bool = mover.try_step(dir)
	if ok:
		host.on_player_stepped(from, state.player_cell)
	return ok


func _test_registry() -> void:
	for id: String in ["step_reactor", "fuse_cannon", "slam", "frost_aura", "phase_shift"]:
		_check("registry creates " + id, TraitRegistry.create(id) != null and TraitRegistry.create(id).get_id() == id)
	_check("registry unknown null", TraitRegistry.create("nope") == null)


func _test_step_reactor() -> void:
	var w: Dictionary = _world(11)
	var state: CombatState = w["state"]
	var boss: BossController = w["boss"]
	var host := _host(w, [{"id": "step_reactor"}])
	var tr: StepReactorTrait = host.get_trait("step_reactor") as StepReactorTrait
	var tt: Array = [0.0]
	_run_until(w, host, tt, 3.0)
	_check("reactor idle: no charge standing still", tr.get_charges() == 0 and not boss.get_actor().is_swinging())
	_step(w, host, Vector2i.RIGHT)
	_step(w, host, Vector2i.LEFT)
	_check("reactor 2 steps = 2 charges, no swing", tr.get_charges() == 2 and not boss.get_actor().is_swinging())
	_step(w, host, Vector2i.RIGHT)
	var actor: CutActor = boss.get_actor()
	_check("reactor fires on 3rd step", actor.is_swinging() and tr.get_fire_count() == 1)
	_check("reactor swing 3 cells incl player", actor.get_cells().size() == 3 and actor.get_cells().has(state.player_cell))
	_check("reactor warning 0.5s", absf(actor.get_duration() - 0.5) < 0.0001, str(actor.get_duration()))
	_check("reactor charges reset", tr.get_charges() == 0)
	var cells: Array[Vector2i] = actor.get_cells()
	var conn: bool = true
	for c: Vector2i in cells:
		var n: int = 0
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if cells.has(c + d):
				n += 1
		conn = conn and n >= 1
	_check("reactor cluster connected", conn)
	_step(w, host, Vector2i.DOWN)
	_check("reactor cooldown: step adds no charge", tr.get_charges() == 0 and tr.get_cooldown_left() > 0.0)
	_run_until(w, host, tt, 6.0)
	_check("reactor swing resolved", not actor.is_swinging())
	_check("reactor cooldown over", tr.get_cooldown_left() == 0.0)
	_step(w, host, Vector2i.UP)
	_check("reactor counts again after cooldown", tr.get_charges() == 1)
	var w2: Dictionary = _world(12)
	var host2 := _host(w2, [{"id": "step_reactor", "params": {"charges_to_fire": 2, "swing_cells": 5, "warning_sec": 0.9}}])
	_step(w2, host2, Vector2i.RIGHT)
	_step(w2, host2, Vector2i.LEFT)
	var a2: CutActor = (w2["boss"] as BossController).get_actor()
	_check("reactor params honoured", a2.is_swinging() and a2.get_cells().size() == 5 and absf(a2.get_duration() - 0.9) < 0.0001)
	a2.cancel()
	_check("reactor swing cancellable", not a2.is_swinging())
	var w3: Dictionary = _world(13)
	var host3 := _host(w3, [{"id": "step_reactor"}])
	var b3: CutActor = (w3["boss"] as BossController).get_actor()
	b3.begin_swing([Vector2i(5, 1)] as Array[Vector2i], "kiem_khi", false)
	var seq: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.RIGHT]
	for i: int in 3:
		_step(w3, host3, seq[i])
	var tr3: StepReactorTrait = host3.get_trait("step_reactor") as StepReactorTrait
	_check("reactor waits while boss busy", tr3.get_fire_count() == 0 and tr3.get_charges() == 3)
	b3.cancel()
	host3.on_tick(0.05)
	_check("reactor fires when free", tr3.get_fire_count() == 1 and tr3.get_charges() == 0)


func _test_fuse() -> void:
	var w: Dictionary = _world(21)
	var state: CombatState = w["state"]
	var host := _host(w, [{"id": "fuse_cannon"}])
	var tr: FuseCannonTrait = host.get_trait("fuse_cannon") as FuseCannonTrait
	var tt: Array = [0.0]
	_run_until(w, host, tt, 11.9)
	_check("fuse not yet at 11.9", tr.get_blast_count() == 0 and tr.get_warning_cells().is_empty() and tr.get_fuse_left() > 0.0)
	_run_until(w, host, tt, 12.2)
	var row: Array[Vector2i] = tr.get_warning_cells()
	_check("fuse warning row at 12s", not row.is_empty())
	var all_row: bool = true
	for c: Vector2i in row:
		all_row = all_row and c.y == state.player_cell.y
	_check("fuse warning is player row only", all_row and row.size() == (w["grid"] as BoardGrid).side_cols)
	var hp0: float = state.player_hp
	_run_until(w, host, tt, 13.0)
	_check("fuse blast dealt 40 to player", is_equal_approx(hp0 - state.player_hp, 40.0), str(hp0 - state.player_hp))
	_check("fuse restarted", tr.get_blast_count() == 1 and tr.get_fuse_left() > 11.0)
	var w2: Dictionary = _world(22)
	var s2: CombatState = w2["state"]
	var h2 := _host(w2, [{"id": "fuse_cannon", "params": {"fuse_sec": 1.0}}])
	var t2: Array = [0.0]
	_run_until(w2, h2, t2, 1.05)
	var cur: int = s2.player_cell.y
	_check("fuse dodge: warning running", not (h2.get_trait("fuse_cannon") as FuseCannonTrait).get_warning_cells().is_empty())
	s2.set_player_cell(Vector2i(s2.player_cell.x, (cur + 1) % 3))
	var hp2: float = s2.player_hp
	_run_until(w2, h2, t2, 2.0)
	_check("fuse dodge: no damage when player left row", is_equal_approx(s2.player_hp, hp2))
	var w3: Dictionary = _world(23)
	var h3 := _host(w3, [{"id": "fuse_cannon"}])
	var f3: FuseCannonTrait = h3.get_trait("fuse_cannon") as FuseCannonTrait
	var t3: Array = [0.0]
	_run_until(w3, h3, t3, 5.0)
	h3.on_boss_damaged(29.0)
	_check("fuse 29 does not reset", f3.get_fuse_left() < 7.5)
	h3.on_boss_damaged(30.0)
	_check("fuse 30 resets", is_equal_approx(f3.get_fuse_left(), 12.0))


func _test_slam() -> void:
	var w: Dictionary = _world(31)
	var state: CombatState = w["state"]
	var grid: BoardGrid = w["grid"]
	var mover: UnitMover = w["mover"]
	var host := _host(w, [{"id": "slam"}])
	var tr: SlamTrait = host.get_trait("slam") as SlamTrait
	var tt: Array = [0.0]
	_run_until(w, host, tt, 6.9)
	_check("slam nothing before 7s", tr.get_warning_cells().is_empty() and tr.get_cracked_cells().is_empty())
	_run_until(w, host, tt, 7.2)
	var warn: Array[Vector2i] = tr.get_warning_cells()
	_check("slam warns exactly 2 cells", warn.size() == 2, str(warn))
	_check("slam never under player", not warn.has(state.player_cell))
	_check("slam cells on player half", grid.is_player_cell(warn[0]) and grid.is_player_cell(warn[1]))
	_check("slam warned cell not blocked yet", not tr.is_cracked(warn[0]))
	_run_until(w, host, tt, 8.0)
	var cr: Array[Vector2i] = tr.get_cracked_cells()
	_check("slam cracked 2 cells after 0.8s", cr.size() == 2 and tr.get_warning_cells().is_empty())
	# put the player next to a cracked cell and try to step onto it
	var target: Vector2i = cr[0]
	var next_to: Vector2i = BoardGrid.NO_CELL
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if grid.is_player_cell(target + d) and not cr.has(target + d):
			next_to = target + d
			break
	state.set_player_cell(next_to)
	mover.tick(10.0)
	var dir: Vector2i = target - next_to
	var refused: bool = not mover.try_step(dir) and state.player_cell == next_to
	_check("slam blocks stepping onto cracked", refused)
	_run_until(w, host, tt, 11.7)
	_check("slam still cracked before crack_sec ends", tr.is_cracked(target))
	_run_until(w, host, tt, 12.0)
	_check("slam first batch expired", not tr.is_cracked(cr[0]) and not tr.is_cracked(cr[1]))
	mover.tick(10.0)
	_check("slam step allowed after expiry", mover.try_step(dir))
	var w2: Dictionary = _world(32)
	var h2 := _host(w2, [{"id": "slam", "params": {"cracked_cells": 9, "slam_damage": 20.0, "slam_interval_sec": 1.0}}])
	var s2: CombatState = w2["state"]
	var hp: float = s2.player_hp
	var t2: Array = [0.0]
	_run_until(w2, h2, t2, 1.9)
	var tr2: SlamTrait = h2.get_trait("slam") as SlamTrait
	_check("slam all-but-player cracked (8)", tr2.get_cracked_cells().size() == 8, str(tr2.get_cracked_cells().size()))
	_check("slam no damage when player not on cracked cell", is_equal_approx(s2.player_hp, hp))
	var w3: Dictionary = _world(33)
	var h3 := _host(w3, [{"id": "slam", "params": {"cracked_cells": 8, "slam_interval_sec": 1.0, "warning_sec": 0.5}}])
	var s3: CombatState = w3["state"]
	var t3: Array = [0.0]
	_run_until(w3, h3, t3, 1.05)
	var wc: Array[Vector2i] = (h3.get_trait("slam") as SlamTrait).get_warning_cells()
	var hp3: float = s3.player_hp
	var moved: bool = false
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if wc.has(s3.player_cell + d):
			(w3["mover"] as UnitMover).tick(10.0)
			moved = (w3["mover"] as UnitMover).try_step(d)
			break
	_run_until(w3, h3, t3, 1.7)
	_check("slam damages unit standing on warned cell when it cracks", moved and is_equal_approx(hp3 - s3.player_hp, 20.0), str(hp3 - s3.player_hp))
	var field := CrackField.new()
	field.announce([Vector2i(1, 1)] as Array[Vector2i], 0.5, 1.0)
	field.tick(0.4)
	_check("crackfield warned", field.is_warned(Vector2i(1, 1)) and not field.is_cracked(Vector2i(1, 1)))
	field.tick(0.2)
	_check("crackfield cracked", field.is_cracked(Vector2i(1, 1)))
	field.tick(1.0)
	_check("crackfield expired", not field.is_cracked(Vector2i(1, 1)))


func _test_frost() -> void:
	var w: Dictionary = _world(41)
	var state: CombatState = w["state"]
	var drops: FieldDrops = w["drops"]
	var host := _host(w, [{"id": "frost_aura"}])
	var tr: FrostAuraTrait = host.get_trait("frost_aura") as FrostAuraTrait
	_check("frost active at full hp", tr.is_active() and is_equal_approx(drops.interval_scale, 1.25))
	state.enemy_hp = 51.0
	host.on_tick(0.05)
	_check("frost active at 51%", tr.is_active())
	state.enemy_hp = 50.0
	host.on_tick(0.05)
	_check("frost off at 50%", not tr.is_active() and is_equal_approx(drops.interval_scale, 1.0))
	state.enemy_hp = 90.0
	host.on_tick(0.05)
	_check("frost stays off", not tr.is_active())
	var cfg := FieldDropsConfig.new()
	cfg.initial_delay_sec = 0.0
	cfg.piece_spawn_interval_sec = 1.0
	cfg.piece_max_on_field = 99
	cfg.piece_freshness_sec = 1000.0
	var grid := BoardGrid.new(3, 3)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var fast := FieldDrops.new(cfg, grid.player_cells(), 1)
	var slow := FieldDrops.new(cfg, grid.player_cells(), 1)
	fast.enable_pieces(lib, "ch1", grid, 1)
	slow.enable_pieces(lib, "ch1", grid, 1)
	slow.interval_scale = 1.0 / 0.8
	for i: int in 60:
		fast.tick(0.1, Vector2i(-1, -1), 1)
		slow.tick(0.1, Vector2i(-1, -1), 1)
	var nf: int = fast.get_points().size()
	var ns: int = slow.get_points().size()
	_check("frost slows spawn count", ns < nf, "%d vs %d" % [nf, ns])
	var wp: Dictionary = _world(42)
	var hp := _host(wp, [{"id": "frost_aura", "params": {"rune_rate_mult": 0.5, "until_hp_ratio": 0.8}}])
	_check("frost params honoured", is_equal_approx((wp["drops"] as FieldDrops).interval_scale, 2.0))
	(wp["state"] as CombatState).enemy_hp = 70.0
	hp.on_boss_damaged(5.0)
	_check("frost params ratio honoured", not (hp.get_trait("frost_aura") as FrostAuraTrait).is_active())


func _test_phase() -> void:
	var w: Dictionary = _world(51)
	var state: CombatState = w["state"]
	var boss: BossController = w["boss"]
	var host := _host(w, [{"id": "phase_shift"}])
	var phases: Array = []
	host.phase_changed.connect(func(p: int) -> void: phases.append(p))
	var tr: PhaseShiftTrait = host.get_trait("phase_shift") as PhaseShiftTrait
	_check("phase starts 1", tr.get_phase() == 1)
	state.enemy_hp = 51.0
	host.on_tick(0.05)
	_check("phase still 1 at 51%", tr.get_phase() == 1 and host.size() == 1)
	state.enemy_hp = 50.0
	host.on_boss_damaged(1.0)
	_check("phase 2 at 50%", tr.get_phase() == 2)
	_check("phase switched brain set", boss.get_brain().get_set_name() == "aggressive", boss.get_brain().get_set_name())
	_check("phase added row_burner", host.get_trait("row_burner") != null and host.size() == 2)
	_check("phase step cooldown x0.85", is_equal_approx(boss.get_mover().cooldown_mult, 0.85))
	state.enemy_hp = 10.0
	host.on_tick(0.05)
	host.on_boss_damaged(1.0)
	_check("phase fires once", phases == [2] and host.size() == 2 and is_equal_approx(boss.get_mover().cooldown_mult, 0.85), str(phases))
	var w2: Dictionary = _world(52)
	var h2 := _host(w2, [{"id": "phase_shift", "params": {"at_hp_ratio": 0.9, "extra_traits": [{"id": "slam"}, {"id": "nope"}], "step_mult": 0.5}}])
	(w2["state"] as CombatState).enemy_hp = 89.0
	h2.on_tick(0.05)
	_check("phase params honoured (slam added, unknown skipped)", h2.get_trait("slam") != null and h2.size() == 2 and is_equal_approx((w2["boss"] as BossController).get_mover().cooldown_mult, 0.5))


func _test_defaults_teardown() -> void:
	var w: Dictionary = _world(61)
	var host := _host(w, [
		{"id": "step_reactor", "params": {"charges_to_fire": "x"}}, {"id": "fuse_cannon", "params": {"fuse_sec": null}},
		{"id": "slam", "params": {"cracked_cells": "many"}}, {"id": "frost_aura", "params": {}}, {"id": "phase_shift", "params": {"extra_traits": 5}},
	])
	_check("bad params -> 5 traits", host.size() == 5)
	_check("default charges 3", (host.get_trait("step_reactor") as StepReactorTrait).get_charges_to_fire() == 3)
	_check("default fuse 12", is_equal_approx((host.get_trait("fuse_cannon") as FuseCannonTrait).get_fuse_sec(), 12.0))
	var slam: SlamTrait = host.get_trait("slam") as SlamTrait
	_check("default slam interval 7", is_equal_approx(slam.get_next_slam_left(), 7.0))
	_check("mover blocker installed", (w["mover"] as UnitMover).blocked_cell_fn.is_valid())
	_check("frost default scale", is_equal_approx((w["drops"] as FieldDrops).interval_scale, 1.25))
	host.teardown_all()
	_check("teardown clears traits", host.size() == 0)
	_check("teardown removes blocker", not (w["mover"] as UnitMover).blocked_cell_fn.is_valid())
	_check("teardown restores rune scale", is_equal_approx((w["drops"] as FieldDrops).interval_scale, 1.0))
	host.teardown_all()
	_check("teardown twice ok", true)
