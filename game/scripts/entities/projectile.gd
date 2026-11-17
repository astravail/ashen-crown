class_name Projectile
extends Node2D

const Ink := preload("res://scripts/fx/ink.gd")

## The bone lance, point toward +x: the pieces of its fill, their shading, and its inked edge as line
## segments. Built once and shared, so drawing a lance allocates nothing.
static var _lance: Array[PackedVector2Array] = []
static var _lance_cols: Array[PackedColorArray] = []
static var _lance_edge := PackedVector2Array()
## A thin bright ring with a soft outside, for the crown of fire around the king's orbs.
static var _halo: Texture2D
static var _no_uv := PackedVector2Array()

var world: World
var kind := "ember"
var dir := Vector2.RIGHT
var speed := 600.0
var dmg := 10.0
var team := Actor.Team.PLAYER
var opts := {}
var radius := 8.0
var life := 1.2
var done := false
var pierce := false
var hit := {}
var t := 0.0
var light: PointLight2D
var src: Actor
var _seed := 0.0


func init() -> void:
	material = World.unshaded_add
	_seed = randf() * 10.0
	src = opts.get("src", null)
	match kind:
		"ember":
			radius = 9.0
			life = 0.9
			pierce = opts.get("pierce", false)
			light = world.make_light(Color(1.0, 0.5, 0.2), 0.9, 260.0)
		"bone":
			radius = 10.0
			life = 0.85
			pierce = true
			_use_lance()
		"shard":
			radius = 7.0
			life = 0.4
			pierce = true
			_use_lance()
		"fireball":
			radius = 11.0
			life = 3.0
			light = world.make_light(Color(1.0, 0.45, 0.2), 0.8, 240.0)
		"king_orb":
			radius = 13.0
			life = 5.0
			light = world.make_light(Color(1.0, 0.4, 0.15), 0.6, 200.0)
			if _halo == null:
				_halo = _ring_tex()
		"firewave":
			radius = 46.0
			life = 0.55
			pierce = true
	if light:
		add_child(light)
	rotation = dir.angle()


func update(dt: float) -> void:
	if done:
		return
	t += dt
	life -= dt
	var step := dir * speed * dt
	global_position += step
	if not world.is_floor_at(global_position) and kind != "firewave":
		_impact(null)
		return
	if life <= 0.0:
		if kind == "fireball" or kind == "ember":
			_impact(null)
		done = true
		return
	if team == Actor.Team.PLAYER:
		for e in world.enemies:
			if e.dead or hit.has(e.get_instance_id()):
				continue
			if e.global_position.distance_to(global_position) < radius + e.radius:
				hit[e.get_instance_id()] = true
				_hit_enemy(e)
				if not pierce:
					done = true
					return
	else:
		var targets: Array[Actor] = []
		if world.player and not world.player.dead:
			targets.append(world.player)
		for m in world.minions:
			targets.append(m)
		for a in targets:
			if a.dead or hit.has(a.get_instance_id()):
				continue
			if a.global_position.distance_to(global_position) < radius + a.radius:
				hit[a.get_instance_id()] = true
				world.damage(a, dmg, _s(), {"type": "fire", "knock": dir * 120.0})
				_impact(a)
				return
	_trail(dt)
	queue_redraw()


func _hit_enemy(e: Enemy) -> void:
	match kind:
		"ember":
			var o := {"type": "fire", "knock": dir * 90.0}
			if opts.get("phoenix", false):
				o.burn = [dmg * 0.4, 2.0]
			world.damage(e, dmg, _s(), o)
			world.area_damage(global_position, 46.0 * world.player.area_mult(), dmg * 0.35, _s(), team, {"type": "fire", "can_crit": false})
			world.glow_fx.burst(global_position, 8, Color(3.0, 1.0, 0.25), 60, 240, 0.35, 2.0, Particles.SPARK)
			world.glow_fx.emit(global_position, Vector2.ZERO, 0.2, 30.0, Color(2.0, 0.7, 0.2, 0.4), Particles.GLOW, 0.0)
			Sfx.play("hit", -10.0, 0.15, 1.3)
		"bone", "shard":
			world.damage(e, dmg, _s(), {"type": "bone", "knock": dir * 70.0})
			world.smoke_fx.burst(global_position, 5, Color(0.85, 0.82, 0.75), 60, 200, 0.4, 3.0, Particles.DEBRIS, 1.4, dir.angle(), 4.0, 0.0)
			Sfx.play("bone", -10.0)
			if kind == "bone" and opts.get("split", false) and not opts.get("split_done", false):
				opts.split_done = true
				for a in [-0.5, 0.0, 0.5]:
					var p := world.spawn_projectile("shard", global_position + dir * 20.0, dir.rotated(a), speed * 0.9, dmg * 0.5, team, {"src": _s()})
					p.hit[e.get_instance_id()] = true
		"firewave":
			world.damage(e, dmg, _s(), {"type": "fire", "burn": [dmg * 0.25, 2.5], "knock": dir * 160.0})


