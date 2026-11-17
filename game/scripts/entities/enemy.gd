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
## How enemies move like individuals rather than like magnets: a steering vector that turns gradually,
## a side they circle toward, a boldness of their own, and a rest between retreats.
var _steer := Vector2.ZERO
var _orbit := 1.0
var _bold := 1.0
var _retreat_cd := 0.0
var fear_t := 0.0
var proc_icd := 0.0


func setup(k: String, hp_mult: float, dmg_mult: float) -> void:
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_bold = randf_range(0.7, 1.3)
	_retreat_cd = randf_range(0.0, 3.0)
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
	_retreat_cd -= dt
	proc_icd = maxf(0.0, proc_icd - dt)
	if fear_t > 0.0 and not is_stunned() and world.player:
		# terrified: runs from the hero, blind to everything else
		fear_t -= dt
		var away := (global_position - world.player.global_position).normalized()
		_steer = _steer.lerp(away, clampf(dt * 8.0, 0.0, 1.0))
		if away.x != 0.0:
			facing = Vector2(signf(away.x), 0)
		integrate(dt, _steer * speed * 0.95 * move_speed_mult())
		state = "chase"
		queue_redraw()
		glow.queue_redraw()
		return
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
			# a walk that has a rhythm to it, not a constant slide toward the target
			var spd := speed * move_speed_mult() * (0.86 + 0.22 * sin(anim * 1.7 + _seed * 3.0))
			if dist < want * 0.85:
				spd = 0.0
			elif _melee_kind() and dist < want * 3.2 and cd > 0.0 and randf() < dt * 0.35 * _bold:
				# close but not striking yet: size the target up from the side for a moment
				state = "circle"
				state_t = randf_range(0.9, 2.0)
				return
			_steer = _steer.lerp(mv, clampf(dt * 5.0, 0.0, 1.0))
			integrate(dt, _steer * spd)
		"retreat":
			state_t -= dt
			var back := (-to.normalized()).rotated(0.5 * _orbit)
			_steer = _steer.lerp(back, clampf(dt * 6.0, 0.0, 1.0))
			integrate(dt, _steer * speed * 0.8 * move_speed_mult())
			if state_t <= 0.0:
				# after backing off they often circle a while before coming back in
				if randf() < 0.55:
					state = "circle"
					state_t = randf_range(1.0, 2.2)
				else:
					state = "chase"
		"circle":
			state_t -= dt
			var want2 := (attack_range + target.radius) * 2.2
			var side := to.orthogonal().normalized() * _orbit
			var radial := to.normalized() * clampf((dist - want2) / 80.0, -1.0, 1.0)
			var dirv := (side * 0.9 + radial * 0.6).normalized()
			_steer = _steer.lerp(dirv, clampf(dt * 5.0, 0.0, 1.0))
			integrate(dt, _steer * speed * 0.62 * move_speed_mult())
			if state_t <= 0.0 or world.nearest_ally(global_position, 120.0) == null and dist > 380.0:
				state = "chase"
				_orbit = -_orbit if randf() < 0.4 else _orbit
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
				# not every attack is followed by another: sometimes they fall back and look for an opening
				if _melee_kind() and _retreat_cd <= 0.0 and randf() < 0.3:
					state = "retreat"
					state_t = randf_range(0.6, 1.3)
					_retreat_cd = randf_range(5.0, 9.0)


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


func _melee_kind() -> bool:
	return not is_boss and kind in ["husk", "brute", "hound"]


func on_damaged(_amount: float, src: Actor, _opts: Dictionary) -> void:
	show_bar_t = 4.0
	# now and then a struck enemy gives ground instead of pressing on
	if _melee_kind() and _retreat_cd <= 0.0 and state in ["chase", "recover", "circle"] and randf() < (0.14 if not is_champion else 0.06):
		state = "retreat"
		state_t = randf_range(0.5, 1.0)
		_retreat_cd = randf_range(6.0, 10.0)
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
	draw_shadow(scale_mult)
	_find_rim()
	var s := scale_mult
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing.x * s, s))
	var walk := sin(anim * (speed / 9.0)) if (state in ["chase", "retreat", "circle"] and not sleeping and not is_stunned()) or (sleeping and wander_dir != Vector2.ZERO) else 0.0
	match kind:
		"husk": _draw_husk(walk)
		"hound": _draw_hound(walk)
		"acolyte": _draw_acolyte(walk)
		"brute": _draw_brute(walk)
		"bloater": _draw_bloater(walk)
		"wraith": _draw_wraith()
	EnemyLooks.draw(self, walk)
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


