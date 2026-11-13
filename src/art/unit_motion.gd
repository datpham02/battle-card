class_name UnitMotion
extends RefCounted
## Unit motion pass (2026-11-13, production/qa/evidence/unit-motion/audit.md): the per-unit motion profile and the
## pure pose math [UnitLayer] draws on top of the sheet clips. Data: `assets/art/units/unit_motion.json` (archetypes
## + unit id -> archetype / overrides; an unlisted id uses `default`).
##
## A pose is a Vector4i(body_x, body_y, lean, squash) in whole art px (art bible 8.10: no rotation, no non-integer
## scale, no half pixels): body_x / body_y move the whole frame (hop, hover, overshoot); lean moves the head band
## along screen x (the torso band gets half, rounded toward zero); squash pushes the torso and head bands DOWN over
## the legs band (never up, so no gap opens). The legs band never moves, so the feet stay pinned. Every function is
## pure and returns a value type: nothing is allocated per frame.

const DATA_PATH: String = "res://assets/art/units/unit_motion.json"
const DEFAULT_ARCHETYPE: String = "default"

static var _data: Dictionary = {}
static var _loaded: bool = false
## unit id -> UnitMotion (resolved once).
static var _cache: Dictionary = {}
## unit id -> body height in art px measured from the sheet's opaque pixels (0 = not measurable).
static var _body_cache: Dictionary = {}

var archetype: String = DEFAULT_ARCHETYPE
var idle_speed: float = 1.0
var breath_px: int = 1
var breath_sec: float = 2.2
var breath_duty: float = 0.45
var sway_px: int = 0
var sway_sec: float = 3.6
var hover_px: int = 0
var hover_sec: float = 1.6
var slide_scale: float = 1.0
var hop_px: int = 1
var lean_px: int = 1
var anticipate: float = 0.12
var land_squash_px: int = 1
var settle_sec: float = 0.12
var overshoot_px: int = 0
var windup_lean_px: int = 1
var windup_squash_px: int = 0
var hit_lean_px: int = 1
var release_sec: float = 0.1
var waist_ratio: float = 0.42
var chest_ratio: float = 0.68
## Per-unit phase offsets in [0, 1) (from the unit id), so no two units breathe or sway in step.
var breath_phase: float = 0.0
var sway_phase: float = 0.0


## The profile of [param unit_id] (cached). An empty or unlisted id gets the `default` archetype.
static func for_unit(unit_id: String) -> UnitMotion:
	if _cache.has(unit_id):
		return _cache[unit_id]
	_ensure()
	var m := from_entry(_data, unit_id)
	_cache[unit_id] = m
	return m


## Pure: resolves [param unit_id] against parsed [param data] ({archetypes, units}): default, then the archetype,
## then the unit's own overrides. Missing or malformed data gives the built-in defaults.
static func from_entry(data: Dictionary, unit_id: String) -> UnitMotion:
	var m := UnitMotion.new()
	var archetypes: Dictionary = data.get("archetypes", {}) if data.get("archetypes", {}) is Dictionary else {}
	var units: Dictionary = data.get("units", {}) if data.get("units", {}) is Dictionary else {}
	var entry: Variant = units.get(unit_id, DEFAULT_ARCHETYPE)
	var arch_name: String = DEFAULT_ARCHETYPE
	var overrides: Dictionary = {}
	if entry is Dictionary:
		overrides = entry
		arch_name = str((entry as Dictionary).get("archetype", DEFAULT_ARCHETYPE))
	else:
		arch_name = str(entry)
	m.archetype = arch_name if archetypes.has(arch_name) else DEFAULT_ARCHETYPE
	m._apply(archetypes.get(DEFAULT_ARCHETYPE, {}))
	if m.archetype != DEFAULT_ARCHETYPE:
		m._apply(archetypes.get(m.archetype, {}))
	m._apply(overrides)
	m.breath_phase = phase_of(unit_id, 0)
	m.sway_phase = phase_of(unit_id, 1)
	return m


## Pure: a stable phase in [0, 1) for [param unit_id] and [param salt].
static func phase_of(unit_id: String, salt: int) -> float:
	var h: int = absi(hash(unit_id + "#" + str(salt)))
	return float(h % 997) / 997.0


## Drops the parsed data and every resolved profile (tests).
static func clear_cache() -> void:
	_cache.clear()
	_body_cache.clear()
	_data = {}
	_loaded = false


