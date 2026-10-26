extends SceneTree
## Story 034 (Parts A, B, D): PieceDeck state, effective weights, Ink, Remove, the "a piece always
## fits" fallback, sanitize and PieceDeckConfig. Headless and deterministic. Prints FAILS=N.

var fails: int = 0
var lib: PieceLibrary
var cfg: PieceDeckConfig


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	cfg = PieceDeckConfig.load_from_file()
	_test_config()
	_test_initial()
	_test_effective_weights()
	_test_ink()
	_test_offer()
	_test_remove()
	_test_reink_removed()
	_test_fallback()
	_test_drop_percent()
	_test_sanitize()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_config() -> void:
	var d := PieceDeckConfig.new()
	ck("file values mirror the built-in defaults",
		near(cfg.ink_offer_chance, d.ink_offer_chance) and cfg.ink_offer_count == d.ink_offer_count
		and near(cfg.mult_step, d.mult_step) and near(cfg.mult_max, d.mult_max)
		and cfg.min_shapes == d.min_shapes and near(cfg.run_only_weight, d.run_only_weight)
		and cfg.shape_removals_start == d.shape_removals_start
		and cfg.shape_removals_per_boss == d.shape_removals_per_boss)
	ck("shipped numbers", near(cfg.ink_offer_chance, 0.35) and cfg.ink_offer_count == 2
		and near(cfg.mult_max, 4.0) and cfg.min_shapes == 5 and near(cfg.run_only_weight, 6.0)
		and cfg.shape_removals_start == 1 and cfg.shape_removals_per_boss == 1)
	var bad: PieceDeckConfig = PieceDeckConfig.from_dictionary({
		"ink_offer_chance": 7, "min_shapes": "five", "mult_max": 6.5, "run_only_weight": -1,
	})
	ck("bad values keep the default, good ones apply",
		near(bad.ink_offer_chance, 0.35) and bad.min_shapes == 5 and near(bad.mult_max, 6.5)
		and near(bad.run_only_weight, 6.0))
	var wrapped: PieceDeckConfig = PieceDeckConfig.from_dictionary({"piece_rewards": {"min_shapes": 3}})
	ck("a whole rewards.json object is accepted", wrapped.min_shapes == 3)
	ck("missing file gives defaults", PieceDeckConfig.load_from_file("res://nope.json").min_shapes == 5)


func _test_initial() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	var ids: Array[String] = PieceDeck.active_ids(st, lib)
	ck("initial: 13 active default shapes in library order", ids == lib.base_shape_ids())
	ck("initial: every mult is 1.0", (st["mult"] as Dictionary).size() == 13
		and near(PieceDeck.mult_of(st, "mono"), 1.0) and near(PieceDeck.mult_of(st, "bar5"), 1.0))
	ck("initial: added empty, run_only absent",
		(st["added"] as Array).is_empty() and PieceDeck.mult_of(st, "y5") == 0.0 and not PieceDeck.has_shape(st, "y5"))
	ck("initial state is JSON-safe", typeof(JSON.parse_string(JSON.stringify(st))) == TYPE_DICTIONARY)


func _test_effective_weights() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	var w: Dictionary = PieceDeck.effective_weights(st, lib, "ch1", cfg)
	var ok: bool = w.size() == 13
	for id: String in lib.base_shape_ids():
		ok = ok and near(float(w[id]), lib.weight(id, "ch1"))
	ck("initial deck: effective weights = original weights", ok)
	st = PieceDeck.apply_ink(st, "bar3", lib, cfg)
	st = PieceDeck.apply_ink(st, "bar3", lib, cfg) # mult 3
	st = PieceDeck.apply_ink(st, "y5", lib, cfg) # added, mult 1
	st = PieceDeck.apply_ink(st, "y5", lib, cfg) # mult 2
	w = PieceDeck.effective_weights(st, lib, "ch2", cfg)
	ck("w = base x mult (bar3 mult 3)", near(float(w["bar3"]), lib.weight("bar3", "ch2") * 3.0))
	ck("w = base x mult (run_only y5 mult 2 uses run_only_weight)", near(float(w["y5"]), cfg.run_only_weight * 2.0))
	ck("untouched shape keeps its base weight", near(float(w["mono"]), lib.weight("mono", "ch2")))
	ck("base_weight of run_only ignores the library", near(PieceDeck.base_weight(lib, "z4", "ch1", cfg), 6.0))
	ck("not-owned run_only shape is absent", not w.has("z4") and not w.has("j4"))
	var zero_cfg: PieceDeckConfig = PieceDeckConfig.from_dictionary({"run_only_weight": 0.0})
	ck("a weight of 0 is dropped from the map",
		not PieceDeck.effective_weights(st, lib, "ch1", zero_cfg).has("y5"))


