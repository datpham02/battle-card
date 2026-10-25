extends SceneTree
## Story 024 Part A: piece drops on the player half (FieldDrops piece mode), the piece bag
## (HoldSlots) and the rotten piece, plus proof that classic mode is unchanged.
## Headless and deterministic (seeded, simulated time only). Prints PASS/FAIL lines and FAILS=N.

var fails: int = 0
var lib: PieceLibrary
var tick_n: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	_test_classic_unchanged()
	_test_seeded_determinism()
	_test_unplaceable_shapes_skipped()
	_test_weights()
	_test_pacing()
	_test_start_pieces()
	_test_pickup_and_bag()
	_test_blocked_and_hunger()
	_test_rotten_piece()
	_test_rotten_thrower()
	_test_config_keys()
	print("FAILS=%d" % fails)
	quit(fails)


# Config with piece pacing fast enough to run many spawns in few ticks.
func _config(interval: float = 0.01, max_on: int = 3, freshness: float = 4.0, start: int = 1) -> FieldDropsConfig:
	var c := FieldDropsConfig.new()
	c.initial_delay_sec = 0.0
	c.piece_spawn_interval_sec = interval
	c.piece_max_on_field = max_on
	c.piece_freshness_sec = freshness
	c.start_pieces = start
	return c


func _piece_drops(grid: BoardGrid, config: FieldDropsConfig, chapter: String = "ch1", seed_value: int = 11) -> FieldDrops:
	var drops := FieldDrops.new(config, grid.player_cells(), grid.perimeter_labels(), seed_value)
	drops.enable_pieces(lib, chapter, grid, seed_value)
	return drops


# Spawn log "shape/rotation/cell" for [param ticks] ticks of 0.02 s with expiring points.
func _spawn_log(drops: FieldDrops, ticks: int) -> Array[String]:
	var log: Array[String] = []
	drops.point_spawned.connect(func(p: FieldPoint) -> void:
		log.append("%s/%d/%s" % [p.piece.shape_id, p.piece.rotation, p.cell]))
	for _i: int in ticks:
		drops.tick(0.02, Vector2i(1, 1), 1)
	return log


func _test_classic_unchanged() -> void:
	var grid := BoardGrid.new(3, 3)
	var config := FieldDropsConfig.new()
	var a := FieldDrops.new(config, grid.player_cells(), grid.perimeter_labels(), 5)
	var b := FieldDrops.new(config, grid.player_cells(), grid.perimeter_labels(), 5)
	var labels_a: Array[String] = []
	var labels_b: Array[String] = []
	a.point_spawned.connect(func(p: FieldPoint) -> void: labels_a.append(p.label))
	b.point_spawned.connect(func(p: FieldPoint) -> void: labels_b.append(p.label))
	var all_classic: bool = true
	for _i: int in 400:
		a.tick(0.05, Vector2i(1, 1), 1)
		b.tick(0.05, Vector2i(1, 1), 1)
		for p: FieldPoint in a.get_points():
			all_classic = all_classic and p.piece == null and not p.rotten and grid.perimeter_labels().has(p.label)
	ck("classic: no piece on any point, labels are perimeter labels", all_classic and labels_a.size() > 5)
	ck("classic: same seed gives the same label sequence", labels_a == labels_b)
	ck("classic: is_piece_mode false, no start pieces, no drawable shapes", not a.is_piece_mode() and a.place_start_pieces(Vector2i(1, 1)) == 0 and a.get_drawable_shapes().is_empty())
	var small := FieldDropsConfig.new()
	small.max_on_field = 2
	small.piece_max_on_field = 5
	small.initial_delay_sec = 0.0
	small.spawn_interval_sec = 0.01
	small.freshness_sec = 100.0
	var c := FieldDrops.new(small, grid.player_cells(), grid.perimeter_labels(), 3)
	for _i: int in 50:
		c.tick(0.05, Vector2i(1, 1), 1)
	ck("classic: reads max_on_field, not piece_max_on_field", c.get_points().size() == 2)
	var d := FieldDrops.new(small, grid.player_cells(), grid.perimeter_labels(), 3)
	var rotten: FieldPoint = d.place_rotten(Vector2i(0, 0), "X", 5.0, 5.0)
	ck("classic: place_rotten still makes a label point without a piece", rotten != null and rotten.rotten and rotten.piece == null and rotten.label == "X")


