class_name PassiveRegistry
extends RefCounted
## The one place that maps a passive id (characters.json `passive.id`) to its script. Adding a
## passive = one BasePassive subclass + one line in [constant SCRIPTS].
## Implements: Story 018.

## id -> GDScript (every script must extend BasePassive).
const SCRIPTS: Dictionary = {
	"second_wind": preload("res://src/passives/second_wind.gd"),
	"wide_caster": preload("res://src/passives/wide_caster.gd"),
	"quick_blade": preload("res://src/passives/quick_blade.gd"),
}


## A fresh instance of the passive [param id], or null (with a warning) for an unknown id.
static func create(id: String) -> BasePassive:
	if not SCRIPTS.has(id):
		push_warning("PassiveRegistry: unknown passive id '%s' (known: %s), none used" % [id, ", ".join(known_ids())])
		return null
	var instance: Object = (SCRIPTS[id] as GDScript).new()
	if not (instance is BasePassive):
		push_warning("PassiveRegistry: script of passive '%s' does not extend BasePassive" % id)
		return null
	return instance as BasePassive


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