func _test_ink() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	var s2: Dictionary = PieceDeck.apply_ink(st, "z4", lib, cfg)
	ck("ink adds a run_only shape at mult 1", (s2["added"] as Array).has("z4") and near(PieceDeck.mult_of(s2, "z4"), 1.0))
	ck("ink does not mutate the input state", not (st["added"] as Array).has("z4") and PieceDeck.mult_of(st, "z4") == 0.0)
	ck("active_ids lists the added shape after the defaults", PieceDeck.active_ids(s2, lib).back() == "z4")
	s2 = PieceDeck.apply_ink(s2, "z4", lib, cfg)
	ck("second ink raises mult by mult_step", near(PieceDeck.mult_of(s2, "z4"), 2.0))
	ck("added is not duplicated", (s2["added"] as Array).count("z4") == 1)
	var s3: Dictionary = PieceDeck.apply_ink(st, "mono", lib, cfg)
	ck("ink on a default shape raises mult", near(PieceDeck.mult_of(s3, "mono"), 2.0) and (s3["added"] as Array).is_empty())
	var cur: Dictionary = st
	for i: int in 10:
		if PieceDeck.can_ink(cur, "square", lib, cfg):
			cur = PieceDeck.apply_ink(cur, "square", lib, cfg)
	ck("ink stops at mult_max", near(PieceDeck.mult_of(cur, "square"), cfg.mult_max))
	ck("a capped shape cannot be inked", not PieceDeck.can_ink(cur, "square", lib, cfg))
	var again: Dictionary = PieceDeck.apply_ink(cur, "square", lib, cfg)
	ck("inking a capped shape leaves the state unchanged", again == cur)
	ck("an unknown shape cannot be inked", not PieceDeck.can_ink(st, "ghost", lib, cfg))
	var odd: PieceDeckConfig = PieceDeckConfig.from_dictionary({"mult_step": 1.5, "mult_max": 4.0})
	var o: Dictionary = PieceDeck.initial(lib)
	o = PieceDeck.apply_ink(o, "mono", lib, odd)
	o = PieceDeck.apply_ink(o, "mono", lib, odd)
	o = PieceDeck.apply_ink(o, "mono", lib, odd)
	ck("a step past the ceiling is clamped to mult_max", near(PieceDeck.mult_of(o, "mono"), 4.0))


func _test_offer() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	var a: Array[String] = PieceDeck.roll_ink_offer(st, lib, cfg, 42)
	var b: Array[String] = PieceDeck.roll_ink_offer(st, lib, cfg, 42)
	ck("offer has ink_offer_count distinct known shapes",
		a.size() == cfg.ink_offer_count and a[0] != a[1] and lib.has_shape(a[0]) and lib.has_shape(a[1]))
	ck("same seed, same offer", a == b)
	var seen: Dictionary = {}
	for s: int in 40:
		for id: String in PieceDeck.roll_ink_offer(st, lib, cfg, s):
			seen[id] = true
	ck("different seeds reach run_only shapes and defaults", seen.has("y5") and seen.has("mono") and seen.size() > 8)
	# Cap everything except two shapes: only those can be offered.
	var mult: Dictionary = {}
	for id: String in lib.shape_ids():
		mult[id] = cfg.mult_max
	mult["mono"] = 1.0
	mult["y5"] = 2.0
	var capped: Dictionary = {"mult": mult, "added": ["z4", "j4", "y5"]}
	var only: Array[String] = PieceDeck.roll_ink_offer(capped, lib, cfg, 7)
	ck("capped shapes are never offered", only.size() == 2 and only.has("mono") and only.has("y5"))
	mult["y5"] = cfg.mult_max
	var one: Array[String] = ["mono"]
	ck("fewer qualify, fewer offered", PieceDeck.roll_ink_offer(capped, lib, cfg, 7) == one)
	mult["mono"] = cfg.mult_max
	ck("none qualify, empty offer", PieceDeck.roll_ink_offer(capped, lib, cfg, 7).is_empty())
	var removed: Dictionary = PieceDeck.remove(st, "mono", lib, cfg)
	var hit: bool = false
	for s: int in 60:
		hit = hit or PieceDeck.roll_ink_offer(removed, lib, cfg, s).has("mono")
	ck("a removed shape can be offered again", hit)


