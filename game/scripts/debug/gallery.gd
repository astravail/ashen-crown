extends Node
## Spawns every enemy variant in rows and saves a screenshot: godot --path game -- --gallery=/tmp/out.png

var main: Node
var out := "/tmp/gallery.png"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gallery="):
			out = a.substr(10)
	await get_tree().create_timer(0.6).timeout
	Game.new_run("knight")
	main._carry = {}
	await main._start_overworld()
	await get_tree().create_timer(1.0).timeout
	var w: World = main.world
	var base: Vector2 = w.player.global_position + Vector2(-200, -330)
	var keys: Array = Data.VARIANTS.keys()
	var cols := 10
	var made: Array = []
	for i in keys.size():
		var e := w.spawn_enemy(keys[i], base + Vector2((i % cols) * 120.0, (i / cols) * 120.0), false, 0)
		e.sleeping = true
		e.pack = -1
		e.facing = Vector2.RIGHT
		made.append(e)
	w.player.invuln_t = 999.0
	w.camera.global_position = base + Vector2(560, 250)
	w.camera.zoom = Vector2(0.95, 0.95)
	w.canvas_mod.color = Color(2.2, 2.2, 2.2)
	w._target_mod = w.canvas_mod.color
	w.camera.position_smoothing_enabled = false
	for i in 40:
		await get_tree().process_frame
		w.camera.global_position = base + Vector2(560, 250)
		w.canvas_mod.color = Color(2.2, 2.2, 2.2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	# The village itself, at its normal lighting
	for e in made:
		e.queue_free()
		w.enemies.erase(e)
	w.canvas_mod.color = w.zone.modulate
	w._target_mod = w.zone.modulate
	w.camera.zoom = Vector2(1.0, 1.0)
	w.camera.global_position = w.map.regions[0].pois.waypoint + Vector2(0, -120)
	for i in 30:
		await get_tree().process_frame
		w.camera.global_position = w.map.regions[0].pois.waypoint + Vector2(0, -120)
	get_viewport().get_texture().get_image().save_png(out.replace(".png", "_village.png"))
	print("[gallery] saved ", out, " variants=", keys.size())
	get_tree().quit()
