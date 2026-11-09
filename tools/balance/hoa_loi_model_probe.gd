extends SceneTree
## Hỏa Lôi damage-model evaluation (tool code, not a test; docs/skill-v2/13-hoa-loi-damage-models.md). Plays COMPLETE
## matches with the deck_sim bot for every set-up below on matched seeds and writes one JSON line per match (raw data;
## the report aggregates them). Nothing in the game changes: the damage model is the evaluation-only
## SwingArbiter.armed_damage_cells_fn seam, the bot policy the evaluation-only sim bot["fuse_policy"].
##   BASE                 Mage starter deck, no Hỏa Lôi (baseline bot)
##   <bot>/<model>        starter + N x hoa_loi; bot baseline | predict; model:
##     A    every armed cell counts (approved, production)
##     A4   at most 4 armed cells count
##     C    at most boss footprint + 1 armed cells count
## Usage: godot --headless --path . -s res://tools/balance/hoa_loi_model_probe.gd -- --chapters=0,1,2 --seeds=10
##        [--copies=2] --out=<abs path .jsonl> [--setups=BASE,baseline/A,...]

const SimCore = preload("res://tools/balance/sim_core.gd")
const ID: String = "hoa_loi"

var _core


func _init() -> void:
	_core = SimCore.new()
	var rest: PackedStringArray = _core.apply_args(OS.get_cmdline_user_args())
	var chapters_list: Array[int] = [0]
	var seeds: int = 10
	var copies: int = 2
	var out_path: String = ""
	var only: Array[String] = []
	for arg: String in rest:
		var v: String = arg.get_slice("=", 1) if arg.contains("=") else ""
		if arg.begins_with("--chapters="):
			chapters_list = []
			for p: String in v.split(","):
				chapters_list.append(int(p))
		elif arg.begins_with("--seeds="):
			seeds = maxi(int(v), 1)
		elif arg.begins_with("--copies="):
			copies = maxi(int(v), 1)
		elif arg.begins_with("--out="):
			out_path = v
		elif arg.begins_with("--setups="):
			for p: String in v.split(","):
				only.append(p)
	_core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var character: Dictionary = _core.prepare_character(_core.characters.get_character("phap_su"))
	var base_deck: Array = []
	for id: Variant in character.get("starter_deck", []):
		base_deck.append({"id": str(id), "level": 1})
	var hl_deck: Array = base_deck.duplicate()
	for i: int in copies:
		hl_deck.append({"id": ID, "level": 1})
	var models: Dictionary = {
		"A": Callable(),
		"A4": func(n: int, _fp: int) -> int: return mini(n, 4),
		"C": func(n: int, fp: int) -> int: return mini(n, fp + 1),
	}
	var setups: Array = [["BASE", "baseline", "", base_deck]]
	for bot_policy: String in ["baseline", "predict"]:
		for m: String in ["A", "A4", "C"]:
			setups.append(["%s/%s" % [bot_policy, m], bot_policy, m, hl_deck])
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if not out_path.is_empty() else null
	var n_done: int = 0
	for setup: Array in setups:
		if not only.is_empty() and not only.has(str(setup[0])):
			continue
		_core.bot["fuse_policy"] = setup[1]
		_core.armed_damage_policy = models.get(setup[2], Callable()) if not str(setup[2]).is_empty() else Callable()
		for ci: int in chapters_list:
			var chapter_id: String = chapters.chapter_id(ci)
			for mid: String in chapters.match_ids(ci):
				var rc: RunConfig = RunConfig.from_node(chapters, ci, mid, "battle", 1, -1)
				var m: Dictionary = _core.prepare_match(rc.matches[0] as Dictionary)
				m["chapter_id"] = chapter_id
				for s: int in seeds:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([mid, "hm", s]) & SimCore.SEED_MASK
					_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
					var r: Dictionary = _core.play_match(m, character, setup[3], -1.0, hash([mid, "hm", s, "m"]) & SimCore.SEED_MASK, rng, null)
					var log_n: Array = []
					var log_k: Array = []
					var log_hit: Array = []
					var log_dmg: Array = []
					for e: Variant in r.get("fz_log", []) as Array:
						var d: Dictionary = e as Dictionary
						log_n.append(int(d["n"]))
						log_k.append(int(d["k"]))
						log_hit.append(1 if bool(d["hit"]) else 0)
						log_dmg.append(snappedf(float(d["dmg"]), 0.01))
					var row: Dictionary = {"setup": setup[0], "bot": setup[1], "model": setup[2], "ch": chapter_id,
						"match": mid, "seed": s, "won": bool(r["won"]), "sec": snappedf(float(r.get("sec", 0.0)), 0.01),
						"dealt": snappedf(float(r.get("dealt", 0.0)), 0.1), "taken": snappedf(float(r.get("taken", 0.0)), 0.1),
						"hp_left": snappedf(float(r.get("hp_end", 0.0)), 0.1), "boss_left": snappedf(float(r.get("boss_hp_end_ratio", 0.0)), 0.001), "timeout": bool(r.get("timeout", false)),
						"fz_casts": int(r.get("fz_casts", 0)), "fz_events": int(r.get("fz_events", 0)),
						"fz_hits": int(r.get("fz_hits", 0)), "fz_cells": int(r.get("fz_cells", 0)),
						"fz_dmg": snappedf(float(r.get("fz_dmg", 0.0)), 0.1), "fz_burn": snappedf(float(r.get("fz_burn_dmg", 0.0)), 0.1),
						"fz_busy": int(r.get("fz_busy_casts", 0)), "fz_skipped": int(r.get("fz_skipped", 0)),
						"b_steps": int(r.get("b_steps", 0)), "b_busy_t": snappedf(float(r.get("b_busy_t", 0.0)), 0.01),
						"b_total_t": snappedf(float(r.get("b_total_t", 0.0)), 0.01),
						"fp": _core.state.enemy_footprint_cells().size() if _core.state != null else 1,
						"ln": log_n, "lk": log_k, "lh": log_hit, "ld": log_dmg}
					if f != null:
						f.store_line(JSON.stringify(row))
					n_done += 1
			print("PROGRESS %s %s done=%d" % [setup[0], chapter_id, n_done])
			if f != null:
				f.flush()
	if f != null:
		f.close()
	print("DONE matches=%d" % n_done)
	quit()
