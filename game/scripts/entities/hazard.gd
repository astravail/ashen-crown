class_name Hazard
extends Node2D
## Ground effects: telegraphed strikes, burning areas, poison clouds.

const Ink := preload("res://scripts/fx/ink.gd")

## Round stamps, white so they take any colour, each drawn as a single textured rect:
## a disc that is dim in the middle and bright toward its edge, a crisp rim with a hairline inside it,
## a flat pool with a soft shore, and a bubble.
static var _fill: Texture2D
static var _rim: Texture2D
static var _pool: Texture2D
static var _bubble: Texture2D
## The marks cut around a rim of radius 1, as line segments.
static var _ticks := PackedVector2Array()
static var _no_uv := PackedVector2Array()

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
var _seed := 0.0
## A line strike's borders, and the hairlines and chevrons inside them, in its own space.
var _edge := PackedVector2Array()
var _marks := PackedVector2Array()


func init() -> void:
	material = World.unshaded_add
	_seed = randf() * 100.0
	if _fill == null:
		_build_stamps()
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
		"line":
			_build_lane()
		"firestorm":
			light = world.make_light(Color(1.0, 0.45, 0.2), 1.3, radius * 4.0)
		"fire_pool":
			light = world.make_light(Color(1.0, 0.4, 0.15), 0.7, radius * 3.0)
		"poison":
			# murk has to darken the ground under it, so it is drawn on the plain unlit layer
			material = World.unshaded
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
			var late := k * k
			var c := color
			# a throb that quickens as the blow nears
			var throb := 0.5 + 0.5 * sin(t * (9.0 + 22.0 * k))
			# the ground inside heats up
			_stamp(_fill, radius, Color(c.r, c.g, c.b, 0.2 + 0.2 * k + 0.1 * late * throb))
			# a tide of light spreads from the middle and meets the rim at the moment of impact
			var rk := radius * k
			Ink.glow(self, Vector2.ZERO, rk * 1.3, Color(c.r, c.g, c.b, 0.12 + 0.2 * late))
			_stamp(_rim, rk, Color(c.r, c.g, c.b, 0.55))
			# the rim itself: crisp, and cut with marks that turn slowly
			_stamp(_rim, radius, Color(c.r * 1.2, c.g * 1.2, c.b * 1.2, 0.75 + 0.25 * k))
			draw_multiline(Transform2D(t * 0.35 + _seed, Vector2(radius, radius), 0.0, Vector2.ZERO) * _ticks, Color(c.r, c.g, c.b, 0.5 + 0.4 * k), 1.6, true)
		"line":
			var k2 := clampf(t / delay, 0.0, 1.0)
			var c2 := color
			var hw := width * 0.5
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
			# the lane: brightest along its borders, like the inside of a rim
			var side := Color(c2.r, c2.g, c2.b, 0.24 + 0.14 * k2)
			var mid := Color(c2.r, c2.g, c2.b, 0.07 + 0.07 * k2)
			draw_primitive(PackedVector2Array([Vector2(0, -hw), Vector2(length, -hw), Vector2(length, 0), Vector2.ZERO]), PackedColorArray([side, side, mid, mid]), _no_uv)
			draw_primitive(PackedVector2Array([Vector2(0, hw), Vector2(length, hw), Vector2(length, 0), Vector2.ZERO]), PackedColorArray([side, side, mid, mid]), _no_uv)
			# the charge runs down it and reaches the far end at the moment of impact
			var x := length * k2
			var soft := Ink.soft_tex()
			draw_texture_rect_region(soft, Rect2(0, -hw, x, width), Rect2(31, 0, 2, 64), Color(c2.r, c2.g, c2.b, 0.22 + 0.2 * k2))
			draw_texture_rect(soft, Rect2(x - hw * 1.1, -hw * 1.15, hw * 2.2, width * 1.15), false, Color(c2.r, c2.g, c2.b, 0.4))
			draw_line(Vector2(x, -hw), Vector2(x, hw), Color(c2.r * 1.2, c2.g * 1.2, c2.b * 1.2, 0.8), 2.0, true)
			draw_multiline(_marks, Color(c2.r, c2.g, c2.b, 0.3 + 0.3 * k2), 1.5, true)
			draw_multiline(_edge, Color(c2.r * 1.2, c2.g * 1.2, c2.b * 1.2, 0.7 + 0.3 * k2), 2.2, true)
		"firestorm":
			var a := clampf(minf(t / 0.3, (duration - t) / 0.4), 0.0, 1.0)
			var breathe := 0.85 + 0.15 * sin(t * 6.0)
			# scorched, glowing ground out to the edge of the storm
			_stamp(_fill, radius, Color(1.5, 0.36, 0.08, 0.3 * a))
			Ink.glow(self, Vector2.ZERO, radius * 1.05, Color(1.7, 0.45, 0.09, 0.24 * a * breathe))
			_stamp(_rim, radius, Color(2.6, 0.8, 0.18, 0.45 * a))
			draw_multiline(Transform2D(-t * 0.5, Vector2(radius, radius), 0.0, Vector2.ZERO) * _ticks, Color(2.6, 0.8, 0.18, 0.35 * a), 1.6, true)
			# fire breaks out of the ground wherever the storm is striking
			for i in 6:
				var ph := t * (0.9 + 0.13 * i) + i * 0.37 + _seed
				var cyc := floorf(ph)
				var grow := sin((ph - cyc) * PI)
				var ang := TAU * _rand(cyc + i * 7.31)
				var p := Vector2(cos(ang), sin(ang)) * sqrt(_rand(cyc * 1.7 + i * 3.1)) * radius * 0.8
				Ink.glow(self, p, 26.0 * grow, Color(2.2, 0.6, 0.12, 0.4 * a))
				Ink.flame(self, p, 6.0 + 5.0 * grow, 48.0 * grow, t, i * 1.7, Color(3.4, 1.4, 0.35, 0.95 * a), Color(2.2, 0.45, 0.08, 0.7 * a))
		"fire_pool":
			var a2 := clampf(minf(t / 0.3, (duration - t) / 0.8), 0.0, 1.0)
			var fl := 0.85 + 0.1 * sin(t * 7.0 + _seed) + 0.05 * sin(t * 13.0 + _seed * 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			# a bed of embers out to the edge, molten in the middle
			_stamp(_fill, radius, Color(1.3, 0.24, 0.05, 0.42 * a2))
			Ink.glow(self, Vector2.ZERO, radius, Color(2.2, 0.6, 0.12, 0.4 * a2 * fl))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# flames licking up from it, the hottest in the middle
			var n := 3 if radius < 45.0 else 5
			for i in n:
				var ang2 := _seed + i * TAU / n + 0.5 * sin(i * 1.9 + _seed)
				var rr := radius * (0.25 + 0.35 * _rand(i * 0.618 + _seed))
				var sz := radius * (0.85 + 0.3 * _rand(i * 2.3 + _seed))
				Ink.flame(self, Vector2(cos(ang2) * rr, sin(ang2) * rr * 0.7), sz * 0.2, sz * 0.7, t, _seed + i * 2.1, Color(2.8, 0.8, 0.16, 0.9 * a2), Color(2.0, 0.36, 0.07, 0.65 * a2))
			Ink.flame(self, Vector2(0, radius * 0.12), radius * 0.14, radius * 0.5, t, _seed + 9.0, Color(4.0, 2.6, 1.1, a2), Color(3.2, 1.3, 0.3, 0.85 * a2))
		"poison":
			var a3 := clampf(minf(t / 0.3, (duration - t) / 0.8), 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			# murk, with a sickly light gathering at its shore and drifting across it
			_stamp(_pool, radius, Color(0.06, 0.12, 0.035, 0.62 * a3))
			_stamp(_fill, radius, Color(0.5, 1.1, 0.22, 0.3 * a3))
			var drift := Vector2(cos(t * 0.7 + _seed), sin(t * 0.9 + _seed)) * radius * 0.3
			Ink.glow(self, drift, radius * 0.6, Color(0.5, 1.2, 0.25, 0.2 * a3))
			Ink.glow(self, -drift, radius * 0.45, Color(0.02, 0.05, 0.01, 0.35 * a3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# bubbles swell and burst
			for i in 5:
				var ph2 := t * (0.7 + 0.11 * i) + i * 0.43 + _seed
				var cyc2 := floorf(ph2)
				var f := ph2 - cyc2
				var ang3 := TAU * _rand(cyc2 + i * 5.7)
				var rr2 := sqrt(_rand(cyc2 * 1.3 + i * 2.9)) * radius * 0.78
				var br := (2.0 + radius * 0.045) * (0.3 + 0.7 * f)
				draw_texture_rect(_bubble, Rect2(cos(ang3) * rr2 - br, sin(ang3) * rr2 * 0.7 - br, br * 2.0, br * 2.0), false, Color(0.85, 1.7, 0.45, (1.0 - f * f) * 0.9 * a3))


## One round stamp of radius r, centred on the hazard.
func _stamp(tex: Texture2D, r: float, col: Color) -> void:
	draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, col)


## A number between 0 and 1 that is always the same for the same x.
static func _rand(x: float) -> float:
	var v := sin(x * 12.9898) * 43758.5453
	return v - floorf(v)


## The borders of a line strike, and the hairlines and chevrons that point the way down it.
func _build_lane() -> void:
	var hw := width * 0.5
	_edge = PackedVector2Array([Vector2(0, -hw), Vector2(length, -hw), Vector2(0, hw), Vector2(length, hw), Vector2(length, -hw), Vector2(length, hw), Vector2(0, -hw), Vector2(0, hw)])
	var inset := minf(6.0, hw * 0.25)
	_marks = PackedVector2Array([Vector2(0, -hw + inset), Vector2(length, -hw + inset), Vector2(0, hw - inset), Vector2(length, hw - inset)])
	var step := maxf(44.0, width * 0.8)
	var h := hw * 0.42
	var x := step
	while x < length - 4.0:
		_marks.append(Vector2(x - h * 0.8, -h))
		_marks.append(Vector2(x, 0))
		_marks.append(Vector2(x, 0))
		_marks.append(Vector2(x - h * 0.8, h))
		x += step


static func _build_stamps() -> void:
	_fill = _radial(256, [0.0, 0.5, 0.82, 0.96, 0.985, 1.0], [0.32, 0.36, 0.62, 1.0, 1.0, 0.0])
	_rim = _radial(512, [0.0, 0.845, 0.855, 0.868, 0.878, 0.945, 0.957, 0.986, 1.0], [0.0, 0.0, 0.5, 0.5, 0.1, 0.1, 1.0, 1.0, 0.0])
	_pool = _radial(128, [0.0, 0.72, 0.9, 1.0], [1.0, 1.0, 0.7, 0.0])
	_bubble = _radial(64, [0.0, 0.55, 0.78, 0.9, 1.0], [0.1, 0.2, 1.0, 0.9, 0.0])
	# twelve ticks standing between the hairline and the rim, and four notches pointing inward
	for i in 12:
		var u := Vector2.from_angle(TAU * i / 12.0)
		_ticks.append(u * 0.885)
		_ticks.append(u * 0.94)
	for i in 4:
		var a := TAU * i / 4.0 + TAU / 24.0
		var tip := Vector2.from_angle(a) * 0.76
		_ticks.append(Vector2.from_angle(a - 0.07) * 0.85)
		_ticks.append(tip)
		_ticks.append(tip)
		_ticks.append(Vector2.from_angle(a + 0.07) * 0.85)


## A round texture whose opacity at each distance from the centre is given by `alphas` at `offsets`.
static func _radial(size: int, offsets: Array, alphas: Array) -> Texture2D:
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


func _s() -> Actor:
	return src if is_instance_valid(src) else null