func _test_seeded_determinism() -> void:
	var grid := BoardGrid.new(3, 3)
	var log_a: Array[String] = _spawn_log(_piece_drops(grid, _config(0.01, 3, 0.01, 0), "ch1", 21), 120)
	var log_b: Array[String] = _spawn_log(_piece_drops(grid, _config(0.01, 3, 0.01, 0), "ch1", 21), 120)
	var log_c: Array[String] = _spawn_log(_piece_drops(grid, _config(0.01, 3, 0.01, 0), "ch1", 22), 120)
	ck("determinism: same seed gives the same shape/rotation/cell log (%d spawns)" % log_a.size(), log_a == log_b and log_a.size() > 20)
	ck("determinism: another seed gives another log", log_a != log_c)
	var d := _piece_drops(grid, _config(), "ch1", 4)
	d.tick(0.02, Vector2i(1, 1), 1)
	var p: FieldPoint = d.get_points()[0]
	ck("spawn: point carries a piece, label is its shape id, rotation 0..3", p.piece != null and p.label == p.piece.shape_id and p.piece.rotation >= 0 and p.piece.rotation <= 3 and not p.rotten)
	ck("spawn: lands on a player cell that is not the player's", grid.is_player_cell(p.cell) and p.cell != Vector2i(1, 1))


func _test_unplaceable_shapes_skipped() -> void:
	var tiny := BoardGrid.new(1, 1)
	var d := FieldDrops.new(_config(), tiny.player_cells(), tiny.perimeter_labels(), 1)
	d.enable_pieces(lib, "ch3", tiny, 1)
	ck("skip: a 1x1 enemy half can only draw the mono", d.get_drawable_shapes() == (["mono"] as Array[String]))
	var shapes_seen: Dictionary = {}
	d.point_spawned.connect(func(p: FieldPoint) -> void: shapes_seen[p.piece.shape_id] = true)
	for _i: int in 100:
		d.tick(0.02, Vector2i(5, 5), 1)
	ck("skip: 100 ticks on the 1x1 half only ever spawned mono", shapes_seen.keys() == ["mono"])
	var narrow := BoardGrid.new(2, 3)
	var n := FieldDrops.new(_config(), narrow.player_cells(), narrow.perimeter_labels(), 1)
	n.enable_pieces(lib, "ch3", narrow, 1)
	var drawable: Array[String] = n.get_drawable_shapes()
	ck("skip: a 2x3 half drops neither bar4, bar5 nor plus5 but keeps bar3 (placed turned)", not drawable.has("bar4") and not drawable.has("bar5") and not drawable.has("plus5") and drawable.has("bar3") and drawable.has("u5"))
	var holey := BoardGrid.new(3, 3, [Vector2i(1, 1)] as Array[Vector2i])
	var h := FieldDrops.new(_config(), holey.player_cells(), holey.perimeter_labels(), 2)
	h.enable_pieces(lib, "ch3", holey, 2)
	ck("skip: a centre hole removes plus5 and square from the draw", not h.get_drawable_shapes().has("plus5") and not h.get_drawable_shapes().has("square") and h.get_drawable_shapes().has("mono"))
	var seen_holey: Dictionary = {}
	h.point_spawned.connect(func(p: FieldPoint) -> void: seen_holey[p.piece.shape_id] = true)
	for _i: int in 300:
		h.tick(0.02, Vector2i(0, 0), 1)
	ck("skip: 300 spawns on the holey board never drew plus5 or square", not seen_holey.has("plus5") and not seen_holey.has("square") and seen_holey.size() > 3)
	var every_fits: bool = true
	for id: String in h.get_drawable_shapes():
		every_fits = every_fits and PiecePlacement.has_any_placement(holey, lib.make_piece(id))
	ck("skip: every drawable shape has a placement", every_fits)
	var one_lib: PieceLibrary = PieceLibrary.from_dictionary({"shapes": [{"id": "bar5", "cells": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]}]})
	var none := FieldDrops.new(_config(), tiny.player_cells(), tiny.perimeter_labels(), 1)
	none.enable_pieces(one_lib, "ch1", tiny, 1)
	for _i: int in 10:
		none.tick(0.02, Vector2i(5, 5), 1)
	ck("skip: when no shape fits nothing drops and nothing crashes", none.get_points().is_empty() and none.place_start_pieces(Vector2i(5, 5)) == 0)


