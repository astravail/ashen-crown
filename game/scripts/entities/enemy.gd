class_name Enemy
extends Actor
## Ash-bound creatures. Behaviour and look branch on `kind`.

var kind := "husk"
var display_name := ""
var speed := 80.0
var dmg := 10.0
var xp := 3
var attack_range := 34.0
var windup := 0.4
var attack_cd := 1.2
var sleeping := true
var pack := -1
var elite := false
var is_champion := false
var is_boss := false
var affix := ""
var scale_mult := 1.0
var target: Actor
var state := "idle"
var state_t := 0.0
var cd := 0.0
var lunge_dir := Vector2.ZERO
var lunge_hit := false
var _retarget := 0.0
var _special := 0.0
var _pool_t := 0.0
var show_bar_t := 0.0
var _seed := 0.0
var home := Vector2.ZERO
var exploded := false
var variant := ""
var zone_idx := 0
var region := 0
var tint := Color.WHITE
var emerge_t := 0.0
var wander_dir := Vector2.ZERO
var _wander_t := 0.0


func setup(k: String, hp_mult: float, dmg_mult: float) -> void:
	var d: Dictionary = Data.enemy_def(k)
	variant = k
	kind = d.get("arch", k)
	tint = d.get("tint", Color.WHITE)
	display_name = d.name
	max_hp = float(d.hp) * hp_mult
	hp = max_hp
	speed = d.speed * randf_range(0.92, 1.08)
	dmg = d.dmg * dmg_mult
	radius = d.radius
	xp = d.xp
	attack_range = d.range
	windup = d.windup
	attack_cd = d.cd
	heavy = kind == "brute"
	_seed = randf() * 100.0
	cd = randf_range(0.2, 1.0)
	anim = randf() * 10.0


func make_elite() -> void:
	elite = true
	affix = ["Molten", "Swift", "Frenzied"][randi() % 3]
	max_hp *= 3.4
	hp = max_hp
	dmg *= 1.3
	scale_mult = 1.25
	radius *= 1.25
	xp *= 4
	if affix == "Swift":
		speed *= 1.4
	if affix == "Frenzied":
		attack_cd *= 0.5
		windup *= 0.8
	display_name = "%s %s" % [affix, display_name]


func make_champion(n: String, s: float) -> void:
	is_champion = true
	elite = true
	affix = "Molten"
	display_name = n
	max_hp *= 9.0 if kind != "brute" else 5.5
	hp = max_hp
	dmg *= 1.5
	scale_mult = s
	radius *= s
	xp *= 12
	heavy = true
	sleeping = true


func wake() -> void:
	if sleeping:
		sleeping = false
		state = "chase"
		home = global_position


func drop_aggro() -> void:
	sleeping = true
	state = "idle"
	target = null


# ---------------------------------------------------------------- update

func update(dt: float) -> void:
	anim += dt
	tick_status(dt)
	show_bar_t = maxf(0.0, show_bar_t - dt)
	if dead:
		return
	if emerge_t > 0.0:
		_update_emerge(dt)
		return
	if sleeping:
		_wander(dt)
		queue_redraw()
		glow.queue_redraw()
		return
	cd -= dt
	_retarget -= dt
	if _retarget <= 0.0 or not is_instance_valid(target) or target.dead:
		_retarget = 0.5
		target = world.nearest_ally(global_position, 1500.0)
		if target == null and world.player and not world.player.dead and world.player.global_position.distance_to(global_position) > 1100.0:
			drop_aggro()
	if affix == "Molten":
		_pool_t -= dt
		if _pool_t <= 0.0 and state == "chase":
			_pool_t = 1.6 if not is_champion else 1.0
			world.spawn_hazard("fire_pool", global_position, {"radius": 30.0 * scale_mult, "duration": 4.0, "dps": dmg * 0.6, "team": Team.ENEMY, "src": self})
	if is_stunned():
		state = "chase" if state != "lunge" else "chase"
		integrate(dt, Vector2.ZERO)
		queue_redraw()
		glow.queue_redraw()
		return
	if not is_instance_valid(target) or target.dead:
		target = null
		integrate(dt, Vector2.ZERO)
	else:
		_think(dt)
	queue_redraw()
	glow.queue_redraw()