## The warm edge a figure takes from the player's torch. Set once per redraw by _find_rim.
const RIM := Color(1.0, 0.64, 0.34)
var _rim_v := Vector2(-0.6, -0.8)
var _rim_a := 0.0


func _find_rim() -> void:
	_rim_a = 0.0
	if world == null or world.player == null or world.player.dead:
		return
	var d := world.player.global_position + Vector2(0, -24) - global_position
	var l := d.length()
	_rim_a = clampf(1.0 - l / 640.0, 0.0, 1.0) * 0.55
	if l > 1.0:
		_rim_v = Vector2(d.x / l * facing.x, d.y / l)


## One piece of a body: shaded, inked, and lit along whichever edge faces the torch.
func _part(pts: PackedVector2Array, c: Color, lit := true, w := 2.0) -> void:
	Ink.shape(self, pts, c.lightened(0.14), c.darkened(0.5), w)
	if lit and _rim_a > 0.03:
		Ink.rim(self, pts, _rim_v, Color(RIM.r, RIM.g, RIM.b, _rim_a), 1.6)


func _draw_husk(walk: float) -> void:
	var c := body_color(Color(0.21, 0.18, 0.165))
	var dk := c.darkened(0.35)
	var wind := state == "windup"
	var lean := 6.0 if wind else 0.0
	var bob := absf(walk) * 1.5
	Ink.limb(self, Vector2(-4, -15), Vector2(-6 - walk * 6.0, 0), 6.5, 4.0, dk, dk.darkened(0.4), 1.6)
	Ink.limb(self, Vector2(-5, -31 + bob), Vector2(-13 + walk * 4.0, -11), 4.5, 3.0, dk, dk.darkened(0.4), 1.6)
	Ink.limb(self, Vector2(5, -15), Vector2(6 + walk * 6.0, 0), 6.5, 4.0, c, c.darkened(0.5), 1.6)
	# what is left of a shift, hanging off the hips
	_part(PackedVector2Array([Vector2(-10, -17 + bob), Vector2(9, -17 + bob), Vector2(11, -6), Vector2(5, -10), Vector2(1, -4), Vector2(-4, -9), Vector2(-9, -5)]), dk, false, 1.6)
	var torso := PackedVector2Array([Vector2(-10, -14 + bob), Vector2(9, -14 + bob), Vector2(15 - lean, -32 + bob), Vector2(8 - lean, -41 + bob), Vector2(-3, -42 + bob), Vector2(-11, -34 + bob), Vector2(-12, -24 + bob)])
	_part(torso, c)
	var rib := Color(dk.r * 0.45, dk.g * 0.45, dk.b * 0.45, 0.85)
	for i in 3:
		draw_line(Vector2(1 - lean * 0.4, -31 + i * 5.0 + bob), Vector2(10 - lean * 0.6, -29 + i * 5.0 + bob), rib, 1.3, true)
	var hp := Vector2(10 - lean, -41 + bob)
	Ink.oval(self, hp + Vector2(2, 5.5), 4.5, 4.0, dk, dk.darkened(0.4), 1.5)
	Ink.oval(self, hp, 7.5, 7.0, c.lightened(0.12), c.darkened(0.3), 2.0)
	Ink.dot(self, hp + Vector2(3, -1), 2.2, Color(0.02, 0.015, 0.015))
	var shoulder := Vector2(8 - lean, -33 + bob)
	var elbow := Vector2(17 - lean, -24 + bob) if not wind else Vector2(14 - lean, -43)
	var hand := Vector2(23, -13 + bob) if not wind else Vector2(3, -52)
	Ink.limb(self, shoulder, elbow, 5.0, 4.0, c, c.darkened(0.4), 1.6)
	Ink.limb(self, elbow, hand, 4.0, 2.5, c, c.darkened(0.4), 1.6)
	var reach := (hand - elbow).normalized()
	for i in 3:
		draw_line(hand, hand + reach.rotated((i - 1) * 0.55) * 6.0, Color(0.6, 0.56, 0.48, c.a), 1.4, true)


