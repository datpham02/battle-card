class_name FloorDynamicLayer
extends Node2D
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
	# F5: the player's swing cells, in the hero's block colour.
	var actor: CutActor = combat.get_cut_actor()
	if actor != null and actor.is_swinging() and vfx.has_pack("cast_target"):
		var frame: int = FloorVfx.frame_for(vfx.entry("cast_target"), clock, reduce)
		for cell: Vector2i in actor.get_cells():
			out.append(_item("cast_target", cell, frame, HERO_BLOCK_TINT))
	# F3 / F7 / F9: floor one-shots.
	for ev: Dictionary in vfx.active_events(FloorVfx.LAYER_FLOOR):
		var frame: int = FloorVfx.frame_for(vfx.entry(str(ev["id"])), float(ev["age"]), reduce)
		if frame >= 0:
			out.append(_item(str(ev["id"]), ev["cell"], frame))
	return out


func _process(_delta: float) -> void:
	if _floor == null:
		return
	var state: Dictionary = _floor.telegraph_state()
	var burn: Array[Dictionary] = burn_state()
	var vfx: Array[Dictionary] = vfx_state()
	if state != _drawn or burn != _drawn_burn or vfx != _drawn_vfx:
		_drawn = state
		_drawn_burn = burn
		_drawn_vfx = vfx
		queue_redraw()


func _draw() -> void:
	_redraws += 1
	if _floor == null:
		return
	# The states are re-read here so a redraw asked by mark_dirty shows the current effects, burn and swing too.
	_drawn_vfx = vfx_state()
	_drawn_burn = burn_state()
	_drawn = _floor.telegraph_state()
	var combat: CombatView = combat_of(_floor)
	var vfx: FloorVfx = null if combat == null else combat.get_floor_vfx()
	if vfx != null:
		for item: Dictionary in _drawn_vfx:
			var cell_rect: Rect2i = _floor.cell_art_rect(item["cell"])
			vfx.draw(self, str(item["id"]), FloorVfx.feet_for(cell_rect), int(item["frame"]), item["tint"], cell_rect)
	BurnPainter.paint(self, _floor, _drawn_burn, vfx != null and vfx.has_pack("burning_cell"))
	_floor.paint_dynamic(self, _drawn)


static func _item(id: String, cell: Vector2i, frame: int, tint: Color = Color.WHITE) -> Dictionary:
	return {"id": id, "cell": cell, "frame": frame, "tint": tint}
