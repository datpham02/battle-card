extends SceneTree
## Story 048 Part B: FloorVfx — frame_for (loop / once / once_hold / reduce motion), the one-shot queue, the hold
## ages, and the nine shipped floor packs (index entries load, clip "whole" has regions, its PNG exists).
## Headless, deterministic.
## Run: godot --headless --path . -s res://tests/unit/art/floor_vfx_test.gd

const FloorVfxScript := preload("res://src/art/floor_vfx.gd")

const PACK_IDS: Array[String] = [
	"burning_cell", "engraving_lit", "engraving_complete", "cracked_cell", "cast_target",
	"hit_impact", "miss_dust", "interrupt", "thorn_spikes", "root_seal", "cell_slash", "big_burst", "small_burst",
	# 2026-11-02 tools/fx-pipeline (recipe kiem_khi) and their 43x31 cell variants
	"impact_burst_big_steel", "impact_burst_big_steel_c43x31", "impact_burst_small_steel", "impact_burst_small_steel_c43x31",
	"mark_stamp_big_steel", "mark_stamp_big_steel_c43x31", "mark_stamp_small_steel", "mark_stamp_small_steel_c43x31",
	# 2026-11-04 (recipe hoa_tran, the Mage's fire)
	"impact_flame_burn", "impact_flame_burn_c43x31", "mark_embers_burn", "mark_embers_burn_c43x31",
	"impact_flame_small_burn", "impact_flame_small_burn_c43x31",
	# 2026-11-08 (Trảm Địa art, vfx_workbench): the burst cell's eruption and its floor mark
	"impact_eruption_tram_dia", "mark_eruption_tram_dia",
]
## Fixture entries (factory data; the frame counts / times are the point of the boundary checks).
const LOOP_ENTRY: Dictionary = {"play": "loop", "frames": 4, "frame_ms": 100}
const ONCE_ENTRY: Dictionary = {"play": "once", "frames": 6, "frame_ms": 50}
const HOLD_ENTRY: Dictionary = {"play": "once_hold", "frames": 12, "frame_ms": 100, "hold_frame": 7}

var fails: int = 0


func check(name: String, ok: bool) -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name)


func _init() -> void:
	test_loop_wraps()
	test_once_finishes()
	test_once_hold_stops_on_hold_frame()
	test_reduce_motion()
	test_empty_entry()
	test_queue_drops_finished_events()
	test_hold_ages()
	test_all_packs_load()
	test_missing_id_is_null()
	test_feet_for()
	test_variant_for_picks_the_nearest_cell()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_loop_wraps() -> void:
	check("loop_frame0", FloorVfxScript.frame_for(LOOP_ENTRY, 0.0, false) == 0)
	check("loop_frame3", FloorVfxScript.frame_for(LOOP_ENTRY, 0.35, false) == 3)
	check("loop_wraps_to_0", FloorVfxScript.frame_for(LOOP_ENTRY, 0.41, false) == 0)
	check("loop_wraps_to_1", FloorVfxScript.frame_for(LOOP_ENTRY, 0.51, false) == 1)


func test_once_finishes() -> void:
	check("once_frame0", FloorVfxScript.frame_for(ONCE_ENTRY, 0.0, false) == 0)
	check("once_last_frame", FloorVfxScript.frame_for(ONCE_ENTRY, 0.29, false) == 5)
	check("once_finished_is_minus1", FloorVfxScript.frame_for(ONCE_ENTRY, 0.31, false) == -1)


func test_once_hold_stops_on_hold_frame() -> void:
	check("hold_frame3", FloorVfxScript.frame_for(HOLD_ENTRY, 0.35, false) == 3)
	check("hold_reaches_7", FloorVfxScript.frame_for(HOLD_ENTRY, 0.75, false) == 7)
	check("hold_stays_7", FloorVfxScript.frame_for(HOLD_ENTRY, 30.0, false) == 7)


func test_reduce_motion() -> void:
	check("reduce_loop_0", FloorVfxScript.frame_for(LOOP_ENTRY, 0.35, true) == 0)
	check("reduce_hold_is_hold_frame", FloorVfxScript.frame_for(HOLD_ENTRY, 0.0, true) == 7)
	check("reduce_once_middle", FloorVfxScript.frame_for(ONCE_ENTRY, 0.0, true) == 3)
	check("reduce_once_still_finishes", FloorVfxScript.frame_for(ONCE_ENTRY, 0.31, true) == -1)


func test_empty_entry() -> void:
	check("empty_entry_minus1", FloorVfxScript.frame_for({}, 0.0, false) == -1)