func _draw_hound(walk: float) -> void:
	var c := body_color(Color(0.18, 0.15, 0.135))
	var dk := c.darkened(0.35)
	var wind := state == "windup"
	for i in 4:
		var x := -13.0 + i * 8.5
		var ph := walk * (1.0 if i % 2 == 0 else -1.0)
		var col := dk if i % 2 == 1 else c
		var knee := Vector2(x + (2.5 if i < 2 else -2.0) + ph * 2.0, -6)
		Ink.limb(self, Vector2(x, -13), knee, 5.5, 3.5, col, col.darkened(0.4), 1.5)
		Ink.limb(self, knee, Vector2(x + ph * 7.0, 0), 3.5, 2.5, col, col.darkened(0.5), 1.5)
	draw_set_transform(Vector2(0, -14 + absf(walk) * 1.2) * scale_mult, 0.0, Vector2(facing.x * scale_mult, scale_mult))
	var tail := PackedVector2Array([Vector2(-20, -3), Vector2(-27, -7 + walk * 2.0), Vector2(-33, -13 + walk * 4.0)])
	draw_polyline(tail, Ink.LINE, 5.5, true)
	draw_polyline(tail, dk, 2.6, true)
	_part(PackedVector2Array([Vector2(-21, -1), Vector2(-12, -8), Vector2(2, -9), Vector2(12, -9), Vector2(17, -3), Vector2(15, 3), Vector2(5, 5), Vector2(-6, 2), Vector2(-16, 4)]), c)
	# hackles raised along the spine
	for i in 5:
		var hx := -13.0 + i * 5.5
		Ink.tri(self, Vector2(hx, -8), Vector2(hx + 2.0, -12.5 - (i % 2) * 1.5), Vector2(hx + 5.0, -8.3), dk.darkened(0.3))
	for i in 3:
		draw_line(Vector2(-4 + i * 5.0, -5), Vector2(-3 + i * 5.0, 2), Color(0.03, 0.025, 0.025, 0.6), 1.2, true)
	var jaw := 3.5 if wind else 0.6
	Ink.shape(self, PackedVector2Array([Vector2(14, -1), Vector2(27, 0 + jaw), Vector2(26, 2.5 + jaw), Vector2(15, 4)]), dk, dk.darkened(0.4), 1.5)
	_part(PackedVector2Array([Vector2(11, -9), Vector2(20, -11), Vector2(28, -7), Vector2(32, -3), Vector2(28, 0), Vector2(14, 1)]), c.lightened(0.04))
	Ink.shape(self, PackedVector2Array([Vector2(13, -9), Vector2(15, -18), Vector2(19, -10)]), dk, dk.darkened(0.3), 1.5)
	for i in 3:
		var tx := 20.0 + i * 3.2
		draw_line(Vector2(tx, 0), Vector2(tx + 0.6, 2.2), Color(0.8, 0.76, 0.66, c.a), 1.2, true)


func _draw_acolyte(walk: float) -> void:
	var c := body_color(Color(0.27, 0.115, 0.085))
	var dk := c.darkened(0.4)
	var sw := walk * 2.0
	var hem := sin(anim * 3.0) * 1.2
	_part(PackedVector2Array([Vector2(-8, -31), Vector2(8, -31), Vector2(12, -14), Vector2(15 + sw, -1), Vector2(9 + sw, 2 + hem), Vector2(4 + sw, -2), Vector2(-1 + sw, 3), Vector2(-6 + sw, -1), Vector2(-11 + sw, 2 - hem), Vector2(-15 + sw, -2), Vector2(-11, -15)]), c)
	var fold := Color(dk.r * 0.5, dk.g * 0.5, dk.b * 0.5, 0.7)
	draw_line(Vector2(-3, -26), Vector2(-5 + sw, -4), fold, 1.3, true)
	draw_line(Vector2(4, -27), Vector2(7 + sw, -5), fold, 1.3, true)
	draw_line(Vector2(-10, -18), Vector2(11, -18), Color(0.5, 0.4, 0.24, c.a), 1.6, true)
	draw_line(Vector2(3, -18), Vector2(2 + sw * 0.5, -9), Color(0.5, 0.4, 0.24, c.a), 1.3, true)
	_part(PackedVector2Array([Vector2(3, -31), Vector2(9, -30), Vector2(18, -28), Vector2(19, -21), Vector2(8, -22)]), c.lightened(0.05), true, 1.6)
	_part(PackedVector2Array([Vector2(-9, -30), Vector2(9, -30), Vector2(10, -41), Vector2(5, -50), Vector2(-2, -52), Vector2(-9, -45)]), shade(Color(0.15, 0.075, 0.06)))
	Ink.oval(self, Vector2(3, -39), 5.5, 6.5, shade(Color(0.02, 0.012, 0.012)), shade(Color(0.02, 0.012, 0.012)), 0.0)


