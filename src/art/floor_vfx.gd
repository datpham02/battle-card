class_name FloorVfx
extends RefCounted
## Story 048 Part B: the nine PixelLab floor-VFX packs (assets/art/vfx/floor/index.json) and their clock.
## One instance per battle (CombatView.get_floor_vfx). It owns the effects clock (ticked with the combat's scaled
## delta, so Focus / pause freeze it), a one-shot event queue (hit, miss, interrupt, thorn, formation complete) and
## the start time of held effects (cracked cells). FloorDynamicLayer (layer "floor", under the units) and
## OverlayLayer (layer "overlay", above them) read it and draw with [method draw].
## Index entry keys: id, dir, layer (floor | overlay), play (loop | once | once_hold), clip, frames, frame_ms,
## hold_frame (once_hold), tint (optional, e.g. "hero_block").
## A pack that fails to load (or whose sheet is not imported) is reported once and [method has_pack] is false for
## it: the caller keeps its old code drawing for that effect.
## Implements: Story 048 Part B.

const INDEX_PATH: String = "res://assets/art/vfx/floor/index.json"
const DEFAULT_CLIP: String = "whole"
const DEFAULT_FRAME_MS: int = 83
const LAYER_FLOOR: String = "floor"
const LAYER_OVERLAY: String = "overlay"
const PLAY_LOOP: String = "loop"
const PLAY_ONCE: String = "once"
const PLAY_ONCE_HOLD: String = "once_hold"
## Index `anchor` value: the clip's frame is centred on the cell (non-fill packs; fill packs are centred already).
const ANCHOR_CENTER: String = "center"
## Index `anchor` value: the pack's feet (its ground point) on the cell centre, for bursts rising out of the cell.
const ANCHOR_GROUND_CENTER: String = "ground_center"

## Loaded once per index path: path -> {"entries": {id: entry}, "packs": {id: VfxPack or null}}.
static var _cache: Dictionary = {}

var _entries: Dictionary = {}
var _packs: Dictionary = {}
var _clock: float = 0.0
## One-shots: {id, cell, side, age}.
var _events: Array[Dictionary] = []
## Held effects: group -> {key: start clock}.
var _holds: Dictionary = {}


func _init(index_path: String = INDEX_PATH) -> void:
	if not _cache.has(index_path):
		_cache[index_path] = _load(index_path)
	var data: Dictionary = _cache[index_path]
	_entries = data["entries"]
	_packs = data["packs"]


## Bottom-centre of a cell's art rect: the anchor every floor pack was made on (integer art px).
static func feet_for(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.get_center().x, rect.end.y)


## Pure: the frame of [param entry] at [param elapsed] seconds. loop wraps; once runs 0..frames-1 then returns -1;
## once_hold stops on hold_frame. Reduce motion = one representative frame (loop 0, once_hold hold_frame, once its
## middle frame, still -1 after the one-shot's length). -1 also for an empty entry.
static func frame_for(entry: Dictionary, elapsed: float, reduce_motion: bool) -> int:
	var frames: int = int(entry.get("frames", 0))
	if frames <= 0:
		return -1
	var frame_ms: int = maxi(1, int(entry.get("frame_ms", DEFAULT_FRAME_MS)))
	var play: String = str(entry.get("play", PLAY_LOOP))
	var hold: int = clampi(int(entry.get("hold_frame", frames - 1)), 0, frames - 1)
	var index: int = int(floor(maxf(elapsed, 0.0) * 1000.0 / float(frame_ms)))
	match play:
		PLAY_ONCE:
			if index >= frames:
				return -1
			return frames >> 1 if reduce_motion else index
		PLAY_ONCE_HOLD:
			return hold if reduce_motion else mini(index, hold)
		_:
			return 0 if reduce_motion else index % frames


## The index entry of [param id] ({} when unknown).
func entry(id: String) -> Dictionary:
	return _entries.get(id, {})


## The loaded pack of [param id]; null when unknown or when it failed to load.
func pack(id: String) -> VfxPack:
	return _packs.get(id, null)


## True when [param id] can be drawn (pack loaded and its clip's sheet is available).
func has_pack(id: String) -> bool:
	var p: VfxPack = pack(id)
	if p == null:
		return false
	var c: Dictionary = p.clip(str(entry(id).get("clip", DEFAULT_CLIP)))
	return not c.is_empty() and c.get("texture", null) != null


func ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _entries:
		out.append(str(key))
	return out


## Effects seconds so far (only [method tick] moves it).
func elapsed() -> float:
	return _clock


## Advances the clock and the one-shots by [param delta] (the combat's scaled delta) and drops finished events.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_clock += delta
	var kept: Array[Dictionary] = []
	for ev: Dictionary in _events:
		ev["age"] = float(ev["age"]) + delta
		if frame_for(entry(str(ev["id"])), float(ev["age"]), false) >= 0:
			kept.append(ev)
	_events = kept


## Queues one-shot [param id] on [param cell] of [param side]. Ignored when the pack is not drawable (the caller's
## old drawing stays in that case).
## [param delay] seconds hold it back (OSFE staggered blasts): it is not drawn until then.
func play(id: String, cell: Vector2i, side: int = 0, delay: float = 0.0) -> void:
	if not has_pack(id):
		return
	_events.append({"id": id, "cell": cell, "side": side, "age": -maxf(delay, 0.0)})


