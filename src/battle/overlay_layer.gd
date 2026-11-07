class_name OverlayLayer
extends Node2D
## Top layer of the battle art canvas (Story 047, art bible 8.6): effects drawn over the units, in
## art px of the 800x360 SubViewport. Story 048 Part B: the overlay one-shots of FloorVfx (layer "overlay",
## each <= 0.35 s): F6 hit_impact on a hit cut's cells where a unit stands, F8 interrupt on interrupted swing cells.
## Redraws only while it has events (and once more when the last one ends, to clear it).
## 2026-10-31: also the hero's cast projectile (CastVfx): from the hero's hand to the target cells over the last
## travel_sec of the player's swing, landing as it resolves. ADR-0001 A1: only for a card whose delivery origin is
## `caster` (SkillDelivery); the per-cell impacts after the landing are CombatView's.
## ADR-0001 Phase 1 Task 5 (pack 01 §1A / §3 step 4): the code-drawn square travels (CastFloorFx, index.json
## travel_style): the caster's streak (a pack with travel_draw square_streak draws stepped squares instead of its art,
## same timing), falling_squares landing on each cell at its arrival, chain_spark hopping link to link, floor_run along
## the floor; plus the square impact flash on each reached cell. Locked cells get no landing / flash (item 5). All in
## the hero's block colours over a 1 px Ink edge; animation only, never the gameplay Block.
## Implements: Story 047 Part A, Story 048 Part B.

var _floor: FloorLayer = null
## The items drawn last ([] = none); compared by value each frame.
var _drawn: Array[Dictionary] = []
var _redraws: int = 0


## Binds the layer to the battle's FloorLayer (for cell_art_rect and the CombatView). When never called, the
## sibling named "FloorLayer" is used.
func setup(floor: FloorLayer) -> void:
	_floor = floor


## Number of times `_draw` ran.
func get_redraw_count() -> int:
	return _redraws


## The overlay effects to draw now: one `{id, cell, frame}` per running one-shot; [] when unbound or none runs.
func vfx_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null:
		return out
	var vfx: FloorVfx = combat.get_floor_vfx()
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	for ev: Dictionary in vfx.active_events(FloorVfx.LAYER_OVERLAY):
		var frame: int = FloorVfx.frame_for(vfx.entry(str(ev["id"])), float(ev["age"]), reduce)
		if frame >= 0:
			out.append({"id": str(ev["id"]), "cell": ev["cell"], "frame": frame})
	return out


func _process(_delta: float) -> void:
	if _floor == null and get_parent() != null:
		_floor = get_parent().get_node_or_null("FloorLayer") as FloorLayer
	var state: Array[Dictionary] = vfx_state()
	var shot: Dictionary = projectile_state()
	if not shot.is_empty():
		state.append(shot)
	var cut: Dictionary = release_state()
	if not cut.is_empty():
		state.append(cut)
	var combat_now: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat_now != null and not combat_now.get_cast_flood().is_empty():
		state.append({"flood": combat_now.get_floor_vfx().elapsed()})
	var travel: Array[Dictionary] = travel_items()
	if not travel.is_empty():
		state.append({"travel": travel})
	if state != _drawn:
		_drawn = state
		queue_redraw()


