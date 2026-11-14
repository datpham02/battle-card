extends SceneTree
## F3 (passive feedback): the cue condition lives on the PASSIVE and matches the rule it marks.
##
## Why this exists as a test and not as a screenshot: a capture proves the cue is *visible*, never
## that it marks the *right* casts. Those are two gates (the lesson from F2's sim mirror: an
## instrument that cannot fail in the presence of the fault proves nothing). This is the correctness
## gate; the retained screenshot is the readability gate, and neither substitutes for the other.
##
## The risk being gated: a drawing layer that re-implemented `cells >= min_cells` would keep using
## the old number after someone tuned characters.json, and the cue would mark the wrong casts while
## every existing test still passed — the player taught a rule the game no longer follows. So the
## passive answers, and these assertions read the SHIPPED params rather than hardcoding 4 and 3.
##
## Headless, pure logic, no scene. Run:
## godot --headless -s res://tests/unit/combat/passive_cue_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" — " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var config: CharacterConfig = CharacterConfig.load_from_file()
	_test_wide_caster(config)
	_test_quick_blade(config)
	_test_event_passives_claim_no_cast_cue(config)
	_test_hunter_mark_event_cue(config)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _passive_of(config: CharacterConfig, character_id: String) -> BasePassive:
	var spec: Dictionary = config.get_character(character_id).get("passive", {}) as Dictionary
	var p: BasePassive = PassiveRegistry.create(str(spec.get("id", "")))
	if p != null:
		p.setup({}, (spec.get("params", {}) as Dictionary))
	return p


# The cue marks exactly the casts the passive speeds up — boundary included, read from the data.
func _test_wide_caster(config: CharacterConfig) -> void:
	var p: BasePassive = _passive_of(config, "phap_su")
	ck("phap_su has wide_caster", p != null and p.get_id() == "wide_caster")
	if p == null:
		return
	var min_cells: int = int((config.get_character("phap_su")["passive"]["params"] as Dictionary).get("min_cells", 4))
	ck("cue ON at the boundary (%d cells)" % min_cells, p.cue_for_cells(min_cells))
	ck("cue ON above it (%d cells)" % (min_cells + 2), p.cue_for_cells(min_cells + 2))
	ck("cue OFF below it (%d cells)" % (min_cells - 1), not p.cue_for_cells(min_cells - 1))
	# The cue and the rule must agree cell for cell, or the mark lies about which casts were sped up.
	for cells: int in range(1, 10):
		var sped: bool = not is_equal_approx(p.modify_swing_duration(cells, 1.0), 1.0)
		ck("%d cells: cue matches the rule" % cells, p.cue_for_cells(cells) == sped,
			"cue=%s sped=%s" % [str(p.cue_for_cells(cells)), str(sped)])


func _test_quick_blade(config: CharacterConfig) -> void:
	var p: BasePassive = _passive_of(config, "sat_thu")
	ck("sat_thu has quick_blade", p != null and p.get_id() == "quick_blade")
	if p == null:
		return
	var max_cells: int = int((config.get_character("sat_thu")["passive"]["params"] as Dictionary).get("max_cells", 4))
	ck("cue ON at the boundary (%d cells)" % max_cells, p.cue_for_cells(max_cells))
	ck("cue OFF above it (%d cells)" % (max_cells + 1), not p.cue_for_cells(max_cells + 1))
	for cells: int in range(1, 10):
		var boosted: bool = not is_equal_approx(p.modify_damage(cells, 1.0), 1.0)
		ck("%d cells: cue matches the rule" % cells, p.cue_for_cells(cells) == boosted,
			"cue=%s boosted=%s" % [str(p.cue_for_cells(cells)), str(boosted)])


# A passive whose trigger is an EVENT, not a cell count, must never claim a per-cast cue — otherwise
# a drawing layer that asks unconditionally would mark every cast of three of the five characters.
func _test_event_passives_claim_no_cast_cue(config: CharacterConfig) -> void:
	for character_id: String in ["kiem_si", "tho_san", "giao_si"]:
		var p: BasePassive = _passive_of(config, character_id)
		if p == null:
			ck("%s has a passive" % character_id, false)
			continue
		var any: bool = false
		for cells: int in range(1, 10):
			if p.cue_for_cells(cells):
				any = true
		ck("%s (%s) claims no per-cast cue" % [character_id, p.get_id()], not any,
			"its trigger is an event, so a cell-count cue would mark unrelated casts")


# F3: hunter_mark's cue is an EVENT cue, and the thing it has to survive is that a card can apply the
# very same Ran stack. If the cue were raised by the stack landing, every Dap Vo card would light the
# hunter's passive. So it is raised inside the passive, after its own rule fired, and these legs pin
# that: a direct status.apply_fragile must leave the cue dark, and a refusal by the internal cooldown
# must too. The one-shot leg matters just as much — a sticky flag would redraw the cue every frame
# until the next mark, teaching the player a frequency the rule does not have.
func _test_hunter_mark_event_cue(config: CharacterConfig) -> void:
	# Arrange — the shipped params, plus a real StatusEffects so the mark can actually land.
	var spec: Dictionary = config.get_character("tho_san").get("passive", {}) as Dictionary
	var params: Dictionary = spec.get("params", {}) as Dictionary
	var icd: float = float(params.get("icd_sec", 0.0))
	var status := StatusEffects.new()
	var p: BasePassive = PassiveRegistry.create(str(spec.get("id", "")))
	ck("tho_san has hunter_mark", p != null and p.get_id() == "hunter_mark")
	if p == null:
		return
	p.setup({"status": status}, params)

	ck("no cue before anything happens", not p.take_event_cue())

	# A CARD applying the identical Ran stack must not light the passive's cue.
	status.apply_fragile(CombatState.Side.ENEMY, 1)
	ck("a card's Ran stack raises no passive cue", not p.take_event_cue(),
		"the chip looks the same; the cue is the only thing that tells them apart")

	# Act — the passive's own rule fires.
	p.on_boss_thorn_step(Vector2i.ZERO)
	ck("the mark raises the cue", p.take_event_cue())
	ck("the cue is one-shot", not p.take_event_cue(),
		"a sticky flag would redraw the cue every frame until the next mark")

	if icd > 0.0:
		# Refused by the internal cooldown: no mark, so no cue may be promised.
		p.on_boss_thorn_step(Vector2i.ZERO)
		ck("a mark refused by the cooldown raises no cue", not p.take_event_cue())
		p.tick(icd)
		p.on_boss_thorn_step(Vector2i.ZERO)
		ck("the cue returns once the cooldown (%.1fs) has passed" % icd, p.take_event_cue())
	else:
		ck("tho_san ships an internal cooldown", false, "icd_sec=0 leaves the cooldown leg untested")

	# teardown must not leave a cue armed for the next match.
	p.fire_event_cue()
	p.teardown()
	ck("teardown clears a pending cue", not p.take_event_cue())
