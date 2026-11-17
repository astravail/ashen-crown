class_name Projectile
extends Node2D

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


func init() -> void:
	material = World.unshaded_add
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
		"shard":
			radius = 7.0
			life = 0.4
			pierce = true
		"fireball":
			radius = 11.0
			life = 3.0
			light = world.make_light(Color(1.0, 0.45, 0.2), 0.8, 240.0)
		"king_orb":
			radius = 13.0
			life = 5.0
			light = world.make_light(Color(1.0, 0.4, 0.15), 0.6, 200.0)
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
			draw_circle(Vector2.ZERO, 14, Color(1.6, 0.5, 0.12, 0.25), true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(-22, -6), Vector2(-30, 0), Vector2(-22, 6)]), Color(2.6, 0.8, 0.2, 0.8))
			draw_circle(Vector2.ZERO, 6, Color(4.0, 2.4, 1.0), true, -1.0, true)
		"bone", "shard":
			var s := 1.0 if kind == "bone" else 0.6
			draw_colored_polygon(PackedVector2Array([Vector2(26, 0) * s, Vector2(-6, -5) * s, Vector2(-26, -2) * s, Vector2(-26, 2) * s, Vector2(-6, 5) * s]), Color(1.5, 1.45, 1.3))
			draw_line(Vector2(-26, 0) * s, Vector2(-60, 0) * s, Color(0.6, 1.2, 1.1, 0.35), 4.0 * s, true)
		"fireball":
			draw_circle(Vector2.ZERO, 18, Color(1.5, 0.4, 0.1, 0.25), true, -1.0, true)
			draw_circle(Vector2.ZERO, 10, Color(2.8, 0.8, 0.2), true, -1.0, true)
			draw_circle(Vector2.ZERO, 5, Color(4.0, 2.2, 0.9), true, -1.0, true)
		"king_orb":
			draw_circle(Vector2.ZERO, 20, Color(1.8, 0.3, 0.08, 0.3), true, -1.0, true)
			draw_circle(Vector2.ZERO, 12, Color(3.0, 0.6, 0.15), true, -1.0, true)
			draw_circle(Vector2.ZERO, 6, Color(4.0, 2.0, 0.8), true, -1.0, true)
		"firewave":
			var a := clampf(life / 0.2, 0.0, 1.0)
			draw_arc(Vector2(-20, 0), radius, -1.0, 1.0, 20, Color(3.0, 0.9, 0.2, 0.7 * a), 10.0, true)
			draw_arc(Vector2(-26, 0), radius * 0.9, -0.9, 0.9, 20, Color(4.0, 2.0, 0.8, 0.5 * a), 4.0, true)


func _s() -> Actor:
	return src if is_instance_valid(src) else null
