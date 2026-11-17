class_name World
extends Node2D
## One zone: map, entities, combat resolution, camera and lighting.

signal player_died
signal level_up
signal fragment_ready
signal zone_exit
signal boss_started
signal boss_defeated
signal banner(title: String, sub: String)

const CELL := 64.0
const ACTIVATE_DIST := 900.0
const UPDATE_DIST := 2000.0

static var unshaded_add: CanvasItemMaterial
static var unshaded: CanvasItemMaterial
static var light_tex: Texture2D

var zone: Dictionary
var zone_idx := 0
var map: MapGen
var player: Player
var enemies: Array[Enemy] = []
var minions: Array[Minion] = []
var projectiles: Array[Projectile] = []
var hazards: Array[Hazard] = []
var pickups: Array[Pickup] = []
var props: Array[Prop] = []
var interactives: Array[Prop] = []
var prop_cells := {}
var blocked := {}
var corpses: Array[Dictionary] = []
var boss: Enemy
var champion: Enemy
var state := "explore"
var objective := ""
var attract := false
var running := true

var camera: Camera2D
var entity_layer: Node2D
var decals: Decals
var glow_fx: Particles
var smoke_fx: Particles
var texts: FloatText
var ground: ColorRect
var veins: ColorRect
var canvas_mod: CanvasModulate

var hitstop_t := 0.0
var shake_amt := 0.0
var flow := PackedInt32Array()
var flow_stamp := PackedInt32Array()
var flow_id := 0
var flow_timer := 0.0
var flow_cell := Vector2i(-1, -1)
var minimap_img: Image
var minimap_tex: ImageTexture
var _minimap_dirty := false
var _minimap_timer := 0.0
var _reveal_cell := Vector2i(-99, -99)
var _activate_timer := 0.0
var arena_center := Vector2.ZERO
var arena_radius := 0.0
var _attract_t := 0.0
var _flask_kills := 0
var _ambient: Array[CPUParticles2D] = []


static func init_static() -> void:
	unshaded_add = CanvasItemMaterial.new()
	unshaded_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	unshaded = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	light_tex = t


