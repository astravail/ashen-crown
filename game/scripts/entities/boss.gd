class_name Boss
extends Enemy
## Aldric, the Ember King. Three phases.

var phase := 1
var intro_t := 0.0
var next_attack := 2.0
var attack_i := 0
var throne_pos := Vector2.ZERO
var charge_t := 0.0
var charge_dir := Vector2.ZERO
var cast_anim := 0.0
var light: PointLight2D
var _charge_hits := {}


func setup(k: String, hp_mult: float, dmg_mult: float) -> void:
	super.setup(k, 1.0, dmg_mult)
	is_boss = true
	heavy = true
	max_hp = Data.ENEMIES[k].hp * (1.25 if Game.fragments.has("greed") else 1.0) * (1.0 + 0.0 * hp_mult)
	hp = max_hp
	display_name = Data.ENEMIES[k].name
	scale_mult = 1.0
	attack_range = 90.0


func _ready() -> void:
	super._ready()
	light = world.make_light(Color(1.0, 0.5, 0.2), 1.4, 900.0)
	add_child(light)
	light.position = Vector2(0, -110)
	throne_pos = global_position


func intro() -> void:
	intro_t = 2.6
	Sfx.play("roar", 0.0)
	world.shake(16.0)
	world.banner.emit(display_name, "Nothing stays buried.")
	world.glow_fx.burst(global_position + Vector2(0, -100), 60, Color(3.0, 1.0, 0.25), 100, 500, 1.0, 3.0, Particles.SPARK)


func reset_fight() -> void:
	phase = 1
	sleeping = true
	global_position = throne_pos
	next_attack = 2.0
	charge_t = 0.0


func update(dt: float) -> void:
	anim += dt
	flash = maxf(0.0, flash - dt * 6.0)
	if vuln_t > 0.0:
		vuln_t -= dt
	cast_anim = maxf(0.0, cast_anim - dt)
	light.energy = 1.3 + 0.2 * sin(anim * 5.0)
	queue_redraw()
	glow.queue_redraw()
	if sleeping or dead:
		return
	if intro_t > 0.0:
		intro_t -= dt
		return
	var p := world.player
	if p == null or p.dead:
		return
	var new_phase := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		next_attack = 1.2
		Sfx.play("roar", -2.0, 0.05, 1.0 + phase * 0.05)
		world.shake(14.0)
		world.glow_fx.ring(global_position, 400.0, Color(3.0, 0.9, 0.2, 1.0), 0.8)
		world.area_damage(global_position, 200.0, 0.0001, self, Team.ENEMY, {"knock_force": 600.0})
		world.banner.emit("The crown burns hotter" if phase == 2 else "Aldric remembers the fire", "")
	var to := p.global_position - global_position
	if to.x != 0.0 and charge_t <= 0.0:
		facing = Vector2(signf(to.x), 0)
	if charge_t > 0.0:
		charge_t -= dt
		integrate(dt, charge_dir * 760.0)
		world.glow_fx.emit(global_position + Vector2(randf_range(-30, 30), -20), -charge_dir * 100.0, 0.6, 5.0, Color(3.0, 0.9, 0.2), Particles.EMBER, 1.0)
		if not _charge_hits.has(1) and global_position.distance_to(p.global_position) < radius + p.radius + 10.0:
			_charge_hits[1] = true
			world.damage(p, dmg * 1.4, self, {"type": "fire", "knock": charge_dir * 500.0, "melee": true})
		return
	next_attack -= dt * (1.0 + 0.25 * (phase - 1))
	if next_attack <= 0.0:
		_attack(p)
		return
	if to.length() > 130.0:
		integrate(dt, world.path_dir(global_position, p.global_position) * speed * (1.0 + 0.15 * (phase - 1)))
	else:
		integrate(dt, Vector2.ZERO)
		cd -= dt
		if cd <= 0.0:
			cd = 1.6
			world.spawn_hazard("telegraph", global_position + facing * 50.0, {"radius": 130.0, "delay": 0.7, "dmg": dmg, "team": Team.ENEMY, "src": self, "knock": 420.0})
			cast_anim = 0.7


