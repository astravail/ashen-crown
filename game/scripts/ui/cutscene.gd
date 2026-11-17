class_name Cutscene
extends Control
## Cinematic cards: black bars, a slow ember backdrop, narrated lines. Space or click skips a line, Esc skips it all.

signal finished

const SCENES := {
	"intro": {"title": "The Fall of Valdremor", "lines": [
		["narrator", "Valdremor did not fall to an army."],
		["narrator", "King Aldric put on a crown that was never meant for a living head."],
		["narrator", "The fire came from inside him, and from him, into everything."],
		["narrator", "Now the ash is falling. Nothing stays buried."],
	]},
	"act0": {"title": "Act I · The Ashen Road", "lines": [["narrator", "The road to the keep is lined with the hanged."]]},
	"act1": {"title": "Act II · The Buried City", "lines": [["narrator", "Valdremor buried its dead. The dead dug out."]]},
	"act2": {"title": "Act III · The Rot", "lines": [["narrator", "The ash settles here, and rots."]]},
	"act3": {"title": "Act IV · The Deep Works", "lines": [["narrator", "The miners dug too deep, and something answered."]]},
	"act4": {"title": "Act V · The Burning Court", "lines": [["narrator", "Where the court still feasts on cinders."]]},
	"act5": {"title": "Act VI · The Pyre", "lines": [["narrator", "Beneath the world, the crown was forged."]]},
	"king": {"title": "The Ember King", "lines": [
		["boss", "You carry my fire. Did you think I would not feel it?"],
		["boss", "Come, then. Burn with me."],
	]},
}

var lines: Array = []
var title := ""
var idx := -1
var t := 0.0
var line_len := 0.0
var fade := 0.0
var closing := false
var scene_id := ""
var clock := 0.0
var shot_t := 0.0
var _rng := RandomNumberGenerator.new()


func play(id: String) -> void:
	scene_id = id
	var sc: Dictionary = SCENES[id]
	title = sc.title
	lines = sc.lines
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next()


func _next() -> void:
	idx += 1
	if idx >= lines.size():
		closing = true
		Voice.stop()
		return
	var l: Array = lines[idx]
	t = 0.0
	shot_t = 0.0
	line_len = 2.4 + String(l[1]).length() * 0.06
	Voice.say(l[0], l[1], line_len)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		closing = true
		Voice.stop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if not closing and t > 0.5:
			_next()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	clock += dt
	shot_t += dt
	if closing:
		fade = move_toward(fade, 0.0, dt * 1.5)
		if fade <= 0.0:
			finished.emit()
			queue_free()
	else:
		fade = move_toward(fade, 1.0, dt * 1.5)
		t += dt
		if idx >= 0 and t > line_len + 0.8:
			_next()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.015, fade))
	_backdrop()
	var cx := size.x * 0.5
	var bar := size.y * 0.12
	draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, fade))
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, fade))
	var tw := Game.font_display_bold.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	draw_string(Game.font_display_bold, Vector2(cx - tw * 0.5, size.y * 0.36), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(0.95, 0.86, 0.74, fade))
	draw_line(Vector2(cx - tw * 0.4, size.y * 0.36 + 22), Vector2(cx + tw * 0.4, size.y * 0.36 + 22), Color(0.8, 0.45, 0.2, fade * 0.8), 1.0)
	if idx >= 0 and idx < lines.size():
		var txt: String = lines[idx][1]
		var shown := int(clampf(t / 0.035, 0.0, float(txt.length())))
		var f := Game.font_italic
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		draw_string(f, Vector2(cx - w * 0.5, size.y * 0.55), txt.substr(0, shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.9, 0.85, 0.78, fade))
	_hint()


func _hint() -> void:
	var h := "Space  ·  next          Esc  ·  skip"
	var w := Game.font_body.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Game.font_body, Vector2(size.x - w - 40, size.y - 30), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.47, 0.44, fade))


# ================================================================ painted backdrops
# Everything is drawn from shapes: a sky, layers of silhouette that drift at different speeds, and
# fire and ash on top. Each scene (and, in the intro, each line) is its own shot.