func _shape_counts(chapter: String, draws: int, seed_value: int) -> Dictionary:
	var grid := BoardGrid.new(5, 5)
	var config := _config(0.01, 3, 0.01, 0)
	var d := _piece_drops(grid, config, chapter, seed_value)
	var counts: Dictionary = {"rot": {}}
	d.point_spawned.connect(func(p: FieldPoint) -> void:
		counts[p.piece.shape_id] = int(counts.get(p.piece.shape_id, 0)) + 1
		(counts["rot"] as Dictionary)[p.piece.rotation] = true)
	for _i: int in draws:
		d.tick(0.02, Vector2i(2, 2), 1)
	return counts


func _large_share(counts: Dictionary, draws: int) -> float:
	return float(int(counts.get("plus5", 0)) + int(counts.get("u5", 0)) + int(counts.get("bar5", 0))) / float(draws)


func _test_weights() -> void:
	var draws: int = 600
	var ch1: Dictionary = _shape_counts("ch1", draws, 31)
	var ch3: Dictionary = _shape_counts("ch3", draws, 31)
	var total_ch1: int = 0
	for id: String in lib.shape_ids():
		total_ch1 += int(ch1.get(id, 0))
	ck("weights: every tick spawned one piece (%d)" % total_ch1, total_ch1 == draws)
	var small_share: float = float(int(ch1.get("mono", 0)) + int(ch1.get("bar2", 0))) / float(draws)
	ck("weights: chapter 1 draws mono+bar2 often (expected ~42%%, got %.0f%%)" % (small_share * 100.0), small_share > 0.30)
	ck("weights: chapter 1 5-cell shapes are rare (expected ~4%%, got %.0f%%)" % (_large_share(ch1, draws) * 100.0), _large_share(ch1, draws) < 0.10)
	ck("weights: chapter 3 drops clearly more 5-cell shapes than chapter 1 (%.0f%% vs %.0f%%)" % [_large_share(ch3, draws) * 100.0, _large_share(ch1, draws) * 100.0], _large_share(ch3, draws) > _large_share(ch1, draws) + 0.05)
	var rotations: Dictionary = ch1["rot"]
	ck("weights: all four rotations occur", rotations.size() == 4)
	var only_bar2: PieceLibrary = PieceLibrary.from_dictionary({
		"shapes": [{"id": "mono", "cells": [[0, 0]]}, {"id": "bar2", "cells": [[0, 0], [1, 0]]}],
		"weights": {"default": {"mono": 0, "bar2": 1}},
	})
	var grid := BoardGrid.new(3, 3)
	var d := FieldDrops.new(_config(), grid.player_cells(), grid.perimeter_labels(), 9)
	d.enable_pieces(only_bar2, "ch1", grid, 9)
	var seen: Dictionary = {}
	d.point_spawned.connect(func(p: FieldPoint) -> void: seen[p.piece.shape_id] = true)
	for _i: int in 100:
		d.tick(0.02, Vector2i(1, 1), 1)
	ck("weights: a weight of 0 is never drawn", seen.keys() == ["bar2"])
	var zeros: PieceLibrary = PieceLibrary.from_dictionary({
		"shapes": [{"id": "mono", "cells": [[0, 0]]}, {"id": "bar2", "cells": [[0, 0], [1, 0]]}],
		"weights": {"default": {"mono": 0, "bar2": 0}},
	})
	var z := FieldDrops.new(_config(), grid.player_cells(), grid.perimeter_labels(), 9)
	z.enable_pieces(zeros, "ch1", grid, 9)
	for _i: int in 20:
		z.tick(0.02, Vector2i(1, 1), 1)
	ck("weights: all-zero weights fall back to a uniform draw instead of stalling", z.get_points().size() > 0)