## Body height (art px) of [param sheet]: rows from the frame bottom to the topmost opaque pixel of its `idle` frame 0,
## measured once per unit id from the texture; the sheet's own body_height() when the image cannot be read
## (headless without import).
static func body_height_of(sheet: SpriteSheet) -> int:
	if sheet == null:
		return 0
	var key: String = sheet.unit_id()
	if _body_cache.has(key):
		return int(_body_cache[key])
	var h: int = sheet.body_height()
	var tex: Texture2D = sheet.texture()
	var c: Dictionary = sheet.clip("idle") if sheet.has_clip("idle") else {}
	var frames: Array = c.get("frames", [])
	if tex != null and not frames.is_empty():
		var img: Image = tex.get_image()
		var r: Rect2i = frames[0]
		if img != null and Rect2i(Vector2i.ZERO, img.get_size()).encloses(r):
			var top: int = -1
			for y: int in r.size.y:
				for x: int in r.size.x:
					if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
						top = y
						break
				if top >= 0:
					break
			if top >= 0:
				h = r.size.y - top
	_body_cache[key] = h
	return h


# ---- Poses (pure) -----------------------------------------------------------------------------------------------

## Idle at [param t] seconds: the breath (squash on a per-unit period and phase), the slow head sway (weight shift,
## [param face] = +1 facing right / -1 left) and the hover of flyers (whole body up, never below the feet).
func idle_pose(t: float, face: int) -> Vector4i:
	var squash: int = 0
	if breath_px > 0 and breath_sec > 0.0:
		var w: float = 0.5 - 0.5 * cos(TAU * fposmod(t / breath_sec + breath_phase, 1.0))
		squash = clampi(floori(w * breath_px + breath_duty), 0, breath_px)
	var lean: int = 0
	if sway_px > 0 and sway_sec > 0.0:
		lean = roundi(sway_px * sin(TAU * fposmod(t / sway_sec + sway_phase, 1.0))) * face
	var by: int = 0
	if hover_px > 0 and hover_sec > 0.0:
		by = -roundi(hover_px * (0.5 - 0.5 * cos(TAU * fposmod(t / hover_sec + breath_phase, 1.0))))
	return Vector4i(0, by, lean, squash)


## Mid-glide at progress [param t] (0 = left the old cell, 1 = on the new one) moving along [param dir] (screen
## direction of the move: x = column sign, y = row sign): a crouch and the head leaning back for the first
## `anticipate` share, then the head leading the move; the whole body on a `hop_px` arc.
func move_pose(t: float, dir: Vector2i) -> Vector4i:
	t = clampf(t, 0.0, 1.0)
	var by: int = -roundi(hop_px * sin(PI * t))
	var lean: int = 0
	var squash: int = 0
	var sx: int = signi(dir.x)
	if t < anticipate:
		lean = -sx * mini(1, lean_px)
		squash = 1 if (hop_px > 0 or land_squash_px > 0) else 0
	else:
		lean = sx * lean_px
	return Vector4i(0, by, lean, squash)


## After landing, at settle progress [param s] (0 = just landed, 1 = settled) of a move along [param dir]: the
## landing squash easing out, the head following through for the first 40 %, an optional 1 px overshoot.
func settle_pose(s: float, dir: Vector2i) -> Vector4i:
	s = clampf(s, 0.0, 1.0)
	var sx: int = signi(dir.x)
	var squash: int = roundi(land_squash_px * (1.0 - s))
	var lean: int = sx * lean_px if s < 0.4 else 0
	var bx: int = sx * overshoot_px if s < 0.5 else 0
	return Vector4i(bx, 0, lean, squash)


## A windup / guard / howl clip: the head coils away from the foe ([param face] = the way the unit faces).
func windup_pose(face: int) -> Vector4i:
	return Vector4i(0, 0, -face * windup_lean_px, windup_squash_px)


## Taking a hit with [param k] of the recoil left (1 = just hit, 0 = done): the head whips back from the blow.
func hit_pose(k: float, face: int) -> Vector4i:
	return Vector4i(0, 0, -face * roundi(hit_lean_px * clampf(k, 0.0, 1.0)), 0)


## Torso band rows and head band rows (from the frame bottom) for a body [param body_h] art px tall.
func band_rows(body_h: int) -> Vector2i:
	return Vector2i(roundi(body_h * waist_ratio), roundi(body_h * chest_ratio))


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("UnitMotion: no %s, built-in defaults" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("UnitMotion: %s is not a JSON object" % DATA_PATH)


func _apply(src: Variant) -> void:
	if not (src is Dictionary):
		return
	var d: Dictionary = src
	for key: String in ["idle_speed", "breath_sec", "breath_duty", "sway_sec", "hover_sec", "slide_scale", "anticipate",
			"settle_sec", "release_sec", "waist_ratio", "chest_ratio"]:
		if d.has(key):
			set(key, float(d[key]))
	for key: String in ["breath_px", "sway_px", "hover_px", "hop_px", "lean_px", "land_squash_px", "overshoot_px",
			"windup_lean_px", "windup_squash_px", "hit_lean_px"]:
		if d.has(key):
			set(key, maxi(int(d[key]), 0))
