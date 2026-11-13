extends SceneTree
## Combat audio sync (docs/skill-v2/10-audio-system-design.md §4, §11 combat_audio_sync_test + golden), through the REAL
## path (cards.json, CastContext from real pieces, SwingArbiter clock, CutEffects) with a CombatAudioBridge and a silent
## AudioDirector driven frame by frame like the game:
## - every scheduled impact body of Trảm Địa, Ngàn Kiếm and Hỏa Lôi starts at the first arbiter clock >= event `at` -
##   lead (and before the impact resolves);
## - the hit layer plays only for events that hit; a miss plays the body and no hit layer;
## - Ngàn Kiếm cancelled before the release plays its cancel cue, stops the channel loop and plays no impact;
## - Hỏa Lôi's 5-cell detonation is ONE impact voice at tier L;
## - audio on / off never changes gameplay: the impact log, HP and swing results are identical with and without the
##   bridge + director.
## Run: godot --headless --path . -s res://tests/unit/audio/combat_audio_sync_test.gd

const HERO := Vector2i(1, 1)
const STEP: float = 1.0 / 60.0
const LEAD: float = 0.03
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const PLUS5: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_scheduled_bodies_start_at_at_minus_lead("tram_dia", "bar4", 0, BAR4, 0.5)
	test_scheduled_bodies_start_at_at_minus_lead("ngan_kiem", "bar4", 0, BAR4, 0.5)
	test_scheduled_bodies_start_at_at_minus_lead("hoa_loi", "bar4", 0, BAR4, -1.0)
	test_miss_plays_body_without_hit_layer()
	test_ngan_kiem_cancel()
	test_hoa_loi_burn_loop_follows_the_burning_cells()
	test_audio_never_changes_gameplay()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A match on a 4 x 3 half with the boss at [param boss]; [param audio] attaches a bridge + silent director.
func _world(boss: Vector2i, audio: bool) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	player.channel_extend_fn = func(id: String) -> float: return float(sc.get_skill(id).get("channel_extend_sec", 0.0))
	player.cast_time_fn = func(id: String) -> float: return float(sc.get_skill(id).get("cast_time_sec", -1.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"side": side, "cells": ev["cells"], "kind": ev["kind"], "mult": ev["mult"], "at": snappedf(arb.clock(), 0.000001),
			"hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	var sched: Array = []
	arb.cast_scheduled.connect(func(side: int, c: Dictionary) -> void: sched.append({"side": side, "cast": c, "clock": arb.clock()}))
	var done: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: done.append({"side": side, "hit": r.get("hit"),
		"damage": r.get("damage"), "skill": r.get("skill_id")}))
	var w: Dictionary = {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "enemy": enemy, "arb": arb,
		"log": log, "sched": sched, "done": done, "director": null, "bridge": null}
	if audio:
		var director := AudioDirector.silent()
		director.lead_override = LEAD
		var bridge := CombatAudioBridge.new(director)
		bridge.attach({"arbiter": arb, "player_actor": player, "enemy_actor": enemy, "state": state, "skills": sc, "status": fx})
		w["director"] = director
		w["bridge"] = bridge
	return w


func _free(w: Dictionary) -> void:
	if w["bridge"] != null:
		(w["bridge"] as CombatAudioBridge).detach()
		(w["bridge"] as CombatAudioBridge).free()
	if w["director"] != null:
		(w["director"] as AudioDirector).free()


func _ctx(w: Dictionary, id: String, shape: String, rot: int, cells: Array[Vector2i]) -> Dictionary:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, rot)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, id: String, shape: String, rot: int, cells: Array[Vector2i], swing: float) -> bool:
	return (w["player"] as CutActor).begin_swing(cells, id, true, 1, swing, {}, _ctx(w, id, shape, rot, cells))


# Frame loop like the game: the arbiter ticks, then the director advances (and fires due cues).
func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		if w["director"] != null:
			(w["director"] as AudioDirector).advance(STEP)
		t += STEP


