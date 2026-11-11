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
	var sky: Array[Dictionary] = sky_items()
	if not sky.is_empty():
		state.append({"sky": sky})
	var fuse: Array[Dictionary] = fuse_items()
	if not fuse.is_empty():
		state.append({"fuse": fuse})

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
	var entry: Dictionary = CastVfx.entry_for(hero_id, str(delivery.get("impact", "")), actor.get_skill_id())
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
		# 2026-11-08: a card whose coil pose holds the hands elsewhere than its release point (Trảm Địa's cast_forward
		# raises the sword on the coil) charges at its `charge_hand` instead.
		var charge_at: Vector2i = from
		if entry.has("charge_hand"):
			charge_at = CastVfx.hand_point({"hand": entry["charge_hand"]}, units.unit_feet_art(CombatState.Side.PLAYER))
		return {"projectile": str(charge["id"]), "pos": charge_at, "frame": cframe, "clip": clip, "hero": hero_id, "charge": true}
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
		# Skill v2: the landing cell is the surge's (locked cells skipped), the cell CastResolver bursts on first.
		var open: Array = combat.unlocked_for_vfx(actor.get_cells())
		var first: Vector2i = SkillDelivery.first_link(delivery, open if not open.is_empty() else actor.get_cells(), combat.get_state().player_cell)
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
	var entry: Dictionary = CastVfx.entry_for(hero_id, str(combat.delivery_for(actor.get_skill_id()).get("impact", "")), actor.get_skill_id())
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
	# Skill v2 (Ngàn Kiếm): the sky blades stand up on screen over their tiles (unmapped). Per drop, back rows first: its
	# Ink edge (`edge` px, 2 on the finale), then its colours, so a nearer sword's edge cuts cleanly over the one behind.
	var sky: Array[Dictionary] = sky_items()
	var i: int = 0
	while i < sky.size():
		var j: int = i
		while j < sky.size() and int(sky[j].get("group", -1)) == int(sky[i].get("group", -1)):
			j += 1
		for n: int in range(i, j):
			var ink: Color = Color(SlabPainter.INK, float((sky[n]["col"] as Color).a))
			draw_rect(Rect2((sky[n]["rect"] as Rect2i).grow(int(sky[n].get("edge", 1)))), ink)
		for n: int in range(i, j):
			draw_rect(Rect2(sky[n]["rect"]), sky[n]["col"])
		i = j
	# Skill v2 Hỏa Lôi H2: the command glyph at the Mage's hand and the tile-origin flame columns (FuseFx), each
	# group's Ink edges first, back rows first.
	_draw_groups(fuse_items())
	# Skill v2 V3 / V1: the standing parts of the player's cast travel (DeliveryFx) and per-card impacts (ImpactFx),
	# rising from the tiles like the flame columns, back rows first.
	_draw_groups(delivery_standing_items())
	_draw_groups(impact_standing_items())


## Screen-space items [{rect, col, edge, group}] drawn group by group (back rows first): each group's Ink edges
## (`edge` px, 0 = none), then its colours, so a nearer group's edge cuts cleanly over the one behind.
func _draw_groups(list: Array[Dictionary]) -> void:
	var a: int = 0
	while a < list.size():
		var b: int = a
		while b < list.size() and int(list[b].get("group", -1)) == int(list[a].get("group", -1)):
			b += 1
		for n: int in range(a, b):
			var e: int = int(list[n].get("edge", 0))
			if e > 0:
				draw_rect(Rect2((list[n]["rect"] as Rect2i).grow(e)), Color(SlabPainter.INK, float((list[n]["col"] as Color).a)))
		for n: int in range(a, b):
			draw_rect(Rect2(list[n]["rect"]), list[n]["col"])
		a = b


