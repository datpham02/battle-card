extends SceneTree
## Multi-enemy Phase 5 VISUAL GATE (plan 3.7e). Not a test: the suites already prove the dispatch reaches the right
## unit. This proves the other claim, the one a suite cannot make — that a PLAYER can see WHICH enemy a trait fired
## for. The failure it hunts is not the wrong unit, it is the AMBIGUOUS one.
##
## Reading test for every frame it saves: cover the filename. Can someone who does not know which trait is on which
## unit point at the right enemy? If they have to guess, the frame fails, and the trait needs a per-unit marker -
## not a bigger effect.
##
## One trait per run, on ONE unit, with the other deliberately bare: a frame where both units carry the trait proves
## nothing about attribution, because anything that fires is on a unit that has it.
##
## THE CARRIER ALTERNATES between unit 0 and unit 1 across the four traits, and that is not cosmetic. Put every
## trait on unit 1 and all four "after" frames light up the same formation slot - the set then cannot distinguish
## "the effect marks the unit the trait fired for" from "the effect appears on the right-hand unit", and it would
## look IDENTICAL if attribution were hardcoded to the second unit in the array. That is not hypothetical: unit-0-only
## wiring is the bug class already found in _apply_pattern_phase. Alternating makes a hardcoded-slot bug produce a
## visibly wrong frame instead of a plausible one. (monster-skills session.)
##
## TWO frames per trait, from the same match: `_before` (trait added, not yet visible) and `_after` (visible state).
## A lone frame can answer WHICH unit but not WHAT HAPPENED to it - it reads ambiguously between "unit 1 went under"
## and "unit 1 is drawn oddly", and a reviewer who cannot tell defaults to the generous reading, which is how a weak
## effect passes. Attribution comes from the DIFFERENCE between the pair, which cannot be read generously.
## (The character session's find, from three cue versions rejected today: a state reads ambiguously, a change reads
## clearly. Show a reviewer the pair, never the single frame.)
##
## BOTH FRAMES OF A PAIR COME FROM ONE PROCESS, and that is load-bearing. A sibling session measured hero HP going
## 175 -> 200 -> 200 -> 165 across ASCENDING --shot-frame numbers taken in four separate processes: a frame index is
## a count of rendered frames, not a point in simulation time, and the mapping between them moves with machine load.
## A before/after pair selected that way can land "after" EARLIER in sim time than its "before" - the pair then shows
## the trait doing nothing, intermittently, which reads as a flaky effect rather than a flaky harness. This tool is
## immune by construction, not by luck: one _shoot call = one match = one process, `before` is held in memory and the
## `after` is taken from the same running tree, and the wait between them ends on a STATE CHANGE (_is_showing), never
## on a frame count. Ordering inside a pair is therefore guaranteed. Nothing is ever compared ACROSS traits, which is
## the only place separate processes appear. (monster-skills session.)
##
## Run (WINDOWED, never headless - this captures frames), with --audio-driver Dummy so a capture run is silent:
##   godot --path . --windowed --resolution 1280x720 --audio-driver Dummy \
##     -s res://tools/qa/multi_enemy_trait_footage.gd -- <out_dir> [burrow,rebirth,boss_phases,shroud]
##
## --demo=multi_two is NOT passed: this tool builds its own two-unit formation through RunConfig.clean_match, the
## same production resolve path DemoArgs uses, so the board is a real formation and not a hand-written one.

const SETTLE_FRAMES: int = 90
## The give-up bound is in SIM SECONDS, not frames, and that is deliberate. A frame count is not a duration: at 60fps
## 900 frames is 15s, at 144fps the same 900 frames is 6.2s, and the slowest trait here needs 4s - a margin that
## quietly shrinks from 3.7x to 1.5x with nothing but the refresh rate. The failure that produces is the nastiest
## kind: a "NO PAIR" line for a trait that WOULD have shown a moment later, read as "the trait never showed" when the
## truth is "we stopped watching early". Seconds are what the trait params are written in, so the bound is now in the
## same unit as the thing it bounds. The frame cap stays as a backstop against a stalled tree, and the report names
## WHICH bound tripped so the two failures are never confused. (monster-skills session.)
const GIVE_UP_SEC: float = 20.0
const GIVE_UP_FRAMES: int = 6000
const SPRITE_SMALL: String = "goblin_scout"
## Which unit carries each trait. Alternated on purpose - see the header. Changing these to one value would make the
## whole capture set unable to tell correct attribution from a hardcoded slot.
const CARRIERS: Dictionary = {"burrow": 1, "rebirth": 0, "boss_phases": 1, "shroud": 0}