func make_light(color: Color, energy: float, size_px: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.color = color
	l.energy = energy
	l.texture_scale = size_px / 256.0
	l.shadow_enabled = false
	return l


# ================================================================ setup

func setup(idx: int, is_attract := false) -> void:
	zone_idx = idx
	zone = Data.ZONES[idx]
	attract = is_attract
	map = MapGen.new()
	map.generate(zone, randi() if not is_attract else 4242)
	_build_layers()
	_build_props()
	if attract:
		camera.global_position = _cell_pos(map.nodes[1])
		return
	_spawn_packs()
	_place_shrines()
	_place_finale()
	player = Player.new()
	player.world = self
	player.setup(Game.class_id)
	entity_layer.add_child(player)
	player.global_position = _cell_pos(map.start)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	_set_objective()
	_reveal()


func _cell_pos(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _build_layers() -> void:
	var size_px := Vector2(map.w, map.h) * CELL
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = zone.modulate
	add_child(canvas_mod)

	var mask := ImageTexture.create_from_image(map.mask_image())
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/ground.gdshader")
	gm.set_shader_parameter("mask", mask)
	gm.set_shader_parameter("col_a", zone.ground_a)
	gm.set_shader_parameter("col_b", zone.ground_b)
	gm.set_shader_parameter("col_wall", zone.wall)
	gm.set_shader_parameter("pattern", zone.pattern)
	gm.set_shader_parameter("map_px", size_px)
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/veins.gdshader")
	var vc: Color = zone.vein
	var hdr := maxf(vc.r, maxf(vc.g, vc.b))
	vm.set_shader_parameter("mask", mask)
	vm.set_shader_parameter("vein", Color(vc.r / hdr, vc.g / hdr, vc.b / hdr))
	vm.set_shader_parameter("vein_hdr", hdr)
	vm.set_shader_parameter("amount", zone.vein_amt)
	vm.set_shader_parameter("pattern", zone.pattern)
	vm.set_shader_parameter("map_px", size_px)
	# The ground is split into chunks: 2D lights only reach a limited number of lights per canvas item.
	var chunk := 768.0
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	veins = ColorRect.new()
	veins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veins)
	var cy := 0.0
	while cy < size_px.y:
		var cx := 0.0
		while cx < size_px.x:
			var g := ColorRect.new()
			g.position = Vector2(cx, cy)
			g.size = Vector2(minf(chunk, size_px.x - cx), minf(chunk, size_px.y - cy))
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.material = gm
			ground.add_child(g)
			var v := ColorRect.new()
			v.position = g.position
			v.size = g.size
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.material = vm
			veins.add_child(v)
			cx += chunk
		cy += chunk

	decals = Decals.new()
	decals.world = self
	add_child(decals)

	smoke_fx = Particles.new()
	smoke_fx.setup(false)
	smoke_fx.max_count = 3200
	smoke_fx.z_index = 2
	glow_fx = Particles.new()
	glow_fx.setup(true)
	glow_fx.z_index = 3

	entity_layer = Node2D.new()
	entity_layer.y_sort_enabled = true
	add_child(entity_layer)
	add_child(smoke_fx)
	add_child(glow_fx)

	texts = FloatText.new()
	texts.z_index = 10
	texts.material = unshaded
	add_child(texts)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	camera.make_current()
	_build_ambient()

	minimap_img = Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
	minimap_img.fill(Color(0, 0, 0, 0))
	minimap_tex = ImageTexture.create_from_image(minimap_img)
	flow.resize(map.w * map.h)
	flow_stamp.resize(map.w * map.h)


func _build_ambient() -> void:
	var ash := CPUParticles2D.new()
	ash.amount = 260
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(900, 600)
	ash.direction = Vector2(0.4, 1.0)
	ash.spread = 25.0
	ash.initial_velocity_min = 12.0
	ash.initial_velocity_max = 34.0
	ash.gravity = Vector2(8, 6)
	ash.scale_amount_min = 1.2
	ash.scale_amount_max = 3.2
	ash.angular_velocity_min = -90
	ash.angular_velocity_max = 90
	ash.color = Color(0.8, 0.77, 0.74, 0.55)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ash.color_ramp = ramp
	ash.z_index = 5
	camera.add_child(ash)

	var embers := CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.local_coords = false
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(900, 600)
	embers.direction = Vector2(0.2, -1.0)
	embers.spread = 40.0
	embers.initial_velocity_min = 10.0
	embers.initial_velocity_max = 40.0
	embers.gravity = Vector2(6, -10)
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	var vc: Color = zone.vein
	embers.color = Color(vc.r, vc.g, vc.b, 1.0)
	var ramp2 := Gradient.new()
	ramp2.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	ramp2.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	embers.color_ramp = ramp2
	embers.material = unshaded_add
	embers.z_index = 5
	camera.add_child(embers)
	_ambient = [ash, embers]


func _build_props() -> void:
	for d in map.props:
		var p := Prop.new()
		p.world = self
		p.kind = d.kind
		p.seed_value = d.seed
		entity_layer.add_child(p)
		p.global_position = d.pos
		p.init()
		props.append(p)
		if p.radius > 0.0:
			var c := Vector2i(d.pos / CELL)
			if not prop_cells.has(c):
				prop_cells[c] = []
			prop_cells[c].append(p)
			if p.radius > 0.0:
				blocked[c] = true


func add_prop(kind: String, pos: Vector2) -> Prop:
	var p := Prop.new()
	p.world = self
	p.kind = kind
	p.seed_value = randi()
	entity_layer.add_child(p)
	p.global_position = pos
	p.init()
	props.append(p)
	interactives.append(p)
	return p


func _spawn_packs() -> void:
	var pool: Dictionary = zone.pool
	var kinds: Array = pool.keys()
	var total := 0
	for k in kinds:
		total += int(pool[k])
	var pack_id := 0
	for c in map.packs:
		pack_id += 1
		var center: Vector2 = (c + Vector2(0.5, 0.5)) * CELL
		var main_kind := _weighted(kinds, pool, total)
		var second := _weighted(kinds, pool, total)
		var n := randi_range(4, 7)
		if main_kind == "brute":
			n = randi_range(1, 2)
		var elite := randf() < 0.14
		for i in n:
			var kind := main_kind if i < n - 2 or n <= 3 else second
			if kind == "brute" and i > 1:
				kind = "husk"
			var pos := center + Vector2(randf_range(-110, 110), randf_range(-110, 110))
			if not is_floor_at(pos):
				pos = center
			var e := spawn_enemy(kind, pos, false)
			e.pack = pack_id
		if elite:
			var ek := main_kind if main_kind != "brute" else "husk"
			var e2 := spawn_enemy(ek, center, false)
			e2.make_elite()
			e2.pack = pack_id


func _weighted(kinds: Array, pool: Dictionary, total: int) -> String:
	var r := randi_range(1, total)
	for k in kinds:
		r -= int(pool[k])
		if r <= 0:
			return k
	return kinds[0]


func _place_shrines() -> void:
	var kinds := ["fury", "warding", "haste"]
	kinds.shuffle()
	var spots := map.branches.duplicate()
	spots.shuffle()
	var placed := 0
	for b in spots:
		if placed >= 3:
			break
		if not map.is_floor(b.x, b.y):
			continue
		var p := add_prop("shrine_" + kinds[placed], _cell_pos(b))
		p.radius = 0.0
		placed += 1


func _place_finale() -> void:
	var c := _cell_pos(map.finish)
	arena_center = c
	arena_radius = 13.0 * CELL
	if zone_idx == Data.ZONES.size() - 1:
		boss = spawn_enemy("ember_king", c + Vector2(0, -140), true)
		boss.sleeping = true
		boss.pack = -1
		var throne := add_prop("throne", c + Vector2(0, -175))
		throne.radius = 0.0
		interactives.erase(throne)
	else:
		var ch: Dictionary = zone.champion
		champion = spawn_enemy(ch.kind, c, true)
		champion.make_champion(ch.name, ch.scale)
		champion.pack = 999
		for i in 6:
			var a := TAU * i / 6.0
			var kinds: Array = zone.pool.keys()
			var k: String = kinds[i % kinds.size()]
			if k == "brute":
				k = "husk"
			var e := spawn_enemy(k, c + Vector2(cos(a), sin(a)) * 180.0, false)
			e.pack = 999


func _set_objective() -> void:
	if zone_idx == Data.ZONES.size() - 1:
		objective = "Find the Ember King" if state == "explore" else ("Kill the Ember King" if state == "boss" else "")
	elif champion and not champion.dead:
		objective = "Slay %s" % champion.display_name
	elif state == "altar":
		objective = "Claim the crown fragment"
	else:
		objective = "Descend"


# ================================================================ spawning

func spawn_enemy(kind: String, pos: Vector2, special: bool) -> Enemy:
	var e: Enemy
	if kind == "ember_king":
		e = Boss.new()
	else:
		e = Enemy.new()
	e.world = self
	e.setup(kind, zone.hp_mult * (1.25 if Game.fragments.has("greed") else 1.0), zone.dmg_mult)
	entity_layer.add_child(e)
	e.global_position = pos
	enemies.append(e)
	if special:
		e.sleeping = false
	return e


func spawn_minion(kind: String, pos: Vector2, life := -1.0) -> Minion:
	var m := Minion.new()
	m.world = self
	m.setup(kind, life)
	entity_layer.add_child(m)
	m.global_position = world_clamp(pos)
	minions.append(m)
	return m


func spawn_projectile(kind: String, pos: Vector2, dir: Vector2, speed: float, dmg: float, team: int, opts := {}) -> Projectile:
	var p := Projectile.new()
	p.world = self
	p.kind = kind
	p.dir = dir.normalized()
	p.speed = speed
	p.dmg = dmg
	p.team = team
	p.opts = opts
	add_child(p)
	p.global_position = pos
	p.init()
	projectiles.append(p)
	return p


func spawn_hazard(kind: String, pos: Vector2, opts := {}) -> Hazard:
	var h := Hazard.new()
	h.world = self
	h.kind = kind
	h.opts = opts
	add_child(h)
	move_child(h, entity_layer.get_index())
	h.global_position = pos
	h.init()
	hazards.append(h)
	return h


func drop_globe(pos: Vector2) -> void:
	var p := Pickup.new()
	p.world = self
	p.kind = "globe"
	entity_layer.add_child(p)
	p.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	pickups.append(p)


# ================================================================ main loop

func _process(delta: float) -> void:
	if not running:
		return
	var dt := minf(delta, 1.0 / 30.0)
	if hitstop_t > 0.0:
		hitstop_t -= delta
		dt *= 0.08
	if attract:
		_update_attract(dt)
	else:
		_update_game(dt)
	glow_fx.view_rect = view_rect()
	smoke_fx.view_rect = glow_fx.view_rect
	glow_fx.update(dt)
	smoke_fx.update(dt)
	texts.update(dt)
	decals.update(dt)
	_update_camera(delta)


func _update_attract(dt: float) -> void:
	_attract_t += dt * 0.035
	var n := map.nodes.size()
	var f := fmod(_attract_t, float(n - 1))
	var i := int(f)
	var target := _cell_pos(map.nodes[i]).lerp(_cell_pos(map.nodes[mini(i + 1, n - 1)]), smoothstep(0.0, 1.0, f - i))
	camera.global_position = camera.global_position.lerp(target, dt * 0.6)
	for p in props:
		p.update(dt)


func _update_game(dt: float) -> void:
	Game.stats.time += dt
	if player and not player.dead:
		player.update(dt)
	_update_flow(dt)
	_activate_timer -= dt
	if _activate_timer <= 0.0:
		_activate_timer = 0.2
		_activate_packs()
	var pp := player.global_position
	var active: Array[Enemy] = []
	for e in enemies:
		if e.dead:
			continue
		if e.global_position.distance_squared_to(pp) > UPDATE_DIST * UPDATE_DIST and not e.is_boss:
			continue
		e.update(dt)
		if not e.sleeping:
			active.append(e)
	_separate(active)
	for m in minions:
		if not m.dead:
			m.update(dt)
	for p in projectiles:
		p.update(dt)
	for h in hazards:
		h.update(dt)
	for p in pickups:
		p.update(dt)
	for p in props:
		if p.global_position.distance_squared_to(pp) < 1600.0 * 1600.0:
			p.update(dt)
	_cleanup()
	_check_interactives()
	_update_boss_gate()
	_minimap_timer -= dt
	if _minimap_timer <= 0.0:
		_minimap_timer = 0.15
		_reveal()
		if _minimap_dirty:
			_minimap_dirty = false
			minimap_tex.update(minimap_img)
	for i in range(corpses.size() - 1, -1, -1):
		corpses[i].t -= dt
		if corpses[i].t <= 0.0:
			corpses.remove_at(i)


func _cleanup() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].dead:
			enemies[i].queue_free()
			enemies.remove_at(i)
	for i in range(minions.size() - 1, -1, -1):
		if minions[i].dead:
			minions[i].queue_free()
			minions.remove_at(i)
	for i in range(projectiles.size() - 1, -1, -1):
		if projectiles[i].done:
			projectiles[i].queue_free()
			projectiles.remove_at(i)
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i].done:
			hazards[i].queue_free()
			hazards.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		if pickups[i].done:
			pickups[i].queue_free()
			pickups.remove_at(i)


