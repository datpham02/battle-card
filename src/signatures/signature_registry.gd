class_name SignatureRegistry
extends RefCounted
## The one place that maps a signature id (characters.json `signature.id`) to its script.
## Adding a signature = one BaseSignature subclass + one line in [constant SCRIPTS].
## Implements: Story 021.

## id -> GDScript (every script must extend BaseSignature).
const SCRIPTS: Dictionary = {
	"tram": preload("res://src/signatures/tram.gd"),
	"thien_hoa": preload("res://src/signatures/thien_hoa.gd"),
	"anh_bo": preload("res://src/signatures/anh_bo.gd"),
	"vay_bat": preload("res://src/signatures/vay_bat.gd"),
	"thanh_an": preload("res://src/signatures/thanh_an.gd"),
}


## A fresh instance of the signature [param id], or null (with a warning) for an unknown id.
static func create(id: String) -> BaseSignature:
	if not SCRIPTS.has(id):
		push_warning("SignatureRegistry: unknown signature id '%s' (known: %s), none used" % [id, ", ".join(known_ids())])
		return null
	var instance: Object = (SCRIPTS[id] as GDScript).new()
	if not (instance is BaseSignature):
		push_warning("SignatureRegistry: script of signature '%s' does not extend BaseSignature" % id)
		return null
	return instance as BaseSignature


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
