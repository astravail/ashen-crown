extends Node
## Automated play-tester. Enabled with: godot -- --bot=<class> [--zone=N] [--shots=DIR]
## Walks to the objective, fights what it meets, picks upgrades and reports progress.

var main: Node
var cls := "knight"
var start_zone := 0
var shot_dir := ""
var astar: AStarGrid2D
var path: PackedVector2Array = []
var path_i := 0
var repath := 0.0
var t := 0.0
var report_t := 0.0
var shot_t := 3.0
var shot_n := 0
var last_pos := Vector2.ZERO
var stuck_t := 0.0
var map_ref: WorldMap
var done := false
var ending_t := 0.0
var jitter_t := 0.0
var jitter := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			cls = a.substr(6)
		elif a.begins_with("--zone="):
			start_zone = int(a.substr(7))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
	await get_tree().create_timer(0.5).timeout
	Game.new_run(cls)
	Game.hero_name = "Bot"
	main._carry = {}
	# Open the road to the start zone and take its hunt, as a player who had followed the story would have.
	Game.quests["story_0"] = {"s": 3, "p": 1}
	for z in start_zone:
		Game.zs(z).claimed = true
		Game.zs(z).champ_dead = true
		Game.unlock("z%d" % z)
	Game.quest_accept("story_%d" % (start_zone + 1))
	Game.quest_accept("%s_cull" % Data.ZONES[start_zone].id)
	await main._load_zone(start_zone)


func _process(dt: float) -> void:
	t += dt
	var w: World = main.world
	if w == null or w.attract or main._busy:
		return
	if map_ref != w.map:
		map_ref = w.map
		_build_astar(w)
	_handle_menus(w)
	if get_tree().paused:
		_release_all()
		return
	var p := w.player
	if p == null or p.dead:
		_release_all()
		return
	report_t -= dt
	if report_t <= 0.0:
		report_t = 10.0
		print("[bot] t=%.0f zone=%d state=%s lvl=%d hp=%d/%d kills=%d enemies=%d frags=%s pos=%s goal_d=%.0f boss=%s" % [t, Game.zone_index, w.state, p.level, p.hp, p.max_hp, Game.stats.kills, w.enemies.size(), Game.fragments, p.global_position, p.global_position.distance_to(w.arena_center), (int(w.boss.hp) if w.boss and not w.boss.dead else -1)])
	if shot_dir != "":
		shot_t -= dt
		if shot_t <= 0.0:
			shot_t = 12.0
			_shot()
	p.bot_control = true
	_drive(w, p, dt)


func _handle_menus(w: World) -> void:
	var m: Menus = main.menus
	match main._overlay:
		"levelup", "fragment":
			if m._keys.size() > 0:
				m._keys[randi() % m._keys.size()].emit_signal("pressed")
		"death":
			if m.is_open():
				print("[bot] died in zone %d at t=%.0f" % [Game.zone_index, t])
				m.respawn.emit()
		"ending":
			ending_t += get_process_delta_time()
			if ending_t > 1.0 and not done:
				done = true
				_shot()
				m.ending_chosen.emit("shatter")
				print("[bot] RUN COMPLETE t=%.0f level=%d kills=%d" % [t, Game.stats.level, Game.stats.kills])
				await get_tree().create_timer(1.0).timeout
				_shot()
				get_tree().quit()


func _build_astar(w: World) -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w.map.w, w.map.h)
	astar.cell_size = Vector2(World.CELL, World.CELL)
	astar.offset = Vector2(World.CELL, World.CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in w.map.h:
		for x in w.map.w:
			if not w.map.is_floor(x, y) or w.blocked.has(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y))
	path = []


func _goal(w: World) -> Vector2:
	for p in w.interactives:
		if not p.used and p.kind == "altar":
			return p.global_position
	return w.arena_center


func _drive(w: World, p: Player, dt: float) -> void:
	var target := w.nearest_enemy(p.global_position, 700.0)
	var move := Vector2.ZERO
	var ranged := p.cls != "knight"
	if target:
		p.aim_point = target.global_position
		var d := target.global_position - p.global_position
		var dist := d.length()
		if ranged:
			if dist < 200.0:
				move = -d.normalized()
			elif dist > 420.0:
				move = w.path_dir(p.global_position, target.global_position)
		else:
			if dist > 60.0:
				move = w.path_dir(p.global_position, target.global_position)
		_press("attack_1", true)
		_press("attack_2", randf() < 0.3)
		_press("skill_1", randf() < 0.15)
		_press("skill_2", randf() < 0.15)
		_press("ultimate", p.ash >= 100.0)
		_press("flask", p.hp < p.max_hp * 0.35)
		_press("dodge", p.hp < p.max_hp * 0.5 and randf() < 0.03)
	else:
		_release_all()
		repath -= dt
		if repath <= 0.0 or path_i >= path.size():
			repath = 1.0
			var from := Vector2i(p.global_position / World.CELL)
			var to := Vector2i(_goal(w) / World.CELL)
			path = astar.get_point_path(from, to)
			path_i = 1
		if path_i < path.size():
			var wp := path[path_i]
			if p.global_position.distance_to(wp) < 40.0:
				path_i += 1
			move = (wp - p.global_position).normalized()
		p.aim_point = p.global_position + move * 200.0
	if jitter_t > 0.0:
		jitter_t -= dt
		move = jitter
	if move != Vector2.ZERO:
		p.aim_dir = (p.aim_point - p.global_position).normalized()
	_set_move(move)
	if p.global_position.distance_to(last_pos) < 1.0 and move != Vector2.ZERO:
		stuck_t += dt
		if stuck_t > 1.5:
			var c := Vector2i(p.global_position / World.CELL)
			var rows := []
			for yy in range(c.y - 2, c.y + 3):
				var row := ""
				for xx in range(c.x - 2, c.x + 3):
					row += "#" if not w.map.is_floor(xx, yy) else ("@" if Vector2i(xx, yy) == c else ".")
				rows.append(row)
			print("[bot] stuck at %s target=%s move=%s path=%d/%d wp=%s grid=%s stunned=%s" % [p.global_position, target, move, path_i, path.size(), path[path_i] if path_i < path.size() else Vector2.ZERO, rows, p.is_stunned()])
			stuck_t = 0.0
			repath = 0.0
			jitter = move.rotated(PI / 2 * (1 if randf() < 0.5 else -1))
			jitter_t = 0.7
	else:
		stuck_t = 0.0
	last_pos = p.global_position


func _set_move(v: Vector2) -> void:
	_axis("move_right", maxf(0.0, v.x))
	_axis("move_left", maxf(0.0, -v.x))
	_axis("move_down", maxf(0.0, v.y))
	_axis("move_up", maxf(0.0, -v.y))


func _axis(a: String, s: float) -> void:
	if s > 0.05:
		Input.action_press(a, s)
	else:
		Input.action_release(a)


func _press(a: String, on: bool) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)


func _release_all() -> void:
	for a in ["attack_1", "attack_2", "skill_1", "skill_2", "ultimate", "flask", "dodge", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _shot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	img.save_png("%s/shot_%02d_z%d.png" % [shot_dir, shot_n, Game.zone_index])
