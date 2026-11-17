class_name Player
extends Actor
## The player character. All three classes live here; behaviour branches on `cls`.

var cls := "knight"
var data: Dictionary
var abilities: Array = []
var _voice_cd := 0.0
## Which ability each bar slot (primary, secondary, skill 1, skill 2) uses; the player arranges it.
var slot_map: Array = [0, 1, 2, 3]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var resource := 0.0
var res_max := 100.0
var ash := 0.0
var ash_full_t := 0.0
var level := 1
var xp := 0.0
var xp_next := 40.0
var pending_levels := 0
var mods := {}
var flask := 3
var flask_cd := 0.0
var base_hp := 300.0
var base_speed := 225.0
var base_armor := 0.0

var aim_point := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var move_dir := Vector2.ZERO
var moving := false
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.RIGHT
var invuln_t := 0.0
var buffs := {}
var ult_t := 0.0
var hurt_t := 0.0

var swing_t := 0.0
var swing_dir := Vector2.RIGHT
var swing_side := 1.0
var cleave_count := 0
var rush_t := 0.0
var rush_dir := Vector2.RIGHT
var rush_hits := {}
var oath_t := 0.0
var oath_stored := 0.0
var molten_t := 0.0
var _aura_tick := 0.0
var cast_t := 0.0
var step_charges := 1
var step_recharge := 0.0
var overheat_t := 0.0
var _trail_t := 0.0
var light: PointLight2D
var bot_control := false


func setup(class_id: String) -> void:
	cls = class_id
	data = Data.CLASSES[cls]
	abilities = data.abilities
	slot_map = Game.loadout_for(cls)
	team = Team.PLAYER
	radius = 15.0
	base_hp = data.max_hp
	base_speed = data.speed
	base_armor = data.armor
	max_hp = base_hp
	hp = max_hp
	resource = 0.0 if cls != "gravecaller" else 60.0
	flask = flask_max()
	recompute()


func _ready() -> void:
	super._ready()
	if world == null:
		return
	light = world.make_light(Color(1.0, 0.86, 0.72), 1.3, 1700.0)
	add_child(light)
	light.position = Vector2(0, -20)
	var accent := world.make_light(data.res_color, 0.35, 420.0)
	add_child(accent)
	accent.position = Vector2(0, -20)


# ---------------------------------------------------------------- stats

func has_mod(id: String) -> bool:
	return mods.has(id)


func mod(id: String) -> int:
	return int(mods.get(id, 0))


func frag(id: String) -> bool:
	return Game.fragments.has(id)


func dmg_mult() -> float:
	var m := 1.0 + 0.12 * mod("ferocity") + Game.gear_stat("dmg") / 100.0
	if frag("hunger"):
		m += 0.3
	if buffs.has("fury"):
		m += 0.5
	if cls == "crownbearer":
		m += 1.5
	if cls == "pyrewitch":
		m += resource * 0.004
		if has_mod("heat_master") and resource > 70.0:
			m += 0.25
	return m


func cd_rate() -> float:
	var r := 1.0 + 0.1 * mod("alacrity") + minf(0.6, Game.gear_stat("cdr") / 100.0)
	if cls == "crownbearer":
		r += 0.6
	if frag("haste"):
		r += 0.25
	if buffs.has("haste"):
		r += 0.3
	return r


func speed() -> float:
	var s := base_speed * (1.0 + 0.1 * mod("swiftness") + minf(0.35, Game.gear_stat("speed") / 100.0))
	if frag("iron"):
		s *= 0.85
	if buffs.has("haste"):
		s *= 1.25
	if cls == "pyrewitch" and ult_t > 0.0:
		s *= 1.3
	return s * move_speed_mult()


func crit_chance() -> float:
	return 0.05 + 0.06 * mod("precision") + Game.gear_stat("crit") / 100.0 + (0.15 if frag("ruin") else 0.0)


func crit_mult() -> float:
	return 1.5 + Game.gear_stat("critd") / 100.0 + (0.5 if frag("ruin") else 0.0)


func area_mult() -> float:
	return 1.0 + 0.15 * mod("reach")


## The potion is no longer a stack of charges: one draught, reusable on a timer, as in Diablo 3.
func flask_max() -> int:
	return 1


func potion_cooldown() -> float:
	return maxf(8.0, 30.0 - 3.0 * mod("flaskmaker") - 5.0 * Game.gear_stat("flask") + (6.0 if frag("ruin") else 0.0))


func ult_duration(base: float) -> float:
	return base * (1.5 if frag("hollow") else 1.0)


func recompute() -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	var m := base_hp * (1.0 + 0.2 * mod("vigor")) + Game.gear_stat("hp")
	if frag("hunger"):
		m *= 0.8
	if frag("iron"):
		m *= 1.4
	max_hp = m
	hp = clampf(ratio * max_hp, 1.0, max_hp)
	armor = minf(Items.MAX_ARMOR, base_armor + (0.1 if frag("iron") else 0.0) + Game.gear_stat("armor") / 100.0)
	flask = mini(flask, flask_max())


func add_mod(id: String) -> void:
	mods[id] = mod(id) + 1
	if id == "flaskmaker":
		flask += 1
	if id == "step_double":
		step_charges = 2
	recompute()


func add_buff(id: String, dur: float) -> void:
	buffs[id] = dur


func untargetable() -> bool:
	return dodge_t > 0.0


func heal(amount: float, show := true) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show and hp - before >= 1.0:
		world.texts.add(global_position + Vector2(0, -50), hp - before, Color(0.5, 1.0, 0.5), false)


## Every so many kills, the draught is ready sooner.
func add_flask_charge() -> void:
	Game.potion_cd = maxf(0.0, Game.potion_cd - 6.0)


func on_kill(e: Enemy, gained_xp: float) -> void:
	var gain := 3.5
	if e.elite:
		gain = 14.0
	if e.is_champion:
		gain = 40.0
	gain *= pow(1.25, mod("ashborn")) * (2.0 if frag("pyre") else 1.0) * (1.0 + Game.gear_stat("ash") / 100.0)
	if ult_t <= 0.0:
		ash = minf(100.0, ash + gain)
	if cls == "gravecaller" and e.global_position.distance_to(global_position) < 450.0:
		resource = minf(res_max, resource + 9.0)
	if mod("leech") > 0 or Game.gear_stat("leech") > 0.0:
		heal(max_hp * (0.015 * mod("leech") + Game.gear_stat("leech") / 100.0), false)
	gain_xp(gained_xp)


func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = Data.xp_for_level(level)
		pending_levels += 1
		Game.stats.level = level
		heal(max_hp * 0.25, false)
		world.glow_fx.burst(global_position, 30, Color(3.0, 1.4, 0.4), 80, 320, 0.8, 3.0, Particles.SPARK)
		world.glow_fx.ring(global_position, 120.0, Color(3.0, 1.2, 0.3, 0.8), 0.6)
		Sfx.play("levelup", -2.0)
		Voice.bark("player", "levelup", "", 10.0)
		world.level_up.emit()


