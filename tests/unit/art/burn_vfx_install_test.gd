extends SceneTree
## 2026-11-04 (user: "VFX Pháp sư"): the fire packs of tools/fx-pipeline recipe hoa_tran are installed. Every card whose
## delivery impact is `burn` (the Mage's Hỏa Xà / Hỏa Tinh / Hỏa Trận) plays the stepped square flame on each hit cell
## (cast index `impact_packs.burn`) and leaves embers on it (`impact_marks.burn`); the code-drawn flash and square
## shards are left out for that impact so the cell is not drawn twice; impacts without a pack keep them.
## Run: godot --headless --path . -s res://tests/unit/art/burn_vfx_install_test.gd

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_check("test_burn_impact_plays_the_flame_pack", CastVfx.impact_pack("burn") == "impact_flame_burn", CastVfx.impact_pack("burn"))
	_check("test_burn_impact_leaves_embers", CastVfx.impact_mark("burn") == "mark_embers_burn", CastVfx.impact_mark("burn"))
	_check("test_slash_has_no_mark", CastVfx.impact_mark("slash") == "")
	_check("test_burn_pack_replaces_code_shards", CastVfx.impact_pack_owns_cells("burn"))
	_check("test_unmapped_impact_keeps_code_shards", not CastVfx.impact_pack_owns_cells("thorns"))
	var vfx := FloorVfx.new()
	for id: String in ["impact_flame_burn", "impact_flame_burn_c43x31", "mark_embers_burn", "mark_embers_burn_c43x31"]:
		var p: VfxPack = vfx.pack(id)
		_check("test_%s_installed_and_loads" % id, vfx.has_pack(id) and p != null)
	_check("test_small_cells_use_the_small_flame", vfx.variant_for("impact_flame_burn", Vector2i(43, 31)) == "impact_flame_burn_c43x31",
		vfx.variant_for("impact_flame_burn", Vector2i(43, 31)))
	_check("test_overlay_flame_is_once", str(vfx.entry("impact_flame_burn").get("layer", "")) == "overlay"
		and str(vfx.entry("impact_flame_burn").get("play", "")) == "once")
	_check("test_embers_on_the_floor_layer", str(vfx.entry("mark_embers_burn").get("layer", "")) == "floor")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
