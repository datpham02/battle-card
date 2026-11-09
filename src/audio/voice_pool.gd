class_name VoicePool
extends RefCounted
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §6, §9): decides which sounds may play. Pure bookkeeping on
## a caller-given clock (no node, no stream), so it is unit-tested with a fake clock; [AudioDirector] maps its voice
## handles onto pre-created AudioStreamPlayers.
##
## Per request, in order:
## 1. Expired one-shots are released ([code]ends <= now[/code]; loops live until released / stopped).
## 2. Same-event cooldown: a repeat of an event within its [code]cooldown_ms[/code] while the first voice still plays is
##    MERGED into that voice: its cell count grows and its size tier is raised (5 one-cell impacts in one tick = one L
##    voice, not five). A repeat whose first voice is gone is dropped.
## 3. Per-event cap ([code]max_voices[/code]): the oldest voice of the same event is stolen.
## 4. Per-category cap (one category per bus, [method AudioBank.voice_cap]): the lowest-priority, then oldest voice of
##    that bus with a priority <= the new one is stolen; none = dropped. Critical voices are never stolen.
## 5. Total cap: buses with reserved voices (Warning) keep them; other buses share the rest with the same stealing rule.

## Handle returned for a dropped request.
const NO_VOICE: int = -1

var _bank: AudioBank
var _voices: Array[Dictionary] = []
var _last_start: Dictionary = {}
var _next_handle: int = 1


## A pool reading caps, priorities, cooldowns and tiers from [param bank].
func _init(bank: AudioBank) -> void:
	_bank = bank


## Asks to start event [param id] at [param now] (seconds) for [param duration] seconds. [param params]: cells (int,
## default 1), tier (String; default from cells), tag (String), loop (bool; default from the event).
## Returns {action: "play" | "merge" | "drop", handle, stolen: Array[int], tier, retier: bool, reason}.
func request(id: String, now: float, duration: float, params: Dictionary = {}) -> Dictionary:
	expire(now)
	var def: Dictionary = _bank.get_event(id)
	if def.is_empty():
		return _drop("unknown")
	var cells: int = maxi(int(params.get("cells", 1)), 1)
	var tier: String = str(params.get("tier", _bank.size_tier(cells)))
	var prio: int = _bank.priority_of(id)
	var bus: String = str(def.get("bus", ""))
	var cooldown: float = float(def.get("cooldown_ms", 0)) / 1000.0
	if _last_start.has(id) and now - float(_last_start[id]["time"]) < cooldown - 0.0000001:
		var first: Dictionary = _find(int(_last_start[id]["handle"]))
		if first.is_empty():
			return _drop("cooldown")
		first["cells"] = int(first["cells"]) + cells
		var merged_tier: String = _bank.size_tier(int(first["cells"]))
		var raise: bool = AudioBank.TIERS.find(merged_tier) > AudioBank.TIERS.find(str(first["tier"])) and not params.has("tier")
		if raise:
			first["tier"] = merged_tier
		return {"action": "merge", "handle": int(first["handle"]), "stolen": [] as Array[int], "tier": str(first["tier"]),
			"retier": raise, "reason": "cooldown"}
	var stolen: Array[int] = []
	var max_voices: int = int(def.get("max_voices", 0))
	if max_voices > 0 and _count(func(v: Dictionary) -> bool: return v["id"] == id) >= max_voices:
		stolen.append(_steal(_oldest(func(v: Dictionary) -> bool: return v["id"] == id)))
	var bus_cap: int = _bank.voice_cap(bus)
	if bus_cap > 0 and _count(func(v: Dictionary) -> bool: return v["bus"] == bus) >= bus_cap:
		var victim: Dictionary = _weakest(func(v: Dictionary) -> bool: return v["bus"] == bus, prio)
		if victim.is_empty():
			return _drop("bus_cap")
		stolen.append(_steal(victim))
	if _bank.reserved_voices(bus) <= 0:
		var shared_cap: int = _bank.voice_cap("total") - _reserved_total()
		var shared := func(v: Dictionary) -> bool: return _bank.reserved_voices(str(v["bus"])) <= 0
		if shared_cap > 0 and _count(shared) >= shared_cap:
			var victim: Dictionary = _weakest(shared, prio)
			if victim.is_empty():
				return _drop("total_cap")
			stolen.append(_steal(victim))
	var handle: int = _next_handle
	_next_handle += 1
	var loop: bool = bool(params.get("loop", def.get("loop", false)))
	_voices.append({"handle": handle, "id": id, "bus": bus, "priority": prio, "started": now,
		"ends": INF if loop else now + maxf(duration, 0.0), "tier": tier, "cells": cells, "tag": str(params.get("tag", "")),
		"loop": loop})
	_last_start[id] = {"time": now, "handle": handle}
	return {"action": "play", "handle": handle, "stolen": stolen, "tier": tier, "retier": false, "reason": ""}


