class_name Icons
## Vector glyphs for abilities, drawn into any CanvasItem.


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.07)
	var dim := Color(col.r, col.g, col.b, col.a * 0.45)
	match id:
		"cleave":
			ci.draw_arc(c, s * 0.36, -2.4, -0.2, 20, dim, w * 1.6, true)
			ci.draw_line(c + Vector2(-0.3, 0.3) * s, c + Vector2(0.32, -0.32) * s, col, w * 1.3, true)
			ci.draw_line(c + Vector2(-0.22, 0.08) * s, c + Vector2(-0.08, 0.22) * s, col, w * 1.3, true)
		"rush":
			var sh := PackedVector2Array([c + Vector2(-0.05, -0.3) * s, c + Vector2(0.3, -0.3) * s, c + Vector2(0.28, 0.05) * s, c + Vector2(0.12, 0.3) * s, c + Vector2(-0.04, 0.05) * s])
			ci.draw_colored_polygon(sh, col)
			for i in 3:
				var y := (-0.15 + i * 0.15) * s
				ci.draw_line(c + Vector2(-0.38 * s, y), c + Vector2(-0.14 * s, y), dim, w, true)
		"oath":
			ci.draw_arc(c, s * 0.36, 0, TAU, 32, dim, w, true)
			var sh2 := PackedVector2Array([c + Vector2(-0.2, -0.24) * s, c + Vector2(0.2, -0.24) * s, c + Vector2(0.18, 0.06) * s, c + Vector2(0, 0.26) * s, c + Vector2(-0.18, 0.06) * s])
			ci.draw_colored_polygon(sh2, col)
		"molten":
			ci.draw_arc(c, s * 0.38, 0, TAU, 32, dim, w * 1.4, true)
			_flame(ci, c + Vector2(0, 0.12) * s, s * 0.55, col)
		"vanguard":
			ci.draw_rect(Rect2(c + Vector2(-0.2, -0.22) * s, Vector2(0.4, 0.42) * s), col)
			ci.draw_circle(c + Vector2(0, -0.22) * s, s * 0.2, col, true, -1.0, true)
			ci.draw_line(c + Vector2(-0.12, -0.08) * s, c + Vector2(0.12, -0.08) * s, Color(0, 0, 0, 0.85), w * 1.2)
			ci.draw_line(c + Vector2(0, -0.4) * s, c + Vector2(0, 0.2) * s, Color(0, 0, 0, 0.5), w * 0.6)
		"lance":
			ci.draw_line(c + Vector2(-0.34, 0.34) * s, c + Vector2(0.22, -0.22) * s, col, w * 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.38, -0.38) * s, c + Vector2(0.14, -0.26) * s, c + Vector2(0.26, -0.14) * s]), col)
		"raise", "titan":
			var k := 1.0 if id == "raise" else 1.25
			ci.draw_circle(c + Vector2(0, -0.06) * s, s * 0.26 * k, col, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.14, 0.12) * s * k, Vector2(0.28, 0.16) * s * k), col)
			ci.draw_circle(c + Vector2(-0.1, -0.06) * s * k, s * 0.07 * k, Color(0, 0, 0, 0.9), true, -1.0, true)
			ci.draw_circle(c + Vector2(0.1, -0.06) * s * k, s * 0.07 * k, Color(0, 0, 0, 0.9), true, -1.0, true)
			if id == "titan":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.28, -0.34) * s, c + Vector2(-0.18, -0.48) * s, c + Vector2(0, -0.36) * s, c + Vector2(0.18, -0.48) * s, c + Vector2(0.28, -0.34) * s]), col)
		"bloom":
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.12, c + Vector2(cos(a), sin(a)) * s * 0.38, col, w * 1.2, true)
			ci.draw_circle(c, s * 0.12, col, true, -1.0, true)
		"wither":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, col, w, true)
			ci.draw_arc(c, s * 0.2, 0.5, TAU - 0.5, 24, dim, w, true)
			ci.draw_circle(c, s * 0.07, col, true, -1.0, true)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.2, -0.2) * s, c + Vector2(-0.34, 0.2) * s, c + Vector2(-0.06, 0.02) * s, c + Vector2(-0.2, 0.34) * s]), dim)
			ci.draw_circle(c + Vector2(0.14, -0.14) * s, s * 0.16, col, true, -1.0, true)
		"storm":
			for i in 5:
				var x := (-0.3 + i * 0.15) * s
				ci.draw_line(c + Vector2(x, -0.32 * s), c + Vector2(x - 0.12 * s, 0.1 * s), col, w, true)
			ci.draw_arc(c + Vector2(0, 0.24) * s, s * 0.3, PI + 0.3, TAU - 0.3, 16, dim, w * 1.4, true)
		"step":
			ci.draw_circle(c + Vector2(-0.24, 0.16) * s, s * 0.1, dim, true, -1.0, true)
			ci.draw_circle(c + Vector2(0.24, -0.16) * s, s * 0.13, col, true, -1.0, true)
			ci.draw_line(c + Vector2(-0.1, 0.06) * s, c + Vector2(0.08, -0.06) * s, col, w, true)
		"smother":
			var hexp := PackedVector2Array()
			for i in 6:
				var a2 := TAU * i / 6.0 + PI / 6.0
				hexp.append(c + Vector2(cos(a2), sin(a2)) * s * 0.34)
			ci.draw_colored_polygon(hexp, dim)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.3) * s, c + Vector2(0.02, -0.04) * s, c + Vector2(-0.06, 0.1) * s, c + Vector2(0.08, 0.3) * s]), col, w, true)
		"phoenix":
			var wing := PackedVector2Array([c + Vector2(0, 0.1) * s, c + Vector2(-0.4, -0.24) * s, c + Vector2(-0.14, -0.06) * s, c + Vector2(0, -0.3) * s, c + Vector2(0.14, -0.06) * s, c + Vector2(0.4, -0.24) * s])
			ci.draw_colored_polygon(wing, col)
			ci.draw_line(c + Vector2(0, 0.1) * s, c + Vector2(0, 0.36) * s, dim, w * 1.4, true)
		"flask":
			ci.draw_circle(c + Vector2(0, 0.08) * s, s * 0.26, col, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.08, -0.36) * s, Vector2(0.16, 0.2) * s), col)
		"dodge":
			ci.draw_arc(c, s * 0.28, -2.6, 0.6, 20, col, w * 1.3, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, 0.02) * s, c + Vector2(0.16, 0.24) * s, c + Vector2(0.38, 0.22) * s]), col)
		_:
			ci.draw_circle(c, s * 0.2, col, true, -1.0, true)