## 2026-10-31: the hero's cast projectile now: {"projectile": pack id, "pos": Vector2i art px, "frame": int}; {} when the
## player is not in the last travel_sec of a swing, or there is no cast pack / canvas binding.
func projectile_state() -> Dictionary:
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or combat.get_cut_actor() == null or combat.get_battle_canvas() == null:
		return {}
	var actor: CutActor = combat.get_cut_actor()
	if not actor.is_swinging():
		return {}
	var units: UnitLayer = combat.get_battle_canvas().get_unit_layer()
	if units == null:
		return {}
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var delivery: Dictionary = combat.delivery_for(actor.get_skill_id())
	var entry: Dictionary = CastVfx.entry_for(hero_id, str(delivery.get("impact", "")))
	if entry.is_empty():
		return {}
	var from: Vector2i = CastVfx.hand_point(entry, units.unit_feet_art(CombatState.Side.PLAYER))
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	# OSFE beat 1: the charge glint at the hand over the last charge_sec before the launch.
	var charged: float = CastVfx.charge_elapsed(entry, actor.get_time_left())
	if charged >= 0.0:
		var charge: Dictionary = CastVfx.charge_entry(entry)
		var charge_pack: VfxPack = CastVfx.pack_for(charge)
		if charge_pack == null:
			return {}
		var clip: String = str(charge.get("clip", CastVfx.DEFAULT_CLIP))
		var cframe: int = 0 if reduce else VfxPack.frame_at(charge_pack.clip(clip), charged, charge_pack.frame_ms(), charge_pack.is_loop())
		return {"projectile": str(charge["id"]), "pos": from, "frame": cframe, "clip": clip, "hero": hero_id, "charge": true}
	var t: float = CastVfx.flight_t(entry, actor.get_time_left())
	if t < 0.0:
		return {}
	# ADR-0001 A1: only a delivery that leaves the caster flies from the hand (sky / ground / in-place / a chain that
	# starts on its first cell do not); the projectile is square-based art, never the gameplay Block.
	if str(delivery.get("origin", "")) != "caster":
		return {}
	var targets: Array[Vector2i] = []
	for cell: Vector2i in actor.get_cells():
		targets.append(units.feet_art_of_cell(cell))
	# OSFE beat 2: a straight shot; on the first_cell path to the cell the delivery lands on first (the nearest cell,
	# or a chain's first link), where the spread starts.
	var to: Vector2i = CastVfx.flight_to(entry, from, targets)
	if str(entry.get("path", "")) == CastVfx.PATH_FIRST_CELL and not actor.get_cells().is_empty():
		var first: Vector2i = SkillDelivery.first_link(delivery, actor.get_cells(), combat.get_state().player_cell)
		to = CastVfx.aim_point(entry, [units.feet_art_of_cell(first)] as Array[Vector2i])
	var pos: Vector2i = CastVfx.flight_pos(from, to, t)
	# Task 5 item 3: the crescent wave is not square-based (pack 01 §1A): the pack's art stays on disk, unused.
	if str(entry.get("travel_draw", "")) == "square_streak":
		return {"streak": str(entry["id"]), "from": from, "to": to, "t": t, "hero": hero_id, "impact": str(delivery.get("impact", ""))}
	var pack: VfxPack = CastVfx.pack_for(entry)
	var frame: int = 0
	if pack != null and not reduce:
		frame = VfxPack.frame_at(pack.clip(str(entry.get("clip", CastVfx.DEFAULT_CLIP))), CastVfx.travel_sec(entry) * t, pack.frame_ms(), pack.is_loop())
	return {"projectile": str(entry["id"]), "pos": pos, "frame": frame, "clip": str(entry.get("clip", CastVfx.DEFAULT_CLIP)), "hero": hero_id}


## 2026-11-02 (tools/fx-pipeline): the hero's release cut now: {"release": pack id, "pos": the hand (art px), "frame",
## "clip"}; {} when the hero's cast entry has no `release` pack, the player is not swinging, or the cut is over. It starts
## when the cast_gesture jumps to its slash frame (CastVfx.release_elapsed) and plays once.
func release_state() -> Dictionary:
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or combat.get_cut_actor() == null or combat.get_battle_canvas() == null:
		return {}
	var actor: CutActor = combat.get_cut_actor()
	if not actor.is_swinging():
		return {}
	var units: UnitLayer = combat.get_battle_canvas().get_unit_layer()
	if units == null:
		return {}
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var entry: Dictionary = CastVfx.entry_for(hero_id, str(combat.delivery_for(actor.get_skill_id()).get("impact", "")))
	var elapsed: float = CastVfx.release_elapsed(entry, actor.get_time_left())
	if elapsed < 0.0:
		return {}
	var rel: Dictionary = CastVfx.release_entry(entry)
	var pack: VfxPack = CastVfx.pack_for(rel)
	if pack == null:
		return {}
	var clip: String = str(rel.get("clip", CastVfx.DEFAULT_CLIP))
	var data: Dictionary = pack.clip(clip)
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var frame: int = VfxPack.frame_at(data, elapsed, pack.frame_ms(), false)
	if not reduce and elapsed * 1000.0 >= float(int(data.get("frames", 0)) * pack.frame_ms()):
		return {}
	return {"release": str(rel["id"]), "pos": CastVfx.hand_point(entry, units.unit_feet_art(CombatState.Side.PLAYER)),
		"frame": 1 if reduce else frame, "clip": clip}