func _activate_packs() -> void:
	var pp := player.global_position
	var woken := {}
	for e in enemies:
		if e.sleeping and not e.dead and e.pack >= 0 and e.global_position.distance_squared_to(pp) < ACTIVATE_DIST * ACTIVATE_DIST:
			if los(e.global_position, pp):
				woken[e.pack] = true
	if woken.is_empty():
		return
	for e in enemies:
		if e.sleeping and woken.has(e.pack):
			e.wake()
			if e == champion:
				banner.emit(champion.display_name, "")
				Sfx.play("roar", -4.0)
	Sfx.play("growl", -8.0, 0.15)


func alert_pack(pack: int) -> void:
	var woke: Enemy = null
	for e in enemies:
		if e.sleeping and e.pack == pack and pack >= 0:
			e.wake()
			woke = e
	# The pack notices you: one of them snarls.
	if woke and player and woke.global_position.distance_to(player.global_position) < 900.0:
		Sfx.play("growl", -7.0, 0.15, 1.15 - minf(0.4, woke.radius / 80.0))


func _separate(list: Array[Enemy]) -> void:
	var n := list.size()
	for i in n:
		var a := list[i]
		for j in range(i + 1, n):
			var b := list[j]
			var d := b.global_position - a.global_position
			var rr := a.radius + b.radius
			var l2 := d.length_squared()
			if l2 < rr * rr and l2 > 0.01:
				var l := sqrt(l2)
				var push := d / l * (rr - l) * 0.5
				var wa := 0.2 if a.heavy else 1.0
				var wb := 0.2 if b.heavy else 1.0
				a.global_position = world_clamp_soft(a.global_position - push * wa, a.radius)
				b.global_position = world_clamp_soft(b.global_position + push * wb, b.radius)
	if player and not player.dead:
		for a in list:
			var d := a.global_position - player.global_position
			var rr := a.radius + player.radius
			if d.length_squared() < rr * rr and d.length_squared() > 0.01:
				a.global_position = world_clamp_soft(player.global_position + d.normalized() * rr, a.radius)