## Skill v2 V1 (ImpactFx): the STANDING items of the player's resolved cast on every hit cell: screen art px over
## the tile's drawn ground centre (unmapped, like fuse_items), [{rect, col, edge, group}] with group = draw index
## (back rows first). [] while nothing stands: no recorded hit, a card without an `impact_variants` form, or a cast
## whose impacts a pack owns (the same rule as the flat path in _side_items).
func impact_standing_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null:
		return out
	var recs: Array[Dictionary] = []
	var tr0: Dictionary = combat.cast_travel_now(TRAVEL_TAIL_SEC, CombatState.Side.PLAYER)
	if not tr0.is_empty():
		recs.append(tr0)
	recs.append_array(combat.event_impacts_now(TRAVEL_TAIL_SEC))
	var group_base: int = 0
	for tr: Dictionary in recs:
		var part: Array[Dictionary] = _record_standing_items(combat, tr, group_base)
		out.append_array(part)
		group_base += 64
	return out


## The standing impact items of one recorded cast [param tr]; groups start at [param group_base].
func _record_standing_items(combat: CombatView, tr: Dictionary, group_base: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tr.is_empty() or bool(tr.get("swinging", false)):
		return out
	var variant: Dictionary = CastVfx.impact_variant(str(tr.get("skill_id", "")))
	var form: String = ImpactFx.form_of(variant)
	# `always`: the form plays on every reached cell, hit or not (Thiên Quang's pillars fall on each cell)
	if form.is_empty() or not (bool(tr.get("hit", false)) or bool(variant.get("always", false))):
		return out
	var delivery: Dictionary = tr["delivery"]
	var impact: String = str(delivery.get("impact", ""))
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	# a signature form stands even over a pack-owned impact (the form was checked non-empty above)
	var style: Dictionary = CastVfx.impact_style(impact)
	var sec: float = float(variant.get("sec", style.get("sec", 0.24)))
	var cols: Array[Color] = variant_colours(variant, CastVfx.impact_colours(impact, hero_id))
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var geo: BoardGeometry = _bg()
	var cells: Array = tr["cells"].duplicate()
	cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y < q.y or (p.y == q.y and p.x < q.x))
	var arrive: Dictionary = tr["arrive"]
	var first_at: float = _first_arrival(arrive)
	var ring_form: String = str(variant.get("ring_form", ""))
	# `hub_only`: the standing part plays on ONE cell, the one nearest the mask's centre (Lốc Cuốn's funnel)
	var hub: Vector2i = _hub_cell(cells) if bool(variant.get("hub_only", false)) else Vector2i(-9999, -9999)
	for g: int in cells.size():
		var c: Vector2i = cells[g]
		if hub.x != -9999 and c != hub:
			continue
		var age: float = float(tr["rel"]) - float(arrive.get(c, 0.0))
		var base: Vector2i = _centre(c)
		if geo != null and geo.is_warped():
			base = geo.warp_art_px(base)
		var w: int = _floor.cell_art_rect(c).size.x
		var cell_form: String = form
		if not ring_form.is_empty() and ImpactFx.FORMS.has(ring_form) and float(arrive.get(c, 0.0)) > first_at + 0.001:
			cell_form = ring_form
		for it: Dictionary in ImpactFx.standing_items(cell_form, base, w, age, sec, hash(c) + 11, 1, variant, reduce):
			var r: Rect2i = it["rect"]
			out.append({"rect": r, "col": tone_colour(it, cols), "edge": 1 if mini(r.size.x, r.size.y) >= 3 else 0, "group": group_base + g})
	return out



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
	# batch 4 (Móc Kéo): the pull path chevrons march toward the divider (the enemy half's left edge)
	var pull: Dictionary = combat.pull_telegraph_now()
	if not pull.is_empty():
		var rects: Array[Rect2i] = []
		for c: Vector2i in pull["cells"] as Array:
			rects.append(_floor.cell_art_rect(c))
		var pull_cols: Array[Color] = variant_colours(CastVfx.impact_variant("moc_keo"), CastVfx.block_colours(hero_id))
		for it: Dictionary in DeliveryFx.pull_path_floor(rects, -1, float(pull["t"])):
			out.append(_sq(it["rect"], tone_colour(it, pull_cols)))
	_surge_items(out, combat, hero_id)
	_sky_shadow_items(out, combat)
	_front_items(out, combat, hero_id)
	_preview_items(out, combat, hero_id)
	return out


