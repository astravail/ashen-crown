class_name Prop
extends Node2D
## Static scenery and interactive objects (shrines, altar, portal).

var world: World
var kind := "rock"
var seed_value := 0
var radius := 0.0
var used := false
var light: PointLight2D
var glow: Node2D
var t := 0.0
var rng := RandomNumberGenerator.new()
var shape := PackedVector2Array()
var scale_v := 1.0
var branches: Array = []
var chest_id := 0
var door_idx := -1


func init() -> void:
	rng.seed = seed_value
	scale_v = rng.randf_range(0.8, 1.25)
	glow = Node2D.new()
	glow.material = World.unshaded_add
	add_child(glow)
	glow.draw.connect(_draw_glow)
	match kind:
		"rock":
			radius = 22.0 * scale_v
			_make_rock(radius * 1.25)
		"rubble":
			radius = 0.0
			_make_rock(16.0 * scale_v)
		"dead_tree":
			radius = 13.0
			_make_tree()
		"pillar":
			radius = 26.0
		"grave":
			radius = 12.0
		"brazier":
			radius = 18.0
			light = world.make_light(Color(1.0, 0.55, 0.25), 1.2, 620.0)
			add_child(light)
			light.position = Vector2(0, -38)
		"banner":
			radius = 10.0
		"spike":
			radius = 18.0 * scale_v
			_make_rock(22.0 * scale_v)
		"chain":
			radius = 0.0
		"reeds":
			radius = 0.0
		"pine":
			radius = 15.0 * scale_v
		"stump":
			radius = 12.0 * scale_v
		"hanged":
			radius = 10.0
		"impaled":
			radius = 10.0
		"bones":
			radius = 0.0
		"skull_pile":
			radius = 20.0 * scale_v
		"sarcophagus":
			radius = 24.0
		"candles":
			radius = 0.0
			light = world.make_light(Color(1.0, 0.7, 0.4), 0.7, 300.0)
			add_child(light)
			light.position = Vector2(0, -16)
		"hut":
			radius = 50.0
		"stall":
			radius = 26.0
		"well":
			radius = 22.0
		"barrel", "crate":
			radius = 12.0
		"bonfire":
			radius = 14.0
			light = world.make_light(Color(1.0, 0.55, 0.25), 1.6, 900.0)
			add_child(light)
			light.position = Vector2(0, -20)
		"chest", "chest_iron", "crown", "door", "gate_seg":
			radius = 0.0
			if kind == "crown":
				light = world.make_light(Color(1.0, 0.7, 0.3), 1.6, 700.0)
				add_child(light)
			if kind == "gate_seg":
				radius = 34.0
		"waypoint":
			radius = 0.0
			light = world.make_light(Color(0.5, 0.8, 1.0), 1.2, 560.0)
			add_child(light)
		"altar", "portal", "throne":
			light = world.make_light(Color(1.0, 0.6, 0.3), 1.6, 900.0)
			add_child(light)
		_:
			if kind.begins_with("shrine"):
				radius = 0.0
				light = world.make_light(_shrine_color(), 1.1, 520.0)
				add_child(light)


func _shrine_color() -> Color:
	match kind:
		"shrine_fury": return Color(1.0, 0.35, 0.2)
		"shrine_warding": return Color(0.5, 0.75, 1.0)
		_: return Color(0.6, 1.0, 0.6)


func _make_rock(r: float) -> void:
	var n := rng.randi_range(6, 9)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var rr := r * rng.randf_range(0.7, 1.1)
		shape.append(Vector2(cos(a) * rr, sin(a) * rr * 0.62 - r * 0.25))


func _make_tree() -> void:
	_branch(Vector2(0, 0), -PI / 2 + rng.randf_range(-0.2, 0.2), 70.0 * scale_v, 9.0, 0)


