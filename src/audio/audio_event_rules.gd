class_name AudioEventRules
extends RefCounted
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §4–§7): PURE mapping from one gameplay fact (a signal and its
## payload) to audio CUES. No node, no clock of its own: the caller passes the times. The bridges call these and hand
## the cues to [method AudioDirector.apply]. A cue is a Dictionary with an [code]op[/code]:
## - [code]play[/code] {id, cells, step, tag[, tier]}: start now.
## - [code]at[/code] {id, at, cells, step, tag[, tier]}: start at arbiter clock time [code]at[/code] (minus the latency lead).
## - [code]after[/code] {id, delay, cells, step, tag}: start after [code]delay[/code] seconds of (unpaused) match time.
## - [code]stop[/code] {tag}: stop the playing voices tagged [code]tag[/code] (loops, wind-ups).
## - [code]cancel[/code] {tag}: drop the not-yet-started cues tagged [code]tag[/code].
## - [code]stop_all[/code] / [code]cancel_all[/code]: every combat voice / every pending cue (match end).
## Gameplay timing never comes from here: impact bodies sit on the [code]at[/code] times of [signal SwingArbiter.cast_scheduled].

## CombatState.Side values (kept literal so the rules load without the combat classes).
const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1
## How long a body hit waits for the signal that names its source (see [method on_damaged]): under one frame.
const BODY_DEFER_SEC: float = 0.001


## Tag of side [param side]'s wind-up voice.
static func swing_tag(side: int) -> String:
	return "swing:%d" % side


## Tag of side [param side]'s channel loop.
static func channel_tag(side: int) -> String:
	return "channel:%d" % side


## Tag of side [param side]'s deferred cancel cue (dropped when the cancel was an interrupt).
static func cancel_tag(side: int) -> String:
	return "cancel:%d" % side


## Tag of every scheduled cue of cast [param cast_id].
static func cast_tag(cast_id: int) -> String:
	return "cast:%d" % cast_id


## Tag of a boss warning's imminent cue.
static func warn_tag(skill_id: String) -> String:
	return "warn:%s" % skill_id


## {delivery, impact} of a card definition (cards.json entry); "" when missing.
static func skill_kind(skill_def: Dictionary) -> Dictionary:
	var d: Variant = skill_def.get("delivery", {})
	if not (d is Dictionary):
		return {"delivery": "", "impact": ""}
	return {"delivery": str((d as Dictionary).get("type", "")), "impact": str((d as Dictionary).get("impact", ""))}


## The event id of [param phase] for card [param skill_id] ("" = silent).
static func skill_event(bank: AudioBank, skill_id: String, skill_def: Dictionary, phase: String) -> String:
	var k: Dictionary = skill_kind(skill_def)
	return bank.resolve_skill(skill_id, str(k["delivery"]), str(k["impact"]), phase)


## [signal CutActor.swing_started]: the player's wind-up (and channel loop for a channelled card); the enemy's swing
## start is the boss wind-up warning.
static func on_swing_started(bank: AudioBank, side: int, skill_id: String, skill_def: Dictionary, cells: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if side != SIDE_PLAYER:
		_add(out, {"op": "play", "id": "warn.boss.windup", "cells": cells, "step": 0, "tag": swing_tag(side)})
		return out
	_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "windup"), "cells": cells, "step": 0,
		"tag": swing_tag(side)})
	_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "channel_loop"), "cells": cells, "step": 0,
		"tag": channel_tag(side)})
	return out


## [signal CutActor.swing_cancelled]: stops the wind-up and channel loop; the player's cancel cue is deferred (tag
## [method cancel_tag]) so an interrupt in the same tick can replace it ([method on_swing_interrupted]).
static func on_swing_cancelled(bank: AudioBank, side: int, skill_id: String, skill_def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"op": "stop", "tag": swing_tag(side)}, {"op": "stop", "tag": channel_tag(side)}]
	if side == SIDE_PLAYER:
		_add(out, {"op": "after", "id": skill_event(bank, skill_id, skill_def, "cancel"), "delay": 0.0, "cells": 1,
			"step": 0, "tag": cancel_tag(side)})
	return out


