extends SceneTree
## Story 037 (W4): unlocks only widen POOLS, never the start of a run. Same character + same seed: the run
## built from an EMPTY save (everything locked) and from an every-unlock save (nothing locked) has an identical
## start state: HP, starter deck, relics, gold, removal tokens, piece deck (state, shape removals) and the first
## region offer. Checked for all five characters (the locked ones too) over several seeds, on the saved dict
## (minus the `locked` key itself). Prints PASS/FAIL lines and FAILS=n.

const SEEDS: Array[int] = [1, 7, 42, 9035, 123456]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _init() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var characters: CharacterConfig = CharacterConfig.load_from_file()
	var cfg: AchievementsConfig = AchievementsConfig.shared()
	var empty := ProgressState.new()
	var full := ProgressState.new()
	full.mark_all_unlocked(cfg, chapters.region_ids())
	var locked_empty: Dictionary = cfg.locked_content(empty)
	var locked_full: Dictionary = cfg.locked_content(full)
	_check("an empty save locks content", not locked_empty.is_empty())
	_check("an every-unlock save locks nothing", locked_full.is_empty(), str(locked_full))
	_check("--progress=all opens every character", _all_open(cfg, full, characters))
	var removals: int = int(RewardRoller.load_config().get("starting_removals", 0))
	for cid: String in characters.ids():
		var ch: Dictionary = characters.get_character(cid)
		for sd: int in SEEDS:
			var a: RunSession = RunSession.begin_world(chapters, ch, sd, removals, locked_empty)
			var b: RunSession = RunSession.begin_world(chapters, ch, sd, removals, locked_full)
			var da: Dictionary = a.to_dict()
			var db: Dictionary = b.to_dict()
			da.erase("locked")
			db.erase("locked")
			if da != db:
				_check("start state %s seed %d identical" % [cid, sd], false, "dicts differ")
				continue
			_check("start state %s seed %d identical (hp, deck, relics, gold, piece deck, offer)" % [cid, sd],
				a.hp == b.hp and a.deck_ids == b.deck_ids and a.relics == b.relics and a.gold == b.gold
				and a.piece_deck == b.piece_deck and a.shape_removals == b.shape_removals and a.region_offer == b.region_offer)
	print("FAILS=%d" % fails)
	quit(fails)


func _all_open(cfg: AchievementsConfig, progress: ProgressState, characters: CharacterConfig) -> bool:
	for cid: String in characters.ids():
		if not cfg.is_unlocked("character", cid, progress):
			return false
	return true