func _draw_brute(walk: float) -> void:
	var c := body_color(Color(0.24, 0.225, 0.235))
	var dk := body_color(Color(0.125, 0.11, 0.115))
	var raise := state == "windup"
	var bob := absf(walk) * 2.0
	Ink.limb(self, Vector2(-10, -22), Vector2(-10 + walk * 6.0, 0), 12.0, 9.0, dk, dk.darkened(0.4))
	Ink.limb(self, Vector2(10, -22), Vector2(10 - walk * 6.0, 0), 12.0, 9.0, dk.lightened(0.06), dk.darkened(0.4))
	Ink.limb(self, Vector2(-22, -50 + bob), Vector2(-31 - walk * 2.0, -26 + bob), 10.0, 8.0, dk.lightened(0.08), dk.darkened(0.3))
	_part(PackedVector2Array([Vector2(-17, -18 + bob), Vector2(17, -18 + bob), Vector2(25, -40 + bob), Vector2(22, -58 + bob), Vector2(-22, -58 + bob), Vector2(-25, -40 + bob)]), c)
	Ink.shape(self, PackedVector2Array([Vector2(-12, -20 + bob), Vector2(12, -20 + bob), Vector2(14, -37 + bob), Vector2(-14, -37 + bob)]), dk.lightened(0.12), dk, 1.5)
	draw_line(Vector2(-20, -56 + bob), Vector2(13, -22 + bob), Color(0.3, 0.2, 0.12, c.a), 3.0, true)
	Ink.oval(self, Vector2(-24, -53 + bob), 12.5, 11.0, c.lightened(0.1), c.darkened(0.35))
	Ink.oval(self, Vector2(24, -53 + bob), 12.5, 11.0, c.lightened(0.1), c.darkened(0.35))
	_part(PackedVector2Array([Vector2(-9, -56 + bob), Vector2(9, -56 + bob), Vector2(10, -70 + bob), Vector2(6, -77 + bob), Vector2(-6, -77 + bob), Vector2(-10, -70 + bob)]), c.lightened(0.05))
	Ink.shape(self, PackedVector2Array([Vector2(-9, -72 + bob), Vector2(-22, -89 + bob), Vector2(-5, -77 + bob)]), dk.lightened(0.1), dk.darkened(0.2), 1.6)
	Ink.shape(self, PackedVector2Array([Vector2(9, -72 + bob), Vector2(22, -89 + bob), Vector2(5, -77 + bob)]), dk.lightened(0.1), dk.darkened(0.2), 1.6)
	var hand := Vector2(31, -38 + bob) if not raise else Vector2(12, -82)
	var head := hand + (Vector2(16, 26) if not raise else Vector2(6, -28))
	Ink.limb(self, Vector2(22, -52 + bob), hand, 10.0, 8.5, c, c.darkened(0.4))
	var along := (head - hand).normalized()
	draw_line(hand - along * 9.0, head, Ink.LINE, 7.0, true)
	draw_line(hand - along * 9.0, head, Color(0.34, 0.27, 0.2, c.a), 4.0, true)
	var side := along.orthogonal()
	var maul := PackedVector2Array([head - along * 9.0 - side * 13.0, head + along * 9.0 - side * 13.0, head + along * 9.0 + side * 13.0, head - along * 9.0 + side * 13.0])
	_part(maul, dk.lightened(0.15))