func _attack(p: Player) -> void:
	var pool := ["volley", "meteors", "sweep", "slam"]
	if phase >= 2:
		pool.append("summon")
	if phase >= 3:
		pool.append("charge")
		pool.append("meteors")
	var a: String = pool[attack_i % pool.size()] if attack_i < pool.size() else pool[randi() % pool.size()]
	attack_i += 1
	cast_anim = 0.8
	match a:
		"volley":
			var n := 14 + phase * 4
			var waves := phase
			for w in waves:
				var off := w * 0.5 * TAU / n
				var tmr := get_tree().create_timer(w * 0.45, false)
				tmr.timeout.connect(_ring.bind(n, off))
			next_attack = 2.6
		"meteors":
			var count := 5 + phase * 2
			for i in count:
				var tp := p.global_position + Vector2(randf_range(-220, 220), randf_range(-220, 220))
				if i == 0:
					tp = p.global_position
				if world.is_floor_at(tp):
					world.spawn_hazard("telegraph", tp, {"radius": 95.0, "delay": 1.1 + i * 0.12, "dmg": dmg * 1.1, "team": Team.ENEMY, "src": self, "sound": "explode", "shake": 6.0, "leave_pool": phase >= 2})
			next_attack = 3.0
		"sweep":
			var base := (p.global_position - global_position).angle()
			var spread := [-0.6, 0.0, 0.6] if phase < 3 else [-0.9, -0.45, 0.0, 0.45, 0.9]
			for s in spread:
				world.spawn_hazard("line", global_position, {"dir": Vector2.from_angle(base + s), "length": 760.0, "width": 70.0, "delay": 1.0, "dmg": dmg * 1.2, "team": Team.ENEMY, "src": self, "leave_pool": phase >= 2})
			next_attack = 2.8
		"slam":
			world.spawn_hazard("telegraph", global_position, {"radius": 210.0, "delay": 1.0, "dmg": dmg * 1.4, "team": Team.ENEMY, "src": self, "knock": 600.0, "sound": "explode", "shake": 12.0})
			next_attack = 2.4
		"summon":
			var alive := 0
			for e in world.enemies:
				if not e.dead and not e.is_boss:
					alive += 1
			if alive < 8:
				for i in 4:
					var ang := TAU * i / 4.0 + randf()
					var sp := world.arena_center + Vector2(cos(ang), sin(ang)) * world.arena_radius * 0.75
					if world.is_floor_at(sp):
						var kind: String = ["husk", "wraith", "hound", "acolyte"][i]
						var e := world.spawn_enemy(kind, sp, true)
						e.pack = -1
						world.smoke_fx.burst(sp, 12, Color(0.2, 0.18, 0.18, 0.8), 30, 120, 1.0, 12, Particles.SMOKE)
			next_attack = 2.0
		"charge":
			charge_dir = (p.global_position - global_position).normalized()
			world.spawn_hazard("line", global_position, {"dir": charge_dir, "length": 620.0, "width": radius * 2.2, "delay": 0.8, "dmg": 0.0001, "team": Team.ENEMY, "src": self})
			var tmr2 := get_tree().create_timer(0.8, false)
			tmr2.timeout.connect(_start_charge)
			next_attack = 2.6


func _ring(n: int, off: float) -> void:
	if dead or world.player == null or world.player.dead:
		return
	for i in n:
		var a := off + TAU * i / n
		world.spawn_projectile("king_orb", global_position + Vector2(0, -60), Vector2.from_angle(a), 260.0 + phase * 30.0, dmg * 0.7, Team.ENEMY, {"src": self})
	Sfx.play("fire_cast", -2.0, 0.05, 0.6)


func _start_charge() -> void:
	if dead:
		return
	charge_t = 0.8
	_charge_hits.clear()
	Sfx.play("roar", -8.0, 0.1, 1.3)


func on_damaged(_amount: float, _src: Actor, _opts: Dictionary) -> void:
	pass


