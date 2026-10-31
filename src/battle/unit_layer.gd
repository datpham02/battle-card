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
## `kiem_si` 96x70 (v3 tall anchor, 2026-10-31), Goblin Scout `goblin_scout` 32x48) is drawn from it with one [UnitAnimator] per side,
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
## Unit frame kinds of the status packs: the hero packs were made on the v1 40x48 frame (the v3 hero is 96x70, body about 31x66), the boss packs on its 32x48 frame.
const FRAME_KIND_HERO: String = "hero"
const FRAME_KIND_GOBLIN: String = "goblin"
## Pack clips drawn under and over the unit (art bible 8.6).
const CLIP_BEHIND: String = "behind"
const CLIP_FRONT: String = "front"

## Sheet clips (the frameTags of Story 045's sheets; `fall` is unused until the falling-cell story).
const CLIP_IDLE: String = "idle"
const CLIP_STEP: String = "step"
const CLIP_CAST: String = "cast_gesture"
const CLIP_HIT: String = "hit"
const CLIP_WINDUP: String = "windup"
const CLIP_VICTORY: String = "victory"
const CLIP_DEFEAT: String = "defeat"
const CLIP_DOWN: String = "down"
const CLIP_AWAKEN: String = "awaken"
## Seconds the `hit` clip outranks step / windup after a damage event (story table, Part C).
const HIT_SEC: float = 0.12
## Facing each side must show: towards the divider (art bible 8.6).
const FACING_PLAYER: String = "right"
const FACING_ENEMY: String = "left"
## Keys of the context [method clip_for] reads (all booleans but `side`).
const CTX_SIDE: String = "side"
const CTX_DEAD: String = "dead"
const CTX_DOWNED: String = "downed"
const CTX_OPPONENT_DEAD: String = "opponent_dead"
const CTX_HIT: String = "hit"
const CTX_CASTING: String = "casting"
const CTX_SWINGING: String = "swinging"
const CTX_AWAKEN: String = "awaken"
const CTX_STEPPING: String = "stepping"
## The two sides, in the order the per-side tables are walked.
const SIDES: Array[int] = [CombatState.Side.PLAYER, CombatState.Side.ENEMY]

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
	_bind_match()
	queue_redraw()


func _process(delta: float) -> void:
	if _combat != null:
		advance(_combat.scaled_delta(delta))
	queue_redraw()


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
		_update_clip(side, maxf(step, 0.0))


## Bottom-centre anchor of the unit of [param side] (CombatState.Side) in whole art px: x = the cell's
## centre, y = the cell's bottom edge minus FEET_INSET_ART. Vector2i(-1, -1) when unbound.
func unit_feet_art(side: int) -> Vector2i:
	if _combat == null or _combat.get_state() == null:
		return Vector2i(-1, -1)
	return _feet_of_cell(_cell_of(side))


## Feet anchor for any board cell (the rule of [method unit_feet_art]).
func feet_art_of_cell(cell: Vector2i) -> Vector2i:
	return _feet_of_cell(cell)


## Status overlay kinds the unit of [param side] wears right now, in draw order (burn, then frozen or
## chill). Empty when unbound or when the unit is dead (a downed boss is not dead for this purpose).
func get_active_status_kinds(side: int) -> Array[String]:
	if _combat == null or _combat.get_state() == null:
		return []
	return status_kinds_for(_combat.get_status(), side, _cell_of(side), _is_alive(side))


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
	var casting: bool = _cast_pending or (anim != null and anim.current_clip() == CLIP_CAST and not anim.is_finished())
	var boss_actor: CutActor = _combat.get_boss().get_actor() if _combat.get_boss() != null else null
	return {
		CTX_SIDE: side,
		CTX_DEAD: state.is_player_dead() if player else state.is_enemy_dead(),
		CTX_DOWNED: (not player) and _combat.is_boss_downed(),
		CTX_OPPONENT_DEAD: state.is_enemy_dead() if player else state.is_player_dead(),
		CTX_HIT: get_hit_left(side) > 0.0,
		CTX_CASTING: player and casting,
		CTX_SWINGING: (not player) and boss_actor != null and boss_actor.is_swinging(),
		CTX_AWAKEN: player and _combat.is_signature_active(),
		CTX_STEPPING: get_step_left(side) > 0.0,
	}