func _sky(top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	var cols := PackedColorArray([_fa(top), _fa(top), _fa(bottom), _fa(bottom)])
	draw_polygon(pts, cols)


func _fa(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * fade)


func _ridge(base_y: float, amp: float, freq: float, seed_v: float, col: Color, speed: float) -> void:
	var pts := PackedVector2Array()
	var x := -20.0
	while x <= size.x + 20.0:
		var u := x * freq + seed_v + clock * speed
		var y := base_y - amp * (0.5 + 0.5 * sin(u) + 0.35 * sin(u * 2.3 + seed_v * 1.7) + 0.15 * sin(u * 5.1))
		pts.append(Vector2(x, y))
		x += 18.0
	pts.append(Vector2(size.x + 20.0, size.y))
	pts.append(Vector2(-20.0, size.y))
	draw_colored_polygon(pts, _fa(col))


func _flame(p: Vector2, w: float, h: float, k: float) -> void:
	var f := 1.0 + 0.35 * sin(clock * 9.0 + p.x * 0.07) + 0.2 * sin(clock * 17.0 + p.x)
	var tip := Vector2(p.x + sin(clock * 5.0 + p.x) * w * 0.3, p.y - h * f * k)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(w, 0), tip]), _fa(Color(2.4, 0.6, 0.12, 0.9)))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.55, 0), p + Vector2(w * 0.55, 0), p + Vector2(tip.x - p.x, -h * f * k * 0.65) + Vector2(0, 0)]), _fa(Color(3.2, 1.6, 0.4, 0.95)))


func _ash(n: int, speed: float, col := Color(0.8, 0.77, 0.74, 0.55)) -> void:
	for i in n:
		var ph := fmod(clock * speed * (0.5 + (i % 5) * 0.12) + i * 0.173, 1.0)
		var x := fmod(i * 197.3, size.x) + sin(clock * 0.8 + i) * 24.0
		draw_circle(Vector2(x, ph * size.y), 1.3 + (i % 3), _fa(Color(col.r, col.g, col.b, col.a * sin(ph * PI))), true, -1.0, true)


func _embers(n: int, col := Color(2.6, 1.0, 0.3, 0.8)) -> void:
	for i in n:
		var ph := fmod(clock * 0.14 + i * 0.137, 1.0)
		var x := fmod(i * 211.7, size.x) + sin(ph * 6.0 + i) * 30.0
		draw_circle(Vector2(x, size.y - ph * size.y), 1.5 + (i % 3), _fa(Color(col.r, col.g, col.b, (1.0 - ph) * col.a)), true, -1.0, true)


func _building(x: float, base: float, w: float, h: float, col: Color, tower := false, broken := false) -> void:
	draw_rect(Rect2(x, base - h, w, h), _fa(col))
	if tower:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, base - h), Vector2(x + w + 6, base - h), Vector2(x + w * 0.5, base - h - w * 1.1)]), _fa(col))
	elif broken:
		draw_colored_polygon(PackedVector2Array([Vector2(x, base - h), Vector2(x + w * 0.3, base - h - 18), Vector2(x + w * 0.55, base - h + 6), Vector2(x + w * 0.8, base - h - 12), Vector2(x + w, base - h)]), _fa(col))
	for i in 3:
		var wy := base - h + 18.0 + i * 26.0
		if wy < base - 20.0:
			var lit := 0.5 + 0.5 * sin(clock * 2.0 + x * 0.3 + i)
			draw_rect(Rect2(x + w * 0.3, wy, 7, 11), _fa(Color(2.2 * lit + 0.2, 0.8 * lit, 0.2, 0.9)))


