extends RefCounted
## Drawing helpers for the game's one look: figures and scenery cut from dark paper, inked at the edge,
## shaded from pale at the top to deep at the foot, and standing on a soft shadow.
## Use from any script with:  const Ink := preload("res://scripts/fx/ink.gd")
##
## Cost: every draw_polygon, draw_circle, draw_polyline and draw_arc makes the renderer allocate GPU
## buffers for that one call, and some drivers allow only a few thousand of them at a time. Lines,
## multilines, rects, textured rects and draw_primitive (up to four points) cost none. So outlines here
## are multilines, limbs and flames are primitives, dots and glows are textured rects, and only the
## fill of a many-sided shape pays for a polygon.

const LINE := Color(0.035, 0.028, 0.03)

static var _soft: Texture2D
static var _disc: Texture2D
static var _unit := PackedVector2Array()


## A round blob that fades smoothly to nothing. White, so it takes any colour as a modulate.
static func soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.45, 0.72, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


## A crisp round dot, for eyes, studs and anything else that would otherwise be a draw_circle.
static func dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _disc == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 48
		t.height = 48
		_disc = t
	var e := r * 1.1
	ci.draw_texture_rect(_disc, Rect2(c.x - e, c.y - e, e * 2.0, e * 2.0), false, col)


## A flat triangle: a spike, a tooth, a tuft. Costs no buffer, unlike a three-point polygon.
static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([col, col, col]), PackedVector2Array())


## The inked edge of a closed shape.
static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 2.0) -> void:
	var n := pts.size()
	var pairs := PackedVector2Array()
	pairs.resize(n * 2)
	for i in n:
		pairs[i * 2] = pts[i]
		pairs[i * 2 + 1] = pts[(i + 1) % n]
	ci.draw_multiline(pairs, col, w, true)


static func _circle() -> PackedVector2Array:
	if _unit.is_empty():
		for i in 16:
			_unit.append(Vector2.from_angle(TAU * i / 16.0))
	return _unit


## A filled shape, pale at its highest point and deep at its lowest, with an inked edge.
static func shape(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color, line_w := 2.0, line := LINE) -> void:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var span := maxf(y1 - y0, 0.001)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		cols[i] = top.lerp(bottom, (pts[i].y - y0) / span)
	ci.draw_polygon(pts, cols)
	if line_w > 0.0:
		line.a *= top.a
		outline(ci, pts, line, line_w)


## An ellipse, shaded and inked like any other shape.
static func oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, top: Color, bottom: Color, line_w := 2.0, rot := 0.0, line := LINE) -> void:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for u in _circle():
		var x := u.x * rx
		var y := u.y * ry
		pts.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	shape(ci, pts, top, bottom, line_w, line)


## An arm, a leg, a branch: thick at a, thin at b.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w0: float, w1: float, top: Color, bottom: Color, line_w := 2.0, line := LINE) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := d.orthogonal().normalized()
	var quad := PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])
	var y0 := minf(a.y, b.y)
	var span := maxf(absf(a.y - b.y), 0.001)
	var ca := top.lerp(bottom, (a.y - y0) / span)
	var cb := top.lerp(bottom, (b.y - y0) / span)
	ci.draw_primitive(quad, PackedColorArray([ca, cb, cb, ca]), PackedVector2Array())
	if line_w > 0.0:
		line.a *= top.a
		outline(ci, quad, line, line_w)


## A thin stroke of light along the edges of a shape that face `toward` (in the shape's own space).
static func rim(ci: CanvasItem, pts: PackedVector2Array, toward: Vector2, col: Color, w := 1.5) -> void:
	var n := pts.size()
	var area := 0.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var flip := 1.0 if area > 0.0 else -1.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var out := Vector2(b.y - a.y, a.x - b.x) * flip
		var l := out.length()
		if l < 0.5:
			continue
		var k := out.dot(toward) / l
		if k > 0.25:
			ci.draw_line(a, b, Color(col.r, col.g, col.b, col.a * minf(1.0, (k - 0.25) * 2.2)), w, true)


## The soft shadow something casts on the ground. The light sits high in the north-west, as it does
## for the terrain, so shadows fall a little to the south-east.
static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, a := 0.5) -> void:
	ci.draw_texture_rect(soft_tex(), Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, Color(0, 0, 0, a))


## A soft disc of light, for anything drawn on an additive layer.
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(soft_tex(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## A tongue of flame: hot at the root, cooler and thinner toward the tip, leaning as it flickers.
static func flame(ci: CanvasItem, base: Vector2, w: float, h: float, t: float, seed_v: float, hot: Color, cool: Color) -> void:
	var lean := sin(t * 5.3 + seed_v) * w * 0.35 + sin(t * 11.0 + seed_v * 2.0) * w * 0.15
	var lick := 1.0 + 0.18 * sin(t * 9.0 + seed_v * 3.0) + 0.1 * sin(t * 17.0 + seed_v)
	var tip := base + Vector2(lean, -h * lick)
	var mid := base + Vector2(lean * 0.35, -h * lick * 0.45)
	var ml := mid + Vector2(-w * 0.72, 0)
	var mr := mid + Vector2(w * 0.72, 0)
	ci.draw_primitive(PackedVector2Array([base + Vector2(-w, 0), ml, mr, base + Vector2(w, 0)]), PackedColorArray([hot, cool, cool, hot]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([ml, tip, mr]), PackedColorArray([cool, Color(cool.r, cool.g, cool.b, 0.0), cool]), PackedVector2Array())
