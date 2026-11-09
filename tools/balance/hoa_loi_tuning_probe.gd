extends SceneTree
## Hỏa Lôi multiplier tuning under Model C (tool code, not a test; docs/skill-v2/14-hoa-loi-multiplier-tuning.md). Plays
## COMPLETE matches on matched seeds and writes one JSON line per match. The card's numbers change IN MEMORY only
## (cards.json untouched): fuse_mult = the candidate, the square clause's multiplier = candidate x --square-ratio (its 1.8 s
## fuse kept). The damage rule is the card's own (Model C, CastResolver.damage_cells). Bots: baseline (the existing policy)
## and predict (evaluation-only, model-aware: sim_core.fuse_expected_value).
##   BASE                      Mage starter deck, no Hỏa Lôi
##   <bot>/x<mult>             starter + N x hoa_loi at that multiplier
## Usage: godot --headless --path . -s res://tools/balance/hoa_loi_tuning_probe.gd -- --chapters=0,1 --seeds=20
##        --out=<abs .jsonl> [--setups=BASE,predict/x2.0,...] [--mults=1.6,2.0,2.4,2.8,3.2] [--square-ratio=1.2]
##        [--hp-ratio=1.0] [--copies=2]

const SimCore = preload("res://tools/balance/sim_core.gd")
const ID: String = "hoa_loi"

var _core


func _init() -> void:
	_core = SimCore.new()
	var rest: PackedStringArray = _core.apply_args(OS.get_cmdline_user_args())
	var chapters_list: Array[int] = [0]
	var seeds: int = 20
	var copies: int = 2
	var out_path: String = ""
	var only: Array[String] = []
	var mults: Array[float] = [1.6, 2.0, 2.4, 2.8, 3.2]
	var square_ratio: float = 1.2
	var hp_ratio: float = 1.0
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
		elif arg.begins_with("--mults="):
			mults = []
			for p: String in v.split(","):
				mults.append(float(p))
		elif arg.begins_with("--square-ratio="):
			square_ratio = float(v)
		elif arg.begins_with("--hp-ratio="):
			hp_ratio = clampf(float(v), 0.05, 1.0)
	_core.load_configs()
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var character: Dictionary = _core.prepare_character(_core.characters.get_character("phap_su"))
	var start_hp: float = -1.0 if hp_ratio >= 1.0 else float(character.get("max_hp", 210)) * hp_ratio
	var base_deck: Array = []
	for id: Variant in character.get("starter_deck", []):
		base_deck.append({"id": str(id), "level": 1})
	var hl_deck: Array = base_deck.duplicate()
	for i: int in copies:
		hl_deck.append({"id": ID, "level": 1})
	var card: Dictionary = _core.cards.get_skill(ID)
	var clause0: Dictionary = (card.get("shape_clause", {}) as Dictionary).duplicate(true)
	var setups: Array = [["BASE", "baseline", 0.0, base_deck]]
	for bot_policy: String in ["baseline", "predict"]:
		for m: float in mults:
			setups.append(["%s/x%.1f" % [bot_policy, m], bot_policy, m, hl_deck])
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if not out_path.is_empty() else null
	var n_done: int = 0
	for setup: Array in setups:
		if not only.is_empty() and not only.has(str(setup[0])):
			continue
		_core.bot["fuse_policy"] = setup[1]
		var m: float = float(setup[2])
		if m > 0.0:
			card["fuse_mult"] = m
			var cl: Dictionary = clause0.duplicate(true)
			cl.erase("fuse_mult_scale")
			cl["fuse_mult"] = m * square_ratio
			card["shape_clause"] = cl
		for ci: int in chapters_list:
			var chapter_id: String = chapters.chapter_id(ci)
			for mid: String in chapters.match_ids(ci):
				var rc: RunConfig = RunConfig.from_node(chapters, ci, mid, "battle", 1, -1)
				var mm: Dictionary = _core.prepare_match(rc.matches[0] as Dictionary)
				mm["chapter_id"] = chapter_id
				for s: int in seeds:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([mid, "ht", s]) & SimCore.SEED_MASK
					_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
					var r: Dictionary = _core.play_match(mm, character, setup[3], start_hp, hash([mid, "ht", s, "m"]) & SimCore.SEED_MASK, rng, null)
					var ln: Array = []
					var lk: Array = []
					var lh: Array = []
					var ld: Array = []
					var lsq: Array = []
					var lfp: Array = []
					for e: Variant in r.get("fz_log", []) as Array:
						var d: Dictionary = e as Dictionary
						ln.append(int(d["n"]))
						lk.append(int(d["k"]))
						lh.append(1 if bool(d["hit"]) else 0)
						ld.append(snappedf(float(d["dmg"]), 0.01))
						lsq.append(1 if bool(d.get("sq", false)) else 0)
						lfp.append(int(d["fp"]))
					var row: Dictionary = {"setup": setup[0], "bot": setup[1], "mult": m, "ch": chapter_id, "match": mid, "seed": s,
						"won": bool(r["won"]), "timeout": bool(r.get("timeout", false)), "sec": snappedf(float(r.get("sec", 0.0)), 0.01),
						"dealt": snappedf(float(r.get("dealt", 0.0)), 0.1), "taken": snappedf(float(r.get("taken", 0.0)), 0.1),
						"hp_left": snappedf(float(r.get("hp_end", 0.0)), 0.1), "boss_left": snappedf(float(r.get("boss_hp_end_ratio", 0.0)), 0.001),
						"fz_casts": int(r.get("fz_casts", 0)), "fz_events": int(r.get("fz_events", 0)), "fz_hits": int(r.get("fz_hits", 0)),
						"fz_cells": int(r.get("fz_cells", 0)), "fz_dmg": snappedf(float(r.get("fz_dmg", 0.0)), 0.1),
						"fz_burn": snappedf(float(r.get("fz_burn_dmg", 0.0)), 0.1), "fz_busy": int(r.get("fz_busy_casts", 0)),
						"fz_skipped": int(r.get("fz_skipped", 0)), "fz_offered": int(r.get("fz_offered", 0)),
						"fz_chosen": int(r.get("fz_chosen", 0)), "fz_passed": r.get("fz_passed", {}),
						"b_steps": int(r.get("b_steps", 0)), "b_busy_t": snappedf(float(r.get("b_busy_t", 0.0)), 0.01),
						"b_total_t": snappedf(float(r.get("b_total_t", 0.0)), 0.01),
						"fp": _core.state.enemy_footprint_cells().size() if _core.state != null else 1,
						"ln": ln, "lk": lk, "lh": lh, "ld": ld, "lsq": lsq, "lfp": lfp}
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