## [signal SwingArbiter.swing_interrupted]: NGẮT! replaces the victim's cancel cue (an interrupt is not a cancel).
static func on_swing_interrupted(victim_side: int) -> Array[Dictionary]:
	return [{"op": "cancel", "tag": cancel_tag(victim_side)}, {"op": "stop", "tag": swing_tag(victim_side)},
		{"op": "stop", "tag": channel_tag(victim_side)},
		{"op": "play", "id": "combat.interrupt", "cells": 1, "step": 0, "tag": ""}]


## [signal SwingArbiter.cast_scheduled] at arbiter clock [param now]: commit, travel, the fuse cues (seal, charge,
## ticks, prime), one impact cue per group of events sharing an [code]at[/code] (size tier by the group's cells; the
## group holding a [method AudioBank.final_kinds] event plays impact_final at tier L, the others impact with
## step = group index)
## and the aftermath; or the fizzle when the cast armed nothing.
static func on_cast_scheduled(bank: AudioBank, side: int, cast: Dictionary, skill_def: Dictionary, now: float) -> Array[Dictionary]:
	var skill_id: String = str(cast.get("skill_id", ""))
	var tag: String = cast_tag(int(cast.get("cast_id", -1)))
	var events: Array = cast.get("events", [])
	var all_cells: int = (cast.get("cells", []) as Array).size()
	var out: Array[Dictionary] = [{"op": "stop", "tag": swing_tag(side)}, {"op": "stop", "tag": channel_tag(side)}]
	if events.is_empty():
		if bool(cast.get("fizzled", false)):
			_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "fizzle"), "cells": 1, "step": 0, "tag": tag})
		return out
	_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "commit"), "cells": all_cells, "step": 0, "tag": tag})
	var groups: Array[Dictionary] = impact_groups(bank, events)
	var first_at: float = float(groups[0]["at"])
	if first_at - now >= bank.timing("travel_min_sec", 0.05):
		_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "travel"), "cells": all_cells, "step": 0,
			"tag": tag})
	if cast.has("fuse_sec"):
		# Synced to the seal VFX (src/art/fuse_fx.gd): the seals draw in for timing.seal_lock_delay_sec (DRAW_IN_SEC),
		# then show their rings = armed -> the lock cue; the countdown drops a ring at fuse/3 and 2fuse/3 and flickers
		# from timing.final_warning_sec (FINAL_SEC) before `at` -> one pulse at each of those visible changes.
		_add(out, {"op": "at", "id": skill_event(bank, skill_id, skill_def, "seal"), "at": now + bank.timing("seal_lock_delay_sec", 0.0),
			"cells": all_cells, "step": 0, "tag": tag})
		_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "charge"), "cells": 1, "step": 0, "tag": tag})
		var ticks: int = int(bank.timing("fuse_ticks", 3.0))
		var fuse: float = first_at - now
		var tick_at: Array[float] = []
		for i: int in range(1, ticks):
			tick_at.append(now + fuse * float(i) / float(ticks))
		var final_warn: float = bank.timing("final_warning_sec", 0.0)
		if final_warn > 0.0 and first_at - final_warn > (tick_at.back() if not tick_at.is_empty() else now):
			tick_at.append(first_at - final_warn)
		for i: int in tick_at.size():
			_add(out, {"op": "at", "id": skill_event(bank, skill_id, skill_def, "tick"), "at": tick_at[i], "cells": 1, "step": i, "tag": tag})
		var prime_at: float = first_at - bank.timing("prime_lead_sec", 0.3)
		if prime_at > now:
			_add(out, {"op": "at", "id": skill_event(bank, skill_id, skill_def, "prime"), "at": prime_at, "cells": 1,
				"step": 0, "tag": tag})
	for i: int in groups.size():
		var g: Dictionary = groups[i]
		var phase: String = "impact_final" if bool(g["final"]) else "impact"
		_add(out, {"op": "at", "id": skill_event(bank, skill_id, skill_def, phase), "at": float(g["at"]),
			"cells": int(g["cells"]), "tier": AudioBank.TIER_L if bool(g["final"]) else bank.size_tier(int(g["cells"])),
			"step": i, "tag": tag})
	var last_at: float = float(groups[-1]["at"])
	_add(out, {"op": "at", "id": skill_event(bank, skill_id, skill_def, "aftermath"),
		"at": last_at + bank.timing("aftermath_delay_sec", 0.4), "cells": all_cells, "step": 0, "tag": tag})
	return out