## Releases one-shots that ended by [param now]; returns their handles.
func expire(now: float) -> Array[int]:
	var gone: Array[int] = []
	for i: int in range(_voices.size() - 1, -1, -1):
		if float(_voices[i]["ends"]) <= now:
			gone.append(int(_voices[i]["handle"]))
			_voices.remove_at(i)
	return gone


## Releases voice [param handle] (finished or stopped by the director).
func release(handle: int) -> void:
	for i: int in range(_voices.size() - 1, -1, -1):
		if int(_voices[i]["handle"]) == handle:
			_voices.remove_at(i)


## Releases every voice tagged [param tag] and returns their handles.
func release_tag(tag: String) -> Array[int]:
	var out: Array[int] = []
	for v: Dictionary in _voices.duplicate():
		if str(v["tag"]) == tag:
			out.append(int(v["handle"]))
			release(int(v["handle"]))
	return out


## Releases every voice on one of [param buses] (all voices when empty) and returns their handles.
func release_buses(buses: Array[String] = []) -> Array[int]:
	var out: Array[int] = []
	for v: Dictionary in _voices.duplicate():
		if buses.is_empty() or buses.has(str(v["bus"])):
			out.append(int(v["handle"]))
			release(int(v["handle"]))
	return out


## Live voices (copies): {handle, id, bus, priority, started, ends, tier, cells, tag, loop}.
func voices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _voices:
		out.append(v.duplicate())
	return out


## Number of live voices on [param bus] (all buses when "").
func active_count(bus: String = "") -> int:
	return _count(func(v: Dictionary) -> bool: return bus.is_empty() or v["bus"] == bus)


## Forgets every voice and cooldown.
func clear() -> void:
	_voices.clear()
	_last_start.clear()


func _drop(reason: String) -> Dictionary:
	return {"action": "drop", "handle": NO_VOICE, "stolen": [] as Array[int], "tier": "", "retier": false, "reason": reason}


func _find(handle: int) -> Dictionary:
	for v: Dictionary in _voices:
		if int(v["handle"]) == handle:
			return v
	return {}


func _count(pred: Callable) -> int:
	var n: int = 0
	for v: Dictionary in _voices:
		if pred.call(v):
			n += 1
	return n


func _oldest(pred: Callable) -> Dictionary:
	var best: Dictionary = {}
	for v: Dictionary in _voices:
		if pred.call(v) and (best.is_empty() or float(v["started"]) < float(best["started"])):
			best = v
	return best


# The lowest-priority, then oldest voice matching [param pred] that a [param prio] request may steal (never Critical,
# never a higher priority); empty when none.
func _weakest(pred: Callable, prio: int) -> Dictionary:
	var best: Dictionary = {}
	for v: Dictionary in _voices:
		if not pred.call(v) or int(v["priority"]) >= AudioBank.PRIORITY_CRITICAL or int(v["priority"]) > prio:
			continue
		if best.is_empty() or int(v["priority"]) < int(best["priority"]) \
				or (int(v["priority"]) == int(best["priority"]) and float(v["started"]) < float(best["started"])):
			best = v
	return best


func _steal(v: Dictionary) -> int:
	var h: int = int(v["handle"])
	release(h)
	return h


func _reserved_total() -> int:
	var n: int = 0
	for b: String in _bank.bus_names():
		n += _bank.reserved_voices(b)
	return n
