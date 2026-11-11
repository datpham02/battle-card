class_name FloorDynamicLayer
extends Node2D
const _ZoneFx = preload("res://src/art/zone_fx.gd")
## The cheap dynamic part of the floor (Story 046 Part C, art bible 8.6): a child of FloorLayer, so it draws right
## after the static slabs and still before UnitLayer. It paints the Story 048 floor VFX (FloorVfx, layer "floor"),
## then the burning cells' time bars (BurnPainter), then the boss's telegraph (TelegraphPainter, so the red telegraph
## stays on top), then the FloorLayer.add_painter hooks. The static floor never redraws per frame; this layer redraws
## only when what it shows changed: when a VFX frame / tint changes, every frame while a cell burns (its time bar
## shrinks) or a boss swing runs, once more when the last of them ends (to clear it), and whenever
## FloorLayer.mark_dirty runs. Time frozen (pause, Focus, demos) = the state does not change = no redraw.
## Floor VFX drawn here (Story 048 Part B): F2 engraving_lit (lit formation cells, alpha = the old fade / warn blink),
## F4 cracked_cell (slam cracks, held), F1 burning_cell (burning cells), F5 cast_target (the player's swing cells,
## hero block tint), then the floor one-shots F3 engraving_complete, F7 miss_dust, F9 thorn_spikes.
## Implements: Story 046 Part C, Story 048 Part B.

## Kiếm sĩ's block colour (art bible): characters carry no block colour in data yet, so the cast target uses it.
const HERO_BLOCK_TINT: Color = Color("8fa3b8")
## The lit engraving's alpha is rounded to this many steps so a slow fade does not redraw every frame.
const ALPHA_STEPS: float = 16.0

var _floor: FloorLayer = null
## The telegraph state drawn last ({} = none); compared by value each frame.
var _drawn: Dictionary = {}
## The burn state drawn last ([] = none); compared by value each frame.
var _drawn_burn: Array[Dictionary] = []
## The floor VFX items drawn last ([] = none); compared by value each frame.
var _drawn_vfx: Array[Dictionary] = []
## The drop tiles drawn last ([] = none); compared by value each frame.
var _drawn_holes: Array[Dictionary] = []
## The charging target cells drawn last ([] = none); compared by value each frame.
var _drawn_charge: Array[Dictionary] = []
## P2.3: the pattern markers / ivory outlines drawn last ({} = none); compared by value each frame.
var _drawn_extras: Dictionary = {}
## Skill v2 Hỏa Lôi H2: the fire-seal floor items drawn last ({} = none): {"under": blast items, "over": sigils}.
var _drawn_fuse: Dictionary = {}
## Batch-3 field marks drawn last (trap jaws, ward frame, pillar stone).
var _drawn_zone: Array[Dictionary] = []
var _redraws: int = 0


## Binds the layer to its FloorLayer (FloorLayer does this when it creates the child).
func setup(floor: FloorLayer) -> void:
	_floor = floor


## Number of times `_draw` ran (tests: per frame only while a burn or a boss swing changes, once when it ends).
func get_redraw_count() -> int:
	return _redraws


## The CombatView bound to [param floor] (FloorLayer exposes no getter; its `_combat` is read directly), or null.
static func combat_of(floor: FloorLayer) -> CombatView:
	if floor == null:
		return null
	var combat: Variant = floor._combat
	if combat == null or not is_instance_valid(combat):
		return null
	return combat as CombatView


## Pure-ish: the lit engraving's alpha for a cell with [param fraction] of its time left: the old CutHudView fade
## (faint .. 1), a flat blink between two low values under [param warn] on the effects clock [param clock].
static func formation_alpha(fraction: float, warn: float, clock: float) -> float:
	var strength: float = lerpf(CutHudView.FORMATION_FAINT, 1.0, clampf(fraction, 0.0, 1.0))
	if fraction < warn:
		var blink_on: bool = fmod(clock * CutHudView.FORMATION_BLINK_HZ, 1.0) < 0.5
		strength = CutHudView.FORMATION_WARN_HIGH if blink_on else CutHudView.FORMATION_WARN_LOW
	return roundf(strength * ALPHA_STEPS) / ALPHA_STEPS