func _check_interactives() -> void:
	if not player or player.dead:
		return
	for p in interactives:
		if p.used:
			continue
		if p.global_position.distance_to(player.global_position) < 70.0:
			p.used = true
			match p.kind:
				"altar":
					Sfx.play("fragment")
					fragment_ready.emit()
				"portal":
					zone_exit.emit()
				"shrine_fury":
					player.add_buff("fury", 30.0)
					banner.emit("Shrine of Fury", "Damage increased for 30 seconds")
					Sfx.play("levelup", -4.0)
				"shrine_warding":
					player.add_buff("warding", 30.0)
					banner.emit("Shrine of Warding", "Damage taken reduced for 30 seconds")
					Sfx.play("levelup", -4.0)
				"shrine_haste":
					player.add_buff("haste", 30.0)
					banner.emit("Shrine of Haste", "Faster movement and cooldowns for 30 seconds")
					Sfx.play("levelup", -4.0)


func _update_boss_gate() -> void:
	if not boss or boss.dead:
		return
	if state == "explore" and player.global_position.distance_to(arena_center) < arena_radius - 3.0 * CELL:
		state = "boss"
		boss.sleeping = false
		boss.intro()
		_set_objective()
		boss_started.emit()
		Sfx.music("music_boss")
	if state == "boss":
		var d := player.global_position - arena_center
		var lim := arena_radius - 40.0
		if d.length() > lim:
			player.global_position = arena_center + d.normalized() * lim
		if randf() < 0.9:
			for i in 3:
				var a := randf() * TAU
				var p := arena_center + Vector2(cos(a), sin(a)) * arena_radius
				if p.distance_to(player.global_position) < 1300.0:
					glow_fx.emit(p, Vector2(randf_range(-15, 15), randf_range(-90, -40)), 0.9, randf_range(3, 7), Color(3.0, 0.9, 0.2, 0.8), Particles.EMBER, 1.0)


