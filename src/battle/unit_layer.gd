class_name UnitLayer
extends Node2D
## Unit layer of the battle art canvas (Story 047, art bible 8.6): the player and the boss, drawn in
## art px of the 800x360 SubViewport, back row first and left to right within a row, each anchored at
## [method unit_feet_art] (bottom-centre of the unit, FEET_INSET_ART art px above the cell's front
## edge). Part A draws the placeholder marks CombatView used to draw: the player's circle with the
## character name and the boss's square (Story 035 downed / invulnerable looks included). Part C adds
## the sprite sheets; units without a sheet keep these marks at the same anchor. Redraws every frame
## (units move; CombatView ticks the match).
##
## Part C (art bible 8.3, 8.6): a unit whose data id has a sheet (`SpriteSheet.load_unit`: Kiem si
## `kiem_si` 96x70 (v3 tall anchor, 2026-10-31), Goblin Scout `goblin_scout` 64x52 (v3, 2026-10-31)) is drawn from it with one [UnitAnimator] per side,
## ticked with the match's scaled delta. The unit ids come from `CombatView.match_params`: the player's
## is `character.id`, the boss's is the match `id` (chapters.json / run fixture). The clip follows the
## story table through [method clip_for], a pure priority over booleans (highest first): defeat / down
## (dead or downed, held) > victory (player, boss dead) > hit (HIT_SEC after a `CombatState.damaged`
## event) > cast_gesture (player, on the player CutActor's `swing_started`) > windup (boss while its
## CutActor swings) > awaken (player while the signature's timed effect runs) > step (for the step
## cooldown after `cell_changed`) > idle. The sprite's bottom-centre sits on the feet anchor in whole
## art px; a unit faces the divider (player right, boss left) and a sheet drawn the other way is
## mirrored with a negative destination width (no rotation, no scaling). Story 035 on a sprite: the
## downed boss is `down`'s last frame tinted DOWNED_COLOR, the invulnerable boss keeps its outline
## around the frame rect.
##
## Part D (art bible 8.5): a unit that is burning (Chay: its cell burns), frozen (Dong Bang: pinned,
## glossary #22) or chilled (Gia Lanh: frost stacks without the pin, glossary #23) wears the PixelLab
## status pack of [StatusPacks]: clip `behind` before the unit, clip `front` after it, both at the feet
## anchor, animated on the pack's frame_ms by a clock fed with the match's scaled delta
## ([method CombatView.scaled_delta]: slowed by the skill menu, stopped by Focus's full stop and by
## freeze_time; a paused battle has no _process at all). Reduce motion ([SettingsStore]) holds frame 0
## of the overlays and of `idle`.
## A dead unit wears nothing; a downed boss (Story 035) keeps its overlays.
## Implements: Story 047 Part A, Part C, Part D.

## Flat placeholder look (CombatView's colours before Story 047).
const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const PLAYER_COLOR: Color = Color(0.25, 0.6, 0.9)
const DOWNED_COLOR: Color = Color(0.55, 0.32, 0.32, 0.55)
const INVULNERABLE_OUTLINE: Color = Color(0.95, 0.95, 1.0, 0.95)
## Feet anchor: art px above the cell's front (bottom) edge (art bible 8.3). Kept for the fallback when a
## cell is too short for FEET_DEPTH_RATIO.
const FEET_INSET_ART: int = 3
## OSFE-style stance (user 2026-10-31, reference image): the feet stand about two thirds down the slab face,
## not on its front lip, so the body rises out of the tile and its own shadow sits on the face.
const FEET_DEPTH_RATIO: float = 0.72
## Ground shadow under every unit: an Ink ellipse on the slab (a floor overlay, so alpha blending is allowed,
## art bible 8.5), width / height as shares of the cell, and its alpha.
const SHADOW_WIDTH_RATIO: float = 0.56
const SHADOW_HEIGHT_RATIO: float = 0.17
const SHADOW_MIN_HEIGHT: int = 4
const SHADOW_COLOR: Color = Color(0.106, 0.090, 0.133, 0.5)
## Player marker: radius as a share of the cell height, label font size as a share of the radius, the
## smallest label font (art px; the fallback font at 1x) and how much of the diameter the label may fill.
const MARKER_RADIUS_RATIO: float = 0.33
const MARKER_FONT_RATIO: float = 0.6
const MARKER_MIN_FONT_SIZE: int = 5
const MARKER_TEXT_FILL: float = 0.92
const MARKER_OUTLINE_ART: float = 2.0
const MARKER_ARC_POINTS: int = 32
## Boss body: width / height as shares of the cell; Story 035 kneeling height as a share of the body.
const ENEMY_BODY_WIDTH_RATIO: float = 0.6
const ENEMY_BODY_HEIGHT_RATIO: float = 0.8
const DOWNED_BODY_HEIGHT_RATIO: float = 0.5
## Outline widths and the dead cross, art px (CombatView drew 3 / 4 / 6 screen px at 720p).
const BODY_OUTLINE_ART: float = 2.0
const INVULNERABLE_GROW_ART: float = 2.0
const DEAD_CROSS_ART: float = 3.0

## Status overlay kinds (the keys of assets/art/vfx/status/index.json) and the order they are drawn in.
const STATUS_BURN: String = "burn"
const STATUS_FROZEN: String = "frozen"
const STATUS_CHILL: String = "chill"
## Unit frame kinds of the status packs: the hero packs are built around the v3 Swordsman (body about 31x66), the goblin packs around the v3 Goblin Scout (body about 26x46); rebuilt 2026-10-31 with the PixelLab VFX workbench, anchored on the feet.
const FRAME_KIND_HERO: String = "hero"
const FRAME_KIND_GOBLIN: String = "goblin"
## Pack clips drawn under and over the unit (art bible 8.6).
const CLIP_BEHIND: String = "behind"
const CLIP_FRONT: String = "front"