## The burning cells to draw now (BurnPainter.state_for on the battle's StatusEffects, measured against the burn
## skill's `burn_duration_sec`); [] when unbound or nothing burns.
func burn_state() -> Array[Dictionary]:
	var combat: CombatView = combat_of(_floor)
	if combat == null:
		return [] as Array[Dictionary]
	var duration: float = 0.0
	var skills: SkillConfig = combat.get_skill_config()
	if skills != null:
		duration = float(skills.get_skill(BurnPainter.BURN_SKILL_ID).get("burn_duration_sec", 0.0))
	return BurnPainter.state_for(combat.get_status(), duration)


## The floor VFX to draw now, in draw order: one `{id, cell, frame, tint}` per effect and cell; [] when unbound or
## nothing shows. An effect whose pack is unavailable is left out (CutHudView / BurnPainter keep the old drawing).
func vfx_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = combat_of(_floor)
	if combat == null or combat.get_grid() == null:
		return out
	var vfx: FloorVfx = combat.get_floor_vfx()
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var clock: float = vfx.elapsed()
	# F2: lit formation cells.
	var formation: FormationMap = combat.get_formation()
	if formation != null and vfx.has_pack("engraving_lit"):
		var warn: float = combat.get_config().formation_fade_warn_ratio
		var frame: int = FloorVfx.frame_for(vfx.entry("engraving_lit"), clock, reduce)
		for cell: Vector2i in formation.lit_cells():
			var alpha: float = formation_alpha(formation.fraction_left(cell), warn, clock)
			out.append(_item("engraving_lit", cell, frame, Color(1.0, 1.0, 1.0, alpha)))
	# F4: cracked cells (slam), each held on hold_frame from the moment it cracked.
	var cracked: Array[Vector2i] = []
	var host: TraitHost = combat.get_trait_host()
	var slam: SlamTrait = null if host == null else host.get_trait(SlamTrait.ID) as SlamTrait
	if slam != null and vfx.has_pack("cracked_cell"):
		cracked = slam.get_cracked_cells()
	var ages: Dictionary = vfx.hold_ages("cracked_cell", cracked)
	for cell: Vector2i in cracked:
		out.append(_item("cracked_cell", cell, FloorVfx.frame_for(vfx.entry("cracked_cell"), float(ages[cell]), reduce)))
	# F1: burning cells.
	if vfx.has_pack("burning_cell"):
		var frame: int = FloorVfx.frame_for(vfx.entry("burning_cell"), clock, reduce)
		for entry: Dictionary in burn_state():
			out.append(_item("burning_cell", entry["cell"], frame))
	# F5 (cast_target pack) is replaced by the code-drawn charge (ADR-0001 Task 5: charge_state / _draw_charge).
	# F10 (playtest 2026-11-01): the foot-lock seal under the enemy while its own swing roots it (replaces the ring).
	if combat.is_boss_step_locked() and not combat.get_state().is_enemy_dead() and vfx.has_pack("root_seal"):
		var frame: int = FloorVfx.frame_for(vfx.entry("root_seal"), clock, reduce)
		# P2.2b: one seal under every footprint cell of a multi-cell enemy.
		for seal_cell: Vector2i in combat.get_state().enemy_footprint_cells():
			out.append(_item("root_seal", seal_cell, frame))
	# F3 / F7 / F9: floor one-shots.
	for ev: Dictionary in vfx.active_events(FloorVfx.LAYER_FLOOR):
		var frame: int = FloorVfx.frame_for(vfx.entry(str(ev["id"])), float(ev["age"]), reduce)
		if frame >= 0:
			out.append(_item(str(ev["id"]), ev["cell"], frame))
	return out


