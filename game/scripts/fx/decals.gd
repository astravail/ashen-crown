class_name Decals
extends Node2D
## Ground marks: blood pools and spatter, torn remains, ash piles and scorch marks.
## Every mark is stamped from two round textures, one soft all the way through and one flat with a soft
## shore, and where each stamp goes is worked out once, when the mark is made. Drawing a mark is then a
## handful of textured rects and nothing else.

const Ink := preload("res://scripts/fx/ink.gd")

## A flat blot with a soft shore, for anything wet or heaped.
static var _blot: Texture2D

var world: World
var items: Array[Dictionary] = []


func _init() -> void:
	if _blot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blot = tex


## The rect of a stamp centred on c, rx wide and ry tall each way.
static func _oval(c: Vector2, rx: float, ry: float) -> Rect2:
	return Rect2(c.x - rx, c.y - ry, rx * 2.0, ry * 2.0)


## A few stamps crowded round p, so that together they make one shape with an uneven shore.
static func _lobes(p: Vector2, r: float, n: int, reach: float, size_min: float, size_max: float, flat: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var a0 := randf() * TAU
	for i in n:
		var a := a0 + TAU * i / n + randf_range(-0.5, 0.5)
		var d := r * reach * randf_range(0.7, 1.2)
		var s := r * randf_range(size_min, size_max)
		out.append(_oval(p + Vector2(cos(a) * d, sin(a) * d * flat), s, s * flat))
	return out


func add_ash(p: Vector2, r: float) -> void:
	var heap := _lobes(p, r, 3, 0.42, 0.4, 0.6, 0.55)
	heap.append(_oval(p, r * 0.8, r * 0.46))
	# pale flecks that have not burned through
	var flecks := PackedVector2Array()
	for i in 5:
		var q := p + Vector2(randf_range(-0.6, 0.6) * r, randf_range(-0.3, 0.3) * r)
		flecks.append(q)
		flecks.append(q + Vector2(1.6, 0.0))
	items.append({"type": 0, "pos": p, "r": r, "heap": heap, "soot": _oval(p, r * 1.5, r * 0.85), "crest": _oval(p + Vector2(-r * 0.12, -r * 0.1), r * 0.6, r * 0.32),
		"flecks": flecks, "t": 40.0, "max": 40.0})
	_trim()


## A splash of blood thrown along dir. Big ones (pools) linger for a long time.
func add_blood(p: Vector2, r: float, dir: Vector2, c: Color, pool := false) -> void:
	var body := _lobes(p, r, 4 if pool else 2, 0.45, 0.3, 0.5, 0.55)
	var main := r * (0.8 if pool else 0.7)
	body.append(_oval(p, main, main * 0.55))
	var drops: Array[Rect2] = []
	var nd := randi_range(4, 9) if pool else randi_range(2, 5)
	for i in nd:
		var off := dir.rotated(randf_range(-0.6, 0.6)) * r * randf_range(0.8, 2.6)
		off.y *= 0.55
		var s := r * randf_range(0.1, 0.3)
		drops.append(_oval(p + off, s, s * 0.6))
		# the bigger drops skip once more where they land
		if s > r * 0.2:
			drops.append(_oval(p + off + off.normalized() * s * 1.8, s * 0.45, s * 0.3))
	var life := 90.0 if pool else 45.0
	items.append({"type": 2, "pos": p, "r": r, "body": body, "drops": drops, "c": c, "t": life, "max": life, "pool": pool,
		"soak": _oval(p, r * 1.4, r * 0.8), "deep": _oval(p, r * 0.7, r * 0.4), "gloss": _oval(p + Vector2(-r * 0.22, -r * 0.13), r * 0.34, r * 0.16)})
	_trim()


## Torn flesh and bone left where something was ripped apart.
func add_remains(p: Vector2, r: float, c: Color) -> void:
	var meat: Array[Rect2] = []
	var wet: Array[Rect2] = []
	var bones := PackedVector2Array()
	for i in randi_range(5, 9):
		var a := randf() * TAU
		var d := r * sqrt(randf()) * 1.4
		var q := p + Vector2(cos(a) * d, sin(a) * d * 0.55)
		var s := randf_range(2.5, 6.0)
		if randf() < 0.35:
			# a shard of bone
			var ba := randf() * TAU
			var bd := Vector2(cos(ba), sin(ba) * 0.55) * s * 1.4
			bones.append(q - bd)
			bones.append(q + bd)
		else:
			meat.append(_oval(q, s * 1.3, s * 1.05))
			wet.append(_oval(q + Vector2(-s * 0.3, -s * 0.3), s * 0.7, s * 0.55))
	items.append({"type": 3, "pos": p, "r": r, "meat": meat, "wet": wet, "bones": bones, "stain": _oval(p, r * 1.7, r * 0.95), "c": c, "t": 70.0, "max": 70.0})
	_trim()


func add_scorch(p: Vector2, r: float) -> void:
	var soot := _lobes(p, r, 3, 0.4, 0.6, 0.85, 0.6)
	soot.append(_oval(p, r * 1.3, r * 0.78))
	# soot thrown outward by the blast
	var rays := PackedVector2Array()
	var a0 := randf() * TAU
	for i in 9:
		var a := a0 + TAU * i / 9.0 + randf_range(-0.2, 0.2)
		var u := Vector2(cos(a), sin(a) * 0.6)
		rays.append(p + u * r * randf_range(0.35, 0.55))
		rays.append(p + u * r * randf_range(0.8, 1.1))
	items.append({"type": 1, "pos": p, "r": r, "soot": soot, "burn": _oval(p + Vector2(randf_range(-0.1, 0.1), randf_range(-0.06, 0.06)) * r, r * 0.62, r * 0.37), "rays": rays, "t": 14.0, "max": 14.0})
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
	var soft := Ink.soft_tex()
	for d in items:
		if not vr.has_point(d.pos):
			continue
		var a: float = clampf(d.t / 4.0, 0.0, 1.0)
		if d.type == 0:
			# a heap of ash on a smudge of soot, paler along its crest
			draw_texture_rect(soft, d.soot, false, Color(0.05, 0.045, 0.04, 0.5 * a))
			var grey := Color(0.1, 0.095, 0.09, 0.8 * a)
			for q: Rect2 in d.heap:
				draw_texture_rect(_blot, q, false, grey)
			draw_texture_rect(soft, d.crest, false, Color(0.36, 0.34, 0.32, 0.6 * a))
			draw_multiline(d.flecks, Color(0.42, 0.4, 0.37, 0.7 * a), 1.6)
		elif d.type == 2:
			var c: Color = d.c
			# Fresh blood is glossy; it darkens and dries as it ages.
			var age: float = 1.0 - d.t / d.max
			var wet := c.lerp(Color(c.r * 0.45, c.g * 0.4, c.b * 0.4), clampf(age * 1.6, 0.0, 1.0))
			wet.a = (0.9 if d.pool else 0.75) * a
			if d.pool:
				# what has soaked into the ground around it
				draw_texture_rect(soft, d.soak, false, Color(wet.r * 0.4, wet.g * 0.4, wet.b * 0.4, 0.5 * a))
			for q: Rect2 in d.body:
				draw_texture_rect(_blot, q, false, wet)
			# deepest, and so darkest, in the middle
			draw_texture_rect(soft, d.deep, false, Color(wet.r * 0.45, wet.g * 0.35, wet.b * 0.35, wet.a * 0.85))
			if d.pool and age < 0.3:
				draw_texture_rect(soft, d.gloss, false, Color(1, 0.75, 0.7, 0.4 * (1.0 - age / 0.3) * a))
			for q: Rect2 in d.drops:
				draw_texture_rect(_blot, q, false, wet)
		elif d.type == 3:
			var c3: Color = d.c
			draw_texture_rect(soft, d.stain, false, Color(c3.r * 0.35, c3.g * 0.3, c3.b * 0.3, 0.55 * a))
			var flesh := Color(c3.r * 0.7, c3.g * 0.55, c3.b * 0.55, 0.95 * a)
			for q: Rect2 in d.meat:
				draw_texture_rect(_blot, q, false, flesh)
			var sheen := Color(c3.r * 1.3, c3.g * 1.0, c3.b * 1.0, 0.7 * a)
			for q: Rect2 in d.wet:
				draw_texture_rect(soft, q, false, sheen)
			var bones: PackedVector2Array = d.bones
			if not bones.is_empty():
				# shards of bone, inked like everything else that is solid
				draw_multiline(bones, Color(Ink.LINE, 0.9 * a), 4.0, true)
				draw_multiline(bones, Color(0.72, 0.68, 0.6, a), 2.0, true)
		else:
			# a burn: soot in overlapping smudges, charred black where the blast was hottest
			var black := Color(0.03, 0.025, 0.02, 0.4 * a)
			for q: Rect2 in d.soot:
				draw_texture_rect(soft, q, false, black)
			draw_texture_rect(soft, d.burn, false, Color(0.015, 0.012, 0.01, 0.5 * a))
			draw_multiline(d.rays, Color(0.03, 0.025, 0.02, 0.2 * a), 2.5, true)