func _draw_bloater(walk: float) -> void:
	var c := body_color(Color(0.31, 0.34, 0.245))
	var dk := c.darkened(0.4)
	var swell := 1.0 + 0.04 * sin(anim * 4.0) + (0.12 * (1.0 - state_t / windup) if state == "windup" else 0.0)
	Ink.limb(self, Vector2(-8, -10), Vector2(-9 + walk * 4.0, 0), 6.0, 4.5, dk, dk.darkened(0.4), 1.6)
	Ink.limb(self, Vector2(8, -10), Vector2(9 - walk * 4.0, 0), 6.0, 4.5, dk, dk.darkened(0.4), 1.6)
	Ink.limb(self, Vector2(15, -32), Vector2(25, -22 + walk * 2.0), 5.0, 3.5, dk.lightened(0.1), dk, 1.6)
	Ink.oval(self, Vector2(0, -26), 21.0 * swell, 20.0 * swell, c.lightened(0.16), c.darkened(0.5), 2.2)
	Ink.glow(self, Vector2(-6, -32), 15.0 * swell, Color(c.r * 1.5, c.g * 1.5, c.b * 1.4, 0.5 * c.a))
	# the skin has been stitched shut more than once
	var seam := Color(0.06, 0.07, 0.04, 0.85)
	draw_polyline(PackedVector2Array([Vector2(-14, -12), Vector2(-6, -18), Vector2(2, -15), Vector2(9, -22), Vector2(15, -18)]), seam, 1.4, true)
	for i in 4:
		var sp := Vector2(-10 + i * 7.0, -15 - (i % 2) * 4.0)
		draw_line(sp + Vector2(-1.5, -3), sp + Vector2(1.5, 3), seam, 1.2, true)
	for q in [Vector2(-10, -20), Vector2(8, -32), Vector2(4, -14), Vector2(-4, -38)]:
		Ink.dot(self, q, 4.2, Color(0.08, 0.1, 0.05, c.a))
	Ink.oval(self, Vector2(12, -46), 7.5, 7.0, c.darkened(0.1), c.darkened(0.45), 2.0)
	Ink.dot(self, Vector2(14, -47), 2.0, Color(0.02, 0.02, 0.015))
	if _rim_a > 0.03:
		Ink.rim(self, PackedVector2Array([Vector2(-21, -26), Vector2(-15, -40), Vector2(0, -46), Vector2(15, -40), Vector2(21, -26), Vector2(15, -12), Vector2(0, -6), Vector2(-15, -12)]), _rim_v, Color(RIM.r, RIM.g, RIM.b, _rim_a), 1.6)


func _draw_wraith() -> void:
	var c := shade(Color(0.17, 0.16, 0.2, 0.92))
	var fl := sin(anim * 3.0) * 4.0
	var w1 := sin(anim * 4.0) * 3.0
	var w2 := sin(anim * 4.0 + 2.0) * 3.0
	var wind := state == "windup"
	# a shroud that frays into nothing before it reaches the ground
	var robe := PackedVector2Array([Vector2(-10, -40 + fl), Vector2(0, -53 + fl), Vector2(10, -40 + fl), Vector2(15, -22 + fl), Vector2(13 + w1, -6 + fl), Vector2(8, -13 + fl),
		Vector2(5 + w2, 2 + fl), Vector2(0, -11 + fl), Vector2(-5 + w1, 4 + fl), Vector2(-8, -12 + fl), Vector2(-13 + w2, -4 + fl), Vector2(-15, -22 + fl)])
	Ink.shape(self, robe, c.lightened(0.14), Color(c.r * 0.5, c.g * 0.5, c.b * 0.65, 0.0), 0.0)
	var crown := PackedVector2Array([robe[11], robe[0], robe[1], robe[2], robe[3]])
	draw_polyline(crown, Color(Ink.LINE.r, Ink.LINE.g, Ink.LINE.b, 0.9 * c.a), 2.0, true)
	if _rim_a > 0.03:
		Ink.rim(self, PackedVector2Array([robe[11], robe[0], robe[1], robe[2], robe[3], Vector2(0, -20 + fl)]), _rim_v, Color(RIM.r, RIM.g, RIM.b, _rim_a * 0.7), 1.5)
	Ink.oval(self, Vector2(2, -42 + fl), 5.5, 6.5, Color(0.01, 0.01, 0.015, c.a), Color(0.01, 0.01, 0.015, c.a), 0.0)
	var hand := Vector2(23, -30 + fl) if not wind else Vector2(10, -60 + fl)
	Ink.limb(self, Vector2(7, -36 + fl), hand, 4.0, 2.0, c, c.darkened(0.3), 1.4)
	var reach := (hand - Vector2(7, -36 + fl)).normalized()
	for i in 3:
		draw_line(hand, hand + reach.rotated((i - 1) * 0.5) * 7.0, c.lightened(0.2), 1.2, true)
	if randf() < 0.3 and world:
		world.smoke_fx.emit(global_position + Vector2(randf_range(-10, 10), -10), Vector2(0, -20), 0.8, 7.0, Color(0.15, 0.14, 0.16, 0.5), Particles.SMOKE, 1.0)


