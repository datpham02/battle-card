extends SceneTree
## World Map v2 — vent_surge vs arena invariant (warden Heat hook fix, 2026-11-12): every `vent_surge` a fight can
## carry asks for at most as many vents as the player's half of every arena that fight can be played in has.
## `TileHazards.trigger_vents` starts "up to count" idle vents, so a `vents` above the arena's count is silently
## clamped — the shipped warden hook (`vents 3` in a caldera with 2 vents per half) was exactly that.
## Sources checked, against the arena data of `assets/data/arenas.json` (`ArenaLibrary.hazards_for_match`):
##   1. every chapter match's own `vent_surge` trait -> its own `arena` block (shape or direct);
##   2. every region rule's `by_gauge` row traits and the `warden_hook` trait_params -> every arena of the region's
##      matches (a row applies to any fight node of the region; the hook to its boss-pool matches that carry the trait);
##   3. every modifier of the catalogue with a `vent_surge` trait -> every arena of each region whose pool offers it.
## Limitation (printed, not failed): a match without an `arena` block plays on the combat.json board, which has no
## vents — a `vent_surge` there would be inert; such a match is reported as "no arena" and counts as a failure only
## when it carries the trait itself (it does not in the shipped data).
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/vent_surge_arena_invariant_test.gd

const TRAIT_ID: String = "vent_surge"

var fails: int = 0
var lib: ArenaLibrary
var _vent_cache: Dictionary = {}


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


## Vents on the player's half of [param arena] ({shape} or a direct block); -1 when the block builds no grid.
func _player_vents(arena: Dictionary) -> int:
	var key: String = JSON.stringify(arena)
	if _vent_cache.has(key):
		return int(_vent_cache[key])
	var grid: BoardGrid = ArenaLibrary.grid_for_spec(arena, lib, 0)
	var n: int = -1
	if grid != null:
		n = (ArenaLibrary.hazards_for_match({"arena": arena}, grid, lib)["vents_player"] as Array).size()
	_vent_cache[key] = n
	return n


## The `vents` param of the vent_surge entry of [param traits] (-1 when the list has none).
func _surge_vents(traits: Variant) -> int:
	if typeof(traits) != TYPE_ARRAY:
		return -1
	for t: Variant in traits as Array:
		if typeof(t) == TYPE_DICTIONARY and str((t as Dictionary).get("id", "")) == TRAIT_ID:
			var params: Variant = (t as Dictionary).get("params", {})
			return int((params as Dictionary).get("vents", VentSurgeTrait.DEFAULT_VENTS)) if typeof(params) == TYPE_DICTIONARY else VentSurgeTrait.DEFAULT_VENTS
	return -1