func test_queue_drops_finished_events() -> void:
	var vfx: FloorVfx = FloorVfxScript.new()
	var hit: Dictionary = vfx.entry("hit_impact")
	var dust: Dictionary = vfx.entry("miss_dust")
	var hit_sec: float = float(hit["frames"]) * float(hit["frame_ms"]) / 1000.0
	var dust_sec: float = float(dust["frames"]) * float(dust["frame_ms"]) / 1000.0
	vfx.play("hit_impact", Vector2i(1, 0), 1)
	vfx.play("miss_dust", Vector2i(2, 1), 1)
	vfx.play("no_such_effect", Vector2i(0, 0), 1)
	check("queue_two_events", vfx.active_events().size() == 2)
	check("queue_overlay_filter", vfx.active_events(FloorVfx.LAYER_OVERLAY).size() == 1)
	check("queue_floor_filter", vfx.active_events(FloorVfx.LAYER_FLOOR).size() == 1)
	vfx.tick(0.0)
	check("queue_zero_tick_keeps", vfx.active_events().size() == 2)
	vfx.tick(hit_sec + 0.001)
	check("queue_hit_dropped_dust_kept", vfx.active_events().size() == 1 and str(vfx.active_events()[0]["id"]) == "miss_dust")
	vfx.tick(dust_sec)
	check("queue_empty_after_all_finish", vfx.active_events().is_empty())
	check("clock_advanced", absf(vfx.elapsed() - (hit_sec + 0.001 + dust_sec)) < 0.0001)


func test_hold_ages() -> void:
	var vfx: FloorVfx = FloorVfxScript.new()
	var a: Vector2i = Vector2i(0, 0)
	var b: Vector2i = Vector2i(1, 0)
	vfx.hold_ages("crack", [a])
	vfx.tick(0.5)
	var ages: Dictionary = vfx.hold_ages("crack", [a, b])
	check("hold_age_old_key", absf(float(ages[a]) - 0.5) < 0.0001)
	check("hold_age_new_key_0", absf(float(ages[b])) < 0.0001)
	vfx.hold_ages("crack", [b])
	vfx.tick(0.25)
	ages = vfx.hold_ages("crack", [a, b])
	check("hold_forgotten_key_restarts", absf(float(ages[a])) < 0.0001)


func test_all_packs_load() -> void:
	var vfx: FloorVfx = FloorVfxScript.new()
	check("index_has_%d_entries_got_%d" % [PACK_IDS.size(), vfx.ids().size()], vfx.ids().size() == PACK_IDS.size())
	# User 2026-11-01: every floor effect sits in the middle of its cell; a centre-anchored frame's middle is the cell's.
	var cell := Rect2i(10, 20, 64, 46)
	var at: Vector2i = FloorVfxScript.centre_anchor(cell, Vector2i(-32, -28), Vector2i(64, 30))
	check("centre_anchor_frame_middle_on_cell_centre", at + Vector2i(-32, -28) + Vector2i(32, 15) == Vector2i(42, 43))
	check("root_seal_is_centred_loop", str(vfx.entry("root_seal").get("anchor", "")) == "center"
		and str(vfx.entry("root_seal").get("play", "")) == "loop")
	for id: String in PACK_IDS:
		var pack: VfxPack = vfx.pack(id)
		check("pack_loads_%s" % id, pack != null)
		if pack == null:
			continue
		var c: Dictionary = pack.clip("whole")
		var regions: Array = c.get("regions", [])
		check("pack_%s_whole_regions_%d" % [id, regions.size()], regions.size() == int(vfx.entry(id)["frames"]))
		check("pack_%s_png_exists" % id, FileAccess.file_exists(pack.dir().path_join(str(c.get("file", "")))))
		check("pack_%s_drawable" % id, vfx.has_pack(id))
	var hold: Dictionary = vfx.entry("cracked_cell")
	check("cracked_cell_once_hold_7", str(hold["play"]) == "once_hold" and int(hold["hold_frame"]) == 7)
	check("cast_target_hero_tint", str(vfx.entry("cast_target").get("tint", "")) == "hero_block")


func test_missing_id_is_null() -> void:
	var vfx: FloorVfx = FloorVfxScript.new()
	check("missing_pack_null", vfx.pack("no_such_effect") == null)
	check("missing_entry_empty", vfx.entry("no_such_effect").is_empty())
	check("missing_not_drawable", not vfx.has_pack("no_such_effect"))
	check("missing_draw_false", not vfx.draw(null, "no_such_effect", Vector2i.ZERO, 0))


func test_feet_for() -> void:
	check("feet_bottom_centre", FloorVfxScript.feet_for(Rect2i(10, 20, 40, 30)) == Vector2i(30, 50))


# 2026-11-02: a pack made for several cell sizes is drawn in the variant made for the nearest cell (never scaled).
func test_variant_for_picks_the_nearest_cell() -> void:
	# Arrange: the shipped index (impact_burst_big_steel made for 64x46, its _c43x31 variant for 43x31)
	var vfx: FloorVfx = FloorVfxScript.new()
	var base: String = "impact_burst_big_steel"
	# Act / Assert
	check("variant_big_cell_keeps_the_base", vfx.variant_for(base, Vector2i(64, 46)) == base)
	check("variant_small_cell_takes_c43x31", vfx.variant_for(base, Vector2i(43, 31)) == base + "_c43x31")
	check("variant_45x32_boss_hall_takes_c43x31", vfx.variant_for(base, Vector2i(45, 32)) == base + "_c43x31")
	check("variant_58x41_takes_the_base", vfx.variant_for(base, Vector2i(58, 41)) == base)
	check("variant_empty_size_keeps_the_id", vfx.variant_for(base, Vector2i.ZERO) == base)
	check("variant_pack_without_cell_keeps_the_id", vfx.variant_for("hit_impact", Vector2i(43, 31)) == "hit_impact")
	check("variant_same_frame_count", int(vfx.entry(base).get("frames", 0)) == int(vfx.entry(base + "_c43x31").get("frames", -1)))