func _test_pacing() -> void:
	var grid := BoardGrid.new(3, 3)
	var capped := _piece_drops(grid, _config(0.01, 3, 100.0, 0))
	for _i: int in 100:
		capped.tick(0.05, Vector2i(1, 1), 1)
	ck("pacing: piece_max_on_field 3 caps the field at 3", capped.get_points().size() == 3)
	var five := _piece_drops(grid, _config(0.01, 5, 100.0, 0))
	for _i: int in 100:
		five.tick(0.05, Vector2i(1, 1), 1)
	ck("pacing: piece_max_on_field 5 allows 5 (classic max_on_field 4 not used)", five.get_points().size() == 5)
	var slow := _piece_drops(grid, _config(2.0, 3, 100.0, 0))
	var spawned: Array = [0]
	slow.point_spawned.connect(func(_p: FieldPoint) -> void: spawned[0] += 1)
	for _i: int in 50:
		slow.tick(0.1, Vector2i(1, 1), 1)
	# initial delay 0: spawn at t=0.1, then every 2.0 s -> t = 0.1, 2.1, 4.1 within 5.0 s.
	ck("pacing: piece_spawn_interval_sec 2.0 gives 3 spawns in 5 s (got %d)" % spawned[0], spawned[0] == 3)
	var fresh := _piece_drops(grid, _config(100.0, 3, 4.0, 0))
	var expired: Array = [0]
	fresh.point_expired.connect(func(_p: FieldPoint) -> void: expired[0] += 1)
	fresh.tick(0.1, Vector2i(1, 1), 1)
	var p: FieldPoint = fresh.get_points()[0]
	ck("pacing: a new piece lives piece_freshness_sec (4.0), not freshness_sec (7.0)", is_equal_approx(p.freshness_left, 4.0))
	fresh.tick(3.8, Vector2i(1, 1), 1)
	ck("pacing: still lying just before it rots", fresh.get_points().size() == 1 and expired[0] == 0)
	fresh.tick(0.3, Vector2i(1, 1), 1)
	ck("pacing: rots off the field after piece_freshness_sec, point_expired fires", fresh.get_points().is_empty() and expired[0] == 1)
	var scaled := _piece_drops(grid, _config(1.0, 3, 100.0, 0))
	scaled.interval_scale = 2.0
	var scaled_count: Array = [0]
	scaled.point_spawned.connect(func(_p: FieldPoint) -> void: scaled_count[0] += 1)
	for _i: int in 45:
		scaled.tick(0.1, Vector2i(1, 1), 1)
	ck("pacing: interval_scale 2.0 doubles the piece interval (spawns at ~0.1, 2.1, 4.1 -> 3 in 4.5 s, got %d)" % scaled_count[0], scaled_count[0] == 3)