# ================================================================ combat

func damage(target: Actor, amount: float, src: Actor, opts := {}) -> float:
	if target == null or target.dead or amount <= 0.0:
		return 0.0
	if target is Boss and ((target as Boss).sleeping or (target as Boss).intro_t > 0.0):
		return 0.0
	var dmg := amount
	var crit := false
	var from_player := src != null and src.team == Actor.Team.PLAYER
	if from_player and player and opts.get("can_crit", true) and not opts.get("dot", false):
		if randf() < player.crit_chance():
			crit = true
			dmg *= player.crit_mult()
	if target.vuln_t > 0.0:
		dmg *= 1.0 + target.vuln_amt
	if target.petrify and from_player and player and player.has_mod("smother_shatter"):
		dmg *= 2.0
	dmg *= 1.0 - target.armor
	if target is Player:
		dmg = (target as Player).incoming(dmg, src, opts)
		if dmg <= 0.0:
			return 0.0
	target.hp -= dmg
	if not opts.get("dot", false):
		target.flash = 1.0
		bleed(target, dmg, src, crit)
	if opts.has("knock"):
		target.push(opts.knock)
	if opts.has("burn"):
		target.apply_burn(opts.burn[0], opts.burn[1], src)
	if opts.has("slow"):
		target.apply_slow(opts.slow[0], opts.slow[1])
	if opts.has("stun") and not (target is Enemy and (target as Enemy).is_boss):
		target.apply_stun(opts.stun)
	if from_player:
		Game.stats.damage_dealt += dmg
		if target.marked and player and player.has_mod("mark_drain"):
			player.heal(dmg * 0.03, false)
	if Game.settings.numbers and (not opts.get("dot", false) or randf() < 0.35):
		var c := Color(1.0, 0.9, 0.75)
		if target.team == Actor.Team.PLAYER:
			c = Color(1.0, 0.35, 0.3) if target is Player else Color(0.7, 0.6, 0.55)
		elif crit:
			c = Color(1.8, 1.0, 0.3)
		elif opts.get("type", "") == "fire":
			c = Color(1.0, 0.62, 0.35)
		elif opts.get("type", "") == "poison":
			c = Color(0.7, 0.9, 0.45)
		if target is Player or target.team == Actor.Team.ENEMY:
			texts.add(target.global_position + Vector2(randf_range(-10, 10), -target.radius * 2.2), dmg, c, crit)
	target.on_damaged(dmg, src, opts)
	if target is Enemy and (target as Enemy).sleeping:
		alert_pack((target as Enemy).pack)
		(target as Enemy).wake()
	if target.hp <= 0.0:
		target.hp = 0.0
		# A big blow, a crit or an explosion tears the body apart instead of just felling it.
		var overkill := crit or dmg >= target.max_hp * 0.45 or opts.has("knock_force")
		_kill(target, src, overkill)
	return dmg


## Blood on every real hit: a spray away from the attacker and, sometimes, a splash on the ground.
func bleed(target: Actor, dmg: float, src: Actor, crit := false) -> void:
	if not Game.settings.get("gore", true):
		return
	var c := target.blood_color()
	if c.a <= 0.0:
		return
	var dir := Vector2.from_angle(randf() * TAU)
	if src and is_instance_valid(src) and src != target:
		dir = (target.global_position - src.global_position).normalized()
	var frac := clampf(dmg / maxf(1.0, target.max_hp), 0.0, 1.0)
	var n := int(clampf(4.0 + frac * 40.0, 4.0, 22.0)) * (2 if crit else 1)
	var hit_p := target.global_position + Vector2(0, -target.radius * 1.2)
	var dark := Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, 0.95)
	smoke_fx.burst(hit_p, n, dark, 80, 320 + frac * 300.0, 0.55, 2.6, Particles.EMBER, 1.3, dir.angle(), 2.5, 700.0)
	if randf() < 0.35 + frac * 2.0 or crit:
		var gp := target.global_position + dir * randf_range(4.0, 20.0)
		decals.add_blood(gp, target.radius * randf_range(0.35, 0.6) * (1.4 if crit else 1.0), dir, c)


