extends SceneTree
## Story 034 Parts A, B (production/epics/kaiten-duel/story-034-piece-deck.md): the piece deck in RunSession
## and the shop's remove_shape service. A new run starts with PieceDeck.initial, shape_removals_start tokens
## and no ink row; save / load keeps piece_deck, shape_removals and pending_ink_offer, a save without those
## keys loads the start values, unknown ids are dropped; apply_ink stops at mult_max; remove_shape spends a
## token, is refused at 0 tokens and at min_shapes (nothing changes); a boss node grants
## shape_removals_per_boss; the shop remove_shape service costs gold once per shop, refuses an illegal
## removal without charging, and an older shop save gains the service. Uses the shipped data files.
## Headless: godot --headless --path . -s res://tests/unit/run/run_session_piece_deck_test.gd
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const HERO: String = "kiem_si"
const SEED: int = 3434
const MAX_HP: float = 300.0
const RICH: int = 1000
## Shape ids of pieces.json used by the checks (the ids ARE the point).
const SMALL: String = "mono"
const MID: String = "bar3"
const RUN_ONLY: String = "y5"
const UNKNOWN: String = "no_such_shape"
## Saved token count of the round-trip check (any value other than the start value).
const SAVED_TOKENS: int = 3

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _new_run() -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	return RunSession.begin(ChaptersConfig.load_from_file(), ch, 0, SEED, [
		{"index": 0, "tier": 1, "nodes": [{"kind": "battle", "match_id": ""}]},
		{"index": 1, "tier": 1, "nodes": [{"kind": "boss", "match_id": ""}]},
	] as Array[Dictionary], 1)


# Save / load through JSON text, the way ProgressStore writes it.
func _reload(run: RunSession) -> RunSession:
	var text: String = JSON.stringify(run.to_dict())
	return RunSession.from_dict(JSON.parse_string(text) as Dictionary, ChaptersConfig.load_from_file(), SkillConfig.load_from_file())


