class_name FieldPoint
extends RefCounted
## One cut point lying on a board cell (or held in a hand slot). Plain data.
## Implements: Story 007.

## Unique id within one FieldDrops instance.
var uid: int = 0
## Perimeter label such as "A1" (A top, B right, C bottom, D left; 1-3).
var label: String = ""
## Board cell the point lies on (meaningless once held in hand).
var cell: Vector2i = Vector2i.ZERO
## Seconds before the point rots away while on the field.
var freshness_left: float = 0.0
