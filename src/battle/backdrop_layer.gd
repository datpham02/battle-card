class_name BackdropLayer
extends Node2D
## Bottom layer of the battle art canvas (Story 047 Part B, art bible 6.4 / 8.6): the region's
## scenery behind the board, in art px of the 800x360 SubViewport. Draws the far backdrop at (0, 0)
## (the whole canvas) and the near mist strip with its bottom on `backdrop.near_bottom_row` of the
## region's `region.json` (the prototype's placement: the strip's last row is `near_bottom_row - 1`).
## A region without backdrop art (today everything but `forest`) gets two flat bands from
## `assets/art/regions.json` (`fallback_bands`: sky above the 20 % board band, ground below) so the
## canvas never shows the old beige and never crashes.
## Redraws only on [method setup] and [method set_region_id]: the backdrop is static for a match
## and independent of the screen size (the canvas is scaled as a whole by BattleCanvas).
## Implements: Story 047 Part B.

var _combat: CombatView = null
var _region_id: String = ArtAssets.DEFAULT_REGION
var _far: Texture2D = null
var _near: Texture2D = null
var _near_bottom_row: int = 0
var _bands: Dictionary = {}
var _redraws: int = 0


## Binds the layer to the battle's CombatView, resolves the art region from
## `match_params["chapter_id"]` (ArtAssets.region_for_chapter; "" -> the default region) and redraws.
func setup(combat: CombatView) -> void:
	_combat = combat
	var chapter: String = str(combat.match_params.get("chapter_id", "")) if combat != null else ""
	set_region_id(ArtAssets.region_for_chapter(chapter))


## Switches the backdrop to art region [param id] (loads its textures, or the flat bands) and redraws.
func set_region_id(id: String) -> void:
	_region_id = id
	_far = ArtAssets.region_texture(id, "backdrop.far")
	_near = ArtAssets.region_texture(id, "backdrop.near")
	# 2026-11-06: a far backdrop drawn with its own mist (bg_forest_far_v2) turns the near strip off
	# (`backdrop.near_enabled` false); the strip, made for the old far, read as white specks over the new canopy.
	var bd: Variant = ArtAssets.region(id).get("backdrop", {})
	if bd is Dictionary and not bool((bd as Dictionary).get("near_enabled", true)):
		_near = null
	var backdrop: Variant = ArtAssets.region(id).get("backdrop", {})
	_near_bottom_row = int((backdrop as Dictionary).get("near_bottom_row", 0)) if backdrop is Dictionary else 0
	_bands = ArtAssets.fallback_bands(id)
	queue_redraw()


## The art region drawn right now (`forest`, ...).
func get_region_id() -> String:
	return _region_id


## True when the region's far backdrop texture is missing and the flat bands are drawn instead.
func is_fallback() -> bool:
	return _far == null


## Number of times `_draw` ran (tests: redraws happen on setup / region change only, never per frame).
func get_redraw_count() -> int:
	return _redraws


func _draw() -> void:
	_redraws += 1
	var canvas := Rect2(Vector2.ZERO, Vector2(ScreenLayout.ART_CANVAS_WIDTH, ScreenLayout.ART_CANVAS_HEIGHT))
	if _far == null:
		# Flat fallback: sky over the scenery band, ground from the board band top down (72 art px at
		# BOARD_BAND_TOP_RATIO 0.20), both from regions.json so no colour lives in code.
		# The first _draw runs on entering the tree, before the deferred setup: resolve the bands then.
		if _bands.is_empty():
			_bands = ArtAssets.fallback_bands(_region_id)
		var horizon: float = floorf(ScreenLayout.ART_CANVAS_HEIGHT * ScreenLayout.BOARD_BAND_TOP_RATIO)
		draw_rect(Rect2(Vector2.ZERO, Vector2(canvas.size.x, horizon)), _bands["sky"])
		draw_rect(Rect2(Vector2(0.0, horizon), Vector2(canvas.size.x, canvas.size.y - horizon)), _bands["ground"])
	else:
		draw_texture_rect(_far, Rect2(Vector2.ZERO, _far.get_size()), false)
	if _near != null:
		var y: int = _near_bottom_row - _near.get_height()
		draw_texture_rect(_near, Rect2(Vector2(0.0, float(y)), _near.get_size()), false)
	# 2026-11-06 (Misty Forest background redesign, free first pass): the painted ground under the board competes
	# with the arena as a second ground plane; region.json `backdrop.ground_shade` lays stepped Ink bands over it
	# ({"from_row": int, "band": int, "alphas": [..]}: one band per alpha, the last alpha down to the bottom).
	var shade: Variant = ArtAssets.region(_region_id).get("backdrop", {}).get("ground_shade", {}) if not _region_id.is_empty() else {}
	if shade is Dictionary and not (shade as Dictionary).is_empty():
		var row: int = int(shade.get("from_row", ScreenLayout.ART_CANVAS_HEIGHT))
		var band: int = maxi(int(shade.get("band", 6)), 1)
		var alphas: Array = shade.get("alphas", [])
		for i: int in alphas.size():
			var h: float = float(band) if i < alphas.size() - 1 else maxf(ScreenLayout.ART_CANVAS_HEIGHT - row, 0.0)
			draw_rect(Rect2(0.0, float(row), canvas.size.x, h), Color(Color("1B1722"), float(alphas[i])))
			row += band