## Unaware enemies mill about near where they stand instead of freezing.
func _wander(dt: float) -> void:
	if is_champion or pack == 999 or pack < 0:
		integrate(dt, Vector2.ZERO)
		return
	if home == Vector2.ZERO:
		home = global_position
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 4.5)
		wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.55 else Vector2.ZERO
	if global_position.distance_to(home) > 150.0:
		wander_dir = (home - global_position).normalized()
	if wander_dir.x != 0.0:
		facing = Vector2(signf(wander_dir.x), 0)
	integrate(dt, wander_dir * speed * 0.28)


## Rising out of the ground: harmless and untargetable until it is up.
func start_emerge() -> void:
	emerge_t = 0.9
	sleeping = false
	state = "chase"
	home = global_position
	scale = Vector2(1.0, 0.2)
	modulate.a = 0.0


func _update_emerge(dt: float) -> void:
	emerge_t -= dt
	var k := clampf(1.0 - emerge_t / 0.9, 0.0, 1.0)
	scale = Vector2(1.0, lerpf(0.2, 1.0, k))
	modulate.a = clampf(k * 2.5, 0.0, 1.0)
	if randf() < dt * 22.0:
		world.smoke_fx.burst(global_position, 2, Color(0.28, 0.2, 0.14, 0.9), 30, 120, 0.7, 5.0, Particles.DEBRIS, TAU, 0.0, 3.0, 260.0)
	if emerge_t <= 0.0:
		scale = Vector2.ONE
		modulate.a = 1.0
		world.shake(2.0)
	queue_redraw()
	glow.queue_redraw()


func _think(dt: float) -> void:
	var tp := target.global_position
	var to := tp - global_position
	var dist := to.length()
	if to.x != 0.0 and state != "lunge":
		facing = Vector2(signf(to.x), 0)
	if is_champion:
		_special -= dt
		if _special <= 0.0 and dist < 600.0:
			_special = 6.5
			_champion_special()
	match state:
		"chase":
			var want := attack_range + target.radius
			if kind == "acolyte":
				var los := world.los(global_position, tp)
				if dist < 220.0 and los:
					integrate(dt, -to.normalized() * speed * 0.8 * move_speed_mult())
				elif dist > attack_range or not los:
					integrate(dt, world.path_dir(global_position, tp) * speed * move_speed_mult())
				else:
					integrate(dt, Vector2.ZERO)
				if dist < attack_range + 40.0 and los and cd <= 0.0:
					_begin_windup()
				return
			if kind == "wraith" and dist > 240.0 and cd <= 0.0 and randf() < dt * 0.8:
				_blink(tp)
				return
			if kind == "hound" and dist < want and dist > 60.0 and cd <= 0.0 and world.los(global_position, tp):
				_begin_windup()
				return
			if dist <= want and cd <= 0.0 and kind != "hound":
				_begin_windup()
				return
			if kind == "hound" and dist <= 60.0 and cd <= 0.0:
				_begin_windup()
				return
			var mv := world.path_dir(global_position, tp)
			var spd := speed * move_speed_mult()
			if dist < want * 0.85:
				spd = 0.0
			integrate(dt, mv * spd)
		"windup":
			state_t -= dt
			integrate(dt, Vector2.ZERO)
			if kind == "hound":
				lunge_dir = (tp - global_position).normalized() if state_t > windup * 0.35 else lunge_dir
			if state_t <= 0.0:
				_strike(tp)
		"lunge":
			state_t -= dt
			integrate(dt, lunge_dir * 720.0)
			if not lunge_hit and target and global_position.distance_to(target.global_position) < radius + target.radius + 8.0:
				lunge_hit = true
				world.damage(target, dmg, self, {"type": "phys", "knock": lunge_dir * 220.0, "melee": true})
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.5
		"recover":
			state_t -= dt
			integrate(dt, Vector2.ZERO)
			if state_t <= 0.0:
				state = "chase"