func _plays(w: Dictionary, prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in (w["director"] as AudioDirector).play_log:
		if e["op"] == "play" and str(e["id"]).begins_with(prefix):
			out.append(e)
	return out


func test_scheduled_bodies_start_at_at_minus_lead(id: String, shape: String, rot: int, cells: Array[Vector2i], swing: float) -> void:
	var w: Dictionary = _world(Vector2i(5, 1), true)
	ck("%s: the cast starts" % id, _cast(w, id, shape, rot, cells, swing))
	_run(w, 4.0)
	var sched: Array = w["sched"]
	ck("%s: one scheduled cast" % id, sched.size() == 1)
	if sched.is_empty():
		_free(w)
		return
	var groups: Array[Dictionary] = AudioEventRules.impact_groups((w["director"] as AudioDirector).get_bank(), sched[0]["cast"]["events"])
	var bodies: Array[Dictionary] = []
	for e: Dictionary in _plays(w, "skill.%s.impact" % id):
		bodies.append(e)
	ck("%s: one impact body per event group (%d)" % [id, groups.size()], bodies.size() == groups.size(), "%d bodies" % bodies.size())
	var timed: bool = bodies.size() == groups.size()
	var worst: float = 0.0
	for i: int in mini(bodies.size(), groups.size()):
		# An event closer than the lead to its scheduling (Trảm Địa's burst at t = 0) starts the moment it is known.
		var target: float = maxf(float(groups[i]["at"]) - LEAD, float(sched[0]["clock"]))
		var started: float = float(bodies[i]["clock"])
		worst = maxf(worst, absf(started - target))
		timed = timed and started >= target - 0.000001 and started < target + STEP + 0.000001 and started <= float(groups[i]["at"]) + 0.000001
	ck("%s: each body started at the first arbiter frame >= max(at - lead, scheduled) (worst offset %.4f s < 1 frame)" % [id, worst], timed)
	var hits: int = (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["hit"] and e["side"] == 0).size()
	var layers: int = _plays(w, "skill.generic.hit").size() + (w["director"] as AudioDirector).play_log.filter(
		func(e: Dictionary) -> bool: return e["op"] == "merge" and e["id"] == "skill.generic.hit").size()
	# Hỏa Lôi's blast is its own hit (audio_events cards.hoa_loi hit / body_hit ""): no layer, no thump on top of it
	# unified identity (2026-11-13): no separate hit layer on any card; impact material + body thump only
	var want_layers: int = 0
	ck("%s: hit layers per hitting event (%d expected)" % [id, want_layers], hits > 0 and layers == want_layers, "%d layers" % layers)
	if id == "hoa_loi":
		var blast_at: float = float(groups[0]["at"])
		var thumps: Array = (w["director"] as AudioDirector).play_log.filter(func(e: Dictionary) -> bool:
			return e["op"] == "play" and e["id"] == "combat.hit.enemy")
		ck("hoa_loi: no body thump anywhere (blast or burn ticks)", thumps.is_empty(),
			str(thumps.map(func(e: Dictionary) -> float: return float(e["clock"]))))
		var sizzles: Array[Dictionary] = _plays(w, "status.burn.hurt")
		ck("hoa_loi: the burn ticks on the boss sizzle instead (after the blast)", not sizzles.is_empty()
			and sizzles.all(func(e: Dictionary) -> bool: return float(e["clock"]) > blast_at), "%d sizzles" % sizzles.size())
		ck("hoa_loi: a 4-seal detonation is one impact voice at tier M", bodies.size() == 1 and bodies[0]["tier"] == "M"
			and int(bodies[0]["cells"]) == 4)
		var tk: Array = _plays(w, "skill.hoa_loi.tick").map(func(e: Dictionary) -> float: return float(e["clock"]))
		var ig: Array = _plays(w, "skill.hoa_loi.ignite").map(func(e: Dictionary) -> float: return float(e["clock"]))
		# real cast: release 0.45 (seals appear) -> the one fire burst there; the fuse is silent (no lock, ticks, prime or
		# drone: user 2026-11-09)
		ck("hoa_loi: the fire burst on the release frame, silent fuse", ig.size() == 1 and absf(ig[0] - 0.45) <= STEP + 0.0001
			and _plays(w, "skill.hoa_loi.seal").is_empty() and tk.is_empty() and _plays(w, "skill.hoa_loi.prime").is_empty()
			and _plays(w, "skill.hoa_loi.charge").is_empty(), "burst %s ticks %s" % [str(ig), str(tk)])
	_free(w)


func test_miss_plays_body_without_hit_layer() -> void:
	var w: Dictionary = _world(Vector2i(5, 2), true)
	_cast(w, "tram_dia", "bar4", 0, BAR4, 0.5)
	_run(w, 4.0)
	var misses: bool = (w["log"] as Array).all(func(e: Dictionary) -> bool: return not e["hit"])
	ck("tram_dia off the boss's row: every event misses", misses and not (w["log"] as Array).is_empty())
	ck("the bodies still play (hit or miss)", _plays(w, "skill.tram_dia.impact").size() >= 1)
	ck("no hit layer and no enemy body hit on a miss", _plays(w, "skill.generic.hit").is_empty() and _plays(w, "combat.hit.enemy").is_empty())
	_free(w)


func test_ngan_kiem_cancel() -> void:
	var w: Dictionary = _world(Vector2i(5, 1), true)
	_cast(w, "ngan_kiem", "bar4", 0, BAR4, 0.5)
	_run(w, 0.3)
	var pool: VoicePool = (w["director"] as AudioDirector).get_pool()
	ck("channelling: the steel resonance loop plays", pool.voices().any(func(v: Dictionary) -> bool: return v["id"] == "skill.ngan_kiem.channel_loop"))
	(w["player"] as CutActor).cancel()
	_run(w, 3.0)
	ck("the cancel cue plays", _plays(w, "skill.ngan_kiem.cancel").size() == 1)
	ck("the loop stopped", not pool.voices().any(func(v: Dictionary) -> bool: return v["id"] == "skill.ngan_kiem.channel_loop"))
	ck("no impact, no commit, no NGAT!", _plays(w, "skill.ngan_kiem.impact").is_empty() and _plays(w, "skill.ngan_kiem.commit").is_empty()
		and _plays(w, "combat.interrupt").is_empty())
	_free(w)


# Hỏa Lôi: the detonation ignites its cells for event_payload.ignite.sec; the burning-ground loop runs exactly while a
# cell burns (it starts with the first ignite, stops when the last cell burns out) and the embers-out cue plays once,
# at that burn-out, not at a fixed delay after the detonation (bug 2026-11-09: it played 0.4 s after the blast).
func test_hoa_loi_burn_loop_follows_the_burning_cells() -> void:
	var w: Dictionary = _world(Vector2i(5, 1), true)
	var fx: StatusEffects = w["fx"]
	var burn_sec: float = float((w["sc"] as SkillConfig).get_skill("hoa_loi")["event_payload"]["ignite"]["sec"])
	var lit: Array = []
	var out: Array = []
	fx.cell_ignited.connect(func(_c: Vector2i) -> void: lit.append((w["arb"] as SwingArbiter).clock()))
	fx.cell_burned_out.connect(func(_c: Vector2i) -> void: out.append((w["arb"] as SwingArbiter).clock()))
	_cast(w, "hoa_loi", "bar4", 0, BAR4, -1.0)
	var pool: VoicePool = (w["director"] as AudioDirector).get_pool()
	var loop_on: Array = []
	var t: float = 0.0
	while t < 6.0:
		_run(w, STEP)
		t += STEP
		if pool.voices().any(func(v: Dictionary) -> bool: return v["id"] == "status.burn.loop"):
			loop_on.append((w["arb"] as SwingArbiter).clock())
	ck("hoa_loi: the detonation ignited cells that later burned out", not lit.is_empty() and not out.is_empty(),
		"%d lit, %d out" % [lit.size(), out.size()])
	if lit.is_empty() or out.is_empty():
		_free(w)
		return
	var first_lit: float = lit.min()
	var last_out: float = out.max()
	ck("burn lasts the card's ignite time (%.1f s)" % burn_sec, absf(last_out - first_lit - burn_sec) < 0.1,
		"%.3f -> %.3f" % [first_lit, last_out])
	# unified identity (no drone): status.burn.loop is a one-shot "fire caught" cue on the first ignite, not a loop
	var caught: Array[Dictionary] = _plays(w, "status.burn.loop")
	ck("the fire-caught cue plays once, on the first ignite (no drone over the burn)", caught.size() == 1
		and absf(float(caught[0]["clock"]) - first_lit) <= STEP * 1.5 and (loop_on.is_empty() or loop_on.max() < last_out),
		"cue %s, burn %.3f..%.3f" % [str(caught.map(func(e: Dictionary) -> float: return float(e["clock"]))), first_lit, last_out])
	var outs: Array[Dictionary] = _plays(w, "status.burn.out")
	ck("embers out plays once, when the last cell burns out", outs.size() == 1 and absf(float(outs[0]["clock"]) - last_out) <= STEP * 1.5,
		str(outs.map(func(e: Dictionary) -> float: return float(e["clock"]))))
	ck("no fixed-delay aftermath for hoa_loi any more", _plays(w, "skill.hoa_loi.aftermath").is_empty())
	_free(w)


# One scripted match: three reference casts, a boss swing that interrupts, a cancel. Returns the gameplay record.
func _scripted(audio: bool) -> Dictionary:
	var w: Dictionary = _world(Vector2i(5, 1), audio)
	_cast(w, "tram_dia", "bar4", 0, BAR4, 0.5)
	_run(w, 2.0)
	_cast(w, "ngan_kiem", "bar4", 0, BAR4, 0.5)
	_run(w, 3.0)
	var hero: Array[Vector2i] = [HERO]
	(w["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 0.6)
	_cast(w, "hoa_loi", "plus5", 0, PLUS5, -1.0)
	_run(w, 4.0)
	_cast(w, "ngan_kiem", "bar4", 0, BAR4, 0.5)
	_run(w, 0.2)
	(w["player"] as CutActor).cancel()
	_run(w, 2.0)
	var state: CombatState = w["state"]
	var rec: Dictionary = {"log": str(w["log"]), "done": str(w["done"]), "enemy_hp": state.enemy_hp, "player_hp": state.player_hp,
		"clock": (w["arb"] as SwingArbiter).clock(), "scheduled": (w["sched"] as Array).size()}
	var sounds: int = (w["director"] as AudioDirector).play_log.size() if audio else 0
	_free(w)
	rec["sounds"] = sounds
	return rec


func test_audio_never_changes_gameplay() -> void:
	var off: Dictionary = _scripted(false)
	var on: Dictionary = _scripted(true)
	ck("the scripted match does something (impacts, damage, sounds)", int(off["scheduled"]) >= 3 and float(off["enemy_hp"]) < 1000.0
		and int(on["sounds"]) > 10, "%d casts, hp %.1f, %d sounds" % [off["scheduled"], off["enemy_hp"], on["sounds"]])
	ck("identical impact log with and without audio", off["log"] == on["log"])
	ck("identical swing results", off["done"] == on["done"])
	ck("identical HP and clock", off["enemy_hp"] == on["enemy_hp"] and off["player_hp"] == on["player_hp"] and off["clock"] == on["clock"],
		"%s / %s" % [off["enemy_hp"], on["enemy_hp"]])
