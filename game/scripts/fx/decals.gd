class_name Decals
extends Node2D
## Ground marks: blood pools and spatter, torn remains, ash piles and scorch marks.

var world: World
var items: Array[Dictionary] = []


func add_ash(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var n := 12
	var seed_v := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var rr := r * (0.7 + 0.35 * sin(a * 3.0 + seed_v) + randf_range(-0.1, 0.1))
		pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * 0.55))
	items.append({"type": 0, "pos": p, "r": r, "pts": pts, "t": 40.0, "max": 40.0, "seed": seed_v})
	_trim()


## A splash of blood thrown along dir. Big ones (pools) linger for a long time.
func add_blood(p: Vector2, r: float, dir: Vector2, c: Color, pool := false) -> void:
	var pts := PackedVector2Array()
	var n := 14
	var seed_v := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var rr := r * (0.6 + 0.3 * sin(a * 4.0 + seed_v) + randf_range(-0.15, 0.2))
		pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * 0.55))
	var drops: Array = []
	var nd := randi_range(4, 9) if pool else randi_range(2, 5)
	for i in nd:
		var off := dir.rotated(randf_range(-0.6, 0.6)) * r * randf_range(0.8, 2.6)
		drops.append([p + Vector2(off.x, off.y * 0.55), r * randf_range(0.08, 0.26)])
	var life := 90.0 if pool else 45.0
	items.append({"type": 2, "pos": p, "r": r, "pts": pts, "drops": drops, "c": c, "t": life, "max": life, "seed": seed_v, "pool": pool})
	_trim()


## Torn flesh and bone left where something was ripped apart.
func add_remains(p: Vector2, r: float, c: Color) -> void:
	var bits: Array = []
	for i in randi_range(5, 9):
		var a := randf() * TAU
		var d := r * sqrt(randf()) * 1.4
		bits.append([p + Vector2(cos(a) * d, sin(a) * d * 0.55), randf_range(2.5, 6.0), randf() < 0.35, randf() * TAU])
	items.append({"type": 3, "pos": p, "r": r, "bits": bits, "c": c, "t": 70.0, "max": 70.0, "seed": 0.0})
	_trim()


func add_scorch(p: Vector2, r: float) -> void:
	items.append({"type": 1, "pos": p, "r": r, "t": 14.0, "max": 14.0, "seed": randf() * 10.0})
	_trim()


func _trim() -> void:
	while items.size() > 420:
		items.pop_front()


func update(dt: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		items[i].t -= dt
		if items[i].t <= 0.0:
			items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var vr := world.view_rect().grow(120)
	for d in items:
		if not vr.has_point(d.pos):
			continue
		var a: float = clampf(d.t / 4.0, 0.0, 1.0)
		if d.type == 0:
			draw_colored_polygon(d.pts, Color(0.09, 0.085, 0.08, 0.75 * a))
			var p: Vector2 = d.pos
			var r: float = d.r
			for k in 5:
				var o := Vector2(sin(d.seed + k * 2.1), cos(d.seed * 1.3 + k)) * r * 0.45
				draw_circle(p + Vector2(o.x, o.y * 0.5), r * 0.16, Color(0.32, 0.3, 0.28, 0.55 * a), true, -1.0, true)
		elif d.type == 2:
			var c: Color = d.c
			# Fresh blood is glossy; it darkens and dries as it ages.
			var age: float = 1.0 - d.t / d.max
			var wet := c.lerp(Color(c.r * 0.45, c.g * 0.4, c.b * 0.4), clampf(age * 1.6, 0.0, 1.0))
			wet.a = (0.9 if d.pool else 0.75) * a
			draw_colored_polygon(d.pts, wet)
			if d.pool:
				var inner := PackedVector2Array()
				for q in d.pts:
					inner.append(d.pos + (q - d.pos) * 0.55)
				draw_colored_polygon(inner, Color(wet.r * 0.6, wet.g * 0.5, wet.b * 0.5, wet.a))
				if age < 0.3:
					draw_circle(d.pos + Vector2(-d.r * 0.2, -d.r * 0.12), d.r * 0.12, Color(1, 0.75, 0.7, 0.18 * (1.0 - age / 0.3)), true, -1.0, true)
			for dr in d.drops:
				draw_set_transform(dr[0], 0.0, Vector2(1.0, 0.6))
				draw_circle(Vector2.ZERO, dr[1], wet, true, -1.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif d.type == 3:
			var c3: Color = d.c
			for b in d.bits:
				var bp: Vector2 = b[0]
				var bs: float = b[1]
				if b[2]:
					# A shard of bone
					var bd := Vector2(cos(b[3]), sin(b[3]) * 0.55) * bs * 1.4
					draw_line(bp - bd, bp + bd, Color(0.72, 0.68, 0.6, 0.9 * a), 2.2, true)
				else:
					draw_circle(bp, bs, Color(c3.r * 0.7, c3.g * 0.55, c3.b * 0.55, 0.95 * a), true, -1.0, true)
					draw_circle(bp + Vector2(-bs * 0.3, -bs * 0.3), bs * 0.45, Color(c3.r * 1.2, c3.g * 0.9, c3.b * 0.9, 0.8 * a), true, -1.0, true)
		else:
			var r2: float = d.r
			draw_set_transform(d.pos, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, r2, Color(0.03, 0.025, 0.02, 0.35 * a), true, -1.0, true)
			draw_circle(Vector2.ZERO, r2 * 0.6, Color(0.02, 0.015, 0.01, 0.35 * a), true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
