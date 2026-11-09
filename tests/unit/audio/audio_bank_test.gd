extends SceneTree
## AudioBank (docs/skill-v2/10-audio-system-design.md §2, §11 audio_bank_test): the real audio_events.json validates
## (buses, priorities, files on disk, every card / archetype reference); every card of cards.json gets a sound for its
## core phases from the archetypes with zero entries of its own; the fallback order card -> delivery x impact ->
## delivery -> impact -> default; "" = silent; impact_final falls back to impact; size tiers; tier files.
## Run: godot --headless --path . -s res://tests/unit/audio/audio_bank_test.gd

const CORE_PHASES: Array[String] = ["windup", "commit", "impact", "impact_final", "hit", "cancel", "fizzle"]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_real_file_validates()
	test_every_card_has_core_sounds()
	test_reference_cards_use_their_overrides()
	test_fallback_order_and_silence()
	test_size_tiers_and_tier_files()
	test_priorities_and_caps()
	test_missing_file_gives_an_error()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A small bank for the order tests (no files checked).
func _mini() -> AudioBank:
	return AudioBank.new({
		"buses": ["Master", "Skill"], "priorities": {"low": 0, "normal": 1, "high": 2, "critical": 3},
		"defaults": {"gain_db": 0.0, "cooldown_ms": 40},
		"events": {"a": {"bus": "Skill", "priority": "normal", "files": ["res://a.wav"]},
			"b": {"bus": "Skill", "priority": "normal", "files": ["res://b.wav"]},
			"c": {"bus": "Skill", "priority": "normal", "files": ["res://c.wav"]},
			"d": {"bus": "Skill", "priority": "normal", "files": ["res://d.wav"]},
			"e": {"bus": "Skill", "priority": "normal", "files": ["res://e.wav"]}},
		"archetypes": {"*": {"*": {"impact": "e", "windup": "e"}, "burn": {"impact": "d"}},
			"SKY": {"*": {"impact": "c"}, "slash": {"impact": "b", "travel": ""}}},
		"cards": {"hero": {"impact": "a"}},
		"phase_fallbacks": {"impact_final": "impact"},
	})


func test_real_file_validates() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var errs: Array[String] = bank.validate(true)
	ck("audio_events.json validates with every file on disk", errs.is_empty(), str(errs.slice(0, 5)))
	ck("the bank defines events and files", bank.event_ids().size() >= 60 and bank.all_files().size() >= 70,
		"%d events %d files" % [bank.event_ids().size(), bank.all_files().size()])
	var naming: bool = true
	for f: String in bank.all_files():
		naming = naming and f.get_file().begins_with("sfx_") and f.ends_with(".wav") and f.begins_with("res://assets/audio/sfx/")
	ck("files follow sfx_<category>_<subject>_<action>_<nn>.wav under assets/audio/sfx", naming)


func test_every_card_has_core_sounds() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/cards.json"))["cards"]
	var missing: Array[String] = []
	# A phase a card override lists as "" is silent by design (Ngàn Kiếm: no separate charge or commit, user 2026-11-09).
	var overrides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_events.json"))["cards"]
	for id: String in cards.keys():
		var def: Dictionary = sc.get_skill(id)
		for phase: String in CORE_PHASES:
			if overrides.has(id) and str((overrides[id] as Dictionary).get(phase, "-")) == "":
				continue
			var ev: String = AudioEventRules.skill_event(bank, id, def, phase)
			if ev.is_empty() or not bank.has_event(ev):
				missing.append("%s.%s" % [id, phase])
	ck("every card (%d) resolves windup / commit / impact / impact_final / hit / cancel / fizzle" % cards.size(),
		missing.is_empty() and cards.size() >= 36, str(missing.slice(0, 6)))
	var burn_card: Dictionary = sc.get_skill("hoa_xa")
	ck("an archetype card picks its impact family (hoa_xa burn -> skill.impact.burn)",
		AudioEventRules.skill_event(bank, "hoa_xa", burn_card, "impact") == "skill.impact.burn")
	ck("a CASTER_TO_TARGET card gets the travel whoosh", AudioEventRules.skill_event(bank, "kiem_khi", sc.get_skill("kiem_khi"), "travel")
		== "skill.generic.travel")
	ck("a SKY_TO_TARGET card has no travel sound", AudioEventRules.skill_event(bank, "kiem_vu", sc.get_skill("kiem_vu"), "travel").is_empty())


func test_reference_cards_use_their_overrides() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var expect: Dictionary = {
		"tram_dia": {"windup": "skill.tram_dia.windup", "commit": "skill.tram_dia.commit", "travel": "skill.tram_dia.travel",
			"impact": "skill.tram_dia.impact", "impact_final": "skill.tram_dia.impact_final", "aftermath": "skill.tram_dia.aftermath"},
		# user 2026-11-09: the summon is the channel loop alone (take B), no separate charge, no commit cue
		"ngan_kiem": {"windup": "", "channel_loop": "skill.ngan_kiem.channel_loop",
			"commit": "", "impact": "skill.ngan_kiem.impact", "impact_final": "skill.ngan_kiem.impact_final",
			"cancel": "skill.ngan_kiem.cancel"},
		# user 2026-11-09 (animation-synced audio): no fuse drone (charge) and no prime hiss: the VFX shows neither
		# user 2026-11-09: fire catching over the gesture (windup), ONE burst when the seals appear (commit), silent fuse
		"hoa_loi": {"windup": "skill.hoa_loi.windup", "commit": "skill.hoa_loi.ignite", "seal": "", "charge": "",
			"tick": "", "prime": "", "impact": "skill.hoa_loi.impact",
			# no timed aftermath: the burning-ground loop and its embers-out follow the burn (status.burn.loop / .out)
			"aftermath": "", "fizzle": "skill.hoa_loi.fizzle"},
	}
	for card: String in expect.keys():
		var ok: bool = true
		for phase: String in (expect[card] as Dictionary).keys():
			ok = ok and AudioEventRules.skill_event(bank, card, sc.get_skill(card), phase) == expect[card][phase]
		ck("%s phases use its storyboard events (§5)" % card, ok)
	ck("a reference card's unlisted phase still falls back (tram_dia cancel -> generic)",
		AudioEventRules.skill_event(bank, "tram_dia", sc.get_skill("tram_dia"), "cancel") == "skill.generic.cancel")