func _test_remove() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	var v: Dictionary = PieceDeck.can_remove(st, "mono", lib, cfg)
	ck("can_remove ok above min_shapes", bool(v["ok"]) and str(v["reason"]) == "")
	var cur: Dictionary = st
	var ids: Array[String] = lib.base_shape_ids()
	for i: int in 8: # 13 -> 5 active
		cur = PieceDeck.remove(cur, ids[i], lib, cfg)
	ck("8 removals leave exactly min_shapes active", PieceDeck.active_ids(cur, lib).size() == cfg.min_shapes)
	ck("removed shape has mult 0", PieceDeck.mult_of(cur, ids[0]) == 0.0 and not PieceDeck.has_shape(cur, ids[0]))
	var refused: Dictionary = PieceDeck.can_remove(cur, ids[8], lib, cfg)
	ck("remove is refused at min_shapes with the reason key",
		not bool(refused["ok"]) and str(refused["reason"]) == "piece_deck.reason.min_shapes")
	var same: Dictionary = PieceDeck.remove(cur, ids[8], lib, cfg)
	ck("a refused remove changes nothing", same == cur)
	var gone: Dictionary = PieceDeck.can_remove(cur, ids[0], lib, cfg)
	ck("already removed is reported", str(gone["reason"]) == "piece_deck.reason.already_removed")
	ck("unknown id is reported", str(PieceDeck.can_remove(cur, "ghost", lib, cfg)["reason"]) == "piece_deck.reason.unknown")
	ck("not-owned run_only shape cannot be removed",
		str(PieceDeck.can_remove(st, "y5", lib, cfg)["reason"]) == "piece_deck.reason.already_removed")
	# An added run_only shape counts toward min_shapes: with it, one more default may go.
	var with_y: Dictionary = PieceDeck.apply_ink(cur, "y5", lib, cfg)
	ck("an added shape lifts the floor by one", bool(PieceDeck.can_remove(with_y, ids[8], lib, cfg)["ok"]))
	var no_y: Dictionary = PieceDeck.remove(with_y, "y5", lib, cfg)
	ck("removing a run_only shape drops it from added", not (no_y["added"] as Array).has("y5")
		and PieceDeck.mult_of(no_y, "y5") == 0.0)
	ck("remove does not mutate the input", PieceDeck.mult_of(st, "mono") == 1.0)


func _test_reink_removed() -> void:
	var st: Dictionary = PieceDeck.initial(lib)
	st = PieceDeck.apply_ink(st, "bar4", lib, cfg)
	st = PieceDeck.apply_ink(st, "bar4", lib, cfg) # mult 3
	st = PieceDeck.remove(st, "bar4", lib, cfg)
	ck("removed bar4 is out of the active set", not PieceDeck.active_ids(st, lib).has("bar4"))
	ck("a removed shape can be inked", PieceDeck.can_ink(st, "bar4", lib, cfg))
	st = PieceDeck.apply_ink(st, "bar4", lib, cfg)
	ck("a removed shape inked back returns to mult 1.0", near(PieceDeck.mult_of(st, "bar4"), 1.0)
		and PieceDeck.active_ids(st, lib).has("bar4"))
	var y: Dictionary = PieceDeck.apply_ink(PieceDeck.initial(lib), "y5", lib, cfg)
	y = PieceDeck.remove(y, "y5", lib, cfg)
	y = PieceDeck.apply_ink(y, "y5", lib, cfg)
	ck("a removed run_only shape comes back through added at 1.0", near(PieceDeck.mult_of(y, "y5"), 1.0)
		and (y["added"] as Array).has("y5") and PieceDeck.active_ids(y, lib).has("y5"))


func _test_fallback() -> void:
	var wide := BoardGrid.new(5, 5)
	var st: Dictionary = PieceDeck.initial(lib)
	var r: Dictionary = PieceDeck.weights_for_match(st, lib, "ch1", wide, cfg)
	ck("a roomy arena: no fallback, effective weights", not bool(r["fallback"])
		and near(float((r["weights"] as Dictionary)["mono"]), lib.weight("mono", "ch1")))
	var empty: Dictionary = PieceDeck.weights_for_match({}, lib, "ch1", wide, cfg)
	var all_orig: bool = (empty["weights"] as Dictionary).size() == 13 and not bool(empty["fallback"])
	for id: String in lib.base_shape_ids():
		all_orig = all_orig and near(float((empty["weights"] as Dictionary)[id]), lib.weight(id, "ch1"))
	ck("an empty state means the original weights of every default shape", all_orig)
	# A deck of only 5-cell shapes (hand built: min_shapes would refuse this via remove) on a 2x3 half.
	var mult: Dictionary = {"plus5": 1.0, "bar5": 2.0, "y5": 1.0}
	for id: String in lib.base_shape_ids():
		if not mult.has(id):
			mult[id] = 0.0
	var big_only: Dictionary = {"mult": mult, "added": ["y5"]}
	var narrow := BoardGrid.new(2, 3)
	var fb: Dictionary = PieceDeck.weights_for_match(big_only, lib, "ch1", narrow, cfg)
	var fw: Dictionary = fb["weights"]
	ck("narrow arena, only 5-cell shapes left: fallback is true", bool(fb["fallback"]))
	ck("fallback weights are the ORIGINAL ones of the shapes that fit",
		fw.has("mono") and near(float(fw["mono"]), lib.weight("mono", "ch1"))
		and not fw.has("bar5") and not fw.has("plus5") and not fw.has("y5") and not fw.has("z4"))
	ck("fallback only holds default shapes that fit", _all_fit(fw, narrow))
	# A half where one of the deck's shapes fits: no fallback.
	var fits: Dictionary = PieceDeck.weights_for_match(big_only, lib, "ch1", BoardGrid.new(5, 2), cfg)
	ck("a deck shape fits: no fallback, deck weights", not bool(fits["fallback"])
		and near(float((fits["weights"] as Dictionary)["bar5"]), lib.weight("bar5", "ch1") * 2.0))
	ck("a null grid skips the fit check", not bool(PieceDeck.weights_for_match(big_only, lib, "ch1", null, cfg)["fallback"]))