func area_damage(center: Vector2, r: float, amount: float, src: Actor, team: int, opts := {}) -> int:
	var hits := 0
	if team == Actor.Team.PLAYER:
		for e in enemies_in_radius(center, r):
			damage(e, amount, src, _with_knock(opts, e.global_position - center))
			hits += 1
	else:
		if player and not player.dead and player.global_position.distance_to(center) < r + player.radius:
			damage(player, amount, src, _with_knock(opts, player.global_position - center))
			hits += 1
		for m in minions:
			if not m.dead and m.global_position.distance_to(center) < r + m.radius:
				damage(m, amount, src, opts)
	return hits


func _with_knock(opts: Dictionary, d: Vector2) -> Dictionary:
	if not opts.has("knock_force"):
		return opts
	var o := opts.duplicate()
	o.knock = d.normalized() * float(opts.knock_force)
	return o


func _kill(target: Actor, src: Actor, overkill := false) -> void:
	target.die(src)
	if target is Player:
		player_died.emit()
		return
	if target is Minion:
		smoke_fx.burst(target.global_position, 10, Color(0.6, 0.6, 0.58, 0.6), 20, 80, 1.0, 10, Particles.SMOKE)
		return
	var e := target as Enemy
	Game.stats.kills += 1
	if e.elite or e.is_champion:
		Game.stats.elites += 1
	var pos := e.global_position
	var bc := e.blood_color()
	if Game.settings.get("gore", true) and bc.a > 0.0:
		_gore_death(e, src, bc, overkill)
	else:
		# Death effect: the body collapses into ash
		smoke_fx.burst(pos, 14, Color(0.25, 0.23, 0.22, 0.85), 30, 120, 1.3, 9 * e.scale_mult, Particles.SMOKE, TAU, 0.0, 2.5, -20.0)
		smoke_fx.burst(pos, 10, Color(0.5, 0.47, 0.44), 60, 220, 0.8, 4, Particles.DEBRIS, TAU, 0.0, 4.0, 220.0)
		decals.add_ash(pos, e.radius * 1.4)
		Sfx.play("enemy_death", -8.0)
	glow_fx.burst(pos, 8, Color(3.0, 1.1, 0.3), 60, 260, 0.6, 2.5, Particles.SPARK)
	corpses.append({"pos": pos, "t": 10.0})
	if player:
		var xp := float(e.xp) * (1.5 if Game.fragments.has("greed") else 1.0)
		player.on_kill(e, xp)
		_flask_kills += 1
		if _flask_kills >= 32:
			_flask_kills = 0
			player.add_flask_charge()
	var globe_chance := 0.09 if not (e.elite or e.is_champion) else 1.0
	if randf() < globe_chance:
		drop_globe(pos)
	if Game.fragments.has("embers"):
		var r := 70.0 + e.radius * 2.0
		hazards_explosion(pos, r, e.max_hp * 0.25, player, Actor.Team.PLAYER, Color(3.0, 1.0, 0.25))
	if e.marked and player and player.has_mod("mark_spread"):
		for o in enemies_in_radius(pos, 160.0):
			o.apply_vuln(0.35, 5.0, true)
	if e == champion:
		_on_champion_dead(pos)
	if e == boss:
		state = "done"
		_set_objective()
		boss_defeated.emit()


func _gore_death(e: Enemy, src: Actor, c: Color, overkill: bool) -> void:
	var pos := e.global_position
	var dir := Vector2.from_angle(randf() * TAU)
	if src and is_instance_valid(src):
		dir = (pos - src.global_position).normalized()
	var s := e.scale_mult
	var dark := Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, 0.95)
	var flesh := Color(c.r * 1.3 + 0.12, c.g + 0.06, c.b + 0.06)
	decals.add_blood(pos + dir * e.radius * 0.6, e.radius * 1.6 * s, dir, c, true)
	if overkill:
		# Torn apart: chunks of meat and bone flung away from the blow, a fountain of blood.
		smoke_fx.burst(pos + Vector2(0, -e.radius), 40, dark, 120, 560, 0.75, 3.0, Particles.EMBER, 2.2, dir.angle(), 2.0, 800.0)
		smoke_fx.burst(pos + Vector2(0, -e.radius), int(10 * s) + 6, flesh, 120, 420, 0.9, 6.0 * s, Particles.DEBRIS, 2.6, dir.angle(), 3.0, 600.0)
		smoke_fx.burst(pos + Vector2(0, -e.radius), 6, Color(0.75, 0.7, 0.62), 160, 460, 0.8, 3.5, Particles.DEBRIS, 2.6, dir.angle(), 3.0, 600.0)
		decals.add_remains(pos + dir * e.radius, e.radius * 1.2 * s, c)
		for i in 3:
			decals.add_blood(pos + dir * e.radius * randf_range(1.5, 4.0) + Vector2(randf_range(-20, 20), randf_range(-12, 12)), e.radius * randf_range(0.4, 0.8), dir, c)
		Sfx.play("gore", -4.0, 0.12)
		shake(3.0 + e.radius * 0.08)
		hitstop(0.03)
	else:
		# Cut down: they fold and bleed out.
		smoke_fx.burst(pos + Vector2(0, -e.radius), 18, dark, 60, 300, 0.6, 2.6, Particles.EMBER, 1.6, dir.angle(), 2.5, 700.0)
		smoke_fx.burst(pos, 4, flesh, 60, 200, 0.7, 4.0, Particles.DEBRIS, TAU, 0.0, 4.0, 300.0)
		decals.add_remains(pos, e.radius * 0.6, c)
	Sfx.play("enemy_death", -6.0, 0.12)