func _branch(from: Vector2, ang: float, length: float, width: float, depth: int) -> void:
	var to := from + Vector2(cos(ang), sin(ang)) * length
	branches.append([from, to, width])
	if depth >= 3:
		return
	var n := rng.randi_range(2, 3)
	for i in n:
		_branch(to, ang + rng.randf_range(-0.8, 0.8), length * rng.randf_range(0.45, 0.7), width * 0.6, depth + 1)


func update(dt: float) -> void:
	t += dt
	if light and kind == "brazier":
		light.energy = 1.1 + 0.15 * sin(t * 9.0) + 0.1 * sin(t * 23.0 + seed_value)
		if rng.randf() < dt * 7.0:
			world.glow_fx.emit(global_position + Vector2(rng.randf_range(-8, 8), -44), Vector2(rng.randf_range(-15, 15), rng.randf_range(-90, -50)), rng.randf_range(0.8, 1.6), rng.randf_range(1.5, 3.0), Color(3.0, 1.2, 0.35), Particles.EMBER, 0.6)
	if light and kind == "candles":
		light.energy = 0.6 + 0.08 * sin(t * 13.0 + seed_value) + 0.05 * sin(t * 29.0)
	if kind == "hanged" and rng.randf() < dt * 0.6 and Game.settings.get("gore", true):
		world.smoke_fx.emit(global_position + Vector2(36 + sin(t * 0.9 + seed_value) * 3.0, -40), Vector2(0, 30), 0.7, 1.8, Color(0.3, 0.02, 0.02, 0.9), Particles.EMBER, 0.0, 300.0)
	if kind.begins_with("shrine") and used and light:
		light.energy = move_toward(light.energy, 0.15, dt)
	if kind == "bonfire":
		light.energy = 1.5 + 0.2 * sin(t * 9.0) + 0.12 * sin(t * 23.0)
		if rng.randf() < dt * 14.0:
			world.glow_fx.emit(global_position + Vector2(rng.randf_range(-8, 8), -26), Vector2(rng.randf_range(-15, 15), rng.randf_range(-110, -60)), rng.randf_range(0.8, 1.6), rng.randf_range(1.5, 3.2), Color(3.0, 1.2, 0.35), Particles.EMBER, 0.6)
	if kind == "sigil" and rng.randf() < dt * 20.0:
		var a6 := rng.randf() * TAU
		world.glow_fx.emit(global_position + Vector2(cos(a6), sin(a6) * 0.5) * 40.0, Vector2(0, -120), 1.0, 2.4, Color(0.8, 1.8, 3.0), Particles.EMBER, 0.4)
	if kind == "waypoint" and rng.randf() < dt * 10.0:
		var a2 := rng.randf() * TAU
		world.glow_fx.emit(global_position + Vector2(cos(a2), sin(a2) * 0.5) * 46.0, Vector2(0, -70), 1.2, 2.2, Color(0.8, 1.8, 3.0), Particles.EMBER, 0.4)
	if kind == "portal" and rng.randf() < dt * 30.0:
		var a := rng.randf() * TAU
		world.glow_fx.emit(global_position + Vector2(cos(a), sin(a) * 0.5) * 70.0, -Vector2(cos(a), sin(a) * 0.5) * 60.0, 1.0, 3.0, Color(3.0, 1.0, 0.3), Particles.EMBER, 0.5)
	if kind == "altar" and not used and rng.randf() < dt * 10.0:
		world.glow_fx.emit(global_position + Vector2(rng.randf_range(-20, 20), -60), Vector2(rng.randf_range(-10, 10), -50), 1.4, 2.5, Color(3.0, 1.5, 0.5), Particles.EMBER, 0.4)
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	match kind:
		"rock", "rubble", "spike":
			_draw_rock()
		"dead_tree":
			_shadow(26)
			for b in branches:
				draw_line(b[0], b[1], Color(0.07, 0.06, 0.055), b[2] + 2.0, true)
			for b in branches:
				draw_line(b[0], b[1], Color(0.16, 0.13, 0.11), b[2], true)
		"pillar":
			_shadow(34)
			var h := 120.0 * scale_v if rng.seed % 3 != 0 else 50.0
			draw_rect(Rect2(-24, -h, 48, h), Color(0.2, 0.19, 0.2))
			draw_rect(Rect2(-24, -h, 14, h), Color(0.28, 0.27, 0.28))
			draw_rect(Rect2(-30, -10, 60, 14), Color(0.16, 0.15, 0.16))
			draw_rect(Rect2(-30, -h - 8, 60, 12), Color(0.24, 0.23, 0.24))
			for i in 3:
				draw_line(Vector2(-12 + i * 12, -h + 6), Vector2(-12 + i * 12, -14), Color(0.12, 0.11, 0.12), 2.0)
		"grave":
			_shadow(18)
			draw_rect(Rect2(-12, -34, 24, 34), Color(0.24, 0.23, 0.23))
			draw_circle(Vector2(0, -34), 12, Color(0.24, 0.23, 0.23), true, -1.0, true)
			draw_line(Vector2(0, -38), Vector2(0, -16), Color(0.12, 0.11, 0.11), 3.0)
			draw_line(Vector2(-7, -30), Vector2(7, -30), Color(0.12, 0.11, 0.11), 3.0)
		"brazier":
			_shadow(22)
			draw_line(Vector2(-14, 0), Vector2(-8, -30), Color(0.12, 0.1, 0.09), 4.0)
			draw_line(Vector2(14, 0), Vector2(8, -30), Color(0.12, 0.1, 0.09), 4.0)
			draw_line(Vector2(0, 2), Vector2(0, -30), Color(0.12, 0.1, 0.09), 4.0)
			var bowl := PackedVector2Array([Vector2(-22, -40), Vector2(22, -40), Vector2(14, -28), Vector2(-14, -28)])
			draw_colored_polygon(bowl, Color(0.2, 0.17, 0.15))
			draw_line(Vector2(-22, -40), Vector2(22, -40), Color(0.35, 0.28, 0.22), 3.0)
		"banner":
			_shadow(10)
			draw_line(Vector2(0, 0), Vector2(0, -110), Color(0.15, 0.12, 0.1), 4.0)
			draw_line(Vector2(-22, -104), Vector2(22, -104), Color(0.15, 0.12, 0.1), 3.0)
			var cloth := PackedVector2Array([Vector2(-18, -104), Vector2(18, -104), Vector2(16, -50), Vector2(4, -60), Vector2(-6, -44), Vector2(-17, -56)])
			draw_colored_polygon(cloth, Color(0.32, 0.08, 0.06))
			draw_circle(Vector2(0, -84), 6, Color(0.55, 0.35, 0.12), true, -1.0, true)
		"chain":
			for i in 8:
				var p := Vector2(i * 9 - 36, sin(i * 0.8 + seed_value) * 6)
				draw_arc(p, 5, 0, TAU, 10, Color(0.2, 0.18, 0.17), 2.0, true)
		"reeds":
			for i in 7:
				var x := rng.randf_range(-16, 16) if false else (i - 3) * 5.0
				var hh := 30.0 + (seed_value >> (i * 3) & 7) * 4.0
				var sway := sin(t * 1.5 + i + seed_value) * 4.0
				draw_line(Vector2(x, 0), Vector2(x + sway, -hh), Color(0.22, 0.24, 0.17), 2.0, true)
		"pine":
			_draw_pine()
		"stump":
			_shadow(16)
			var sr := 12.0 * scale_v
			draw_rect(Rect2(-sr, -14, sr * 2.0, 14), Color(0.11, 0.09, 0.07))
			draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, sr, Color(0.26, 0.2, 0.14), true, -1.0, true)
			draw_arc(Vector2.ZERO, sr * 0.65, 0.0, TAU, 20, Color(0.18, 0.13, 0.09), 1.5, true)
			draw_arc(Vector2.ZERO, sr * 0.3, 0.0, TAU, 14, Color(0.18, 0.13, 0.09), 1.5, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"hanged":
			_draw_hanged()
		"impaled":
			_draw_impaled()
		"bones":
			_draw_bones(Vector2.ZERO, 1.0)
			_draw_bones(Vector2(rng.seed % 30 - 15, 10), 0.7)
		"skull_pile":
			_shadow(30)
			var k := 0
			for row in 4:
				var cnt := 5 - row
				for i in cnt:
					var sp := Vector2((i - (cnt - 1) * 0.5) * 13.0 * scale_v, -row * 10.0 * scale_v - 6.0)
					_skull(sp + Vector2(sin(k * 1.7 + seed_value) * 2.0, 0), 6.5 * scale_v, 0.75 + 0.1 * ((k * 7) % 3))
					k += 1
		"sarcophagus":
			_shadow(36)
			draw_rect(Rect2(-34, -30, 68, 30), Color(0.17, 0.16, 0.15))
			draw_rect(Rect2(-34, -30, 68, 6), Color(0.1, 0.095, 0.09))
			var lid := PackedVector2Array([Vector2(-36, -30), Vector2(36, -30), Vector2(30, -48), Vector2(-30, -48)])
			draw_colored_polygon(lid, Color(0.26, 0.25, 0.23))
			draw_line(Vector2(0, -46), Vector2(0, -32), Color(0.12, 0.11, 0.1), 3.0)
			draw_line(Vector2(-8, -42), Vector2(8, -42), Color(0.12, 0.11, 0.1), 3.0)
			if rng.seed % 2 == 0:
				# Lid pushed aside: something got out
				draw_colored_polygon(PackedVector2Array([Vector2(-30, -48), Vector2(-6, -48), Vector2(-10, -34), Vector2(-30, -34)]), Color(0.03, 0.025, 0.025))
		"candles":
			for i in 4:
				var cp := Vector2((i - 1.5) * 9.0, (i % 2) * 5.0)
				var ch := 10.0 + float((seed_value >> (i * 2)) & 3) * 4.0
				draw_rect(Rect2(cp.x - 2.5, cp.y - ch, 5, ch), Color(0.55, 0.5, 0.42))
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 22, Color(0.5, 0.46, 0.38, 0.35), true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"throne":
			_shadow(70)
			draw_rect(Rect2(-60, -150, 120, 150), Color(0.1, 0.08, 0.08))
			draw_rect(Rect2(-75, -40, 150, 40), Color(0.14, 0.11, 0.1))
			var spikes := PackedVector2Array([Vector2(-60, -150), Vector2(-48, -200), Vector2(-30, -155), Vector2(0, -215), Vector2(30, -155), Vector2(48, -200), Vector2(60, -150)])
			draw_colored_polygon(spikes, Color(0.12, 0.09, 0.08))
		"hut":
			_shadow(60)
			draw_rect(Rect2(-50, -62, 100, 62), Color(0.16, 0.12, 0.09))
			draw_rect(Rect2(-50, -62, 100, 8), Color(0.1, 0.08, 0.06))
			draw_colored_polygon(PackedVector2Array([Vector2(-64, -58), Vector2(64, -58), Vector2(40, -106), Vector2(-40, -106)]), Color(0.1, 0.07, 0.06))
			draw_line(Vector2(-64, -58), Vector2(64, -58), Color(0.2, 0.14, 0.1), 3.0)
			draw_rect(Rect2(-9, -32, 18, 32), Color(0.05, 0.035, 0.03))
			draw_rect(Rect2(22, -46, 14, 14), Color(0.12, 0.1, 0.08))
		"stall":
			_shadow(34)
			draw_line(Vector2(-26, 0), Vector2(-26, -58), Color(0.15, 0.11, 0.08), 4.0)
			draw_line(Vector2(26, 0), Vector2(26, -58), Color(0.15, 0.11, 0.08), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-34, -58), Vector2(34, -58), Vector2(28, -74), Vector2(-28, -74)]), Color(0.38, 0.1, 0.07))
			draw_rect(Rect2(-28, -24, 56, 10), Color(0.2, 0.15, 0.1))
			draw_rect(Rect2(-22, -30, 10, 6), Color(0.45, 0.4, 0.34))
			draw_rect(Rect2(2, -30, 14, 6), Color(0.3, 0.28, 0.3))
		"well":
			_shadow(26)
			draw_set_transform(Vector2(0, -8), 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 22, Color(0.2, 0.19, 0.18), true, -1.0, true)
			draw_circle(Vector2.ZERO, 15, Color(0.02, 0.03, 0.04), true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_line(Vector2(-18, -10), Vector2(-18, -44), Color(0.15, 0.11, 0.08), 3.0)
			draw_line(Vector2(18, -10), Vector2(18, -44), Color(0.15, 0.11, 0.08), 3.0)
			draw_line(Vector2(-22, -44), Vector2(22, -44), Color(0.15, 0.11, 0.08), 3.0)
		"barrel":
			_shadow(14)
			draw_rect(Rect2(-10, -24, 20, 24), Color(0.2, 0.14, 0.09))
			draw_line(Vector2(-10, -17), Vector2(10, -17), Color(0.1, 0.09, 0.08), 2.0)
			draw_line(Vector2(-10, -7), Vector2(10, -7), Color(0.1, 0.09, 0.08), 2.0)
		"crate":
			_shadow(16)
			draw_rect(Rect2(-12, -22, 24, 22), Color(0.22, 0.17, 0.11))
			draw_rect(Rect2(-12, -22, 24, 22), Color(0.1, 0.08, 0.06), false, 2.0)
			draw_line(Vector2(-12, -22), Vector2(12, 0), Color(0.1, 0.08, 0.06), 2.0)
		"bonfire":
			_shadow(26)
			for i in 5:
				var a3 := TAU * i / 5.0
				draw_line(Vector2(cos(a3), sin(a3) * 0.5) * 18, Vector2(0, -8), Color(0.14, 0.1, 0.07), 5.0, true)
		"chest", "chest_iron":
			_shadow(20)
			var wood := Color(0.24, 0.16, 0.1) if kind == "chest" else Color(0.16, 0.15, 0.16)
			var band := Color(0.5, 0.4, 0.2) if kind == "chest" else Color(0.5, 0.2, 0.12)
			draw_rect(Rect2(-18, -20, 36, 20), wood)
			draw_rect(Rect2(-18, -20, 36, 4), wood.lightened(0.1))
			if used:
				draw_colored_polygon(PackedVector2Array([Vector2(-18, -20), Vector2(18, -20), Vector2(14, -38), Vector2(-14, -38)]), wood.darkened(0.2))
				draw_rect(Rect2(-14, -20, 28, 4), Color(0.02, 0.015, 0.015))
			else:
				draw_rect(Rect2(-18, -32, 36, 12), wood.lightened(0.05))
				draw_arc(Vector2(0, -32), 18.0, PI, TAU, 14, wood.lightened(0.05), 2.0, true)
				draw_rect(Rect2(-3, -24, 6, 7), band)
			draw_line(Vector2(-12, -20), Vector2(-12, 0), band, 2.0)
			draw_line(Vector2(12, -20), Vector2(12, 0), band, 2.0)
		"waypoint":
			_shadow(46)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 46, Color(0.12, 0.13, 0.15), true, -1.0, true)
			draw_arc(Vector2.ZERO, 40, 0.0, TAU, 32, Color(0.3, 0.35, 0.42), 3.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 4:
				var a4 := TAU * i / 4.0 + PI / 4.0
				var bp := Vector2(cos(a4) * 38, sin(a4) * 19)
				draw_rect(Rect2(bp + Vector2(-5, -30), Vector2(10, 30)), Color(0.18, 0.18, 0.2))
		"door":
			_shadow(30)
			draw_rect(Rect2(-24, -64, 48, 64), Color(0.1, 0.08, 0.07))
			draw_rect(Rect2(-18, -56, 36, 56), Color(0.03, 0.025, 0.02))
			draw_arc(Vector2(0, -56), 18.0, PI, TAU, 14, Color(0.18, 0.14, 0.1), 5.0, true)
		"gate_seg":
			_shadow(38)
			draw_rect(Rect2(-30, -90, 60, 90), Color(0.08, 0.07, 0.07))
			draw_rect(Rect2(-30, -90, 60, 10), Color(0.2, 0.17, 0.15))
			for i in 4:
				draw_line(Vector2(-22 + i * 14, -80), Vector2(-22 + i * 14, -6), Color(0.15, 0.14, 0.15), 3.0)
		"crown":
			_shadow(30)
			draw_rect(Rect2(-26, -22, 52, 22), Color(0.14, 0.11, 0.1))
		"altar":
			_shadow(50)
			draw_rect(Rect2(-46, -34, 92, 34), Color(0.2, 0.18, 0.17))
			draw_rect(Rect2(-54, -42, 108, 10), Color(0.27, 0.24, 0.22))
			draw_rect(Rect2(-46, -6, 92, 6), Color(0.12, 0.1, 0.1))
		"portal":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 82, Color(0.02, 0.01, 0.01), true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			if kind.begins_with("shrine"):
				_shadow(30)
				draw_rect(Rect2(-18, -70, 36, 70), Color(0.18, 0.17, 0.17) if not used else Color(0.12, 0.11, 0.11))
				var top := PackedVector2Array([Vector2(-24, -70), Vector2(0, -92), Vector2(24, -70)])
				draw_colored_polygon(top, Color(0.22, 0.2, 0.2))


func _draw_rock() -> void:
	if shape.is_empty():
		return
	_shadow(radius + 10.0 if radius > 0.0 else 18.0)
	var c := Color(0.17, 0.155, 0.15) if kind != "spike" else Color(0.07, 0.05, 0.06)
	if kind == "spike":
		var tip := Vector2(rng.seed % 20 - 10, -90.0 * scale_v)
		for i in shape.size():
			var a := shape[i]
			var b := shape[(i + 1) % shape.size()]
			var lit := 0.06 + 0.12 * maxf(0.0, -(b - a).normalized().y)
			draw_colored_polygon(PackedVector2Array([a, b, tip]), c + Color(lit, lit * 0.8, lit * 0.9))
		return
	draw_colored_polygon(shape, c)
	var top := PackedVector2Array()
	for p in shape:
		top.append(p * 0.62 + Vector2(-3, -8))
	draw_colored_polygon(top, c.lightened(0.18))


func _draw_pine() -> void:
	_shadow(30 * scale_v)
	var s := scale_v * 1.1
	draw_rect(Rect2(-4 * s, -26 * s, 8 * s, 26 * s), Color(0.09, 0.07, 0.05))
	var tiers := 4
	for i in tiers:
		var y := -22.0 * s - i * 30.0 * s
		var w := (40.0 - i * 8.0) * s
		var h := 46.0 * s
		var sway := sin(t * 0.7 + seed_value + i) * 1.5 * i
		var dark := Color(0.05, 0.075, 0.06)
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(sway, y - h)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.15, y), Vector2(w, y), Vector2(sway, y - h)]), dark.lightened(0.07))