func _initialize() -> void:
	var lib: PieceLibrary = RunSession.piece_library()
	var cfg: PieceDeckConfig = RunSession.piece_config()

	# --- start values
	var run: RunSession = _new_run()
	_check("new run: piece_deck = PieceDeck.initial", run.piece_deck == PieceDeck.initial(lib), str(run.piece_deck))
	_check("new run: shape_removals = shape_removals_start", run.shape_removals == cfg.shape_removals_start, str(run.shape_removals))
	_check("new run: no ink row", not run.has_pending_ink_offer())

	# --- save / load keeps the three fields
	_check("ink a run-only shape", run.apply_ink(RUN_ONLY))
	_check("ink a default shape", run.apply_ink(MID))
	_check("remove a shape with a token", bool(run.remove_shape(SMALL, true)["ok"]))
	run.shape_removals = SAVED_TOKENS
	run.set_pending_ink_offer([MID, RUN_ONLY] as Array[String])
	var back: RunSession = _reload(run)
	_check("reload: run kept", back != null)
	if back != null:
		_check("reload keeps piece_deck", PieceDeck.active_ids(back.piece_deck, lib) == PieceDeck.active_ids(run.piece_deck, lib)
			and is_equal_approx(PieceDeck.mult_of(back.piece_deck, MID), PieceDeck.mult_of(run.piece_deck, MID))
			and PieceDeck.mult_of(back.piece_deck, SMALL) == 0.0, "%s vs %s" % [str(back.piece_deck), str(run.piece_deck)])
		_check("reload keeps shape_removals", back.shape_removals == SAVED_TOKENS, str(back.shape_removals))
		_check("reload keeps pending_ink_offer", back.pending_ink_offer == run.pending_ink_offer, str(back.pending_ink_offer))

	# --- missing keys = start values; unknown ids dropped
	var d: Dictionary = run.to_dict()
	d.erase("piece_deck")
	d.erase("shape_removals")
	d.erase("pending_ink_offer")
	var old: RunSession = RunSession.from_dict(d, ChaptersConfig.load_from_file(), SkillConfig.load_from_file())
	_check("old save: piece_deck = initial", old != null and old.piece_deck == PieceDeck.initial(lib))
	_check("old save: shape_removals = start", old != null and old.shape_removals == cfg.shape_removals_start)
	_check("old save: no ink row", old != null and not old.has_pending_ink_offer())
	d = run.to_dict()
	(d["piece_deck"]["mult"] as Dictionary)[UNKNOWN] = 2.0
	d["pending_ink_offer"] = [UNKNOWN, MID]
	var odd: RunSession = RunSession.from_dict(d, ChaptersConfig.load_from_file(), SkillConfig.load_from_file())
	_check("unknown shape dropped from the saved deck", odd != null and not (odd.piece_deck["mult"] as Dictionary).has(UNKNOWN))
	_check("unknown shape dropped from the saved ink row", odd != null and odd.pending_ink_offer == ([MID] as Array[String]), str(odd.pending_ink_offer if odd != null else []))

	# --- apply_ink stops at mult_max
	var capped: RunSession = _new_run()
	var guard: int = 0
	while capped.apply_ink(MID) and guard < 100:
		guard += 1
	_check("ink stops at mult_max", is_equal_approx(PieceDeck.mult_of(capped.piece_deck, MID), cfg.mult_max), str(PieceDeck.mult_of(capped.piece_deck, MID)))
	_check("ink at the ceiling refused", not capped.apply_ink(MID))
	_check("ink of an unknown shape refused", not capped.apply_ink(UNKNOWN))

	# --- tokens
	var tok: RunSession = _new_run()
	tok.shape_removals = 1
	_check("remove with a token: ok and token spent", bool(tok.remove_shape(SMALL, true)["ok"]) and tok.shape_removals == 0)
	var before: Dictionary = tok.piece_deck.duplicate(true)
	var refused: Dictionary = tok.remove_shape(MID, true)
	_check("remove at 0 tokens refused (no_token)", not bool(refused["ok"]) and str(refused["reason"]) == RunSession.REASON_NO_TOKEN, str(refused))
	_check("refusal changes nothing", tok.piece_deck == before and tok.shape_removals == 0)
	_check("remove without a token (shop path) needs none", bool(tok.remove_shape(MID, false)["ok"]) and tok.shape_removals == 0)
	_check("removing a removed shape refused (already_removed)", str(tok.remove_shape(SMALL, false)["reason"]) == PieceDeck.REASON_ALREADY_REMOVED)

	# --- min_shapes: a config whose floor sits one below the full deck
	var full: int = PieceDeck.active_ids(PieceDeck.initial(lib), lib).size()
	var tight: PieceDeckConfig = PieceDeckConfig.from_dictionary({"piece_rewards": {"min_shapes": full - 1}})
	var floor_run: RunSession = _new_run()
	floor_run.shape_removals = 2
	_check("remove down to min_shapes: ok", bool(floor_run.remove_shape(SMALL, true, lib, tight)["ok"]))
	var at_floor: Dictionary = floor_run.remove_shape(MID, true, lib, tight)
	_check("remove below min_shapes refused (min_shapes)", not bool(at_floor["ok"]) and str(at_floor["reason"]) == PieceDeck.REASON_MIN_SHAPES, str(at_floor))
	_check("min_shapes refusal keeps the token", floor_run.shape_removals == 1)
	_check("a removed shape can be inked back at mult 1", floor_run.apply_ink(SMALL, lib, tight) and is_equal_approx(PieceDeck.mult_of(floor_run.piece_deck, SMALL), 1.0))

	# --- boss token
	var walk: RunSession = _new_run()
	var start_tokens: int = walk.shape_removals
	walk.choose_node(0)
	walk.complete_node(MAX_HP, MAX_HP, "battle", {}, 0.0)
	_check("a battle node grants no shape token", walk.shape_removals == start_tokens)
	walk.choose_node(0)
	walk.complete_node(MAX_HP, MAX_HP, "boss", {}, 0.0)
	_check("a boss node grants shape_removals_per_boss", walk.shape_removals == start_tokens + cfg.shape_removals_per_boss, str(walk.shape_removals))

	# --- shop service remove_shape
	var economy: EconomyConfig = EconomyConfig.load_from_file()
	var shop_run: RunSession = _new_run()
	shop_run.gold = RICH
	var tokens: int = shop_run.shape_removals
	var state: Dictionary = ShopLogic.build(SEED, 1, 2, 1, 0.0, [], SkillConfig.load_from_file(), RewardRoller.load_config(), null, economy)
	var price: int = economy.service_price(ShopLogic.SERVICE_REMOVE_SHAPE, 1)
	_check("shop offers remove_shape at its economy price", int(state["services"][ShopLogic.SERVICE_REMOVE_SHAPE]["price"]) == price and price > 0, str(state["services"]))
	var bad: Dictionary = ShopLogic.use_service(state, shop_run, ShopLogic.SERVICE_REMOVE_SHAPE, UNKNOWN)
	_check("illegal removal refused without charging", not bool(bad["ok"]) and str(bad["reason"]) == ShopLogic.REASON_BAD_SHAPE
		and str(bad["reason_key"]) == PieceDeck.REASON_UNKNOWN and shop_run.gold == RICH, str(bad))
	var ok: Dictionary = ShopLogic.use_service(state, shop_run, ShopLogic.SERVICE_REMOVE_SHAPE, SMALL)
	_check("remove_shape service: ok, gold spent, shape gone, no token used", bool(ok["ok"]) and shop_run.gold == RICH - price
		and not PieceDeck.has_shape(shop_run.piece_deck, SMALL) and shop_run.shape_removals == tokens, str(ok))
	_check("remove_shape service once per shop", str(ShopLogic.use_service(state, shop_run, ShopLogic.SERVICE_REMOVE_SHAPE, MID)["reason"]) == ShopLogic.REASON_USED)
	var legacy: Dictionary = ShopLogic.to_dict(state)
	(legacy["services"] as Dictionary).erase(ShopLogic.SERVICE_REMOVE_SHAPE)
	var restored: Dictionary = ShopLogic.from_dict(JSON.parse_string(JSON.stringify(legacy)))
	_check("a shop saved before Story 034 gains the service", not restored.is_empty()
		and not bool(restored["services"][ShopLogic.SERVICE_REMOVE_SHAPE]["used"]), str(restored.get("services", {})))

	print("FAILS=%d" % fails)
	quit(fails)
