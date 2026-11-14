extends SceneTree
## Multi-enemy Phase 5 step 1 (docs/design/world-map-v2/MULTI-ENEMY-PHASE3-5-PLAN.md 3.3-3.4): one TraitHost per
## enemy unit, the five one-point hooks installed by CombatView and routed by unit key, and trait ticking that no
## longer stops because unit 0 died.
##
## Every check here leads with a POSITIVE assertion. A suite built only from absence assertions ("unit 0 was not
## affected") passes just as happily against a dispatcher that fires for nobody at all, which is exactly the state
## this step could fail into: the hooks are single slots and TraitHost no longer installs them.
##
## Run: godot --headless --path . -s res://tests/unit/combat/multi_enemy_traits_test.gd
##
## LIMIT OF THIS SUITE (multi-enemy Phase 5): it asserts STATE, never a frame. That the dispatch reaches the
## right unit is checked here; that a PLAYER can tell which enemy a trait fired for is NOT, and cannot be -
## this harness captures no frames. The failure it is blind to is the ambiguous unit, not the wrong one.
## The Phase 5 visual gate (production/qa/evidence/) is what would retire this paragraph. Until those frames
## exist, a green run here is not evidence that the feature reads on screen.

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const SEED: int = 7
const DT: float = 0.05
const ARENA: Dictionary = {"side_cols": 5, "side_rows": 4, "missing_cells": []}

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _initialize() -> void:
	await process_frame
	await _test_a_host_per_unit()
	await _test_untargetable_is_per_unit()
	await _test_burn_heal_is_per_unit()
	await _test_tick_survives_unit0_death()
	await _test_burrow_moves_its_own_unit()
	await _test_rebirth_revives_its_own_unit()
	await _test_hop_skip_counts_its_own_steps()
	await _test_one_enemy_unchanged()
	await process_frame
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


func _block(id: String, hp: float = 80.0) -> Dictionary:
	return {"id": id, "max_hp": hp, "brain": "block", "ai": {"boss_think_interval_sec": 0.3}}


func _params(entries: Array) -> Dictionary:
	var first: Dictionary = entries[0]
	var raw: Dictionary = {"id": str(first.get("id", "fx")), "boss_max_hp": float(first["max_hp"]), "arena": ARENA,
		"end_delay_sec": 0.0, "boss_think_interval_sec": 0.3}
	if entries.size() > 1:
		raw["enemies"] = entries
		raw["attack_slots"] = 1
	var m: Dictionary = RunConfig.clean_match(raw, 0)
	m["end_delay_sec"] = 0.0
	return m


func _match(params: Dictionary) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = params
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	return holder