# Skill v2 (Ngàn Kiếm, SkyDropFx): the tile-exact floor shadow of every pending drop, darker as its strike nears.
func _sky_shadow_items(out: Array[Dictionary], combat: CombatView) -> void:
	var now: float = combat.combat_clock()
	for d: Dictionary in combat.get_sky_drops():
		var a: float = SkyDropFx.shadow_alpha(d, now)
		if a <= 0.0:
			continue
		out.append({"rect": SkyDropFx.shadow_rect(_floor.cell_art_rect(d["cell"])), "col": Color(SlabPainter.INK, a),
			"fill": true, "width": 0, "edge": false})


## Skill v2 (Ngàn Kiếm, SkyDropFx): the screen-space sky items [{rect, col, edge, group}]: the summoning squares at the
## Knight's hand while a SKY_TO_TARGET swing winds up (group -1), then every drop's blade / impact / shatter over its
## tile's drawn ground centre (group = its draw index, back rows first). A blade hovering over the enemy is see-through
## (SkyDropFx.blade_alpha). Drawn unmapped (vertical on screen), each group's Ink edge first.
func sky_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null:
		return out
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var geo: BoardGeometry = _bg()
	var actor: CutActor = combat.get_cut_actor()
	if actor != null and actor.is_swinging() and combat.get_battle_canvas() != null \
			and str(combat.delivery_for(actor.get_skill_id()).get("type", "")) == SkillDelivery.SKY_TO_TARGET:
		var units: UnitLayer = combat.get_battle_canvas().get_unit_layer()
		var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
		var entry: Dictionary = CastVfx.entry_for(hero_id, "", actor.get_skill_id())
		if units != null and not entry.is_empty():
			# 2026-11-08: on the card's own coil pose (a card whose coil pose holds the sword up), the squares
			# gather at its `charge_hand` (the raised blade); else at the release hand.
			var hand: Vector2i = CastVfx.hand_point({"hand": entry.get("charge_hand", entry.get("hand", [0, 0]))},
				units.unit_feet_art(CombatState.Side.PLAYER))
			var k: float = 1.0 - actor.get_time_left() / maxf(actor.get_duration(), 0.001)
			var cols: Array[Color] = SkyDropFx.tone_colours(false)
			# an on-tile summon card (`summon_fx`) shows nothing at the hand: its swords form on the target tiles
			if not bool(entry.get("summon_fx", false)):
				for it: Dictionary in SkyDropFx.summon_items(hand, k, 5, reduce):
					out.append({"rect": it["rect"], "col": cols[int(it["tone"])]})
	var now: float = combat.combat_clock()
	# Back rows first, so a nearer (lower) sword overlaps the one behind it (VFX scale guide: layering).
	var drops: Array[Dictionary] = combat.get_sky_drops()
	drops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["cell"] as Vector2i).y < (b["cell"] as Vector2i).y)
	var state: CombatState = combat.get_state()
	for g: int in drops.size():
		var d: Dictionary = drops[g]
		var base: Vector2i = _centre(d["cell"])
		if geo != null and geo.is_warped():
			base = geo.warp_art_px(base)
		var cols2: Array[Color] = SkyDropFx.tone_colours(bool(d.get("final", false)))
		var a: float = SkyDropFx.blade_alpha(d, now, state != null and state.is_enemy_at(d["cell"]))
		for it: Dictionary in SkyDropFx.items(d, now, base, reduce):
			out.append({"rect": it["rect"], "col": Color(cols2[int(it["tone"])], a), "edge": int(it.get("edge", 1)), "group": g})
	return out