## Sheet clips (the frameTags of Story 045's sheets; `fall` plays when a unit dies by falling into a hole, ADR-0001 Task 5).
const CLIP_IDLE: String = "idle"
const CLIP_STEP: String = "step"
## 2026-11-02 (user: "tiến có animation tiến, lùi có animation lùi, lên xuống cũng vậy", OSFE dashes): the step clip
## per direction, relative to the way the unit faces; a sheet without one plays CLIP_STEP.
const CLIP_STEP_FORWARD: String = "step_forward"
const CLIP_STEP_BACK: String = "step_back"
const CLIP_STEP_UP: String = "step_up"
const CLIP_STEP_DOWN: String = "step_down"
## 2026-11-02 guard stance: played once when the match binds (the hero draws the sword into the guard), then idle.
const CLIP_DRAW: String = "draw"
const CLIP_CAST: String = "cast_gesture"
const CLIP_HIT: String = "hit"
const CLIP_WINDUP: String = "windup"
const CLIP_VICTORY: String = "victory"
const CLIP_DEFEAT: String = "defeat"
const CLIP_DOWN: String = "down"
const CLIP_AWAKEN: String = "awaken"
const CLIP_FALL: String = "fall"
## Seconds the `hit` clip outranks step / windup after a damage event (story table, Part C).
const HIT_SEC: float = 0.12
## Facing each side must show: towards the divider (art bible 8.6).
const FACING_PLAYER: String = "right"
const FACING_ENEMY: String = "left"
## Keys of the context [method clip_for] reads (all booleans but `side`).
const CTX_SIDE: String = "side"
const CTX_DEAD: String = "dead"
## True when the unit died by falling into a drop-tile hole (CombatView.died_by_fall).
const CTX_FELL: String = "fell"
const CTX_DOWNED: String = "downed"
const CTX_OPPONENT_DEAD: String = "opponent_dead"
const CTX_HIT: String = "hit"
const CTX_CASTING: String = "casting"
const CTX_SWINGING: String = "swinging"
const CTX_AWAKEN: String = "awaken"
const CTX_STEPPING: String = "stepping"
## The two sides, in the order the per-side tables are walked.
const SIDES: Array[int] = [CombatState.Side.PLAYER, CombatState.Side.ENEMY]
## OSFE hit feel: the shake flips side every this many seconds.
const SHAKE_STEP_SEC: float = 0.03
## Step dust (2026-11-02): square grains (art px) left on the old cell, their colour (slab light edge) and how far
## they drift sideways / rise over the dust's life.
const DUST_GRAIN_ART: int = 2
const DUST_COLOR: Color = Color("5A5650")
const DUST_SPREAD_ART: int = 6
const DUST_RISE_ART: int = 3

var _combat: CombatView = null
## Status clocks: CombatState.Side -> {kind: String -> elapsed match seconds since the kind started}.
var _status_clock: Dictionary = {}
## Reduce motion (accessibility): overlays and `idle` hold frame 0. Read from SettingsStore at setup.
var _reduce_motion: bool = false

## Part C per-side tables (CombatState.Side -> value).
var _unit_id: Dictionary = {}
var _sheet: Dictionary = {}
var _anim: Dictionary = {}
## The clip the state asks for (what [method clip_for] returned on the last update).
var _logical_clip: Dictionary = {}
## Seconds of hit priority left; a new damage event restarts the clip.
var _hit_left: Dictionary = {}
var _hit_restart: Dictionary = {}
## Seconds of the step clip left (the step cooldown read on the update after `cell_changed`).
var _step_left: Dictionary = {}
var _step_pending: Dictionary = {}
## The player's cast_gesture is due (swing_started seen, clip not started yet).
var _cast_pending: bool = false
## What the signals are connected to (null until the match is bound).
var _bound_state: CombatState = null
var _bound_actor: CutActor = null
## OSFE hit feel (CastVfx.hit_feel, user 2026-11-01): seconds of white flash and of shake left per side, the feel
## values, and the add-blend child the flash is drawn on.
var _flash_left: Dictionary = {}
var _shake_left: Dictionary = {}
var _feel: Dictionary = {}
var _flash: Node2D = null
## A damage event whose flash has not started: CombatState.Side -> seconds still to wait (-1 = delay not read yet).
var _flash_wait: Dictionary = {}
## Step glide (2026-11-02, OSFE dash feel): per side, the cell and ground (drawn feet) seen on the last advance, the
## glide {from: Vector2i ground, left, total} and the dust {at: Vector2i, left, total}.
var _last_cell: Dictionary = {}
var _last_ground: Dictionary = {}
var _slide: Dictionary = {}
## The directional step clip of the last step per side (step_clip_for).
var _step_clip: Dictionary = {}
## A new step started since the clip was last chosen (a second dash the same way restarts the clip).
var _step_restart: Dictionary = {}
var _dust: Dictionary = {}


## Binds the layer to the battle's CombatView (state, grid, names and screen size come from it).
## [param settings] is the store the reduce-motion flag is read from (the shared one when null).
## The match (units, animators, signals) binds now when the view is ready, else on the first update.
func setup(combat: CombatView, settings: SettingsStore = null) -> void:
	_unbind_match()
	_combat = combat
	_status_clock.clear()
	var store: SettingsStore = settings if settings != null else SettingsStore.shared()
	_reduce_motion = store != null and store.get_reduce_motion()
	set_process(combat != null)
	_feel = CastVfx.hit_feel()
	_ensure_flash_layer()
	_bind_match()
	queue_redraw()


func _process(delta: float) -> void:
	if _combat != null:
		advance(_combat.scaled_delta(delta))
	queue_redraw()
	if _flash != null:
		_flash.queue_redraw()


func _exit_tree() -> void:
	_unbind_match()


## Advances every clock of the layer by [param step] match seconds: the status overlays and the unit
## animators (clip selection, then tick). _process calls it with [method CombatView.scaled_delta];
## tests call it directly. No-op until the view has a state.
func advance(step: float) -> void:
	if _combat == null or _combat.get_state() == null:
		return
	_bind_match()
	_advance_status_clocks(step)
	for side: int in SIDES:
		_track_step(side, maxf(step, 0.0))
		_update_clip(side, maxf(step, 0.0))
		_flash_left[side] = maxf(float(_flash_left.get(side, 0.0)) - maxf(step, 0.0), 0.0)
		_shake_left[side] = maxf(float(_shake_left.get(side, 0.0)) - maxf(step, 0.0), 0.0)
		_tick_flash_wait(side, maxf(step, 0.0))


## Seconds of white hit flash left on [param side] (0 when none).
func get_flash_left(side: int) -> float:
	return float(_flash_left.get(side, 0.0))


## Pure: the shake offset (art px) of a unit with [param left] seconds of shake: [param px] to one side, then the
## other, flipping every SHAKE_STEP_SEC; zero when none is left.
static func shake_offset(left: float, px: int) -> Vector2i:
	if left <= 0.0 or px <= 0:
		return Vector2i.ZERO
	return Vector2i(px if int(left / SHAKE_STEP_SEC) % 2 == 0 else -px, 0)