func _test_start_pieces() -> void:
	var grid := BoardGrid.new(3, 3)
	var d := _piece_drops(grid, _config(3.0, 3, 8.0, 2))
	var placed: int = d.place_start_pieces(Vector2i(1, 1))
	var points: Array[FieldPoint] = d.get_points()
	var clean: bool = true
	for p: FieldPoint in points:
		clean = clean and p.piece != null and p.label == p.piece.shape_id and p.cell != Vector2i(1, 1) and grid.is_player_cell(p.cell) and is_equal_approx(p.freshness_left, 8.0)
	ck("start: start_pieces 2 places 2 pieces on free cells, not the player's", placed == 2 and points.size() == 2 and clean and points[0].cell != points[1].cell)
	d.tick(0.1, Vector2i(1, 1), 1)
	ck("start: the next drop waits a full interval after the start pieces", d.get_points().size() == 2)
	var capped := _piece_drops(grid, _config(3.0, 3, 8.0, 5))
	ck("start: start_pieces above piece_max_on_field is capped at it", capped.place_start_pieces(Vector2i(1, 1)) == 3)
	var none := _piece_drops(grid, _config(3.0, 3, 8.0, 0))
	ck("start: start_pieces 0 places nothing", none.place_start_pieces(Vector2i(1, 1)) == 0 and none.get_points().is_empty())
	var one := BoardGrid.new(1, 1)
	var lone := FieldDrops.new(_config(3.0, 3, 8.0, 2), one.player_cells(), one.perimeter_labels(), 1)
	lone.enable_pieces(lib, "ch1", one, 1)
	ck("start: no free cell besides the player's places nothing", lone.place_start_pieces(Vector2i(0, 0)) == 0)
	var a := _piece_drops(grid, _config(3.0, 3, 8.0, 2), "ch1", 77)
	var b := _piece_drops(grid, _config(3.0, 3, 8.0, 2), "ch1", 77)
	a.place_start_pieces(Vector2i(1, 1))
	b.place_start_pieces(Vector2i(1, 1))
	var same: bool = a.get_points().size() == b.get_points().size()
	for i: int in a.get_points().size():
		same = same and a.get_points()[i].cell == b.get_points()[i].cell and a.get_points()[i].label == b.get_points()[i].label and a.get_points()[i].piece.rotation == b.get_points()[i].piece.rotation
	ck("start: same seed places the same start pieces", same)


func _test_pickup_and_bag() -> void:
	var grid := BoardGrid.new(3, 3)
	var drops := FieldDrops.new(_config(), grid.player_cells(), grid.perimeter_labels(), 1)
	drops.enable_pieces(lib, "ch1", grid, 1)
	var hand: HoldSlots = HoldSlots.create_piece_hand(3)
	ck("bag: create_piece_hand(3) has 3 slots; 5 and 0 are not clamped to 3..4", hand.get_slot_count() == 3 and HoldSlots.create_piece_hand(5).get_slot_count() == 5 and HoldSlots.create_piece_hand(0).get_slot_count() == 1)
	ck("bag: the classic constructor still clamps to 3..4", HoldSlots.new(1).get_slot_count() == 3 and HoldSlots.new(9).get_slot_count() == 4)
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]
	var ids: Array[String] = ["bar3", "t4", "mono", "square"]
	for i: int in 4:
		drops.debug_place_piece(lib.make_piece(ids[i], i), cells[i], 10.0)
	for i: int in 3:
		var got: FieldPoint = drops.pick_up_at(cells[i], hand.can_place())
		ck("bag: pickup %d succeeds and fills slot %d" % [i + 1, i], got != null and hand.place_in_first_free(got) == i)
	ck("bag: get_piece returns the held pieces (shape and rotation kept)", hand.get_piece(0).shape_id == "bar3" and hand.get_piece(1).shape_id == "t4" and hand.get_piece(1).rotation == 1 and hand.get_piece(2).shape_id == "mono")
	ck("bag: the bag is full", hand.is_full() and not hand.can_place())
	var blocked: Array = [0]
	drops.pickup_blocked.connect(func(_p: FieldPoint) -> void: blocked[0] += 1)
	var fourth: FieldPoint = drops.pick_up_at(cells[3], hand.can_place())
	ck("bag: a 4th pickup is refused, pickup_blocked fires, the piece stays", fourth == null and blocked[0] == 1 and drops.get_points().size() == 1 and drops.get_points()[0].cell == cells[3])
	hand.remove(1)
	var retry: FieldPoint = drops.pick_up_at(cells[3], hand.can_place())
	ck("bag: after a slot frees the same piece can be picked up", retry != null and hand.place_in_first_free(retry) == 1 and hand.get_piece(1).shape_id == "square")
	ck("bag: get_piece is null for an out-of-range index", hand.get_piece(-1) == null and hand.get_piece(9) == null)
	var h2: HoldSlots = HoldSlots.create_piece_hand(3)
	ck("bag: get_piece is null for an empty slot", h2.get_piece(0) == null)
	var classic := FieldPoint.new()
	classic.label = "A1"
	h2.place_in_first_free(classic)
	ck("bag: get_piece is null for a classic label point", h2.get_piece(0) == null and h2.get_point(0) == classic)
	ck("bag: a non-rotten piece can be selected", hand.toggle_selected(0) and hand.is_selected(0))


