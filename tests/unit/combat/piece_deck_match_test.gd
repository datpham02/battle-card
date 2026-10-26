extends SceneTree
## Story 034 (criteria A4 "Boss khong bi anh huong", B3 "Luon con hinh vua san"): CombatView gives the
## run's piece deck (match_params["piece_deck"]) to the PLAYER drops only. (a) a deck with removals and
## a raised mult: the player's weights are the deck weights, the boss still draws by PieceLibrary.weight
## (no injected source, removed shapes still drawable for it); (b) no / empty deck: the player's call is
## today's (no injected weights, no fallback); (c) only 5-cell shapes active on a 2x3 half where none
## fits: fallback true, original weights of the shapes that fit, the HUD notice shows. Headless,
## deterministic (fixed drops seed, time frozen). Prints PASS/FAIL lines and FAILS=n.
## FieldDrops has no public weight getter, so the tests read its `_weight_source` / `_weight_of`.

const CHAPTER: String = "ch1"
const EPS: float = 0.001

var fails: int = 0
var lib: PieceLibrary
var cfg: PieceDeckConfig


func ck(label: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + label + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	lib = PieceLibrary.load_from_file()
	cfg = PieceDeckConfig.load_from_file()
	await _test_deck_weights_player_only()
	await _test_no_deck_unchanged()
	await _test_fallback_narrow_arena()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A headless match (HoldSlotsView + CombatView + CutHudView in one holder, time frozen).
func _match(params: Dictionary, grid: BoardGrid = null) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = params
	v.drops_seed = 7
	v.freeze_time = true
	v.grid_override = grid
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	return holder


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# A deck with every default shape at 1.0, then [param mults] over it.
func _deck(mults: Dictionary, added: Array = []) -> Dictionary:
	var mult: Dictionary = {}
	for id: String in lib.base_shape_ids():
		mult[id] = 1.0
	for id: String in mults.keys():
		mult[id] = mults[id]
	return {"mult": mult, "added": added}


func _test_deck_weights_player_only() -> void:
	# Arrange
	var deck: Dictionary = _deck({"mono": 0.0, "bar2": 0.0, "square": 3.0})
	# Act
	var holder: Node = await _match({"piece_deck": deck, "chapter_id": CHAPTER, "player_hp": -1.0})
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var w: Dictionary = v.get_player_piece_weights()
	var expected: Dictionary = PieceDeck.weights_for_match(deck, lib, CHAPTER, v.get_grid(), cfg)["weights"]
	# Assert: player
	ck("deck: no fallback on the normal arena", not v.is_piece_deck_fallback())
	ck("deck: removed mono / bar2 have no player weight", not w.has("mono") and not w.has("bar2"), str(w.keys()))
	ck("deck: square = 3 x library weight", absf(float(w.get("square", 0.0)) - 3.0 * lib.weight("square", CHAPTER)) < EPS, str(w.get("square")))
	ck("deck: player weights == PieceDeck.weights_for_match", w == expected)
	var drops: FieldDrops = v.get_drops()
	ck("deck: player drops got the injected weights", drops._weight_source is Dictionary and drops._weight_of("square") == float(w["square"]))
	ck("deck: removed shapes not drawable for the player", not drops.get_drawable_shapes().has("mono") and not drops.get_drawable_shapes().has("bar2"))
	# Assert: boss (criterion A4)
	var boss_drops: FieldDrops = v.get_boss().get_drops()
	ck("deck: boss drops have no injected source", boss_drops._weight_source == null)
	var boss_ok: bool = true
	for id: String in boss_drops.get_drawable_shapes():
		boss_ok = boss_ok and absf(boss_drops._weight_of(id) - lib.weight(id, CHAPTER)) < EPS
	ck("deck: boss draws by PieceLibrary.weight", boss_ok and not boss_drops.get_drawable_shapes().is_empty())
	ck("deck: mono still drawable for the boss", boss_drops.get_drawable_shapes().has("mono"), str(boss_drops.get_drawable_shapes()))
	ck("deck: no notice without fallback", not (holder.get_node("CutHudView") as CutHudView).is_piece_deck_notice_visible())
	_drop(holder)


func _test_no_deck_unchanged() -> void:
	for params: Dictionary in [{"player_hp": -1.0}, {"piece_deck": {}, "player_hp": -1.0}]:
		# Arrange / Act
		var holder: Node = await _match(params)
		var v: CombatView = holder.get_node("CombatView") as CombatView
		var label: String = "empty deck" if params.has("piece_deck") else "no deck"
		# Assert
		ck("%s: player weights empty (original)" % label, v.get_player_piece_weights().is_empty())
		ck("%s: no fallback" % label, not v.is_piece_deck_fallback())
		ck("%s: player drops have no injected source" % label, v.get_drops()._weight_source == null)
		ck("%s: boss drops have no injected source" % label, v.get_boss().get_drops()._weight_source == null)
		_drop(holder)


func _test_fallback_narrow_arena() -> void:
	# Arrange: only 5-cell shapes active (hand built: min_shapes would refuse this through remove) on a
	# 2x3 half, where none of plus5 / bar5 / y5 fits (the same fixture as P1's PieceDeck test).
	var mult: Dictionary = {"plus5": 1.0, "bar5": 2.0, "y5": 1.0}
	for id: String in lib.base_shape_ids():
		if not mult.has(id):
			mult[id] = 0.0
	var big_only: Dictionary = {"mult": mult, "added": ["y5"]}
	var narrow := BoardGrid.new(2, 3)
	# Act
	var holder: Node = await _match({"piece_deck": big_only, "chapter_id": CHAPTER, "player_hp": -1.0}, narrow)
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var w: Dictionary = v.get_player_piece_weights()
	# Assert
	ck("narrow: fallback true", v.is_piece_deck_fallback())
	ck("narrow: mono gets its ORIGINAL weight", absf(float(w.get("mono", 0.0)) - lib.weight("mono", CHAPTER)) < EPS, str(w))
	var fit_ok: bool = not w.is_empty()
	for id: String in w.keys():
		fit_ok = fit_ok and not lib.is_run_only(id) and PiecePlacement.has_any_placement(narrow, lib.make_piece(id), true) \
			and absf(float(w[id]) - lib.weight(id, CHAPTER)) < EPS
	ck("narrow: only fitting default shapes, original weights", fit_ok and not w.has("bar5") and not w.has("y5"), str(w.keys()))
	var drawable: Array[String] = v.get_drops().get_drawable_shapes()
	ck("narrow: player can draw a fitting shape", not drawable.is_empty() and drawable.has("mono"), str(drawable))
	ck("narrow: HUD shows the fallback notice", (holder.get_node("CutHudView") as CutHudView).is_piece_deck_notice_visible())
	ck("narrow: notice key exists in the HUD", CutHudView.TEXT_PIECE_DECK_FALLBACK == "ui.piece_deck.fallback")
	_drop(holder)