func _draw_hanged() -> void:
	_shadow(14)
	var wood := Color(0.14, 0.11, 0.09)
	draw_line(Vector2(0, 0), Vector2(0, -130), wood, 7.0)
	draw_line(Vector2(-4, -126), Vector2(46, -126), wood, 6.0)
	draw_line(Vector2(0, -100), Vector2(22, -124), wood, 4.0)
	var sw := sin(t * 0.9 + seed_value) * 0.06
	var top := Vector2(38, -124)
	var neck := top + Vector2(0, 34).rotated(sw)
	draw_line(top, neck, Color(0.3, 0.26, 0.18), 1.5, true)
	draw_set_transform(neck, sw, Vector2.ONE)
	var body := Color(0.16, 0.13, 0.12)
	draw_circle(Vector2(0, 6), 7, Color(0.3, 0.25, 0.22), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 12), Vector2(8, 12), Vector2(7, 46), Vector2(-7, 46)]), body)
	draw_line(Vector2(-3, 46), Vector2(-4, 68), body, 4.0)
	draw_line(Vector2(3, 46), Vector2(4, 68), body, 4.0)
	draw_line(Vector2(-8, 14), Vector2(-10, 40), body, 3.0)
	draw_line(Vector2(8, 14), Vector2(10, 40), body, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Game.settings.get("gore", true):
		draw_set_transform(Vector2(38, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 12, Color(0.25, 0.02, 0.02, 0.8), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_impaled() -> void:
	_shadow(14)
	var wood := Color(0.15, 0.11, 0.08)
	var gore: bool = Game.settings.get("gore", true)
	if gore:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 20, Color(0.25, 0.02, 0.02, 0.85), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(0, 0), Vector2(0, -120), wood, 6.0)
	var body := Color(0.18, 0.14, 0.13)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -64), Vector2(9, -64), Vector2(8, -96), Vector2(-8, -96)]), body)
	draw_circle(Vector2(5, -100), 7, Color(0.3, 0.25, 0.22), true, -1.0, true)
	draw_line(Vector2(-8, -92), Vector2(-20, -70), body, 3.0)
	draw_line(Vector2(8, -92), Vector2(18, -112), body, 3.0)
	draw_line(Vector2(-4, -64), Vector2(-10, -40), body, 4.0)
	draw_line(Vector2(4, -64), Vector2(8, -42), body, 4.0)
	draw_line(Vector2(0, -120), Vector2(0, -132), wood.lightened(0.1), 3.0)
	if gore:
		draw_line(Vector2(-1, -64), Vector2(-1, -8), Color(0.32, 0.02, 0.02, 0.9), 3.0)
		draw_line(Vector2(0, -104), Vector2(0, -130), Color(0.35, 0.03, 0.03, 0.9), 2.5)


