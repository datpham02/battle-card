extends SceneTree
## Story 035 Part F1 (P1b): Spare / Execute rules. Only a REGION boss raises the fate choice (never the final
## match, a miniboss or a battle); the Execute offer has the configured count and rarity floor and never an
## owned relic; Spare gives nothing (the boss reward token still comes from complete_node); boss_fates and
## pending_fate round-trip the save; a v5 save loads with the Story 035 fields at their defaults; ProgressState
## v6 counts fates / endings and loads old files; endings at 5/0, 0/5, 3/2, 1/4 spared/executed.
## Uses the shipped chapters.json / characters.json / relics.json. Prints PASS/FAIL lines and FAILS=n.

const HERO: String = "kiem_si"
const RUN_SEED: int = 3535
const MAX_HP: float = 300.0
const CFG: Dictionary = {"luck_start": 0.0, "luck_per_node": 1.0, "rest_heal_ratio": 0.3, "rest_forge_levels": 1, "boss_removal_tokens": 1}
## The shipped `world.fate` / `world.endings` starting values (story Part A / C).
const FATE_CFG: Dictionary = {"execute_artifact_offers": 3, "execute_min_rarity": "rare", "fate_hold_sec": 0.6}
const ENDINGS_CFG: Dictionary = {"spare_min_ratio": 1.0, "execute_max_ratio": 0.0}
const OFFER_SEEDS: int = 25

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


# A world run already inside the first offered region (column 0), so it saves / loads as a live run.
func _session(chapters: ChaptersConfig) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	var s: RunSession = RunSession.begin_world(chapters, ch, RUN_SEED, 1)
	s.choose_region(s.region_offer[0], 0)
	return s


func _rt(s: RunSession, chapters: ChaptersConfig) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), chapters)


func _fates(spared: int, executed: int) -> Array:
	var out: Array = []
	for i: int in spared:
		out.append({"floor": i, "region_id": "ch1", "match_id": "m%d" % i, "fate": "spare"})
	for i: int in executed:
		out.append({"floor": spared + i, "region_id": "ch2", "match_id": "x%d" % i, "fate": "execute"})
	return out


func _rank(id: String) -> int:
	return RelicConfig.rarity_rank(str(RelicRegistry.info(id).get("rarity", "")))


