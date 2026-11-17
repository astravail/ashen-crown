class_name Minion
extends Actor
## Allies: Ashbound skeletons, the Ossuary Titan, the Fallen Vanguard.

var kind := "skeleton"
var life := -1.0
var speed := 210.0
var dmg := 12.0
var attack_r := 30.0
var attack_cd := 0.9
var cd := 0.0
var target: Enemy
var swing_t := 0.0
var _retarget := 0.0
var spawn_t := 0.0


func setup(k: String, l: float) -> void:
	kind = k
	life = l
	team = Team.PLAYER
	var p := world.player
	var lvl := float(p.level) if p else 1.0
	match k:
		"skeleton":
			radius = 13.0
			max_hp = 70.0 * (1.0 + 0.12 * lvl)
			speed = 215.0
			attack_r = 30.0
			attack_cd = 0.85
		"titan":
			radius = 32.0
			max_hp = 900.0 * (1.0 + 0.1 * lvl)
			speed = 170.0
			attack_r = 70.0
			attack_cd = 1.5
			heavy = true
		"vanguard":
			radius = 16.0
			max_hp = 400.0 * (1.0 + 0.1 * lvl)
			speed = 300.0
			attack_r = 40.0
			attack_cd = 0.75
			heavy = true
	hp = max_hp
	cd = randf_range(0.0, 0.4)
	spawn_t = 0.4


