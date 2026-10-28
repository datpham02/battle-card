class_name OddBlockConfig
extends RefCounted
## Story 041 "Khoi La" tuning: the `odd_blocks` block of assets/data/field_drops.json (also a match's
## `odd_blocks` override, merged over it). A missing block = the feature is off (chance 0). Values are
## clamped: chance 0..1, min_cells >= 1, size_divisor >= 1, size_min >= 1, size_max >= size_min,
## max_tries >= 1, negative weights -> 0. Schema: assets/data/schema.md.
## Size rule: max size on a half of N real cells = clampi(N / size_divisor + size_add, size_min, size_max)
## (integer division); the allowed sizes are min_cells..max size with a weight > 0 in size_weights.
## Implements: Story 041 (Parts A, D).

## Below this many cells every shape already exists in pieces.json (1-4 cells), so a smaller
## min_cells only wastes tries (a rule of polyominoes, not a tuning number).
const SMALLEST_NEW_SIZE: int = 5

## Probability that one tick spawn is an odd block (0 = off).
var chance: float = 0.0
## Smallest odd block, in cells.
var min_cells: int = 5
## Max size formula: target cells / size_divisor + size_add, clamped to size_min..size_max.
var size_divisor: int = 4
var size_add: int = 3
var size_min: int = 4
var size_max: int = 7
## Draw weight per size in cells (int -> float); a size without an entry has weight 0.
var size_weights: Dictionary = {5: 6.0, 6: 3.0, 7: 1.0}
## Generation tries per spawn before falling back to a classic piece.
var max_tries: int = 40


## Builds a config from the `odd_blocks` dictionary; missing keys keep the defaults (chance 0 = off
## when the key is absent), nonsense is clamped.
static func from_dictionary(data: Dictionary) -> OddBlockConfig:
	var c := OddBlockConfig.new()
	c.chance = clampf(float(data.get("chance", c.chance)), 0.0, 1.0)
	c.min_cells = maxi(int(data.get("min_cells", c.min_cells)), 1)
	if c.min_cells < SMALLEST_NEW_SIZE:
		push_warning("OddBlockConfig: min_cells %d < %d only wastes tries (every 1-4 cell shape is in pieces.json)"
			% [c.min_cells, SMALLEST_NEW_SIZE])
	c.size_divisor = maxi(int(data.get("size_divisor", c.size_divisor)), 1)
	c.size_add = int(data.get("size_add", c.size_add))
	c.size_min = maxi(int(data.get("size_min", c.size_min)), 1)
	c.size_max = maxi(int(data.get("size_max", c.size_max)), c.size_min)
	c.max_tries = maxi(int(data.get("max_tries", c.max_tries)), 1)
	var raw: Variant = data.get("size_weights", null)
	if raw is Dictionary:
		c.size_weights = {}
		for key: Variant in (raw as Dictionary).keys():
			var size: int = int(str(key))
			if size <= 0:
				push_warning("OddBlockConfig: size_weights key '%s' is not a positive size, ignored" % key)
				continue
			c.size_weights[size] = maxf(float((raw as Dictionary)[key]), 0.0)
	elif raw != null:
		push_warning("OddBlockConfig: size_weights must be an object, using the defaults")
	return c


## Independent copy.
func copy() -> OddBlockConfig:
	var c := OddBlockConfig.new()
	c.chance = chance
	c.min_cells = min_cells
	c.size_divisor = size_divisor
	c.size_add = size_add
	c.size_min = size_min
	c.size_max = size_max
	c.size_weights = size_weights.duplicate()
	c.max_tries = max_tries
	return c


## The config as an `odd_blocks` dictionary (size_weights keys as strings, like the JSON).
func to_dictionary() -> Dictionary:
	var weights: Dictionary = {}
	for size: int in size_weights.keys():
		weights[str(size)] = size_weights[size]
	return {
		"chance": chance, "min_cells": min_cells, "size_divisor": size_divisor, "size_add": size_add,
		"size_min": size_min, "size_max": size_max, "size_weights": weights, "max_tries": max_tries,
	}


## A new config: this one with the keys of [param overrides] (a match's `odd_blocks`) merged over it.
## A `size_weights` override replaces the whole weight map.
func with_overrides(overrides: Dictionary) -> OddBlockConfig:
	var merged: Dictionary = to_dictionary()
	for key: Variant in overrides.keys():
		merged[key] = overrides[key]
	return OddBlockConfig.from_dictionary(merged)


## Largest odd block on a target half of [param target_cells] real cells.
func max_size_for(target_cells: int) -> int:
	return clampi(target_cells / size_divisor + size_add, size_min, size_max)


## Weight of size [param cells] (0 when unlisted).
func weight_of(cells: int) -> float:
	return maxf(float(size_weights.get(cells, 0.0)), 0.0)


## Sizes min_cells..max_size_for(target_cells) whose weight is > 0, ascending.
func allowed_sizes(target_cells: int) -> Array[int]:
	var out: Array[int] = []
	for size: int in range(min_cells, max_size_for(target_cells) + 1):
		if weight_of(size) > 0.0:
			out.append(size)
	return out


## True when odd blocks can drop on a target half of [param target_cells] cells (chance > 0 and at
## least one allowed size).
func is_enabled_for(target_cells: int) -> bool:
	return chance > 0.0 and not allowed_sizes(target_cells).is_empty()