func test_fallback_order_and_silence() -> void:
	var b: AudioBank = _mini()
	ck("card override first", b.resolve_skill("hero", "SKY", "slash", "impact") == "a")
	ck("then delivery x impact", b.resolve_skill("x", "SKY", "slash", "impact") == "b")
	ck("then delivery x *", b.resolve_skill("x", "SKY", "burn", "impact") == "c")
	ck("then * x impact", b.resolve_skill("x", "GROUND", "burn", "impact") == "d")
	ck("then * x *", b.resolve_skill("x", "GROUND", "slash", "impact") == "e")
	ck("an empty entry is silent and stops the chain", b.resolve_skill("x", "SKY", "slash", "travel") == "")
	ck("an unlisted phase is silent", b.resolve_skill("x", "GROUND", "slash", "aftermath") == "")
	ck("impact_final falls back to impact", b.resolve_skill("hero", "SKY", "slash", "impact_final") == "a")


func test_size_tiers_and_tier_files() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	ck("1-2 cells = S, 3-4 = M, 5+ = L", bank.size_tier(1) == "S" and bank.size_tier(2) == "S" and bank.size_tier(3) == "M"
		and bank.size_tier(4) == "M" and bank.size_tier(5) == "L" and bank.size_tier(9) == "L")
	var s: Array[String] = bank.files_for("skill.hoa_loi.impact", "S")
	var l: Array[String] = bank.files_for("skill.hoa_loi.impact", "L")
	ck("Hoa Loi detonation has one file per tier", bank.has_tier_files("skill.hoa_loi.impact") and s.size() == 1 and l.size() == 1
		and s[0] != l[0] and l[0].ends_with("_l_01.wav"))
	ck("an event without tier files plays its variants at any tier", bank.files_for("skill.ngan_kiem.impact", "L").size() == 4)
	ck("tier gain for plain events: S quieter than L", bank.tier_gain_db("S") < bank.tier_gain_db("L"))


func test_priorities_and_caps() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	ck("boss imminent is Critical on the Warning bus", bank.priority_of("warn.boss.imminent") == AudioBank.PRIORITY_CRITICAL
		and bank.bus_of("warn.boss.imminent") == "Warning")
	var warn_only_warning: bool = true
	for id: String in bank.event_ids():
		if id.begins_with("warn."):
			warn_only_warning = warn_only_warning and bank.bus_of(id) == "Warning"
	ck("every warn.* event is on the Warning bus", warn_only_warning)
	ck("voice caps: total 24, Skill 8, Combat 6, UI 4, Warning 2 reserved", bank.voice_cap("total") == 24 and bank.voice_cap("Skill") == 8
		and bank.voice_cap("Combat") == 6 and bank.voice_cap("UI") == 4 and bank.voice_cap("Warning") == 2 and bank.reserved_voices("Warning") == 2)
	ck("Ngan Kiem drops capped at 3 overlapping", int(bank.get_event("skill.ngan_kiem.impact")["max_voices"]) == 3)
	# the summon loop plays its intro once, then repeats only its sustain (tools/audio/sfx_import.py sustain_loop)
	var loop_stream: AudioStreamWAV = load(bank.files_for("skill.ngan_kiem.channel_loop", "M")[0]) as AudioStreamWAV
	ck("Ngan Kiem summon loop: forward loop from a loop_begin inside the file (no restart of the intro)",
		loop_stream != null and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop_stream.loop_begin > 0
		and loop_stream.loop_begin < int(loop_stream.get_length() * loop_stream.mix_rate),
		"" if loop_stream == null else "mode %d begin %d" % [loop_stream.loop_mode, loop_stream.loop_begin])
	ck("defaults merge into events (pitch range)", float(bank.get_event("ui.tap").get("pitch_semitones", -1.0)) > 0.0)


func test_missing_file_gives_an_error() -> void:
	var b: AudioBank = _mini()
	var errs: Array[String] = b.validate(true)
	ck("missing files are reported", errs.size() >= 5 and str(errs).contains("missing file"), str(errs.slice(0, 2)))
	var broken := AudioBank.new({"buses": ["Master"], "priorities": {"normal": 1}, "events": {"x": {"bus": "Nope", "priority": "loud"}},
		"cards": {"c": {"impact": "ghost"}}})
	var e2: Array[String] = broken.validate(false)
	ck("unknown bus, priority, no file and unknown reference are reported", e2.size() == 4, str(e2))
	ck("a missing data file loads an empty bank with an error", AudioBank.load_from_file("res://no/such.json").errors.size() == 1)