## Drop tiles (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md rules 3-4) to draw now, both halves:
## `{cell, phase: "crack", k}` (k = crack progress 0..1, snapped to HOLE_K_STEPS and to the telegraph's reduce-motion
## steps), `{cell, phase: "hole"}`, `{cell, phase: "return", k}` (k = 1 just returned .. 0 fade over; also restored crumble cells). [] when unbound.
func hole_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = combat_of(_floor)
	if combat == null or combat.get_status() == null or combat.get_config() == null:
		return out
	var status: StatusEffects = combat.get_status()
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		for cell: Vector2i in status.crack_cells(side):
			var k: float = combat.get_config().quantize_progress(status.crack_progress(side, cell), reduce)
			out.append({"cell": cell, "phase": "crack", "k": roundf(k * ALPHA_STEPS) / ALPHA_STEPS})
		for cell: Vector2i in status.hole_cells(side):
			out.append({"cell": cell, "phase": "hole", "k": 1.0})
		for cell: Vector2i in status.returning_cells(side):
			var fade: float = 0.0 if reduce else status.hole_return_fraction(side, cell)
			out.append({"cell": cell, "phase": "return", "k": roundf(fade * ALPHA_STEPS) / ALPHA_STEPS})
		# Sky Isles crumble / island_drop cells come back the same way (TileHazards.return_fade_sec, the same
		# zones.hole_return_fade_sec; ADR-0001 Phase 1, 2026-11-01).
		var hazards: TileHazards = combat.get_hazards()
		if hazards != null:
			for cell: Vector2i in hazards.returning_cells(side):
				var back: float = 0.0 if reduce else hazards.return_fraction(side, cell)
				out.append({"cell": cell, "phase": "return", "k": roundf(back * ALPHA_STEPS) / ALPHA_STEPS})
	return out


## ADR-0001 Task 5 item 1 (pack 01 §3 steps 2-3): the player's charging target cells: one {cell, step, steps, check}
## per unlocked swing cell (check = the foe's cell gets the tick; step = CastFloorFx.charge_step of the swing progress).
## Locked cells (cracking / hole) are left out (item 5). [] when the player is not swinging.
func charge_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = combat_of(_floor)
	if combat == null or combat.get_state() == null:
		return out
	var actor: CutActor = combat.get_cut_actor()
	if actor == null or not actor.is_swinging():
		return out
	var style: Dictionary = CastVfx.travel_style("charge")
	var steps: int = int(style.get("steps", CastFloorFx.DEFAULT_CHARGE_STEPS))
	var step: int = CastFloorFx.charge_step(actor.get_progress(), steps)
	if SettingsStore.shared().get_reduce_motion():
		step = steps - 1
	var state: CombatState = combat.get_state()
	for cell: Vector2i in actor.get_cells():
		if combat.is_cell_locked(cell):
			continue
		out.append({"cell": cell, "step": step, "steps": steps, "check": state.is_enemy_at(cell)})
	return out


## Skill v2 Hỏa Lôi H2 (FuseFx): the floor part of every armed field now, in flat cell art px: {"under": the blast
## flash / shock ring / scorch / fizzle (drawn under the burn flames), "over": the armed sigils (drawn over a burning
## cell, so a seal on fire stays readable)}; {} when none.
func fuse_state() -> Dictionary:
	var combat: CombatView = combat_of(_floor)
	if combat == null or _floor == null or combat.get_arbiter() == null:
		return {}
	var recs: Array[Dictionary] = combat.get_fuse_fx()
	if recs.is_empty():
		return {}
	var now: float = combat.combat_clock()
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var under: Array[Dictionary] = []
	var over: Array[Dictionary] = []
	for rec: Dictionary in recs:
		var cell_rect: Rect2i = _floor.cell_art_rect(rec["cell"])
		var slab: Rect2i = SlabPainter.slab_rect(cell_rect.size)
		slab.position += cell_rect.position
		over.append_array(FuseFx.sigil_items(rec, now, slab, reduce))
		under.append_array(FuseFx.blast_floor_items(rec, now, slab, reduce))
	if under.is_empty() and over.is_empty():
		return {}
	return {"under": under, "over": over}