func revive() -> void:
	dead = false
	visible = true
	hp = max_hp
	burn_t = 0.0
	poison_t = 0.0
	stun_t = 0.0
	slow_t = 0.0
	invuln_t = 2.0
	flask = flask_max()
	Game.potion_cd = 0.0
	overheat_t = 0.0
	if cls == "pyrewitch":
		resource = 0.0


func export_state() -> Dictionary:
	return {"hp": hp / max_hp, "resource": resource, "ash": ash, "level": level, "xp": xp, "xp_next": xp_next,
		"mods": mods.duplicate(), "flask": flask, "step_charges": step_charges, "points": pending_levels}


func import_state(s: Dictionary) -> void:
	mods = s.mods.duplicate()
	level = s.level
	xp = s.xp
	xp_next = s.xp_next
	resource = s.resource if cls != "pyrewitch" else 0.0
	ash = s.ash
	flask = s.flask
	step_charges = s.step_charges
	pending_levels = int(s.get("points", 0))
	recompute()
	hp = maxf(max_hp * 0.5, max_hp * float(s.hp))


# ---------------------------------------------------------------- update

func update(dt: float) -> void:
	anim += dt
	tick_status(dt)
	var rate := cd_rate()
	for i in cds.size():
		cds[i] = maxf(0.0, cds[i] - dt * rate)
	if step_charges < (2 if has_mod("step_double") else 1):
		step_recharge += dt * rate
		if step_recharge >= abilities[2].cd:
			step_recharge = 0.0
			step_charges += 1
	for k in buffs.keys():
		buffs[k] -= dt
		if buffs[k] <= 0.0:
			buffs.erase(k)
	dodge_cd = maxf(0.0, dodge_cd - dt)
	flask_cd = maxf(0.0, flask_cd - dt)
	invuln_t = maxf(0.0, invuln_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	_voice_cd = maxf(0.0, _voice_cd - dt)
	swing_t = maxf(0.0, swing_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
	_update_aim()
	_update_resource(dt)
	_update_ash(dt)
	_update_regen(dt)

	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = move_dir.length() > 0.1
	if dodge_t > 0.0:
		dodge_t -= dt
		integrate(dt, dodge_dir * 640.0)
		if randf() < 0.6:
			world.smoke_fx.emit(global_position, -dodge_dir * 40.0, 0.5, 8.0, Color(0.4, 0.38, 0.36, 0.5), Particles.SMOKE, 2.0)
	elif rush_t > 0.0:
		_update_rush(dt)
	elif is_stunned():
		integrate(dt, Vector2.ZERO)
	else:
		var spd := speed()
		if swing_t > 0.0 and cls == "knight":
			spd *= 0.55
		integrate(dt, move_dir.limit_length(1.0) * spd)
		_handle_input()

	if oath_t > 0.0:
		oath_t -= dt
		if oath_t <= 0.0:
			_oath_release()
	if molten_t > 0.0:
		molten_t -= dt
		_molten_aura(dt)
	if ult_t > 0.0:
		ult_t -= dt
		_update_ult(dt)
	if overheat_t > 0.0:
		overheat_t -= dt
		hp -= max_hp * 0.06 * dt
		if randf() < 0.5:
			world.glow_fx.emit(global_position + Vector2(randf_range(-12, 12), -30), Vector2(0, -80), 0.5, 3.0, Color(3.0, 0.8, 0.2), Particles.EMBER, 1.0)
		if hp <= 0.0:
			hp = 0.0
			world._kill(self, null)
			return
	light.energy = 1.3 + (0.3 if cls == "pyrewitch" and resource > 70.0 else 0.0)
	queue_redraw()
	glow.queue_redraw()


func _update_aim() -> void:
	if bot_control:
		var bd := aim_point - global_position
		if bd.length() > 4.0:
			aim_dir = bd.normalized()
		facing = Vector2(signf(aim_dir.x) if aim_dir.x != 0.0 else 1.0, 0)
		return
	if Game.using_gamepad:
		var r := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if r.length() > 0.3:
			aim_dir = r.normalized()
			aim_point = global_position + aim_dir * 320.0
			return
		var e: Enemy = world.nearest_enemy(global_position, 650.0) if bool(Game.settings.get("aim_assist", true)) else null
		if e:
			aim_point = e.global_position
			aim_dir = (aim_point - global_position).normalized()
			return
		if move_dir.length() > 0.2:
			aim_dir = move_dir.normalized()
		aim_point = global_position + aim_dir * 260.0
	else:
		aim_point = get_global_mouse_position()
		var d := aim_point - global_position
		if d.length() > 4.0:
			aim_dir = d.normalized()
	if aim_dir.x != 0.0:
		facing = Vector2(signf(aim_dir.x), 0)


func target_point(max_range: float) -> Vector2:
	var d := aim_point - global_position
	var p := global_position + d.limit_length(max_range)
	if not world.los(global_position, p):
		var steps := 12
		for i in range(steps, -1, -1):
			var q := global_position + d.limit_length(max_range) * (float(i) / steps)
			if world.los(global_position, q):
				return q
	return p


func _update_resource(dt: float) -> void:
	match cls:
		"gravecaller":
			resource = minf(res_max, resource + 1.5 * dt)
		"pyrewitch":
			resource = maxf(0.0, resource - 12.0 * dt)
		"knight":
			pass


func _update_ash(dt: float) -> void:
	if ash >= 100.0:
		ash_full_t += dt
		var limit := 10.0 if not frag("pyre") else 6.0
		if ash_full_t > limit:
			var rate := 0.015 * (2.0 if frag("pyre") else 1.0)
			hp -= max_hp * rate * dt
			if randf() < dt * 6.0:
				world.smoke_fx.emit(global_position + Vector2(randf_range(-14, 14), -30), Vector2(0, -30), 1.0, 6.0, Color(0.5, 0.48, 0.46, 0.6), Particles.SMOKE, 1.0)
			if hp <= 1.0:
				hp = 1.0
	else:
		ash_full_t = 0.0


func ash_cursed() -> bool:
	return ash >= 100.0 and ash_full_t > (10.0 if not frag("pyre") else 6.0)


func _update_regen(dt: float) -> void:
	if (mod("second_wind") > 0 or Game.gear_stat("regen") > 0.0) and not frag("thorns"):
		hp = minf(max_hp, hp + max_hp * (0.01 * mod("second_wind") + Game.gear_stat("regen") / 100.0) * dt)


# ---------------------------------------------------------------- input / casting

func _handle_input() -> void:
	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
		dodge_dir = move_dir.normalized() if moving else aim_dir
		dodge_t = 0.3
		dodge_cd = 1.0 * (2.0 if frag("hollow") else 1.0)
		Sfx.play("dodge", -4.0)
		return
	if Input.is_action_just_pressed("flask"):
		_drink()
	if Input.is_action_just_pressed("ultimate"):
		_try_cast(4)
	if Input.is_action_pressed("attack_1") and world.hovered_loot == null:
		_try_cast(slot_map[0])
	if Input.is_action_pressed("attack_2"):
		_try_cast(slot_map[1])
	if Input.is_action_pressed("skill_1"):
		_try_cast(slot_map[2])
	if Input.is_action_pressed("skill_2"):
		_try_cast(slot_map[3])


func _drink() -> void:
	if Game.potion_cd > 0.0 or flask_cd > 0.0 or hp >= max_hp:
		return
	Game.potion_cd = potion_cooldown()
	flask_cd = 1.0
	Voice.bark("player", "potion", "", 40.0)
	heal(max_hp * 0.45 * (1.0 + 0.15 * mod("flaskmaker")))
	Sfx.play("flask")
	world.glow_fx.burst(global_position + Vector2(0, -20), 16, Color(2.4, 0.3, 0.25), 40, 160, 0.6, 2.5, Particles.EMBER, TAU, 0.0, 2.0, -100.0)


func slot_ability(slot: int) -> int:
	return 4 if slot >= 4 else int(slot_map[slot])


func can_cast(i: int) -> bool:
	var a: Dictionary = abilities[i]
	if i == 4:
		return ash >= 100.0 and ult_t <= 0.0
	if cls == "pyrewitch" and a.id == "step":
		return step_charges > 0
	if cds[i] > 0.0:
		return false
	if cls != "pyrewitch" and resource < float(a.cost):
		return false
	return true


func _try_cast(i: int) -> void:
	if not can_cast(i):
		return
	if cast_t > 0.0 and i != 4:
		return
	var a: Dictionary = abilities[i]
	var ok: bool = call("_cast_" + String(a.id))
	if not ok:
		return
	if i == 4:
		ash = 0.0
		ash_full_t = 0.0
		Sfx.play("ultimate")
		world.shake(10.0)
		return
	if cls == "pyrewitch" and a.id == "step":
		step_charges -= 1
	else:
		cds[i] = float(a.cd)
	if cls != "pyrewitch":
		resource -= float(a.cost)
	else:
		_add_heat(Data.HEAT_COST.get(a.id, 0.0))


func _add_heat(amount: float) -> void:
	resource = clampf(resource + amount, 0.0, res_max)
	if resource >= res_max and ult_t <= 0.0:
		resource = 55.0
		overheat_t = 2.0
		world.texts.add_label(global_position + Vector2(0, -70), "Overheated", Color(1.0, 0.45, 0.25))
		world.glow_fx.burst(global_position, 26, Color(3.0, 0.8, 0.2), 80, 300, 0.6, 3.0, Particles.SPARK)
		Sfx.play("explode_small", -4.0)


# ---------------- Ashen Knight

func _cast_cleave() -> bool:
	swing_t = 0.24
	swing_dir = aim_dir
	swing_side = -swing_side
	cast_t = 0.12
	cleave_count += 1
	var wide := has_mod("cleave_wide")
	var reach := 108.0 * area_mult() * (1.15 if wide else 1.0)
	var half := deg_to_rad(80.0 if wide else 65.0)
	var dmg := 26.0 * dmg_mult() * (1.25 if wide else 1.0)
	var hits := 0
	for e in world.enemies_in_radius(global_position, reach):
		var to := e.global_position - global_position
		if absf(aim_dir.angle_to(to)) <= half or to.length() < e.radius + radius + 6.0:
			world.damage(e, dmg, self, {"type": "fire", "burn": [6.0 * dmg_mult(), 3.0], "knock": to.normalized() * 180.0, "melee": true})
			world.glow_fx.burst(e.global_position, 6, Color(3.0, 1.0, 0.3), 80, 260, 0.3, 2.0, Particles.SPARK, 1.2, to.angle())
			hits += 1
	if hits > 0:
		resource = minf(res_max, resource + 5.0 + minf(5.0, hits - 1.0) * 1.5)
		Sfx.play("hit", -4.0)
		world.hitstop(0.035)
		world.shake(2.0 + minf(hits, 4))
	Sfx.play("swing", -6.0)
	if has_mod("cleave_wave") and cleave_count % 3 == 0:
		world.spawn_projectile("firewave", global_position + aim_dir * 30.0, aim_dir, 720.0, 30.0 * dmg_mult(), Team.PLAYER, {"src": self})
	return true


func _cast_rush() -> bool:
	rush_t = 0.26
	rush_dir = aim_dir
	rush_hits.clear()
	Sfx.play("dodge", -2.0, 0.05, 0.8)
	return true


func _update_rush(dt: float) -> void:
	rush_t -= dt
	integrate(dt, rush_dir * 1050.0)
	world.smoke_fx.emit(global_position + Vector2(randf_range(-8, 8), 0), -rush_dir * 60.0, 0.6, 10.0, Color(0.35, 0.32, 0.3, 0.55), Particles.SMOKE, 2.0)
	for e in world.enemies_in_radius(global_position + rush_dir * 16.0, 34.0):
		var id := e.get_instance_id()
		if rush_hits.has(id):
			continue
		rush_hits[id] = true
		var side := Vector2(-rush_dir.y, rush_dir.x)
		var push := side * signf(side.dot(e.global_position - global_position) + 0.01) * 320.0 + rush_dir * 120.0
		world.damage(e, 34.0 * dmg_mult(), self, {"type": "phys", "stun": 1.2, "knock": push, "melee": true})
		Sfx.play("hit_heavy", -4.0)
		world.shake(4.0)
		resource = minf(res_max, resource + 4.0)
	if rush_t <= 0.0:
		if has_mod("rush_quake"):
			world.area_damage(global_position, 130.0 * area_mult(), 40.0 * dmg_mult(), self, Team.PLAYER, {"type": "phys", "knock_force": 300.0, "stun": 0.6})
			world.glow_fx.ring(global_position, 130.0 * area_mult(), Color(2.4, 1.0, 0.4, 0.8))
			world.smoke_fx.burst(global_position, 12, Color(0.3, 0.28, 0.26, 0.6), 60, 200, 0.8, 10, Particles.SMOKE)
			Sfx.play("slam", -4.0)
			world.shake(8.0)
		if has_mod("rush_refund") and rush_hits.size() >= 3:
			cds[1] = 0.0


func _cast_oath() -> bool:
	oath_t = 3.0
	oath_stored = 0.0
	Sfx.play("summon", -6.0, 0.05, 1.4)
	world.glow_fx.ring(global_position, 70.0, Color(3.0, 1.4, 0.5, 0.9), 0.4)
	return true


func _oath_release() -> void:
	var r := 175.0 * area_mult()
	var dmg := 25.0 * dmg_mult() + oath_stored * (2.0 if has_mod("oath_nova") else 1.0)
	world.area_damage(global_position, r, dmg, self, Team.PLAYER, {"type": "fire", "knock_force": 380.0, "burn": [8.0 * dmg_mult(), 3.0]})
	world.glow_fx.ring(global_position, r, Color(3.2, 1.2, 0.3, 1.0), 0.5)
	world.glow_fx.burst(global_position, 40, Color(3.0, 1.0, 0.25), 120, 520, 0.6, 3.0, Particles.SPARK)
	world.glow_fx.emit(global_position, Vector2.ZERO, 0.35, r, Color(2.0, 0.6, 0.15, 0.3), Particles.GLOW, 0.0)
	world.decals.add_scorch(global_position, r * 0.7)
	Sfx.play("explode")
	world.shake(10.0)
	world.hitstop(0.06)
	if has_mod("oath_heal"):
		heal(max_hp * 0.15)


func _cast_molten() -> bool:
	molten_t = 8.0 * (1.5 if has_mod("molten_long") else 1.0)
	Sfx.play("fire_cast", -2.0, 0.05, 0.7)
	world.glow_fx.burst(global_position, 30, Color(3.0, 0.9, 0.2), 60, 260, 0.6, 3.0, Particles.EMBER)
	return true


func _molten_aura(dt: float) -> void:
	_aura_tick -= dt
	if randf() < 0.7:
		var a := randf() * TAU
		var r := molten_radius() * randf_range(0.3, 1.0)
		world.glow_fx.emit(global_position + Vector2(cos(a), sin(a) * 0.6) * r, Vector2(0, -50), 0.6, 2.5, Color(3.0, 0.9, 0.2), Particles.EMBER, 1.0)
	if _aura_tick > 0.0:
		return
	_aura_tick = 0.5
	var dps := 16.0 * dmg_mult() * (2.0 if has_mod("molten_spread") else 1.0)
	for e in world.enemies_in_radius(global_position, molten_radius()):
		world.damage(e, dps * 0.5, self, {"type": "fire", "dot": true, "burn": [dps * 0.3, 2.0]})


func molten_radius() -> float:
	return 90.0 * area_mult() * (1.6 if has_mod("molten_spread") else 1.0)


func _cast_vanguard() -> bool:
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var m := world.spawn_minion("vanguard", global_position + Vector2(cos(a), sin(a)) * 70.0, ult_duration(12.0))
		world.glow_fx.burst(m.global_position, 20, Color(1.6, 2.2, 3.0), 40, 200, 0.7, 3.0, Particles.EMBER, TAU, 0.0, 2.0, -100.0)
	ult_t = ult_duration(12.0)
	return true


# ---------------- Gravecaller

func _cast_lance() -> bool:
	var marrow := has_mod("lance_marrow")
	world.spawn_projectile("bone", global_position + aim_dir * 22.0 + Vector2(0, -22), aim_dir, 1050.0 if marrow else 780.0, 21.0 * dmg_mult() * (1.4 if marrow else 1.0), Team.PLAYER, {"src": self, "split": has_mod("lance_split")})
	Sfx.play("bone", -6.0)
	cast_t = 0.1
	swing_t = 0.18
	return true


func minion_count(kind: String) -> int:
	var n := 0
	for m in world.minions:
		if not m.dead and m.kind == kind:
			n += 1
	return n


func max_skeletons() -> int:
	return 5 + (3 if has_mod("raise_legion") else 0)


func _cast_raise() -> bool:
	if minion_count("skeleton") >= max_skeletons():
		return false
	var p := global_position + aim_dir * 60.0
	if not world.is_floor_at(p):
		p = global_position
	raise_skeleton(p)
	return true


func raise_skeleton(p: Vector2) -> void:
	world.spawn_minion("skeleton", p)
	world.smoke_fx.burst(p, 10, Color(0.3, 0.3, 0.3, 0.7), 20, 90, 0.9, 9, Particles.SMOKE, TAU, 0.0, 2.0, -30.0)
	world.glow_fx.burst(p, 14, Color(1.0, 2.4, 2.2), 40, 160, 0.6, 2.0, Particles.EMBER, TAU, 0.0, 2.0, -120.0)
	Sfx.play("summon", -6.0)


func _cast_bloom() -> bool:
	var target := target_point(560.0)
	var big := has_mod("bloom_big")
	var r := 95.0 * area_mult() * (1.4 if big else 1.0)
	var dmg := 58.0 * dmg_mult() * (1.4 if big else 1.0)
	var used := 0
	var list := world.corpses.duplicate()
	list.sort_custom(func(a, b): return a.pos.distance_to(target) < b.pos.distance_to(target))
	for c in list:
		if used >= 3 or c.pos.distance_to(target) > 220.0:
			break
		used += 1
		world.corpses.erase(c)
		_bloom_at(c.pos, r, dmg)
		if has_mod("bloom_raise") and minion_count("skeleton") < max_skeletons():
			raise_skeleton(c.pos)
	if used == 0:
		_bloom_at(target, r * 0.7, dmg * 0.45)
	return true


func _bloom_at(p: Vector2, r: float, dmg: float) -> void:
	world.area_damage(p, r, dmg, self, Team.PLAYER, {"type": "poison", "knock_force": 260.0})
	world.spawn_hazard("poison", p, {"radius": r * 0.8, "duration": 3.0, "dps": dmg * 0.25, "team": Team.PLAYER, "src": self})
	world.smoke_fx.burst(p, 16, Color(0.75, 0.72, 0.65), 100, 360, 0.6, 4.0, Particles.DEBRIS, TAU, 0.0, 3.0, 300.0)
	world.glow_fx.burst(p, 18, Color(0.8, 2.6, 1.2), 80, 320, 0.5, 2.5, Particles.SPARK)
	world.glow_fx.ring(p, r, Color(0.8, 2.2, 1.0, 0.8))
	world.smoke_fx.burst(p, 8, Color(0.3, 0.38, 0.2, 0.6), 30, 100, 1.2, r * 0.25, Particles.SMOKE)
	Sfx.play("explode_small", -4.0)
	world.shake(4.0)


func _cast_wither() -> bool:
	var target := target_point(600.0)
	var r := 130.0 * area_mult()
	for e in world.enemies_in_radius(target, r):
		e.apply_vuln(0.35, 6.0, true)
		e.apply_slow(0.3, 6.0)
	world.glow_fx.ring(target, r, Color(0.7, 2.2, 1.9, 0.9), 0.5)
	world.glow_fx.emit(target, Vector2.ZERO, 0.5, r, Color(0.3, 0.9, 0.8, 0.22), Particles.GLOW, 0.0)
	for i in 20:
		var a := randf() * TAU
		world.glow_fx.emit(target + Vector2(cos(a), sin(a)) * randf() * r, Vector2(0, -40), 0.9, 2.5, Color(0.8, 2.4, 2.0), Particles.EMBER, 1.0)
	Sfx.play("freeze", -6.0, 0.05, 0.7)
	return true


func _cast_titan() -> bool:
	var p := target_point(200.0)
	world.spawn_minion("titan", p, ult_duration(16.0))
	world.smoke_fx.burst(p, 30, Color(0.3, 0.3, 0.3, 0.8), 40, 200, 1.4, 16, Particles.SMOKE)
	world.glow_fx.burst(p, 40, Color(1.0, 2.6, 2.3), 80, 360, 0.9, 3.0, Particles.SPARK)
	world.glow_fx.ring(p, 200.0, Color(1.0, 2.4, 2.2, 0.9), 0.6)
	ult_t = ult_duration(16.0)
	return true


# ---------------- Pyrewitch

func _cast_bolt() -> bool:
	var spd := 920.0
	var dmg := 24.0 * dmg_mult()
	var dirs: Array[float] = [0.0]
	if has_mod("bolt_split") or ult_t > 0.0:
		dirs = [-0.2, 0.0, 0.2]
	for a in dirs:
		world.spawn_projectile("ember", global_position + aim_dir * 22.0 + Vector2(0, -24), aim_dir.rotated(a), spd, dmg, Team.PLAYER, {"src": self, "pierce": has_mod("bolt_pierce"), "phoenix": ult_t > 0.0})
	Sfx.play("fire_cast", -10.0, 0.12, 1.3)
	cast_t = 0.08
	swing_t = 0.15
	return true


func _cast_storm() -> bool:
	var p := target_point(560.0)
	var r := 115.0 * area_mult() * (1.4 if has_mod("storm_big") else 1.0)
	world.spawn_hazard("firestorm", p, {"radius": r, "duration": 4.0 + (2.0 if has_mod("storm_pull") else 0.0), "dps": 36.0 * dmg_mult(), "team": Team.PLAYER, "src": self, "pull": has_mod("storm_pull")})
	Sfx.play("fire_cast", 0.0, 0.05, 0.6)
	cast_t = 0.2
	swing_t = 0.25
	return true


func _cast_step() -> bool:
	var from := global_position
	var d := (aim_point - from).limit_length(290.0)
	if d.length() < 40.0:
		d = aim_dir * 290.0
	var dest := from
	var steps := 16
	for i in range(steps, 0, -1):
		var q := from + d * (float(i) / steps)
		if world.los(from, q) and world.world_clamp_soft(q, radius).distance_to(q) < 2.0:
			dest = q
			break
	if dest == from:
		return false
	global_position = dest
	invuln_t = 0.2
	var r := 95.0 * area_mult()
	world.area_damage(from, r, 42.0 * dmg_mult(), self, Team.PLAYER, {"type": "fire", "knock_force": 300.0, "burn": [8.0, 2.0]})
	world.glow_fx.burst(from, 30, Color(3.0, 1.0, 0.25), 80, 380, 0.5, 3.0, Particles.SPARK)
	world.glow_fx.ring(from, r, Color(3.0, 1.0, 0.3, 0.9))
	world.glow_fx.emit(from, Vector2.ZERO, 0.3, r, Color(2.0, 0.6, 0.15, 0.3), Particles.GLOW, 0.0)
	for i in 12:
		world.glow_fx.emit(from.lerp(dest, i / 12.0), Vector2(randf_range(-20, 20), -30), 0.5, 3.0, Color(3.0, 1.2, 0.3), Particles.EMBER, 1.0)
	world.decals.add_scorch(from, r * 0.7)
	Sfx.play("teleport", -4.0)
	world.shake(5.0)
	if has_mod("step_vent"):
		_add_heat(-25.0 - Data.HEAT_COST.step)
	return true


func _cast_smother() -> bool:
	var p := target_point(520.0)
	var r := 115.0 * area_mult()
	for e in world.enemies_in_radius(p, r):
		world.damage(e, 16.0 * dmg_mult(), self, {"type": "phys"})
		if not e.is_boss:
			e.apply_stun(2.2)
			e.petrify = true
			e.burn_t = 0.0
	world.smoke_fx.burst(p, 26, Color(0.5, 0.48, 0.45, 0.8), 60, 260, 1.2, 12, Particles.SMOKE)
	world.smoke_fx.burst(p, 16, Color(0.6, 0.58, 0.55), 80, 300, 0.6, 4.0, Particles.DEBRIS, TAU, 0.0, 3.0, 300.0)
	world.glow_fx.ring(p, r, Color(1.6, 1.5, 1.4, 0.7))
	Sfx.play("freeze", -2.0)
	world.shake(4.0)
	return true


func _cast_phoenix() -> bool:
	ult_t = ult_duration(9.0)
	resource = 0.0
	overheat_t = 0.0
	world.glow_fx.burst(global_position, 60, Color(3.0, 1.0, 0.25), 100, 500, 0.9, 3.0, Particles.SPARK)
	world.glow_fx.ring(global_position, 220.0, Color(3.0, 1.2, 0.3, 1.0), 0.6)
	return true


func _update_ult(dt: float) -> void:
	if cls == "pyrewitch":
		_trail_t -= dt
		if _trail_t <= 0.0 and moving:
			_trail_t = 0.14
			world.spawn_hazard("fire_pool", global_position, {"radius": 40.0, "duration": 2.5, "dps": 30.0 * dmg_mult(), "team": Team.PLAYER, "src": self})
		if randf() < 0.9:
			world.glow_fx.emit(global_position + Vector2(randf_range(-14, 14), randf_range(-50, -10)), Vector2(randf_range(-30, 30), -90), 0.6, 3.5, Color(3.0, 1.0, 0.25), Particles.EMBER, 1.0)
		if ult_t <= 0.0:
			world.area_damage(global_position, 190.0 * area_mult(), 60.0 * dmg_mult(), self, Team.PLAYER, {"type": "fire", "knock_force": 400.0})
			world.glow_fx.ring(global_position, 190.0 * area_mult(), Color(3.0, 1.0, 0.25, 1.0), 0.5)
			world.glow_fx.burst(global_position, 40, Color(3.0, 1.0, 0.25), 120, 500, 0.6, 3.0, Particles.SPARK)
			Sfx.play("explode")
			world.shake(8.0)


# ---------------------------------------------------------------- damage in / out

func incoming(dmg: float, src: Actor, opts: Dictionary) -> float:
	if dodge_t > 0.0 or invuln_t > 0.0 or dead:
		return 0.0
	var d := dmg
	if buffs.has("warding"):
		d *= 0.5
	if frag("haste"):
		d *= 1.15
	if molten_t > 0.0 and has_mod("molten_long"):
		d *= 0.85
	if oath_t > 0.0:
		var blocked := d * 0.6
		oath_stored += blocked
		d -= blocked
	if cls == "knight":
		resource = minf(res_max, resource + 3.0)
	Game.stats.damage_taken += d
	if src and opts.get("melee", false) and src is Enemy:
		if molten_t > 0.0:
			world.damage(src, 20.0 * dmg_mult(), self, {"type": "fire", "burn": [8.0, 3.0], "can_crit": false})
		if frag("thorns"):
			world.damage(src, dmg * 0.6, self, {"type": "phys", "can_crit": false})
	return d


func on_damaged(amount: float, _src: Actor, _opts: Dictionary) -> void:
	if amount >= 1.0 and hurt_t <= 0.0:
		hurt_t = 0.25
		Sfx.play("hurt", -6.0)
		# now and then the hero cries out, in their own voice
		if _voice_cd <= 0.0 and randf() < 0.3:
			_voice_cd = 2.0
			Sfx.play("hurt_" + ("pyrewitch" if cls == "pyrewitch" else ("gravecaller" if cls == "gravecaller" else "knight")), -2.0, 0.06)
		world.shake(3.0 + minf(8.0, amount / max_hp * 60.0))


func die(_src: Actor) -> void:
	dead = true
	world.smoke_fx.burst(global_position, 30, Color(0.3, 0.28, 0.27, 0.9), 40, 160, 1.6, 14, Particles.SMOKE)
	world.glow_fx.burst(global_position, 30, Color(3.0, 1.0, 0.3), 60, 300, 1.0, 3.0, Particles.SPARK)
	visible = false


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if dead:
		return
	draw_shadow()
	var bob := sin(anim * 11.0) * 1.6 if moving else sin(anim * 2.0) * 0.6
	var step := sin(anim * 11.0) if moving else 0.0
	var side := 1.0 if aim_dir.x >= 0.0 else -1.0
	var a := 0.45 if dodge_t > 0.0 else 1.0
	match cls:
		"knight":
			_draw_knight(bob, step, side, a)
		"crownbearer":
			_draw_knight(bob, step, side, a)
			var cy := -62.0 + bob
			var gold := Color(1.0, 0.8, 0.25, a)
			draw_colored_polygon(PackedVector2Array([Vector2(-10, cy), Vector2(-12, cy - 12), Vector2(-5, cy - 6), Vector2(0, cy - 15), Vector2(5, cy - 6), Vector2(12, cy - 12), Vector2(10, cy)]), gold)
		"gravecaller":
			_draw_gravecaller(bob, step, side, a)
		"pyrewitch":
			_draw_witch(bob, step, side, a)
	draw_status_marks()


func _c(c: Color, a: float) -> Color:
	var s := shade(c)
	s.a *= a
	return s


func _mirror(pts: Array, side: float, y: float) -> PackedVector2Array:
	# Shapes are drawn facing right; this turns them to face the way the hero is aiming.
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * side, p.y + y))
	if side < 0.0:
		out.reverse()
	return out