var _out: String = ""
var _report: Array[String] = []
var _manifest_before: Dictionary = {}


# Phase 5: a capture needs its OWN tree guard, and a WIDER scope than the headless runner's. run_all_tests.sh
# allowlists code-ish extensions and deliberately drops .import/.uid as import noise; for a screenshot a changed
# .import IS a changed picture, as are assets/art/**, *.tscn and project.godot. Borrowing that function here would
# print "tree stable" while a backdrop was swapped under the camera. The scope is PRINTED with the result: a guard
# that says TREE STABLE without saying stable over what is an assertion, not a measurement.
const SCOPE_RE: String = "(^|/)project\\.godot$|^assets/art/|\\.(gd|json|csv|tres|tscn|cfg|sh|png|import|uid)$"


# The tool's OWN output directory is excluded, and this is the one exclusion that is not a judgement call: the
# frames are this run's product, not its input, so including them makes the guard fire on every single run - the
# always-firing gate that teaches people to ignore the one line that matters. The first version did exactly that
# (TREE MOVED on a run where the only movers were its own eight PNGs). Every OTHER path stays in scope.
func _manifest() -> Dictionary:
	var out: Dictionary = {}
	var re: RegEx = RegEx.create_from_string(SCOPE_RE)
	_walk("res://", re, out)
	return out


