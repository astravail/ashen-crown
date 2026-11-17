class_name World
extends Node2D
## One zone: map, entities, combat resolution, camera and lighting.

signal player_died
signal level_up
signal fragment_ready
signal boss_started
signal boss_defeated
signal banner(title: String, sub: String)
signal npc_talk(kind: String)
signal waypoint_open
signal crown_taken
signal door_enter(interior_idx: int)
signal door_exit
signal recall_done
signal portal_return(pos: Vector2)
signal act_entered(act: int)

const CELL := 64.0
const ACTIVATE_DIST := 430.0
const INTERACT_KINDS := ["chest", "chest_iron", "waypoint", "crown", "door"]
const UPDATE_DIST := 2000.0
const PostFX := preload("res://scripts/fx/post_fx.gd")
const Ink := preload("res://scripts/fx/ink.gd")

static var unshaded_add: CanvasItemMaterial
static var unshaded: CanvasItemMaterial
static var light_tex: Texture2D

var zone: Dictionary
var zone_idx := 0
var map: WorldMap
var rt: Array[Dictionary] = []  # runtime state per region
var cur := -1
var village := false
var interior := false
var npcs: Array[Npc] = []
var loots: Array[Loot] = []
var ambush: Array[Dictionary] = []
var interact_target: Node
var interact_text := ""
var full_warn := 0.0
## The piece of gear under the cursor, if any. Clicking takes it instead of attacking.
var hovered_loot: Loot = null
var recall_t := 0.0
var recall_cd := 0.0
var recall_prop: Prop
## Where the hero stood when recalling, and the portal left in the village that leads back there.
var recall_origin := Vector2.ZERO
var town_portal: Prop
var return_pos := Vector2.ZERO
var objective_pos := Vector2.ZERO
var guide_pts := PackedVector2Array()
var _astar: AStarGrid2D
var _guide_t := 0.0
var guide_node: Node2D
var explored := PackedByteArray()
var _region_timer := 0.0
var _target_mod := Color.WHITE
var _lowhp_t := 0.0
var _near_arena_msg := {}
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
var post: PostFX

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
	# How far above the ground the flame sits. The terrain is lit in relief, so a low lamp rakes
	# across it and throws every stone into shadow, while a high one lights it evenly.
	l.height = clampf(size_px * 0.1, 36.0, 170.0)
	return l


# ================================================================ setup

func setup(idx: int, is_attract := false, opts := {}) -> void:
	attract = is_attract
	interior = idx >= Data.LAST_ZONE + 1
	map = WorldMap.new()
	if attract:
		map.build_single(0, 4242)
	elif interior:
		map.build_single(idx, int(hash(Data.ZONES[idx].id)))
	else:
		map.build_overworld(int(opts.get("seed", randi())))
	zone = map.regions[0].zd
	zone_idx = map.regions[0].zone
	for r in map.regions:
		rt.append({"active": false, "left_at": 0.0, "enemies": [], "champion": null, "boss": null, "state": "explore",
			"arena_center": (Vector2(r.finish) + Vector2(0.5, 0.5)) * CELL, "gates": [], "waypoint": null, "props": []})
	_build_layers()
	if attract:
		_build_props(0)
		camera.global_position = _cell_pos(map.regions[0].nodes[1])
		return
	player = Player.new()
	player.world = self
	player.setup(Game.class_id)
	entity_layer.add_child(player)
	var start_pos: Vector2
	if opts.has("pos"):
		start_pos = opts.pos
	elif interior:
		start_pos = _cell_pos(map.regions[0].start) + Vector2(0, 40)
	else:
		start_pos = map.regions[0].pois.start
	player.global_position = start_pos
	camera.global_position = player.global_position
	camera.reset_smoothing()
	if interior:
		_enter_region(0)
	else:
		_enter_region(map.region_at(int(start_pos.x / CELL), int(start_pos.y / CELL)))
	_reveal()


func _cell_pos(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


## The old ambient was far too dark to read the ground by; lift it a little.
static func _lift(c: Color) -> Color:
	return Color(minf(c.r * 1.2, 1.0), minf(c.g * 1.17, 1.0), minf(c.b * 1.13, 1.0), c.a)


func _build_layers() -> void:
	var size_px := Vector2(map.w, map.h) * CELL
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = _lift(map.regions[0].zd.modulate)
	_target_mod = canvas_mod.color
	add_child(canvas_mod)

	var mask := ImageTexture.create_from_image(map.mask_image())
	var gmats: Array[ShaderMaterial] = []
	var vmats: Array[ShaderMaterial] = []
	for r in map.regions:
		var zd: Dictionary = r.zd
		var gm := ShaderMaterial.new()
		gm.shader = load("res://shaders/ground.gdshader")
		gm.set_shader_parameter("mask", mask)
		gm.set_shader_parameter("col_a", zd.ground_a)
		gm.set_shader_parameter("col_b", zd.ground_b)
		gm.set_shader_parameter("col_wall", zd.wall)
		gm.set_shader_parameter("pattern", zd.pattern)
		gm.set_shader_parameter("map_px", size_px)
		var vm := ShaderMaterial.new()
		vm.shader = load("res://shaders/veins.gdshader")
		var vc: Color = zd.vein
		var hdr := maxf(vc.r, maxf(vc.g, vc.b))
		vm.set_shader_parameter("mask", mask)
		vm.set_shader_parameter("vein", Color(vc.r / hdr, vc.g / hdr, vc.b / hdr))
		vm.set_shader_parameter("vein_hdr", hdr)
		vm.set_shader_parameter("amount", zd.vein_amt)
		vm.set_shader_parameter("pattern", zd.pattern)
		vm.set_shader_parameter("map_px", size_px)
		gmats.append(gm)
		vmats.append(vm)
	# The ground is split into chunks: 2D lights only reach a limited number of lights per canvas item.
	# Chunks with no floor are skipped, which matters on a map this big.
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	veins = ColorRect.new()
	veins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veins)
	var cells := 12
	for cy in range(0, map.h, cells):
		for cx in range(0, map.w, cells):
			var ri := -1
			for y in range(cy, mini(map.h, cy + cells)):
				for x in range(cx, mini(map.w, cx + cells)):
					if map.is_floor(x, y):
						ri = map.region_at(x, y)
						break
				if ri >= 0:
					break
			if ri < 0:
				continue
			var g := ColorRect.new()
			g.position = Vector2(cx, cy) * CELL
			g.size = Vector2(mini(cells, map.w - cx), mini(cells, map.h - cy)) * CELL
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.material = gmats[ri]
			ground.add_child(g)
			var v := ColorRect.new()
			v.position = g.position
			v.size = g.size
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.material = vmats[ri]
			veins.add_child(v)

	decals = Decals.new()
	decals.world = self
	add_child(decals)

	var q: float = Game.quality_factor()
	smoke_fx = Particles.new()
	smoke_fx.setup(false)
	smoke_fx.max_count = int(3200 * maxf(0.25, q))
	smoke_fx.z_index = 2
	glow_fx = Particles.new()
	glow_fx.setup(true)
	glow_fx.z_index = 3

	entity_layer = Node2D.new()
	entity_layer.y_sort_enabled = true
	add_child(entity_layer)
	add_child(smoke_fx)
	add_child(glow_fx)

	guide_node = Node2D.new()
	guide_node.material = unshaded_add
	guide_node.z_index = 3
	guide_node.draw.connect(_draw_guide)
	add_child(guide_node)
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
	post = PostFX.new()
	add_child(post)
	post.setup(self)
	post.apply_zone(map.regions[0].zd, true)

	# The map starts empty: only ground you have walked on fills in, so everything else is found by exploring.
	minimap_img = Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
	minimap_img.fill(Color(0, 0, 0, 0))
	minimap_tex = ImageTexture.create_from_image(minimap_img)
	explored.resize(map.w * map.h)
	flow.resize(map.w * map.h)
	flow_stamp.resize(map.w * map.h)


