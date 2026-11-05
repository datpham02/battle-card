extends SceneTree
## Cast rhythm spec 2026-11-05 (design/quick-specs/nhip-ra-chieu-2026-11-05.md), Knight story: the shared conditional
## crit (1.2, `target_pinned`) and the `parry` cast mode (1.1, card do_kiem). Covers: crit only while the target is
## pinned and x mult after Ran; a parry card is unavailable with no enemy telegraph and available during a pattern
## WINDUP / WARNING or a block-brain boss swing; a pattern strike inside the guard deals 0 to the hero, reflects
## reflect_mult x its damage and pins the enemy; a strike after the window hurts normally; a burn tick is never parried;
## a block-brain boss swing is parried the same way and does not interrupt the hero; the timeout pick skips do_kiem
## without a telegraph; the Knight's starter holds do_kiem and the boss card list never does.
## Pure logic: fixture worlds built in code (the card data is read from cards.json, the game's real numbers).
## Run: godot --headless --path . -s res://tests/unit/combat/parry_crit_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const PARRY_CARD: String = "do_kiem"
const CRIT_CARD: String = "kiem_vu"

var fails: int = 0
var _cards: SkillConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cards = SkillConfig.load_from_file()
	test_crit_data_is_normalised()
	test_crit_applies_only_when_target_pinned()
	test_parry_card_unavailable_without_telegraph()
	test_parry_card_available_during_windup_and_warning()
	test_parry_card_available_during_boss_swing()
	test_hit_inside_window_is_parried_reflected_and_pins()
	test_hit_after_window_hurts_normally()
	test_burn_tick_is_not_parried()
	test_boss_swing_inside_window_is_parried()
	test_parry_card_hit_never_interrupts_the_enemy_attack()
	test_timeout_pick_skips_parry_without_telegraph()
	test_knight_starter_holds_parry_and_boss_never_does()
	test_crit_counts_when_cast_starts_on_a_frozen_foe()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_crit_data_is_normalised() -> void:
	var crit: Dictionary = _cards.get_skill(CRIT_CARD).get("crit", {}) as Dictionary
	_check("test_crit_field_loaded_from_cards_json", str(crit.get("when", "")) == "target_pinned" and is_equal_approx(float(crit.get("mult", 0.0)), 1.5), str(crit))
	_check("test_crit_unknown_condition_is_dropped", CritRules.normalize({"when": "moon_full", "mult": 3.0}).is_empty())
	_check("test_crit_mult_floored_at_1", is_equal_approx(float(CritRules.normalize({"when": "target_pinned", "mult": 0.5})["mult"]), 1.0))
	_check("test_kiem_vu_thiet_kiem_chan_phong_carry_the_crit",
		["kiem_vu", "thiet_kiem", "chan_phong"].all(func(id: String) -> bool: return not (_cards.get_skill(id).get("crit", {}) as Dictionary).is_empty()))


func _crit_world() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 500.0)
	var status := StatusEffects.new()
	return {"grid": grid, "state": state, "status": status}


func _player_hit(w: Dictionary, card: String) -> Dictionary:
	var state: CombatState = w["state"]
	var cells: Array[Vector2i] = [state.enemy_cell, state.enemy_cell + Vector2i(0, 1) if state.enemy_cell.y < 2 else state.enemy_cell + Vector2i(0, -1)]
	return CutEffects.apply(state, w["grid"], P, cells, card, CutConfig.new(), _cards, w["status"])


