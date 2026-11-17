class_name Hazard
extends Node2D
## Ground effects: telegraphed strikes, burning areas, poison clouds.

var world: World
var kind := "telegraph"
var opts := {}
var done := false
var t := 0.0
var radius := 80.0
var duration := 1.0
var delay := 1.0
var team := Actor.Team.ENEMY
var dmg := 10.0
var dps := 10.0
var color := Color(2.4, 0.6, 0.15)
var dir := Vector2.RIGHT
var length := 300.0
var width := 60.0
var src: Actor
var light: PointLight2D
var _tick := 0.0


func init() -> void:
	material = World.unshaded_add
	radius = opts.get("radius", radius)
	duration = opts.get("duration", duration)
	delay = opts.get("delay", delay)
	team = opts.get("team", team)
	dmg = opts.get("dmg", dmg)
	dps = opts.get("dps", dps)
	color = opts.get("color", color)
	dir = opts.get("dir", dir)
	length = opts.get("length", length)
	width = opts.get("width", width)
	src = opts.get("src", null)
	match kind:
		"firestorm":
			light = world.make_light(Color(1.0, 0.45, 0.2), 1.3, radius * 4.0)
		"fire_pool":
			light = world.make_light(Color(1.0, 0.4, 0.15), 0.7, radius * 3.0)
		"poison":
			light = world.make_light(Color(0.55, 0.9, 0.35), 0.45, radius * 3.0)
	if light:
		add_child(light)


func update(dt: float) -> void:
	if done:
		return
	t += dt
	match kind:
		"telegraph":
			if t >= delay:
				_trigger_circle()
				done = true
		"line":
			if t >= delay:
				_trigger_line()
				done = true
		"firestorm":
			_persist(dt, Actor.Team.PLAYER)
			var r := radius
			for i in 3:
				var a := randf() * TAU
				var p := global_position + Vector2(cos(a), sin(a)) * sqrt(randf()) * r
				world.glow_fx.emit(p + Vector2(-40, -160), Vector2(160, 640), 0.25, 3.0, Color(3.0, 0.9, 0.2), Particles.SPARK, 0.0)
			if randf() < 0.4:
				var a2 := randf() * TAU
				var p2 := global_position + Vector2(cos(a2), sin(a2)) * sqrt(randf()) * r
				world.glow_fx.burst(p2, 3, Color(3.0, 1.0, 0.3), 30, 120, 0.3, 2.0, Particles.SPARK)
			if opts.get("pull", false):
				for e in world.enemies_in_radius(global_position, r * 1.4):
					if not e.is_boss:
						e.knock += (global_position - e.global_position).normalized() * 500.0 * dt
		"fire_pool":
			_persist(dt, team)
			if randf() < dt * 8.0:
				var a := randf() * TAU
				world.glow_fx.emit(global_position + Vector2(cos(a), sin(a) * 0.6) * randf() * radius, Vector2(0, -40), 0.7, 3.0, Color(2.6, 0.7, 0.15), Particles.EMBER, 1.0)
		"poison":
			_persist(dt, team)
			if randf() < dt * 6.0:
				var a := randf() * TAU
				world.smoke_fx.emit(global_position + Vector2(cos(a), sin(a) * 0.6) * randf() * radius, Vector2(randf_range(-10, 10), -15), 1.6, radius * 0.25, Color(0.35, 0.45, 0.22, 0.5), Particles.SMOKE, 0.5)
	if light and kind != "telegraph":
		light.energy = clampf((duration - t) / 0.5, 0.0, 1.0) * (1.2 if kind == "firestorm" else 0.6)
	queue_redraw()


func _persist(dt: float, hit_team: int) -> void:
	if t >= duration:
		done = true
		return
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.25
	var o := {"type": "fire" if kind != "poison" else "poison", "dot": true}
	if kind == "firestorm":
		o.burn = [dps * 0.3, 2.0]
	if hit_team == Actor.Team.PLAYER:
		for e in world.enemies_in_radius(global_position, radius):
			world.damage(e, dps * 0.25, _s(), o)
	else:
		world.area_damage(global_position, radius, dps * 0.25, _s(), Actor.Team.ENEMY, o)