func update(dt: float) -> void:
	anim += dt
	tick_status(dt)
	spawn_t = maxf(0.0, spawn_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	cd -= dt
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			hp = 0.0
			world._kill(self, null)
			return
	var p := world.player
	if p == null or p.dead:
		integrate(dt, Vector2.ZERO)
		return
	var to_player := p.global_position - global_position
	if to_player.length() > 1100.0:
		global_position = p.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		global_position = world.world_clamp(global_position)
		return
	_retarget -= dt
	if _retarget <= 0.0 or not is_instance_valid(target) or target.dead:
		_retarget = 0.4
		target = world.nearest_enemy(global_position, 520.0)
		if target and target.global_position.distance_to(p.global_position) > 700.0:
			target = null
	if spawn_t > 0.0:
		integrate(dt, Vector2.ZERO)
	elif target:
		var to := target.global_position - global_position
		if to.x != 0.0:
			facing = Vector2(signf(to.x), 0)
		var reach := attack_r + target.radius
		if to.length() > reach:
			integrate(dt, world.path_dir(global_position, target.global_position) * speed * move_speed_mult())
		else:
			integrate(dt, Vector2.ZERO)
			if cd <= 0.0:
				_attack()
	else:
		if to_player.length() > 130.0:
			integrate(dt, world.path_dir(global_position, p.global_position) * speed * 0.95)
			if to_player.x != 0.0:
				facing = Vector2(signf(to_player.x), 0)
		else:
			integrate(dt, Vector2.ZERO)
	queue_redraw()
	glow.queue_redraw()


func _attack() -> void:
	cd = attack_cd
	swing_t = 0.25
	var p := world.player
	var dm := p.dmg_mult()
	match kind:
		"skeleton":
			var o := {"type": "phys", "knock": (target.global_position - global_position).normalized() * 90.0, "can_crit": true}
			var d := 13.0 * dm
			if p.has_mod("raise_burn"):
				d *= 1.5
				o.burn = [5.0 * dm, 3.0]
			world.damage(target, d, p, o)
			Sfx.play("bone", -16.0)
		"titan":
			var c := global_position + facing * 40.0
			world.area_damage(c, 125.0, 75.0 * dm, p, Team.PLAYER, {"type": "phys", "knock_force": 320.0, "stun": 0.5})
			world.smoke_fx.burst(c, 12, Color(0.35, 0.33, 0.3, 0.7), 60, 220, 0.9, 12, Particles.SMOKE)
			world.glow_fx.ring(c, 125.0, Color(1.0, 2.2, 2.0, 0.7))
			world.shake(5.0)
			Sfx.play("slam", -6.0)
		"vanguard":
			var c2 := global_position + facing * 26.0
			world.area_damage(c2, 85.0, 34.0 * dm, p, Team.PLAYER, {"type": "phys", "knock_force": 200.0})
			world.glow_fx.burst(c2, 8, Color(1.6, 2.2, 3.0), 60, 220, 0.3, 2.0, Particles.SPARK)
			Sfx.play("swing", -12.0)


func _draw() -> void:
	var fade := 1.0 - spawn_t / 0.4
	draw_shadow()
	draw_set_transform(Vector2(0, (1.0 - fade) * 20.0), 0.0, Vector2(facing.x, 1.0))
	var walk := sin(anim * 12.0) * 0.8
	match kind:
		"skeleton":
			var b := shade(Color(0.72, 0.69, 0.62, fade))
			draw_line(Vector2(-4, -14), Vector2(-4 + walk * 4.0, 0), b, 2.5, true)
			draw_line(Vector2(4, -14), Vector2(4 - walk * 4.0, 0), b, 2.5, true)
			draw_line(Vector2(0, -14), Vector2(0, -34), b, 3.0, true)
			for i in 3:
				draw_line(Vector2(-7, -18 - i * 5), Vector2(7, -18 - i * 5), b, 2.0, true)
			draw_circle(Vector2(1, -40), 6.5, b, true, -1.0, true)
			var arm := Vector2(16, -24) if swing_t <= 0.0 else Vector2(18, -40)
			draw_line(Vector2(2, -32), arm, b, 2.5, true)
			draw_line(arm, arm + Vector2(14, -8 if swing_t <= 0.0 else 12), shade(Color(0.4, 0.38, 0.36, fade)), 3.0, true)
		"titan":
			var b2 := shade(Color(0.7, 0.67, 0.6, fade))
			var d := shade(Color(0.45, 0.42, 0.38, fade))
			draw_line(Vector2(-14, -40), Vector2(-16 + walk * 6.0, 0), d, 12.0, true)
			draw_line(Vector2(14, -40), Vector2(16 - walk * 6.0, 0), d, 12.0, true)
			var body := PackedVector2Array([Vector2(-30, -40), Vector2(30, -40), Vector2(40, -100), Vector2(-40, -100)])
			draw_colored_polygon(body, b2)
			for i in 4:
				draw_line(Vector2(-28, -50 - i * 12), Vector2(28, -50 - i * 12), d, 3.0, true)
			draw_circle(Vector2(4, -116), 16.0, b2, true, -1.0, true)
			var arm2 := Vector2(56, -60) if swing_t <= 0.0 else Vector2(60, -20)
			draw_line(Vector2(34, -92), arm2, b2, 10.0, true)
			draw_line(Vector2(-34, -92), Vector2(-50, -50), b2, 10.0, true)
		"vanguard":
			pass
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing.x, 1.0))
	match kind:
		"skeleton":
			glow.draw_circle(Vector2(3, -41), 1.4, Color(1.0, 2.8, 2.5), true, -1.0, true)
		"titan":
			glow.draw_circle(Vector2(0, -118), 2.6, Color(1.0, 2.8, 2.5), true, -1.0, true)
			glow.draw_circle(Vector2(9, -118), 2.6, Color(1.0, 2.8, 2.5), true, -1.0, true)
			glow.draw_circle(Vector2(0, -72), 9.0, Color(0.5, 1.5, 1.4, 0.4), true, -1.0, true)
		"vanguard":
			var a := 0.55 + 0.15 * sin(anim * 5.0)
			var c := Color(0.8, 1.2, 1.8, a)
			var walk := sin(anim * 12.0) * 0.8
			glow.draw_line(Vector2(-6, -18), Vector2(-6 + walk * 5.0, 0), c, 5.0, true)
			glow.draw_line(Vector2(6, -18), Vector2(6 - walk * 5.0, 0), c, 5.0, true)
			glow.draw_colored_polygon(PackedVector2Array([Vector2(-12, -16), Vector2(12, -16), Vector2(15, -42), Vector2(-15, -42)]), c)
			glow.draw_circle(Vector2(0, -50), 8.0, c, true, -1.0, true)
			var ang := -0.6 if swing_t <= 0.0 else 0.9
			glow.draw_line(Vector2(14, -30), Vector2(14, -30) + Vector2(cos(ang), sin(ang)) * 42.0, Color(2.0, 2.6, 3.4, 0.9), 4.0, true)
			glow.draw_line(Vector2(-4, -50), Vector2(6, -50), Color(3.0, 3.4, 4.0), 2.0)
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func blood_color() -> Color:
	return Color(0, 0, 0, 0)