func _test_blocked_and_hunger() -> void:
	var grid := BoardGrid.new(3, 3)
	var blocked_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	var d := _piece_drops(grid, _config(0.01, 3, 0.02, 0), "ch1", 5)
	d.set_blocked_cells(blocked_cells)
	var bad: bool = false
	var seen: int = 0
	for _i: int in 300:
		d.tick(0.02, Vector2i(2, 0), 1)
		for p: FieldPoint in d.get_points():
			seen += 1
			bad = bad or blocked_cells.has(p.cell)
	ck("blocked: pieces never spawn on a burning cell (%d seen)" % seen, not bad and seen > 0)
	var e := FieldDrops.new(_config(), grid.player_cells(), grid.perimeter_labels(), 1)
	e.enable_pieces(lib, "ch1", grid, 1)
	e.debug_place_piece(lib.make_piece("bar2"), Vector2i(0, 0), 5.0)
	e.debug_place_piece(lib.make_piece("mono"), Vector2i(1, 0), 5.0)
	e.set_blocked_cells([Vector2i(0, 0)] as Array[Vector2i])
	var sig: Array = [0]
	e.pickup_blocked.connect(func(_p: FieldPoint) -> void: sig[0] += 1)
	ck("blocked: a burning cell refuses pickup silently", e.pick_up_at(Vector2i(0, 0), true) == null and e.pick_up_at(Vector2i(0, 0), false) == null and sig[0] == 0)
	ck("blocked: another cell still works", e.pick_up_at(Vector2i(1, 0), true) != null)
	var hungry_cfg := _config(2.0, 1, 0.5, 0)
	hungry_cfg.hungry_after_sec = 1.0
	hungry_cfg.hungry_interval_mult = 0.5
	var hungry := _piece_drops(grid, hungry_cfg)
	var hungry_n: Array = [0]
	hungry.point_spawned.connect(func(_p: FieldPoint) -> void: hungry_n[0] += 1)
	hungry.tick(2.0, Vector2i(1, 1), 0)
	hungry.tick(0.5, Vector2i(1, 1), 0)
	hungry.tick(0.5, Vector2i(1, 1), 0)
	var fed := _piece_drops(grid, hungry_cfg)
	var fed_n: Array = [0]
	fed.point_spawned.connect(func(_p: FieldPoint) -> void: fed_n[0] += 1)
	fed.tick(2.0, Vector2i(1, 1), 1)
	fed.tick(0.5, Vector2i(1, 1), 1)
	fed.tick(0.5, Vector2i(1, 1), 1)
	ck("hunger: an empty hand halves the piece interval (second piece after 1.0 s, not 2.0 s)", hungry_n[0] == 2 and fed_n[0] == 1)


