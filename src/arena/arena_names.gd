class_name ArenaNames
extends RefCounted
## Player-facing names of the arenas.json shapes (shared by the HUD and the floor-select screen).
## Implements: Story 015.

## arenas.json shape id -> display name; an unknown id shows the id itself.
const NAMES: Dictionary = {
	"square": "Vuông",
	"rect": "Chữ nhật",
	"cross": "Chữ thập",
	"u_shape": "Chữ U",
	"staircase": "Bậc thang",
	"ring": "Vòng",
	"islands_bridge": "Hai đảo",
	"diamond": "Kim cương",
}
## Shown for a floor whose arena is drawn from a pool.
const TEXT_RANDOM: String = "Ngẫu nhiên"


## Display name of [param shape_id]; the id itself when unknown.
static func name_for(shape_id: String) -> String:
	return str(NAMES.get(shape_id, shape_id))
