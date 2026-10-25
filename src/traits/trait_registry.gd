class_name TraitRegistry
extends RefCounted
## The one place that maps a trait id (chapters.json `traits[].id`) to its script. Adding a mechanic
## = one BossTrait subclass + one line in [constant SCRIPTS]. Scripts are preloaded so no
## reflection or path lookup happens at match start.
## Implements: Story 014 (Part B).

## id -> GDScript (every script must extend BossTrait).
const SCRIPTS: Dictionary = {
	"rotten_thrower": preload("res://src/traits/rotten_thrower.gd"),
	"row_burner": preload("res://src/traits/row_burner.gd"),
	"step_reactor": preload("res://src/traits/step_reactor.gd"),
	"fuse_cannon": preload("res://src/traits/fuse_cannon.gd"),
	"slam": preload("res://src/traits/slam.gd"),
	"frost_aura": preload("res://src/traits/frost_aura.gd"),
	"phase_shift": preload("res://src/traits/phase_shift.gd"),
	"seal_caster": preload("res://src/traits/seal_caster.gd"),
	"thorn_field": preload("res://src/traits/thorn_field.gd"),
}


## A fresh instance of the trait [param id], or null (with a warning) for an unknown id.
static func create(id: String) -> BossTrait:
	if not SCRIPTS.has(id):
		push_warning("TraitRegistry: unknown trait id '%s' (known: %s), skipped" % [id, ", ".join(known_ids())])
		return null
	var script: GDScript = SCRIPTS[id] as GDScript
	var instance: Object = script.new()
	if not (instance is BossTrait):
		push_warning("TraitRegistry: script of trait '%s' does not extend BossTrait, skipped" % id)
		return null
	return instance as BossTrait


## True when [param id] is registered.
static func has_id(id: String) -> bool:
	return SCRIPTS.has(id)


## Every registered id, sorted.
static func known_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in SCRIPTS.keys():
		ids.append(str(key))
	ids.sort()
	return ids