func test_crit_applies_only_when_target_pinned() -> void:
	var dpc: float = float(_cards.get_skill(CRIT_CARD)["damage_per_cell"])
	var plain: Dictionary = _player_hit(_crit_world(), CRIT_CARD)
	_check("test_unpinned_target_no_crit", not bool(plain["crit"]) and is_equal_approx(float(plain["damage"]), dpc * 2.0), str(plain["damage"]))
	var w: Dictionary = _crit_world()
	var status: StatusEffects = w["status"]
	status.pin(E, 2.0)
	var pin_mult: float = status.damage_mult_against(E)
	var crit: Dictionary = _player_hit(w, CRIT_CARD)
	_check("test_pinned_target_crits_x1_5", bool(crit["crit"]) and is_equal_approx(float(crit["damage"]), dpc * 2.0 * pin_mult * 1.5),
		"%s vs %s" % [crit["damage"], dpc * 2.0 * pin_mult * 1.5])
	# After Ran: x fragile then x crit (order: Ran -> crit).
	var w2: Dictionary = _crit_world()
	var st2: StatusEffects = w2["status"]
	st2.pin(E, 2.0)
	st2.apply_fragile(E, 1)
	var fragile_mult: float = st2.fragile_mult if "fragile_mult" in st2 else 1.0
	var both: Dictionary = _player_hit(w2, CRIT_CARD)
	_check("test_crit_stacks_with_ran", bool(both["crit"]) and bool(both["fragile_hit"]) and float(both["damage"]) > float(crit["damage"]) - 0.001,
		"%s (fragile mult %s)" % [both["damage"], fragile_mult])
	# A card without crit never crits on a pinned target.
	var w3: Dictionary = _crit_world()
	(w3["status"] as StatusEffects).pin(E, 2.0)
	_check("test_card_without_crit_never_crits", not bool(_player_hit(w3, "kiem_khi")["crit"]))
	# The block-brain boss reuses player cards: its swings never crit (crit is the hero's rule, spec 1.2 / 1.3).
	var w4: Dictionary = _crit_world()
	var st4: CombatState = w4["state"]
	(w4["status"] as StatusEffects).pin(P, 2.0)
	var boss_hit: Dictionary = CutEffects.apply(st4, w4["grid"], E, [st4.player_cell] as Array[Vector2i], CRIT_CARD, CutConfig.new(), _cards, w4["status"])
	_check("test_boss_swing_never_crits_on_a_pinned_hero", bool(boss_hit["hit"]) and not bool(boss_hit["crit"]), str(boss_hit["damage"]))


func _ctx(on: bool) -> Dictionary:
	return {SkillAvailability.CTX_ENEMY_TELEGRAPH: on}


func test_parry_card_unavailable_without_telegraph() -> void:
	var none: Dictionary = SkillAvailability.check(_cards, SkillCooldowns.new(), PARRY_CARD, 1)
	_check("test_parry_unavailable_with_no_context", not bool(none["available"]) and str(none["reason"]) == "no_telegraph", str(none))
	var off: Dictionary = SkillAvailability.check(_cards, SkillCooldowns.new(), PARRY_CARD, 1, 1, _ctx(false))
	_check("test_parry_unavailable_with_no_telegraph", not bool(off["available"]))
	_check("test_parry_available_with_telegraph", bool(SkillAvailability.check(_cards, SkillCooldowns.new(), PARRY_CARD, 1, 1, _ctx(true))["available"]))
	_check("test_direct_card_ignores_the_context", bool(SkillAvailability.check(_cards, SkillCooldowns.new(), "kiem_khi", 1)["available"]))
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill("fx_2"), "solo", 3)
	_check("test_idle_enemy_is_no_telegraph", not ParryGuard.enemy_telegraph(w["ctrl"], null))


func _one_skill(skill_id: String) -> EnemySkillsConfig:
	return EnemySkillsConfig.from_dictionary({"skills": Fx.skills(), "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": [skill_id]}}})


