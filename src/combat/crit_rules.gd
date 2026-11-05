class_name CritRules
extends RefCounted
## Conditional critical hits (cast rhythm spec 2026-11-05 section 1.2, design/quick-specs/nhip-ra-chieu-2026-11-05.md).
## A card may carry `"crit": {"when": <condition>, "mult": <x>}`; a hit that meets the condition AT THE MOMENT OF THE
## HIT deals its damage x mult (CutEffects.apply, right after Fragile and before the featured / relic / execute /
## passive / signature multipliers and the flat defense) and reports result.crit = true. Stateless and pure.
##
## Extending: add the condition id to [constant CONDITIONS] and one branch to [method holds]; [param ctx] carries what
## the hit knows (state, status, target_side, and later e.g. combo_hit_index). The first story ships `target_pinned`
## only; the spec's target_burning / combo_3 / target_on_hazard / self_hp_high land with their heroes' stories.

## The condition ids a card's crit.when may name. An unknown id is dropped at load (warning) and never crits.
const CONDITIONS: Array[String] = ["target_pinned"]
## Multiplier used when a crit omits `mult` (the spec's starting value).
const DEFAULT_MULT: float = 1.5


## Normalises a card's raw `crit` value: {} for none / invalid (warning when present but bad), else
## {"when": String, "mult": float >= 1}. [param where] names the card in warnings.
static func normalize(raw: Variant, where: String = "") -> Dictionary:
	if raw == null:
		return {}
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("CritRules: %s crit must be an object, ignored" % where)
		return {}
	var d: Dictionary = raw as Dictionary
	var when: String = str(d.get("when", ""))
	if not CONDITIONS.has(when):
		push_warning("CritRules: %s crit.when '%s' unknown, ignored" % [where, when])
		return {}
	var mult: float = DEFAULT_MULT
	var raw_mult: Variant = d.get("mult", DEFAULT_MULT)
	if typeof(raw_mult) == TYPE_FLOAT or typeof(raw_mult) == TYPE_INT:
		mult = maxf(float(raw_mult), 1.0)
	else:
		push_warning("CritRules: %s crit.mult must be a number, using %s" % [where, DEFAULT_MULT])
	return {"when": when, "mult": mult}


## True when condition [param when] holds for the hit described by [param ctx]:
## {state: CombatState, status: StatusEffects (may be null), target_side: int}. Unknown condition / missing data: false.
static func holds(when: String, ctx: Dictionary) -> bool:
	var status: StatusEffects = ctx.get("status") as StatusEffects
	var target_side: int = int(ctx.get("target_side", CombatState.Side.ENEMY))
	match when:
		"target_pinned":
			return status != null and status.is_pinned(target_side)
	return false


## The multiplier the card [param skill] (a resolved card dict) gets for this hit: its crit.mult when the condition
## holds, else 1.0.
static func mult_for(skill: Dictionary, ctx: Dictionary) -> float:
	var crit: Dictionary = skill.get("crit", {}) as Dictionary
	if crit.is_empty() or not holds(str(crit.get("when", "")), ctx):
		return 1.0
	return float(crit.get("mult", DEFAULT_MULT))