## The running one-shots (copies), optionally only those of [param layer]; a delayed one only once its delay ran out.
func active_events(layer: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in _events:
		if float(ev["age"]) < 0.0:
			continue
		if layer.is_empty() or str(entry(str(ev["id"])).get("layer", LAYER_FLOOR)) == layer:
			out.append(ev.duplicate())
	return out


func clear_events() -> void:
	_events.clear()


## Held effects (once_hold): records the start of every new key of [param keys] in [param group], forgets keys no
## longer present, and returns key -> seconds since it appeared.
func hold_ages(group: String, keys: Array) -> Dictionary:
	var starts: Dictionary = _holds.get(group, {})
	var next: Dictionary = {}
	var out: Dictionary = {}
	for key: Variant in keys:
		var start: float = float(starts.get(key, _clock))
		next[key] = start
		out[key] = _clock - start
	_holds[group] = next
	return out


## Prefix of a cell-size variant id: "<id>_c<w>x<h>" (tools/fx-pipeline packs made for another cell size).
const VARIANT_INFIX: String = "_c"


## The id to draw for [param id] on a cell of [param cell_size] (art px): among [param id] and its drawable variants
## "<id>_c<w>x<h>", the one whose index `cell` [w, h] is nearest the cell (height first, then width). [param id] itself
## when it has no `cell`, no variant is drawable, or [param cell_size] is empty. Pure on the loaded index; never scales.
func variant_for(id: String, cell_size: Vector2i) -> String:
	var base: Variant = entry(id).get("cell", null)
	if cell_size.x <= 0 or cell_size.y <= 0 or not (base is Array) or (base as Array).size() != 2:
		return id
	var best: String = id
	var best_cost: int = _cell_cost(base as Array, cell_size)
	for key: Variant in _entries:
		var k: String = str(key)
		if not k.begins_with(id + VARIANT_INFIX) or not has_pack(k):
			continue
		var c: Variant = entry(k).get("cell", null)
		if not (c is Array) or (c as Array).size() != 2:
			continue
		var cost: int = _cell_cost(c as Array, cell_size)
		if cost < best_cost:
			best_cost = cost
			best = k
	return best


static func _cell_cost(cell: Array, size: Vector2i) -> int:
	return absi(int(cell[1]) - size.y) * 1000 + absi(int(cell[0]) - size.x)


## Draws [param frame] of [param id]'s clip with its anchor at [param feet] (art px), tinted by [param tint].
## False when the pack is unavailable or the frame is negative. With a [param clip_rect], a pack that has cell-size
## variants is drawn in the one made for the nearest cell ([method variant_for]; same frame count by construction).
func draw(canvas: CanvasItem, id: String, feet: Vector2i, frame: int, tint: Color = Color.WHITE, clip_rect: Rect2i = Rect2i()) -> bool:
	if frame < 0 or canvas == null:
		return false
	if clip_rect.has_area():
		id = variant_for(id, clip_rect.size)
	var p: VfxPack = pack(id)
	if p == null:
		return false
	# Story 048: a "fill" pack is made on the largest cell (`ref_cell`, 64x46) to cover its whole face: its face centre
	# goes on the cell's centre (feet = centre + half the reference height) and it is cropped to the cell it plays on.
	var e: Dictionary = entry(id)
	var crop := Rect2i()
	var at: Vector2i = feet
	var clip_name: String = str(e.get("clip", DEFAULT_CLIP))
	if bool(e.get("fill", false)) and clip_rect.has_area():
		crop = clip_rect
		var ref_h: int = int((e.get("ref_cell", [64, 46]) as Array)[1])
		var c: Vector2i = clip_rect.position + clip_rect.size / 2
		at = Vector2i(c.x, c.y + ref_h / 2)
	elif str(e.get("anchor", "")) == ANCHOR_GROUND_CENTER and clip_rect.has_area():
		at = clip_rect.position + clip_rect.size / 2
	elif str(e.get("anchor", "")) == ANCHOR_CENTER and clip_rect.has_area():
		var data: Dictionary = p.clip(clip_name)
		if not data.is_empty():
			at = centre_anchor(clip_rect, data["offset"], data["frame_size"])
	return p.draw_clip(canvas, clip_name, at, frame, tint, crop)


## Pure: the feet point that puts the middle of a clip frame ([param offset] from the feet, [param frame_size]) on
## the centre of [param cell_rect]: every floor effect sits in the middle of its cell (user 2026-11-01).
static func centre_anchor(cell_rect: Rect2i, offset: Vector2i, frame_size: Vector2i) -> Vector2i:
	var c: Vector2i = cell_rect.position + cell_rect.size / 2
	return c - offset - frame_size / 2


static func _load(index_path: String) -> Dictionary:
	var out: Dictionary = {"entries": {}, "packs": {}}
	if not FileAccess.file_exists(index_path):
		push_warning("FloorVfx: no index at %s; floor effects use the old drawing" % index_path)
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not (data is Dictionary) or not ((data as Dictionary).get("packs", null) is Dictionary):
		push_warning("FloorVfx: malformed index at %s" % index_path)
		return out
	var packs: Dictionary = (data as Dictionary)["packs"]
	for id: Variant in packs:
		if not (packs[id] is Dictionary):
			continue
		var e: Dictionary = (packs[id] as Dictionary).duplicate()
		e["id"] = str(id)
		out["entries"][str(id)] = e
		var dir: String = index_path.get_base_dir().path_join(str(e.get("dir", id)))
		var p: VfxPack = VfxPack.load_pack(dir)
		if p != null and not p.has_clip(str(e.get("clip", DEFAULT_CLIP))):
			push_warning("FloorVfx: pack %s has no clip %s" % [id, e.get("clip", DEFAULT_CLIP)])
			p = null
		if p != null:
			# The clip may start after frame 0 of the pack (an empty lead frame trimmed): its own frame count is
			# what plays; the index's pack-level count is kept as `pack_frames`.
			e["pack_frames"] = int(e.get("frames", 0))
			e["frames"] = int(p.clip(str(e.get("clip", DEFAULT_CLIP))).get("frames", 0))
		out["packs"][str(id)] = p
	return out
