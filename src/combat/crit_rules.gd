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
## Skill v2 M19 (docs/skill-v2/02-mechanics-catalog.md): target_burning (the target stands on a burning cell),
## target_on_hazard (any zone under it: burn, thorns, cracking / hole), target_marked (Rạn stacks), self_hp_high (the
## caster at or above SELF_HP_HIGH_RATIO), combo_3 (the 3rd+ hit wave of a multi-hit cast, ctx.wave_index >= 2),
## line_full (the cast holds a `line` piece of LINE_FULL_LEN+ cells, ctx.cast_context), first_strike (the target was not
## hit for FIRST_STRIKE_SEC, ctx.since_target_hit; false while the caller does not know it).
const CONDITIONS: Array[String] = ["target_pinned", "target_burning", "target_on_hazard", "target_marked", "self_hp_high",
	"combo_3", "line_full", "first_strike"]
const SELF_HP_HIGH_RATIO: float = 0.7
const LINE_FULL_LEN: int = 4
const FIRST_STRIKE_SEC: float = 3.0
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
	var state: CombatState = ctx.get("state") as CombatState
	match when:
		"target_pinned":
			return status != null and status.is_pinned(target_side)
		"target_burning", "target_on_hazard":
			if status == null or state == null:
				return false
			var cells: Array[Vector2i] = state.enemy_footprint_cells() if target_side == CombatState.Side.ENEMY else [state.player_cell] as Array[Vector2i]
			for c: Vector2i in cells:
				if when == "target_burning" and status.is_burning(c):
					return true
				if when == "target_on_hazard" and not status.zone_kinds_at(c).is_empty():
					return true
			return false
		"target_marked":
			return status != null and status.fragile_stacks(target_side) > 0
		"self_hp_high":
			if state == null:
				return false
			var caster_player: bool = target_side == CombatState.Side.ENEMY
			var hp: float = state.player_hp if caster_player else state.enemy_hp
			var mx: float = state.player_max_hp if caster_player else state.enemy_max_hp
			return mx > 0.0 and hp / mx >= SELF_HP_HIGH_RATIO
		"combo_3":
			return int(ctx.get("wave_index", -1)) >= 2
		"line_full":
			for p: Variant in (ctx.get("cast_context", {}) as Dictionary).get("pieces", []) as Array:
				var d: Dictionary = p as Dictionary
				if (d.get("tags", []) as Array).has("line") and (d.get("cells", []) as Array).size() >= LINE_FULL_LEN:
					return true
			return false
		"first_strike":
			return float(ctx.get("since_target_hit", -1.0)) >= FIRST_STRIKE_SEC
	return false


## The multiplier the card [param skill] (a resolved card dict) gets for this hit: its crit.mult when the condition
## holds, else 1.0.
static func mult_for(skill: Dictionary, ctx: Dictionary) -> float:
	var crit: Dictionary = skill.get("crit", {}) as Dictionary
	if crit.is_empty() or not holds(str(crit.get("when", "")), ctx):
		return 1.0
	return float(crit.get("mult", DEFAULT_MULT))