## Bottom-centre anchor of the unit of [param side] (CombatState.Side) in whole art px: x = the cell's
## centre, y = the cell's bottom edge minus FEET_INSET_ART. Vector2i(-1, -1) when unbound.
func unit_feet_art(side: int) -> Vector2i:
	if _combat == null or _combat.get_state() == null:
		return Vector2i(-1, -1)
	return _ground_of(side)


## Pure: the directional step clip for a move from [param from] to [param to] (board cells) by a unit that faces
## right when [param faces_right]: along its facing = forward, against it = back, a row up (toward the back of the
## board) = up, a row down = down; a diagonal or no move counts by its column first.
static func step_clip_for(from: Vector2i, to: Vector2i, faces_right: bool) -> String:
	var d: Vector2i = to - from
	if d.x != 0:
		return CLIP_STEP_FORWARD if (d.x > 0) == faces_right else CLIP_STEP_BACK
	if d.y < 0:
		return CLIP_STEP_UP
	if d.y > 0:
		return CLIP_STEP_DOWN
	return CLIP_STEP


## Pure: the offset (art px) of a gliding unit from its target feet: the whole [param from] - [param to] gap when
## [param left] == [param total], shrinking with an ease-out (fast start, soft landing) to zero when [param left] is 0.
static func slide_offset(from: Vector2i, to: Vector2i, left: float, total: float) -> Vector2i:
	if total <= 0.0 or left <= 0.0:
		return Vector2i.ZERO
	var t: float = 1.0 - clampf(left / total, 0.0, 1.0)
	var remain: float = pow(1.0 - t, 3.0)
	return Vector2i(roundi((from.x - to.x) * remain), roundi((from.y - to.y) * remain))


## Seconds of step glide left on [param side] (0 when it stands on its cell).
func get_slide_left(side: int) -> float:
	return float((_slide.get(side, {}) as Dictionary).get("left", 0.0))


# The drawn feet of [param side]: its cell's feet plus the glide offset while it is stepping.
func _ground_of(side: int) -> Vector2i:
	var to: Vector2i = _feet_of_unit(side)
	var slide: Dictionary = _slide.get(side, {})
	if slide.is_empty():
		return to
	return to + slide_offset(slide["from"] as Vector2i, to, float(slide["left"]), float(slide["total"]))


# Starts a glide (and dust) when [param side]'s cell changed since the last advance, from where it was drawn then;
# runs the glide and dust clocks down by [param step]. Reduce motion: no glide, no dust (the unit snaps as before).
func _track_step(side: int, step: float) -> void:
	var cell: Vector2i = _cell_of(side)
	if _reduce_motion:
		_slide.erase(side)
		_dust.erase(side)
	if _last_cell.has(side) and _last_cell[side] != cell and not _reduce_motion:
		var slide_sec: float = float(_feel.get("step_slide_sec", 0.0))
		var dust_sec: float = float(_feel.get("step_dust_sec", 0.0))
		var from: Vector2i = _last_ground[side]
		_step_clip[side] = step_clip_for(_last_cell[side], cell, facing_for(side) == FACING_PLAYER)
		_step_restart[side] = true
		if slide_sec > 0.0:
			_slide[side] = {"from": from, "left": slide_sec, "total": slide_sec}
		if dust_sec > 0.0:
			_dust[side] = {"at": from, "left": dust_sec, "total": dust_sec}
	else:
		for table: Dictionary in [_slide, _dust]:
			var entry: Dictionary = table.get(side, {})
			if not entry.is_empty():
				entry["left"] = maxf(float(entry["left"]) - step, 0.0)
				if float(entry["left"]) <= 0.0:
					table.erase(side)
	_last_cell[side] = cell
	_last_ground[side] = _ground_of(side)


# Square dust on the cell a unit just left: four grains drifting out and up, fading over the dust's life.
func _draw_dust(side: int) -> void:
	var dust: Dictionary = _dust.get(side, {})
	if dust.is_empty():
		return
	var t: float = 1.0 - clampf(float(dust["left"]) / maxf(float(dust["total"]), 0.001), 0.0, 1.0)
	var at: Vector2i = dust["at"]
	var spread: int = roundi(DUST_SPREAD_ART * t)
	var rise: int = roundi(DUST_RISE_ART * t)
	var color := Color(DUST_COLOR, 1.0 - t)
	for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
		var p := Vector2i(at.x + dir.x * (spread + 2) - DUST_GRAIN_ART / 2, at.y - DUST_GRAIN_ART + dir.y * rise - rise)
		draw_rect(Rect2(Vector2(p), Vector2(DUST_GRAIN_ART, DUST_GRAIN_ART)), color)


## Feet anchor for any board cell (the rule of [method unit_feet_art]).
func feet_art_of_cell(cell: Vector2i) -> Vector2i:
	return _feet_of_cell(cell)


## Status overlay kinds the unit of [param side] wears right now, in draw order (burn, then frozen or
## chill). Empty when unbound or when the unit is dead (a downed boss is not dead for this purpose).
func get_active_status_kinds(side: int) -> Array[String]:
	if _combat == null or _combat.get_state() == null:
		return []
	return status_kinds_for(_combat.get_status(), side, _status_cell(side), _is_alive(side))


## Match seconds the overlay [param kind] of [param side] has been running (0 when it is not active).
func get_status_elapsed(side: int, kind: String) -> float:
	var clock: Dictionary = _status_clock.get(side, {})
	return float(clock.get(kind, 0.0))


## Whether reduce motion holds the overlays and `idle` on frame 0 (set from SettingsStore at setup).
func is_reduce_motion() -> bool:
	return _reduce_motion


## Overrides the reduce-motion flag (tests, demos); the store is not written.
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on
	for side: int in _anim:
		(_anim[side] as UnitAnimator).set_reduce_motion(on)
	queue_redraw()


## Data id of the unit of [param side] ("" when the match has none, e.g. a character-less test floor).
func get_unit_id(side: int) -> String:
	return String(_unit_id.get(side, ""))


## The clip the game state asks for on [param side] (the result of [method clip_for] on the last
## update; `idle` before the first). The same for a placeholder unit, which has no animator.
func get_current_clip(side: int) -> String:
	return String(_logical_clip.get(side, CLIP_IDLE))


## The animator of [param side] (null until bound; a placeholder unit has one over a null sheet).
func get_animator(side: int) -> UnitAnimator:
	return _anim.get(side, null)