func _impact(_target: Actor) -> void:
	done = true
	match kind:
		"ember":
			world.glow_fx.burst(global_position, 6, Color(3.0, 1.0, 0.25), 40, 160, 0.3, 2.0, Particles.SPARK)
		"fireball", "king_orb":
			world.glow_fx.burst(global_position, 10, Color(3.0, 0.9, 0.2), 40, 200, 0.4, 2.5, Particles.SPARK)
			world.smoke_fx.burst(global_position, 4, Color(0.2, 0.18, 0.17, 0.6), 20, 60, 0.8, 8, Particles.SMOKE)
			Sfx.play("explode_small", -14.0)
		"bone":
			world.smoke_fx.burst(global_position, 6, Color(0.85, 0.82, 0.75), 60, 200, 0.4, 3.0, Particles.DEBRIS)


func _trail(_dt: float) -> void:
	match kind:
		"ember":
			world.glow_fx.emit(global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3)), -dir * 40.0 + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.3, 3.0, Color(2.8, 0.8, 0.2), Particles.EMBER, 2.0)
		"fireball", "king_orb":
			world.glow_fx.emit(global_position, Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.4, 5.0, Color(2.4, 0.6, 0.15, 0.8), Particles.EMBER, 2.0)
		"firewave":
			for i in 2:
				var off := Vector2(-dir.y, dir.x) * randf_range(-radius, radius)
				world.glow_fx.emit(global_position + off, Vector2(0, -60) + dir * 40.0, 0.45, 4.0, Color(3.0, 0.9, 0.2), Particles.EMBER, 1.0)