## Flat marks on armed trap / ward / pillar cells (both halves). [] when none.
func zone_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat: CombatView = combat_of(_floor)
	if combat == null or _floor == null or combat.get_status() == null:
		return out
	var step: int = int(combat.combat_clock() * 8.0) % 8
	var status: StatusEffects = combat.get_status()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		for kind: String in StatusEffects.FIELD_KINDS:
			for cell: Vector2i in status.field_cells(side, kind):
				var info: Dictionary = status.field_at(side, cell)
				var cell_rect: Rect2i = _floor.cell_art_rect(cell)
				var slab: Rect2i = SlabPainter.slab_rect(cell_rect.size)
				slab.position += cell_rect.position
				out.append_array(_ZoneFx.marks(kind, str((info.get("data", {}) as Dictionary).get("skill_id", "")), slab, step))
		# batch 4 (Dấu Tử): the death mark on the marked unit's cells while it lasts
		if status.has_mark(side):
			var m: Dictionary = status.mark_at(side)
			var frac: float = float(m.get("left", 0.0)) / maxf(float(m.get("total", 1.0)), 0.001)
			var state: CombatState = combat.get_state()
			var marked: Array = state.enemy_footprint_cells() if side == CombatState.Side.ENEMY else [state.player_cell]
			for cell: Vector2i in marked:
				var cell_rect: Rect2i = _floor.cell_art_rect(cell)
				var slab: Rect2i = SlabPainter.slab_rect(cell_rect.size)
				slab.position += cell_rect.position
				out.append_array(_ZoneFx.mark(slab, step, frac))
	return out


func _process(_delta: float) -> void:
	var combat_now: CombatView = combat_of(_floor) if _floor != null else null
	if combat_now != null and not combat_now.get_cast_flood().is_empty():
		queue_redraw()
	if _floor == null:
		return
	var state: Dictionary = _floor.telegraph_state()
	var burn: Array[Dictionary] = burn_state()
	var vfx: Array[Dictionary] = vfx_state()
	var holes: Array[Dictionary] = hole_state()
	var charge: Array[Dictionary] = charge_state()
	var extras: Dictionary = _floor.pattern_extras()
	var fuse: Dictionary = fuse_state()
	if fuse != _drawn_fuse:
		_drawn_fuse = fuse
		queue_redraw()
	var zone: Array[Dictionary] = zone_state()
	if zone != _drawn_zone:
		_drawn_zone = zone
		queue_redraw()
	if state != _drawn or burn != _drawn_burn or vfx != _drawn_vfx or holes != _drawn_holes or charge != _drawn_charge 			or extras != _drawn_extras:
		_drawn_extras = extras
		_drawn_charge = charge
		_drawn = state
		_drawn_burn = burn
		_drawn_vfx = vfx
		_drawn_holes = holes
		queue_redraw()


func _draw() -> void:
	_redraws += 1
	if _floor == null:
		return
	# The states are re-read here so a redraw asked by mark_dirty shows the current effects, burn and swing too.
	_drawn_vfx = vfx_state()
	_drawn_burn = burn_state()
	_drawn_holes = hole_state()
	_drawn = _floor.telegraph_state()
	_drawn_charge = charge_state()
	_drawn_extras = _floor.pattern_extras()
	var combat: CombatView = combat_of(_floor)
	var vfx: FloorVfx = null if combat == null else combat.get_floor_vfx()
	if combat != null:
		_draw_holes(combat, vfx)
	if vfx != null:
		for item: Dictionary in _drawn_vfx:
			var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
			vfx.draw(self, str(item["id"]), FloorVfx.feet_for(cell_rect), int(item["frame"]), item["tint"], cell_rect)
	_drawn_fuse = fuse_state()
	for it: Dictionary in _drawn_fuse.get("under", []) as Array:
		draw_rect(Rect2(it["rect"]), it["col"])
	BurnPainter.paint(self, _floor, _drawn_burn, vfx != null and vfx.has_pack("burning_cell"))
	for it: Dictionary in _drawn_fuse.get("over", []) as Array:
		draw_rect(Rect2(it["rect"]), it["col"])
	_drawn_zone = zone_state()
	for it: Dictionary in _drawn_zone:
		draw_rect(Rect2(it["rect"]), it["col"])
	if combat != null:
		_draw_charge(combat)
	_floor.paint_dynamic(self, _drawn)
	if combat != null:
		_draw_flood(combat.get_cast_flood())