## The sheet of [param side] (null for a placeholder unit).
func get_sheet(side: int) -> SpriteSheet:
	return _sheet.get(side, null)


## True when [param side] is drawn with the Part A mark instead of a sprite: no sheet for its id, or
## the sheet's PNG is not available (not imported).
func is_placeholder(side: int) -> bool:
	var sheet: SpriteSheet = get_sheet(side)
	return sheet == null or sheet.texture() == null


## Seconds of hit priority left on [param side] (0 when no hit is showing).
func get_hit_left(side: int) -> float:
	return float(_hit_left.get(side, 0.0))


## Seconds of the step clip left on [param side] (0 when not stepping).
func get_step_left(side: int) -> float:
	return float(_step_left.get(side, 0.0))


## The booleans [method clip_for] reads for [param side], from the live match. Empty when unbound.
func clip_context(side: int) -> Dictionary:
	if _combat == null or _combat.get_state() == null:
		return {}
	var state: CombatState = _combat.get_state()
	var player: bool = side == CombatState.Side.PLAYER
	var anim: UnitAnimator = get_animator(side)
	# 2026-10-31: the cast_gesture shows for the player's whole swing (held on its first frame until the projectile is
	# due, CastVfx), not only for the clip's length.
	var actor: CutActor = _combat.get_cut_actor() if player else null
	var casting: bool = _cast_pending or (actor != null and actor.is_swinging()) or (anim != null and anim.current_clip() == CLIP_CAST and not anim.is_finished())
	var boss_actor: CutActor = _combat.get_boss().get_actor() if _combat.get_boss() != null else null
	return {
		CTX_SIDE: side,
		CTX_DEAD: state.is_player_dead() if player else state.is_enemy_dead(),
		CTX_DOWNED: (not player) and _combat.is_boss_downed(),
		CTX_FELL: _combat.died_by_fall(side),
		CTX_OPPONENT_DEAD: state.is_enemy_dead() if player else state.is_player_dead(),
		CTX_HIT: get_hit_left(side) > 0.0,
		CTX_CASTING: player and casting,
		CTX_SWINGING: (not player) and boss_actor != null and boss_actor.is_swinging(),
		CTX_AWAKEN: player and _combat.is_signature_active(),
		CTX_STEPPING: get_step_left(side) > 0.0,
	}


## 2026-10-31: true while the player's cast_gesture should wait on its first frame: its swing still has more than
## CastVfx.gesture_due_left of the hero's projectile to go (so the slash frame meets the launch). False for the boss,
## with no swing, or no cast pack.
func cast_hold(side: int) -> bool:
	if side != CombatState.Side.PLAYER or _combat == null:
		return false
	var actor: CutActor = _combat.get_cut_actor()
	if actor == null or not actor.is_swinging():
		return false
	var entry: Dictionary = CastVfx.entry_for(String(_unit_id.get(side, "")))
	if entry.is_empty():
		return false
	return actor.get_time_left() > CastVfx.gesture_due_left(entry)


# 2026-11-01 (v4 wind-up): the cast clip plays from the swing start and stops on its coil frame (the cast index's
# gesture_hold_frame) while the telegraph runs; when the launch is due it jumps to the slash frame after the coil.
# An entry without a hold frame keeps the old behaviour (held on frame 0 until due).
func _drive_cast_hold(side: int, anim: UnitAnimator) -> void:
	var hold: int = CastVfx.gesture_hold_frame(CastVfx.entry_for(String(_unit_id.get(side, ""))))
	if hold < 0:
		anim.set_paused(cast_hold(side))
		return
	if cast_hold(side):
		anim.set_paused(anim.frame_index() >= hold)
		return
	if anim.frame_index() <= hold:
		anim.seek(hold + 1)
	anim.set_paused(false)


## The clip for a unit's state, pure (Story 047 Part C table). [param ctx] keys: `side`
## (CombatState.Side, default PLAYER) and the booleans `dead`, `downed`, `opponent_dead`, `hit`,
## `casting`, `swinging`, `awaken`, `stepping` (absent = false). Priority, highest first:
## dead by a fall (`fell`) -> `fall` (Task 5; [method _update_clip] keeps `defeat` / `down` for a sheet without it);
## dead or downed -> `defeat` (player) / `down` (boss); player with the boss dead -> `victory`;
## hit -> `hit`; player casting -> `cast_gesture`; boss swinging -> `windup`; player with the signature
## running -> `awaken`; stepping -> `step`; else `idle`.
static func clip_for(ctx: Dictionary) -> String:
	var player: bool = int(ctx.get(CTX_SIDE, CombatState.Side.PLAYER)) == CombatState.Side.PLAYER
	if bool(ctx.get(CTX_DEAD, false)) and bool(ctx.get(CTX_FELL, false)):
		return CLIP_FALL
	if bool(ctx.get(CTX_DEAD, false)) or bool(ctx.get(CTX_DOWNED, false)):
		return CLIP_DEFEAT if player else CLIP_DOWN
	if player and bool(ctx.get(CTX_OPPONENT_DEAD, false)):
		return CLIP_VICTORY
	if bool(ctx.get(CTX_HIT, false)):
		return CLIP_HIT
	if player and bool(ctx.get(CTX_CASTING, false)):
		return CLIP_CAST
	if not player and bool(ctx.get(CTX_SWINGING, false)):
		return CLIP_WINDUP
	if player and bool(ctx.get(CTX_AWAKEN, false)):
		return CLIP_AWAKEN
	if bool(ctx.get(CTX_STEPPING, false)):
		return CLIP_STEP
	return CLIP_IDLE


## The unit ids of a match, pure: {PLAYER: `match_params.character.id`, ENEMY: `match_params.id`}
## ("" when absent). The boss id is the chapters.json match id (`goblin_scout`, `wolf`, ...).
static func unit_ids_for(match_params: Dictionary) -> Dictionary:
	var character: Variant = match_params.get("character")
	var player_id: String = str((character as Dictionary).get("id", "")) if character is Dictionary else ""
	return {
		CombatState.Side.PLAYER: player_id,
		CombatState.Side.ENEMY: str(match_params.get("id", "")),
	}


## The facing [param side] must show: the player faces right, the boss faces left (both face the divider).
static func facing_for(side: int) -> String:
	return FACING_PLAYER if side == CombatState.Side.PLAYER else FACING_ENEMY