func _skull(p: Vector2, r: float, shade_v: float) -> void:
	var bone := Color(0.62, 0.58, 0.5) * shade_v
	bone.a = 1.0
	draw_circle(p, r, bone, true, -1.0, true)
	draw_rect(Rect2(p.x - r * 0.55, p.y + r * 0.4, r * 1.1, r * 0.55), bone)
	draw_circle(p + Vector2(-r * 0.38, 0), r * 0.27, Color(0.04, 0.03, 0.03), true, -1.0, true)
	draw_circle(p + Vector2(r * 0.38, 0), r * 0.27, Color(0.04, 0.03, 0.03), true, -1.0, true)


func _draw_bones(p: Vector2, s: float) -> void:
	var bone := Color(0.58, 0.54, 0.46)
	var a := float(rng.seed % 100) / 100.0 * PI
	draw_line(p + Vector2(-12, -3).rotated(a) * s, p + Vector2(12, 3).rotated(a) * s, bone, 3.0 * s, true)
	draw_line(p + Vector2(-10, 5).rotated(a + 0.8) * s, p + Vector2(10, -5).rotated(a + 0.8) * s, bone, 3.0 * s, true)
	_skull(p + Vector2(10, -6) * s, 6.0 * s, 0.9)


func _shadow(r: float) -> void:
	draw_set_transform(Vector2(6, 4), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	match kind:
		"brazier":
			for i in 3:
				var fl := 1.0 + 0.2 * sin(t * (11.0 + i * 3.0) + i)
				var pts := PackedVector2Array([Vector2(-16 + i * 4, -40), Vector2(16 - i * 4, -40), Vector2(sin(t * 6.0 + i) * 4.0, -40 - (26 - i * 6) * fl)])
				var c: Color = [Color(2.6, 0.7, 0.15, 0.9), Color(3.2, 1.3, 0.3, 0.9), Color(4.0, 2.6, 1.2, 1.0)][i]
				glow.draw_colored_polygon(pts, c)
		"altar":
			if not used:
				var y := -70.0 + sin(t * 2.0) * 6.0
				_crown_shard(Vector2(0, y), 1.0)
				glow.draw_circle(Vector2(0, y), 34, Color(1.5, 0.6, 0.15, 0.18), true, -1.0, true)
		"portal":
			glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			for i in 4:
				var a := t * (1.2 + i * 0.4) + i
				glow.draw_arc(Vector2.ZERO, 70 - i * 13, a, a + PI * 1.3, 40, Color(3.0, 1.0 + i * 0.3, 0.25, 0.7), 4.0, true)
			glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"crown":
			if not used:
				_crown_shard(Vector2(0, -50.0 + sin(t * 2.0) * 5.0), 1.3)
		"door":
			glow.draw_rect(Rect2(-14, -50, 28, 50), Color(0.8, 0.45, 0.15, 0.15 + 0.05 * sin(t * 3.0)))
		"waypoint":
			var pulse2 := 0.7 + 0.3 * sin(t * 2.5)
			glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			glow.draw_arc(Vector2.ZERO, 30, t, t + PI * 1.4, 24, Color(0.8, 1.8, 3.0, pulse2), 3.0, true)
			glow.draw_arc(Vector2.ZERO, 18, -t * 1.3, -t * 1.3 + PI, 18, Color(1.0, 2.0, 3.0, pulse2), 2.5, true)
			glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 4:
				var a5 := TAU * i / 4.0 + PI / 4.0
				glow.draw_circle(Vector2(cos(a5) * 38, sin(a5) * 19 - 32), 3.0, Color(0.9, 2.0, 3.0, pulse2), true, -1.0, true)
		"hut":
			glow.draw_rect(Rect2(22, -46, 14, 14), Color(2.4, 1.2, 0.4, 0.85))
			glow.draw_circle(Vector2(29, -39), 26, Color(1.6, 0.7, 0.2, 0.09), true, -1.0, true)
		"candles":
			for i in 4:
				var cp := Vector2((i - 1.5) * 9.0, (i % 2) * 5.0)
				var ch := 10.0 + float((seed_value >> (i * 2)) & 3) * 4.0
				var fl := 1.0 + 0.25 * sin(t * (12.0 + i) + i)
				glow.draw_colored_polygon(PackedVector2Array([cp + Vector2(-2.5, -ch), cp + Vector2(2.5, -ch), cp + Vector2(sin(t * 7.0 + i), -ch - 8.0 * fl)]), Color(3.2, 1.6, 0.5, 0.95))
				glow.draw_circle(cp + Vector2(0, -ch - 3), 7, Color(1.4, 0.7, 0.2, 0.15), true, -1.0, true)
		"throne":
			glow.draw_line(Vector2(-60, -150), Vector2(60, -150), Color(2.0, 0.5, 0.1, 0.6), 2.0)
		_:
			if kind.begins_with("shrine") and not used:
				var c := _shrine_color()
				var pulse := 0.7 + 0.3 * sin(t * 3.0)
				glow.draw_circle(Vector2(0, -48), 9, Color(c.r * 3.0, c.g * 3.0, c.b * 3.0, pulse), true, -1.0, true)
				glow.draw_circle(Vector2(0, -48), 22, Color(c.r, c.g, c.b, 0.15 * pulse), true, -1.0, true)


func _crown_shard(p: Vector2, s: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-16, 10) * s, p + Vector2(-18, -8) * s, p + Vector2(-7, 0) * s, p + Vector2(0, -16) * s, p + Vector2(7, 0) * s, p + Vector2(12, -6) * s, p + Vector2(10, 10) * s])
	glow.draw_colored_polygon(pts, Color(3.2, 1.6, 0.5))
	glow.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(4.0, 2.6, 1.2), 1.5, true)