func _build_ambient() -> void:
	var ash := CPUParticles2D.new()
	ash.amount = int(120 * Game.quality_factor())
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(900, 600)
	# a warm wind carries the ash sideways and a little up, so it never reads as falling snow
	ash.direction = Vector2(1.0, -0.12)
	ash.spread = 18.0
	ash.initial_velocity_min = 40.0
	ash.initial_velocity_max = 110.0
	ash.gravity = Vector2(14, -3)
	ash.texture = Ink.soft_tex()
	ash.scale_amount_min = 0.04
	ash.scale_amount_max = 0.1
	ash.angular_velocity_min = -90
	ash.angular_velocity_max = 90
	ash.color = Color(0.42, 0.36, 0.32, 0.6)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ash.color_ramp = ramp
	ash.z_index = 5
	camera.add_child(ash)

	var embers := CPUParticles2D.new()
	embers.amount = int(70 * Game.quality_factor())
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
	embers.texture = Ink.soft_tex()
	embers.scale_amount_min = 0.07
	embers.scale_amount_max = 0.16
	var vc: Color = map.regions[0].zd.vein
	embers.color = Color(vc.r, vc.g, vc.b, 1.0)
	var ramp2 := Gradient.new()
	ramp2.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	ramp2.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	embers.color_ramp = ramp2
	embers.material = unshaded_add
	embers.z_index = 5
	camera.add_child(embers)
	_ambient = [ash, embers]
	ash.visible = Game.quality_factor() > 0.0
	embers.visible = ash.visible


