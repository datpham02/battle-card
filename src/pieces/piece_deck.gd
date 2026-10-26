class_name PieceDeck
extends RefCounted
## The player's piece deck of a run (Story 034): one multiplier per shape that scales its drop
## weight, "Ink" (add a run_only shape or raise a multiplier) and "Remove" (multiplier to 0).
## All functions are static and pure: the state is a plain JSON-safe Dictionary
## `{"mult": {shape_id: float}, "added": [shape_id, ...]}` and every mutation returns a NEW state.
## `added` lists the run_only shapes the run has taken; a default-pool shape is always in `mult`.
## Numbers come from [PieceDeckConfig] (rewards.json -> piece_rewards), never from this file.
## Boss drops never read this: only the player side is given [method weights_for_match].
## Implements: Story 034 (design/game-brief.md, "Bo manh").

const KEY_MULT: String = "mult"
const KEY_ADDED: String = "added"
const REASON_UNKNOWN: String = "piece_deck.reason.unknown"
const REASON_ALREADY_REMOVED: String = "piece_deck.reason.already_removed"
const REASON_MIN_SHAPES: String = "piece_deck.reason.min_shapes"


## Start-of-run state: every default-pool shape of [param lib] at mult 1.0, nothing added.
static func initial(lib: PieceLibrary) -> Dictionary:
	var mult: Dictionary = {}
	for id: String in lib.base_shape_ids():
		mult[id] = 1.0
	return {KEY_MULT: mult, KEY_ADDED: []}