func _begin_windup() -> void:
	state = "windup"
	state_t = windup
	match kind:
		"brute":
			var hz := world.spawn_hazard("telegraph", global_position + facing * 20.0, {"radius": 100.0 * scale_mult, "delay": windup, "dmg": dmg, "team": Team.ENEMY, "src": self, "knock": 360.0, "sound": "slam", "leave_pool": is_champion})
			hz.color = Color(2.4, 0.5, 0.12)
		"bloater":
			world.spawn_hazard("telegraph", global_position, {"radius": 115.0 * scale_mult, "delay": windup, "dmg": dmg, "team": Team.ENEMY, "src": self, "color": Color(0.8, 1.8, 0.4), "sound": "explode", "leave_poison": true})
		"hound":
			lunge_dir = (target.global_position - global_position).normalized()


func _strike(tp: Vector2) -> void:
	cd = attack_cd * randf_range(0.85, 1.15)
	match kind:
		"husk", "wraith":
			state = "recover"
			state_t = 0.35
			if target and global_position.distance_to(target.global_position) < attack_range + target.radius + 22.0:
				world.damage(target, dmg, self, {"type": "phys", "knock": (target.global_position - global_position).normalized() * 160.0, "melee": true})
				Sfx.play("hit", -10.0, 0.1, 0.7)
			else:
				Sfx.play("swing", -12.0, 0.1, 0.8)
		"hound":
			state = "lunge"
			state_t = 0.26
			lunge_hit = false
			Sfx.play("dodge", -12.0, 0.1, 1.3)
		"acolyte":
			state = "recover"
			state_t = 0.3
			var dir := (tp - global_position).normalized()
			world.spawn_projectile("fireball", global_position + dir * 20.0 + Vector2(0, -26), dir, 340.0, dmg, Team.ENEMY, {"src": self})
			if elite:
				for a in [-0.25, 0.25]:
					world.spawn_projectile("fireball", global_position + Vector2(0, -26), dir.rotated(a), 340.0, dmg, Team.ENEMY, {"src": self})
			Sfx.play("fire_cast", -12.0, 0.1, 0.9)
		"brute":
			state = "recover"
			state_t = 0.8
		"bloater":
			exploded = true
			hp = 0.0
			world._kill(self, null)


func _blink(tp: Vector2) -> void:
	cd = 3.5
	var behind := tp + (tp - global_position).normalized() * 70.0
	if not world.is_floor_at(behind) or not world.los(tp, behind):
		behind = tp + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		if not world.is_floor_at(behind):
			return
	world.smoke_fx.burst(global_position, 10, Color(0.2, 0.2, 0.22, 0.8), 30, 120, 0.8, 9, Particles.SMOKE)
	global_position = behind
	world.smoke_fx.burst(global_position, 10, Color(0.2, 0.2, 0.22, 0.8), 30, 120, 0.8, 9, Particles.SMOKE)
	Sfx.play("teleport", -12.0, 0.1, 0.7)
	state = "windup"
	state_t = windup + 0.15


func _champion_special() -> void:
	var tp := target.global_position
	for i in 4:
		var p := tp + Vector2(randf_range(-140, 140), randf_range(-140, 140))
		if i == 0:
			p = tp
		if world.is_floor_at(p):
			world.spawn_hazard("telegraph", p, {"radius": 80.0, "delay": 1.0 + i * 0.15, "dmg": dmg * 0.9, "team": Team.ENEMY, "src": self, "sound": "explode_small", "shake": 4.0})


func on_damaged(_amount: float, src: Actor, _opts: Dictionary) -> void:
	show_bar_t = 4.0
	if src and src != target and randf() < 0.3:
		target = src


func die(_src: Actor) -> void:
	dead = true
	if kind == "bloater" and not exploded:
		world.spawn_hazard("telegraph", global_position, {"radius": 110.0 * scale_mult, "delay": 0.3, "dmg": dmg * 0.8, "team": Team.ENEMY, "src": null, "color": Color(0.8, 1.8, 0.4), "sound": "explode_small", "leave_poison": true})