func _trigger_circle() -> void:
	var o := {"type": "fire", "knock_force": opts.get("knock", 300.0)}
	if opts.has("stun"):
		o.stun = opts.stun
	world.area_damage(global_position, radius, dmg, _s(), team, o)
	var c := color
	world.glow_fx.burst(global_position, int(radius / 4.0), c, 80, radius * 4.0, 0.5, 3.0, Particles.SPARK)
	world.glow_fx.ring(global_position, radius, Color(c.r, c.g, c.b, 0.9), 0.4)
	world.glow_fx.emit(global_position, Vector2.ZERO, 0.3, radius, Color(c.r, c.g, c.b, 0.3), Particles.GLOW, 0.0)
	world.smoke_fx.burst(global_position, int(radius / 10.0) + 3, Color(0.18, 0.16, 0.15, 0.7), 30, 120, 1.2, radius * 0.25, Particles.SMOKE)
	world.decals.add_scorch(global_position, radius * 0.8)
	world.shake(opts.get("shake", 7.0))
	Sfx.play(opts.get("sound", "slam"), -4.0)
	if opts.get("leave_pool", false):
		world.spawn_hazard("fire_pool", global_position, {"radius": radius * 0.7, "duration": 5.0, "dps": dmg * 0.25, "team": team, "src": _s()})
	if opts.get("leave_poison", false):
		world.spawn_hazard("poison", global_position, {"radius": radius * 0.9, "duration": 5.0, "dps": dmg * 0.3, "team": team, "src": _s()})


func _trigger_line() -> void:
	var a := global_position
	var b := a + dir * length
	var hits: Array[Actor] = []
	if team == Actor.Team.ENEMY:
		if world.player and not world.player.dead:
			hits.append(world.player)
		for m in world.minions:
			hits.append(m)
	else:
		for e in world.enemies:
			hits.append(e)
	for h in hits:
		var p := Geometry2D.get_closest_point_to_segment(h.global_position, a, b)
		if p.distance_to(h.global_position) < width * 0.5 + h.radius:
			world.damage(h, dmg, _s(), {"type": "fire", "knock": Vector2(-dir.y, dir.x) * 200.0 * signf((h.global_position - p).dot(Vector2(-dir.y, dir.x)) + 0.01)})
	var steps := int(length / 30.0)
	for i in steps:
		var p2 := a + dir * (float(i) / steps) * length
		world.glow_fx.burst(p2, 2, color, 40, 200, 0.5, 3.0, Particles.SPARK)
		if i % 3 == 0:
			world.smoke_fx.emit(p2, Vector2(0, -20), 1.0, width * 0.3, Color(0.18, 0.16, 0.15, 0.6), Particles.SMOKE, 1.0)
	world.shake(6.0)
	Sfx.play("explode_small", -4.0)
	if opts.get("leave_pool", false):
		for i in range(0, steps, 3):
			world.spawn_hazard("fire_pool", a + dir * (float(i) / steps) * length, {"radius": width * 0.6, "duration": 4.0, "dps": dmg * 0.3, "team": team, "src": _s()})


func _draw() -> void:
	match kind:
		"telegraph":
			var k := clampf(t / delay, 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.08 + 0.06 * k), true, -1.0, true)
			draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.18), true, -1.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.6), 2.0, true)
		"line":
			var k2 := clampf(t / delay, 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
			draw_rect(Rect2(0, -width * 0.5, length, width), Color(color.r, color.g, color.b, 0.08 + 0.05 * k2))
			draw_rect(Rect2(0, -width * 0.5, length * k2, width), Color(color.r, color.g, color.b, 0.16))
			draw_rect(Rect2(0, -width * 0.5, length, width), Color(color.r, color.g, color.b, 0.55), false, 2.0)
		"firestorm":
			var a := clampf(minf(t / 0.3, (duration - t) / 0.4), 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(1.4, 0.35, 0.08, 0.12 * a), true, -1.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(2.4, 0.7, 0.15, 0.35 * a), 2.0, true)
		"fire_pool":
			var a2 := clampf(minf(t / 0.3, (duration - t) / 0.8), 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			draw_circle(Vector2.ZERO, radius, Color(1.2, 0.25, 0.05, 0.22 * a2), true, -1.0, true)
			draw_circle(Vector2.ZERO, radius * 0.6, Color(2.0, 0.5, 0.1, 0.18 * a2), true, -1.0, true)
		"poison":
			var a3 := clampf(minf(t / 0.3, (duration - t) / 0.8), 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			draw_circle(Vector2.ZERO, radius, Color(0.35, 0.6, 0.15, 0.16 * a3), true, -1.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.6, 1.2, 0.3, 0.3 * a3), 2.0, true)


func _s() -> Actor:
	return src if is_instance_valid(src) else null