func _draw_knight(bob: float, step: float, side: float, a: float) -> void:
	var steel := _c(Color(0.37, 0.36, 0.385), a)
	var iron := _c(Color(0.15, 0.14, 0.15), a)
	var cloth := _c(Game.accent_color(), a)
	var line := Color(Ink.LINE.r, Ink.LINE.g, Ink.LINE.b, a)
	var y := -18.0 + bob
	var sway := step * 3.0
	# A cloak in the house colour, torn at the hem, trailing a beat behind the stride
	Ink.shape(self, PackedVector2Array([Vector2(-13, y - 25), Vector2(13, y - 25), Vector2(15 - sway, y + 6), Vector2(9 - sway, y + 13), Vector2(3 - sway, y + 7),
		Vector2(-4 - sway, y + 14), Vector2(-10 - sway, y + 8), Vector2(-15 - sway, y + 11)]), cloth.darkened(0.3), cloth.darkened(0.72), 2.0, line)
	Ink.limb(self, Vector2(-7, -19), Vector2(-7 + step * 5.0, 0), 8.0, 6.0, iron.lightened(0.16), iron, 1.8, line)
	Ink.limb(self, Vector2(7, -19), Vector2(7 - step * 5.0, 0), 8.0, 6.0, iron.lightened(0.16), iron, 1.8, line)
	var chest := PackedVector2Array([Vector2(-13, y), Vector2(13, y), Vector2(16, y - 14), Vector2(14, y - 27), Vector2(-14, y - 27), Vector2(-16, y - 14)])
	Ink.shape(self, chest, steel.lightened(0.1), steel.darkened(0.5), 2.0, line)
	Ink.shape(self, PackedVector2Array([Vector2(-6, y + 5), Vector2(6, y + 5), Vector2(5, y - 22), Vector2(-5, y - 22)]), cloth.lightened(0.08), cloth.darkened(0.45), 1.5, line)
	draw_line(Vector2(-13, y - 2), Vector2(13, y - 2), _c(Color(0.2, 0.13, 0.08), a), 3.0, true)
	draw_rect(Rect2(-2.5, y - 4.5, 5, 5), _c(Color(0.62, 0.5, 0.26), a))
	Ink.oval(self, Vector2(-16, y - 24), 8.5, 7.5, steel.lightened(0.22), steel.darkened(0.3), 2.0, 0.0, line)
	Ink.oval(self, Vector2(16, y - 24), 8.5, 7.5, steel.lightened(0.22), steel.darkened(0.3), 2.0, 0.0, line)
	# Great helm: a ridge down the face, a slit to see through, holes to breathe through
	Ink.shape(self, PackedVector2Array([Vector2(-9, y - 27), Vector2(9, y - 27), Vector2(10, y - 42), Vector2(7, y - 51), Vector2(0, y - 54), Vector2(-7, y - 51), Vector2(-10, y - 42)]),
		steel.lightened(0.24), steel.darkened(0.25), 2.0, line)
	draw_line(Vector2(0, y - 53), Vector2(0, y - 29), _c(Color(0.16, 0.15, 0.16), a), 1.5, true)
	draw_line(Vector2(-7.5, y - 40), Vector2(7.5, y - 40), _c(Color(0.02, 0.015, 0.015), a), 3.2, true)
	for i in 3:
		Ink.dot(self, Vector2(side * (2.5 + i * 2.2), y - 33.5), 0.8, _c(Color(0.05, 0.045, 0.05), a))
	draw_line(Vector2(-8.5, y - 47), Vector2(-5.5, y - 51), Color(1, 1, 1, 0.3 * a), 1.3, true)
	Ink.shape(self, _mirror([Vector2(0, -54), Vector2(-4, -61), Vector2(-14, -56), Vector2(-10, -49)], side, y), cloth.lightened(0.1), cloth.darkened(0.35), 1.5, line)
	# Kite shield on the off hand
	var sx := -side * 18.0
	var shield := PackedVector2Array([Vector2(sx - 11, y - 31), Vector2(sx + 11, y - 31), Vector2(sx + 11, y - 13), Vector2(sx, y + 3), Vector2(sx - 11, y - 13)])
	Ink.shape(self, shield, _c(Color(0.25, 0.21, 0.2), a), _c(Color(0.1, 0.085, 0.085), a), 2.2, line)
	var trim := PackedVector2Array([Vector2(sx - 8, y - 28), Vector2(sx + 8, y - 28), Vector2(sx + 8, y - 14), Vector2(sx, y - 2), Vector2(sx - 8, y - 14), Vector2(sx - 8, y - 28)])
	draw_polyline(trim, _c(Color(0.56, 0.43, 0.23), a), 1.6, true)
	draw_line(Vector2(sx, y - 26), Vector2(sx, y - 6), cloth, 2.5, true)
	draw_line(Vector2(sx - 6, y - 20), Vector2(sx + 6, y - 20), cloth, 2.5, true)
	# Sword
	var hand := Vector2(side * 16.0, y - 16)
	var ang := aim_dir.angle()
	if swing_t > 0.0:
		var k := 1.0 - swing_t / 0.24
		ang = swing_dir.angle() + swing_side * lerpf(-1.3, 1.3, ease(k, 0.4))
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := dir.orthogonal()
	var blade := PackedVector2Array([hand + nrm * 2.8, hand + dir * 45.0 + nrm * 2.2, hand + dir * 53.0, hand + dir * 45.0 - nrm * 2.2, hand - nrm * 2.8])
	Ink.shape(self, blade, _c(Color(0.8, 0.78, 0.76), a), _c(Color(0.5, 0.49, 0.52), a), 1.5, line)
	draw_line(hand + dir * 5.0, hand + dir * 42.0, _c(Color(0.32, 0.32, 0.35), a), 1.0, true)
	draw_line(hand - nrm * 8.0, hand + nrm * 8.0, line, 5.0, true)
	draw_line(hand - nrm * 7.0, hand + nrm * 7.0, _c(Color(0.56, 0.43, 0.23), a), 2.6, true)
	Ink.dot(self, hand - dir * 6.0, 2.6, _c(Color(0.56, 0.43, 0.23), a))
	Ink.oval(self, hand - dir * 1.5, 4.5, 4.5, steel.lightened(0.1), steel.darkened(0.3), 1.5, 0.0, line)