func die(_src: Actor) -> void:
	dead = true
	world.shake(24.0)
	world.hitstop(0.25)
	Sfx.play("roar", 0.0, 0.0, 0.8)
	Sfx.play("explode")
	world.glow_fx.burst(global_position + Vector2(0, -80), 120, Color(3.0, 1.0, 0.25), 100, 700, 1.6, 4.0, Particles.SPARK)
	world.glow_fx.ring(global_position, 500.0, Color(3.0, 1.2, 0.3, 1.0), 1.0)
	world.smoke_fx.burst(global_position, 50, Color(0.25, 0.22, 0.2, 0.9), 40, 260, 2.4, 22, Particles.SMOKE)


func _draw() -> void:
	draw_shadow(1.5)
	var rise := 0.0
	if intro_t > 0.0:
		rise = intro_t / 2.6
	draw_set_transform(Vector2(0, -rise * 10.0), 0.0, Vector2(facing.x, 1.0))
	var cloak := shade(Color(0.15, 0.06, 0.05))
	var armor := shade(Color(0.25, 0.21, 0.2))
	var dark := shade(Color(0.11, 0.09, 0.09))
	var walk := sin(anim * 6.0) if charge_t > 0.0 or not sleeping else 0.0
	var wave := sin(anim * 2.2) * 3.0
	# The royal cloak: burnt to rags, still dragging behind him
	Ink.shape(self, PackedVector2Array([Vector2(-22, -110), Vector2(22, -110), Vector2(44, -40), Vector2(48 + wave, -4), Vector2(34, -14), Vector2(24 + wave, 2), Vector2(10, -12),
		Vector2(-4 - wave, 4), Vector2(-18, -10), Vector2(-32 - wave, 2), Vector2(-40, -14), Vector2(-52 + wave, -6), Vector2(-46, -44)]), cloak.lightened(0.1), cloak.darkened(0.6), 2.6)
	Ink.limb(self, Vector2(-14, -42), Vector2(-14 + walk * 8.0, 0), 15.0, 11.0, dark.lightened(0.12), dark.darkened(0.3), 2.2)
	Ink.limb(self, Vector2(14, -42), Vector2(14 - walk * 8.0, 0), 15.0, 11.0, dark.lightened(0.12), dark.darkened(0.3), 2.2)
	Ink.limb(self, Vector2(-34, -100), Vector2(-46, -60), 13.0, 11.0, armor, armor.darkened(0.45), 2.2)
	var torso := PackedVector2Array([Vector2(-24, -40), Vector2(24, -40), Vector2(30, -66), Vector2(36, -108), Vector2(-36, -108), Vector2(-30, -66)])
	Ink.shape(self, torso, armor.lightened(0.14), armor.darkened(0.55), 2.6)
	# Plates of the cuirass, and what is left of a king's tabard
	draw_line(Vector2(-31, -72), Vector2(31, -72), Color(0.04, 0.03, 0.03, 0.8), 1.8, true)
	draw_line(Vector2(-27, -54), Vector2(27, -54), Color(0.04, 0.03, 0.03, 0.8), 1.8, true)
	Ink.shape(self, PackedVector2Array([Vector2(-9, -44), Vector2(9, -44), Vector2(7, -22), Vector2(2, -28), Vector2(-3, -18), Vector2(-8, -26)]), cloak.lightened(0.25), cloak.darkened(0.3), 1.8)
	draw_line(Vector2(-26, -42), Vector2(26, -42), shade(Color(0.4, 0.3, 0.14)), 4.0, true)
	for sgn in [-1.0, 1.0]:
		# Pauldrons, each crowned with a spike
		Ink.oval(self, Vector2(sgn * 36.0, -106), 17.0, 14.0, armor.lightened(0.22), armor.darkened(0.4), 2.4)
		Ink.shape(self, PackedVector2Array([Vector2(sgn * 30.0, -116), Vector2(sgn * 48.0, -138), Vector2(sgn * 44.0, -112)]), armor.lightened(0.1), dark, 1.8)
	Ink.rim(self, torso, Vector2(-0.7, -0.7), Color(0.9, 0.5, 0.25, 0.4), 1.8)
	# A helm with no face behind it
	Ink.shape(self, PackedVector2Array([Vector2(-14, -108), Vector2(14, -108), Vector2(15, -134), Vector2(10, -146), Vector2(-10, -146), Vector2(-15, -134)]), dark.lightened(0.22), dark.darkened(0.2), 2.4)
	draw_line(Vector2(0, -144), Vector2(0, -112), Color(0.03, 0.025, 0.025, 0.9), 1.8, true)
	draw_line(Vector2(-11, -130), Vector2(13, -130), Color(0.02, 0.015, 0.015), 4.5, true)
	var up := cast_anim > 0.0
	var hand := Vector2(44, -70) if not up else Vector2(30, -150)
	Ink.limb(self, Vector2(34, -100), hand, 13.0, 11.0, armor.lightened(0.1), armor.darkened(0.4), 2.2)
	Ink.oval(self, hand, 8.5, 8.0, dark.lightened(0.2), dark, 2.0)
	# The blade itself is black iron: the fire on it is drawn by the glow layer
	var tip := hand + (Vector2(40, 70) if not up else Vector2(10, -90))
	var edge := (tip - hand).orthogonal().normalized() * 4.0
	Ink.shape(self, PackedVector2Array([hand + edge, tip, hand - edge]), dark.lightened(0.1), dark.darkened(0.4), 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	var rise := intro_t / 2.6 if intro_t > 0.0 else 0.0
	glow.draw_set_transform(Vector2(0, -rise * 10.0), 0.0, Vector2(facing.x, 1.0))
	var heat := 1.0 + 0.4 * (phase - 1)
	var flick := 0.85 + 0.15 * sin(anim * 9.0)
	# Burning crown
	var crown := PackedVector2Array([Vector2(-18, -146), Vector2(-20, -166), Vector2(-10, -156), Vector2(0, -172), Vector2(10, -156), Vector2(20, -166), Vector2(18, -146)])
	glow.draw_colored_polygon(crown, Color(3.0 * heat, 1.3, 0.35))
	for i in 3:
		var x := -12.0 + i * 12.0
		var h := (18.0 + 10.0 * sin(anim * 7.0 + i)) * heat
		Ink.flame(glow, Vector2(x, -158), 6.5, h, anim, float(i) * 2.1, Color(3.0, 1.1, 0.25, 0.8 * flick), Color(2.4, 0.5, 0.1, 0.6 * flick))
	Ink.glow(glow, Vector2(0, -160), 70.0, Color(1.6, 0.45, 0.1, 0.4 * heat))
	glow.draw_line(Vector2(-8, -130), Vector2(-2, -130), Color(4.0, 1.6, 0.4), 3.0)
	glow.draw_line(Vector2(4, -130), Vector2(10, -130), Color(4.0, 1.6, 0.4), 3.0)
	# Cracks in the armour
	glow.draw_polyline(PackedVector2Array([Vector2(-10, -46), Vector2(-4, -70), Vector2(-12, -90), Vector2(-2, -108)]), Color(2.8, 0.8, 0.2, 0.8 * flick), 2.0, true)
	glow.draw_polyline(PackedVector2Array([Vector2(14, -50), Vector2(8, -78), Vector2(16, -100)]), Color(2.8, 0.8, 0.2, 0.7 * flick), 2.0, true)
	# Fire sword
	var up := cast_anim > 0.0
	var hand := Vector2(44, -70) if not up else Vector2(30, -150)
	var tip := hand + (Vector2(40, 70) if not up else Vector2(10, -90))
	var edge := (tip - hand).orthogonal().normalized()
	glow.draw_primitive(PackedVector2Array([hand + edge * 9.0, tip, hand - edge * 9.0]), PackedColorArray([Color(1.6, 0.4, 0.1, 0.25), Color(1.6, 0.4, 0.1, 0.0), Color(1.6, 0.4, 0.1, 0.25)]), PackedVector2Array())
	glow.draw_primitive(PackedVector2Array([hand + edge * 3.0, tip, hand - edge * 3.0]), PackedColorArray([Color(3.4, 1.4, 0.4), Color(3.0, 0.8, 0.2, 0.7), Color(3.4, 1.4, 0.4)]), PackedVector2Array())
	for i in 4:
		var fp := hand.lerp(tip, 0.15 + i * 0.22)
		Ink.flame(glow, fp, 5.0, 16.0, anim, float(i) * 1.7, Color(3.0, 1.0, 0.25, 0.7 * flick), Color(2.2, 0.5, 0.1, 0.5))
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