func _initialize() -> void:
	lib = ArenaLibrary.load_from_file()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var rules: RegionRules = RegionRules.load_from_file()
	var arena_names: Dictionary = {}  # region id -> {arena key: {"arena": block, "vents": n, "matches": [ids]}}
	var no_arena: Dictionary = {}  # region id -> [match ids without an arena block]
	var checked: int = 0
	# 1. Each match's own trait against its own arena; collect the region's arenas.
	for ci: int in chapters.chapter_count():
		var region: String = chapters.chapter_id(ci)
		arena_names[region] = {}
		no_arena[region] = []
		for mid: String in chapters.match_ids(ci):
			var raw: Dictionary = chapters.get_match_raw(ci, mid)
			var arena: Variant = raw.get("arena", {})
			var own: int = _surge_vents(raw.get("traits", []))
			if typeof(arena) != TYPE_DICTIONARY or (arena as Dictionary).is_empty():
				(no_arena[region] as Array).append(mid)
				if own >= 0:
					check(false, "%s/%s carries vent_surge (vents %d) but has no arena block (combat.json board: no vents)" % [region, mid, own])
				continue
			var n: int = _player_vents(arena as Dictionary)
			var key: String = JSON.stringify(arena)
			if not (arena_names[region] as Dictionary).has(key):
				(arena_names[region] as Dictionary)[key] = {"arena": arena, "vents": n, "matches": []}
			((arena_names[region] as Dictionary)[key]["matches"] as Array).append(mid)
			if own >= 0:
				checked += 1
				check(own <= n, "%s/%s own vent_surge vents %d <= %d vents of its arena %s" % [region, mid, own, n, str(arena)])
	# 2. Region rules: by_gauge row traits and the warden hook against the region's arenas.
	for region: String in rules.region_ids():
		var rule: Dictionary = rules.rule_for(region)
		if rule.is_empty():
			continue
		var arenas: Dictionary = arena_names.get(region, {})
		check(not arenas.is_empty(), "%s (rule %s) has at least one match with an arena block to check against" % [region, rule.get("id", "")])
		var rows: Dictionary = (rule.get("combat_effect", {}) as Dictionary).get("by_gauge", {})
		for g: Variant in rows.keys():
			var v: int = _surge_vents((rows[g] as Dictionary).get("traits", []))
			if v < 0:
				continue
			for key: Variant in arenas.keys():
				var a: Dictionary = arenas[key]
				checked += 1
				check(v <= int(a["vents"]), "%s heat row %s vent_surge vents %d <= %d vents of arena %s (%s)" % [region, str(g), v, int(a["vents"]), str(a["arena"]), ", ".join(PackedStringArray(a["matches"]))])
		var hook: Dictionary = rule.get("warden_hook", {})
		var hook_params: Dictionary = hook.get("trait_params", {}) if not hook.is_empty() else {}
		if hook_params.has(TRAIT_ID) and (hook_params[TRAIT_ID] as Dictionary).has("vents"):
			var hv: int = int((hook_params[TRAIT_ID] as Dictionary)["vents"])
			var ci: int = chapters.region_index(region)
			var pools: Dictionary = chapters.get_map_spec(ci).get("pools", {})
			var boss_ids: Array[String] = []
			var boss_pool: Variant = pools.get("boss", {})
			if typeof(boss_pool) == TYPE_DICTIONARY:
				for tier: Variant in (boss_pool as Dictionary).keys():
					for id: Variant in (boss_pool as Dictionary)[tier] as Array:
						if not boss_ids.has(str(id)):
							boss_ids.append(str(id))
			check(not boss_ids.is_empty(), "%s warden hook: the region has a boss pool to apply it to" % region)
			for bid: String in boss_ids:
				var braw: Dictionary = chapters.get_match_raw(ci, bid)
				if _surge_vents(braw.get("traits", [])) < 0:
					continue  # the hook overrides params of an existing trait only
				var barena: Variant = braw.get("arena", {})
				if typeof(barena) != TYPE_DICTIONARY or (barena as Dictionary).is_empty():
					check(false, "%s warden %s has no arena block to check the hook's vents %d against" % [region, bid, hv])
					continue
				var bn: int = _player_vents(barena as Dictionary)
				checked += 1
				check(hv <= bn, "%s warden hook vent_surge vents %d <= %d vents of %s's arena %s" % [region, hv, bn, bid, str(barena)])
		# 3. Modifiers of the catalogue offered in this region's pool.
		for mod_id: String in rules.modifier_pool(region):
			var cat: Dictionary = rules.modifier(mod_id)
			if not cat.has("trait"):
				continue
			var mv: int = _surge_vents([cat["trait"]])
			if mv < 0:
				continue
			for key: Variant in arenas.keys():
				var a: Dictionary = arenas[key]
				checked += 1
				check(mv <= int(a["vents"]), "%s modifier %s vent_surge vents %d <= %d vents of arena %s" % [region, mod_id, mv, int(a["vents"]), str(a["arena"])])
	for region: String in no_arena.keys():
		if not (no_arena[region] as Array).is_empty():
			print("NOTE %s: %d match(es) without an arena block (combat.json board, no vents; not checked): %s" % [region, (no_arena[region] as Array).size(), ", ".join(PackedStringArray(no_arena[region]))])
	check(checked > 0, "at least one vent_surge entry was checked (%d)" % checked)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