func _build_props(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var door_cell := Vector2(-9999, -9999)
	for d in r.props:
		var p := Prop.new()
		p.world = self
		p.kind = d.kind
		p.seed_value = d.seed
		entity_layer.add_child(p)
		p.global_position = d.pos
		p.init()
		props.append(p)
		rt[ri].props.append(p)
		if p.radius > 0.0:
			_register_solid(p)


func _register_solid(p: Prop) -> void:
	var c := Vector2i(p.global_position / CELL)
	if not prop_cells.has(c):
		prop_cells[c] = []
	prop_cells[c].append(p)
	blocked[c] = true


func _unregister_solid(p: Prop) -> void:
	var c := Vector2i(p.global_position / CELL)
	if prop_cells.has(c):
		prop_cells[c].erase(p)
		if prop_cells[c].is_empty():
			prop_cells.erase(c)
			blocked.erase(c)


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


func _arch_of(k: String) -> String:
	return String(Data.enemy_def(k).get("arch", k))


func _spawn_packs(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var zd: Dictionary = r.zd
	var pool: Dictionary = zd.pool
	if pool.is_empty():
		return
	var kinds: Array = pool.keys()
	var total := 0
	for k in kinds:
		total += int(pool[k])
	var pack_id := ri * 1000
	for c in r.packs:
		pack_id += 1
		var center: Vector2 = (c + Vector2(0.5, 0.5)) * CELL
		var main_kind := _weighted(kinds, pool, total)
		var second := _weighted(kinds, pool, total)
		var n := maxi(2, int(round(randi_range(4, 7) * Data.GRIND.pack_size)))
		if _arch_of(main_kind) == "brute":
			n = randi_range(1, 2)
		var elite := randf() < 0.14
		for i in n:
			var kind := main_kind if i < n - 2 or n <= 3 else second
			if _arch_of(kind) == "brute" and i > 1:
				kind = _weighted_no_brute(kinds, pool, total)
			var pos := center + Vector2(randf_range(-110, 110), randf_range(-110, 110))
			if not is_floor_at(pos):
				pos = center
			var e := spawn_enemy(kind, pos, false, ri)
			e.pack = pack_id
		if elite:
			var ek := main_kind if _arch_of(main_kind) != "brute" else _weighted_no_brute(kinds, pool, total)
			var e2 := spawn_enemy(ek, center, false, ri)
			e2.make_elite()
			e2.pack = pack_id


func _weighted_no_brute(kinds: Array, pool: Dictionary, total: int) -> String:
	for i in 8:
		var k := _weighted(kinds, pool, total)
		if _arch_of(k) != "brute":
			return k
	return kinds[0]


func _weighted(kinds: Array, pool: Dictionary, total: int) -> String:
	var r := randi_range(1, total)
	for k in kinds:
		r -= int(pool[k])
		if r <= 0:
			return k
	return kinds[0]


func _place_shrines(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var kinds := ["fury", "warding", "haste"]
	kinds.shuffle()
	var spots: Array = (r.branches as Array).duplicate()
	spots.shuffle()
	var placed := 0
	for b in spots:
		if placed >= 2:
			break
		if not map.is_floor(b.x, b.y):
			continue
		var p := add_prop("shrine_" + kinds[placed], _cell_pos(b))
		p.radius = 0.0
		rt[ri].props.append(p)
		placed += 1


func _place_finale(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var st: Dictionary = rt[ri]
	var z: int = r.zone
	var c: Vector2 = st.arena_center
	var zs := Game.zs(z)
	if z == Data.LAST_ZONE:
		var throne := add_prop("throne", c + Vector2(0, -175))
		throne.radius = 0.0
		interactives.erase(throne)
		st.props.append(throne)
		if zs.boss_dead:
			_place_crown(ri)
			st.state = "done"
		else:
			spawn_quest_boss(ri)
		return
	if (r.zd.champion as Dictionary).is_empty():
		return
	if zs.champ_dead:
		if not zs.claimed:
			var altar := add_prop("altar", c)
			altar.radius = 0.0
			st.props.append(altar)
			st.state = "altar"
		else:
			st.state = "portal"
		return
	spawn_quest_boss(ri)


## Bosses and champions only exist while their quest is active.
func spawn_quest_boss(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var st: Dictionary = rt[ri]
	if not st.active or st.champion != null or st.boss != null:
		return
	var z: int = r.zone
	var zs := Game.zs(z)
	var c: Vector2 = st.arena_center
	if z == Data.LAST_ZONE:
		if zs.boss_dead or not Game.quest_active_for("boss", z):
			return
		var b := spawn_enemy("ember_king", c + Vector2(0, -140), true, ri)
		b.sleeping = true
		b.pack = -1
		st.boss = b
		if cur == ri:
			boss = b
		return
	if zs.champ_dead or not Game.quest_active_for("champion", z):
		return
	var ch: Dictionary = r.zd.champion
	var e := spawn_enemy(ch.kind, c, true, ri)
	e.make_champion(ch.name, ch.scale)
	e.pack = 999
	st.champion = e
	if cur == ri:
		champion = e
	var kinds: Array = (r.zd.pool as Dictionary).keys()
	for i in 6:
		var a := TAU * i / 6.0
		var k: String = kinds[i % kinds.size()]
		if _arch_of(k) == "brute":
			k = kinds[0]
		var g := spawn_enemy(k, c + Vector2(cos(a), sin(a)) * 180.0, false, ri)
		g.pack = 999


func _place_crown(ri: int) -> void:
	var st: Dictionary = rt[ri]
	var crown := add_prop("crown", st.arena_center + Vector2(0, -120))
	crown.radius = 0.0
	st.props.append(crown)


func _place_waypoint(ri: int, pos: Vector2) -> void:
	var p := add_prop("waypoint", pos)
	p.radius = 0.0
	rt[ri].waypoint = p
	rt[ri].props.append(p)


func _place_chests(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var z: int = r.zone
	var opened: Dictionary = Game.zs(z).chests
	for i in (r.chests as Array).size():
		var c: Dictionary = r.chests[i]
		var p := add_prop("chest_iron" if c.iron else "chest", c.pos)
		p.radius = 0.0
		p.chest_id = i
		p.used = opened.has(i)
		rt[ri].props.append(p)


func _place_doors(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	for i in range(Data.LAST_ZONE + 1, Data.ZONES.size()):
		var it: Dictionary = Data.ZONES[i]
		if int(it.parent) != int(r.zone):
			continue
		var pos: Vector2
		if r.zone < 0:
			pos = r.pois.door
		else:
			var cell: Vector2i = r.branches[0] if not (r.branches as Array).is_empty() else r.nodes[1]
			pos = _cell_pos(cell)
			for p in rt[ri].props:
				if p.global_position.distance_to(pos) < 130.0 and p.radius > 0.0:
					_unregister_solid(p)
					p.radius = 0.0
					p.visible = false
		var d := add_prop("door", pos)
		d.radius = 0.0
		d.door_idx = i
		rt[ri].props.append(d)


func _place_gates(ri: int) -> void:
	for gi in map.gates.size():
		var g: Dictionary = map.gates[gi]
		if int(g.a) != ri or ri == 0:
			continue
		var z: int = map.regions[ri].zone
		if Game.zs(z).claimed:
			continue
		var along := Vector2(g.dir).normalized()
		var perp := Vector2(-along.y, along.x)
		var base := _cell_pos(g.cell)
		var segs: Array = []
		for k in range(-2, 3):
			var p := add_prop("gate_seg", base + perp * k * 64.0)
			interactives.erase(p)
			p.radius = 34.0
			_register_solid(p)
			segs.append(p)
			rt[ri].props.append(p)
		rt[ri].gates.append({"segs": segs, "zone": z})


func open_gates(ri: int) -> void:
	for gd in rt[ri].gates:
		for p in gd.segs:
			_unregister_solid(p)
			p.radius = 0.0
			glow_fx.burst(p.global_position + Vector2(0, -40), 14, Color(2.4, 1.2, 0.5), 60, 200, 0.8, 3.0, Particles.SPARK)
			p.queue_free()
			props.erase(p)
	rt[ri].gates.clear()
	Sfx.play("slam", -4.0)
	shake(8.0)


func _place_ambush(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var em: Dictionary = r.zd.get("emerge", {})
	if em.is_empty():
		return
	var cands: Array = []
	for p in rt[ri].props:
		if p.kind in em.from:
			cands.append(p)
	cands.shuffle()
	for i in mini(int(em.sites), cands.size()):
		var p: Prop = cands[i]
		if not is_floor_at(p.global_position + Vector2(0, 24)):
			continue
		ambush.append({"pos": p.global_position + Vector2(0, 24), "kind": em.kind, "n": randi_range(2, 3), "ri": ri, "done": false})


func _place_village(ri: int) -> void:
	var r: Dictionary = map.regions[ri]
	var pois: Dictionary = r.pois
	for k in ["smith", "mystic", "elder", "keeper"]:
		var n := Npc.new()
		n.world = self
		n.setup(k)
		entity_layer.add_child(n)
		n.global_position = pois["stash" if k == "keeper" else k]
		npcs.append(n)
		_register_solid_npc(n)
	_place_waypoint(ri, pois.waypoint)
	_place_doors(ri)


func _register_solid_npc(n: Npc) -> void:
	var c := Vector2i(n.global_position / CELL)
	if not prop_cells.has(c):
		prop_cells[c] = []
	prop_cells[c].append(n)
	blocked[c] = true


func _activate_region(ri: int) -> void:
	var st: Dictionary = rt[ri]
	if st.active:
		return
	st.active = true
	var r: Dictionary = map.regions[ri]
	_build_props(ri)
	if interior:
		_spawn_packs(ri)
		_place_chests(ri)
		var ex := add_prop("door", _cell_pos(r.start))
		ex.radius = 0.0
		ex.door_idx = -1
		st.props.append(ex)
		return
	if r.zone < 0:
		_place_village(ri)
		return
	_spawn_packs(ri)
	_place_shrines(ri)
	_place_chests(ri)
	_place_waypoint(ri, _cell_pos(r.waypoint))
	_place_doors(ri)
	_place_ambush(ri)
	_place_finale(ri)
	_place_gates(ri)


## Packs come back after you have been away for a while: this is a game about going round again.
func _respawn_region(ri: int) -> void:
	for e in enemies.duplicate():
		if e.region == ri and not e.is_champion and not e.is_boss and e.pack != 999:
			e.queue_free()
			enemies.erase(e)
	for a in ambush:
		if a.ri == ri:
			a.done = false
	_spawn_packs(ri)


func _set_objective() -> void:
	if cur < 0:
		return
	var r: Dictionary = map.regions[cur]
	var st: Dictionary = rt[cur]
	var z: int = r.zone
	objective_pos = st.arena_center
	if z < 0:
		var m := Game.quest_marker()
		if Game.quest_status("story_0") == 1:
			objective = "Enter Maren's Cellar"
			objective_pos = r.pois.door
		else:
			objective = "Speak with Sister Maren" if m != "" else "Take the road to the Blackwood"
			objective_pos = r.pois.elder if m != "" else (Vector2(r.finish) + Vector2(0.5, 0.5)) * CELL
		return
	if interior:
		objective = "Find the reliquary chest" if Game.quest_status("story_0") == 1 else "Plunder the depths"
		objective_pos = Vector2.ZERO
		for p in props:
			if p.kind.begins_with("chest") and not p.used:
				objective_pos = p.global_position
				break
		return
	var zs := Game.zs(z)
	if z == Data.LAST_ZONE and zs.boss_dead:
		objective = "Take the crown"
	elif st.state == "altar":
		objective = "Claim the crown fragment"
	elif st.champion != null and not (st.champion as Enemy).dead:
		objective = "Slay %s" % (st.champion as Enemy).display_name
	elif st.boss != null and not (st.boss as Enemy).dead:
		objective = "Find and kill the Ember King" if st.state == "explore" else "Kill the Ember King"
	elif zs.claimed:
		objective = "Follow the tunnel onward"
		objective_pos = _cell_pos(r.finish)
	elif Game.quest_active_for("champion", z) or Game.quest_active_for("boss", z):
		objective = "Hunt the beast in the arena"
	elif Game.quest_active_for("chest", z):
		objective = "Find chests"
		var near := INF
		for p in st.props:
			if p.kind.begins_with("chest") and not p.used and p.global_position.distance_to(player.global_position) < near:
				near = p.global_position.distance_to(player.global_position)
				objective_pos = p.global_position
	else:
		objective = "Speak with the Elder about this land"
		objective_pos = map.regions[0].pois.elder


# ================================================================ spawning

func spawn_enemy(kind: String, pos: Vector2, special: bool, ri := -1) -> Enemy:
	if ri < 0:
		ri = maxi(cur, 0)
	var zd: Dictionary = map.regions[ri].zd
	var e: Enemy
	if kind == "ember_king":
		e = Boss.new()
	else:
		e = Enemy.new()
	e.world = self
	var d: Dictionary = Game.diff()
	e.setup(kind, float(zd.hp_mult) * float(Data.GRIND.enemy_hp) * float(d.hp) * (1.25 if Game.fragments.has("greed") else 1.0), float(zd.dmg_mult) * float(d.dmg))
	if kind == "ember_king":
		e.max_hp *= float(d.hp) * 1.35
		e.hp = e.max_hp
	e.zone_idx = map.regions[ri].zone
	e.region = ri
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
	if guide_node:
		guide_node.queue_redraw()
	_update_camera(delta)
	if post:
		post.hurt = move_toward(post.hurt, (1.0 - player.hp / (player.max_hp * 0.35)) if player and not player.dead and player.hp < player.max_hp * 0.35 else 0.0, delta * 1.5)
		post.update(delta, camera)


func _update_attract(dt: float) -> void:
	_attract_t += dt * 0.035
	var nodes: Array = map.regions[0].nodes
	var n := nodes.size()
	var f := fmod(_attract_t, float(n - 1))
	var i := int(f)
	var target := _cell_pos(nodes[i]).lerp(_cell_pos(nodes[mini(i + 1, n - 1)]), smoothstep(0.0, 1.0, f - i))
	camera.global_position = camera.global_position.lerp(target, dt * 0.6)
	_tend_props(camera.global_position, dt)


## Scenery near the view is drawn and animated; the rest holds no picture at all, so a world of
## thousands of props costs only what is on screen.
func _tend_props(center: Vector2, dt: float) -> void:
	for p in props:
		var d2 := p.global_position.distance_squared_to(center)
		if d2 < 1500.0 * 1500.0:
			p.wake()
			p.update(dt)
		elif d2 > 1750.0 * 1750.0:
			p.sleep()
		elif not p.asleep:
			p.update(dt)


func _update_game(dt: float) -> void:
	Game.stats.time += dt
	Game.stat_add("playtime", dt)
	Game.stat_add("playtime_class", dt, Game.class_id)
	_track_distance()
	full_warn = maxf(0.0, full_warn - dt)
	_lowhp_t = maxf(0.0, _lowhp_t - dt)
	Game.potion_cd = maxf(0.0, Game.potion_cd - dt)
	Game.diff_cd = maxf(0.0, Game.diff_cd - dt)
	if player and not player.dead:
		player.update(dt)
	_update_flow(dt)
	_region_timer -= dt
	if _region_timer <= 0.0:
		_region_timer = 0.25
		_update_region()
	_activate_timer -= dt
	if _activate_timer <= 0.0:
		_activate_timer = 0.2
		_activate_packs()
		_update_ambush()
	var pp := player.global_position
	var active: Array[Enemy] = []
	for e in enemies:
		if e.dead:
			continue
		if e.global_position.distance_squared_to(pp) > UPDATE_DIST * UPDATE_DIST and not e.is_boss:
			continue
		e.update(dt)
		if not e.sleeping and e.emerge_t <= 0.0:
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
	for l in loots:
		l.update(dt)
	_update_hover_loot()
	for n in npcs:
		n.update(dt)
	_tend_props(pp, dt)
	_cleanup()
	_update_interact()
	_update_guide(dt)
	_update_recall(dt)
	_check_interactives()
	_update_boss_gate()
	if player and not player.dead and player.hp < player.max_hp * 0.25 and _lowhp_t <= 0.0:
		_lowhp_t = 30.0
		Voice.bark("player", "lowhp", "", 30.0)
	_minimap_timer -= dt
	if _minimap_timer <= 0.0:
		_minimap_timer = 0.15
		_reveal()
		if _minimap_dirty:
			_minimap_dirty = false
			minimap_tex.update(minimap_img)
	canvas_mod.color = canvas_mod.color.lerp(_target_mod, clampf(dt * 1.2, 0.0, 1.0))
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
	for i in range(loots.size() - 1, -1, -1):
		if loots[i].done:
			loots[i].queue_free()
			loots.remove_at(i)


func _activate_packs() -> void:
	var pp := player.global_position
	var woken := {}
	for e in enemies:
		if e.sleeping and not e.dead and e.pack >= 0 and e.emerge_t <= 0.0:
			var d2 := e.global_position.distance_squared_to(pp)
			# Only close, visible enemies notice you; the rest keep milling about.
			if d2 < ACTIVATE_DIST * ACTIVATE_DIST and (d2 < 190.0 * 190.0 or los(e.global_position, pp)):
				woken[e.pack] = true
	if woken.is_empty():
		return
	for e in enemies:
		if e.sleeping and woken.has(e.pack):
			e.wake()
			if e.is_champion:
				banner.emit(e.display_name, "")
				Sfx.play("roar", -4.0)
				Voice.bark("boss", "intro", "You should not have come.", 5.0)
	Sfx.play("growl", -8.0, 0.15)


func _update_ambush() -> void:
	var pp := player.global_position
	for a in ambush:
		if a.done:
			continue
		var d: float = a.pos.distance_to(pp)
		if d < 210.0:
			a.done = true
			for i in int(a.n):
				var e := spawn_enemy(a.kind, a.pos + Vector2(randf_range(-40, 40), randf_range(-20, 30)), false, a.ri)
				if not is_floor_at(e.global_position):
					e.global_position = a.pos
				e.pack = -2
				e.start_emerge()
			smoke_fx.burst(a.pos, 16, Color(0.3, 0.22, 0.15, 0.9), 40, 200, 0.9, 8.0, Particles.DEBRIS, TAU, 0.0, 3.0, 300.0)
			Sfx.play("slam", -8.0, 0.1, 0.7)
			shake(5.0)
			Voice.bark("player", "trap", "", 20.0)
		elif d < 420.0 and randf() < 0.06:
			smoke_fx.burst(a.pos, 3, Color(0.3, 0.22, 0.15, 0.7), 10, 60, 0.7, 4.0, Particles.DEBRIS, TAU, 0.0, 2.0, 200.0)


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
		if p.used or p.kind in INTERACT_KINDS:
			continue
		if p.global_position.distance_to(player.global_position) < 70.0:
			p.used = true
			match p.kind:
				"altar":
					Sfx.play("fragment")
					fragment_ready.emit()
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
	if cur < 0 or not boss or boss.dead:
		return
	var st: Dictionary = rt[cur]
	if st.state == "explore" and player.global_position.distance_to(arena_center) < arena_radius - 3.0 * CELL:
		st.state = "boss"
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
	if target is Player:
		Game.stat_add("damage_taken", dmg)
	if target is Player and src is Enemy:
		Game.last_killer = (src as Enemy).display_name
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
		Game.stat_add("damage_dealt", dmg)
		Game.stat_max("biggest_hit", dmg)
		if crit:
			Game.stat_add("crits", 1.0)
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
	Game.stat_add("kills", 1.0)
	Game.stat_add("zone_kills", 1.0, str(e.zone_idx))
	Game.stat_add("kinds", 1.0, e.display_name if (e.is_champion or e.is_boss) else String(e.variant))
	if e.elite or e.is_champion:
		Game.stats.elites += 1
		Game.stat_add("elites", 1.0)
		Game.quest_advance("elite", e.zone_idx)
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
		var xp := float(e.xp) * float(Data.GRIND.xp_mult) * (1.0 + e.zone_idx * float(Data.GRIND.xp_zone)) * float(Game.diff().xp) * (1.5 if Game.fragments.has("greed") else 1.0)
		player.on_kill(e, xp)
		_drop_loot(e, pos)
		Game.quest_advance("kill", e.zone_idx)
		_flask_kills += 1
		if _flask_kills >= 32:
			_flask_kills = 0
			player.add_flask_charge()
	var globe_chance := 0.035 if not (e.elite or e.is_champion) else 0.3
	if Game.gear_stat("blast") > 0.0:
		hazards_explosion(pos, 70.0 + e.radius * 2.0, e.max_hp * Game.gear_stat("blast") / 100.0, player, Actor.Team.PLAYER, Color(3.0, 1.0, 0.25))
	if randf() < globe_chance:
		drop_globe(pos)
	if Game.fragments.has("embers"):
		var r := 70.0 + e.radius * 2.0
		hazards_explosion(pos, r, e.max_hp * 0.25, player, Actor.Team.PLAYER, Color(3.0, 1.0, 0.25))
	if e.marked and player and player.has_mod("mark_spread"):
		for o in enemies_in_radius(pos, 160.0):
			o.apply_vuln(0.35, 5.0, true)
	if e.is_champion:
		_on_champion_dead(e, pos)
	if e.is_boss:
		_on_boss_dead(e, pos)


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


func _on_champion_dead(e: Enemy, pos: Vector2) -> void:
	var st: Dictionary = rt[e.region]
	var z: int = e.zone_idx
	Game.zs(z).champ_dead = true
	Game.stat_add("champions", 1.0)
	st.state = "altar"
	st.champion = null
	champion = null
	if cur == e.region:
		state = "altar"
	_set_objective()
	shake(14.0)
	Sfx.play("explode")
	var altar := add_prop("altar", st.arena_center)
	altar.radius = 0.0
	st.props.append(altar)
	glow_fx.burst(pos, 40, Color(3.0, 1.2, 0.3), 80, 400, 1.2, 3.5, Particles.SPARK)
	banner.emit("%s falls" % e.display_name, "A crown fragment lies on the altar")
	# A champion always drops a weapon and two more pieces.
	var ilvl := Items.drop_ilvl(z, 2)
	var mf := Game.gear_stat("mf") + float(Game.diff().mf)
	drop_item(Items.roll_drop("champion", ilvl, mf, "weapon", 2), pos)
	for i in 2:
		drop_item(Items.roll_drop("champion", ilvl, mf, "", 2), pos)
	for i in 6:
		drop_gold(int((12.0 + 6.0 * z) * float(Data.GRIND.gold_mult) * (1.0 + Game.gear_stat("gold") / 100.0) * float(Game.diff().gold)), pos)
	Game.quest_advance("champion", z)
	Voice.bark("player", "quest_done", "", 5.0)


func _on_boss_dead(e: Enemy, pos: Vector2) -> void:
	var st: Dictionary = rt[e.region]
	var z: int = e.zone_idx
	Game.zs(z).boss_dead = true
	Game.stat_add("bosses", 1.0)
	st.boss = null
	boss = null
	st.state = "done"
	state = "done"
	_place_crown(e.region)
	_set_objective()
	shake(18.0)
	var ilvl := Items.drop_ilvl(z, 3)
	for it in Items.boss_loot(ilvl):
		drop_item(it, pos)
	for i in 14:
		drop_gold(int((30.0 + 8.0 * z) * float(Data.GRIND.gold_mult) * (1.0 + Game.gear_stat("gold") / 100.0) * float(Game.diff().gold)), pos)
	banner.emit("The Ember King falls", "His crown lies on the throne")
	Game.quest_advance("boss", z)
	Voice.bark("player", "boss_dead", "", 5.0)
	boss_defeated.emit()


# ================================================================ loot

func _scatter(pos: Vector2) -> Vector2:
	for i in 6:
		var p := pos + Vector2.from_angle(randf() * TAU) * randf_range(24.0, 90.0)
		if is_floor_at(p):
			return p
	return pos


## Name tags of gear lying close together are stacked, so each one can be read.
func _stack_loot_tags() -> void:
	var tags: Array[Loot] = []
	for l in loots:
		if l.gold == 0 and not l.done and l.global_position.distance_squared_to(camera.global_position) < 1000000.0:
			tags.append(l)
	tags.sort_custom(func(a: Loot, b: Loot): return a.global_position.x < b.global_position.x)
	for i in tags.size():
		var a := tags[i]
		var dy := 0.0
		var moved := true
		while moved and dy > -110.0:
			moved = false
			for j in i:
				var b := tags[j]
				if absf(a.global_position.x - b.global_position.x) < (a.tag_w + b.tag_w) * 0.5 \
						and absf((a.global_position.y + dy) - (b.global_position.y + b.tag_dy)) < 22.0:
					dy -= 22.0
					moved = true
					break
		a.tag_dy = dy


func _update_hover_loot() -> void:
	_stack_loot_tags()
	hovered_loot = null
	if attract or player == null or player.dead or get_tree().paused:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var m := get_global_mouse_position()
	var best := INF
	for l in loots:
		if not l.done and l.under_cursor(m):
			var d := l.global_position.distance_squared_to(m)
			if d < best:
				best = d
				hovered_loot = l
	if hovered_loot and Input.is_action_just_pressed("attack_1"):
		hovered_loot.pick_up()


func drop_item(item: Dictionary, pos: Vector2) -> void:
	var l := Loot.new()
	l.world = self
	l.item = item
	entity_layer.add_child(l)
	l.global_position = _scatter(pos)
	loots.append(l)
	if int(item.rarity) >= 3:
		glow_fx.ring(l.global_position, 90.0, Color(3.0, 1.4, 0.4, 0.9), 0.6)
		Sfx.play("levelup", -8.0, 0.1, 0.7)
	elif int(item.rarity) == 2:
		Sfx.play("fragment", -14.0, 0.1, 1.2)


func drop_gold(amount: int, pos: Vector2) -> void:
	if amount <= 0:
		return
	var l := Loot.new()
	l.world = self
	l.gold = amount
	entity_layer.add_child(l)
	l.global_position = _scatter(pos)
	loots.append(l)


func _drop_loot(e: Enemy, pos: Vector2) -> void:
	if e.is_champion or e.is_boss:
		return
	var z := e.zone_idx
	var mf := Game.gear_stat("mf") + float(Game.diff().mf)
	var gold_base := (1.5 + e.xp * 0.8) * (1.0 + z * 0.55) * float(Data.GRIND.gold_mult) * (1.0 + Game.gear_stat("gold") / 100.0) * float(Game.diff().gold)
	if e.elite:
		drop_gold(int(round(gold_base * 6.0)), pos)
		drop_item(Items.roll_drop("elite", Items.drop_ilvl(z, 1), mf), pos)
		if randf() < 0.25:
			drop_item(Items.roll_drop("elite", Items.drop_ilvl(z, 1), mf), pos)
		return
	if randf() < 0.5:
		drop_gold(maxi(1, int(round(gold_base * randf_range(0.6, 1.4)))), pos)
	if randf() < float(Data.GRIND.drop_chance):
		drop_item(Items.roll_drop("normal", Items.drop_ilvl(z), mf), pos)


func open_chest(p: Prop) -> void:
	p.used = true
	var z: int = map.regions[cur].zone
	Game.zs(z).chests[p.chest_id] = true
	var iron := p.kind == "chest_iron"
	Game.stat_add("chests", 1.0)
	Sfx.play("hit_heavy", -6.0, 0.1, 0.7)
	glow_fx.burst(p.global_position + Vector2(0, -20), 16, Color(3.0, 2.0, 0.6), 60, 240, 0.7, 2.5, Particles.SPARK)
	var mf := Game.gear_stat("mf") + float(Game.diff().mf)
	var ilvl := Items.drop_ilvl(maxi(z, 0), 1 if iron else 0)
	var n := (2 if iron else 1) + (1 if randf() < (0.4 if iron else 0.4) else 0)
	for i in n:
		drop_item(Items.roll_drop("iron" if iron else "chest", ilvl, mf), p.global_position)
	var gold := int((6.0 + 4.0 * maxi(z, 0)) * randf_range(0.8, 1.4) * (2.0 if iron else 1.0) * float(Data.GRIND.gold_mult) * (1.0 + Game.gear_stat("gold") / 100.0) * float(Game.diff().gold))
	for i in 3:
		drop_gold(maxi(1, gold / 3), p.global_position)
	if not iron and not interior and randf() < 0.1:
		banner.emit("A trap!", "The chest was bait")
		var kinds: Array = (zone.pool as Dictionary).keys()
		for i in 4:
			var a := TAU * i / 4.0 + randf()
			var e := spawn_enemy(kinds[randi() % kinds.size()], p.global_position + Vector2(cos(a), sin(a)) * 120.0, false, cur)
			if not is_floor_at(e.global_position):
				e.global_position = p.global_position
			e.pack = -2
			e.wake()
		Voice.bark("player", "trap", "", 5.0)
	else:
		Voice.bark("player", "chest", "", 40.0)
	Game.quest_advance("chest", z)


# ================================================================ interaction

func _update_interact() -> void:
	interact_target = null
	interact_text = ""
	if not player or player.dead:
		return
	var pp := player.global_position
	var best := 100.0
	for n in npcs:
		var d := n.global_position.distance_to(pp)
		if d < best:
			best = d
			interact_target = n
			interact_text = "Talk to %s" % n.display_name
	for p in interactives:
		if p.kind not in INTERACT_KINDS or p.global_position.distance_to(pp) > 110.0:
			continue
		if p.kind.begins_with("chest") and p.used:
			continue
		var d2 := p.global_position.distance_to(pp)
		if d2 < best:
			best = d2
			interact_target = p
			match p.kind:
				"chest": interact_text = "Open chest"
				"chest_iron": interact_text = "Open iron chest"
				"waypoint": interact_text = "Use waypoint"
				"crown": interact_text = "Take the crown"
				"door": interact_text = "Leave" if p.door_idx < 0 else "Enter %s" % Data.ZONES[p.door_idx].name
	# Waypoints unlock when you first touch them.
	if cur >= 0 and rt[cur].waypoint != null and not interior:
		var wp: Prop = rt[cur].waypoint
		var wid := "z%d" % map.regions[cur].zone
		if map.regions[cur].zone >= 0 and not Game.waypoints.has(wid) and wp.global_position.distance_to(pp) < 90.0:
			Game.unlock(wid)
			banner.emit("Waypoint discovered", "You can now travel here from any waypoint")
			Sfx.play("fragment", -4.0)
			Voice.bark("player", "waypoint", "", 8.0)
			glow_fx.ring(wp.global_position, 120.0, Color(0.8, 1.8, 3.0, 0.9), 0.6)
	if interact_target and Input.is_action_just_pressed("interact"):
		_interact(interact_target)


func _interact(t: Node) -> void:
	if t is Npc:
		npc_talk.emit((t as Npc).kind)
		return
	var p := t as Prop
	match p.kind:
		"chest", "chest_iron": open_chest(p)
		"waypoint": waypoint_open.emit()
		"crown": crown_taken.emit()
		"door":
			if p.door_idx < 0:
				door_exit.emit()
			else:
				door_enter.emit(p.door_idx)


# ================================================================ regions

func _update_region() -> void:
	if interior or not player:
		return
	var c := Vector2i(player.global_position / CELL)
	var i := map.region_at(c.x, c.y)
	if i != cur:
		_enter_region(i)
	# Hint about the arena when no hunt is active
	if cur >= 0 and not village and not _near_arena_msg.has(cur):
		var st: Dictionary = rt[cur]
		var z: int = map.regions[cur].zone
		if player.global_position.distance_to(st.arena_center) < 900.0 and st.champion == null and st.boss == null and not Game.zs(z).champ_dead and not Game.zs(z).boss_dead:
			_near_arena_msg[cur] = true
			banner.emit("Something sleeps here", "Take the hunt from the Elder to wake it")


func _enter_region(i: int) -> void:
	var old := cur
	if old >= 0:
		rt[old].left_at = Time.get_ticks_msec() / 1000.0
	cur = i
	var r: Dictionary = map.regions[i]
	var st: Dictionary = rt[i]
	zone = r.zd
	zone_idx = r.zone
	village = r.zone < 0
	if not st.active:
		_activate_region(i)
	elif Time.get_ticks_msec() / 1000.0 - float(st.left_at) > 150.0 and not village and not interior:
		_respawn_region(i)
	arena_center = st.arena_center
	arena_radius = 13.0 * CELL
	champion = st.champion
	boss = st.boss
	state = st.state
	_target_mod = _lift(zone.modulate)
	if post:
		post.apply_zone(zone)
	_set_objective()
	if not interior and old != i:
		banner.emit(zone.name, zone.line)
		Sfx.ambience(zone.get("ambient", ""))
		Sfx.music("music_title" if village else "music_combat", 2.0)
		for amb in _ambient:
			if amb is CPUParticles2D and amb.material == unshaded_add:
				var vc: Color = zone.vein
				amb.color = Color(vc.r, vc.g, vc.b, 1.0)
	if r.zone >= 0 and not interior:
		var zs := Game.zs(r.zone)
		zs.visited = true
		Game.max_zone = maxi(Game.max_zone, r.zone)
		var act := Data.act_of(r.zone)
		if not Game.acts_seen.has(act):
			Game.acts_seen[act] = true
			act_entered.emit(act)


## Where every unlocked waypoint is. Only places you have touched appear.
func waypoint_targets() -> Array:
	var out: Array = [{"id": "village", "name": "Cinderfall", "sub": "Village", "pos": (map.regions[0].pois.waypoint as Vector2) + Vector2(0, 64)}]
	for i in range(1, map.regions.size()):
		var r: Dictionary = map.regions[i]
		if Game.waypoints.has("z%d" % r.zone):
			out.append({"id": "z%d" % r.zone, "name": r.zd.name, "sub": Data.ACTS[Data.act_of(r.zone)].name, "pos": _cell_pos(r.waypoint) + Vector2(0, 64)})
	return out


func teleport_player(pos: Vector2) -> void:
	player.global_position = pos
	camera.global_position = pos
	camera.reset_smoothing()
	glow_fx.burst(pos, 30, Color(0.8, 1.8, 3.0), 80, 320, 0.8, 3.0, Particles.SPARK)
	Sfx.play("teleport", -4.0)
	_update_region()
	for e in enemies:
		e.drop_aggro()


# ================================================================ recall sigil

func start_recall() -> bool:
	if recall_t > 0.0 or recall_cd > 0.0 or village or player.dead:
		return false
	if state == "boss":
		banner.emit("You cannot leave", "The arena holds you")
		return false
	recall_t = 3.0
	recall_origin = player.global_position
	recall_prop = add_prop("sigil", player.global_position)
	recall_prop.radius = 0.0
	interactives.erase(recall_prop)
	Sfx.play("summon", -4.0, 0.0, 0.8)
	return true


## Leaves a portal in the village that leads back to where the hero recalled from.
func open_town_portal(back_to: Vector2) -> void:
	close_town_portal()
	return_pos = back_to
	var at: Vector2 = map.regions[0].pois.waypoint + Vector2(-110, 70)
	town_portal = add_prop("town_portal", at)
	town_portal.radius = 0.0
	interactives.erase(town_portal)
	Sfx.play("summon", -6.0, 0.0, 1.1)


func close_town_portal() -> void:
	if town_portal and is_instance_valid(town_portal):
		town_portal.queue_free()
		props.erase(town_portal)
	town_portal = null


func cancel_recall() -> void:
	recall_t = 0.0
	if player:
		player.modulate.a = 1.0
		player.scale = Vector2.ONE
	if recall_prop and is_instance_valid(recall_prop):
		recall_prop.queue_free()
		props.erase(recall_prop)
	recall_prop = null


func _update_recall(dt: float) -> void:
	recall_cd = maxf(0.0, recall_cd - dt)
	if town_portal and is_instance_valid(town_portal) and village and not player.dead:
		if player.global_position.distance_to(town_portal.global_position) < 46.0 and town_portal.t > 0.8:
			var dest := return_pos
			close_town_portal()
			portal_return.emit(dest)
	if Input.is_action_just_pressed("recall") and not get_tree().paused:
		start_recall()
	if recall_t <= 0.0:
		return
	if player.dead or player.hurt_t > 0.0:
		cancel_recall()
		banner.emit("Recall interrupted", "")
		recall_cd = 1.0
		return
	recall_t -= dt
	# in the last moments the portal draws the hero in
	var pull := clampf(1.0 - recall_t / 0.6, 0.0, 1.0)
	player.modulate.a = 1.0 - pull * 0.9
	player.scale = Vector2.ONE * (1.0 - pull * 0.45)
	if recall_t <= 0.0:
		cancel_recall()
		recall_cd = 0.0
		Voice.bark("player", "recall", "", 5.0)
		recall_done.emit()


func claim_fragment_done() -> void:
	var z: int = zone_idx
	Game.zs(z).claimed = true
	rt[cur].state = "portal"
	state = "portal"
	_set_objective()
	open_gates(cur)
	banner.emit("The way onward is open", "The tunnel gate grinds aside")


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
		if post and amount >= 6.0:
			post.kick = maxf(post.kick, minf(1.0, amount / 20.0))


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


func is_explored(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return false
	return explored[c.y * map.w + c.x] == 1


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
			var idx := y * map.w + x
			if explored[idx] == 1:
				continue
			explored[idx] = 1
			if map.is_floor(x, y):
				minimap_img.set_pixel(x, y, Color(0.55, 0.5, 0.46, 0.75))
				_minimap_dirty = true
			else:
				var edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if map.is_floor(x + d.x, y + d.y):
						edge = true
				if edge:
					minimap_img.set_pixel(x, y, Color(0.95, 0.75, 0.5, 0.95))
					_minimap_dirty = true


func respawn_player() -> void:
	player.revive()
	player.global_position = _cell_pos(map.regions[cur].start)
	camera.reset_smoothing()
	cancel_recall()
	for e in enemies:
		e.drop_aggro()
	if state == "boss" and boss:
		state = "explore"
		rt[cur].state = "explore"
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




func spawn_quest_bosses() -> void:
	for i in rt.size():
		if rt[i].active:
			spawn_quest_boss(i)
	champion = rt[cur].champion
	boss = rt[cur].boss


var _last_pos := Vector2.ZERO


func _track_distance() -> void:
	if player == null or player.dead:
		return
	var d := player.global_position.distance_to(_last_pos)
	if d < 300.0 and _last_pos != Vector2.ZERO:
		Game.stat_add("distance", d / 64.0)
	_last_pos = player.global_position


# ================================================================ wayfinding

## Where the guide leads: your own marker if you set one, otherwise whatever the active quest asks.
func guide_target() -> Vector2:
	if not Game.markers.is_empty():
		return Game.markers[Game.markers.size() - 1]
	return objective_pos


func guide_is_marker() -> bool:
	return not Game.markers.is_empty()


func _ensure_guide_grid() -> void:
	if _astar != null or interior or attract:
		return
	const GS := 4
	var cw := ceili(map.w / float(GS))
	var ch := ceili(map.h / float(GS))
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, cw, ch)
	_astar.cell_size = Vector2(GS * CELL, GS * CELL)
	_astar.offset = Vector2(GS * CELL, GS * CELL) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cy in ch:
		for cx in cw:
			var n := 0
			for y in GS:
				for x in GS:
					if map.is_floor(cx * GS + x, cy * GS + y):
						n += 1
			if n < 6:
				_astar.set_point_solid(Vector2i(cx, cy))


func _update_guide(dt: float) -> void:
	_guide_t -= dt
	if _guide_t > 0.0 or player == null:
		return
	_guide_t = 0.7
	_ensure_guide_grid()
	guide_pts = PackedVector2Array()
	if _astar == null:
		return
	var target := guide_target()
	if target.distance_to(player.global_position) < 500.0 or target == Vector2.ZERO:
		return
	var gs := 4.0 * CELL
	var a := Vector2i(player.global_position / gs)
	var b := Vector2i(target / gs)
	if _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return
	var path := _astar.get_point_path(a, b)
	var out := PackedVector2Array()
	var travelled := 0.0
	var prev := player.global_position
	for i in range(1, path.size()):
		travelled += prev.distance_to(path[i])
		prev = path[i]
		out.append(path[i])
		if travelled > 1500.0:
			break
	guide_pts = out


func _draw_guide() -> void:
	if player == null or guide_pts.is_empty() or player.dead:
		return
	var col := Color(0.6, 1.6, 2.4) if guide_is_marker() else Color(2.6, 1.7, 0.6)
	var pos := player.global_position
	var t := Time.get_ticks_msec() / 1000.0
	var dist_acc := 0.0
	for p in guide_pts:
		var seg := p - pos
		var len := seg.length()
		var dir := seg / maxf(len, 0.001)
		var d := fmod(t * 120.0, 80.0) - dist_acc
		while d < len:
			if d > 0.0:
				var q := pos + dir * d
				var total := dist_acc + d
				var a := clampf(1.0 - total / 1500.0, 0.0, 1.0) * 0.8
				Ink.glow(guide_node, q, 6.0, Color(col.r, col.g, col.b, a * 0.4))
				guide_node.draw_circle(q, 1.3, Color(col.r, col.g, col.b, a * 0.8), true, -1.0, true)
			d += 80.0
		dist_acc += len
		pos = p