func _draw_gravecaller(bob: float, step: float, side: float, a: float) -> void:
	var robe := _c(Color(0.17, 0.195, 0.21), a)
	var line := Color(Ink.LINE.r, Ink.LINE.g, Ink.LINE.b, a)
	var bone := _c(Color(0.8, 0.77, 0.68), a)
	var y := -6.0 + bob
	var sway := step * 3.0
	Ink.shape(self, PackedVector2Array([Vector2(-11, y - 30), Vector2(11, y - 30), Vector2(14, y - 12), Vector2(17 + sway, 0), Vector2(11 + sway, 3), Vector2(6 + sway, -1), Vector2(sway, 4),
		Vector2(-6 + sway, -1), Vector2(-12 + sway, 3), Vector2(-17 + sway, -1), Vector2(-14, y - 12)]), robe.lightened(0.12), robe.darkened(0.55), 2.0, line)
	var stole := _c(Game.accent_color().lerp(Color(0.22, 0.25, 0.25), 0.5), a)
	Ink.shape(self, PackedVector2Array([Vector2(-4 + sway * 0.6, 0), Vector2(4 + sway * 0.6, 0), Vector2(3, y - 28), Vector2(-3, y - 28)]), stole.lightened(0.1), stole.darkened(0.4), 1.3, line)
	# A mantle over the shoulders, strung with knucklebones
	Ink.shape(self, PackedVector2Array([Vector2(-14, y - 23), Vector2(0, y - 19), Vector2(14, y - 23), Vector2(11, y - 33), Vector2(-11, y - 33)]), robe.lightened(0.22), robe.darkened(0.2), 1.6, line)
	for i in 5:
		Ink.dot(self, Vector2(-10 + i * 5.0, y - 22.5 + absf(i - 2.0) * -1.2), 1.5, bone)
	Ink.shape(self, _mirror([Vector2(-12, -30), Vector2(12, -30), Vector2(11, -46), Vector2(5, -59), Vector2(-2, -56), Vector2(-11, -47)], side, y), robe.lightened(0.2), robe.darkened(0.3), 2.0, line)
	Ink.oval(self, Vector2(side * 2.0, y - 41), 6.5, 7.5, _c(Color(0.015, 0.018, 0.022), a), _c(Color(0.015, 0.018, 0.022), a), 0.0)
	# A staff of black wood with a skull bound to its head
	var hx := side * 16.0
	var lift := -6.0 if swing_t > 0.0 else 0.0
	Ink.limb(self, Vector2(hx, 3 + lift), Vector2(hx, y - 58 + lift), 4.0, 3.2, _c(Color(0.26, 0.21, 0.17), a), _c(Color(0.1, 0.08, 0.065), a), 1.6, line)
	draw_line(Vector2(hx - 3, y - 50 + lift), Vector2(hx + 3, y - 54 + lift), _c(Color(0.42, 0.34, 0.2), a), 1.5, true)
	draw_line(Vector2(hx - 3, y - 54 + lift), Vector2(hx + 3, y - 50 + lift), _c(Color(0.42, 0.34, 0.2), a), 1.5, true)
	Ink.oval(self, Vector2(hx, y - 64 + lift), 6.0, 6.5, bone, bone.darkened(0.4), 1.6, 0.0, line)
	draw_rect(Rect2(hx - 3.5, y - 59.5 + lift, 7, 3.5), bone.darkened(0.25))
	Ink.dot(self, Vector2(hx - 2.3, y - 64.5 + lift), 1.6, _c(Color(0.03, 0.03, 0.03), a))
	Ink.dot(self, Vector2(hx + 2.3, y - 64.5 + lift), 1.6, _c(Color(0.03, 0.03, 0.03), a))
	Ink.oval(self, Vector2(hx, y - 26 + lift), 3.8, 3.8, robe.lightened(0.25), robe, 1.4, 0.0, line)