## Pure: the impact events grouped by [code]at[/code] (within timing.group_epsilon_sec), sorted by time:
## [{at, cells, final}].
static func impact_groups(bank: AudioBank, events: Array) -> Array[Dictionary]:
	var eps: float = bank.timing("group_epsilon_sec", 0.001)
	var finals: Array[String] = bank.final_kinds()
	var sorted: Array = events.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("at", a.get("t", 0.0))) < float(b.get("at", b.get("t", 0.0))))
	var groups: Array[Dictionary] = []
	for e: Dictionary in sorted:
		var at: float = float(e.get("at", e.get("t", 0.0)))
		var n: int = maxi((e.get("cells", []) as Array).size(), 1)
		var is_final: bool = finals.has(str(e.get("kind", "")))
		if not groups.is_empty() and absf(at - float(groups[-1]["at"])) <= eps:
			groups[-1]["cells"] = int(groups[-1]["cells"]) + n
			groups[-1]["final"] = bool(groups[-1]["final"]) or is_final
		else:
			groups.append({"at": at, "cells": n, "final": is_final})
	return groups


## [signal SwingArbiter.impact_resolved]: the hit layer, only on a hit (the body was pre-scheduled hit or miss).
static func on_impact_resolved(bank: AudioBank, side: int, event: Dictionary, hit: bool, skill_id: String, skill_def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not hit:
		return out
	var victim: int = SIDE_ENEMY if side == SIDE_PLAYER else SIDE_PLAYER
	# the hit is announced here: the deferred body hit of the same damage (on_damaged) is dropped
	out.append({"op": "cancel", "tag": body_tag(victim)})
	var n: int = maxi((event.get("cells", []) as Array).size(), 1)
	_add(out, {"op": "play", "id": skill_event(bank, skill_id, skill_def, "hit"), "cells": n, "step": 0, "tag": ""})
	# a card whose impact IS the hit (Hỏa Lôi's one blast) lists body_hit "": no thump stacked on its impact body
	if not bank.card_silences(skill_id, "body_hit"):
		_add(out, {"op": "play", "id": "combat.hit.enemy" if side == SIDE_PLAYER else "combat.hit.player", "cells": 1, "step": 0, "tag": ""})
	return out


## Tag of side [param side]'s deferred body hit (on_damaged), dropped when the same damage turns out to be a skill
## impact ([method on_impact_resolved]) or a burn tick ([method on_burn_hurt]).
static func body_tag(side: int) -> String:
	return "body:%d" % side


## [signal StatusEffects.burn_hurt]: a burn tick hurt [param side]: no body thump (it would repeat every tick), a light
## sizzle instead.
static func on_burn_hurt(side: int) -> Array[Dictionary]:
	return [{"op": "cancel", "tag": body_tag(side)}, {"op": "play", "id": "status.burn.hurt", "cells": 1, "step": 0, "tag": ""}]


## [signal CombatState.damaged]: the body hit of [param side]; the low-HP heartbeat when the player falls under
## timing.hp_low_ratio ([param hp_ratio] = player hp / max after the hit).
static func on_damaged(bank: AudioBank, side: int, amount: float, hp_ratio: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if amount <= 0.0:
		return out
	# Deferred by BODY_DEFER_SEC (one frame): CombatState.damaged fires before the signal that names the source (a
	# skill impact or a burn tick), which cancels it by tag; any other damage plays the thump one frame later.
	_add(out, {"op": "after", "id": "combat.hit.player" if side == SIDE_PLAYER else "combat.hit.enemy", "delay": BODY_DEFER_SEC,
		"cells": 1, "step": 0, "tag": body_tag(side)})
	if side == SIDE_PLAYER and hp_ratio > 0.0 and hp_ratio < bank.timing("hp_low_ratio", 0.25):
		_add(out, {"op": "play", "id": "combat.hp_low", "cells": 1, "step": 0, "tag": ""})
	return out


## [signal PatternController.warning_started]: the imminent alarm in the last timing.imminent_lead_sec of the warning
## (at once when the warning is shorter).
static func on_warning_started(bank: AudioBank, skill_id: String, warning_sec: float) -> Array[Dictionary]:
	var delay: float = maxf(warning_sec - bank.timing("imminent_lead_sec", 0.5), 0.0)
	return [{"op": "after", "id": "warn.boss.imminent", "delay": delay, "cells": 1, "step": 0, "tag": warn_tag(skill_id)}]


## [signal PatternController.warning_cleared]: drops a pending imminent alarm (a stun or a cancelled skill).
static func on_warning_cleared(skill_id: String) -> Array[Dictionary]:
	return [{"op": "cancel", "tag": warn_tag(skill_id)}]


## [signal PatternController.stage_changed] entered WINDUP (boss wind-up warning).
static func on_boss_windup() -> Array[Dictionary]:
	return [{"op": "play", "id": "warn.boss.windup", "cells": 1, "step": 0, "tag": swing_tag(SIDE_ENEMY)}]


## [signal CombatView.match_ended]: drops pending cues, stops combat voices, plays the stinger.
static func on_match_ended(player_won: bool) -> Array[Dictionary]:
	return [{"op": "cancel_all"}, {"op": "stop_all"},
		{"op": "play", "id": "flow.victory" if player_won else "flow.defeat", "cells": 1, "step": 0, "tag": ""}]


## A Block went into a hold slot ([signal HoldSlots.slot_filled]); pitch tier by its cell count.
static func on_block_pickup(bank: AudioBank, cells: int) -> Array[Dictionary]:
	return [{"op": "play", "id": "block.pickup", "cells": cells, "tier": bank.size_tier(cells), "step": 0, "tag": ""}]


## Tag of the burning-ground loop (one for the whole battle, any burn source).
const BURN_TAG: String = "burn"
## The burning-ground loop and its embers-out cue (audio_events.json).
const BURN_LOOP: String = "status.burn.loop"
const BURN_OUT: String = "status.burn.out"


## The number of burning cells went from [param before] to [param now] (StatusEffects cell_ignited / cell_burned_out):
## the loop starts when the first cell catches fire and stops, with the embers-out cue, when the last one burns out.
## [param now] sizes the loop's tier.
static func on_burning_changed(bank: AudioBank, before: int, now: int) -> Array[Dictionary]:
	if before <= 0 and now > 0:
		return [{"op": "play", "id": BURN_LOOP, "cells": now, "tier": bank.size_tier(now), "step": 0, "tag": BURN_TAG}]
	if before > 0 and now <= 0:
		return [{"op": "stop", "tag": BURN_TAG}, {"op": "play", "id": BURN_OUT, "cells": before, "step": 0, "tag": ""}]
	return []


## A one-shot cue of event [param id] (block.place, combat.parry, ...).
static func ui(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add(out, {"op": "play", "id": id, "cells": 1, "step": 0, "tag": ""})
	return out


## A one-shot UI cue by its NAME in audio_events.json "cues" (tap, toggle, back, menu_open, choose, ...). UI and card
## event ids share their prefixes with translation keys, so code names the cue and the data holds the id.
static func ui_cue(bank: AudioBank, cue_name: String) -> Array[Dictionary]:
	return ui(bank.cue(cue_name))


# Appends [param cue] unless it plays nothing (an empty id resolved as silent).
static func _add(out: Array[Dictionary], cue: Dictionary) -> void:
	if cue.has("id") and str(cue["id"]).is_empty():
		return
	out.append(cue)
