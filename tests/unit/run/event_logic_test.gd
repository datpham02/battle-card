extends SceneTree
## Story 033 Part C/E: EventLogic (pure) over the shipped events.json. The 8 events exist and each ends
## with a "Rời đi" choice that costs and does nothing; pick_event is seeded and never repeats while an
## unseen event is left; every effect type applies correctly (gold, hp, relic, card_offer, curse,
## remove_card tokens / pick, upgrade_card, fight + finish_fight, run_modifier, swap_relic); `requires`
## greys a choice out with a reason and resolve refuses it with no change; HP never goes below 1; the
## outcome is the same after a save / load; loi_the adds slow_step for 2 matches; every string key of
## the events exists in vi and en (bodies <= 300 characters).
## Prints PASS/FAIL lines and FAILS=n; exits 1 on any failure.

const HERO: String = "kiem_si"
const SEED: int = 4242
const MAX_HP: float = 300.0
const CSV_PATH: String = "res://assets/i18n/strings.csv"
const BODY_CAP: int = 300
const EXPECTED: Array[String] = ["ban_tho_mau", "ke_buon_nguyen", "song_bac", "tran_thach", "suoi_tinh",
	"ke_lang_thang", "mo_hoang", "loi_the"]

var fails: int = 0
var passes: int = 0
var _chapters: ChaptersConfig = null


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _new_run() -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	var run: RunSession = RunSession.begin_world(_chapters, ch, SEED, 1)
	run.gold = 0
	return run


func _rt(run: RunSession) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), _chapters)


func _choice_index(event_id: String, choice_id: String) -> int:
	var choices: Array = EventLogic.get_event(event_id)["choices"]
	for i: int in choices.size():
		if str((choices[i] as Dictionary)["id"]) == choice_id:
			return i
	return -1


func _applied(result: Dictionary, type: String) -> Dictionary:
	for e: Dictionary in result.get("effects_applied", []):
		if str(e["type"]) == type:
			return e
	return {}


# key -> [vi, en] from the CSV.
func _csv() -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 3:
			out[row[0]] = [row[1], row[2]]
	return out


