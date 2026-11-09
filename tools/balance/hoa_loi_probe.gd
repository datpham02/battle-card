extends SceneTree
## Hỏa Lôi balance probe (tool code, not a test; docs/skill-v2/09-hoa-loi-design.md D5): the deck_sim bot plays every
## match of a chapter with the Mage's starter deck, with and without Hỏa Lôi, and prints the fuse metrics. Nothing is
## written; card / brain data change in memory only.
##   BASE        the Mage starter deck (no Hỏa Lôi)
##   HL          starter + N x hoa_loi, the approved prototype rule (whole field: dpc x armed cells x mult)
##   HL react=X  the same with every boss weight set's fuse_react_sec = X (sensitivity of the boss counterplay)
## Damage models (counterfactual, recomputed from every recorded detonation of the HL run; the RULE is not changed):
##   A whole field  (approved)  dmg x 1                       a touch on 1 seal pays for every armed cell
##   B covered only             dmg x k / n                   only the armed cells under the boss's footprint count
##   C capped field             dmg x min(n, fp + 1) / n      the field counts at most the footprint + 1 cells
## (n = armed cells, k = armed cells under the footprint at the blast, fp = footprint size; dmg keeps every other
## multiplier of the real hit.)
## Usage: godot --headless --path . -s res://tools/balance/hoa_loi_probe.gd -- --chapter=0 --seeds=12 [--copies=2]

const SimCore = preload("res://tools/balance/sim_core.gd")
const ID: String = "hoa_loi"

var _core


func _init() -> void:
	_core = SimCore.new()
	var rest: PackedStringArray = _core.apply_args(OS.get_cmdline_user_args())
	var ci: int = 0
	var seeds: int = 12
	var copies: int = 2
	for arg: String in rest:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--chapter="):
			ci = int(v)
		elif arg.begins_with("--seeds="):
			seeds = maxi(int(v), 1)
		elif arg.begins_with("--copies="):
			copies = maxi(int(v), 1)
	_core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var chapter_id: String = chapters.chapter_id(ci)
	var character: Dictionary = _core.prepare_character(_core.characters.get_character("phap_su"))
	var base_deck: Array = []
	for id: Variant in character.get("starter_deck", []):
		base_deck.append({"id": str(id), "level": 1})
	var hl_deck: Array = base_deck.duplicate()
	for i: int in copies:
		hl_deck.append({"id": ID, "level": 1})
	var setups: Array = [["BASE", base_deck, -1.0], ["HL", hl_deck, -1.0], ["HL react=0.0", hl_deck, 0.0],
		["HL react=1.5", hl_deck, 1.5]]
	print("hoa_loi_probe chapter=%d (%s) seeds=%d deck=phap_su starter (+%dx%s)" % [ci + 1, chapter_id, seeds, copies, ID])
	print("RESULT | setup | match | win % | mean sec | dealt/match | HL blasts | hit % | armed cells/blast | HL dmg share % | dmg/blast A | dmg/blast B | dmg/blast C | casts while boss busy %")
	var models: Dictionary = {}
	for setup: Array in setups:
		_set_react(float(setup[2]))
		var sum: Dictionary = {}
		var log_all: Array = []
		for id: String in chapters.match_ids(ci):
			var rc: RunConfig = RunConfig.from_node(chapters, ci, id, "battle", 1, -1)
			var m: Dictionary = _core.prepare_match(rc.matches[0] as Dictionary)
			m["chapter_id"] = chapter_id
			var acc: Dictionary = {}
			var log_m: Array = []
			for s: int in seeds:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([id, "hl", s]) & SimCore.SEED_MASK
				_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
				var r: Dictionary = _core.play_match(m, character, setup[1], -1.0, hash([id, "hl", s, "m"]) & SimCore.SEED_MASK, rng, null)
				_add(acc, "won", 1.0 if bool(r["won"]) else 0.0)
				_add(acc, "n", 1.0)
				for k: String in ["sec", "dealt", "fz_events", "fz_hits", "fz_cells", "fz_dmg", "fz_busy_casts"]:
					_add(acc, k, float(r.get(k, 0.0)))
				_add(acc, "hl_casts", float(r.get("fz_events", 0.0)))
				log_m.append_array(r.get("fz_log", []) as Array)
			print(_row(setup[0], id, acc, log_m))
			for k: String in acc:
				_add(sum, k, float(acc[k]))
			log_all.append_array(log_m)
		print(_row(setup[0], "ALL", sum, log_all))
		if setup[0] == "HL":
			models = _models(log_all)
	_set_react(-1.0)
	print("")
	print("MODELS (HL run, every detonation) | blasts %d | hits %d | k distribution on hits %s" % [int(models.get("blasts", 0)),
		int(models.get("hits", 0)), str(models.get("k_hist", {}))])
	print("MODELS | n distribution on hits %s | footprint sizes on hits %s" % [str(models.get("n_hist", {})), str(models.get("fp_hist", {}))])
	for key: String in ["A", "B", "C"]:
		print("MODEL %s | dmg/hit %.1f | dmg/blast %.1f | per-n dmg/hit %s" % [key, float(models.get(key + "_hit", 0.0)),
			float(models.get(key + "_blast", 0.0)), str(models.get(key + "_by_n", {}))])
	quit()


