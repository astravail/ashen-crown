extends Node
## Offscreen stills at a fixed 1920x1080, whatever size the window happens to be:
##   godot --path game res://scripts/debug/shots.tscn -- --out=/tmp/shots [--views=title,village,zone0,fight2,gallery] [--quality=0..3] [--class=knight|gravecaller|pyrewitch] [--bench]
## The whole game runs inside a SubViewport; a second one converts the linear HDR picture to sRGB for the PNG.

const SIZE := Vector2i(1920, 1080)

var out_dir := "/tmp/shots"
var views: PackedStringArray = ["title", "village", "zone0", "zone1", "zone2", "zone3", "zone4", "zone5", "fight0", "gallery"]
var stage: SubViewport
var conv: SubViewport
var main: Node
var quality := 2
var hero := "knight"
var bench := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--views="):
			views = a.substr(8).split(",")
		elif a.begins_with("--quality="):
			quality = int(a.substr(10))
		elif a == "--bench":
			bench = true
		elif a.begins_with("--class="):
			hero = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out_dir)
	stage = SubViewport.new()
	stage.size = SIZE
	stage.use_hdr_2d = true
	stage.msaa_2d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_4X, Viewport.MSAA_8X][quality]
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(stage)
	conv = SubViewport.new()
	conv.size = SIZE
	conv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(conv)
	var tr := TextureRect.new()
	tr.texture = stage.get_texture()
	tr.size = Vector2(SIZE)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec3 c = clamp(texture(TEXTURE, UV).rgb, 0.0, 1.0);\n\tvec3 lo = c * 12.92;\n\tvec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;\n\tCOLOR = vec4(mix(lo, hi, step(vec3(0.0031308), c)), 1.0);\n}\n"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	tr.material = sm
	conv.add_child(tr)
	# A small preview in the window so a person watching can see what is being captured.
	var prev := TextureRect.new()
	prev.texture = conv.get_texture()
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(prev)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	conv.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("[shots] ", name)
	if bench:
		var t0 := Time.get_ticks_usec()
		var n := 0
		while Time.get_ticks_usec() - t0 < 2500000:
			await get_tree().process_frame
			n += 1
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("[bench] %s q=%d  %.2f ms  %.0f fps" % [name, quality, ms, 1000.0 / ms])