func blood_color() -> Color:
	match kind:
		"wraith": return Color(0, 0, 0, 0)
		"bloater": return Color(0.32, 0.36, 0.06)
		"ember_king": return Color(0.55, 0.1, 0.02)
	return Color(0.42, 0.02, 0.03)


# ---------------------------------------------------------------- drawing

func body_color(base: Color) -> Color:
	var c := base
	if tint != Color.WHITE:
		c = Color(clampf(c.r * tint.r + (tint.r - 1.0) * 0.06, 0.0, 2.0), clampf(c.g * tint.g + (tint.g - 1.0) * 0.06, 0.0, 2.0), clampf(c.b * tint.b + (tint.b - 1.0) * 0.06, 0.0, 2.0), c.a)
	if state == "windup":
		c = c.lerp(Color(0.5, 0.15, 0.08), 0.35 + 0.25 * sin(anim * 30.0))
	return shade(c)


func _draw() -> void:
	draw_shadow(1.0)
	var s := scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing.x * s, s))
	var walk := sin(anim * (speed / 9.0)) if (state == "chase" and not sleeping and not is_stunned()) or (sleeping and wander_dir != Vector2.ZERO) else 0.0
	match kind:
		"husk": _draw_husk(walk)
		"hound": _draw_hound(walk)
		"acolyte": _draw_acolyte(walk)
		"brute": _draw_brute(walk)
		"bloater": _draw_bloater(walk)
		"wraith": _draw_wraith()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_status_marks()
	_draw_bar()


func _draw_bar() -> void:
	if is_boss:
		return
	var show := elite or show_bar_t > 0.0
	if not show or hp >= max_hp and not elite:
		return
	var w := 46.0 if not elite else 80.0
	var top := -radius * 3.4 - (16.0 if elite else 0.0)
	draw_rect(Rect2(-w * 0.5 - 1, top - 1, w + 2, 6), Color(0, 0, 0, 0.7))
	var col := Color(0.75, 0.16, 0.1) if not elite else Color(0.95, 0.55, 0.15)
	draw_rect(Rect2(-w * 0.5, top, w * hp / max_hp, 4), col)
	if elite:
		var f := Game.font_display
		var fs := 13 if not is_champion else 15
		var tw := f.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(-tw * 0.5, top - 6), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-tw * 0.5, top - 6), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.75, 0.4))


func _draw_husk(walk: float) -> void:
	var c := body_color(Color(0.16, 0.14, 0.13))
	var lean := 6.0 if state == "windup" else 0.0
	draw_line(Vector2(-5, -14), Vector2(-5 + walk * 5.0, 0), c, 5.0, true)
	draw_line(Vector2(5, -14), Vector2(5 - walk * 5.0, 0), c, 5.0, true)
	var body := PackedVector2Array([Vector2(-10, -12), Vector2(9, -12), Vector2(14 - lean, -34), Vector2(2 - lean, -40), Vector2(-9, -32)])
	draw_colored_polygon(body, c)
	draw_circle(Vector2(10 - lean, -40), 7.0, c, true, -1.0, true)
	var arm := Vector2(20, -12) if state != "windup" else Vector2(2, -46)
	draw_line(Vector2(8 - lean, -32), arm, c, 4.0, true)
	draw_line(Vector2(-6, -30), Vector2(-12 + walk * 3.0, -12), c, 4.0, true)