func _init() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()

	# --- only region bosses get a fate ---
	_check("region boss -> fate", FateLogic.is_boss_fate_node("boss", false))
	_check("final match -> no fate", not FateLogic.is_boss_fate_node("boss", true))
	_check("miniboss / battle / elite -> no fate", not FateLogic.is_boss_fate_node("miniboss", false)
		and not FateLogic.is_boss_fate_node("battle", false) and not FateLogic.is_boss_fate_node("elite", false))

	# --- execute offer: count, rarity floor, never owned, deterministic ---
	var rare_rank: int = RelicConfig.rarity_rank("rare")
	var count_ok: bool = true
	var floor_ok: bool = true
	var distinct_ok: bool = true
	for sd: int in OFFER_SEEDS:
		var offer: Array[String] = FateLogic.roll_execute_offer([], FATE_CFG, null, sd)
		count_ok = count_ok and offer.size() == int(FATE_CFG["execute_artifact_offers"])
		for id: String in offer:
			floor_ok = floor_ok and _rank(id) >= rare_rank
			distinct_ok = distinct_ok and offer.count(id) == 1
	_check("execute offer has execute_artifact_offers ids", count_ok)
	_check("execute offer rarity >= execute_min_rarity (rare)", floor_ok)
	_check("execute offer ids are distinct", distinct_ok)
	_check("execute offer is deterministic by seed", FateLogic.roll_execute_offer([], FATE_CFG, null, 7) == FateLogic.roll_execute_offer([], FATE_CFG, null, 7))
	var two: Dictionary = FATE_CFG.duplicate()
	two["execute_artifact_offers"] = 2
	_check("execute offer count follows the config", FateLogic.roll_execute_offer([], two, null, 1).size() == 2)
	var epic_cfg: Dictionary = FATE_CFG.duplicate()
	epic_cfg["execute_min_rarity"] = "epic"
	var epic_ok: bool = true
	for sd: int in OFFER_SEEDS:
		for id: String in FateLogic.roll_execute_offer([], epic_cfg, null, sd):
			epic_ok = epic_ok and _rank(id) >= RelicConfig.rarity_rank("epic")
	_check("execute offer floor follows the config (epic)", epic_ok)
	var owned: Array[String] = []
	for id: String in RelicRegistry.all_ids():
		if _rank(id) == rare_rank and owned.size() < 3:
			owned.append(id)
	var owned_ok: bool = owned.size() == 3
	for sd: int in OFFER_SEEDS:
		var offer2: Array[String] = FateLogic.roll_execute_offer(owned, FATE_CFG, null, sd)
		owned_ok = owned_ok and offer2.size() == 3
		for id: String in offer2:
			owned_ok = owned_ok and not owned.has(id) and _rank(id) >= rare_rank
	_check("execute offer never contains an owned relic", owned_ok, str(owned))

	# --- record_fate / spare gives nothing ---
	var s: RunSession = _session(chapters)
	_check("fresh run: no fates, nothing pending", s.boss_fates.is_empty() and not s.pending_fate and s.pending_fate_match.is_empty())
	_check("record_fate without pending -> false", not s.record_fate("spare") and s.boss_fates.is_empty())
	s.begin_fate({"floor": 0, "region_id": s.region_id, "match_id": "boss_a"})
	_check("begin_fate sets pending", s.pending_fate and s.is_fate_pending() and str(s.pending_fate_match["match_id"]) == "boss_a")
	_check("unknown fate refused, still pending", not s.record_fate("maybe") and s.pending_fate and s.boss_fates.is_empty())
	var relics_before: Array[String] = s.relic_ids()
	var gold_before: int = s.gold
	var tokens_before: int = s.removal_tokens
	_check("spare recorded", s.record_fate("spare") and not s.pending_fate and s.pending_fate_match.is_empty() and s.boss_fates.size() == 1)
	_check("spare entry shape", s.boss_fates[0] == {"floor": 0, "region_id": s.region_id, "match_id": "boss_a", "fate": "spare"}, str(s.boss_fates))
	_check("spare gives nothing (no relic, no offer, no gold)", s.relic_ids() == relics_before and not s.has_pending_relic_offer() and s.gold == gold_before)
	s.choose_node(0)
	var res: Dictionary = s.complete_node(MAX_HP, MAX_HP, "boss", CFG)
	_check("after spare the boss reward token still comes", bool(res["advanced"]) and s.removal_tokens == tokens_before + 1)

	# --- pending_fate and boss_fates round-trip the save ---
	var p: RunSession = _session(chapters)
	p.begin_fate({"floor": 0, "region_id": p.region_id, "match_id": "boss_a"})
	p.record_fate("execute")
	p.begin_fate({"floor": 1, "region_id": p.region_id, "match_id": "boss_b"})
	var back: RunSession = _rt(p, chapters)
	_check("pending run loads", back != null and not back.needs_restart)
	_check("pending_fate round trip", back != null and back.pending_fate and back.pending_fate_match == {"floor": 1, "region_id": p.region_id, "match_id": "boss_b"}, str(back.pending_fate_match if back != null else {}))
	_check("boss_fates round trip", back != null and back.boss_fates == p.boss_fates)
	_check("resumed fate can be chosen", back != null and back.record_fate("spare") and back.boss_fates.size() == 2 and str(back.boss_fates[1]["match_id"]) == "boss_b")
	var store: ProgressStore = ProgressStore.memory_store()
	var ps0 := ProgressState.new()
	ps0.set_run(p)
	store.save_state(ps0)
	var through_store: RunSession = RunSession.from_dict(store.load_state(chapters).get_run_dict(), chapters)
	_check("pending fate survives the progress store", through_store != null and through_store.pending_fate and through_store.boss_fates.size() == 1)

	# --- v5 save loads ---
	var v5: Dictionary = JSON.parse_string(JSON.stringify(_session(chapters).to_dict()))
	v5["version"] = 5
	for k: String in ["boss_fates", "pending_fate", "pending_fate_match", "stats"]:
		v5.erase(k)
	var o5: RunSession = RunSession.from_dict(v5, chapters)
	# World Map v2 (D5): saves below MIN_LOADABLE_VERSION 8 (v5-v7) take the needs_restart path, like pre-v5 ones.
	_check("v5 save restarts (needs_restart, empty map)", o5 != null and o5.needs_restart and o5.map.is_empty() and o5.restart_reason == RunSession.RESTART_OLD_SAVE)
	_check("v5 save: empty fates, nothing pending, zero stats", o5 != null and o5.boss_fates.is_empty() and not o5.pending_fate
		and int(o5.stats["matches_won"]) == 0 and float(o5.stats["damage_dealt"]) == 0.0 and (o5.stats["death"] as Dictionary).is_empty())
	_check("v5 save re-saves as the current version (v8, World Map v2)", o5 != null and int(o5.to_dict()["version"]) == RunSession.SAVE_VERSION and RunSession.SAVE_VERSION == 8)
	var v4: Dictionary = v5.duplicate(true)
	v4["version"] = 4
	var o4: RunSession = RunSession.from_dict(v4, chapters)
	_check("v4 save still needs_restart", o4 != null and o4.needs_restart)
	var bad: Dictionary = p.to_dict()
	bad["boss_fates"] = [{"floor": 0, "fate": "maybe"}, "x", {"floor": 2, "region_id": "ch1", "match_id": "m", "fate": "execute"}]
	var cleaned: RunSession = RunSession.from_dict(bad, chapters)
	_check("unknown saved fates dropped", cleaned != null and cleaned.boss_fates.size() == 1 and str(cleaned.boss_fates[0]["fate"]) == "execute")

	# --- ProgressState v6 ---
	_check("ProgressState version 8 (Story 038)", ProgressState.VERSION == 8)
	var ps := ProgressState.new()
	_check("fresh progress: empty fate keys", ps.get_spared_bosses().is_empty() and ps.get_executed_bosses().is_empty()
		and ps.get_spare_total() == 0 and ps.get_execute_total() == 0 and ps.get_endings_seen().is_empty())
	ps.record_fate("boss_a", "spare")
	ps.record_fate("boss_a", "spare")
	ps.record_fate("boss_b", "execute")
	ps.record_fate("boss_a", "execute")
	ps.record_fate("boss_c", "maybe")
	ps.record_ending("spare")
	ps.record_ending("spare")
	ps.record_ending("balance")
	_check("record_fate: sets dedup, totals count every choice", ps.get_spared_bosses() == (["boss_a"] as Array[String])
		and ps.get_executed_bosses() == (["boss_b", "boss_a"] as Array[String]) and ps.get_spare_total() == 2 and ps.get_execute_total() == 2)
	_check("record_ending dedup", ps.get_endings_seen() == (["spare", "balance"] as Array[String]))
	var json: Dictionary = JSON.parse_string(ps.to_json())
	_check("to_json carries the v6 keys (progress is v7 since Story 037)", int(json["version"]) == ProgressState.VERSION and json.has("spared_bosses") and json.has("executed_bosses")
		and json.has("spare_total") and json.has("execute_total") and json.has("endings_seen"))
	var ps_back: ProgressState = ProgressState.from_json(ps.to_json(), chapters)
	_check("progress v6 round trip", ps_back.get_spared_bosses() == ps.get_spared_bosses() and ps_back.get_executed_bosses() == ps.get_executed_bosses()
		and ps_back.get_spare_total() == 2 and ps_back.get_execute_total() == 2 and ps_back.get_endings_seen() == ps.get_endings_seen())
	var old5: ProgressState = ProgressState.from_json('{"version":5,"locale":"en","regions_boss_beaten":["ch1"],"best_floor":3,"cleared_bosses":2}', chapters)
	_check("v5 progress file loads with empty fate keys", old5.get_locale() == "en" and old5.has_region_boss_beaten("ch1") and old5.get_best_floor() == 3
		and old5.get_spared_bosses().is_empty() and old5.get_spare_total() == 0 and old5.get_endings_seen().is_empty())
	old5.record_fate("boss_a", "execute")
	_check("old file then adds", old5.get_executed_bosses() == (["boss_a"] as Array[String]) and old5.get_execute_total() == 1)
	var junk: ProgressState = ProgressState.from_json('{"version":6,"spared_bosses":"x","spare_total":-4,"endings_seen":["spare","spare",""]}', chapters)
	_check("bad v6 values sanitised", junk.get_spared_bosses().is_empty() and junk.get_spare_total() == 0 and junk.get_endings_seen() == (["spare"] as Array[String]))

	# --- endings ---
	_check("spare_ratio 5/0 = 1, 0/5 = 0, empty = -1", FateLogic.spare_ratio(_fates(5, 0)) == 1.0 and FateLogic.spare_ratio(_fates(0, 5)) == 0.0 and FateLogic.spare_ratio([]) == -1.0)
	_check("ending 5/0 -> spare", FateLogic.ending_for(_fates(5, 0), ENDINGS_CFG) == "spare")
	_check("ending 0/5 -> execute", FateLogic.ending_for(_fates(0, 5), ENDINGS_CFG) == "execute")
	_check("ending 3/2 -> balance", FateLogic.ending_for(_fates(3, 2), ENDINGS_CFG) == "balance")
	_check("ending 1/4 -> balance", FateLogic.ending_for(_fates(1, 4), ENDINGS_CFG) == "balance")
	_check("ending with no fates -> balance", FateLogic.ending_for([], ENDINGS_CFG) == "balance")
	_check("ending with missing cfg keys uses the defaults", FateLogic.ending_for(_fates(0, 5), {}) == "execute" and FateLogic.ending_for(_fates(5, 0), {}) == "spare")
	var e: RunSession = _session(chapters)
	for f: Dictionary in _fates(3, 2):
		e.begin_fate(f)
		e.record_fate(str(f["fate"]))
	_check("RunSession.ending_id delegates (3/2 -> balance)", e.ending_id(ENDINGS_CFG) == "balance" and e.boss_fates.size() == 5)

	print("FAILS=%d" % fails)
	quit(fails)