## Destination rect of a frame of [param size] whose bottom-centre is [param feet], whole art px (an
## odd width floors the left edge). With [param flip] the width is negative and starts at the right
## edge, which `draw_texture_rect_region` draws mirrored (art bible 8.10: a flip is allowed, rotation
## and non-integer scaling are not).
static func sprite_dest_rect(feet: Vector2i, size: Vector2i, flip: bool) -> Rect2:
	@warning_ignore("integer_division")
	var x: int = feet.x - size.x / 2
	var y: int = feet.y - size.y
	if flip:
		return Rect2(float(x + size.x), float(y), -float(size.x), float(size.y))
	return Rect2(float(x), float(y), float(size.x), float(size.y))


## The status overlay kinds a unit wears, pure: `burn` when its [param cell] burns, then `frozen`
## while [param side] is pinned (Dong Bang), else `chill` while it has frost stacks (Gia Lanh); never
## both frozen and chill. Empty for a null status or when [param alive] is false. Fragile (Ran) keeps
## the script overlay of the HUD and is not a pack.
static func status_kinds_for(status: StatusEffects, side: int, cell: Vector2i, alive: bool = true) -> Array[String]:
	var out: Array[String] = []
	if status == null or not alive:
		return out
	if status.is_burning(cell):
		out.append(STATUS_BURN)
	if status.is_pinned(side):
		out.append(STATUS_FROZEN)
	elif status.get_frost_stacks(side) > 0:
		out.append(STATUS_CHILL)
	return out


## Frame of a status pack's clips at [param elapsed_sec]: 0 under [param reduce_motion], else
## [method VfxPack.frame_at] on the pack's frame_ms and loop flag. The `front` clip gives the frame
## count (`behind` when a pack has no front; every shipped pack has both with the same count).
## 0 for a null pack.
static func overlay_frame(elapsed_sec: float, pack: VfxPack, reduce_motion: bool = false) -> int:
	if pack == null or reduce_motion:
		return 0
	var clip_data: Dictionary = pack.clip(CLIP_FRONT)
	if clip_data.is_empty():
		clip_data = pack.clip(CLIP_BEHIND)
	return VfxPack.frame_at(clip_data, elapsed_sec, pack.frame_ms(), pack.is_loop())


## Pack frame kind of [param side]: hero for the player, goblin for the boss.
static func frame_kind_of(side: int) -> String:
	return FRAME_KIND_HERO if side == CombatState.Side.PLAYER else FRAME_KIND_GOBLIN


# Connects to the match once its state exists: unit ids and sheets from match_params, one animator per
# side on `idle`, the damage / step / cast signals. Idempotent for the same state.
func _bind_match() -> void:
	if _combat == null:
		return
	var state: CombatState = _combat.get_state()
	if state == null or state == _bound_state:
		return
	_unbind_match()
	_bound_state = state
	state.damaged.connect(_on_damaged)
	state.cell_changed.connect(_on_cell_changed)
	var actor: CutActor = _combat.get_cut_actor()
	if actor != null:
		actor.swing_started.connect(_on_player_swing_started)
		_bound_actor = actor
	var ids: Dictionary = unit_ids_for(_combat.match_params)
	_cast_pending = false
	for side: int in SIDES:
		var unit_id: String = String(ids[side])
		_unit_id[side] = unit_id
		_sheet[side] = SpriteSheet.load_unit(unit_id) if not unit_id.is_empty() else null
		var anim := UnitAnimator.new(_sheet[side])
		anim.set_reduce_motion(_reduce_motion)
		var sheet: SpriteSheet = _sheet[side]
		anim.play(CLIP_DRAW if sheet != null and sheet.has_clip(CLIP_DRAW) and not _reduce_motion else CLIP_IDLE)
		_anim[side] = anim
		_logical_clip[side] = CLIP_IDLE
		_hit_left[side] = 0.0
		_hit_restart[side] = false
		_step_left[side] = 0.0
		_step_pending[side] = false


func _unbind_match() -> void:
	if _bound_state != null and is_instance_valid(_bound_state):
		if _bound_state.damaged.is_connected(_on_damaged):
			_bound_state.damaged.disconnect(_on_damaged)
		if _bound_state.cell_changed.is_connected(_on_cell_changed):
			_bound_state.cell_changed.disconnect(_on_cell_changed)
	if _bound_actor != null and is_instance_valid(_bound_actor) and _bound_actor.swing_started.is_connected(_on_player_swing_started):
		_bound_actor.swing_started.disconnect(_on_player_swing_started)
	_bound_state = null
	_bound_actor = null


func _on_damaged(side: int, amount: float) -> void:
	if amount <= 0.0:
		return
	_hit_left[side] = HIT_SEC
	_hit_restart[side] = true
	# The flash waits for the cell blast that hits this unit (CombatView.take_hit_delay, read on the next update,
	# after the cut's blasts were queued).
	_flash_wait[side] = -1.0


# Starts the hit flash and shake of [param side] once its wait (see _on_damaged) has run out.
func _tick_flash_wait(side: int, step: float) -> void:
	if not _flash_wait.has(side):
		return
	var wait: float = float(_flash_wait[side])
	if wait < 0.0:
		wait = _combat.take_hit_delay(side) if _combat != null else 0.0
	else:
		wait -= step
	if wait > 0.0:
		_flash_wait[side] = wait
		return
	_flash_wait.erase(side)
	_flash_left[side] = float(_feel.get("flash_sec", 0.0))
	if not _reduce_motion:
		_shake_left[side] = float(_feel.get("shake_sec", 0.0))


func _on_cell_changed(side: int, _old_cell: Vector2i, _new_cell: Vector2i) -> void:
	# The mover starts its cooldown AFTER the state emits cell_changed; the length is read on the next update.
	_step_pending[side] = true


func _on_player_swing_started(_cells: Array[Vector2i], _skill_id: String, _duration: float) -> void:
	_cast_pending = true


# The mover of [param side]: the player's (CombatView) or the boss's (BossController); null when absent.
func _mover_of(side: int) -> UnitMover:
	if side == CombatState.Side.PLAYER:
		return _combat.get_mover()
	return _combat.get_boss().get_mover() if _combat.get_boss() != null else null