func _draw_witch(bob: float, step: float, side: float, a: float) -> void:
	var robe := _c(Color(0.28, 0.095, 0.085), a)
	var hat := _c(Color(0.13, 0.085, 0.085), a)
	var line := Color(Ink.LINE.r, Ink.LINE.g, Ink.LINE.b, a)
	var y := -6.0 + bob
	var sway := step * 3.0
	Ink.shape(self, _mirror([Vector2(-8, -40), Vector2(8, -40), Vector2(-3, -25), Vector2(-15, -13), Vector2(-12, -30)], side, y), _c(Game.hair_color(), a).lightened(0.1), _c(Game.hair_color(), a).darkened(0.4), 1.5, line)
	# A dress scorched black along the hem
	Ink.shape(self, PackedVector2Array([Vector2(-9, y - 30), Vector2(9, y - 30), Vector2(12, y - 14), Vector2(16 + sway, 0), Vector2(10 + sway, 3), Vector2(5 + sway, -1), Vector2(sway, 4),
		Vector2(-5 + sway, -1), Vector2(-11 + sway, 3), Vector2(-16 + sway, -1), Vector2(-12, y - 14)]), robe.lightened(0.14), _c(Color(0.05, 0.03, 0.03), a), 2.0, line)
	draw_line(Vector2(-11.5, y - 15), Vector2(11.5, y - 15), _c(Color(0.6, 0.45, 0.2), a), 2.0, true)
	draw_line(Vector2(-2, y - 15), Vector2(-4 + sway * 0.5, y - 5), _c(Color(0.6, 0.45, 0.2), a), 1.4, true)
	var skin := _c(Game.skin_color(), a)
	Ink.oval(self, Vector2(0, y - 36), 7.5, 8.0, skin.lightened(0.08), skin.darkened(0.3), 1.6, 0.0, line)
	# Wide brim, and a point that has long since given up standing straight
	Ink.oval(self, Vector2(0, y - 43), 21.0, 6.5, hat.lightened(0.12), hat.darkened(0.3), 2.0, 0.0, line)
	Ink.shape(self, _mirror([Vector2(-10, -45), Vector2(10, -45), Vector2(6, -58), Vector2(-1, -66), Vector2(-12, -73), Vector2(-5, -62), Vector2(-7, -56)], side, y), hat.lightened(0.18), hat.darkened(0.25), 2.0, line)
	draw_line(Vector2(-9.5, y - 47.5), Vector2(9.5, y - 47.5), _c(Color(0.62, 0.24, 0.1), a), 2.6, true)
	var hand := Vector2(side * 10.0, y - 22) + aim_dir * (10.0 + (8.0 if swing_t > 0.0 else 0.0))
	Ink.limb(self, Vector2(side * 8.0, y - 27), hand, 6.0, 4.0, robe.lightened(0.18), robe.darkened(0.2), 1.6, line)
	Ink.oval(self, hand, 3.2, 3.2, skin, skin.darkened(0.3), 1.3, 0.0, line)