## Cleans a loaded state: unknown ids dropped with a warning, missing default shapes filled with
## 1.0, `added` only holds existing run_only ids that are active, values kept >= 0 (the upper
## bound needs the config and is not applied here). Missing or garbage input gives [method initial].
static func sanitize(state: Variant, lib: PieceLibrary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY or typeof((state as Dictionary).get(KEY_MULT)) != TYPE_DICTIONARY:
		return initial(lib)
	var src: Dictionary = state
	var raw_mult: Dictionary = src[KEY_MULT]
	var mult: Dictionary = {}
	for key: Variant in raw_mult.keys():
		var id: String = str(key)
		var v: Variant = raw_mult[key]
		if not lib.has_shape(id):
			push_warning("PieceDeck: unknown shape '%s' in the saved deck, dropped" % id)
			continue
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			push_warning("PieceDeck: mult of '%s' is not a number, dropped" % id)
			continue
		mult[id] = maxf(float(v), 0.0)
	var added: Array = []
	var raw_added: Variant = src.get(KEY_ADDED, [])
	if typeof(raw_added) == TYPE_ARRAY:
		for item: Variant in raw_added as Array:
			var id: String = str(item)
			if not lib.has_shape(id) or not lib.is_run_only(id):
				push_warning("PieceDeck: '%s' in 'added' is not a known run_only shape, dropped" % id)
				continue
			if added.has(id):
				continue
			if not mult.has(id):
				mult[id] = 1.0
			if float(mult[id]) > 0.0:
				added.append(id)
	# A run_only shape that is not in `added` is not owned: it keeps at most a removed marker (0).
	for id: String in lib.run_only_ids():
		if mult.has(id) and float(mult[id]) > 0.0 and not added.has(id):
			push_warning("PieceDeck: run_only shape '%s' has a mult but is not in 'added', dropped" % id)
			mult.erase(id)
	for id: String in lib.base_shape_ids():
		if not mult.has(id):
			mult[id] = 1.0
	return {KEY_MULT: mult, KEY_ADDED: added}


## Multiplier of shape [param id] (0.0 when absent).
static func mult_of(state: Dictionary, id: String) -> float:
	return float(_mult(state).get(id, 0.0))


## True when the deck holds [param id] with a multiplier above 0.
static func has_shape(state: Dictionary, id: String) -> bool:
	return mult_of(state, id) > 0.0


## Shapes that can drop at all, in library order: mult > 0 and (default pool or in `added`).
static func active_ids(state: Dictionary, lib: PieceLibrary) -> Array[String]:
	var out: Array[String] = []
	var added: Array = _added(state)
	for id: String in lib.shape_ids():
		if mult_of(state, id) <= 0.0:
			continue
		if lib.is_run_only(id) and not added.has(id):
			continue
		out.append(id)
	return out


## Base weight before the multiplier: [member PieceDeckConfig.run_only_weight] for a run_only
## shape, else the library's weight for [param chapter_id].
static func base_weight(lib: PieceLibrary, id: String, chapter_id: String, cfg: PieceDeckConfig) -> float:
	if lib.is_run_only(id):
		return cfg.run_only_weight
	return lib.weight(id, chapter_id)


## `{id: base * mult}` for the active shapes whose weight is above 0.
static func effective_weights(
	state: Dictionary, lib: PieceLibrary, chapter_id: String, cfg: PieceDeckConfig
) -> Dictionary:
	var out: Dictionary = {}
	for id: String in active_ids(state, lib):
		var w: float = base_weight(lib, id, chapter_id, cfg) * mult_of(state, id)
		if w > 0.0:
			out[id] = w
	return out


## Weights the player's drops use in one match: `{"weights": Dictionary, "fallback": bool}`.
## An empty/garbage [param state] means the original weights of every default-pool shape.
## When no shape of the effective weights has a placement on the ENEMY half of [param grid]
## (the player's pieces land there), the original weights of the default-pool shapes that DO fit
## are returned with fallback = true and a warning, so the match always has a piece that fits.
static func weights_for_match(
	state: Dictionary, lib: PieceLibrary, chapter_id: String, grid: BoardGrid, cfg: PieceDeckConfig
) -> Dictionary:
	if typeof(_mult(state)) != TYPE_DICTIONARY or _mult(state).is_empty():
		var orig: Dictionary = {}
		for id: String in lib.base_shape_ids():
			orig[id] = lib.weight(id, chapter_id)
		return {"weights": orig, "fallback": false}
	var weights: Dictionary = effective_weights(state, lib, chapter_id, cfg)
	if grid == null:
		return {"weights": weights, "fallback": false}
	for id: String in weights.keys():
		if PiecePlacement.has_any_placement(grid, lib.make_piece(id), true):
			return {"weights": weights, "fallback": false}
	var fitting: Dictionary = {}
	for id: String in lib.base_shape_ids():
		if PiecePlacement.has_any_placement(grid, lib.make_piece(id), true):
			fitting[id] = lib.weight(id, chapter_id)
	push_warning("PieceDeck: no shape of the deck fits this arena, using the original weights")
	return {"weights": fitting, "fallback": true}


## `{id: 100 * w / sum}`; every value is 0 when the sum is 0.
static func drop_percent(weights: Dictionary) -> Dictionary:
	var total: float = 0.0
	for id: Variant in weights.keys():
		total += maxf(float(weights[id]), 0.0)
	var out: Dictionary = {}
	for id: Variant in weights.keys():
		out[id] = 0.0 if total <= 0.0 else 100.0 * maxf(float(weights[id]), 0.0) / total
	return out


## True when [param id] is a library shape whose mult is below the ceiling (so it may be offered).
static func can_ink(state: Dictionary, id: String, lib: PieceLibrary, cfg: PieceDeckConfig) -> bool:
	return lib.has_shape(id) and mult_of(state, id) < cfg.mult_max


## New state after inking [param id]: a run_only shape not yet active is added at mult 1.0; a
## shape at mult 0 (removed) returns to 1.0; otherwise mult rises by mult_step up to mult_max.
## An unchanged copy (and a warning) when [method can_ink] is false.
static func apply_ink(
	state: Dictionary, id: String, lib: PieceLibrary, cfg: PieceDeckConfig
) -> Dictionary:
	var out: Dictionary = _copy(state)
	if not can_ink(state, id, lib, cfg):
		push_warning("PieceDeck: cannot ink '%s' (unknown or at the ceiling)" % id)
		return out
	var m: float = mult_of(state, id)
	var added: Array = out[KEY_ADDED]
	var mult: Dictionary = out[KEY_MULT]
	var owned: bool = m > 0.0 and (not lib.is_run_only(id) or added.has(id))
	if not owned:
		mult[id] = 1.0
		if lib.is_run_only(id) and not added.has(id):
			added.append(id)
	else:
		mult[id] = minf(m + cfg.mult_step, cfg.mult_max)
	return out


## [param cfg].ink_offer_count distinct shapes that can still be inked, drawn with a generator
## seeded by [param rng_seed] (same seed, same offer); fewer when fewer qualify, empty when none.
static func roll_ink_offer(
	state: Dictionary, lib: PieceLibrary, cfg: PieceDeckConfig, rng_seed: int
) -> Array[String]:
	var pool: Array[String] = []
	for id: String in lib.shape_ids():
		if can_ink(state, id, lib, cfg):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out: Array[String] = []
	while out.size() < cfg.ink_offer_count and not pool.is_empty():
		var i: int = rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## Whether [param id] may be removed: `{"ok": bool, "reason": String}`. Reasons (translation
## keys): piece_deck.reason.unknown, .already_removed (not active), .min_shapes (fewer than
## min_shapes active shapes would stay). `reason` is "" when ok.
static func can_remove(
	state: Dictionary, id: String, lib: PieceLibrary, cfg: PieceDeckConfig
) -> Dictionary:
	if not lib.has_shape(id):
		return {"ok": false, "reason": REASON_UNKNOWN}
	var active: Array[String] = active_ids(state, lib)
	if not active.has(id):
		return {"ok": false, "reason": REASON_ALREADY_REMOVED}
	if active.size() - 1 < cfg.min_shapes:
		return {"ok": false, "reason": REASON_MIN_SHAPES}
	return {"ok": true, "reason": ""}


## New state with mult[id] = 0 (and a run_only id dropped from `added`); an unchanged copy and a
## warning when [method can_remove] is not ok.
static func remove(
	state: Dictionary, id: String, lib: PieceLibrary, cfg: PieceDeckConfig
) -> Dictionary:
	var out: Dictionary = _copy(state)
	var verdict: Dictionary = can_remove(state, id, lib, cfg)
	if not bool(verdict["ok"]):
		push_warning("PieceDeck: cannot remove '%s' (%s)" % [id, verdict["reason"]])
		return out
	(out[KEY_MULT] as Dictionary)[id] = 0.0
	(out[KEY_ADDED] as Array).erase(id)
	return out


static func _mult(state: Dictionary) -> Dictionary:
	var m: Variant = state.get(KEY_MULT, {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


static func _added(state: Dictionary) -> Array:
	var a: Variant = state.get(KEY_ADDED, [])
	return a if typeof(a) == TYPE_ARRAY else []


static func _copy(state: Dictionary) -> Dictionary:
	return {KEY_MULT: _mult(state).duplicate(true), KEY_ADDED: _added(state).duplicate(true)}