func _on_champion_dead(pos: Vector2) -> void:
	state = "altar"
	_set_objective()
	shake(14.0)
	Sfx.play("explode")
	var c := arena_center
	var altar := add_prop("altar", c)
	altar.radius = 0.0
	glow_fx.burst(pos, 40, Color(3.0, 1.2, 0.3), 80, 400, 1.2, 3.5, Particles.SPARK)
	banner.emit("%s falls" % champion.display_name, "A crown fragment lies on the altar")


func claim_fragment_done() -> void:
	state = "portal"
	_set_objective()
	var portal := add_prop("portal", arena_center + Vector2(0, 150))
	portal.radius = 0.0
	banner.emit("The way down is open", "")


func hazards_explosion(pos: Vector2, r: float, dmg: float, src: Actor, team: int, c: Color) -> void:
	area_damage(pos, r, dmg, src, team, {"type": "fire", "knock_force": 260.0})
	glow_fx.burst(pos, 22, c, 80, 360, 0.6, 3.0, Particles.SPARK)
	glow_fx.emit(pos, Vector2.ZERO, 0.35, r * 0.9, Color(c.r, c.g, c.b, 0.35), Particles.GLOW, 0.0)
	glow_fx.ring(pos, r, Color(c.r, c.g, c.b, 0.8))
	smoke_fx.burst(pos, 8, Color(0.18, 0.16, 0.15, 0.7), 30, 100, 1.2, r * 0.25, Particles.SMOKE)
	decals.add_scorch(pos, r * 0.8)
	Sfx.play("explode_small", -6.0)
	shake(4.0)


# ================================================================ queries

