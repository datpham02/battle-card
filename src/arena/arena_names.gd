class_name ArenaNames
extends RefCounted
## Translation keys of the arenas.json shapes (shared by the HUD and the floor-select screen).
## Implements: Story 015; keys through the i18n CSV since Story 017.

## arenas.json shape id -> key `arena.<id>.name`; an unknown id shows the id itself.
const NAMES: Dictionary = {
	"square": "arena.square.name",
	"rect": "arena.rect.name",
	"cross": "arena.cross.name",
	"u_shape": "arena.u_shape.name",
	"staircase": "arena.staircase.name",
	"ring": "arena.ring.name",
	"islands_bridge": "arena.islands_bridge.name",
	"diamond": "arena.diamond.name",
	"cross_wide": "arena.cross_wide.name",
	"pillars": "arena.pillars.name",
	"an_dai_dais": "arena.an_dai_dais.name",
	"bog": "arena.bog.name",
	"reed_maze": "arena.reed_maze.name",
	"dunes": "arena.dunes.name",
	"oasis": "arena.oasis.name",
	"forge": "arena.forge.name",
	"caldera": "arena.caldera.name",
	"twin_isles": "arena.twin_isles.name",
	"three_isles": "arena.three_isles.name",
	"boss_hall": "arena.boss_hall.name",  # P2.2b: boss-only 6x4 arena (multi-cell Wardens)
}
## Key shown for a floor whose arena is drawn from a pool (translate with tr()).
const TEXT_RANDOM: String = "ui.arena.random"


## Translated display name of [param shape_id]; the id itself when unknown.
static func name_for(shape_id: String) -> String:
	if not NAMES.has(shape_id):
		return shape_id
	return TranslationServer.translate(str(NAMES[shape_id]))