func _all_fit(weights: Dictionary, grid: BoardGrid) -> bool:
	for id: String in weights.keys():
		if lib.is_run_only(id) or not PiecePlacement.has_any_placement(grid, lib.make_piece(id), true):
			return false
	return not weights.is_empty()


func _test_drop_percent() -> void:
	var p: Dictionary = PieceDeck.drop_percent({"a": 1.0, "b": 3.0})
	ck("drop_percent: shares of the sum", near(float(p["a"]), 25.0) and near(float(p["b"]), 75.0))
	var z: Dictionary = PieceDeck.drop_percent({"a": 0.0})
	ck("drop_percent: 0 when the sum is 0", near(float(z["a"]), 0.0))
	ck("drop_percent: empty in, empty out", PieceDeck.drop_percent({}).is_empty())
	var st: Dictionary = PieceDeck.initial(lib)
	var total: float = 0.0
	for v: Variant in PieceDeck.drop_percent(PieceDeck.effective_weights(st, lib, "ch1", cfg)).values():
		total += float(v)
	ck("percent of a deck sums to 100", near(total, 100.0))


func _test_sanitize() -> void:
	var clean: Dictionary = PieceDeck.sanitize({
		"mult": {"mono": 2.0, "ghost": 3.0, "bar2": -4, "bar3": "x", "y5": 3.0, "z4": 2.0},
		"added": ["y5", "ghost", "mono", "y5"],
	}, lib)
	var m: Dictionary = clean["mult"]
	ck("unknown id is dropped", not m.has("ghost"))
	ck("a good value is kept", near(float(m["mono"]), 2.0))
	ck("a negative value becomes 0", near(float(m["bar2"]), 0.0))
	ck("a non-number is dropped then refilled with 1.0", near(float(m["bar3"]), 1.0))
	ck("missing default shapes are filled with 1.0", m.has("bar5") and near(float(m["bar5"]), 1.0) and m.size() == 14)
	ck("added keeps only existing run_only ids, once", (clean["added"] as Array) == ["y5"])
	ck("a run_only mult that is not in added is dropped", not m.has("z4"))
	ck("kept run_only shape is active", PieceDeck.active_ids(clean, lib).has("y5") and near(float(m["y5"]), 3.0))
	ck("a mult above mult_max is not clamped here",
		near(PieceDeck.mult_of(PieceDeck.sanitize({"mult": {"mono": 9.0}, "added": []}, lib), "mono"), 9.0))
	var init: Dictionary = PieceDeck.initial(lib)
	ck("garbage input returns the initial state", PieceDeck.sanitize(null, lib) == init
		and PieceDeck.sanitize("x", lib) == init and PieceDeck.sanitize({}, lib) == init
		and PieceDeck.sanitize({"mult": 5}, lib) == init)
	var added_only: Dictionary = PieceDeck.sanitize({"mult": {"mono": 1.0}, "added": ["j4"]}, lib)
	ck("an added run_only id without a mult entry gets 1.0", near(PieceDeck.mult_of(added_only, "j4"), 1.0))
	var round_trip: Dictionary = PieceDeck.sanitize(JSON.parse_string(JSON.stringify(
		PieceDeck.apply_ink(PieceDeck.initial(lib), "y5", lib, cfg))), lib)
	ck("a JSON round trip keeps the deck", near(PieceDeck.mult_of(round_trip, "y5"), 1.0)
		and (round_trip["added"] as Array) == ["y5"])
