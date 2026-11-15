extends SceneTree
## Multi-enemy Phase 5 (D4, plan §3.7): a SHARED trait may exist ONCE per match. A formation that gives the same
## shared trait to two units is rejected whole, with a warning naming the trait and both units.
##
## Why rejection and not de-duplication: the eleven shared traits write into the player's half or into one global
## quantity, so the second copy does not stack, it fights the first. `sandstorm` stores the previous drift
## multiplier and restores 1.0 when it ends, so the FIRST storm ending switches off the SECOND storm that is still
## blowing. Dropping one trait silently would ship an encounter whose author designed around an effect the engine
## cannot give.
##
## The negative legs matter as much as the positive ones: a check that only ever fires would reject every
## formation, and the suite would still look green if it only asserted rejections.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _has_problem(cfg: ChaptersConfig, needle: String) -> bool:
	for p: String in cfg.formation_problems():
		if p.contains(needle):
			return true
	return false


func _fixture(formations: Dictionary) -> Dictionary:
	var matches: Dictionary = {
		"a": {"boss_max_hp": 100, "arena": {"shape": "square"}},
		"b": {"boss_max_hp": 120, "arena": {"shape": "square"}},
		"c": {"boss_max_hp": 90, "arena": {"shape": "square"}},
	}
	return {"chapters": [{"id": "ch1", "matches": matches, "formations": formations,
		"formation_pools": {"0": formations.keys()}}]}


func _initialize() -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	ChaptersConfig.set_formation_lookup(library, func(_enemy_id: String) -> Array: return [[0, 0]])

	# --- Arrange / Act: one shared trait on two units -------------------------------------------------------------
	var dup: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"bad": {"type": "normal", "enemies": [
			{"id": "a", "traits": [{"id": "sandstorm"}]},
			{"id": "b", "traits": [{"id": "sandstorm"}]},
		]},
	}))
	# --- Assert
	check(dup.formation_ids(0).is_empty(), "duplicate shared trait: the formation is rejected whole")
	check(_has_problem(dup, "sandstorm"), "duplicate shared trait: the warning names the trait")
	check(_has_problem(dup, "'a'") and _has_problem(dup, "'b'"), "duplicate shared trait: the warning names both units")

	# A string entry is the same defect written another way; the check must not be fooled by the spelling.
	var dup_str: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"bad2": {"type": "normal", "enemies": [
			{"id": "a", "traits": ["row_burner"]},
			{"id": "b", "traits": ["row_burner"]},
		]},
	}))
	check(dup_str.formation_ids(0).is_empty(), "duplicate shared trait as plain strings: also rejected")

	# --- The silent half: these must all be ACCEPTED ---------------------------------------------------------------
	var ok_one: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"fine": {"type": "normal", "enemies": [
			{"id": "a", "traits": [{"id": "sandstorm"}]},
			{"id": "b", "traits": [{"id": "row_burner"}]},
		]},
	}))
	check(ok_one.formation_ids(0).size() == 1, "two DIFFERENT shared traits: accepted (the limit is per trait)")

	# PER-UNIT traits are the other eleven: duplicating them is the normal case and must stay legal, or every
	# formation of two burrowers becomes undesignable.
	var ok_per_unit: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"twins": {"type": "normal", "enemies": [
			{"id": "a", "traits": [{"id": "burrow"}]},
			{"id": "b", "traits": [{"id": "burrow"}]},
		]},
	}))
	check(ok_per_unit.formation_ids(0).size() == 1, "same PER-UNIT trait on two units: accepted")

	# One unit listing a shared trait TWICE is also rejected, and deciding that took re-reading the plan rather
	# than trusting the phrasing I remembered. §3.7 D4's body describes the check as "two units carrying the same
	# shared trait", but its heading states the RULE: "Trait SHARED gioi han mot ban moi tran" - one copy per
	# MATCH. §3.1 says the same: "chung can duoc gioi han mot ban cho moi tran". Two instances on one host produce
	# exactly the hazard the rule exists for - two sandstorms, one global drift multiplier, the first to end
	# switching off the second. So the body describes the common case, not the limit.
	# This leg first asserted the opposite and failed against the implementation, which is what forced the
	# question into the open instead of leaving two readings of D4 alive in the code and the test.
	var same_unit: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"typo": {"type": "normal", "enemies": [
			{"id": "a", "traits": [{"id": "gust"}, {"id": "gust"}]},
			{"id": "b"},
		]},
	}))
	check(same_unit.formation_ids(0).is_empty(), "one unit listing a shared trait twice: also rejected (one copy per MATCH)")

	var plain: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"plain": {"type": "normal", "enemies": [{"id": "a"}, {"id": "b"}]},
	}))
	check(plain.formation_ids(0).size() == 1 and plain.formation_problems().is_empty(),
			"no traits at all: accepted, no problems")

	# The shipped data must not start failing because of this rule.
	var shipped: ChaptersConfig = ChaptersConfig.load_from_file()
	check(shipped.formation_problems().is_empty(),
			"shipped chapters.json: no shared-trait clash (%s)" % ",".join(shipped.formation_problems()))

	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)
