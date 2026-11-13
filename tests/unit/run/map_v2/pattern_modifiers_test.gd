extends SceneTree
## Monster Skill Phase 1 (Hellfire plan §4.4 / R3): the lane modifiers `big_hands` and `quick_blocks` reach a
## pattern-brain enemy through `pattern_tempo_mult` (0.9 / 0.85) while a block-brain match keeps exactly its old effect
## (boss_min_runes +1 / boss_drop_interval_mult x0.85) and never carries the pattern key. Path under test: the shipped
## region_rules.json modifier -> EncounterComposer.apply_to_raw -> RunConfig._apply_scaling -> RunConfig.from_dictionary.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/pattern_modifiers_test.gd

## Boundary values: a region / floor step_mult whose product is the pattern tempo before the modifier.
const REGION_STEP: float = 1.05
const FLOOR_STEP: float = 0.97

var fails: int = 0


func check(ok: bool, name: String, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var rules: RegionRules = RegionRules.load_from_file()
	check(RegionRules.PATCH_MULT_KEYS.has("pattern_tempo_mult"), "pattern_tempo_mult is a combat patch key")
	var big: Dictionary = rules.modifier("big_hands")
	var quick: Dictionary = rules.modifier("quick_blocks")
	check(is_equal_approx(float((big["match"] as Dictionary).get("pattern_tempo_mult", 0.0)), 0.9), "big_hands carries pattern_tempo_mult 0.9")
	check(is_equal_approx(float((quick["match"] as Dictionary).get("pattern_tempo_mult", 0.0)), 0.85), "quick_blocks carries pattern_tempo_mult 0.85")
	check(int((big["match"] as Dictionary).get("boss_min_runes_add", 0)) == 1 and is_equal_approx(float((quick["match"] as Dictionary).get("boss_drop_interval_mult", 0.0)), 0.85),
		"the block-brain parts are unchanged")
	for mod_id: String in ["big_hands", "quick_blocks"]:
		var patch: Dictionary = (rules.modifier(mod_id)["match"] as Dictionary)
		var want: float = float(patch["pattern_tempo_mult"])
		var pattern_match: Dictionary = _resolve({"id": "imp", "boss_max_hp": 92, "brain": "pattern", "enemy": "imp"}, patch)
		check(is_equal_approx(float(pattern_match.get("pattern_tempo_mult", 0.0)), want * REGION_STEP * FLOOR_STEP),
			"%s: pattern enemy tempo = %.2f x region x floor" % [mod_id, want], str(pattern_match.get("pattern_tempo_mult")))
		var plain_pattern: Dictionary = _resolve({"id": "imp", "boss_max_hp": 92, "brain": "pattern", "enemy": "imp"}, {})
		check(is_equal_approx(float(plain_pattern.get("pattern_tempo_mult", 0.0)), REGION_STEP * FLOOR_STEP), "%s: without the modifier the tempo is region x floor" % mod_id)
		var block_match: Dictionary = _resolve({"id": "skeleton", "boss_max_hp": 92, "boss_min_runes": 1, "boss_drop_interval_mult": 1.0}, patch)
		check(not block_match.has("pattern_tempo_mult"), "%s: a block-brain match never carries pattern_tempo_mult" % mod_id, str(block_match.keys()))
		if mod_id == "big_hands":
			check(int(block_match.get("boss_min_runes", 0)) == 2, "big_hands: block match boss_min_runes 1 -> 2", str(block_match.get("boss_min_runes")))
		else:
			check(is_equal_approx(float(block_match.get("boss_drop_interval_mult", 0.0)), 0.85), "quick_blocks: block match drop interval x0.85",
				str(block_match.get("boss_drop_interval_mult")))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# The raw match with the modifier's match patch applied, scaled like a floor-2 Hellfire node, then cleaned.
func _resolve(raw: Dictionary, patch: Dictionary) -> Dictionary:
	var r: Dictionary = raw.duplicate(true)
	EncounterComposer.apply_to_raw(r, {EncounterComposer.KEY_MATCH_PATCH: patch.duplicate(true)})
	RunConfig._apply_scaling(r, {"step_mult": REGION_STEP}, {"step_mult": FLOOR_STEP})
	return RunConfig.from_dictionary({"matches": [r]}).matches[0]
