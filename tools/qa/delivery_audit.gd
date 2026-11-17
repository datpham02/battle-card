extends SceneTree
## Evidence tool (monster-cast-anim session, 2026-11-17): prints the NORMALIZED delivery of every enemy skill,
## so a data change can be checked against what the engine actually ended up with.
##
## Run: godot --headless --path . -s res://tools/qa/delivery_audit.gd
##
## WHY IT EXISTS. `SkillDelivery.normalize` repairs bad data instead of refusing it: an origin that is not legal
## for a type is replaced by the type's first legal origin and a line is appended to `problems`. Nothing throws,
## nothing turns red. So a suite run that is all green says "nothing broke" — it does not say "the change landed".
## This prints the value the engine holds and every problem line, which is the difference between the two.


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	var skills: Dictionary = cfg.skills
	var by_type: Dictionary = {}
	var problems: int = 0
	for sid: String in skills:
		var d: Dictionary = (skills[sid] as Dictionary).get("delivery", {}) as Dictionary
		var t: String = str(d.get("type", "?"))
		by_type[t] = int(by_type.get(t, 0)) + 1
	for p: String in cfg.problems:
		if p.findn("delivery") >= 0 or p.findn("origin") >= 0 or p.findn("travel") >= 0:
			print("PROBLEM ", p)
			problems += 1
	for t: String in by_type:
		print("TYPE %-22s %d" % [t, by_type[t]])
	print("DELIVERY_PROBLEMS ", problems)
	# the skills this session moved: print each one's resolved delivery, so it can be read, not assumed
	for sid: String in ["ogre_club", "sphinx_claw", "golem_cinder_slam", "reacter_lash", "zombie_grab",
			"slug_slime_trail", "sentinel_anchor", "sprite_mirage"]:
		if not skills.has(sid):
			continue
		var d: Dictionary = (skills[sid] as Dictionary).get("delivery", {}) as Dictionary
		print("SKILL %-22s type=%-22s origin=%-14s travel=%s" % [sid, d.get("type", "?"), d.get("origin", "?"), d.get("travel", "?")])
	quit(0)
