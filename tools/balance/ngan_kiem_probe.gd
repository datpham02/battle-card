extends SceneTree
## Cast Commitment balance probe for Ngàn Kiếm (tool code, not a test): the deck_sim bot (sim_core.gd) plays every
## match of a chapter with the Knight's starter deck plus Ngàn Kiếm, under three set-ups, and prints the channel
## metrics side by side. Nothing is written; cards.json is changed in memory only.
##   PREV            the previous accepted rules: swing (no extension), hover 0.5, the hero rooted until 0.22 s before
##                   the first hit (modelled as a 0.28 s lock after the swing end), no cancel
##   COMMIT          the prototype: channel +0.28, hover 0.22, commit lock 0.13, the bot always commits
##   COMMIT+CANCEL   the same, the bot cancels a channel when an enemy warning covers its cell (then dodges)
## Same seeds for every set-up, so the rows differ only by the rules.
## Usage: godot --headless --path . -s res://tools/balance/ngan_kiem_probe.gd -- --chapter=0 --seeds=12 [--copies=2]

const SimCore = preload("res://tools/balance/sim_core.gd")
const ID: String = "ngan_kiem"

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
	var character: Dictionary = _core.prepare_character(_core.characters.get_character("kiem_si"))
	var deck: Array = []
	for id: Variant in character.get("starter_deck", []):
		deck.append({"id": str(id), "level": 1})
	for i: int in copies:
		deck.append({"id": ID, "level": 1})
	var card: Dictionary = _core.cards.get_skill(ID)
	var setups: Array = [
		["PREV", {"channel_extend_sec": 0.0, "sky_hover_sec": 0.5, "commit_lock_sec": 0.28}, "never"],
		["COMMIT", {"channel_extend_sec": 0.28, "sky_hover_sec": 0.22, "commit_lock_sec": 0.13}, "never"],
		["COMMIT+CANCEL", {"channel_extend_sec": 0.28, "sky_hover_sec": 0.22, "commit_lock_sec": 0.13}, "on_warning"],
	]
	print("ngan_kiem_probe chapter=%d (%s) seeds=%d deck=starter+%dx%s" % [ci + 1, chapter_id, seeds, copies, ID])
	print("RESULT | setup | match | win % | mean sec | NK casts | cancels | interrupts | committed | hit casts % | dmg/committed | whiff % (boss dodged) | HP lost channeling/cast | casts in enemy recovery %")
	var totals: Dictionary = {}
	for setup: Array in setups:
		for k: String in setup[1]:
			card[k] = setup[1][k]
		_core.bot["channel_cancel"] = setup[2]
		var sum: Dictionary = {}
		for id: String in chapters.match_ids(ci):
			var rc: RunConfig = RunConfig.from_node(chapters, ci, id, "battle", 1, -1)
			var m: Dictionary = _core.prepare_match(rc.matches[0] as Dictionary)
			m["chapter_id"] = chapter_id
			var acc: Dictionary = {}
			for s: int in seeds:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([id, "nk", s]) & SimCore.SEED_MASK
				_core.time_limit_sec = SimCore.MATCH_TIMEOUT_SEC
				var r: Dictionary = _core.play_match(m, character, deck, -1.0, hash([id, "nk", s, "m"]) & SimCore.SEED_MASK, rng, null)
				_add(acc, "won", 1.0 if bool(r["won"]) else 0.0)
				_add(acc, "n", 1.0)
				for k: String in ["sec", "ch_casts", "ch_cancels", "ch_interrupts", "ch_committed", "ch_hits", "ch_dmg", "ch_hit_casts",
						"ch_taken", "ch_recovery_casts"]:
					_add(acc, k, float(r.get(k, 0.0)))
			print(_row(setup[0], id, acc))
			for k: String in acc:
				_add(sum, k, float(acc[k]))
		print(_row(setup[0], "ALL", sum))
		totals[setup[0]] = sum
	print("")
	print("Notes: hit casts % = committed casts with >= 1 hit; whiff % = committed casts that hit nothing (the boss left")
	print("or was never in the region); HP lost channeling counts every HP the hero lost while its channel ran.")
	quit()


func _add(d: Dictionary, k: String, v: float) -> void:
	d[k] = float(d.get(k, 0.0)) + v


func _row(setup: String, id: String, a: Dictionary) -> String:
	var n: float = maxf(float(a.get("n", 0.0)), 1.0)
	var casts: float = float(a.get("ch_casts", 0.0))
	var committed: float = float(a.get("ch_committed", 0.0))
	var whiffs: float = committed - float(a.get("ch_hit_casts", 0.0))
	return "RESULT | %s | %s | %.0f | %.1f | %.0f | %.0f | %.0f | %.0f | %.0f | %.1f | %.0f | %.2f | %.0f" % [setup, id,
		100.0 * float(a.get("won", 0.0)) / n, float(a.get("sec", 0.0)) / n, casts, float(a.get("ch_cancels", 0.0)),
		float(a.get("ch_interrupts", 0.0)), committed, 100.0 * (committed - whiffs) / maxf(committed, 1.0),
		float(a.get("ch_dmg", 0.0)) / maxf(committed, 1.0), 100.0 * whiffs / maxf(committed, 1.0),
		float(a.get("ch_taken", 0.0)) / maxf(casts, 1.0), 100.0 * float(a.get("ch_recovery_casts", 0.0)) / maxf(casts, 1.0)]