# Which paths moved, so a red verdict is diagnosable instead of merely loud.
func _moved(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = []
	for path: String in before:
		if not after.has(path):
			names.append("gone: " + path)
		elif after[path] != before[path]:
			names.append("changed: " + path)
	for path: String in after:
		if not before.has(path):
			names.append("new: " + path)
	names.sort()
	return names


func _walk(dir_path: String, re: RegEx, out: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_walk(full, re, out)
		else:
			var rel: String = full.replace("res://", "")
			if re.search(rel) != null and not rel.begins_with(_out):
				var f: FileAccess = FileAccess.open(full, FileAccess.READ)
				if f != null:
					out[rel] = f.get_buffer(f.get_length()).get_string_from_ascii().md5_text()
		name = dir.get_next()
	dir.list_dir_end()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "production/qa/evidence/multi-enemy-phase5"
	var which: PackedStringArray = (args[1] if args.size() > 1 else "burrow,rebirth,boss_phases,shroud").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_manifest_before = _manifest()

	# "shroud@1" overrides the default carrier for ONE run. The defaults stay alternating; this exists because the
	# worst defect found (the shroud cloud drawn on unit 0's footprint whatever unit was shrouding) sits on a trait
	# whose default carrier IS unit 0 - so the standard set fixes the bug without ever photographing the fix.
	for id: String in which:
		await _shoot(id.strip_edges())

	print("REPORT")
	for line: String in _report:
		print("  ", line)
	# Before AND after, like the shared runner: one reading cannot tell a stable tree from a lucky one.
	print("SCOPE: ", SCOPE_RE)
	var moved: PackedStringArray = _moved(_manifest_before, _manifest())
	if moved.is_empty():
		print("TREE: STABLE over the scope above (%d files)" % _manifest_before.size())
	else:
		print("TREE: *** MOVED MID-CAPTURE - these frames describe no single version ***")
		for name: String in moved:
			print("      ", name)
	quit(0)


# A fresh match per trait: traits install hooks and change unit state, so reusing one match would let the previous
# trait's leftovers into the next frame.
func _shoot(spec: String) -> void:
	var trait_id: String = spec.split("@")[0] if "@" in spec else spec
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("tho_san")
	# The formation is injected into the RunConfig BEFORE the battle spawns, and that timing is the whole of it:
	# CombatView builds `_state` from match_params in _ready (combat_view.gd:429), so a `match_params` assignment made
	# after the battle is PLAYING changes a dictionary nobody reads again. The first version of this tool did exactly
	# that and every trait reported "the formation did not build two units" - one unit on the board, four honest
	# SKIPPED lines, zero frames. The run was right and the tool was wrong, which is the only reason it was visible.
	var cfg: RunConfig = RunConfig.from_node(ChaptersConfig.load_from_file(), "ch1", "dire_wolf", "battle", 7, 3)
	cfg.matches[0] = _two_unit_match(cfg.matches[0])
	var rc: RunController = gf.enter_test_floor(cfg)
	var waited: float = 0.0
	for _i in GIVE_UP_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		waited += await _step()
		if waited > GIVE_UP_SEC:
			break
	var v := rc.get_battle().get_node("CombatView") as CombatView

	for _i in SETTLE_FRAMES:
		await process_frame

	var state: CombatState = v.get_state()
	var index: int = int(CARRIERS.get(trait_id, 1))
	if "@" in spec:
		index = int(spec.split("@")[1])   # the override reads from SPEC; trait_id has already lost it
	var carrier: int = CombatState.unit_key(index)
	var other: int = CombatState.unit_key(1 - index)
	var host: TraitHost = v.host_of(carrier)
	if host == null or state.enemy_keys().size() < 2:
		_report.append("%s: SKIPPED - the formation did not build two units" % trait_id)
		_drop(main)
		return

	# Unit 0 stays bare on purpose. This is the whole point of the frame.
	var added: BossTrait = host.add_trait(trait_id, _params_for(trait_id))
	if added == null:
		_report.append("%s: SKIPPED - trait not added" % trait_id)
		_drop(main)
		return
	# BEFORE: the same board, same camera, trait installed but not yet showing. Held in memory and written only if
	# the AFTER lands - a lone "before" is not evidence of anything.
	await process_frame
	# The pair's whole claim is "this difference IS the trait appearing", and that claim needs the before frame to be
	# an ABSENCE, not merely an earlier moment. A trait that fires on spawn, or re-arms between matches, would make
	# both frames "showing" and the pair would prove nothing - at worst it catches the effect mid-fade and again
	# re-fired, which reads as a WEAK effect rather than a broken capture. So the premise is asserted, not assumed.
	# (monster-skills session, the mirror of their carrier-alternation find.)
	if _is_showing(v, added, trait_id, carrier):
		# Some traits have no "off" state to photograph: `shroud` is on from the moment it exists and lifts only
		# while the unit is pinned or casting, so an absence frame cannot be taken at all. Rather than fake a pair,
		# save ONE frame under a different name and say what it can and cannot support. A lone frame answers WHICH
		# UNIT - and for the defect this run exists to document (the cloud drawn on unit 0's footprint whatever unit
		# was shrouding) which-unit IS the entire claim. It still cannot show WHAT HAPPENED, so it is never filed
		# as a pair.
		var only: String = "%s_unit%d_state.png" % [trait_id, index]
		root.get_texture().get_image().save_png(_out.path_join(only))
		_report.append(("%s: SINGLE FRAME %s (no pair possible - the trait has no off state). Answers WHICH UNIT "
			+ "only: carrier unit %d at %s, BARE unit %d at %s") % [trait_id, only, index,
			str(state.cell_of(carrier)), 1 - index, str(state.cell_of(other))])
		_drop(main)
		return
	var before: Image = root.get_texture().get_image()

	if trait_id == "rebirth":
		state.damage_unit(index, 999.0)      # rebirth only shows while it is reviving
	elif trait_id == "boss_phases":
		# The first run reported NO FRAME here and the trait was never tested. at_hp_ratio is a THRESHOLD: nothing
		# in a passive capture damages the carrier, so its HP stayed at 1.0 and the phase could not arm. The tool
		# was asking the trait to fire under conditions that forbid it. One tick of damage under the threshold is
		# the whole fix - and it has to hit the CARRIER, because damaging the bare unit would re-create the bug
		# this gate exists to find, in the harness instead of the game.
		state.damage_unit(index, state.max_hp_of(carrier) * 0.05)

	var fired: bool = false
	var elapsed: float = 0.0
	var frames: int = 0
	for _i in GIVE_UP_FRAMES:
		elapsed += await _step()
		frames += 1
		if _is_showing(v, added, trait_id, carrier):
			fired = true
			break
		if elapsed > GIVE_UP_SEC:
			break
	# The carrier is in the FILENAME, so a reviewer checking the cover-the-filename test has to uncover it
	# deliberately - and so the set is self-describing once they do.
	var before_name: String = "%s_unit%d_before.png" % [trait_id, index]
	var after_name: String = "%s_unit%d_after.png" % [trait_id, index]
	if fired:
		before.save_png(_out.path_join(before_name))
		root.get_texture().get_image().save_png(_out.path_join(after_name))
		_report.append("%s: SAVED %s + %s - carrier unit %d at %s, BARE unit %d at %s" % [trait_id,
			before_name, after_name, index, str(state.cell_of(carrier)), 1 - index, str(state.cell_of(other))])
	else:
		# NOT saved, and said out loud. A frame taken before the trait shows is worse than no frame: it looks like
		# evidence and shows nothing, which is the whole class of defect this gate exists to avoid.
		# Name the bound that tripped. "Ran out of sim time" and "the tree stalled" are different failures and a single
		# NO FRAME line would hide which one happened.
		var why: String = ("%.1fs of sim time" % elapsed) if elapsed > GIVE_UP_SEC else ("%d frames (tree stalled before %.1fs)" % [frames, GIVE_UP_SEC])
		_report.append("%s: NO FRAME - the trait never became visible within %s" % [trait_id, why])
	_drop(main)


# Params chosen so each trait reaches its VISIBLE state quickly; none of them change what the trait draws.
func _params_for(trait_id: String) -> Dictionary:
	match trait_id:
		"burrow":
			return {"interval_sec": 0.2, "burrow_sec": 3.0, "surface_warn_sec": 2.5}
		"rebirth":
			return {"lives": 1, "revive_sec": 4.0, "revive_ratio": 0.4}
		"boss_phases":
			return {"phases": [{}, {"at_hp_ratio": 0.99, "phase_shift_sec": 4.0}]}
		"shroud":
			return {}
	return {}


# True when the trait is in the state a player would have to read off the screen.
func _is_showing(v: CombatView, t: BossTrait, trait_id: String, key: int) -> bool:
	match trait_id:
		"burrow":
			# The surface warning, not the burrow itself: a burrowed unit is invisible, so the frame that has to be
			# legible is the one announcing WHERE it comes back.
			return (t as BurrowTrait).get_surface_cell() != Vector2i(-1, -1)
		"rebirth":
			return (t as RebirthTrait).is_reviving()
		"boss_phases":
			return v.get_state().get_unit(CombatState.unit_index_of(key)).invulnerable_left > 0.0
		"shroud":
			return (t as ShroudTrait).is_shrouding()
	return false


# One frame, returning the sim time it consumed, so every wait in this file is measured in the unit its bounds use.
func _step() -> float:
	await process_frame
	return root.get_process_delta_time()


# Two units, built the way a chapter formation is built. Unit 0 keeps the match's own enemy; unit 1 is a second body
# with a shipped sheet, so both draw real sprites - an invented id draws the placeholder quad and the frame would
# prove nothing about which enemy the player is looking at. RunConfig.clean_match is the production resolve path
# (ai block, footprint, defense), and merging its result over the spec keeps the keys clean_match drops.
func _two_unit_match(spec: Dictionary) -> Dictionary:
	var raw: Dictionary = spec.duplicate(true)
	raw["enemies"] = [
		{"id": str(spec.get("id", "dire_wolf")), "max_hp": float(spec.get("boss_max_hp", 80.0)), "brain": "block"},
		{"id": SPRITE_SMALL, "max_hp": 60.0, "brain": "block"},
	]
	raw["attack_slots"] = 1
	var merged: Dictionary = spec.duplicate(true)
	var resolved: Dictionary = RunConfig.clean_match(raw, 0)
	for key: Variant in resolved.keys():
		merged[key] = resolved[key]
	return merged


func _drop(main: Node) -> void:
	root.remove_child(main)
	main.free()
