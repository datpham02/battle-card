class_name FieldPoint
extends RefCounted
## One cut point lying on a board cell (or held in a hand slot). Plain data.
## Implements: Story 007, Story 014 (rotten points).

## Unique id within one FieldDrops instance.
var uid: int = 0
## Perimeter label such as "A1" (A top, B right, C bottom, D left; 1-3).
var label: String = ""
## Board cell the point lies on (meaningless once held in hand).
var cell: Vector2i = Vector2i.ZERO
## Seconds before the point rots away while on the field.
var freshness_left: float = 0.0
## Story 014: a rotten point (thrown by a boss trait) occupies a hand slot but can never be
## selected or cut; HoldSlots.tick_rot removes it from the hand once [member rot_in_hand_sec]
## has elapsed.
var rotten: bool = false
## Seconds a rotten point stays in the hand before it leaves on its own (counts down in hand).
var rot_in_hand_sec: float = 0.0