func _view(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# --- one host per unit ------------------------------------------------------------------------------------------

func _test_a_host_per_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b"), _block("c")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var hosts: Array = []
	for key: int in s.enemy_keys():
		hosts.append(v.host_of(key))
	check(hosts.size() == 3 and not hosts.has(null), "hosts: every enemy unit has its own TraitHost", str(hosts.size()))
	check(hosts[0] != hosts[1] and hosts[1] != hosts[2], "hosts: they are three distinct objects")
	check(v.host_of(E) == v.get_trait_host(), "hosts: unit 0's host is still the one the HUD reads")
	var keys_ok: bool = true
	for key: int in s.enemy_keys():
		if v.host_of(key).key != key:
			keys_ok = false
	check(keys_ok, "hosts: each host knows its own unit key")
	_drop(holder)


# --- the hooks answer per unit ----------------------------------------------------------------------------------

func _test_untargetable_is_per_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var k1: int = CombatState.unit_key(1)
	var arbiter: SwingArbiter = v.get_arbiter()
	check(arbiter.enemy_untargetable_fn.is_valid(), "untargetable: the view installed the hook, not a host")
	check(not bool(arbiter.enemy_untargetable_fn.call(E)) and not bool(arbiter.enemy_untargetable_fn.call(k1)),
		"untargetable: nobody is hidden before a burrow exists")

	# Burrow on unit 1 only. The POSITIVE leg is the one that matters: unit 1 must actually become unhittable.
	var host: TraitHost = v.host_of(k1)
	var added: BossTrait = host.add_trait("burrow", {"interval_sec": 0.01, "burrow_sec": 5.0, "surface_warn_sec": 0.5})
	check(added != null, "untargetable: burrow was added to unit 1's host")
	for i: int in 60:
		host.on_tick(DT)
	check(bool(arbiter.enemy_untargetable_fn.call(k1)), "untargetable: unit 1 IS hidden while burrowed")
	check(not bool(arbiter.enemy_untargetable_fn.call(E)),
		"untargetable: unit 0 stays hittable — the old single slot made a burrow anywhere hide unit 0")
	_drop(holder)


func _test_burn_heal_is_per_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var k1: int = CombatState.unit_key(1)
	var status: StatusEffects = v.get_status()
	check(status.burn_heal_ratio_fn.is_valid(), "burn heal: the view installed the hook")
	v.host_of(k1).add_trait("burn_eater", {"heal_ratio": 1.0})
	check(float(status.burn_heal_ratio_fn.call(k1)) > 0.0, "burn heal: unit 1 with burn_eater reports a ratio",
		str(status.burn_heal_ratio_fn.call(k1)))
	check(is_equal_approx(float(status.burn_heal_ratio_fn.call(E)), 0.0),
		"burn heal: unit 0 without it reports zero", str(status.burn_heal_ratio_fn.call(E)))
	_drop(holder)


# --- the live bug this step fixes -------------------------------------------------------------------------------

func _test_tick_survives_unit0_death() -> void:
	var holder: Node = await _match(_params([_block("a", 10.0), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var host: TraitHost = v.host_of(k1)
	host.add_trait("burrow", {"interval_sec": 0.01, "burrow_sec": 5.0, "surface_warn_sec": 0.5})

	s.damage_unit(0, 999.0)
	check(s.is_key_dead(E) and not s.is_key_dead(k1), "tick: unit 0 is dead and unit 1 is alive")
	v.freeze_time = false
	for i: int in 60:
		v._process(DT)
	v.freeze_time = true
	# POSITIVE: unit 1's trait kept running. The old gate read is_enemy_dead(), so unit 0's death froze every trait
	# in the match — visible today in a one-enemy match the moment the enemy is downed and then dies.
	check(bool(v.get_arbiter().enemy_untargetable_fn.call(k1)),
		"tick: unit 1's burrow still runs after unit 0 died")
	_drop(holder)


# --- the traits act on their OWN unit ----------------------------------------------------------------------------

# Found while diagnosing the tick failure, and worse than it: these traits did not merely stop when unit 0 died,
# they acted ON unit 0 when they ran. burrow surfaced through set_enemy_cell, rebirth revived through heal_enemy,
# hop_skip hopped from enemy_cell — all unit-0 aliases. A burrow on unit 2 teleported unit 0 across the board.
func _test_burrow_moves_its_own_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var host: TraitHost = v.host_of(k1)
	var trait_obj: BossTrait = host.add_trait("burrow", {"interval_sec": 0.01, "burrow_sec": 0.2, "surface_warn_sec": 0.01})
	var unit0_before: Vector2i = s.cell_of(E)
	var unit1_before: Vector2i = s.cell_of(k1)
	# Long enough to burrow AND surface again, which is the half that moves a cell.
	for i: int in 200:
		host.on_tick(DT)
	# POSITIVE FIRST, and it must be a leg that cannot pass vacuously. The earlier version accepted
	# "unit 1 is not untargetable" as proof of a cycle - true of a burrow that never fired at all. The
	# surface cell is seeded from the cells OTHER than the one it burrowed from, so a completed cycle
	# always moves the unit: count and cell together say the trait ran AND landed somewhere new.
	var burrows: int = int((trait_obj as BurrowTrait).get_burrow_count())
	check(burrows >= 1, "burrow: unit 1's burrow actually fired", "count=%d" % burrows)
	check(s.cell_of(k1) != unit1_before, "burrow: unit 1 itself moved to its surface cell",
		"%s -> %s" % [str(unit1_before), str(s.cell_of(k1))])
	check(s.cell_of(E) == unit0_before,
		"burrow: unit 0 has NOT been moved by unit 1's burrow", "%s -> %s" % [str(unit0_before), str(s.cell_of(E))])
	_drop(holder)


func _test_rebirth_revives_its_own_unit() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b", 20.0)]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	v.host_of(k1).add_trait("rebirth", {"lives": 1, "revive_sec": 0.1, "revive_ratio": 0.4})
	var unit0_hp_before: float = s.hp_of(E)

	s.damage_unit(1, 999.0)
	# POSITIVE: the death hook reached unit 1's own host and the trait caught the death.
	check(not s.is_key_dead(k1) or s.hp_of(k1) > 0.0,
		"rebirth: unit 1's own death was caught by its own host", str(s.hp_of(k1)))
	check(is_equal_approx(s.hp_of(E), unit0_hp_before),
		"rebirth: unit 0's HP was NOT touched — the alias form revived unit 0 instead",
		"%.1f -> %.1f" % [unit0_hp_before, s.hp_of(E)])
	for i: int in 60:
		v.host_of(k1).on_tick(DT)
	check(s.hp_of(k1) > 0.0, "rebirth: unit 1 is alive again after its revive", str(s.hp_of(k1)))
	_drop(holder)


# The monster-skills session's suggestion, and the cheap shape of it: drive the cell signal directly instead of
# fighting a whole match into hopping. This tests the KEYING, which is what step 1 changed, not the hop mechanic.
# The counter ran off the legacy cell_changed, which reports Side.ENEMY for unit 0 alone - so a hop_skip on unit 1
# counted unit 0's steps and never its own, hopping on another unit's clock.
func _test_hop_skip_counts_its_own_steps() -> void:
	var holder: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(holder)
	var s: CombatState = v.get_state()
	var k1: int = CombatState.unit_key(1)
	var t1: HopSkipTrait = v.host_of(k1).add_trait("hop_skip", {"hop_every": 99, "hop_warn_sec": 1.0}) as HopSkipTrait
	check(t1 != null and t1.get_step_count() == 0, "hop_skip: starts at zero steps")

	# POSITIVE: unit 1's own move is counted.
	var before: int = t1.get_step_count()
	check(s.set_key_cell(k1, _free_cell_for(s, k1)), "hop_skip: unit 1's move went through")
	check(t1.get_step_count() > before, "hop_skip: unit 1's own step IS counted",
		"%d -> %d" % [before, t1.get_step_count()])

	# NEGATIVE, and it means something now that the leg above proved the counter is live at all.
	var after_own: int = t1.get_step_count()
	check(s.set_key_cell(E, _free_cell_for(s, E)), "hop_skip: unit 0's move went through too")
	check(t1.get_step_count() == after_own, "hop_skip: unit 0's step is NOT counted for unit 1",
		"%d -> %d" % [after_own, t1.get_step_count()])
	_drop(holder)


# A cell of the enemy half this unit can actually stand on and is not already standing on.
func _free_cell_for(s: CombatState, key: int) -> Vector2i:
	var index: int = CombatState.unit_index_of(key)
	var here: Vector2i = s.cell_of(key)
	for cell: Vector2i in s.grid.enemy_cells():
		if cell != here and s.unit_fits(index, cell):
			return cell
	return here


# --- a one-enemy match must be untouched ------------------------------------------------------------------------

func _test_one_enemy_unchanged() -> void:
	var holder: Node = await _match(_params([_block("solo")]))
	var v: CombatView = _view(holder)
	check(v.host_of(E) != null and v.get_trait_host() == v.host_of(E), "1v1: one host, and it is unit 0's")
	check(v.host_of(CombatState.unit_key(1)) == null, "1v1: there is no second host")
	var arbiter: SwingArbiter = v.get_arbiter()
	check(arbiter.enemy_untargetable_fn.is_valid(), "1v1: the hook is installed")
	v.host_of(E).add_trait("burrow", {"interval_sec": 0.01, "burrow_sec": 5.0, "surface_warn_sec": 0.5})
	for i: int in 60:
		v.host_of(E).on_tick(DT)
	check(bool(arbiter.enemy_untargetable_fn.call(E)), "1v1: a burrowed enemy is still hidden, as before")
	check(v.any_trait("burrow") != null, "1v1: any_trait finds it")
	check(v.any_trait("rebirth") == null, "1v1: any_trait does not invent one")
	_drop(holder)