# Ticks status, guard and controller in STEP slices until the controller reaches [param stage] (or [param limit] s).
func _tick_until(w: Dictionary, stage: int, guard: ParryGuard = null, limit: float = 6.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		if guard != null:
			guard.tick(STEP)
		ctrl.tick(STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


func test_parry_card_available_during_windup_and_warning() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill("fx_2"), "solo", 4)
	var ctrl: PatternController = w["ctrl"]
	_check("fixture: windup reached", _tick_until(w, PatternController.Stage.WINDUP))
	_check("test_windup_is_a_telegraph", ParryGuard.enemy_telegraph(ctrl, null) and ctrl.is_threatening())
	_check("fixture: warning reached", _tick_until(w, PatternController.Stage.WARNING))
	_check("test_warning_is_a_telegraph", ParryGuard.enemy_telegraph(ctrl, null))
	_check("test_strike_time_left_is_the_warning_left", ctrl.strike_time_left() <= 1.0 + 0.001 and ctrl.strike_time_left() > 0.0, str(ctrl.strike_time_left()))
	_check("fixture: recovery reached", _tick_until(w, PatternController.Stage.RECOVERY))
	_check("test_recovery_is_no_telegraph", not ParryGuard.enemy_telegraph(ctrl, null))


func test_parry_card_available_during_boss_swing() -> void:
	var boss_actor := CutActor.new(CutConfig.new(), E)
	_check("test_idle_boss_actor_is_no_telegraph", not ParryGuard.enemy_telegraph(null, boss_actor))
	boss_actor.begin_swing([Vector2i(1, 1)] as Array[Vector2i], "kiem_khi", false)
	_check("test_swinging_boss_actor_is_a_telegraph", ParryGuard.enemy_telegraph(null, boss_actor))


# A fx_2 strike (14 damage, no status) on a still hero; the guard opens [param open_before] s before the strike.
func _parry_case(open_before: float) -> Dictionary:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill("fx_2"), "solo", 5)
	var ctrl: PatternController = w["ctrl"]
	var guard := ParryGuard.new()
	ctrl.player_guard = guard
	var card: Dictionary = _cards.resolved(PARRY_CARD, 1)
	_tick_until(w, PatternController.Stage.WARNING)
	var opened: bool = false
	var t: float = 0.0
	var resolved: Array[Dictionary] = []  # an array: a lambda captures locals by value
	ctrl.skill_resolved.connect(func(_id: String, r: Dictionary) -> void: resolved.append(r))
	while t < 4.0 and resolved.is_empty():
		if not opened and ctrl.strike_time_left() <= open_before + 0.0001:
			guard.open_from_card(card)
			opened = true
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		guard.tick(STEP)
		ctrl.tick(STEP)
		t += STEP
	w["guard"] = guard
	w["card"] = card
	w["result"] = resolved[0] if not resolved.is_empty() else {}
	return w