func _initialize() -> void:
	_chapters = ChaptersConfig.load_from_file()
	var cards: SkillConfig = SkillConfig.load_from_file()
	var relics: RelicConfig = RelicConfig.load_from_file()

	# --- data shape: the 8 events, last choice = leave
	var ids: Array[String] = EventLogic.event_ids()
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	var want: Array[String] = EXPECTED.duplicate()
	want.sort()
	_check("events.json has the 8 events of the story", sorted_ids == want, str(ids))
	var leave_ok: bool = true
	for id: String in ids:
		var choices: Array = EventLogic.get_event(id)["choices"]
		var last: Dictionary = choices[choices.size() - 1]
		var outs: Array = last["outcomes"]
		leave_ok = leave_ok and choices.size() >= 2 and choices.size() <= 4 and str(last["label_key"]) == "ui.event.leave" \
			and str(last["cost_key"]).is_empty() and (last["requires"] as Dictionary).is_empty() \
			and outs.size() == 1 and ((outs[0] as Dictionary)["effects"] as Array).is_empty()
	_check("every event's last choice is Rời đi with no cost and no effect", leave_ok)
	var chances_ok: bool = true
	for id: String in ids:
		for c: Dictionary in EventLogic.get_event(id)["choices"]:
			var total: float = 0.0
			for o: Dictionary in c["outcomes"]:
				total += float(o["chance"])
			chances_ok = chances_ok and is_equal_approx(total, 1.0)
	_check("every choice's chances sum to 1", chances_ok)

	# --- strings vi + en
	var csv: Dictionary = _csv()
	var missing: Array[String] = []
	var long: Array[String] = []
	var keys: Array[String] = [EventLogic.KEY_NEED_GOLD, EventLogic.KEY_NEED_RELIC, EventLogic.KEY_NEED_HP,
		EventLogic.KEY_NEED_CARDS, EventLogic.KEY_NEED_UPGRADABLE, EventLogic.KEY_BAD_CHOICE, "ui.event.bad_pick",
		"event.tran_thach.fight_won"]
	for reason: String in [ShopLogic.REASON_UNKNOWN, ShopLogic.REASON_SOLD, ShopLogic.REASON_USED, ShopLogic.REASON_NO_GOLD,
			ShopLogic.REASON_OWNED, ShopLogic.REASON_BAD_INDEX, ShopLogic.REASON_MIN_DECK, ShopLogic.REASON_FULL_HP]:
		keys.append("ui.shop.reason." + reason)
	for id: String in ids:
		var e: Dictionary = EventLogic.get_event(id)
		keys.append(str(e["title_key"]))
		keys.append(str(e["body_key"]))
		for c: Dictionary in e["choices"]:
			keys.append(str(c["label_key"]))
			if not str(c["cost_key"]).is_empty():
				keys.append(str(c["cost_key"]))
			for o: Dictionary in c["outcomes"]:
				keys.append(str(o["result_key"]))
	for key: String in keys:
		var row: Variant = csv.get(key)
		if row == null or str(row[0]).strip_edges().is_empty() or str(row[1]).strip_edges().is_empty():
			missing.append(key)
		elif key.ends_with(".body") and (str(row[0]).length() > BODY_CAP or str(row[1]).length() > BODY_CAP):
			long.append(key)
	_check("every event / shop key has vi and en", missing.is_empty(), str(missing))
	_check("every event body is <= 300 characters per language", long.is_empty(), str(long))

	# --- pick_event: seeded, no repeat
	_check("pick_event is deterministic", EventLogic.pick_event(SEED, 1, 2, 0, []) == EventLogic.pick_event(SEED, 1, 2, 0, []))
	var used: Array = EXPECTED.duplicate()
	used.erase("mo_hoang")
	_check("pick_event never repeats while one is unseen", EventLogic.pick_event(SEED, 1, 2, 0, used) == "mo_hoang")
	_check("pick_event restarts the pool when all were seen", ids.has(EventLogic.pick_event(SEED, 1, 2, 0, EXPECTED.duplicate())))

	# --- ban_tho_mau: hp cost + relic floor rare; requires blocks
	var run: RunSession = _new_run()
	var give: int = _choice_index("ban_tho_mau", "give")
	var r: Dictionary = EventLogic.resolve("ban_tho_mau", give, run, MAX_HP)
	var relic_id: String = str(_applied(r, "relic").get("id", ""))
	_check("ban_tho_mau: lose 15 % max HP", bool(r["ok"]) and is_equal_approx(run.hp, MAX_HP * 0.85), str(run.hp))
	_check("ban_tho_mau: a relic of rarity rare or better", run.has_relic(relic_id)
		and RelicConfig.rarity_rank(str(relics.get_relic(relic_id)["rarity"])) >= RelicConfig.rarity_rank("rare"), relic_id)
	var weak: RunSession = _new_run()
	weak.hp = 40.0
	var d: Dictionary = EventLogic.describe("ban_tho_mau", weak, MAX_HP)
	var c0: Dictionary = d["choices"][give]
	_check("describe greys out an HP cost the player cannot pay, with a reason",
		not bool(c0["enabled"]) and c0["reason_key"] == EventLogic.KEY_NEED_HP and bool(c0["needs_confirm"]), str(c0))
	_check("describe keeps Rời đi enabled", bool((d["choices"][(d["choices"] as Array).size() - 1] as Dictionary)["enabled"]))
	var refused: Dictionary = EventLogic.resolve("ban_tho_mau", give, weak, MAX_HP)
	_check("resolve refuses a blocked choice and changes nothing", not bool(refused["ok"]) and is_equal_approx(weak.hp, 40.0) and weak.relic_ids().is_empty())

	# --- HP never below 1 (fixture event without requires)
	var fixture: Array = [{"id": "fx", "title_key": "t", "body_key": "b", "choices": [
		{"id": "hurt", "label_key": "l", "cost_key": "", "requires": {}, "confirm": true,
			"outcomes": [{"chance": 1.0, "result_key": "r", "effects": [{"type": "hp", "ratio": -0.9}]}]},
		{"id": "leave", "label_key": "ui.event.leave", "cost_key": "", "requires": {}, "confirm": false,
			"outcomes": [{"chance": 1.0, "result_key": "r", "effects": []}]}]}]
	var fragile: RunSession = _new_run()
	fragile.hp = 10.0
	EventLogic.resolve("fx", 0, fragile, MAX_HP, {"events": fixture})
	_check("an HP loss never drops HP below 1", is_equal_approx(fragile.hp, 1.0), str(fragile.hp))

	# --- song_bac: gold requires, gold effects, determinism, save / load
	var poor: RunSession = _new_run()
	var dd: Dictionary = EventLogic.describe("song_bac", poor, MAX_HP)
	_check("song_bac: both bets greyed out with 0 gold (need_gold)",
		not bool(dd["choices"][0]["enabled"]) and not bool(dd["choices"][1]["enabled"]) and dd["choices"][0]["reason_key"] == EventLogic.KEY_NEED_GOLD
		and dd["choices"][0]["reason_args"] == [30], str(dd["choices"]))
	var gambler: RunSession = _new_run()
	gambler.gold = 100
	var copy: RunSession = _rt(gambler)
	var small: int = _choice_index("song_bac", "bet_small")
	var g1: Dictionary = EventLogic.resolve("song_bac", small, gambler, MAX_HP)
	var g2: Dictionary = EventLogic.resolve("song_bac", small, copy, MAX_HP)
	var amount: int = int(_applied(g1, "gold").get("amount", 0))
	_check("song_bac small bet: +75 or -30", (amount == 75 and gambler.gold == 175) or (amount == -30 and gambler.gold == 70), str(g1))
	_check("same outcome after a save / load", g1["outcome_index"] == g2["outcome_index"] and g1["effects_applied"] == g2["effects_applied"] and gambler.gold == copy.gold)
	var seen: Dictionary = {}
	for s: int in 60:
		var bettor: RunSession = _new_run()
		bettor.gold = 100
		seen[int(EventLogic.resolve("song_bac", small, bettor, MAX_HP, {"seed": s})["outcome_index"])] = true
	_check("both bet outcomes happen over 60 seeds", seen.size() == 2, str(seen))

	# --- ke_buon_nguyen: curse + card_offer pick
	var buyer: RunSession = _new_run()
	var kb: Dictionary = EventLogic.resolve("ke_buon_nguyen", _choice_index("ke_buon_nguyen", "accept"), buyer, MAX_HP)
	var picks: Array = kb["pending_picks"]
	var offer: Array = (picks[0] as Dictionary)["ids"] if not picks.is_empty() else []
	var all_epic: bool = offer.size() == 3
	for id: Variant in offer:
		all_epic = all_epic and cards.get_rarity(str(id)) == "epic" and not cards.is_curse(str(id))
	_check("ke_buon_nguyen: curse ganh_nang joins the deck at level 1", buyer.deck_ids.has("ganh_nang") and _level_of(buyer, "ganh_nang") == 1)
	_check("ke_buon_nguyen: a pick of 3 epic cards", all_epic, str(offer))
	var size_before: int = buyer.deck.size()
	var done: Dictionary = EventLogic.complete_pick(buyer, picks[0], str(offer[0]))
	_check("complete_pick adds the chosen card", bool(done["ok"]) and (buyer.deck.size() == size_before or buyer.deck.size() == size_before + 1) and buyer.deck_ids.has(str(offer[0])))
	_check("complete_pick refuses a card not offered", not bool(EventLogic.complete_pick(buyer, picks[0], "not_a_card")["ok"]))
	EventLogic.resolve("ke_buon_nguyen", 0, buyer, MAX_HP, {"seed": SEED + 1})
	_check("a second curse is a second copy, never a level up", buyer.deck_ids.count("ganh_nang") == 2 and _level_of(buyer, "ganh_nang") == 1)

	# --- tran_thach: pending fight, finish_fight
	var duelist: RunSession = _new_run()
	var tt: Dictionary = EventLogic.resolve("tran_thach", 0, duelist, MAX_HP)
	var fight: Dictionary = tt["pending_fight"]
	_check("tran_thach: pending danger fight at +1 tier", fight.get("kind") == "danger" and int(fight.get("tier_add", 0)) == 1 and duelist.relic_ids().is_empty(), str(fight))
	var lost: Dictionary = EventLogic.finish_fight(duelist, fight, false, MAX_HP)
	_check("tran_thach lost: no reward", not bool(lost["ok"]) and duelist.relic_ids().is_empty() and duelist.gold == 0)
	var won: Dictionary = EventLogic.finish_fight(duelist, fight, true, MAX_HP)
	_check("tran_thach won: a relic and 25 gold", bool(won["ok"]) and duelist.relic_ids().size() == 1 and duelist.gold == 25, str(won))

	# --- suoi_tinh: heal / hp cost + upgrade pick
	var bather: RunSession = _new_run()
	bather.hp = 100.0
	EventLogic.resolve("suoi_tinh", _choice_index("suoi_tinh", "drink"), bather, MAX_HP)
	_check("suoi_tinh drink: +25 % max HP", is_equal_approx(bather.hp, 100.0 + 0.25 * MAX_HP), str(bather.hp))
	var temper: RunSession = _new_run()
	var st: Dictionary = EventLogic.resolve("suoi_tinh", _choice_index("suoi_tinh", "bathe"), temper, MAX_HP)
	var up_pick: Dictionary = (st["pending_picks"] as Array)[0] if not (st["pending_picks"] as Array).is_empty() else {}
	_check("suoi_tinh bathe: -10 % max HP and an upgrade pick", is_equal_approx(temper.hp, MAX_HP * 0.9) and up_pick.get("type") == "upgrade_card", str(st))
	var lvl: int = int(temper.deck[0]["level"])
	_check("complete_pick upgrades the chosen card", bool(EventLogic.complete_pick(temper, up_pick, 0)["ok"]) and int(temper.deck[0]["level"]) == lvl + 1)
	var maxed: RunSession = _new_run()
	for e: Dictionary in maxed.deck:
		e["level"] = SkillConfig.MAX_LEVEL
	var ds: Dictionary = EventLogic.describe("suoi_tinh", maxed, MAX_HP)
	_check("suoi_tinh bathe greyed out when no card can be upgraded",
		not bool(ds["choices"][_choice_index("suoi_tinh", "bathe")]["enabled"]) and ds["choices"][_choice_index("suoi_tinh", "bathe")]["reason_key"] == EventLogic.KEY_NEED_UPGRADABLE)

	# --- ke_lang_thang: swap_relic
	var trader: RunSession = _new_run()
	var swap: int = _choice_index("ke_lang_thang", "swap")
	_check("ke_lang_thang greyed out without a relic", not bool(EventLogic.describe("ke_lang_thang", trader, MAX_HP)["choices"][swap]["enabled"]))
	trader.add_relic("an_chu")
	_check("ke_lang_thang greyed out with only a boss relic", not bool(EventLogic.describe("ke_lang_thang", trader, MAX_HP)["choices"][swap]["enabled"]))
	trader.add_relic("an_don")
	var sw: Dictionary = EventLogic.resolve("ke_lang_thang", swap, trader, MAX_HP)
	var swapped: Dictionary = _applied(sw, "swap_relic")
	_check("swap gives the common relic for a rare one", swapped.get("lost") == "an_don" and not trader.has_relic("an_don")
		and trader.has_relic(str(swapped.get("gained", ""))) and str(relics.get_relic(str(swapped["gained"]))["rarity"]) == "rare"
		and trader.has_relic("an_chu"), str(swapped))

	# --- mo_hoang: gold or curse oan_hon
	var outcomes: Dictionary = {}
	for s: int in 60:
		var digger: RunSession = _new_run()
		var mh: Dictionary = EventLogic.resolve("mo_hoang", 0, digger, MAX_HP, {"seed": s})
		if not _applied(mh, "gold").is_empty():
			outcomes["gold"] = int(_applied(mh, "gold")["amount"]) == 40 and digger.gold == 40
		if not _applied(mh, "curse").is_empty():
			outcomes["curse"] = digger.deck_ids.has("oan_hon")
	_check("mo_hoang: both outcomes happen and apply (+40 gold / oan_hon)", outcomes.get("gold", false) and outcomes.get("curse", false), str(outcomes))

	# --- loi_the: run modifier 2 matches + token + gold
	var vow: RunSession = _new_run()
	var tokens: int = vow.removal_tokens
	EventLogic.resolve("loi_the", 0, vow, MAX_HP)
	var mod: Dictionary = vow.run_modifiers[0] if not vow.run_modifiers.is_empty() else {}
	_check("loi_the: slow_step for 2 matches with step_cooldown x1.2", mod.get("id") == "slow_step" and int(mod.get("matches_left", 0)) == 2
		and is_equal_approx(float(vow.active_modifier_params("step_cooldown").get("mul", 0.0)), 1.2), str(mod))
	_check("loi_the: +1 removal token and +30 gold", vow.removal_tokens == tokens + 1 and vow.gold == 30)
	var vow2: RunSession = _rt(vow)
	_check("loi_the modifier survives a save / load", vow2 != null and vow2.has_run_modifier("slow_step"))
	vow.tick_run_modifiers()
	vow.tick_run_modifiers()
	_check("loi_the modifier ends after 2 matches", not vow.has_run_modifier("slow_step"))

	# --- leave does nothing
	var walker: RunSession = _new_run()
	var before: Dictionary = walker.to_dict()
	var lv: Dictionary = EventLogic.resolve("ban_tho_mau", give + 1, walker, MAX_HP)
	_check("Rời đi changes nothing", bool(lv["ok"]) and (lv["effects_applied"] as Array).is_empty() and walker.to_dict() == before)
	_check("a bad choice index is refused", not bool(EventLogic.resolve("ban_tho_mau", 9, walker, MAX_HP)["ok"]))

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _level_of(run: RunSession, id: String) -> int:
	var best: int = 0
	for e: Dictionary in run.deck:
		if str(e["id"]) == id:
			best = maxi(best, int(e["level"]))
	return best