func _test_rotten_piece() -> void:
	var grid := BoardGrid.new(3, 3)
	var drops := _piece_drops(grid, _config(100.0, 3, 8.0, 0))
	var thrown: Array = []
	drops.point_spawned.connect(func(p: FieldPoint) -> void: thrown.append(p))
	var point: FieldPoint = drops.place_rotten_piece(Vector2i(2, 1), 6.0, 2.0)
	ck("rotten piece: placed as a rotten point carrying a rotten piece, point_spawned fires", point != null and point.rotten and point.piece != null and point.piece.is_rotten() and thrown.size() == 1)
	ck("rotten piece: 1 cell, label is the reserved id, timers stored", point.piece.cell_count() == 1 and point.label == Piece.ROTTEN_ID and is_equal_approx(point.freshness_left, 6.0) and is_equal_approx(point.rot_in_hand_sec, 2.0))
	ck("rotten piece: never placeable (flag, anchors, any rotation, snap)", not point.piece.placeable() and PiecePlacement.valid_anchors(grid, point.piece).is_empty() and not PiecePlacement.has_any_placement(grid, point.piece) and PiecePlacement.snap(grid, point.piece, Vector2i(4, 1)).is_empty())
	ck("rotten piece: refuses an occupied cell, a boss cell and a burning cell", drops.place_rotten_piece(Vector2i(2, 1), 5.0, 5.0) == null and drops.place_rotten_piece(Vector2i(4, 1), 5.0, 5.0) == null)
	drops.set_blocked_cells([Vector2i(0, 0)] as Array[Vector2i])
	ck("rotten piece: refuses a blocked cell", drops.place_rotten_piece(Vector2i(0, 0), 5.0, 5.0) == null)
	drops.set_blocked_cells([] as Array[Vector2i])
	var full := _piece_drops(grid, _config(100.0, 1, 8.0, 0))
	full.place_rotten_piece(Vector2i(0, 0), 5.0, 5.0)
	full.tick(0.1, Vector2i(1, 1), 1)
	ck("rotten piece: counts toward piece_max_on_field (no drop while it lies there)", full.get_points().size() == 1)
	var hand: HoldSlots = HoldSlots.create_piece_hand(3)
	var cleared: Array[int] = []
	hand.slot_cleared.connect(func(index: int, _p: FieldPoint) -> void: cleared.append(index))
	var picked: FieldPoint = drops.pick_up_at(Vector2i(2, 1), hand.can_place())
	var slot: int = hand.place_in_first_free(picked)
	ck("rotten piece: picked up it occupies a bag slot", picked == point and slot == 0 and hand.get_occupied_count() == 1 and hand.get_rotten_count() == 1)
	ck("rotten piece: the held piece reports not placeable", hand.get_piece(0).is_rotten() and not hand.get_piece(0).placeable())
	ck("rotten piece: it cannot be selected", hand.toggle_selected(0) == false and hand.get_selected_indices().is_empty())
	hand.tick_rot(1.0)
	ck("rotten piece: still in the hand before rot_in_hand_sec", hand.get_occupied_count() == 1 and cleared.is_empty())
	hand.tick_rot(1.0)
	ck("rotten piece: rots out of the hand after rot_in_hand_sec with slot_cleared", hand.get_occupied_count() == 0 and cleared == ([0] as Array[int]))
	var lying := _piece_drops(grid, _config(100.0, 3, 8.0, 0))
	lying.place_rotten_piece(Vector2i(0, 2), 1.0, 5.0)
	lying.tick(1.1, Vector2i(1, 1), 1)
	var still_rotten: bool = false
	for p: FieldPoint in lying.get_points():
		still_rotten = still_rotten or p.rotten
	ck("rotten piece: rots off the field after freshness_left", not still_rotten)
	var classic_mode := FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), grid.perimeter_labels(), 1)
	var in_classic: FieldPoint = classic_mode.place_rotten_piece(Vector2i(0, 0), 5.0, 5.0)
	ck("rotten piece: place_rotten_piece also works without piece mode", in_classic != null and in_classic.piece.is_rotten())


