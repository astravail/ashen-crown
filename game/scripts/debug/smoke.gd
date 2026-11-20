extends Node
## Walks through every system once to catch runtime errors: godot --headless --path game -- --smoke

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.5).timeout
	await _run()


func _say(t: String) -> void:
	print("[smoke] ", t)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	Game.new_run("knight")
	Game.hero_name = "Smoke"
	main._carry = {}
	await main._start_overworld()
	await _wait(1.0)
	var w: World = main.world
	_say("village region=%d zone=%s npcs=%d" % [w.cur, w.zone.name, w.npcs.size()])
	var p: Panels = main.panels
	Game.gold = 9000
	for i in 12:
		Game.add_item(Items.roll_drop("shop", 5, 0.0))
	Game.equip(0)
	Game.equip(1)
	p.world = w
	for m in [["inv", ""], ["smith", "smith"], ["mystic", "mystic"], ["stash", ""]]:
		p.show_inventory(m[0], m[1])
		await _wait(0.2)
	p._buy(0)
	p._pack_click(2)
	p._repair()
	p._sell_commons()
	p._mend()
	_say("shop ok, gold=%d" % Game.gold)
	p.show_skills()
	await _wait(0.2)
	w.player.level = 32
	w.player.toggle_rune(Data.runes_of(w.player.cls, 0)[0].id)
	w.player.toggle_rune(Data.runes_of(w.player.cls, 0)[1].id)
	w.player.toggle_passive("vigor")
	w.player.toggle_passive("ferocity")
	w.player.toggle_passive("swiftness")
	w.player.toggle_passive("precision")
	assert(w.player.passives_used() == 3, "three passive slots at level 32")
	assert(not w.player.has_mod(Data.runes_of(w.player.cls, 0)[0].id), "one rune per ability")
	w.player.mods["reach"] = 5
	w.player.normalize_mods()
	p.show_skills()
	await _wait(0.2)
	p.show_waypoints()
	await _wait(0.2)
	p.show_quests(true)
	await _wait(0.2)
	p.show_quests(false)
	await _wait(0.2)
	p.close()
	_say("panels ok")

	# Story: the cellar
	Game.quest_accept("story_0")
	w._set_objective()
	_say("objective: %s at %s" % [w.objective, w.objective_pos])
	w.door_enter.emit(12)
	await _wait(5.0)
	var iw: World = main.world
	_say("interior=%s zone=%s enemies=%d" % [iw.interior, iw.zone.name, iw.enemies.size()])
	var chest: Prop = null
	for pr in iw.props:
		if pr.kind.begins_with("chest"):
			chest = pr
			break
	if chest:
		iw.open_chest(chest)
	_say("chests in cellar=%d, quest status=%d, loot on ground=%d" % [iw.props.filter(func(x): return x.kind.begins_with("chest")).size(), Game.quest_status("story_0"), iw.loots.size()])
	iw.door_exit.emit()
	await _wait(3.0)
	_say("back in overworld=%s interior=%s" % [main.world == main.overworld, main.world.interior])
	p.world = main.world
	p._turn_in(Data.quest("story_0"))
	_say("turned in story_0 status=%d gold=%d" % [Game.quest_status("story_0"), Game.gold])

	# Zone 0: chests, waypoint, recall
	var w2: World = main.world
	Game.quest_accept("story_1")
	await main._load_zone(0)
	await _wait(9.0)  # the act cutscene pauses the game
	w2 = main.world
	_say("zone=%s champion=%s enemies=%d ambush=%d guide_target=%s" % [w2.zone.name, w2.champion, w2.enemies.size(), w2.ambush.size(), w2.guide_target()])
	for i in 5:
		await _wait(0.8)
	_say("guide points=%d" % w2.guide_pts.size())
	var wp: Prop = w2.rt[w2.cur].waypoint
	w2.player.global_position = wp.global_position + Vector2(30, 20)
	await _wait(1.0)
	_say("waypoint unlocked=%s targets=%d" % [Game.waypoints.has("z0"), w2.waypoint_targets().size()])
	w2.player.invuln_t = 30.0
	_say("start_recall -> %s (village=%s cd=%.1f dead=%s state=%s)" % [w2.start_recall(), w2.village, w2.recall_cd, w2.player.dead, w2.state])
	for i in 6:
		await _wait(1.0)
		_say("  recall_t=%.1f hurt=%.2f hp=%d paused=%s cur=%d" % [w2.recall_t, w2.player.hurt_t, w2.player.hp, get_tree().paused, main.world.cur])
	_say("after recall region=%d village=%s" % [main.world.cur, main.world.village])
	# Champion, altar, gate
	await main._load_zone(0)
	await _wait(1.0)
	w2 = main.world
	_say("champion alive=%s gates=%d" % [w2.champion != null, w2.rt[w2.cur].gates.size()])
	if w2.champion:
		w2.player.invuln_t = 60.0
		w2.damage(w2.champion, 1.0e9, w2.player)
		await _wait(0.5)
		_say("champion dead: state=%s loot=%d quest=%d altar=%s" % [w2.state, w2.loots.size(), Game.quest_status("story_1"), w2.props.any(func(x): return x.kind == "altar")])
		w2.claim_fragment_done()
		_say("claimed: gates left=%d zone_state=%s" % [w2.rt[w2.cur].gates.size(), Game.zs(0)])
	# The last boss only exists with its quest
	Game.zs(10).claimed = true
	Game.quest_accept("story_12")
	await main._load_zone(11)
	await _wait(9.0)
	w2 = main.world
	_say("throne room boss=%s" % [w2.rt[w2.cur].boss != null])
	if w2.rt[w2.cur].boss:
		w2.rt[w2.cur].boss.sleeping = false
		w2.damage(w2.rt[w2.cur].boss, 1.0e9, w2.player)
		await _wait(0.5)
		_say("boss dead: crown=%s loot=%d" % [w2.props.any(func(x): return x.kind == "crown"), w2.loots.size()])
	# markers
	Game.markers.append(Vector2(6000, 6000))
	await _wait(1.0)

	# Save and load
	main._autosave()
	var saves := Game.list_characters()
	_say("saved characters=%d" % saves.size())
	if not saves.is_empty():
		var ok := Game.load_character(saves[0].id)
		_say("load ok=%s gold=%d inv=%d" % [ok, Game.gold, Game.inv.size()])

	# Menus
	var mn: Menus = main.menus
	mn.show_statistics()
	await _wait(0.2)
	for t in 4:
		mn._stat_tab = t
		mn.show_statistics()
		await _wait(0.2)
	mn.show_fallen()
	await _wait(0.2)
	mn.show_characters()
	await _wait(0.2)
	mn.show_customize("pyrewitch")
	await _wait(0.2)
	mn.show_settings(func(): pass)
	await _wait(0.2)
	mn.show_pause()
	await _wait(0.2)
	Game.record_fallen("Smoke test")
	mn.show_permadeath("Smoke test")
	await _wait(0.2)
	Game.delete_character(Game.char_id)
	_say("SMOKE DONE")
	get_tree().quit()