func test_hit_inside_window_is_parried_reflected_and_pins() -> void:
	var w: Dictionary = _parry_case(0.4)
	var state: CombatState = w["state"]
	var card: Dictionary = w["card"]
	var r: Dictionary = w["result"]
	_check("fixture: the strike hit the hero's cell", bool(r.get("hit", false)), str(r))
	_check("test_parried_hit_deals_zero_to_hero", is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	var reflect: float = 14.0 * float(card["reflect_mult"])
	_check("test_parry_reflects_reflect_mult_x_damage", is_equal_approx(state.enemy_hp, 300.0 - reflect), "%s (want %s)" % [state.enemy_hp, 300.0 - reflect])
	_check("test_parry_pins_the_enemy", (w["status"] as StatusEffects).is_pinned(E))
	_check("test_parry_result_reports_it", bool(r.get("parried", false)) and is_equal_approx(float(r.get("reflected", 0.0)), reflect))
	_check("test_guard_closes_after_one_parry", not (w["guard"] as ParryGuard).is_active() and (w["guard"] as ParryGuard).parries == 1)


func test_hit_after_window_hurts_normally() -> void:
	var w: Dictionary = _parry_case(0.95)  # guard 0.8 s opened 0.95 s before the strike: closed when it lands
	var state: CombatState = w["state"]
	_check("test_hit_after_window_hurts", is_equal_approx(state.player_hp, 86.0), str(state.player_hp))
	_check("test_no_reflect_after_window", is_equal_approx(state.enemy_hp, 300.0) and not (w["status"] as StatusEffects).is_pinned(E))
	_check("test_whiffed_guard_counts_no_parry", (w["guard"] as ParryGuard).parries == 0)


func test_burn_tick_is_not_parried() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var status := StatusEffects.new()
	var guard := ParryGuard.new()
	guard.open(5.0, 1.5, 1.2)
	status.ignite([state.player_cell] as Array[Vector2i], 2.0, 0.5, 3.0)
	for i: int in 12:
		status.tick(0.1, state)
		guard.tick(0.1)
	_check("test_burn_tick_hurts_through_the_guard", state.player_hp < 100.0, str(state.player_hp))
	_check("test_burn_tick_leaves_the_guard_open", guard.is_active() and guard.parries == 0 and is_equal_approx(state.enemy_hp, 100.0))


func test_boss_swing_inside_window_is_parried() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var status := StatusEffects.new()
	var cc := CutConfig.new()
	var pa := CutActor.new(cc, P)
	var ba := CutActor.new(cc, E)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, _cards, status)
	var guard := ParryGuard.new()
	arb.player_guard = guard
	var interrupted: Array = []
	arb.swing_interrupted.connect(func(s: int, _c: Array[Vector2i], _k: String) -> void: interrupted.append(s))
	ba.begin_swing([state.player_cell] as Array[Vector2i], "kiem_khi", false)
	# The hero's own long swing runs meanwhile, aimed away: a normal boss hit would interrupt it.
	pa.begin_swing([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 0), Vector2i(4, 2)] as Array[Vector2i], "kiem_khi", true, 1, 10.0)
	guard.open(10.0, 1.5, 1.2)
	arb.tick(ba.get_time_left() + 0.01)
	var dmg: float = float(_cards.get_skill("kiem_khi")["damage_per_cell"])
	_check("test_boss_swing_parried_deals_zero", is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	_check("test_boss_swing_reflected_and_pinned", is_equal_approx(state.enemy_hp, 100.0 - dmg * 1.5) and status.is_pinned(E), str(state.enemy_hp))
	_check("test_parried_boss_swing_does_not_interrupt_the_hero", interrupted.is_empty() and pa.is_swinging())


# Design decision (story note in the spec): the parry card's own small hit must not cancel the attack it answers, or a
# parry could never land on an interruptible skill (the default). Block brain: the arbiter does not cancel the boss's
# swing; pattern brain: CombatView / the sim skip PatternController.on_enemy_hit for a parry card (SwingArbiter
# reports result.no_interrupt for both).
func test_parry_card_hit_never_interrupts_the_enemy_attack() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var cc := CutConfig.new()
	var pa := CutActor.new(cc, P)
	var ba := CutActor.new(cc, E)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, _cards, StatusEffects.new())
	var results: Array[Dictionary] = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void:
		if side == P:
			results.append(r))
	ba.begin_swing([state.player_cell] as Array[Vector2i], "kiem_khi", false, 1, 10.0)
	pa.begin_swing([state.enemy_cell] as Array[Vector2i], PARRY_CARD, true, 1, 0.1)
	arb.tick(0.2)
	_check("fixture: the parry card hit the enemy", not results.is_empty() and bool(results[0]["hit"]))
	_check("test_parry_card_hit_keeps_the_boss_swing", ba.is_swinging())
	_check("test_parry_card_result_says_no_interrupt", not results.is_empty() and bool(results[0].get("no_interrupt", false)))
	# A direct card still interrupts (unchanged rule).
	var pa2 := CutActor.new(cc, P)
	var ba2 := CutActor.new(cc, E)
	var arb2 := SwingArbiter.new(state, grid, pa2, ba2, cc, _cards, StatusEffects.new())
	ba2.begin_swing([state.player_cell] as Array[Vector2i], "kiem_khi", false, 1, 10.0)
	pa2.begin_swing([state.enemy_cell] as Array[Vector2i], "kiem_khi", true, 1, 0.1)
	arb2.tick(0.2)
	_check("test_direct_card_hit_still_interrupts", not ba2.is_swinging())