func _crown(c: Vector2, s: float, glow: float, cracked := false) -> void:
	var pts := PackedVector2Array([c + Vector2(-1.0, 0.55) * s, c + Vector2(-1.1, -0.5) * s, c + Vector2(-0.5, -0.1) * s, c + Vector2(-0.3, -0.85) * s, c + Vector2(0, -0.2) * s, c + Vector2(0.3, -0.85) * s, c + Vector2(0.5, -0.1) * s, c + Vector2(1.1, -0.5) * s, c + Vector2(1.0, 0.55) * s])
	draw_circle(c, s * 1.6, _fa(Color(1.6, 0.5, 0.1, 0.12 * glow)), true, -1.0, true)
	draw_circle(c, s * 1.0, _fa(Color(2.0, 0.7, 0.15, 0.12 * glow)), true, -1.0, true)
	draw_colored_polygon(pts, _fa(Color(0.6 + 1.6 * glow, 0.25 + 0.7 * glow, 0.06 + 0.15 * glow)))
	draw_polyline(pts + PackedVector2Array([pts[0]]), _fa(Color(3.0, 1.8, 0.7)), 3.0, true)
	if cracked:
		draw_polyline(PackedVector2Array([c + Vector2(0.1, -0.2) * s, c + Vector2(-0.15, 0.1) * s, c + Vector2(0.1, 0.3) * s, c + Vector2(-0.1, 0.55) * s]), _fa(Color(4.0, 2.4, 0.8)), 3.0, true)


func _figure(p: Vector2, h: float, col: Color, crown := false) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.28, 0), p + Vector2(h * 0.28, 0), p + Vector2(h * 0.16, -h * 0.7), p + Vector2(-h * 0.16, -h * 0.7)]), _fa(col))
	draw_circle(p + Vector2(0, -h * 0.82), h * 0.11, _fa(col), true, -1.0, true)
	draw_line(p + Vector2(-h * 0.2, -h * 0.6), p + Vector2(-h * 0.45, -h * 0.25), _fa(col), h * 0.06, true)
	draw_line(p + Vector2(h * 0.2, -h * 0.6), p + Vector2(h * 0.45, -h * 0.25), _fa(col), h * 0.06, true)
	if crown:
		_crown(p + Vector2(0, -h * 1.0), h * 0.12, 0.8 + 0.2 * sin(clock * 3.0))


func _tree(x: float, base: float, h: float, col: Color) -> void:
	draw_line(Vector2(x, base), Vector2(x, base - h), _fa(col), 6.0, true)
	for i in 4:
		var by := base - h * (0.4 + i * 0.16)
		var s := 1.0 if i % 2 == 0 else -1.0
		draw_line(Vector2(x, by), Vector2(x + s * h * 0.28, by - h * 0.14), _fa(col), 3.0, true)