func _draw() -> void:
	_redraws += 1
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null:
		return
	_drawn = vfx_state()
	var vfx: FloorVfx = combat.get_floor_vfx()
	var geo: BoardGeometry = _bg()
	for item: Dictionary in _drawn:
		var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
		# The cell rect lets a centre-anchored pack (cell_slash) sit in the middle of its cell.
		var feet: Vector2i = FloorVfx.feet_for(cell_rect)
		# ADR-0002: the anchor follows the board map (BoardGeometry.warp_art_px); the pack's frames are never scaled, so
		# the cell rect handed to a centre-anchored pack is shifted with it rather than warped.
		var warped: Vector2i = geo.warp_art_px(feet)
		cell_rect.position += warped - feet
		feet = warped
		vfx.draw(self, str(item["id"]), feet, int(item["frame"]), Color.WHITE, cell_rect)
	var shot: Dictionary = projectile_state()
	if not shot.is_empty():
		_drawn.append(shot)
		if shot.has("projectile"):
			var pack: VfxPack = CastVfx.pack_for(CastVfx.pack_entry(str(shot["projectile"])))
			if pack != null:
				pack.draw_clip(self, str(shot["clip"]), shot["pos"], int(shot["frame"]))
	var cut: Dictionary = release_state()
	if not cut.is_empty():
		_drawn.append(cut)
		var cut_pack: VfxPack = CastVfx.pack_for(CastVfx.pack_entry(str(cut["release"])))
		if cut_pack != null:
			cut_pack.draw_clip(self, str(cut["clip"]), cut["pos"], int(cut["frame"]))
	_draw_shards(combat.get_cast_flood())
	_draw_travel(combat, travel_items())


## Task 5: the code-drawn travel, flash and impact squares to draw now: one {"rect": Rect2i, "col": Color, "fill": bool,
## "width": int, "edge": bool (1 px Ink edge under it)} each; [] when unbound or nothing runs. Both sides (item 4: the
## boss's casts in the enemy block colours `_enemy`, only on the cells it hits, locked cells skipped).
func travel_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null:
		return out
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var shot: Dictionary = projectile_state()
	if shot.has("streak"):
		# 2026-11-07: the streak takes the card's impact colours (ice pale blue), else the hero's block colours.
		_streak(out, shot["from"], shot["to"], float(shot["t"]), CastVfx.impact_colours(str(shot.get("impact", "")), hero_id))
	_side_items(out, combat, CombatState.Side.PLAYER, hero_id)
	_side_items(out, combat, CombatState.Side.ENEMY, ENEMY_BLOCK)
	return out


## The block colours key of the boss's casts (index.json block_colours `_enemy`, #CFC6B4 flat).
const ENEMY_BLOCK: String = "_enemy"
## Seconds the recorded cast stays drawn past its last arrival (covers the longest impact_style sec).
const TRAVEL_TAIL_SEC: float = 0.4


func _streak(out: Array[Dictionary], from: Vector2i, to: Vector2i, t: float, block: Array[Color]) -> void:
	var st: Dictionary = CastVfx.travel_style("square_streak")
	var rects: Array[Rect2i] = CastFloorFx.streak_rects(from, to, t, int(st.get("count", 4)), int(st.get("size", 5)), float(st.get("spacing", 6)))
	for i: int in rects.size():
		out.append(_sq(rects[i], block[1] if i == 0 else block[0]))