## The clip for a unit's state, pure (Story 047 Part C table). [param ctx] keys: `side`
## (CombatState.Side, default PLAYER) and the booleans `dead`, `downed`, `opponent_dead`, `hit`,
## `casting`, `swinging`, `awaken`, `stepping` (absent = false). Priority, highest first:
## dead or downed -> `defeat` (player) / `down` (boss); player with the boss dead -> `victory`;
## hit -> `hit`; player casting -> `cast_gesture`; boss swinging -> `windup`; player with the signature
## running -> `awaken`; stepping -> `step`; else `idle`.
static func clip_for(ctx: Dictionary) -> String:
	var player: bool = int(ctx.get(CTX_SIDE, CombatState.Side.PLAYER)) == CombatState.Side.PLAYER
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
		anim.play(CLIP_IDLE)
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
		CLIP_STEP:
			if anim.current_clip() != CLIP_STEP or anim.is_finished():
				anim.play_timed(CLIP_STEP, float(_step_left[side]), UnitAnimator.ONCE)
		_:
			anim.play(want)


func _feet_of_cell(cell: Vector2i) -> Vector2i:
	var rect: Rect2i = _cell_art_rect(cell)
	@warning_ignore("integer_division")
	var x: int = rect.position.x + rect.size.x / 2
	var y: int = mini(rect.position.y + roundi(rect.size.y * FEET_DEPTH_RATIO), rect.end.y - FEET_INSET_ART)
	return Vector2i(x, y)


## The ground shadow of a unit standing on [param cell] (art px): a stepped Ink ellipse centred on the feet, one
## 1 px row per draw_rect so the edge stays on whole pixels. Pure geometry in [method shadow_rows].
func _draw_shadow(cell: Vector2i, feet: Vector2i) -> void:
	for row: Rect2i in shadow_rows(_cell_art_rect(cell).size, feet):
		draw_rect(Rect2(row), SHADOW_COLOR)


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
	var vp: Vector2 = _combat.get_viewport_rect().size
	return ScreenLayout.to_art_rect(vp, ScreenLayout.cell_rect(_combat.get_grid(), vp, cell))


func _cell_of(side: int) -> Vector2i:
	var state: CombatState = _combat.get_state()
	return state.player_cell if side == CombatState.Side.PLAYER else state.enemy_cell


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
		{"side": CombatState.Side.ENEMY, "cell": _cell_of(CombatState.Side.ENEMY)},
	]
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.y != cb.y:
			return ca.y < cb.y
		if ca.x != cb.x:
			return ca.x < cb.x
		return int(a["side"]) < int(b["side"]))
	for unit: Dictionary in units:
		var side: int = int(unit["side"])
		var cell: Vector2i = unit["cell"]
		var kinds: Array[String] = get_active_status_kinds(side)
		var feet: Vector2i = _feet_of_cell(cell)
		_draw_shadow(cell, feet)
		_draw_status_overlays(side, kinds, feet, CLIP_BEHIND)
		if not _draw_sprite(side, feet):
			if side == CombatState.Side.PLAYER:
				_draw_player_marker(cell)
			else:
				_draw_enemy(cell)
		_draw_status_overlays(side, kinds, feet, CLIP_FRONT)


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
	var c: Vector2 = rect.get_center().floor()
	var radius: float = floorf(rect.size.y * MARKER_RADIUS_RATIO)
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


# The boss's placeholder: a square body centred in the cell; Story 035 kneeling when downed, an
# outline while invulnerable, grey with a cross when dead.
func _draw_enemy(cell: Vector2i) -> void:
	var state: CombatState = _combat.get_state()
	var dead: bool = state.is_enemy_dead()
	var rect := Rect2(_cell_art_rect(cell))
	var body_size := Vector2(floorf(rect.size.x * ENEMY_BODY_WIDTH_RATIO), floorf(rect.size.y * ENEMY_BODY_HEIGHT_RATIO))
	var body := Rect2((rect.get_center() - body_size * 0.5).floor(), body_size)
	if _combat.is_boss_downed():
		var kneel_h: float = floorf(body_size.y * DOWNED_BODY_HEIGHT_RATIO)
		var kneel := Rect2(Vector2(body.position.x, body.end.y - kneel_h), Vector2(body_size.x, kneel_h))
		draw_rect(kneel, DOWNED_COLOR)
		draw_rect(kneel, Color(TEXT_COLOR, 0.6), false, BODY_OUTLINE_ART)
		return
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, BODY_OUTLINE_ART)
	if not dead and state.enemy_invulnerable_left > 0.0:
		draw_rect(body.grow(INVULNERABLE_GROW_ART), INVULNERABLE_OUTLINE, false, BODY_OUTLINE_ART)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, DEAD_CROSS_ART)
		draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, DEAD_CROSS_ART)


# Width of [param text] in the fallback font at [param font_size] (art px).
func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