func _draw_glow() -> void:
	if petrify:
		return
	var s := scale_mult
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing.x * s, s))
	var wind := state == "windup"
	var hot := Color(3.0, 1.0, 0.25) if not wind else Color(4.0, 1.6, 0.5)
	var halo := Color(1.4, 0.38, 0.08, 0.5) if not wind else Color(2.0, 0.6, 0.14, 0.7)
	match kind:
		"husk":
			var lean := 6.0 if wind else 0.0
			var eye := Vector2(13 - lean, -42)
			Ink.glow(glow, eye, 7.0, halo)
			Ink.dot(glow, eye, 1.5, hot)
			# the fire that keeps it walking shows through the cracks in its chest
			var crack := Color(1.7, 0.45, 0.1, 0.75)
			glow.draw_polyline(PackedVector2Array([Vector2(-4, -16), Vector2(0, -23), Vector2(-1, -28), Vector2(4, -32), Vector2(8 - lean, -35)]), crack, 1.1, true)
			glow.draw_line(Vector2(0, -23), Vector2(5, -21), crack, 1.0, true)
		"hound":
			for i in 4:
				var sp := Vector2(-11 + i * 6.0, -23)
				Ink.glow(glow, sp, 5.5, Color(1.6, 0.4, 0.08, 0.45))
				Ink.dot(glow, sp, 1.3, Color(3.0, 0.8, 0.2, 0.9))
			var eye2 := Vector2(24, -21)
			Ink.glow(glow, eye2, 7.0, halo)
			Ink.dot(glow, eye2, 1.5, hot)
			if wind:
				Ink.glow(glow, Vector2(24, -12), 9.0, Color(2.2, 0.6, 0.12, 0.6))
		"acolyte":
			var orb := Vector2(19, -25)
			var r := 4.5 + (5.0 * (1.0 - state_t / windup) if wind else 0.0)
			Ink.glow(glow, orb, r * 2.8, Color(1.4, 0.4, 0.09, 0.4))
			Ink.dot(glow, orb, r, Color(3.4, 1.2, 0.3))
			Ink.dot(glow, orb + Vector2(-r * 0.25, -r * 0.25), r * 0.45, Color(4.0, 2.6, 1.2))
			Ink.glow(glow, Vector2(4, -39), 6.0, halo)
			Ink.dot(glow, Vector2(2, -40), 1.2, hot)
			Ink.dot(glow, Vector2(6, -40), 1.2, hot)
		"brute":
			Ink.glow(glow, Vector2(0, -68), 12.0, halo)
			glow.draw_line(Vector2(-6, -68), Vector2(6, -68), hot, 2.2, true)
			if is_champion:
				glow.draw_polyline(PackedVector2Array([Vector2(-14, -30), Vector2(-4, -36), Vector2(-2, -42), Vector2(10, -48)]), Color(2.6, 0.7, 0.15, 0.8), 2.0, true)
		"bloater":
			var gas := 0.75 + 0.25 * sin(anim * 4.0)
			for p in [Vector2(-10, -20), Vector2(8, -32), Vector2(4, -14), Vector2(-4, -38)]:
				Ink.glow(glow, p, 8.0, Color(0.5, 1.2, 0.2, 0.5 * gas))
				Ink.dot(glow, p, 2.6, Color(1.2, 2.4, 0.5, 0.9))
			Ink.dot(glow, Vector2(14, -47), 1.4, Color(2.0, 2.6, 0.6))
		"wraith":
			var fl := sin(anim * 3.0) * 4.0
			Ink.glow(glow, Vector2(2, -42 + fl), 9.0, Color(1.4, 0.3, 0.1, 0.5))
			Ink.dot(glow, Vector2(-1, -42 + fl), 1.6, Color(3.0, 0.6, 0.2))
			Ink.dot(glow, Vector2(5, -42 + fl), 1.6, Color(3.0, 0.6, 0.2))
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
			Ink.dot(glow, Vector2(cos(a) * 12.0, -radius * 3.2 * scale_mult + sin(a) * 4.0), 2.0, Color(2.5, 2.2, 1.5))