func _side_items(out: Array[Dictionary], combat: CombatView, side: int, caster_id: String) -> void:
	var tr: Dictionary = combat.cast_travel_now(TRAVEL_TAIL_SEC, side)
	if tr.is_empty():
		return
	var block: Array[Color] = CastVfx.block_colours(caster_id)
	var delivery: Dictionary = tr["delivery"]
	# 2026-11-07 (user: the Mage's falling fire was dark specks): the player's travel squares take the impact's own
	# colours when its style names them (burn orange, freeze pale blue); the boss keeps its flat enemy colour.
	var travel_cols: Array[Color] = CastVfx.impact_colours(str(delivery.get("impact", "")), caster_id) if side == CombatState.Side.PLAYER else block
	var rel: float = float(tr["rel"])
	var arrive: Dictionary = tr["arrive"]
	var shown: Array = tr["cells"]
	# The boss's straight shot from its hand to the first cell (the player's comes from projectile_state).
	if side != CombatState.Side.PLAYER and bool(tr.get("swinging", false)) and str(delivery.get("origin", "")) == "caster" and not shown.is_empty():
		var units: UnitLayer = combat.get_battle_canvas().get_unit_layer() if combat.get_battle_canvas() != null else null
		var entry: Dictionary = CastVfx.entry_for("")
		var t: float = CastVfx.flight_t(entry, -rel)
		if units != null and t >= 0.0:
			var hand: Array = entry.get("hand", [14, -34]) as Array
			# ADR-0002: travel squares are composed on the FLAT floor (drawn through the map in _draw_travel), so the
			# hand point (from the drawn feet) goes back to the flat floor first.
			var hand_at: Vector2i = units.unit_feet_art(side) + Vector2i(-int(hand[0]), int(hand[1]))
			var from: Vector2i = Vector2i(_bg().unwarp_art(Vector2(hand_at) + Vector2(0.5, 0.5)).floor())
			var first: Vector2i = SkillDelivery.first_link(delivery, shown, tr["caster"])
			_streak(out, from, _centre(first), t, block)
	match str(delivery.get("travel", "")):
		"falling_squares":
			var fs: Dictionary = CastVfx.travel_style("falling_squares")
			for c: Vector2i in shown:
				var rects: Array[Rect2i] = CastFloorFx.fall_rects(_floor.cell_art_rect(c), float(arrive.get(c, 0.0)) - rel,
					float(fs.get("drop_sec", 0.2)), int(fs.get("height", 70)), int(fs.get("count", 3)), int(fs.get("size", 4)), hash(c))
				for i: int in rects.size():
					out.append(_sq(rects[i], travel_cols[1] if i == 0 else travel_cols[0]))
		"chain_spark":
			var cs: Dictionary = CastVfx.travel_style("chain_spark")
			var links: Array = arrive.keys()
			links.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(arrive[a]) < float(arrive[b]))
			for k: int in range(links.size() - 1):
				var t0: float = float(arrive[links[k]])
				var t1: float = float(arrive[links[k + 1]])
				if rel >= t0 and rel < t1:
					var p: Vector2i = CastFloorFx.hop_point(_centre(links[k]), _centre(links[k + 1]), (rel - t0) / maxf(t1 - t0, 0.001), int(cs.get("lift", 12)))
					out.append(_sq(CastFloorFx.square_rect(p, int(cs.get("size", 4))), travel_cols[1]))
		"floor_run":
			var fr: Dictionary = CastVfx.travel_style("floor_run")
			var o: Vector2i = SkillDelivery.origin_cell(delivery, arrive.keys(), tr["caster"])
			for c: Vector2i in shown:
				var rects: Array[Rect2i] = CastFloorFx.run_rects(_centre(o), _centre(c), rel, float(arrive.get(c, 0.0)),
					int(fr.get("count", 3)), int(fr.get("size", 4)), float(fr.get("trail_sec", 0.025)))
				for i: int in rects.size():
					out.append(_sq(rects[i], travel_cols[1] if i == 0 else travel_cols[0]))
	if bool(tr.get("swinging", false)):
		return
	# The square impact flash on every reached (unlocked) cell, then (item 2) the impact's square shards on a hit.
	var sec: float = float(CastVfx.travel_style("flash").get("sec", 0.12))
	var impact: String = str(delivery.get("impact", ""))
	var style: Dictionary = CastVfx.impact_style(impact)
	var cols: Array[Color] = CastVfx.impact_colours(impact, caster_id)
	var dir: int = 1 if side == CombatState.Side.PLAYER else -1
	# 2026-11-02: when the hero's cast entry draws this cast's impacts with packs (CombatView._play_hero_wave), the code
	# flash and shards would draw a second impact on the same cells (in game the flash's white cell frame read as a UI
	# selection box over the burst): both are left out for that cast. Every other cast keeps them.
	var packs_own: bool = side == CombatState.Side.PLAYER and str(delivery.get("type", "")) == SkillDelivery.CASTER_TO_TARGET \
			and str(delivery.get("travel", "")) == "hero_pack" and CastVfx.packs_replace_shards(CastVfx.entry_for(caster_id, impact))
	# 2026-11-04: an impact drawn by its own FloorVfx pack (impact_packs: the Mage's fire) drops the code flash / shards too.
	if packs_own or (bool(tr.get("hit", false)) and CastVfx.impact_pack_owns_cells(impact)):
		return
	for c: Vector2i in shown:
		var age: float = rel - float(arrive.get(c, 0.0))
		for f: Dictionary in CastFloorFx.flash_rects(_floor.cell_art_rect(c), age, sec):
			out.append({"rect": f["rect"], "col": Color(block[1], 0.85) if bool(f["fill"]) else block[1], "fill": bool(f["fill"]),
				"width": int(f["width"]), "edge": false})
		if bool(tr.get("hit", false)) and not style.is_empty():
			for it: Dictionary in CastFloorFx.impact_rects(impact, _floor.cell_art_rect(c), age, float(style.get("sec", 0.24)), hash(c) + 11, dir):
				var r: Rect2i = it["rect"]
				out.append({"rect": r, "col": cols[1] if bool(it["light"]) else cols[0], "fill": true, "width": 0,
					"edge": mini(r.size.x, r.size.y) >= 3})