## Skill v2 Hỏa Lôi H2 (FuseFx): the screen-space items [{rect, col, edge, group}]: the command glyph at the Mage's
## hand while a `glyph` card's swing runs (group -1), then each armed cell's flame column over its tile's drawn ground
## centre once the field blows (group = draw index, back rows first). Same records and clock as the gameplay events.
func fuse_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null or combat.get_arbiter() == null:
		return out
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var actor: CutActor = combat.get_cut_actor()
	if actor != null and actor.is_swinging() and combat.get_battle_canvas() != null:
		var units: UnitLayer = combat.get_battle_canvas().get_unit_layer()
		var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
		var entry: Dictionary = CastVfx.entry_for(hero_id, "", actor.get_skill_id())
		var k: float = 1.0 - actor.get_time_left() / maxf(actor.get_duration(), 0.001)
		if units != null and bool(entry.get("glyph", false)):
			var hand: Vector2i = CastVfx.hand_point({"hand": entry.get("charge_hand", entry.get("hand", [0, 0]))},
				units.unit_feet_art(CombatState.Side.PLAYER))
			for it: Dictionary in FuseFx.glyph_items(hand, k, reduce):
				it["group"] = -1
				out.append(it)
		elif units != null and CastVfx.card_clip(actor.get_skill_id()).is_empty():
			# Skill v2 V2: every other cast speaks its hero's glyph (index cast_glyphs) at the hold frame's hand.
			var kit: Dictionary = CastVfx.cast_glyph(hero_id)
			if not kit.is_empty():
				var ghand: Vector2i = CastVfx.hand_point({"hand": kit.get("hand", entry.get("hand", [0, 0]))},
					units.unit_feet_art(CombatState.Side.PLAYER))
				for it: Dictionary in CastGlyphFx.items(str(kit["form"]), ghand, k, CastVfx.block_colours(hero_id), reduce):
					it["group"] = -1
					out.append(it)
	var recs: Array[Dictionary] = combat.get_fuse_fx().duplicate()
	recs.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return (p["cell"] as Vector2i).y < (q["cell"] as Vector2i).y)
	var now: float = combat.combat_clock()
	var geo: BoardGeometry = _bg()
	for g: int in recs.size():
		var rec: Dictionary = recs[g]
		var base: Vector2i = _centre(rec["cell"])
		if geo != null and geo.is_warped():
			base = geo.warp_art_px(base)
		var w: int = _floor.cell_art_rect(rec["cell"]).size.x
		for it: Dictionary in FuseFx.eruption_items(rec, now, base, w, reduce):
			it["group"] = g
			out.append(it)
	return out


## Skill v2 (Trảm Địa): incoming front squares, eruption timing and the preview colours.
const SURGE_FRONT_COUNT: int = 4
const SURGE_FRONT_SIZE: int = 5
const SURGE_ERUPT_SEC: float = 0.5
const SURGE_PREVIEW_ALPHA: float = 0.85
const SURGE_BLOCKED_ALPHA: float = 0.6


# Skill v2 (Trảm Địa): the steel front travelling into each next surge cell (on the arbiter clock).
func _front_items(out: Array[Dictionary], combat: CombatView, hero_id: String) -> void:
	var cols: Array[Color] = CastVfx.block_colours(hero_id)
	for fr: Dictionary in combat.get_surge_fronts():
		var rects: Array[Rect2i] = CastFloorFx.front_rects(_centre(fr["from"]), _centre(fr["to"]), float(fr["f"]),
			SURGE_FRONT_COUNT, SURGE_FRONT_SIZE)
		for i: int in rects.size():
			out.append(_sq(rects[i], cols[1] if i == 0 else cols[0]))


# Skill v2 (Trảm Địa): the subtle tile-exact preview of the surge while the card menu offers it (landing corners,
# step chevrons pointing the propagation direction, a dim X on cells a lock cuts off). Steel, never red.
func _preview_items(out: Array[Dictionary], combat: CombatView, hero_id: String) -> void:
	var pv: Dictionary = combat.get_surge_preview()
	if pv.is_empty():
		return
	var cols: Array[Color] = CastVfx.block_colours(hero_id)
	var lit := Color(cols[1], SURGE_PREVIEW_ALPHA)
	var dim := Color(cols[0], SURGE_PREVIEW_ALPHA)
	for e: Dictionary in pv["events"] as Array:
		var cell: Vector2i = (e["cells"] as Array)[0]
		var from: Vector2i = e.get("from", CastResolver.NO_CELL)
		var kind: String = str(e["kind"])
		var src: Vector2i = _centre(from) if from != CastResolver.NO_CELL else _centre(cell)
		for r: Rect2i in CastFloorFx.preview_rects(_floor.cell_art_rect(cell), kind, src):
			out.append({"rect": r, "col": lit if kind != CastResolver.KIND_SURGE else dim, "fill": true, "width": 0, "edge": true})
	for b: Variant in pv["blocked"] as Array:
		for r: Rect2i in CastFloorFx.preview_rects(_floor.cell_art_rect(b as Vector2i), "blocked", Vector2i.ZERO):
			out.append({"rect": r, "col": Color(cols[0], SURGE_BLOCKED_ALPHA), "fill": true, "width": 0, "edge": false})