func _draw_hound(walk: float) -> void:
	var c := body_color(Color(0.13, 0.11, 0.1))
	for i in 4:
		var x := -12.0 + i * 8.0
		var ph := walk * (1.0 if i % 2 == 0 else -1.0)
		draw_line(Vector2(x, -10), Vector2(x + ph * 6.0, 0), c, 3.5, true)
	draw_set_transform(Vector2(0, -14) * scale_mult, 0.0, Vector2(facing.x * scale_mult, scale_mult))
	var body := PackedVector2Array([Vector2(-20, 0), Vector2(-8, -8), Vector2(12, -7), Vector2(18, 0), Vector2(10, 5), Vector2(-14, 5)])
	draw_colored_polygon(body, c)
	var head := PackedVector2Array([Vector2(12, -8), Vector2(28, -4), Vector2(30, 2), Vector2(14, 3)])
	draw_colored_polygon(head, c)
	draw_colored_polygon(PackedVector2Array([Vector2(14, -8), Vector2(17, -15), Vector2(19, -6)]), c)
	draw_line(Vector2(-20, -1), Vector2(-30, -8 + walk * 3.0), c, 3.0, true)


func _draw_acolyte(walk: float) -> void:
	var c := body_color(Color(0.2, 0.1, 0.07))
	var sw := walk * 2.0
	var body := PackedVector2Array([Vector2(-14 + sw, 0), Vector2(14 + sw, 0), Vector2(8, -30), Vector2(0, -46), Vector2(-8, -30)])
	draw_colored_polygon(body, c)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -30), Vector2(8, -30), Vector2(3, -50), Vector2(-6, -44)]), shade(Color(0.13, 0.07, 0.05)))
	draw_circle(Vector2(3, -38), 5.0, shade(Color(0.02, 0.01, 0.01)), true, -1.0, true)
	draw_line(Vector2(4, -28), Vector2(16, -24), c, 4.0, true)


func _draw_brute(walk: float) -> void:
	var c := body_color(Color(0.19, 0.18, 0.19))
	var dark := body_color(Color(0.1, 0.09, 0.09))
	draw_line(Vector2(-9, -20), Vector2(-9 + walk * 6.0, 0), dark, 9.0, true)
	draw_line(Vector2(9, -20), Vector2(9 - walk * 6.0, 0), dark, 9.0, true)
	var body := PackedVector2Array([Vector2(-18, -18), Vector2(18, -18), Vector2(24, -54), Vector2(-24, -54)])
	draw_colored_polygon(body, c)
	draw_circle(Vector2(-24, -52), 12.0, c, true, -1.0, true)
	draw_circle(Vector2(24, -52), 12.0, c, true, -1.0, true)
	draw_rect(Rect2(-10, -76, 20, 22), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -72), Vector2(-22, -88), Vector2(-8, -78)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -72), Vector2(22, -88), Vector2(8, -78)]), dark)
	var raise := state == "windup"
	var hand := Vector2(30, -40) if not raise else Vector2(10, -80)
	var head := hand + (Vector2(16, 26) if not raise else Vector2(6, -28))
	draw_line(Vector2(20, -50), hand, c, 7.0, true)
	draw_line(hand, head, Color(0.3, 0.26, 0.22), 5.0, true)
	draw_rect(Rect2(head - Vector2(11, 8), Vector2(22, 16)), dark)


func _draw_bloater(walk: float) -> void:
	var c := body_color(Color(0.25, 0.27, 0.2))
	var swell := 1.0 + 0.04 * sin(anim * 4.0) + (0.12 * (1.0 - state_t / windup) if state == "windup" else 0.0)
	draw_line(Vector2(-8, -8), Vector2(-8 + walk * 4.0, 0), c, 4.0, true)
	draw_line(Vector2(8, -8), Vector2(8 - walk * 4.0, 0), c, 4.0, true)
	draw_circle(Vector2(0, -26), 20.0 * swell, c, true, -1.0, true)
	draw_circle(Vector2(-5, -30), 13.0 * swell, c.lightened(0.08), true, -1.0, true)
	draw_circle(Vector2(12, -46), 7.0, c.darkened(0.2), true, -1.0, true)