func _backdrop() -> void:
	var w := size.x
	var h := size.y
	var base := h * 0.72
	match scene_id:
		"intro":
			match clampi(idx, 0, 3):
				0:
					_sky(Color(0.04, 0.02, 0.03), Color(0.5, 0.12, 0.05))
					_ridge(base - 40, 60, 0.004, 1.0, Color(0.1, 0.05, 0.05), 3.0)
					for i in 14:
						var bx := fmod(i * 163.0 - clock * 6.0 + w, w + 120.0) - 60.0
						_building(bx, base, 60 + (i * 37) % 50, 80 + (i * 53) % 150, Color(0.04, 0.025, 0.03), i % 3 == 0, i % 3 == 1)
						_flame(Vector2(bx + 30, base - 40 - (i * 29) % 80), 18.0, 60.0 + (i * 17) % 40, clampf(shot_t * 0.6, 0.0, 1.0))
					draw_rect(Rect2(0, base, w, h - base), _fa(Color(0.03, 0.02, 0.02)))
					_embers(60)
				1:
					_sky(Color(0.05, 0.02, 0.02), Color(0.45, 0.1, 0.03))
					_ridge(base, 80, 0.003, 4.0, Color(0.06, 0.03, 0.03), 1.0)
					draw_rect(Rect2(w * 0.3, base - 20, w * 0.4, h), _fa(Color(0.05, 0.03, 0.03)))
					_figure(Vector2(w * 0.5, base - 20), 230.0 + shot_t * 6.0, Color(0.02, 0.012, 0.012), true)
					_embers(50)
				2:
					_sky(Color(0.02, 0.01, 0.01), Color(0.2, 0.05, 0.02))
					var g := 0.6 + 0.4 * sin(clock * 2.5)
					_crown(Vector2(w * 0.5, h * 0.45), 170.0 + shot_t * 8.0, g, true)
					for i in 10:
						var a := TAU * i / 10.0 + clock * 0.3
						_flame(Vector2(w * 0.5 + cos(a) * 280.0, h * 0.45 + sin(a) * 120.0 + 90.0), 14.0, 50.0, 1.0)
					_embers(70)
				_:
					_sky(Color(0.03, 0.025, 0.03), Color(0.2, 0.1, 0.08))
					_ridge(base, 40, 0.005, 2.0, Color(0.05, 0.04, 0.04), 2.0)
					for i in 6:
						_building(fmod(i * 230.0 + 80.0, w), base, 80, 60 + (i * 31) % 60, Color(0.035, 0.03, 0.03), false, true)
					draw_rect(Rect2(0, base, w, h - base), _fa(Color(0.03, 0.025, 0.025)))
					_ash(120, 0.12)
		"act0":
			_sky(Color(0.03, 0.04, 0.04), Color(0.18, 0.2, 0.17))
			_ridge(base - 120, 90, 0.004, 1.0, Color(0.07, 0.09, 0.08), 3.0)
			_ridge(base - 40, 110, 0.006, 5.0, Color(0.04, 0.055, 0.045), 6.0)
			for i in 7:
				var x := fmod(i * 290.0 - clock * 14.0 + w * 2.0, w + 200.0) - 100.0
				draw_line(Vector2(x, base + 20), Vector2(x, base - 190), _fa(Color(0.03, 0.025, 0.02)), 7.0, true)
				draw_line(Vector2(x - 6, base - 186), Vector2(x + 70, base - 186), _fa(Color(0.03, 0.025, 0.02)), 6.0, true)
				_figure(Vector2(x + 60 + sin(clock * 1.2 + i) * 3.0, base - 120), 80.0, Color(0.02, 0.02, 0.02))
			draw_rect(Rect2(0, base + 20, w, h), _fa(Color(0.02, 0.025, 0.02)))
			_ridge(base + 80, 20, 0.01, 9.0, Color(0.5, 0.55, 0.5, 0.18), 12.0)
			_ash(60, 0.1)
		"act1":
			_sky(Color(0.03, 0.03, 0.05), Color(0.2, 0.18, 0.22))
			for i in 10:
				var x := fmod(i * 210.0 - clock * 10.0 + w * 2.0, w + 160.0) - 80.0
				_building(x, base, 70 + (i * 23) % 40, 140 + (i * 47) % 200, Color(0.05, 0.045, 0.06), i % 2 == 0, i % 2 == 1)
			draw_rect(Rect2(0, base, w, h), _fa(Color(0.03, 0.03, 0.04)))
			for i in 18:
				draw_line(Vector2(fmod(i * 131.0, w), base + 30 + (i % 4) * 20), Vector2(fmod(i * 131.0, w) + 16, base + 26 + (i % 4) * 20), _fa(Color(0.7, 0.68, 0.6, 0.6)), 3.0, true)
			_ash(80, 0.08, Color(0.7, 0.7, 0.8, 0.4))
		"act2":
			_sky(Color(0.04, 0.06, 0.06), Color(0.22, 0.3, 0.26))
			_ridge(base - 30, 60, 0.004, 3.0, Color(0.05, 0.08, 0.07), 4.0)
			draw_rect(Rect2(0, base, w, h), _fa(Color(0.04, 0.07, 0.06)))
			for i in 6:
				_tree(fmod(i * 330.0 + 120.0, w), base + 6, 200 + (i * 41) % 90, Color(0.02, 0.03, 0.025))
			for i in 40:
				var rx := fmod(i * 97.0, w)
				draw_line(Vector2(rx, base + 40 + (i % 5) * 14), Vector2(rx + sin(clock * 1.5 + i) * 5, base + 10 + (i % 5) * 14), _fa(Color(0.03, 0.06, 0.04)), 2.0, true)
			_ridge(base + 60, 14, 0.012, 2.0, Color(0.55, 0.7, 0.65, 0.2), 10.0)
			_ash(50, 0.06, Color(0.6, 0.7, 0.6, 0.35))
		"act3":
			_sky(Color(0.03, 0.02, 0.02), Color(0.16, 0.1, 0.07))
			draw_rect(Rect2(w * 0.22, h * 0.2, w * 0.56, h), _fa(Color(0.015, 0.01, 0.01)))
			draw_rect(Rect2(w * 0.22 - 24, h * 0.2, 24, h), _fa(Color(0.1, 0.07, 0.04)))
			draw_rect(Rect2(w * 0.78, h * 0.2, 24, h), _fa(Color(0.1, 0.07, 0.04)))
			draw_rect(Rect2(w * 0.22 - 24, h * 0.2 - 24, w * 0.56 + 48, 24), _fa(Color(0.12, 0.08, 0.05)))
			for i in 4:
				var lx := w * (0.3 + i * 0.13)
				draw_line(Vector2(lx, h * 0.2), Vector2(lx, h * 0.2 + 70), _fa(Color(0.2, 0.15, 0.1)), 2.0)
				draw_circle(Vector2(lx, h * 0.2 + 80), 12 + sin(clock * 6.0 + i) * 1.5, _fa(Color(2.6, 1.5, 0.5, 0.9)), true, -1.0, true)
				draw_circle(Vector2(lx, h * 0.2 + 80), 70, _fa(Color(1.6, 0.8, 0.3, 0.08)), true, -1.0, true)
			draw_rect(Rect2(0, base, w, h), _fa(Color(0.04, 0.03, 0.025)))
			for i in 2:
				draw_line(Vector2(w * 0.4 + i * 70, base), Vector2(w * 0.5 + i * 160, h), _fa(Color(0.2, 0.15, 0.1)), 4.0)
			_ash(40, 0.05, Color(0.6, 0.5, 0.4, 0.4))
		"act4":
			_sky(Color(0.03, 0.02, 0.05), Color(0.25, 0.08, 0.14))
			for i in 7:
				var x := w * (0.08 + i * 0.14)
				draw_rect(Rect2(x, h * 0.18, 46, base - h * 0.18), _fa(Color(0.05, 0.035, 0.08)))
				draw_rect(Rect2(x - 8, h * 0.18 - 14, 62, 16), _fa(Color(0.07, 0.05, 0.1)))
			draw_rect(Rect2(0, base, w, h), _fa(Color(0.025, 0.02, 0.035)))
			_figure(Vector2(w * 0.5, base), 260.0, Color(0.14, 0.08, 0.2))
			draw_circle(Vector2(w * 0.5, base - 190), 90.0, _fa(Color(1.6, 0.5, 1.0, 0.1 + 0.04 * sin(clock * 2.0))), true, -1.0, true)
			_embers(40, Color(2.2, 0.5, 1.2, 0.7))
		"act5":
			_sky(Color(0.05, 0.01, 0.01), Color(0.7, 0.15, 0.04))
			_crown(Vector2(w * 0.5, h * 0.28), 110.0, 0.7 + 0.3 * sin(clock * 2.0), true)
			_ridge(base - 20, 90, 0.005, 2.0, Color(0.1, 0.03, 0.03), 5.0)
			_ridge(base + 40, 50, 0.008, 6.0, Color(0.04, 0.015, 0.015), 9.0)
			for i in 8:
				var x := fmod(i * 240.0 - clock * 20.0 + w * 2.0, w + 160.0) - 80.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 20, base + 40), Vector2(x + 20, base + 40), Vector2(x + (i % 3) * 6.0, base - 90 - (i % 4) * 30)]), _fa(Color(0.03, 0.01, 0.01)))
			draw_rect(Rect2(0, base + 60, w, h), _fa(Color(0.02, 0.008, 0.008)))
			for i in 12:
				_flame(Vector2(fmod(i * 177.0, w), base + 56), 22.0, 70.0, 1.0)
			_embers(90)
		"king":
			var flash := maxf(0.0, sin(clock * 1.3)) * (1.0 if fmod(clock, 4.0) < 0.25 else 0.0)
			_sky(Color(0.04 + flash, 0.01 + flash * 0.5, 0.01), Color(0.5 + flash, 0.1, 0.03))
			_ridge(base, 60, 0.004, 1.0, Color(0.05, 0.02, 0.02), 1.0)
			draw_rect(Rect2(w * 0.35, base - 40, w * 0.3, h), _fa(Color(0.04, 0.02, 0.02)))
			_figure(Vector2(w * 0.5, base - 40), 340.0 + sin(clock) * 4.0, Color(0.015, 0.01, 0.01), true)
			_embers(80)