# User 2026-11-01 (reference board): the cast explodes on the first cell and lights the area cell by cell: each cell
# wipes in from the neighbour it was reached from (bright leading edge), flashes, then glows gold with a gold outline
# and cracks until every cell is lit, and all fade together (floor overlay: alpha allowed, art bible 8.5).
func _draw_flood(flood: Dictionary) -> void:
	# flood.tiles false (user 2026-11-01): only the bursts and shards show, no lit cells.
	if flood.is_empty() or not bool(flood["style"].get("tiles", true)):
		return
	var style: Dictionary = flood["style"]
	var fill: Color = style["fill"]
	var edge: Color = style["edge"]
	var edge_px: int = int(style["edge_px"])
	for item: Dictionary in flood["cells"]:
		var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
		var r: Rect2i = CastVfx.flood_rect(cell_rect, float(item["reveal"]), item["dir"])
		if not r.has_area():
			continue
		var f: float = float(item["fade"])
		var flash: float = 1.0 - clampf(float(item["since"]) / 0.15, 0.0, 1.0)
		draw_rect(Rect2(r), Color(fill, (float(style["alpha"]) + 0.4 * flash) * f))
		if float(item["reveal"]) >= 1.0:
			draw_rect(Rect2(cell_rect.grow(-1)), Color(fill, f), false, edge_px)
			for pts: Array in CastVfx.crack_lines(item["cell"], cell_rect):
				for k: int in range(1, pts.size()):
					draw_line(Vector2(pts[k - 1]), Vector2(pts[k]), Color(style["crack"], f), 1.0)
		if float(item["reveal"]) < 1.0:
			var dir: Vector2i = item["dir"]
			if dir == Vector2i.ZERO:
				draw_rect(Rect2(r), Color(edge, f), false, edge_px)
			elif dir.x != 0:
				var ex: int = r.end.x - edge_px if dir.x > 0 else r.position.x
				draw_rect(Rect2(ex, r.position.y, edge_px, r.size.y), Color(edge, f))
			else:
				var ey: int = r.end.y - edge_px if dir.y > 0 else r.position.y
				draw_rect(Rect2(r.position.x, ey, r.size.x, edge_px), Color(edge, f))


# Task 5 item 1: the charging target cells: a full-cell fill in the hero's block colour, a 2 px outline (both one
# palette step brighter per charge step), and a pixel tick on the foe's cell. Flat colours, whole px, no glow.
func _draw_charge(combat: CombatView) -> void:
	if _drawn_charge.is_empty():
		return
	var hero_id: String = str(UnitLayer.unit_ids_for(combat.match_params).get(CombatState.Side.PLAYER, ""))
	var block: Array[Color] = CastVfx.block_colours(hero_id)
	var style: Dictionary = CastVfx.travel_style("charge")
	var alpha: Variant = style.get("fill_alpha", [0.35, 0.75])
	var ok: bool = alpha is Array and (alpha as Array).size() == 2
	var lo: float = float(alpha[0]) if ok else 0.35
	var hi: float = float(alpha[1]) if ok else 0.75
	var px: int = int(style.get("outline_px", 2))
	var check_px: int = int(style.get("check_px", 2))
	for item: Dictionary in _drawn_charge:
		var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
		var slab: Rect2i = SlabPainter.slab_rect(cell_rect.size)
		slab.position += cell_rect.position
		var c: Dictionary = CastFloorFx.charge_colours(block[0], block[1], int(item["step"]), int(item["steps"]), lo, hi)
		draw_rect(Rect2(slab), c["fill"])
		_outline(slab, px, c["outline"])
		if bool(item["check"]):
			var ticks: Array[Rect2i] = CastFloorFx.check_rects(slab, check_px)
			for r: Rect2i in ticks:
				draw_rect(Rect2(r.grow(1)), SlabPainter.INK)
			for r: Rect2i in ticks:
				draw_rect(Rect2(r), block[1])