# One update of [param side]: consume a pending step (its length = the cooldown just started), run the
# timers and the running clip down by [param step], then pick the clip with [method clip_for] for the
# state reached and start / keep it on the animator (a clip started now shows its frame 0 this update).
func _update_clip(side: int, step: float) -> void:
	if bool(_step_pending.get(side, false)):
		_step_pending[side] = false
		var mover: UnitMover = _mover_of(side)
		_step_left[side] = maxf(mover.get_cooldown_remaining(), 0.0) if mover != null else 0.0
	_hit_left[side] = maxf(float(_hit_left.get(side, 0.0)) - step, 0.0)
	_step_left[side] = maxf(float(_step_left.get(side, 0.0)) - step, 0.0)
	var anim: UnitAnimator = get_animator(side)
	if anim != null:
		anim.tick(step)
	var want: String = clip_for(clip_context(side))
	# Task 5 item 6: a unit whose sheet has no `fall` clip keeps its normal death.
	if want == CLIP_FALL and (get_sheet(side) == null or not get_sheet(side).has_clip(CLIP_FALL)):
		want = CLIP_DEFEAT if side == CombatState.Side.PLAYER else CLIP_DOWN
	_logical_clip[side] = want
	if anim == null:
		return
	match want:
		CLIP_HIT:
			if bool(_hit_restart.get(side, false)):
				_hit_restart[side] = false
				anim.play(CLIP_HIT, true)
			else:
				anim.play(CLIP_HIT)
		CLIP_CAST:
			if _cast_pending:
				_cast_pending = false
				anim.play(CLIP_CAST, true)
			else:
				anim.play(CLIP_CAST)
			_drive_cast_hold(side, anim)
		CLIP_STEP:
			var step_clip: String = String(_step_clip.get(side, CLIP_STEP))
			if get_sheet(side) == null or not get_sheet(side).has_clip(step_clip):
				step_clip = CLIP_STEP
			if step_clip == CLIP_STEP:
				if anim.current_clip() != step_clip or anim.is_finished():
					anim.play_timed(step_clip, float(_step_left[side]), UnitAnimator.ONCE)
			elif anim.current_clip() != step_clip or bool(_step_restart.get(side, false)):
				_step_restart[side] = false
				# A directional dash keeps its own frame times (50 ms), so its lean meets the glide instead of being
				# stretched over the whole step cooldown; it holds its last (settled) frame until the step ends.
				anim.play(step_clip, true)
		_:
			# The match-start draw runs to its end before the idle (any other clip cuts in at once).
			if want == CLIP_IDLE and anim.current_clip() == CLIP_DRAW and not anim.is_finished():
				return
			anim.play(want)


func _feet_of_cell(cell: Vector2i) -> Vector2i:
	var rect: Rect2i = _cell_art_rect(cell)
	@warning_ignore("integer_division")
	var x: int = rect.position.x + rect.size.x / 2
	var y: int = mini(rect.position.y + roundi(rect.size.y * FEET_DEPTH_RATIO), rect.end.y - FEET_INSET_ART)
	return _warp_feet(Vector2i(x, y))


# ADR-0002: the flat feet anchor moved onto the drawn board (BoardGeometry.warp_art_px; the sprite is never scaled).
func _warp_feet(feet: Vector2i) -> Vector2i:
	return _bg().warp_art_px(feet)


## ADR-0002: the board geometry the layer draws with (BoardGeometry.of the bound CombatView; flat when unbound).
func board_geometry() -> BoardGeometry:
	return _bg()


func _bg() -> BoardGeometry:
	var geo: BoardGeometry = BoardGeometry.of(_combat)
	if geo == null:
		geo = BoardGeometry.make(_combat.get_grid(), _combat.get_viewport_rect().size)
	return geo


## The ground shadow of a unit standing in a rect of [param rect_size] (its cell, or a multi-cell footprint, P2.2b) (art px): a stepped Ink ellipse centred on the feet, one
## 1 px row per draw_rect so the edge stays on whole pixels. Pure geometry in [method shadow_rows]. ADR-0002: on the
## perspective board the ellipse is sized by the floor's local scale at the feet ([method shadow_size]), still flat-stepped.
func _draw_shadow(rect_size: Vector2i, feet: Vector2i) -> void:
	for row: Rect2i in shadow_rows(shadow_size(rect_size, feet), feet):
		draw_rect(Rect2(row), SHADOW_COLOR)


## ADR-0002: the rect size the ground shadow at drawn feet [param feet] is computed for: [param rect_size] (the flat
## cell / footprint) times the floor's local scale there (rows at the back are narrower and shorter); unchanged flat.
func shadow_size(rect_size: Vector2i, feet: Vector2i) -> Vector2i:
	var geo: BoardGeometry = _bg()
	if not geo.is_warped():
		return rect_size
	var k: Vector2 = geo.art_local_scale(geo.unwarp_art(Vector2(feet) + Vector2(0.5, 0.5)))
	return Vector2i(roundi(rect_size.x * k.x), roundi(rect_size.y * k.y))


## Rows of the ground shadow for a cell of [param cell_size] with the feet at [param feet]: one Rect2i per
## pixel row, widest at the feet row, integer art px.
static func shadow_rows(cell_size: Vector2i, feet: Vector2i) -> Array[Rect2i]:
	var rows: Array[Rect2i] = []
	var half_w: float = cell_size.x * SHADOW_WIDTH_RATIO * 0.5
	var h: int = maxi(SHADOW_MIN_HEIGHT, roundi(cell_size.y * SHADOW_HEIGHT_RATIO))
	var half_h: float = h * 0.5
	for i: int in h:
		var dy: float = (i + 0.5) - half_h
		var t: float = clampf(1.0 - (dy * dy) / (half_h * half_h), 0.0, 1.0)
		var w: int = roundi(half_w * sqrt(t)) * 2
		if w <= 0:
			continue
		@warning_ignore("integer_division")
		rows.append(Rect2i(feet.x - w / 2, feet.y - roundi(half_h) + i, w, 1))
	return rows


func _cell_art_rect(cell: Vector2i) -> Rect2i:
	return _bg().cell_art_rect(cell)


func _cell_of(side: int) -> Vector2i:
	var state: CombatState = _combat.get_state()
	return state.player_cell if side == CombatState.Side.PLAYER else state.enemy_cell


# P2.2b (D13): the art rect a unit stands in: its cell, or the bounding rect of a multi-cell enemy's footprint.
func _unit_art_rect(side: int) -> Rect2i:
	var state: CombatState = _combat.get_state()
	if side == CombatState.Side.PLAYER or state.enemy_footprint_size() <= 1:
		return _cell_art_rect(_cell_of(side))
	var out: Rect2i = Rect2i()
	var first: bool = true
	for cell: Vector2i in state.enemy_footprint_cells():
		var r: Rect2i = _cell_art_rect(cell)
		out = r if first else out.merge(r)
		first = false
	return out