func _draw_wraith() -> void:
	var c := shade(Color(0.12, 0.11, 0.13, 0.85))
	var fl := sin(anim * 3.0) * 4.0
	var pts := PackedVector2Array([Vector2(-14, -18 + fl), Vector2(-6, -6 + fl), Vector2(0, -14 + fl), Vector2(7, -4 + fl), Vector2(14, -16 + fl), Vector2(10, -40 + fl), Vector2(0, -52 + fl), Vector2(-10, -40 + fl)])
	draw_colored_polygon(pts, c)
	var arm := Vector2(22, -30 + fl) if state != "windup" else Vector2(10, -58 + fl)
	draw_line(Vector2(6, -36 + fl), arm, c, 3.0, true)
	if randf() < 0.3 and world:
		world.smoke_fx.emit(global_position + Vector2(randf_range(-10, 10), -10), Vector2(0, -20), 0.8, 7.0, Color(0.15, 0.14, 0.16, 0.5), Particles.SMOKE, 1.0)


func _draw_glow() -> void:
	if petrify:
		return
	var s := scale_mult
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing.x * s, s))
	var wind := state == "windup"
	var hot := Color(3.0, 1.0, 0.25) if not wind else Color(4.0, 1.6, 0.5)
	match kind:
		"husk":
			var lean := 6.0 if wind else 0.0
			glow.draw_circle(Vector2(13 - lean, -41), 1.6, hot, true, -1.0, true)
			glow.draw_line(Vector2(-4, -16), Vector2(2, -30), Color(2.4, 0.7, 0.15, 0.8), 1.5)
			glow.draw_line(Vector2(2, -30), Vector2(8 - lean, -34), Color(2.4, 0.7, 0.15, 0.8), 1.5)
		"hound":
			for i in 4:
				glow.draw_circle(Vector2(-14 + i * 7, -21), 2.2, Color(3.0, 0.8, 0.2, 0.9), true, -1.0, true)
			glow.draw_circle(Vector2(24, -11), 1.8, hot, true, -1.0, true)
		"acolyte":
			var orb := Vector2(18, -24)
			var r := 5.0 + (5.0 * (1.0 - state_t / windup) if wind else 0.0)
			glow.draw_circle(orb, r * 2.2, Color(1.6, 0.45, 0.1, 0.3), true, -1.0, true)
			glow.draw_circle(orb, r, Color(3.4, 1.2, 0.3), true, -1.0, true)
			glow.draw_circle(Vector2(5, -39), 1.4, hot, true, -1.0, true)
		"brute":
			glow.draw_line(Vector2(-6, -68), Vector2(6, -68), hot, 2.5)
			if is_champion:
				glow.draw_line(Vector2(-14, -30), Vector2(10, -48), Color(2.6, 0.7, 0.15, 0.8), 2.0)
		"bloater":
			for p in [Vector2(-10, -20), Vector2(8, -32), Vector2(4, -14), Vector2(-4, -38)]:
				glow.draw_circle(p, 3.0, Color(1.2, 2.4, 0.5, 0.9), true, -1.0, true)
			glow.draw_circle(Vector2(14, -47), 1.4, Color(2.0, 2.6, 0.6), true, -1.0, true)
		"wraith":
			var fl := sin(anim * 3.0) * 4.0
			glow.draw_circle(Vector2(-1, -42 + fl), 1.8, Color(3.0, 0.6, 0.2), true, -1.0, true)
			glow.draw_circle(Vector2(5, -42 + fl), 1.8, Color(3.0, 0.6, 0.2), true, -1.0, true)
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if elite:
		var col := Color(2.0, 0.9, 0.25, 0.35) if affix != "Swift" else Color(1.0, 1.6, 2.4, 0.35)
		if affix == "Frenzied":
			col = Color(2.6, 0.3, 0.2, 0.35)
		glow.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		glow.draw_arc(Vector2.ZERO, radius * 1.6, 0.0, TAU, 40, col, 3.0, true)
		glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_stunned() and not petrify:
		for i in 3:
			var a := anim * 5.0 + i * TAU / 3.0
			glow.draw_circle(Vector2(cos(a) * 12.0, -radius * 3.2 * scale_mult + sin(a) * 4.0), 2.0, Color(2.5, 2.2, 1.5), true, -1.0, true)