func _draw() -> void:
	match kind:
		"ember":
			# a bolt of fire: a white-hot bead dragging two soft tails
			var fl := 1.0 + 0.12 * sin(t * 47.0 + _seed) + 0.08 * sin(t * 71.0)
			Ink.glow(self, Vector2(-4, 0), 27.0, Color(1.5, 0.45, 0.1, 0.3))
			_comet(13.0, 60.0 * fl, Color(2.2, 0.6, 0.13, 0.75))
			_comet(7.0, 30.0 * fl, Color(3.4, 1.5, 0.45, 0.95))
			Ink.dot(self, Vector2(1, 0), 3.0, Color(4.0, 3.0, 1.6))
		"bone", "shard":
			var s := 1.0 if kind == "bone" else 0.6
			# the cold light that carries it, strung out behind
			draw_texture_rect_region(Ink.soft_tex(), Rect2(-98.0 * s, -8.0 * s, 80.0 * s, 16.0 * s), Rect2(0, 0, 32, 64), Color(0.5, 1.3, 1.15, 0.45))
			Ink.glow(self, Vector2(4.0 * s, 0), 24.0 * s, Color(0.45, 1.15, 1.0, 0.2))
			# the lance itself, turned over when it flies left so its pale side stays uppermost
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s if dir.x >= 0.0 else -s))
			for i in _lance.size():
				draw_primitive(_lance[i], _lance_cols[i], _no_uv)
			draw_multiline(_lance_edge, Ink.LINE, 1.7, true)
			draw_line(Vector2(-17, -1.3), Vector2(18, -1.2), Color(1.25, 1.2, 1.05, 0.7), 1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"fireball":
			# a thrown ball of fire: heavier and redder than the player's bolts, with flames streaming off it
			var pulse := 1.0 + 0.08 * sin(t * 22.0 + _seed)
			Ink.glow(self, Vector2.ZERO, 34.0, Color(1.5, 0.3, 0.07, 0.32))
			_flames_behind(Vector2(3, 0), 9.0, 42.0, Color(2.4, 0.55, 0.11, 0.75), Color(1.8, 0.28, 0.05, 0.6))
			_flames_behind(Vector2(2, 0), 5.5, 25.0, Color(3.4, 1.4, 0.38, 0.95), Color(2.8, 0.8, 0.18, 0.85))
			Ink.glow(self, Vector2.ZERO, 18.0 * pulse, Color(3.0, 0.8, 0.18, 0.95))
			Ink.dot(self, Vector2(1.5, 0), 4.0, Color(4.0, 2.6, 1.1))
		"king_orb":
			# the Ember King's orbs: slow, molten, and crowned with a ring of fire that beats like a heart
			var beat := 1.0 + 0.1 * sin(t * 9.0 + _seed)
			Ink.glow(self, Vector2.ZERO, 44.0, Color(1.6, 0.24, 0.06, 0.3))
			_flames_behind(Vector2(4, 0), 11.0, 32.0, Color(2.4, 0.45, 0.09, 0.7), Color(1.7, 0.2, 0.04, 0.55))
			Ink.glow(self, Vector2.ZERO, 22.0 * beat, Color(3.0, 0.5, 0.1, 0.95))
			var hr := 19.0 * beat
			draw_texture_rect(_halo, Rect2(-hr, -hr, hr * 2.0, hr * 2.0), false, Color(3.6, 1.4, 0.35, 0.85))
			# two sparks circling it
			var orbit := Vector2.from_angle(t * 7.0 + _seed) * 15.0 * beat
			Ink.dot(self, orbit, 2.0, Color(4.0, 2.4, 1.0))
			Ink.dot(self, -orbit, 2.0, Color(4.0, 2.4, 1.0))
			Ink.dot(self, Vector2.ZERO, 5.0, Color(4.0, 2.2, 0.9))
		"firewave":
			_draw_wave(clampf(life / 0.2, 0.0, 1.0))


## A soft teardrop: a round head at the origin and a tail thinning out behind it.
func _comet(head: float, tail: float, col: Color) -> void:
	var soft := Ink.soft_tex()
	draw_texture_rect_region(soft, Rect2(-tail, -head, tail, head * 2.0), Rect2(0, 0, 32, 64), col)
	draw_texture_rect_region(soft, Rect2(0, -head, head, head * 2.0), Rect2(32, 0, 32, 64), col)


## A tongue of flame laid along the path already flown, rooted at `at`.
func _flames_behind(at: Vector2, w: float, h: float, hot: Color, cool: Color) -> void:
	draw_set_transform(at, -PI * 0.5, Vector2.ONE)
	Ink.flame(self, Vector2.ZERO, w, h, t, _seed + w, hot, cool)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A crescent of fire as wide as the wave's reach: white-hot along its leading edge and torn into
## tongues where it trails away. Built from quads, each fading from the edge backward.
func _draw_wave(a: float) -> void:
	var r := radius + 2.0
	var c0 := Vector2(-20, 0)
	draw_texture_rect(Ink.soft_tex(), Rect2(-52.0, -r * 1.2, 96.0, r * 2.4), false, Color(1.6, 0.4, 0.08, 0.26 * a))
	var gone := Color(2.0, 0.35, 0.06, 0.0)
	var lip_gone := Color(4.0, 2.2, 0.8, 0.0)
	var n := 7
	var lead0 := Vector2.ZERO
	var back0 := 0.0
	var k0 := 0.0
	for i in n + 1:
		var u := float(i) / n
		var th := -1.05 + 2.1 * u
		# 0 at the horns of the crescent, 1 in its middle
		var k := sin(u * PI)
		var lead := c0 + Vector2(cos(th), sin(th)) * r
		var back := (8.0 + 30.0 * k) * (1.0 + 0.3 * sin(t * 23.0 + i * 2.4 + _seed)) + (10.0 if i % 2 == 1 else 0.0)
		if i > 0:
			var c_a := Color(3.2, 1.0, 0.24, 0.85 * a * (0.2 + 0.8 * k0))
			var c_b := Color(3.2, 1.0, 0.24, 0.85 * a * (0.2 + 0.8 * k))
			draw_primitive(PackedVector2Array([lead0, lead, lead - Vector2(back, 0), lead0 - Vector2(back0, 0)]), PackedColorArray([c_a, c_b, gone, gone]), _no_uv)
			var l_a := Color(4.0, 2.6, 1.1, a * k0)
			var l_b := Color(4.0, 2.6, 1.1, a * k)
			draw_primitive(PackedVector2Array([lead0, lead, lead - Vector2(7.0, 0), lead0 - Vector2(7.0, 0)]), PackedColorArray([l_a, l_b, lip_gone, lip_gone]), _no_uv)
		lead0 = lead
		back0 = back
		k0 = k


## Bone is solid: it has to cover what is behind it, so it is drawn on the plain unlit layer.
func _use_lance() -> void:
	material = World.unshaded
	if not _lance.is_empty():
		return
	var top := Color(1.0, 0.96, 0.84)
	var deep := Color(0.4, 0.36, 0.33)
	var pieces := [
		[Vector2(30, 0), Vector2(8, -3.6), Vector2(8, 3.6)],
		[Vector2(8, -3.6), Vector2(-19, -2.8), Vector2(-19, 2.8), Vector2(8, 3.6)],
		[Vector2(-19, -2.8), Vector2(-23, -5.4), Vector2(-23, 5.4), Vector2(-19, 2.8)],
		[Vector2(-23, -5.4), Vector2(-28, -3.8), Vector2(-28, 3.8), Vector2(-23, 5.4)]]
	for piece in pieces:
		var pts := PackedVector2Array(piece)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(deep, clampf((p.y + 5.4) / 10.8, 0.0, 1.0)))
		_lance.append(pts)
		_lance_cols.append(cols)
	var loop := [Vector2(30, 0), Vector2(8, -3.6), Vector2(-19, -2.8), Vector2(-23, -5.4), Vector2(-28, -3.8), Vector2(-28, 3.8), Vector2(-23, 5.4), Vector2(-19, 2.8), Vector2(8, 3.6)]
	for i in loop.size():
		_lance_edge.append(loop[i])
		_lance_edge.append(loop[(i + 1) % loop.size()])
	# the groove between the two knuckles of the joint
	_lance_edge.append(Vector2(-28, 0))
	_lance_edge.append(Vector2(-24.5, 0))


static func _ring_tex() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 0.72, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _s() -> Actor:
	return src if is_instance_valid(src) else null