func test_timeout_pick_skips_parry_without_telegraph() -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 0)]
	var ok: bool = true
	var telegraph: bool = false
	for seed: int in 30:
		var flow := CutFlow.new(_cards, SkillCooldowns.new())
		flow.rng.seed = seed
		flow.availability_context_fn = func() -> Dictionary: return {SkillAvailability.CTX_ENEMY_TELEGRAPH: telegraph}
		var chosen: Array[String] = []
		flow.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: chosen.append(id))
		flow.open_menu(["a"] as Array[String], cells, [PARRY_CARD, PARRY_CARD, "kiem_vu"] as Array[String], 0.1)
		flow.tick_real(0.2)
		ok = ok and chosen == ([_cards.default_card] as Array[String])
	_check("test_timeout_never_casts_parry_without_telegraph", ok)
	telegraph = true
	var flow2 := CutFlow.new(_cards, SkillCooldowns.new())
	flow2.availability_context_fn = func() -> Dictionary: return {SkillAvailability.CTX_ENEMY_TELEGRAPH: telegraph}
	var got: Array[String] = []
	flow2.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: got.append(id))
	flow2.open_menu(["a"] as Array[String], cells, [PARRY_CARD] as Array[String], 0.1)
	flow2.tick_real(0.2)
	_check("test_timeout_may_cast_parry_during_a_telegraph", got == ([PARRY_CARD] as Array[String]), str(got))


func test_knight_starter_holds_parry_and_boss_never_does() -> void:
	var chars: CharacterConfig = CharacterConfig.load_from_file()
	var deck: Array[String] = chars.deck_of("kiem_si")
	_check("test_knight_starter_has_do_kiem", deck.has(PARRY_CARD) and deck.size() == 6, str(deck))
	_check("test_knight_starter_lost_one_kiem_khi", deck.count("kiem_khi") == 0, str(deck))
	_check("test_do_kiem_is_a_player_card", _cards.is_player_card(PARRY_CARD) and _cards.card_order.has(PARRY_CARD))
	_check("test_boss_card_list_never_holds_do_kiem", not _cards.boss_card_order().has(PARRY_CARD))
	var card: Dictionary = _cards.get_skill(PARRY_CARD)
	_check("test_do_kiem_numbers_from_data", int(card["min_cells"]) == 1 and is_equal_approx(float(card["cooldown_sec"]), 6.0)
		and is_equal_approx(float(card["damage_per_cell"]), 3.0) and is_equal_approx(float(card["parry_sec"]), 0.8)
		and is_equal_approx(float(card["reflect_mult"]), 1.5) and is_equal_approx(float(card["parry_pin_sec"]), 1.2), str(card))


# Fix 2026-11-05: a Pin lasts 1.2 s while a 3-6 cell swing lasts 0.95-1.7 s, so reading the crit only at the hit missed
# almost every "cast on the Frozen foe" crit (the sim showed 0 crits / match). The arbiter snapshots the condition when
# the hero's swing starts.
func test_crit_counts_when_cast_starts_on_a_frozen_foe() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0)
	var status := StatusEffects.new()
	var cc := CutConfig.new()
	var pa := CutActor.new(cc, P)
	var ba := CutActor.new(cc, E)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, _cards, status)
	var results: Array[Dictionary] = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void:
		if side == P:
			results.append(r))
	status.pin(E, 0.3)
	pa.begin_swing([state.enemy_cell] as Array[Vector2i], "thiet_kiem", true, 1, 1.0)
	for i: int in 10:
		status.tick(0.11, state)
		arb.tick(0.11)
	_check("fixture: the pin ended before the hit", not status.is_pinned(E))
	_check("test_cast_on_frozen_foe_crits_after_the_pin_ends", not results.is_empty() and bool(results[0].get("crit", false)), str(results))
