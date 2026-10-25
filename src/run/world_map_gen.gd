class_name WorldMapGen
extends RefCounted
## Pure, seeded world generator (Story 031 Part B): which regions a floor offers, and the seed of a
## region's map. A "region" is a chapter of chapters.json (the word `zone` belongs to seals / thorns,
## Story 027). Needs no map tree: the offer is a function of (region_pool, run_seed, floor, chosen_path).
## Design: design/game-brief.md "Run v6", design/reference/osfe-reference.md section 9.3.

const SEED_MASK: int = 0x7fffffff
## Regions offered per floor when the caller passes no count (`world.choices_per_floor` of chapters.json).
const DEFAULT_CHOICES: int = 2


## Region ids offered at 0-based [param floor] (at most [param choices], 2 different ids; fewer when the
## pool is smaller, [] for an empty pool). [param chosen_path] = region ids picked at the floors before
## (index = floor). Rules in order: (1) regions not yet visited this run first; (2) then the least
## visited; (3) avoid the region just visited at the previous floor while another one is left; (4) ties
## drawn with an RNG seeded by hash([run_seed, floor, chosen_path]). Same inputs -> same offer.
static func offer_for_floor(region_pool: Array, run_seed: int, floor: int, chosen_path: Array,
		choices: int = DEFAULT_CHOICES) -> Array[String]:
	var offer: Array[String] = []
	var candidates: Array[String] = []
	for id: Variant in region_pool:
		if not candidates.has(str(id)):
			candidates.append(str(id))
	var path: Array[String] = []
	for id: Variant in chosen_path:
		path.append(str(id))
	var visits: Dictionary = {}
	for id: String in path:
		visits[id] = int(visits.get(id, 0)) + 1
	var last: String = path[path.size() - 1] if not path.is_empty() else ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor, path]) & SEED_MASK
	var want: int = mini(maxi(choices, 1), candidates.size())
	while offer.size() < want:
		var best: Array[String] = []
		var best_key: Array = []
		for id: String in candidates:
			if offer.has(id):
				continue
			# Lower is better: visit count first (0 = unvisited), then "was the previous floor's region".
			var key: Array = [int(visits.get(id, 0)), 1 if id == last else 0]
			if best.is_empty() or _key_less(key, best_key):
				best = [id]
				best_key = key
			elif key == best_key:
				best.append(id)
		if best.is_empty():
			break
		offer.append(best[rng.randi_range(0, best.size() - 1)])
	return offer


## Seed of the map of [param region_id] entered at 0-based [param floor]:
## hash([run_seed, region_id, floor]), non-negative. The same region met again on another floor gets
## another map.
static func region_map_seed(run_seed: int, region_id: String, floor: int) -> int:
	return hash([run_seed, region_id, floor]) & SEED_MASK


static func _key_less(a: Array, b: Array) -> bool:
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false