# P2.2b: the feet anchor of [param side]: [method _feet_of_cell] of its cell; for a multi-cell enemy x = the centre of
# the footprint's bounding rect and y = the feet row of the footprint's FRONT (bottom) row, so the body stands on the
# footprint the way a 1-cell unit stands on its cell.
func _feet_of_unit(side: int) -> Vector2i:
	var state: CombatState = _combat.get_state()
	if side == CombatState.Side.PLAYER or state.enemy_footprint_size() <= 1:
		return _feet_of_cell(_cell_of(side))
	var rect: Rect2i = _unit_art_rect(side)
	var bottom: Vector2i = state.enemy_cell + Vector2i(0, state.footprint_extent().y - 1)
	var bottom_rect: Rect2i = _cell_art_rect(bottom)
	var y: int = mini(bottom_rect.position.y + roundi(bottom_rect.size.y * FEET_DEPTH_RATIO), bottom_rect.end.y - FEET_INSET_ART)
	@warning_ignore("integer_division")
	return _warp_feet(Vector2i(rect.position.x + rect.size.x / 2, y))


# P2.2b: the cell the status overlays read (burn): a burning footprint cell when any burns, else the unit's cell.
func _status_cell(side: int) -> Vector2i:
	var state: CombatState = _combat.get_state()
	if side == CombatState.Side.ENEMY and state.enemy_footprint_size() > 1 and _combat.get_status() != null:
		for cell: Vector2i in state.enemy_footprint_cells():
			if _combat.get_status().is_burning(cell):
				return cell
	return _cell_of(side)


# Alive for the overlays: the player while not dead; the boss while not dead OR downed (Story 035: downed
# is 0 HP kept on the board, and its cell may still burn).
func _is_alive(side: int) -> bool:
	var state: CombatState = _combat.get_state()
	if side == CombatState.Side.PLAYER:
		return not state.is_player_dead()
	return not state.is_enemy_dead() or _combat.is_boss_downed()


# Advances the clock of every active kind by [param step] match seconds; a kind that just started
# begins at 0, a kind that ended is dropped (so it restarts from 0 next time).
func _advance_status_clocks(step: float) -> void:
	for side: int in SIDES:
		var kinds: Array[String] = get_active_status_kinds(side)
		if not _status_clock.has(side):
			_status_clock[side] = {}
		var clock: Dictionary = _status_clock[side]
		for key: Variant in clock.keys():
			if not kinds.has(String(key)):
				clock.erase(key)
		for kind: String in kinds:
			if clock.has(kind):
				clock[kind] = float(clock[kind]) + maxf(step, 0.0)
			else:
				clock[kind] = 0.0


func _draw() -> void:
	if _combat == null or _combat.get_state() == null:
		return
	# Draw order (art bible 8.6): back row first, then left to right; the player before the boss on a tie.
	var units: Array[Dictionary] = [
		{"side": CombatState.Side.PLAYER, "cell": _cell_of(CombatState.Side.PLAYER)},
		{"side": CombatState.Side.ENEMY, "cell": _cell_of(CombatState.Side.ENEMY) + Vector2i(0, _combat.get_state().footprint_extent().y - 1)},
	]
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.y != cb.y:
			return ca.y < cb.y
		if ca.x != cb.x:
			return ca.x < cb.x
		return int(a["side"]) < int(b["side"]))
	for side: int in SIDES:
		_draw_dust(side)
	for unit: Dictionary in units:
		var side: int = int(unit["side"])
		var cell: Vector2i = _cell_of(side)
		var kinds: Array[String] = get_active_status_kinds(side)
		var ground: Vector2i = _ground_of(side)
		_draw_shadow(_unit_art_rect(side).size, ground)
		var feet: Vector2i = ground + shake_offset(float(_shake_left.get(side, 0.0)), int(_feel.get("shake_px", 0)))
		_draw_status_overlays(side, kinds, feet, CLIP_BEHIND)
		if not _draw_sprite(side, feet):
			if side == CombatState.Side.PLAYER:
				_draw_player_marker(cell)
			else:
				_draw_enemy(_unit_art_rect(side))
		_draw_status_overlays(side, kinds, feet, CLIP_FRONT)


# The add-blend child the hit flash draws on (created once; children draw over the units).
func _ensure_flash_layer() -> void:
	if _flash != null:
		return
	_flash = Node2D.new()
	_flash.name = "HitFlash"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = mat
	add_child(_flash)
	_flash.draw.connect(_draw_flash)


# OSFE hit feel: the current frame of each unit with flash left, added over itself in white (fading out), so the
# body flashes bright for flash_sec.
func _draw_flash() -> void:
	if _combat == null or _combat.get_state() == null:
		return
	var total: float = maxf(float(_feel.get("flash_sec", 0.0)), 0.001)
	for side: int in SIDES:
		var left: float = float(_flash_left.get(side, 0.0))
		var sheet: SpriteSheet = get_sheet(side)
		var anim: UnitAnimator = get_animator(side)
		if left <= 0.0 or sheet == null or anim == null or sheet.texture() == null:
			continue
		var src: Rect2i = anim.frame_rect()
		if src.size.x <= 0 or src.size.y <= 0:
			continue
		var feet: Vector2i = _feet_of_unit(side) + shake_offset(float(_shake_left.get(side, 0.0)), int(_feel.get("shake_px", 0)))
		var dest: Rect2 = sprite_dest_rect(feet, src.size, sheet.facing() != facing_for(side))
		var alpha: float = float(_feel.get("flash_alpha", 0.75)) * clampf(left / total, 0.0, 1.0)
		_flash.draw_texture_rect_region(sheet.texture(), dest, Rect2(src), Color(1.0, 1.0, 1.0, alpha))