func _draw_glow() -> void:
	if dead:
		return
	var bob := sin(anim * 11.0) * 1.6 if moving else sin(anim * 2.0) * 0.6
	var side := 1.0 if aim_dir.x >= 0.0 else -1.0
	match cls:
		"knight", "crownbearer":
			var y := -18.0 + bob
			Ink.glow(glow, Vector2(0, y - 40), 11.0, Color(1.5, 0.5, 0.12, 0.4))
			glow.draw_line(Vector2(-6, y - 40), Vector2(6, y - 40), Color(3.0, 1.2, 0.3), 2.0, true)
			if molten_t > 0.0:
				var r := molten_radius()
				glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
				Ink.dot(glow, Vector2.ZERO, r, Color(1.0, 0.25, 0.05, 0.12))
				glow.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(2.4, 0.7, 0.15, 0.4), 2.0, true)
				glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				glow.draw_line(Vector2(-12, y - 2), Vector2(12, y - 22), Color(2.6, 0.7, 0.15, 0.7), 2.0)
			if oath_t > 0.0:
				var pulse := 0.6 + 0.4 * sin(anim * 14.0)
				glow.draw_arc(Vector2(0, -24), 40.0, 0.0, TAU, 40, Color(3.0, 1.5, 0.5, 0.6 * pulse), 3.0, true)
			if swing_t > 0.0:
				var k := 1.0 - swing_t / 0.24
				var reach := 108.0 * area_mult() * (1.15 if has_mod("cleave_wide") else 1.0)
				var base := swing_dir.angle()
				var a0 := base - swing_side * 1.2
				var a1 := base - swing_side * 1.2 + swing_side * 2.4 * ease(k, 0.4)
				var c := Color(3.0, 1.1, 0.3, 0.8 * (1.0 - k))
				glow.draw_arc(Vector2(0, -24), reach * 0.85, minf(a0, a1), maxf(a0, a1), 24, c, 10.0 * (1.0 - k) + 2.0, true)
		"gravecaller":
			var y2 := -6.0 + bob
			var lift := -6.0 if swing_t > 0.0 else 0.0
			Ink.dot(glow, Vector2(side * 2.0 - 3.0, y2 - 42), 1.6, Color(1.0, 3.0, 2.6))
			Ink.dot(glow, Vector2(side * 2.0 + 3.0, y2 - 42), 1.6, Color(1.0, 3.0, 2.6))
			var fp := Vector2(side * 16.0, y2 - 72 + lift)
			var f := 1.0 + 0.15 * sin(anim * 13.0)
			Ink.glow(glow, fp, 20.0 * f, Color(0.4, 1.4, 1.3, 0.4))
			Ink.flame(glow, fp + Vector2(0, 5), 5.5, 15.0, anim, 1.0, Color(1.2, 3.0, 2.7, 0.95), Color(0.5, 1.8, 1.6, 0.8))
			Ink.flame(glow, fp + Vector2(0, 5), 2.8, 9.0, anim, 3.0, Color(2.6, 3.4, 3.2), Color(1.2, 3.0, 2.7, 0.9))
		"pyrewitch":
			var y3 := -6.0 + bob
			var hand := Vector2(side * 10.0, y3 - 22) + aim_dir * (10.0 + (8.0 if swing_t > 0.0 else 0.0))
			var heat := resource / 100.0
			Ink.glow(glow, hand, 22.0 + heat * 14.0, Color(1.6, 0.4, 0.1, 0.45))
			Ink.flame(glow, hand + Vector2(0, 3), 4.5 + heat * 3.0, 12.0 + heat * 10.0, anim, 2.0, Color(3.0, 1.0 + heat, 0.25, 0.95), Color(2.4, 0.6, 0.12, 0.8))
			Ink.dot(glow, hand, 2.6 + heat * 2.0, Color(3.6, 2.2 + heat, 0.8))
			Ink.dot(glow, Vector2(side * 3.0, y3 - 37), 1.4, Color(3.5, 1.5, 0.4))
			if ult_t > 0.0:
				for i in 3:
					var w := sin(anim * 8.0 + i * 2.0) * 10.0
					Ink.tri(glow, Vector2(-14 + i * 14, -6), Vector2(-4 + i * 14, -6), Vector2(-9 + i * 14 + w, -70 - i * 6), Color(3.0, 0.9 + i * 0.4, 0.2, 0.55))
				Ink.glow(glow, Vector2(0, -30), 52.0, Color(1.6, 0.4, 0.1, 0.32))
	if invuln_t > 0.0 and int(anim * 20.0) % 2 == 0:
		glow.draw_arc(Vector2(0, -24), 28.0, 0.0, TAU, 24, Color(2.0, 1.6, 1.2, 0.35), 2.0, true)
