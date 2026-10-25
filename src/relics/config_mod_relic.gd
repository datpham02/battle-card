class_name ConfigModRelic
extends BaseRelic
## The one shared script of every relic that only changes a config number (Story 032): the params
## ARE the overrides, `{config_key: {mul: x} | {add: x} | {add: a, mul: m} | {set: v} | v}`
## (a bare number is `set`, an absolute value, e.g. han_ky `han_stacks: 2`). Adding a config-type
## relic = adding JSON only. Keys must be in RelicRegistry.CONFIG_KEYS (others warn and are still
## passed on). No ctx keys needed; the combat wave applies [method config_overrides] through
## RelicRegistry.merge_overrides / apply_override.
## Implements: Story 032.

var _overrides: Dictionary = {}


## Builds the override table from the params.
func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_overrides = {}
	for key: Variant in _params.keys():
		var entry: Dictionary = _read_entry(_params[key])
		if entry.is_empty():
			push_warning("ConfigModRelic '%s': param '%s' is not {mul|add|set: number}, ignored" % [_relic_id, str(key)])
			continue
		if not RelicRegistry.CONFIG_KEYS.has(str(key)):
			push_warning("ConfigModRelic '%s': '%s' is not a known config key" % [_relic_id, str(key)])
		_overrides[str(key)] = entry


## The `{key: {add/mul/set}}` table of the params (a copy).
func config_overrides() -> Dictionary:
	return _overrides.duplicate(true)


## Drops the table and the references.
func teardown() -> void:
	_overrides = {}
	super.teardown()


static func _read_entry(raw: Variant) -> Dictionary:
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return {"set": float(raw)}
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = {}
	for field: String in ["add", "mul", "set"]:
		var value: Variant = (raw as Dictionary).get(field)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			out[field] = float(value)
	return out