# The sprite of [param side] at the feet anchor: the animator's frame from the sheet texture, mirrored
# when the sheet faces away from the divider; the downed boss tinted DOWNED_COLOR, the invulnerable
# boss outlined around the frame. False (nothing drawn) for a placeholder unit.
func _draw_sprite(side: int, feet: Vector2i) -> bool:
	var sheet: SpriteSheet = get_sheet(side)
	var anim: UnitAnimator = get_animator(side)
	if sheet == null or anim == null:
		return false
	var texture: Texture2D = sheet.texture()
	var src: Rect2i = anim.frame_rect()
	if texture == null or src.size.x <= 0 or src.size.y <= 0:
		return false
	var dest: Rect2 = sprite_dest_rect(feet, src.size, sheet.facing() != facing_for(side))
	var tint: Color = Color.WHITE
	var state: CombatState = _combat.get_state()
	if side == CombatState.Side.ENEMY and _combat.is_boss_downed():
		tint = DOWNED_COLOR
	draw_texture_rect_region(texture, dest, Rect2(src), tint)
	if side == CombatState.Side.ENEMY and not state.is_enemy_dead() and state.enemy_invulnerable_left > 0.0:
		draw_rect(dest.abs().grow(INVULNERABLE_GROW_ART), INVULNERABLE_OUTLINE, false, BODY_OUTLINE_ART)
	return true


# One clip ([param clip_name]) of every active pack of [param side] at the feet anchor; a missing pack
# or sheet draws nothing (StatusPacks / VfxPack warned once).
func _draw_status_overlays(side: int, kinds: Array[String], feet: Vector2i, clip_name: String) -> void:
	for kind: String in kinds:
		var pack: VfxPack = StatusPacks.pack(kind, frame_kind_of(side))
		if pack == null:
			continue
		var frame: int = overlay_frame(get_status_elapsed(side, kind), pack, _reduce_motion)
		pack.draw_clip(self, clip_name, feet, frame)


# The player's placeholder: a circle with the character name, centred in the cell.
func _draw_player_marker(cell: Vector2i) -> void:
	var state: CombatState = _combat.get_state()
	var rect := Rect2(_cell_art_rect(cell))
	# ADR-0002: centred on the drawn cell centre, sized by the floor's local scale there.
	var geo: BoardGeometry = _bg()
	var c: Vector2 = geo.warp_art(rect.get_center()).floor()
	var k: Vector2 = geo.art_local_scale(rect.get_center())
	var radius: float = floorf(rect.size.y * MARKER_RADIUS_RATIO * minf(k.x, k.y))
	var color: Color = ENEMY_DEAD_COLOR if state.is_player_dead() else PLAYER_COLOR
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0.0, TAU, MARKER_ARC_POINTS, TEXT_COLOR, MARKER_OUTLINE_ART)
	var font_size: int = maxi(int(radius * MARKER_FONT_RATIO), MARKER_MIN_FONT_SIZE)
	var text: String = _combat.get_player_name()
	var max_width: float = radius * 2.0 * MARKER_TEXT_FILL
	# Auto-fit (Story 018): shrink the font to MARKER_MIN_FONT_SIZE, then fall back to the first word.
	while font_size > MARKER_MIN_FONT_SIZE and _text_width(text, font_size) > max_width:
		font_size -= 1
	if _text_width(text, font_size) > max_width and text.contains(" "):
		text = text.get_slice(" ", 0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-radius, floorf(font_size * 0.4)), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)


# The boss's placeholder body in flat art px: a rect centred in [param area] (its cell, or the bounding rect of a
# multi-cell footprint, P2.2b: the body fills the footprint with the same margins).
static func enemy_body_rect(area: Rect2i) -> Rect2:
	var rect := Rect2(area)
	var body_size := Vector2(floorf(rect.size.x * ENEMY_BODY_WIDTH_RATIO), floorf(rect.size.y * ENEMY_BODY_HEIGHT_RATIO))
	return Rect2((rect.get_center() - body_size * 0.5).floor(), body_size)


## ADR-0002: the drawn polygon of the boss placeholder (art px): its footprint's body rect (an inset of the footprint,
## [method enemy_body_rect]) through BoardGeometry.art_quad, so on the perspective board it is the warped footprint
## polygon inset; the plain body rect's corners while flat. Empty when unbound.
func enemy_placeholder_polygon() -> PackedVector2Array:
	if _combat == null or _combat.get_state() == null:
		return PackedVector2Array()
	return _bg().art_quad(enemy_body_rect(_unit_art_rect(CombatState.Side.ENEMY)))


# The boss's placeholder: the body ([method enemy_body_rect] of [param area]) drawn as the mapped quad of the floor
# (ADR-0002); Story 035 kneeling when downed, an outline while invulnerable, grey with a cross when dead.
func _draw_enemy(area: Rect2i) -> void:
	var state: CombatState = _combat.get_state()
	var dead: bool = state.is_enemy_dead()
	var geo: BoardGeometry = _bg()
	var body: Rect2 = enemy_body_rect(area)
	if _combat.is_boss_downed():
		var kneel_h: float = floorf(body.size.y * DOWNED_BODY_HEIGHT_RATIO)
		var kneel := Rect2(Vector2(body.position.x, body.end.y - kneel_h), Vector2(body.size.x, kneel_h))
		_fill_art(geo, kneel, DOWNED_COLOR)
		_outline_art(geo, kneel, Color(TEXT_COLOR, 0.6), BODY_OUTLINE_ART)
		return
	_fill_art(geo, body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	_outline_art(geo, body, TEXT_COLOR, BODY_OUTLINE_ART)
	if not dead and state.enemy_invulnerable_left > 0.0:
		_outline_art(geo, body.grow(INVULNERABLE_GROW_ART), INVULNERABLE_OUTLINE, BODY_OUTLINE_ART)
	if dead:
		draw_line(geo.warp_art(body.position), geo.warp_art(body.end), TEXT_COLOR, DEAD_CROSS_ART)
		draw_line(geo.warp_art(Vector2(body.end.x, body.position.y)), geo.warp_art(Vector2(body.position.x, body.end.y)), TEXT_COLOR, DEAD_CROSS_ART)


# ADR-0002: flat art rect [param rect] filled as its drawn quad (draw_rect while flat).
func _fill_art(geo: BoardGeometry, rect: Rect2, color: Color) -> void:
	if not geo.is_warped():
		draw_rect(rect, color)
		return
	draw_colored_polygon(geo.art_quad(rect), color)


# ADR-0002: flat art rect [param rect] outlined as its drawn quad (draw_rect unfilled while flat).
func _outline_art(geo: BoardGeometry, rect: Rect2, color: Color, width: float) -> void:
	if not geo.is_warped():
		draw_rect(rect, color, false, width)
		return
	BoardGeometry.draw_polygon_outline(self, geo.art_quad(rect), color, width)


# Width of [param text] in the fallback font at [param font_size] (art px).
func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