## Skill v2 (Trảm Địa primary impact): the screen-space eruption items [{rect, col}] (drawn unmapped, vertical on
## screen, anchored on the burst tile's drawn centre); [] when none runs.
func eruption_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null:
		return out
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var cols: Array[Color] = CastVfx.block_colours(hero_id)
	var geo: BoardGeometry = _bg()
	for r: Dictionary in combat.get_surge_fx():
		if str(r["kind"]) != CastResolver.KIND_BURST:
			continue
		var cell: Vector2i = r["cell"]
		var flat: Rect2i = _floor.cell_art_rect(cell)
		var base: Vector2i = _centre(cell)
		var w: int = flat.size.x
		if geo != null and geo.is_warped():
			base = geo.warp_art_px(base)
		for it: Dictionary in CastFloorFx.eruption_rects(base, w, float(r["age"]), SURGE_ERUPT_SEC, hash(cell)):
			out.append({"rect": it["rect"], "col": tone_colour(it, cols)})
	return out


## Skill v2 (Trảm Địa): crack line, reveal time and shockwave numbers (art px / seconds).
const SURGE_CRACK_REVEAL_SEC: float = 0.08
const SURGE_CRACK_SIZE: int = 3
const SURGE_CRACK_GAP: int = 3
const SURGE_SHOCK_SEC: float = 0.3
const SURGE_SHOCK_COUNT: int = 16
const SURGE_SHOCK_SIZE: int = 6
## The burst's second, inner shock ring starts this much later (the heavier first impact).
const SURGE_SHOCK_ECHO_SEC: float = 0.08


# Skill v2 (Trảm Địa, 02-vfx-concepts.md §8.1): per fired surge event, the steel crack from the cell the surge came from
# and, on the burst / a landing, the ground shockwave squares; in the caster's block colours (steel), never red.
func _surge_items(out: Array[Dictionary], combat: CombatView, hero_id: String) -> void:
	var fx: Array[Dictionary] = combat.get_surge_fx()
	if fx.is_empty():
		return
	var cols: Array[Color] = CastVfx.block_colours(hero_id)
	for r: Dictionary in fx:
		var cell: Vector2i = r["cell"]
		var from: Vector2i = r["from"]
		var age: float = float(r["age"])
		if from != CastResolver.NO_CELL:
			var rects: Array[Rect2i] = CastFloorFx.crack_rects(_centre(from), _centre(cell), age, SURGE_CRACK_REVEAL_SEC,
				CombatView.SURGE_FX_SEC, SURGE_CRACK_SIZE, SURGE_CRACK_GAP, hash(cell))
			for i: int in rects.size():
				out.append(_sq(rects[i], cols[1] if i % 2 == 0 else cols[0]))
		var kind: String = str(r["kind"])
		# 2026-11-08: the burst's ring now comes from mark_eruption_tram_dia (one shockwave, not two); a landing keeps it.
		if kind == CastResolver.KIND_LANDING:
			var w: int = _floor.cell_art_rect(cell).size.x
			var big: bool = kind == CastResolver.KIND_BURST
			var rects2: Array[Rect2i] = CastFloorFx.shock_rects(_centre(cell), age, SURGE_SHOCK_SEC,
				int(w * (1.0 if big else 0.5)), SURGE_SHOCK_COUNT if big else SURGE_SHOCK_COUNT / 2, SURGE_SHOCK_SIZE if big else 3)
			if big:
				rects2.append_array(CastFloorFx.shock_rects(_centre(cell), age - SURGE_SHOCK_ECHO_SEC, SURGE_SHOCK_SEC,
					int(w * 0.6), SURGE_SHOCK_COUNT / 2, SURGE_SHOCK_SIZE - 2))
			for i: int in rects2.size():
				out.append(_sq(rects2[i], cols[1] if i % 3 == 0 else cols[0]))