# Sets fuse_react_sec on every boss weight set (<0 = restore the file's values).
var _saved_sets: Dictionary = {}


func _set_react(v: float) -> void:
	var sets: Dictionary = _core.brain_data.get("sets", {}) as Dictionary
	if _saved_sets.is_empty():
		for name: Variant in sets:
			_saved_sets[name] = (sets[name] as Dictionary).get("fuse_react_sec", null)
	for name: Variant in sets:
		var s: Dictionary = sets[name] as Dictionary
		if v < 0.0:
			if _saved_sets.get(name) == null:
				s.erase("fuse_react_sec")
			else:
				s["fuse_react_sec"] = _saved_sets[name]
		else:
			s["fuse_react_sec"] = v


func _models(log: Array) -> Dictionary:
	var out: Dictionary = {"blasts": log.size(), "hits": 0, "k_hist": {}, "n_hist": {}, "fp_hist": {}}
	var sums: Dictionary = {"A": 0.0, "B": 0.0, "C": 0.0}
	var by_n: Dictionary = {"A": {}, "B": {}, "C": {}}
	var n_hits: Dictionary = {}
	for e: Variant in log:
		var d: Dictionary = e as Dictionary
		if not bool(d["hit"]):
			continue
		out["hits"] = int(out["hits"]) + 1
		var n: int = maxi(int(d["n"]), 1)
		var k: int = int(d["k"])
		var fp: int = int(d["fp"])
		var dmg: float = float(d["dmg"])
		_bump(out["k_hist"], k)
		_bump(out["n_hist"], n)
		_bump(out["fp_hist"], fp)
		_bump(n_hits, n)
		var vals: Dictionary = {"A": dmg, "B": dmg * float(k) / float(n), "C": dmg * float(mini(n, fp + 1)) / float(n)}
		for key: String in vals:
			sums[key] = float(sums[key]) + float(vals[key])
			(by_n[key] as Dictionary)[n] = float((by_n[key] as Dictionary).get(n, 0.0)) + float(vals[key])
	var hits: float = maxf(float(out["hits"]), 1.0)
	var blasts: float = maxf(float(out["blasts"]), 1.0)
	for key: String in sums:
		out[key + "_hit"] = float(sums[key]) / hits
		out[key + "_blast"] = float(sums[key]) / blasts
		var per: Dictionary = {}
		for n: Variant in by_n[key]:
			per[n] = snappedf(float((by_n[key] as Dictionary)[n]) / maxf(float(n_hits[n]), 1.0), 0.1)
		out[key + "_by_n"] = per
	return out


func _bump(d: Dictionary, key: Variant) -> void:
	d[key] = int(d.get(key, 0)) + 1


func _add(d: Dictionary, k: String, v: float) -> void:
	d[k] = float(d.get(k, 0.0)) + v


func _row(setup: String, id: String, a: Dictionary, log: Array) -> String:
	var n: float = maxf(float(a.get("n", 0.0)), 1.0)
	var blasts: float = float(a.get("fz_events", 0.0))
	var m: Dictionary = _models(log)
	return "RESULT | %s | %s | %.0f | %.1f | %.0f | %.0f | %.0f | %.2f | %.1f | %.1f | %.1f | %.1f | %.0f" % [setup, id,
		100.0 * float(a.get("won", 0.0)) / n, float(a.get("sec", 0.0)) / n, float(a.get("dealt", 0.0)) / n, blasts,
		100.0 * float(a.get("fz_hits", 0.0)) / maxf(blasts, 1.0), float(a.get("fz_cells", 0.0)) / maxf(blasts, 1.0),
		100.0 * float(a.get("fz_dmg", 0.0)) / maxf(float(a.get("dealt", 0.0)), 1.0),
		float(m.get("A_blast", 0.0)), float(m.get("B_blast", 0.0)), float(m.get("C_blast", 0.0)),
		100.0 * float(a.get("fz_busy_casts", 0.0)) / maxf(blasts, 1.0)]
