extends SceneTree
## Multi-enemy Phase 5 (D7): the phase banner listens to EXACTLY ONE host — unit 0's — and when that host is
## replaced, the old one is disconnected first.
##
## Why this suite exists, written out because the bug it guards leaves no trace in the code that replaces it:
## `_connect_phase` was widened from one host to a set of hosts, and the widening silently deleted the branch that
## disconnects a REPLACED host. That branch was conditional on a state — "this one host is being swapped for
## another" — which the new design could not express: with a set there is no replacement, only an append. So the
## missing code had no shape in the new language, and no reviewer or test could notice an absence that the new
## design has no word for.
##
## The lesson, and the reason this leg is written at all: WIDENING IS NOT ADDITION. Turning "one" into "many"
## rewrites the problem, and branches that only existed in the "one" world vanish without a diff that looks wrong.
## Write the leg for the old branch BEFORE widening, while the question can still be asked.
##
## A second defect rode along and this suite catches it too: connecting with `_on_phase_changed.bind(host)` makes
## `is_connected(_on_phase_changed)` return false forever, because a bound Callable never equals the unbound one.
## The disconnect line then never matches — the first defect's fix, silently disabled by the second.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _connections(host: TraitHost) -> int:
	return host.phase_changed.get_connections().size() if host != null else -1


func _initialize() -> void:
	# Arrange: the smallest stack that makes CutHudView._process run _connect_phase for real.
	var holder := Node.new()
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"boss_max_hp": 100.0}
	v.freeze_time = true
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	await process_frame

	var first: TraitHost = v.get_trait_host()
	check(first != null, "setup: unit 0 has a TraitHost")
	check(_connections(first) == 1, "connect: unit 0's host has exactly one phase_changed listener (got %d)"
			% _connections(first))

	# D7: no other unit may raise the banner. Build a second host the way _setup_extra_units does and confirm the
	# HUD does not listen to it - a per-unit banner is the thing the decision forbids.
	var other := TraitHost.new(v.make_trait_ctx(CombatState.unit_key(1)), [], 1, CombatState.unit_key(1), false)
	await process_frame
	check(_connections(other) == 0, "D7: a second unit's host gets NO phase listener (got %d)" % _connections(other))

	# The leg that would have caught the regression that actually shipped. The one above only asserts that a host
	# built outside _hosts_by_key gets no listener - true of the broken version too, so it documents D7 without
	# testing it. This one registers unit 1's host the way _setup_extra_units does and then makes it announce: if
	# anything listens, the banner text changes, which is exactly what D7 forbids and what b085d7dc shipped.
	# The unit must exist in the STATE, not just in _hosts_by_key: the broken version iterates
	# get_state().enemy_keys(), so an entry nobody enumerates is never reached and the leg passes on both versions.
	# Measured: without this line the leg is green against the regression it was written for.
	check(v.get_state().add_unit("dev_dummy", 30.0) >= 0, "setup: a second enemy unit exists in the state")
	v._hosts_by_key[CombatState.unit_key(1)] = other
	# ASSERT THE PREMISE BEFORE THE BEHAVIOUR. The broken version walks get_state().enemy_keys(); a leg that sets up
	# a unit the state does not list walks a road neither version travels, so it goes green on both and reads like a
	# pass. Checking the premise turns "silently skipped" into "loudly broken" - the same move as the third guard in
	# run_all_tests.sh: ask whether the thing you need is actually there instead of predicting how it might be
	# missing. (The coordinating session's rule, after this leg went green twice against the bug it was written for.)
	check(v.get_state().enemy_keys().has(CombatState.unit_key(1)),
			"premise: enemy_keys() lists unit 1, so the code under test can reach it")
	await process_frame
	await process_frame
	var banner_before: String = hud._phase_banner_text
	other.announce_phase(2)
	await process_frame
	check(hud._phase_banner_text == banner_before,
			"D7 (the real gate): a phase change on unit 1 raises NO banner (text '%s')" % hud._phase_banner_text)
	v._hosts_by_key.erase(CombatState.unit_key(1))

	# Act: replace unit 0's host, the one state the widened version could not express.
	v._trait_host = TraitHost.new(v.make_trait_ctx(), [], 2, CombatState.Side.ENEMY, false)
	await process_frame
	await process_frame
	var second: TraitHost = v.get_trait_host()

	# Assert: the old host is released, the new one is listened to, and the count never grows past one.
	check(second != first, "replace: get_trait_host() now returns the new host")
	check(_connections(first) == 0, "replace: the OLD host was disconnected (got %d)" % _connections(first))
	check(_connections(second) == 1, "replace: the NEW host has exactly one listener (got %d)"
			% _connections(second))

	# Idempotence: _connect_phase runs every frame, so a stable host must not accumulate listeners.
	await process_frame
	await process_frame
	check(_connections(second) == 1, "steady state: repeated _connect_phase does not stack listeners (got %d)"
			% _connections(second))

	holder.free()
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)