func enemies_in_radius(center: Vector2, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if not e.dead and e.global_position.distance_to(center) < r + e.radius:
			out.append(e)
	return out


func nearest_enemy(pos: Vector2, max_d: float, need_los := true) -> Enemy:
	var best: Enemy
	var bd := max_d
	for e in enemies:
		if e.dead or e.sleeping and e.pack != 999:
			continue
		var d := e.global_position.distance_to(pos)
		if d < bd and (not need_los or los(pos, e.global_position)):
			bd = d
			best = e
	return best


func nearest_ally(pos: Vector2, max_d: float) -> Actor:
	var best: Actor = null
	var bd := max_d
	if player and not player.dead and not player.untargetable():
		bd = player.global_position.distance_to(pos)
		best = player if bd < max_d else null
		if best == null:
			bd = max_d
	for m in minions:
		if m.dead:
			continue
		var d := m.global_position.distance_to(pos) * 1.15
		if d < bd:
			bd = d
			best = m
	return best


func is_floor_at(p: Vector2) -> bool:
	return map.is_floor(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


func los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 28.0) + 1
	for i in steps + 1:
		if not is_floor_at(a + d * (float(i) / steps)):
			return false
	return true


func world_clamp(p: Vector2) -> Vector2:
	if is_floor_at(p):
		return p
	return player.global_position if player else p


func world_clamp_soft(p: Vector2, r: float) -> Vector2:
	return _resolve(p, r)


func move_circle(pos: Vector2, motion: Vector2, r: float) -> Vector2:
	var steps := maxi(1, int(ceil(motion.length() / maxf(4.0, r * 0.5))))
	var step := motion / steps
	var p := pos
	for i in steps:
		p = _resolve(p + step, r)
	return p


func _resolve(p: Vector2, r: float) -> Vector2:
	var cx := int(floor(p.x / CELL))
	var cy := int(floor(p.y / CELL))
	var reach := int(ceil(r / CELL)) + 1
	for y in range(cy - reach, cy + reach + 1):
		for x in range(cx - reach, cx + reach + 1):
			if not map.is_floor(x, y):
				var rect_min := Vector2(x, y) * CELL
				var closest := Vector2(clampf(p.x, rect_min.x, rect_min.x + CELL), clampf(p.y, rect_min.y, rect_min.y + CELL))
				var d := p - closest
				var l := d.length()
				if l < r:
					if l < 0.001:
						# Center is inside the wall; push toward the cell's open side.
						p = _cell_pos(Vector2i(cx, cy)) if map.is_floor(cx, cy) else p + Vector2(0, -r)
					else:
						p += d / l * (r - l)
			var key := Vector2i(x, y)
			if prop_cells.has(key):
				for pr in prop_cells[key]:
					var dd: Vector2 = p - pr.global_position
					var rr: float = r + pr.radius
					var ll := dd.length()
					if ll < rr and ll > 0.001:
						p = pr.global_position + dd / ll * rr
	return p


func _update_flow(dt: float) -> void:
	if not player:
		return
	flow_timer -= dt
	var pc := Vector2i(player.global_position / CELL)
	if pc == flow_cell and flow_timer > 0.0:
		return
	flow_timer = 0.35
	flow_cell = pc
	flow_id += 1
	var w := map.w
	var q := PackedInt32Array()
	var start := pc.y * w + pc.x
	if not map.is_floor(pc.x, pc.y):
		return
	q.append(start)
	flow[start] = 0
	flow_stamp[start] = flow_id
	var head := 0
	var limit := 42
	while head < q.size():
		var idx := q[head]
		head += 1
		var dist := flow[idx]
		if dist >= limit:
			continue
		var x := idx % w
		var y := idx / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not map.is_floor(nx, ny) or blocked.has(Vector2i(nx, ny)):
				continue
			var ni := ny * w + nx
			if flow_stamp[ni] == flow_id:
				continue
			flow_stamp[ni] = flow_id
			flow[ni] = dist + 1
			q.append(ni)


## Direction toward the player along the walkable grid.
func flow_dir(pos: Vector2) -> Vector2:
	var c := Vector2i(pos / CELL)
	var w := map.w
	var i := c.y * w + c.x
	if i < 0 or i >= flow.size() or flow_stamp[i] != flow_id:
		return Vector2.ZERO
	var best := flow[i]
	var target := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = c + d
		if not map.is_floor(n.x, n.y) or blocked.has(n):
			continue
		if d.x != 0 and d.y != 0 and not (map.is_floor(c.x + d.x, c.y) and map.is_floor(c.x, c.y + d.y)):
			continue
		var ni := n.y * w + n.x
		if flow_stamp[ni] == flow_id and flow[ni] < best:
			best = flow[ni]
			target = n
	if target.x < 0:
		return Vector2.ZERO
	return (_cell_pos(target) - pos).normalized()


func path_dir(from: Vector2, to: Vector2) -> Vector2:
	if los(from, to):
		return (to - from).normalized()
	if player and to.distance_to(player.global_position) < 80.0:
		var f := flow_dir(from)
		if f != Vector2.ZERO:
			return f
	return (to - from).normalized()


# ================================================================ camera / view

func view_rect() -> Rect2:
	var vs := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - vs * 0.5, vs)


func shake(amount: float) -> void:
	if Game.settings.shake:
		shake_amt = minf(24.0, maxf(shake_amt, amount))


func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)


func _update_camera(delta: float) -> void:
	if player and not attract:
		var look := Vector2.ZERO
		if not player.dead:
			look = (player.aim_point - player.global_position).limit_length(260.0) * 0.18
		camera.global_position = player.global_position + look
	shake_amt = move_toward(shake_amt, 0.0, delta * 40.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	var vs := get_viewport_rect().size / camera.zoom
	for a in _ambient:
		a.emission_rect_extents = vs * 0.6


func _reveal() -> void:
	if not player:
		return
	var c := Vector2i(player.global_position / CELL)
	if c == _reveal_cell:
		return
	_reveal_cell = c
	var r := 13
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= map.w or y >= map.h:
				continue
			if Vector2(x - c.x, y - c.y).length_squared() > r * r:
				continue
			if minimap_img.get_pixel(x, y).a > 0.0:
				continue
			var col := Color(0.55, 0.5, 0.46, 0.75) if map.is_floor(x, y) else Color(0, 0, 0, 0)
			if not map.is_floor(x, y):
				var edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if map.is_floor(x + d.x, y + d.y):
						edge = true
				if edge:
					col = Color(0.95, 0.75, 0.5, 0.9)
				else:
					col = Color(0, 0, 0, 0.001)
			minimap_img.set_pixel(x, y, col)
			_minimap_dirty = true


func respawn_player() -> void:
	player.revive()
	player.global_position = _cell_pos(map.start)
	camera.reset_smoothing()
	for e in enemies:
		e.drop_aggro()
	if state == "boss" and boss:
		state = "explore"
		boss.hp = boss.max_hp
		boss.reset_fight()
		_set_objective()
		Sfx.music("music_combat")
	for h in hazards:
		if h.team == Actor.Team.ENEMY:
			h.done = true
	for p in projectiles:
		if p.team == Actor.Team.ENEMY:
			p.done = true