## The block colours key of the boss's casts (index.json block_colours `_enemy`, #CFC6B4 flat).
const ENEMY_BLOCK: String = "_enemy"
## Seconds the recorded cast stays drawn past its last arrival (covers the longest impact_style sec).
const TRAVEL_TAIL_SEC: float = 1.6


## V4 feel pass: the colour of a toned item (ImpactFx / DeliveryFx `tone`: 0 dark, 1 body, 2 highlight, 3 core) from
## [param cols] = [body, highlight]; an item without a tone falls back to its `light` flag.
static func tone_colour(it: Dictionary, cols: Array[Color]) -> Color:
	match int(it.get("tone", 2 if bool(it.get("light", false)) else 1)):
		0:
			return cols[0].darkened(0.38)
		1:
			return cols[0]
		2:
			return cols[1]
		_:
			return Color("F8FBFF")


func _streak(out: Array[Dictionary], from: Vector2i, to: Vector2i, t: float, block: Array[Color]) -> void:
	# Skill v2 V3: the boss's straight shot as a DeliveryFx streak (head, tail, sparks).
	for it: Dictionary in DeliveryFx.streak(from, to, t):
		out.append(_sq(it["rect"], block[1] if bool(it["light"]) else block[0]))


## Skill v2 V3 (DeliveryFx): the STANDING part of the player's cast travel: the falling block of a sky delivery, the
## hopping bolt of a chain, the dust behind a ground ripple, the drop-in of an in-place card — screen art px over the
## tiles' drawn ground points, [{rect, col, edge, group}] (group = draw index, back rows first). [] when no cast
## travels or its hero pack draws the travel itself.
func delivery_standing_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = FloorDynamicLayer.combat_of(_floor)
	if combat == null or _floor == null:
		return out
	var tr: Dictionary = combat.cast_travel_now(TRAVEL_TAIL_SEC, CombatState.Side.PLAYER)
	if tr.is_empty():
		return out
	var delivery: Dictionary = tr["delivery"]
	var travel: String = str(delivery.get("travel", ""))
	if travel == "hero_pack" or travel == "square_streak":
		return out
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var variant: Dictionary = CastVfx.impact_variant(str(tr.get("skill_id", "")))
	var cols: Array[Color] = variant_colours(variant, CastVfx.impact_colours(str(delivery.get("impact", "")), hero_id))
	var rel: float = float(tr["rel"])
	var arrive: Dictionary = tr["arrive"]
	var geo: BoardGeometry = _bg()
	var cells: Array = tr["cells"].duplicate()
	cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y < q.y or (p.y == q.y and p.x < q.x))
	var timing: Dictionary = combat.delivery_timing()
	var items: Array[Dictionary] = []
	match travel:
		"falling_squares":
			var fall: float = float((timing.get(SkillDelivery.SKY_TO_TARGET, {}) as Dictionary).get("fall_sec", 0.12))
			var first_at: float = _first_arrival(arrive)
			var meteor: bool = bool(variant.get("meteor", false))
			for g: int in cells.size():
				var c: Vector2i = cells[g]
				var until: float = float(arrive.get(c, 0.0)) - rel
				var w: int = _floor.cell_art_rect(c).size.x
				# Thiên Thạch: the first-arrival cell takes the meteor, streaking in over the whole hover
				var sky: Array[Dictionary] = DeliveryFx.meteor_standing(_ground_of(c, geo), w, until, maxf(float(arrive.get(c, 0.0)), fall), hash(c)) \
					if meteor and float(arrive.get(c, 0.0)) <= first_at + 0.001 else DeliveryFx.sky_standing(_ground_of(c, geo), w, until, fall, hash(c))
				for it: Dictionary in sky:
					it["group"] = g
					items.append(it)
		"chain_spark":
			var links: Array = arrive.keys()
			links.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(arrive[a]) < float(arrive[b]))
			for k: int in range(links.size() - 1):
				var t0: float = float(arrive[links[k]])
				var t1: float = float(arrive[links[k + 1]])
				if rel >= t0 and rel < t1:
					for it: Dictionary in DeliveryFx.chain_standing(_ground_of(links[k], geo), _ground_of(links[k + 1], geo),
							_floor.cell_art_rect(links[k + 1]).size.x, (rel - t0) / maxf(t1 - t0, 0.001)):
						it["group"] = k
						items.append(it)
		"floor_run":
			var o: Vector2i = SkillDelivery.origin_cell(delivery, arrive.keys(), tr["caster"])
			var ob: Vector2i = _ground_of(o, geo)
			for g: int in cells.size():
				var c: Vector2i = cells[g]
				var at: float = float(arrive.get(c, 0.0))
				if at <= 0.0 or rel < 0.0 or rel > at:
					continue
				var cb: Vector2i = _ground_of(c, geo)
				var front: Vector2i = Vector2i(Vector2(ob).lerp(Vector2(cb), rel / at).round())
				var back: Vector2 = Vector2(ob - cb).normalized() if ob != cb else Vector2(-1, 0)
				for it: Dictionary in DeliveryFx.ground_dust(front, back, _floor.cell_art_rect(c).size.x, rel / at, hash(c)):
					it["group"] = g
					items.append(it)
		"none":
			for g: int in cells.size():
				var c: Vector2i = cells[g]
				for it: Dictionary in DeliveryFx.gather_standing(_ground_of(c, geo), _floor.cell_art_rect(c).size.x, float(arrive.get(c, 0.0)) - rel):
					it["group"] = g
					items.append(it)
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		out.append({"rect": r, "col": tone_colour(it, cols), "edge": 1 if mini(r.size.x, r.size.y) >= 3 else 0, "group": int(it["group"])})
	return out