func _sq(r: Rect2i, col: Color) -> Dictionary:
	return {"rect": r, "col": col, "fill": true, "width": 0, "edge": true}


# The FLAT floor point of [param cell] the square travels run between (the cell's centre, whole px). ADR-0002: every
# travel / flash / impact rect is composed on the flat floor and drawn through the board map ([method _draw_travel]).
func _centre(cell: Vector2i) -> Vector2i:
	var r: Rect2i = _floor.cell_art_rect(cell)
	@warning_ignore("integer_division")
	return r.position + r.size / 2


## ADR-0002: the board geometry the overlay draws with (BoardGeometry.of the floor's CombatView; flat when unbound).
func _bg() -> BoardGeometry:
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	var geo: BoardGeometry = BoardGeometry.of(combat)
	if geo == null and combat != null:
		geo = BoardGeometry.make(combat.get_grid(), combat.get_viewport_rect().size)
	return geo


## ADR-0002: the drawn art polygon of a FLAT travel / flash / impact rect [param r] (the mapped quad; the rect's corners
## while flat). Tests compare it with the board's cell polygons.
func travel_polygon(r: Rect2i) -> PackedVector2Array:
	return _bg().art_quad(Rect2(r))


func _draw_travel(_combat: CombatView, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var geo: BoardGeometry = _bg()
	var warped: bool = geo != null and geo.is_warped()
	for it: Dictionary in items:
		if bool(it["edge"]):
			if warped:
				draw_colored_polygon(geo.art_quad(Rect2(it["rect"].grow(1))), SlabPainter.INK)
			else:
				draw_rect(Rect2(it["rect"].grow(1)), SlabPainter.INK)
	for it: Dictionary in items:
		var col: Color = it["col"]
		var r: Rect2i = it["rect"]
		if warped:
			if bool(it["fill"]):
				draw_colored_polygon(geo.art_quad(Rect2(r)), col)
			else:
				var w: float = float(it["width"])
				BoardGeometry.draw_polygon_outline(self, geo.art_quad(Rect2(r).grow(-w * 0.5)), col, w)
			continue
		if bool(it["fill"]):
			draw_rect(Rect2(r), col)
		else:
			var w: int = int(it["width"])
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, w), col)
			draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
			draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - w * 2), col)
			draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - w * 2), col)


# User 2026-11-01 (reference board): square tessera shards rise from every lit cell and fade with the flood.
func _draw_shards(flood: Dictionary) -> void:
	if flood.is_empty():
		return
	var geo: BoardGeometry = _bg()
	if geo == null:
		return
	var style: Dictionary = flood["style"]
	for item: Dictionary in flood["cells"]:
		var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
		var since: float = float(item["since"])
		var life: float = 1.0 - clampf(since / 0.5, 0.0, 1.0)
		# ADR-0002: the shards rise from the drawn cell: composed on the flat cell, each (tiny, pixel-art) square moved
		# whole onto the drawn floor (BoardGeometry.warp_art_px of its corner, like every VFX anchor; never scaled). A
		# mapped quad per shard cost ~25-60 ms a frame on a full flood, so it is not used here.
		var col := Color(style["edge"], float(item["fade"]) * (0.4 + 0.6 * life))
		for sq: Rect2i in CastVfx.shard_rects(item["cell"], cell_rect, since, int(style["squares"])):
			draw_rect(Rect2(Rect2i(geo.warp_art_px(sq.position), sq.size)), col, false, 1.0)

