class_name ConveyorCard
extends RefCounted
## Logic-side state of one card riding the belt (no scene dependency).

## Unique id within one ConveyorBelt.
var uid: int = 0
## Card type id from the data table.
var type_id: String = ""
## Position along the belt in belt units; 0 = spawn end, belt_length = far end.
var position: float = 0.0