## Signature knob `colours` ([body, highlight] hex) of an impact variant, else [param fallback].
static func variant_colours(variant: Dictionary, fallback: Array[Color]) -> Array[Color]:
	var v: Variant = variant.get("colours", null)
	if v is Array and (v as Array).size() >= 2:
		return [Color(str(v[0])), Color(str(v[1]))]
	return fallback


## The cell of [param cells] nearest their centroid (ties: the first in the list).
static func _hub_cell(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-9999, -9999)
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	var centre: Vector2 = sum / float(cells.size())
	var best: Vector2i = cells[0]
	var best_d: float = INF
	for c: Vector2i in cells:
		var d: float = Vector2(c).distance_squared_to(centre)
		if d < best_d:
			best_d = d
			best = c
	return best


## The earliest arrival time of a cast's cells (INF for none).
static func _first_arrival(arrive: Dictionary) -> float:
	var first: float = INF
	for c: Vector2i in arrive:
		first = minf(first, float(arrive[c]))
	return first


## The drawn (warped) ground centre of [param cell], screen art px.
func _ground_of(cell: Vector2i, geo: BoardGeometry) -> Vector2i:
	var base: Vector2i = _centre(cell)
	if geo != null and geo.is_warped():
		base = geo.warp_art_px(base)
	return base


func _side_items(out: Array[Dictionary], combat: CombatView, side: int, caster_id: String) -> void:
	var tr: Dictionary = combat.cast_travel_now(TRAVEL_TAIL_SEC, side)
	if not tr.is_empty():
		_record_items(out, combat, side, caster_id, tr)
	# Skill v2 V1: the player's scheduled casts come event by event (CombatView.event_impacts_now)
	if side == CombatState.Side.PLAYER:
		for rec: Dictionary in combat.event_impacts_now(TRAVEL_TAIL_SEC):
			_record_items(out, combat, side, caster_id, rec)