func _run() -> void:
	await get_tree().process_frame
	# A known quality level for the stills, whatever the player has saved. Nothing here is written back.
	Game.settings["tutorials"] = false
	Game.settings.quality = quality
	Game.settings.glow = quality >= 1
	Game.settings.fps_cap = 0
	Game.settings.vsync = false
	Game.apply_settings()
	main = load("res://scenes/main.tscn").instantiate()
	stage.add_child(main)
	await _wait(2.5)
	if views.has("title"):
		await _snap("title")
	var need_world := false
	for v in views:
		if v != "title":
			need_world = true
	if not need_world:
		get_tree().quit()
		return
	# Leave the player's records and saves as they were: starting a run counts it, and the
	# autosave would add a "Shots" character to their list.
	var records: Dictionary = Game.records.duplicate()
	Game.new_run(hero)
	Game.records = records
	Game.save_records()
	for c in main.get_children():
		if c is Timer:
			(c as Timer).stop()
	Game.hero_name = "Shots"
	for z in Data.LAST_ZONE + 1:
		Game.zs(z).claimed = true
		Game.zs(z).champ_dead = true
		Game.acts_seen[z] = true
	main._carry = {}
	await main._start_overworld()
	await _wait(3.2)
	var w: World = main.world
	w.player.invuln_t = 9999.0
	for v in views:
		if v == "village":
			await _snap("village")
			w.teleport_player(w.map.regions[0].pois.waypoint + Vector2(0, 90))
			await _wait(0.8)
			await _snap("village_waypoint")
		elif v.begins_with("zone"):
			var zi := int(v.substr(4))
			if not w.map.zone_region.has(zi):
				continue
			var r: Dictionary = w.map.regions[w.map.zone_region[zi]]
			w.teleport_player(Vector2(r.start) * World.CELL + Vector2(32, 32))
			await _wait(1.6)
			await _snap("zone%d_a" % zi)
			var nodes: Array = r.nodes
			w.teleport_player((Vector2(nodes[nodes.size() / 2]) + Vector2(0.5, 0.5)) * World.CELL)
			await _wait(1.4)
			await _snap("zone%d_b" % zi)
		elif v.begins_with("fight"):
			var zf := int(v.substr(5))
			var rf: Dictionary = w.map.regions[w.map.zone_region[zf]]
			var nf: Array = rf.nodes
			w.teleport_player((Vector2(nf[mini(2, nf.size() - 1)]) + Vector2(0.5, 0.5)) * World.CELL)
			await _wait(0.6)
			var pp: Vector2 = w.player.global_position
			var kinds: Array = (rf.zd.pool as Dictionary).keys()
			for i in 9:
				var a := TAU * i / 9.0
				var pos := pp + Vector2(cos(a), sin(a) * 0.7) * (150.0 + 40.0 * (i % 3))
				if w.is_floor_at(pos):
					var e := w.spawn_enemy(kinds[i % kinds.size()], pos, false, w.cur)
					e.pack = -3
					e.wake()
					if i == 0:
						e.make_elite()
			w.player.bot_control = true
			w.player.aim_point = pp + Vector2(160, 20)
			w.player.aim_dir = Vector2.RIGHT
			Input.action_press("attack_1")
			await _wait(0.9)
			await _snap("fight%d_a" % zf)
			Input.action_press("skill_1")
			await _wait(0.5)
			Input.action_release("skill_1")
			Input.action_press("attack_2")
			await _wait(0.7)
			await _snap("fight%d_b" % zf)
			Input.action_release("attack_1")
			Input.action_release("attack_2")
			for e in w.enemies.duplicate():
				if e.pack == -3 and not e.dead:
					w.damage(e, 99999.0, w.player)
			await _wait(0.35)
			await _snap("fight%d_c" % zf)
			await _wait(1.0)
		elif v == "gallery":
			w.teleport_player(w.map.regions[0].pois.waypoint + Vector2(0, 90))
			await _wait(0.5)
			var base: Vector2 = w.player.global_position + Vector2(-560, -260)
			var keys: Array = Data.VARIANTS.keys()
			for i in keys.size():
				var g := w.spawn_enemy(keys[i], base + Vector2((i % 10) * 124.0, (i / 10) * 124.0), false, 0)
				g.sleeping = true
				g.pack = -1
				g.facing = Vector2.RIGHT
			await _wait(0.8)
			await _snap("gallery")
			for e in w.enemies.duplicate():
				if e.pack == -1:
					e.queue_free()
					w.enemies.erase(e)
		elif v == "boss":
			# The Ember King and whatever the hero can summon, side by side in the throne room
			var rb: Dictionary = w.map.regions[w.map.zone_region[Data.LAST_ZONE]]
			var nb: Array = rb.nodes
			w.teleport_player((Vector2(nb[mini(2, nb.size() - 1)]) + Vector2(0.5, 0.5)) * World.CELL)
			await _wait(0.8)
			var bp: Vector2 = w.player.global_position
			var king := w.spawn_enemy("ember_king", bp + Vector2(190, -40), true, w.cur)
			king.sleeping = true
			king.pack = -1
			king.facing = Vector2.LEFT
			w.spawn_minion("skeleton", bp + Vector2(-90, 40))
			w.spawn_minion("skeleton", bp + Vector2(-130, -30))
			w.spawn_minion("titan", bp + Vector2(-240, 30), 20.0)
			w.spawn_minion("vanguard", bp + Vector2(-60, -90), 20.0)
			w.camera.zoom = Vector2(2.0, 2.0)
			await _wait(1.4)
			await _snap("boss")
			w.camera.zoom = Vector2(1.5, 1.5)
			king.queue_free()
			w.enemies.erase(king)
		elif v == "interior":
			await main._enter_interior(Data.LAST_ZONE + 1)
			await _wait(1.5)
			w = main.world
			w.player.invuln_t = 9999.0
			await _snap("interior_a")
			var ni: Array = w.map.regions[0].nodes
			w.teleport_player((Vector2(ni[ni.size() / 2]) + Vector2(0.5, 0.5)) * World.CELL)
			await _wait(1.2)
			await _snap("interior_b")
			main._exit_interior_now(main._door_pos + Vector2(0, 70))
			w = main.world
			await _wait(0.5)
		elif v == "cuts":
			# A still of every cutscene shot
			for id in Cutscene.SCENES.keys():
				for sidx in (4 if id == "intro" else 1):
					var cs := Cutscene.new()
					main.cut_layer.add_child(cs)
					cs.play(id)
					cs.idx = sidx
					cs.clock = 6.0
					for f in 8:
						await get_tree().process_frame
						cs.t = 2.5
						cs.shot_t = 2.5
						cs.fade = 1.0
					await _snap("cut_%s_%d" % [id, sidx])
					cs.queue_free()
			Voice.stop()
		elif v == "loot":
			# What lies on the ground after a fight: every rarity of item, gold, life globes, blood and ash
			var zl: Dictionary = w.map.regions[w.map.zone_region[1]]
			var nl: Array = zl.nodes
			w.teleport_player((Vector2(nl[mini(2, nl.size() - 1)]) + Vector2(0.5, 0.5)) * World.CELL)
			await _wait(0.6)
			var lp: Vector2 = w.player.global_position
			for i in 8:
				var it: Dictionary = Items.roll_drop("champion", 12, 400.0, "", i % 4)
				var l := Loot.new()
				l.world = w
				l.item = it
				w.entity_layer.add_child(l)
				l.global_position = lp + Vector2(-300 + i * 86.0, -110 + (i % 2) * 40.0)
				w.loots.append(l)
			for i in 5:
				w.drop_gold(20 + i * 40, lp + Vector2(-200 + i * 90.0, 110))
				w.drop_globe(lp + Vector2(-200 + i * 100.0, 190))
			w.decals.add_blood(lp + Vector2(180, 20), 34.0, Vector2.RIGHT, Color(0.42, 0.02, 0.03), true)
			w.decals.add_blood(lp + Vector2(240, 60), 16.0, Vector2.RIGHT, Color(0.42, 0.02, 0.03))
			w.decals.add_remains(lp + Vector2(200, 30), 22.0, Color(0.42, 0.02, 0.03))
			w.decals.add_ash(lp + Vector2(-220, 30), 30.0)
			w.decals.add_scorch(lp + Vector2(-140, -30), 60.0)
			w.camera.zoom = Vector2(2.0, 2.0)
			await _wait(1.2)
			await _snap("loot")
			w.camera.zoom = Vector2(1.5, 1.5)
		elif v == "props":
			# Every kind of scenery in rows, two zoomed pages, under the village's own light
			w.teleport_player(w.map.regions[0].pois.waypoint + Vector2(0, 90))
			await _wait(0.5)
			var kinds := ["rock", "rubble", "spike", "dead_tree", "pine", "stump", "pillar", "grave", "brazier", "banner", "chain", "reeds",
				"hanged", "impaled", "bones", "skull_pile", "sarcophagus", "candles", "throne", "hut", "stall", "well", "barrel", "crate",
				"bonfire", "chest", "chest_iron", "waypoint", "door", "gate_seg", "crown", "altar", "portal", "shrine_fury", "shrine_warding", "shrine_haste", "sigil"]
			var origin: Vector2 = w.player.global_position + Vector2(-380, -170)
			var made: Array = []
			for i in kinds.size():
				var pr := w.add_prop(kinds[i], origin + Vector2((i % 6) * 152.0, (i / 6) * 150.0))
				pr.radius = 0.0
				w.interactives.erase(pr)
				made.append(pr)
			w.player.visible = false
			w.camera.zoom = Vector2(2.2, 2.2)
			w.camera.position_smoothing_enabled = false
			for page in 3:
				for f in 50:
					w.player.global_position = origin + Vector2(380, 150 + page * 300.0)
					await get_tree().process_frame
				await _snap("props_%d" % page)
			for pr in made:
				w.props.erase(pr)
				pr.queue_free()
			w.player.visible = true
			w.camera.zoom = Vector2(1.5, 1.5)
			w.camera.position_smoothing_enabled = true
	get_tree().quit()
