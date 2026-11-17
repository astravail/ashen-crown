class_name Particles
extends Node2D
## Lightweight batched particles. One instance for additive glow, one for smoke and debris.

enum { SPARK, EMBER, SMOKE, DEBRIS, GLOW, RING }

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()
var max_life := PackedFloat32Array()
var size := PackedFloat32Array()
var drag := PackedFloat32Array()
var grav := PackedFloat32Array()
var col := PackedColorArray()
var kind := PackedInt32Array()
var max_count := 1600
var view_rect := Rect2()


func setup(additive: bool) -> void:
	var mat := CanvasItemMaterial.new()
	if additive:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func emit(p: Vector2, v: Vector2, l: float, s: float, c: Color, k: int, d := 2.0, g := 0.0) -> void:
	if pos.size() >= max_count:
		return
	pos.append(p)
	vel.append(v)
	life.append(l)
	max_life.append(l)
	size.append(s)
	drag.append(d)
	grav.append(g)
	col.append(c)
	kind.append(k)


func burst(p: Vector2, n: int, c: Color, spd_min: float, spd_max: float, l: float, s: float, k: int, spread := TAU, dir := 0.0, d := 3.0, g := 0.0) -> void:
	for i in n:
		var a := dir + randf_range(-spread * 0.5, spread * 0.5)
		var sp := randf_range(spd_min, spd_max)
		emit(p + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Vector2(cos(a), sin(a)) * sp, l * randf_range(0.6, 1.2), s * randf_range(0.6, 1.3), c, k, d, g)


func ring(p: Vector2, radius: float, c: Color, l := 0.35) -> void:
	emit(p, Vector2.ZERO, l, radius, c, RING, 0.0, 0.0)


func update(dt: float) -> void:
	var i := 0
	while i < pos.size():
		life[i] -= dt
		if life[i] <= 0.0:
			_remove(i)
			continue
		var v := vel[i]
		v *= maxf(0.0, 1.0 - drag[i] * dt)
		v.y += grav[i] * dt
		vel[i] = v
		pos[i] += v * dt
		i += 1
	queue_redraw()


func _remove(i: int) -> void:
	var last := pos.size() - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		life[i] = life[last]
		max_life[i] = max_life[last]
		size[i] = size[last]
		drag[i] = drag[last]
		grav[i] = grav[last]
		col[i] = col[last]
		kind[i] = kind[last]
	pos.resize(last)
	vel.resize(last)
	life.resize(last)
	max_life.resize(last)
	size.resize(last)
	drag.resize(last)
	grav.resize(last)
	col.resize(last)
	kind.resize(last)


func _draw() -> void:
	var vr := view_rect.grow(80)
	for i in pos.size():
		var p := pos[i]
		if not vr.has_point(p):
			continue
		var t := life[i] / max_life[i]
		var c := col[i]
		match kind[i]:
			SPARK:
				var tail := vel[i] * 0.035
				c.a *= t
				draw_line(p - tail, p, c, size[i] * (0.4 + 0.6 * t), true)
			EMBER:
				c.a *= minf(1.0, t * 2.5)
				draw_circle(p, size[i] * (0.5 + 0.5 * t), c, true, -1.0, true)
			SMOKE:
				c.a *= t * t * 0.9
				draw_circle(p, size[i] * (1.6 - t * 0.8), c, true, -1.0, true)
			DEBRIS:
				c.a *= minf(1.0, t * 3.0)
				var r := size[i]
				draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), c)
			GLOW:
				c.a *= t * t
				draw_circle(p, size[i] * (1.3 - 0.3 * t), c, true, -1.0, true)
			RING:
				c.a *= t
				var rr := size[i] * (1.0 - t * t) + 4.0
				draw_arc(p, rr, 0.0, TAU, 48, c, 3.0 + 6.0 * t, true)