static func _flame(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([base + Vector2(-0.28, 0) * s, base + Vector2(-0.3, -0.3) * s, base + Vector2(-0.12, -0.2) * s, base + Vector2(0, -0.6) * s, base + Vector2(0.14, -0.22) * s, base + Vector2(0.3, -0.36) * s, base + Vector2(0.28, 0) * s, base + Vector2(0, 0.12) * s])
	ci.draw_colored_polygon(pts, col)


static func crown(ci: CanvasItem, c: Vector2, s: float, col: Color, crack: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.5, 0.3) * s, c + Vector2(-0.56, -0.28) * s, c + Vector2(-0.26, 0.0) * s, c + Vector2(0, -0.46) * s, c + Vector2(0.26, 0.0) * s, c + Vector2(0.56, -0.28) * s, c + Vector2(0.5, 0.3) * s])
	ci.draw_colored_polygon(pts, Color(0.09, 0.075, 0.07))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col, maxf(1.5, s * 0.04), true)
	ci.draw_rect(Rect2(c + Vector2(-0.5, 0.32) * s, Vector2(1.0, 0.1) * s), col)
	ci.draw_polyline(PackedVector2Array([c + Vector2(0, -0.46) * s, c + Vector2(-0.07, -0.1) * s, c + Vector2(0.06, 0.06) * s, c + Vector2(-0.03, 0.32) * s]), crack, maxf(1.5, s * 0.03), true)


## Gear glyphs for inventory slots and ground loot.
static func item(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.09)
	var dim := Color(col.r, col.g, col.b, col.a * 0.55)
	match id:
		"blade":
			ci.draw_line(c + Vector2(-0.28, 0.34) * s, c + Vector2(0.3, -0.34) * s, col, w * 1.6, true)
			ci.draw_line(c + Vector2(-0.2, 0.06) * s, c + Vector2(-0.02, 0.24) * s, dim, w * 1.4, true)
		"mace":
			ci.draw_line(c + Vector2(-0.3, 0.34) * s, c + Vector2(0.14, -0.14) * s, dim, w * 1.4, true)
			ci.draw_circle(c + Vector2(0.2, -0.2) * s, s * 0.17, col, true, -1.0, true)
		"staff":
			ci.draw_line(c + Vector2(-0.18, 0.38) * s, c + Vector2(0.18, -0.3) * s, dim, w * 1.3, true)
			ci.draw_circle(c + Vector2(0.2, -0.34) * s, s * 0.11, col, true, -1.0, true)
		"wand":
			ci.draw_line(c + Vector2(-0.3, 0.3) * s, c + Vector2(0.24, -0.24) * s, dim, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, -0.3) * s, c + Vector2(0.14, -0.22) * s, c + Vector2(0.22, -0.14) * s]), col)
		"scepter":
			ci.draw_line(c + Vector2(-0.26, 0.34) * s, c + Vector2(0.16, -0.18) * s, dim, w * 1.3, true)
			ci.draw_arc(c + Vector2(0.22, -0.26) * s, s * 0.14, 0, TAU, 14, col, w, true)
		"helm":
			ci.draw_arc(c + Vector2(0, 0.04) * s, s * 0.28, PI, TAU, 18, col, w * 1.6, true)
			ci.draw_rect(Rect2(c + Vector2(-0.28, 0.04) * s, Vector2(0.56, 0.22) * s), dim)
		"chest":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.28) * s, c + Vector2(0.3, -0.28) * s, c + Vector2(0.22, 0.3) * s, c + Vector2(-0.22, 0.3) * s]), col)
			ci.draw_line(c + Vector2(0, -0.28) * s, c + Vector2(0, 0.3) * s, Color(0, 0, 0, 0.45), w * 0.8)
		"boots":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.16, -0.3) * s, c + Vector2(0.06, -0.3) * s, c + Vector2(0.06, 0.1) * s, c + Vector2(0.3, 0.22) * s, c + Vector2(-0.16, 0.26) * s]), col)
		"ring":
			ci.draw_arc(c + Vector2(0, 0.06) * s, s * 0.22, 0, TAU, 20, col, w * 1.5, true)
			ci.draw_circle(c + Vector2(0, -0.2) * s, s * 0.08, dim, true, -1.0, true)
		"amulet":
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.26, 0.2, PI - 0.2, 16, dim, w, true)
			ci.draw_circle(c + Vector2(0, 0.2) * s, s * 0.13, col, true, -1.0, true)
		_:
			ci.draw_circle(c, s * 0.2, col, true, -1.0, true)