## The flat items of one recorded cast [param tr] (a cast_travel_now record or an event record): its travel, the
## impact flash and the impact / aftermath on its cells.
func _record_items(out: Array[Dictionary], combat: CombatView, side: int, caster_id: String, tr: Dictionary) -> void:
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
	# Skill v2 V3 (DeliveryFx): the flat part of the travel; the standing part is delivery_standing_items().
	match str(delivery.get("travel", "")):
		"falling_squares":
			for c: Vector2i in shown:
				for it: Dictionary in DeliveryFx.sky_floor(_floor.cell_art_rect(c), float(arrive.get(c, 0.0)) - rel):
					out.append(_sq(it["rect"], tone_colour(it, travel_cols)))
		"chain_spark":
			pass  # the hopping bolt stands up on screen (delivery_standing_items)
		"floor_run":
			var o: Vector2i = SkillDelivery.origin_cell(delivery, arrive.keys(), tr["caster"])
			for c: Vector2i in shown:
				for it: Dictionary in DeliveryFx.ground_floor(_centre(o), _centre(c), rel, float(arrive.get(c, 0.0))):
					out.append(_sq(it["rect"], tone_colour(it, travel_cols)))
		"none":
			for c: Vector2i in shown:
				for it: Dictionary in DeliveryFx.gather_floor(_floor.cell_art_rect(c), float(arrive.get(c, 0.0)) - rel):
					out.append(_sq(it["rect"], tone_colour(it, travel_cols)))
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
	# Skill v2 V1: the player's card may name its own ImpactFx form (index impact_variants); the shared shards otherwise.
	var variant: Dictionary = CastVfx.impact_variant(str(tr.get("skill_id", ""))) if side == CombatState.Side.PLAYER else {}
	var form: String = ImpactFx.form_of(variant)
	# a pack that owns the cells (the steel burst, the burn flames) replaces the shared flash / shards, but a card's
	# own signature form still plays over it (Hỏa Băng's steam over the fire)
	if (packs_own or (bool(tr.get("hit", false)) and CastVfx.impact_pack_owns_cells(impact))) and form.is_empty():
		return
	var owned: bool = packs_own or CastVfx.impact_pack_owns_cells(impact)
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	# signature knobs: the variant's own colours, and a second form for the cells that are not the first arrival
	cols = variant_colours(variant, cols)
	var first_at: float = _first_arrival(arrive)
	var ring_form: String = str(variant.get("ring_form", ""))
	for c: Vector2i in shown:
		var age: float = rel - float(arrive.get(c, 0.0))
		var cell_form: String = form
		if not ring_form.is_empty() and ImpactFx.FORMS.has(ring_form) and float(arrive.get(c, 0.0)) > first_at + 0.001:
			cell_form = ring_form
		if not owned:
			for f: Dictionary in CastFloorFx.flash_rects(_floor.cell_art_rect(c), age, sec):
				out.append({"rect": f["rect"], "col": Color(block[1], 0.85) if bool(f["fill"]) else block[1], "fill": bool(f["fill"]),
					"width": int(f["width"]), "edge": false})
		# `always`: a signature form that plays on every reached cell, hit or not (Thiên Quang's pillars)
		if (bool(tr.get("hit", false)) or (not form.is_empty() and bool(variant.get("always", false)))) and not style.is_empty():
			# a variant's own `sec` (0.5 s) outlasts the type's; the recorded cast is kept past its last arrival for it
			var impact_sec: float = float(variant.get("sec", style.get("sec", 0.24)))
			var items: Array[Dictionary] = ImpactFx.items(cell_form, _floor.cell_art_rect(c), age, impact_sec, hash(c) + 11, dir, variant, reduce) \
				if not form.is_empty() else CastFloorFx.impact_rects(impact, _floor.cell_art_rect(c), age, impact_sec, hash(c) + 11, dir)
			# V4 feel pass: what the hit leaves on the cell after its clip (ImpactFx.aftermath_items, `after_sec`)
			if not form.is_empty() and age >= impact_sec:
				items = ImpactFx.aftermath_items(cell_form, _floor.cell_art_rect(c), age - impact_sec, float(variant.get("after_sec", 0.0)), hash(c) + 11, variant)
			for it: Dictionary in items:
				var r: Rect2i = it["rect"]
				out.append({"rect": r, "col": tone_colour(it, cols), "fill": true, "width": 0,
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