# Whole-px outline of [param r], [param px] wide, inside the rect.
func _outline(r: Rect2i, px: int, color: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, px), color)
	draw_rect(Rect2(r.position.x, r.end.y - px, r.size.x, px), color)
	draw_rect(Rect2(r.position.x, r.position.y + px, px, r.size.y - px * 2), color)
	draw_rect(Rect2(r.end.x - px, r.position.y + px, px, r.size.y - px * 2), color)


# Task 5 item 4 (user: "o rot co trang tri giong o trong, khong den xi"): the drop-tile pit in the region's own floor
# palette, darker: deep floor, lit back wall and a middle step (stepped bands, no gradient), a broken lighter rim on the
# top / sides and a few rubble squares. [param opening] {"rim", "wall"} = which parts show (all for an open hole; the
# crack -> hole transition opens the rim first, then the wall).
func _draw_pit(cell: Vector2i, slab: Rect2i, opening: Dictionary) -> void:
	var pal: Dictionary = _floor.get_platform_palette()
	var cols: Dictionary = CastFloorFx.pit_colours(_pal(pal, "deck", Color("3A3B37")), _pal(pal, "face", Color("262521")),
		_pal(pal, "face_top", Color("5A5B54")), CastVfx.travel_style("pit"))
	var lay: Dictionary = CastFloorFx.pit_layout(slab, hash(cell) * 7 + 3)
	if bool(opening.get("wall", false)):
		draw_rect(Rect2(lay["deep"]), cols["deep"])
		draw_rect(Rect2(lay["bands"][0]), cols["wall"])
		draw_rect(Rect2(lay["bands"][1]), cols["mid"])
		for r: Rect2i in lay["rubble"]:
			draw_rect(Rect2(r), cols["rubble"])
	if bool(opening.get("rim", false)):
		for r: Rect2i in lay["rim"]:
			draw_rect(Rect2(r), cols["rim"])


static func _pal(palette: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = palette.get(key, null)
	if v is Color:
		return v
	if v is String and not (v as String).is_empty():
		return Color(v as String)
	return fallback


# Drop tiles (rules 3-4), no text: a CRACK deepens like a boss telegraph (red #E5293B fill on the slab at the
# telegraph's fill alpha for progress k, plus the F4 cracked_cell pack stepped through its frames by k so the crack
# spreads); a HOLE is a dark empty slab (Ink); a RETURNING cell fades back in from white.
func _draw_holes(combat: CombatView, vfx: FloorVfx) -> void:
	var has_crack_art: bool = vfx != null and vfx.has_pack("cracked_cell")
	for item: Dictionary in _drawn_holes:
		var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
		var slab: Rect2i = SlabPainter.slab_rect(cell_rect.size)
		slab.position += cell_rect.position
		var k: float = float(item["k"])
		match str(item["phase"]):
			"crack":
				draw_rect(Rect2(slab), Color(TelegraphPainter.RED, combat.get_config().telegraph_fill_alpha(k)))
				if has_crack_art:
					var hold: int = int(vfx.entry("cracked_cell").get("hold_frame", 0))
					vfx.draw(self, "cracked_cell", FloorVfx.feet_for(cell_rect), roundi(k * float(hold)), Color.WHITE, cell_rect)
				# Task 5 item 4: on the last steps the crack lines widen to the pit's broken rim, then the wall opens.
				var opening: Dictionary = CastFloorFx.crack_opening(k)
				if bool(opening["rim"]):
					_draw_pit(item["cell"], slab, opening)
			"hole":
				_draw_pit(item["cell"], slab, {"rim": true, "wall": true})
			"return":
				if k > 0.0:
					draw_rect(Rect2(slab), Color(1.0, 1.0, 1.0, k))


static func _item(id: String, cell: Vector2i, frame: int, tint: Color = Color.WHITE) -> Dictionary:
	return {"id": id, "cell": cell, "frame": frame, "tint": tint}