func _test_rotten_thrower() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var params: Dictionary = {"first_delay_sec": 0.0, "interval_sec": 2.0, "max_on_field": 1, "rot_in_hand_sec": 3.0, "field_freshness_sec": 50.0}
	# Piece mode: the throw is a rotten piece.
	var piece_drops := _piece_drops(grid, _config(100.0, 3, 8.0, 0))
	var t1 := RottenThrowerTrait.new()
	t1.setup({"player_drops": piece_drops, "state": state, "grid": grid}, params, 3)
	t1.on_match_start()
	t1.on_tick(0.1)
	var points: Array[FieldPoint] = piece_drops.get_points()
	ck("thrower: piece mode throws a rotten piece", points.size() == 1 and points[0].rotten and points[0].piece != null and points[0].piece.is_rotten() and not points[0].piece.placeable())
	ck("thrower: the piece lies on a free player cell, not the player's", grid.is_player_cell(points[0].cell) and points[0].cell != state.player_cell and is_equal_approx(points[0].rot_in_hand_sec, 3.0))
	t1.on_tick(0.1)
	t1.on_tick(0.1)
	ck("thrower: max_on_field still respected in piece mode", piece_drops.get_points().size() == 1 and t1.get_throw_count() == 1)
	# Classic mode: unchanged label point.
	var classic_drops := FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), grid.perimeter_labels(), 3)
	var t2 := RottenThrowerTrait.new()
	t2.setup({"player_drops": classic_drops, "state": state, "grid": grid}, params, 3)
	t2.on_match_start()
	t2.on_tick(0.1)
	var classic_points: Array[FieldPoint] = classic_drops.get_points()
	ck("thrower: classic mode still throws a labelled rotten point without a piece", classic_points.size() == 1 and classic_points[0].rotten and classic_points[0].piece == null and classic_points[0].label == "X")


func _test_config_keys() -> void:
	var from_file: FieldDropsConfig = FieldDropsConfig.load_from_file()
	ck("config: field_drops.json carries the piece keys (3.0 / 3 / 8.0 / 1)", is_equal_approx(from_file.piece_spawn_interval_sec, 3.0) and from_file.piece_max_on_field == 3 and is_equal_approx(from_file.piece_freshness_sec, 8.0) and from_file.start_pieces == 1)
	ck("config: classic keys are untouched (1.8 / 4 / 7.0)", is_equal_approx(from_file.spawn_interval_sec, 1.8) and from_file.max_on_field == 4 and is_equal_approx(from_file.freshness_sec, 7.0))
	var defaults: FieldDropsConfig = FieldDropsConfig.from_dictionary({})
	ck("config: missing piece keys keep the documented defaults", is_equal_approx(defaults.piece_spawn_interval_sec, 3.0) and defaults.piece_max_on_field == 3 and is_equal_approx(defaults.piece_freshness_sec, 8.0) and defaults.start_pieces == 1)
	var clamped: FieldDropsConfig = FieldDropsConfig.from_dictionary({"piece_spawn_interval_sec": -1, "piece_max_on_field": 0, "piece_freshness_sec": 0, "start_pieces": -4})
	ck("config: nonsense piece keys clamp (interval/freshness default, max >= 1, start >= 0)", is_equal_approx(clamped.piece_spawn_interval_sec, 3.0) and clamped.piece_max_on_field == 1 and is_equal_approx(clamped.piece_freshness_sec, 8.0) and clamped.start_pieces == 0)
	var custom: FieldDropsConfig = FieldDropsConfig.from_dictionary({"piece_spawn_interval_sec": 1.5, "piece_max_on_field": 2, "piece_freshness_sec": 5.0, "start_pieces": 2})
	var copy: FieldDropsConfig = custom.copy()
	ck("config: copy() carries the piece keys", is_equal_approx(copy.piece_spawn_interval_sec, 1.5) and copy.piece_max_on_field == 2 and is_equal_approx(copy.piece_freshness_sec, 5.0) and copy.start_pieces == 2)
	var hold: HoldSlotsConfig = HoldSlotsConfig.load_from_file()
	ck("config: hold_slots.json has piece_slot_count 3 and slot_count 4", hold.piece_slot_count == 3 and hold.slot_count == 4)
	ck("config: piece_slot_count clamps to 1..6 and slot_count keeps its 3..4 clamp", HoldSlotsConfig.from_dictionary({"piece_slot_count": 0}).piece_slot_count == 1 and HoldSlotsConfig.from_dictionary({"piece_slot_count": 99}).piece_slot_count == 6 and HoldSlotsConfig.from_dictionary({"slot_count": 9}).slot_count == 4 and HoldSlotsConfig.from_dictionary({}).piece_slot_count == 3)
