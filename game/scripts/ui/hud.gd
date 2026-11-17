class_name Hud
extends Control

const Ink := preload("res://scripts/fx/ink.gd")
## In-game HUD, drawn directly: orbs, skill bar, ash meter, minimap, boss bar, banners.

var world: World
var banner_title := ""
var banner_sub := ""
var banner_t := 0.0
var big_map := false
var t := 0.0
var _hp_trail := 1.0


var _map_rect := Rect2()
var _map_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_banner(title: String, sub: String) -> void:
	banner_title = title
	banner_sub = sub
	banner_t = 4.0


func _process(dt: float) -> void:
	t += dt
	banner_t = maxf(0.0, banner_t - dt)
	if world and world.player:
		var r := world.player.hp / world.player.max_hp
		_hp_trail = r if r > _hp_trail else move_toward(_hp_trail, r, dt * 0.35)
	# The big map pauses the game so you can place markers in peace.
	if Input.is_action_just_pressed("map") and (not get_tree().paused or big_map):
		big_map = not big_map
		get_tree().paused = big_map
	queue_redraw()


func _draw() -> void:
	if world == null or world.player == null:
		return
	var vs := get_viewport_rect().size
	var p := world.player
	_draw_vignette(vs, p)
	_draw_bottom(vs, p)
	_draw_top(vs)
	_draw_minimap(vs)
	if big_map:
		_draw_big_map(vs)
	_draw_boss(vs)
	_draw_banner(vs)
	_draw_left(p)
	_draw_tracker(vs)
	_draw_guide_arrow(vs)
	_draw_prompt(vs)
	_draw_recall(vs)


# ---------------------------------------------------------------- pieces

func _text(pos: Vector2, s: String, size: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	var f := font if font else Game.font_body
	if outline > 0:
		draw_string_outline(f, pos, s, align, width, size, outline, Color(0, 0, 0, 0.75 * col.a))
	draw_string(f, pos, s, align, width, size, col)


func _center_text(cx: float, y: float, s: String, size: int, col: Color, font: Font = null, outline := 0) -> void:
	var f := font if font else Game.font_body
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(cx - w * 0.5, y), s, size, col, f, HORIZONTAL_ALIGNMENT_LEFT, -1, outline)


func _draw_vignette(vs: Vector2, p: Player) -> void:
	var low := 1.0 - clampf(p.hp / p.max_hp / 0.35, 0.0, 1.0)
	if low > 0.0 and not p.dead:
		var pulse := 0.75 + 0.25 * sin(t * 6.0)
		_edge(vs, Color(0.45, 0.02, 0.0, 0.55 * low * pulse))
	if p.ash_cursed():
		_edge(vs, Color(0.35, 0.33, 0.32, 0.45))


func _edge(vs: Vector2, c: Color) -> void:
	var clear := Color(c.r, c.g, c.b, 0.0)
	var e := 180.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, e), Vector2(0, e)]), PackedColorArray([c, c, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, vs.y - e), Vector2(vs.x, vs.y - e), Vector2(vs.x, vs.y), Vector2(0, vs.y)]), PackedColorArray([clear, clear, c, c]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, vs.y), Vector2(0, vs.y)]), PackedColorArray([c, clear, clear, c]))
	draw_polygon(PackedVector2Array([Vector2(vs.x - e, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - e, vs.y)]), PackedColorArray([clear, c, c, clear]))


static var _ring_tex: Texture2D


## A disc that is clear in the middle and dark at the edge: it rounds a flat circle into a ball.
func _ring() -> Texture2D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 0.93, 0.985, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.05), Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.66), Color(0, 0, 0, 0)])
		var t2 := GradientTexture2D.new()
		t2.gradient = g
		t2.fill = GradientTexture2D.FILL_RADIAL
		t2.fill_from = Vector2(0.5, 0.5)
		t2.fill_to = Vector2(1.0, 0.5)
		t2.width = 128
		t2.height = 128
		_ring_tex = t2
	return _ring_tex


func _orb(center: Vector2, r: float, ratio: float, col: Color, trail: float, style := "") -> void:
	draw_circle(center, r + 7.0, Color(0.03, 0.025, 0.025, 0.92), true, -1.0, true)
	draw_circle(center, r, Color(0.08, 0.06, 0.055), true, -1.0, true)
	if trail > ratio:
		_liquid(center, r, trail, Color(0.9, 0.85, 0.75, 0.25))
	_liquid(center, r, ratio, col)
	_orb_fx(center, r, ratio, style)
	# Roundness: the edge falls into shadow, light pools on the upper left and the lower right catches a glow
	var rr := r - 1.0
	draw_texture_rect(_ring(), Rect2(center - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false)
	var soft := Ink.soft_tex()
	draw_texture_rect(soft, Rect2(center + Vector2(-0.62, -0.7) * r, Vector2(0.78, 0.6) * r), false, Color(1, 1, 1, 0.34))
	draw_texture_rect(soft, Rect2(center + Vector2(-0.42, -0.58) * r, Vector2(0.26, 0.16) * r), false, Color(1, 1, 1, 0.75))
	draw_texture_rect(soft, Rect2(center + Vector2(0.05, 0.42) * r, Vector2(0.62, 0.42) * r), false, Color(col.r, col.g, col.b, 0.0).lerp(Color(1, 0.8, 0.7, 0.16), 1.0))
	# Gothic bronze ring with a lit upper-left edge and rivets.
	draw_arc(center, r + 5.0, 0.0, TAU, 72, Color(0.02, 0.015, 0.012), 9.0, true)
	draw_arc(center, r + 5.0, 0.0, TAU, 72, Ornate.GOLD_LO, 6.0, true)
	draw_arc(center, r + 5.0, PI * 0.8, PI * 1.75, 40, Ornate.GOLD_HI, 4.0, true)
	draw_arc(center, r + 5.0, PI * 1.75, PI * 2.2, 20, Ornate.GOLD_MID, 4.0, true)
	draw_arc(center, r + 5.0, PI * 0.2, PI * 0.8, 20, Ornate.GOLD_MID, 3.0, true)
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.39
		var q := center + Vector2(cos(a), sin(a)) * (r + 5.0)
		draw_circle(q, 3.2, Color(0.04, 0.03, 0.02), true, -1.0, true)
		draw_circle(q, 2.2, Ornate.GOLD_HI.lerp(Ornate.GOLD_LO, 0.5 + 0.5 * sin(a)), true, -1.0, true)


## What lives in the glass: each resource has its own matter, and its own way of showing how much is left.
func _orb_fx(center: Vector2, r: float, ratio: float, style: String) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.01:
		return
	var rr := r - 3.0
	var surf_y := center.y + rr - 2.0 * rr * ratio
	var half := sqrt(maxf(rr * rr - (surf_y - center.y) * (surf_y - center.y), 0.0)) * 0.86
	var soft := Ink.soft_tex()
	match style:
		"blood":
			# slow bubbles rising through thick blood and a dark clot drifting at the surface
			for i in 7:
				var ph := fposmod(t * (0.12 + i * 0.017) + i * 0.37, 1.0)
				var bx := center.x + sin(i * 2.3 + t * 0.4) * half * 0.8
				var by := center.y + rr - ph * (center.y + rr - surf_y)
				if by > surf_y + 3.0:
					Ink.dot(self, Vector2(bx, by), 1.4 + (i % 3) * 0.9, Color(1.0, 0.55, 0.5, 0.35 * sin(ph * PI)))
			draw_texture_rect(soft, Rect2(center.x - half * 0.6 + sin(t * 0.5) * half * 0.3, surf_y - 2.0, half * 0.7, 9.0), false, Color(0.12, 0.0, 0.0, 0.55))
		"Cinder":
			# molten metal: a hot seam under a cooling crust, and sparks lifting off the surface
			for i in 5:
				var cx := center.x + sin(i * 1.9 + t * 0.35) * half * 0.8
				draw_texture_rect(soft, Rect2(cx - 11, surf_y - 1.0, 22, 7), false, Color(0.08, 0.03, 0.02, 0.7))
			draw_texture_rect(soft, Rect2(center.x - half, surf_y - 6.0, half * 2.0, 14.0), false, Color(1.6, 0.9, 0.3, 0.45 + 0.15 * sin(t * 3.0)))
			for i in 6:
				var ph := fposmod(t * (0.35 + i * 0.05) + i * 0.29, 1.0)
				var ex := center.x + sin(i * 3.1 + ph * 4.0) * half * 0.7
				var ey := surf_y - ph * minf(r * 0.7, surf_y - (center.y - rr) - 2.0)
				if ey > center.y - rr + 4.0:
					Ink.dot(self, Vector2(ex, ey), 1.6, Color(1.0, 0.7, 0.25, 0.9 * (1.0 - ph)))
		"Soul Embers":
			# pale wisps curling up through the glass, with cold motes among them
			var segs := PackedVector2Array()
			for w in 4:
				var x0 := center.x + (w - 1.5) * half * 0.5
				var prev := Vector2(x0, center.y + rr - 2.0)
				var top := maxf(surf_y + 4.0, center.y - rr + 6.0)
				for k in range(1, 13):
					var f := float(k) / 12.0
					var y := lerpf(center.y + rr - 2.0, top, f)
					var q := Vector2(x0 + sin(f * 7.0 + t * 1.3 + w * 1.7) * half * 0.16 * (0.4 + f), y)
					segs.append(prev)
					segs.append(q)
					prev = q
			draw_multiline(segs, Color(0.75, 1.0, 0.95, 0.3), 1.6, true)
			for i in 6:
				var ph := fposmod(t * 0.2 + i * 0.17, 1.0)
				Ink.dot(self, Vector2(center.x + sin(i * 2.7 + t * 0.6) * half * 0.8, center.y + rr - ph * (center.y + rr - surf_y)), 1.5, Color(0.8, 1.0, 1.0, 0.7 * sin(ph * PI)))
		"Heat":
			# flames standing on the surface: the more heat, the taller they stand
			var room := minf(r * 0.95, surf_y - (center.y - rr) - 2.0)
			if room > 6.0:
				for i in 5:
					var fx := center.x + (i - 2.0) * half * 0.42
					var fh := room * (0.55 + 0.45 * sin(t * 4.0 + i * 1.7)) * (1.0 - absf(i - 2.0) * 0.18)
					Ink.flame(self, Vector2(fx, surf_y + 1.0), half * 0.28, fh, t, float(i) * 3.7, Color(1.8, 0.65, 0.12, 0.85), Color(1.4, 0.22, 0.05, 0.6))
		"Crown Fire":
			# gold that turns slowly, glittering
			for i in 8:
				var a := t * 0.6 + i * TAU / 8.0
				var pp := Vector2(center.x + cos(a) * half * 0.6, lerpf(surf_y + 6.0, center.y + rr - 6.0, 0.5 + 0.5 * sin(a * 1.3 + i)))
				Ink.dot(self, pp, 1.5, Color(1.0, 0.95, 0.6, 0.6 * (0.5 + 0.5 * sin(t * 3.0 + i))))


func _liquid(center: Vector2, r: float, ratio: float, col: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.005:
		return
	var rr := r - 1.0
	if ratio >= 0.995:
		var pts_f := PackedVector2Array()
		var cols_f := PackedColorArray()
		for i in 48:
			var a := TAU * i / 48.0
			var q := Vector2(cos(a), sin(a))
			pts_f.append(center + q * rr)
			var k := clampf(q.y * 0.5 + 0.5, 0.0, 1.0)
			var c3 := col.lerp(Color(col.r * 0.32, col.g * 0.3, col.b * 0.3, col.a), k * 0.85)
			cols_f.append(Color(c3.r * (1.25 - k * 0.2), c3.g * (1.25 - k * 0.2), c3.b * (1.25 - k * 0.2), col.a))
		draw_polygon(pts_f, cols_f)
		return
	var dy := rr - 2.0 * rr * ratio
	var a0 := asin(clampf(dy / rr, -1.0, 1.0))
	var a1 := PI - a0
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	var left := pts[pts.size() - 1]
	var right := pts[0]
	var m := 12
	var amp := minf(2.0, (right.x - left.x) * 0.02)
	for i in range(1, m):
		var k := float(i) / m
		var x := lerpf(left.x, right.x, k)
		pts.append(Vector2(x, center.y + dy + sin(x * 0.08 + t * 3.0) * amp * sin(k * PI)))
	# lit at the surface and deepening toward the bottom of the glass
	var cols := PackedColorArray()
	cols.resize(pts.size())
	var top_y := center.y + dy
	for i in pts.size():
		var k := clampf((pts[i].y - top_y) / maxf(center.y + rr - top_y, 1.0), 0.0, 1.0)
		var c2 := col.lerp(Color(col.r * 0.32, col.g * 0.3, col.b * 0.3, col.a), k * 0.85)
		cols[i] = Color(c2.r * (1.25 - k * 0.2), c2.g * (1.25 - k * 0.2), c2.b * (1.25 - k * 0.2), col.a)
	draw_polygon(pts, cols)
	draw_line(left, right, Color(1, 0.95, 0.9, 0.5), 2.0, true)
	draw_line(left + Vector2(0, 2), right + Vector2(0, 2), Color(1, 1, 1, 0.12), 3.0, true)


func _draw_bottom(vs: Vector2, p: Player) -> void:
	var cx := vs.x * 0.5
	var by := vs.y - 48.0
	# Backplate
	var plate := PackedVector2Array([Vector2(cx - 420, by + 26), Vector2(cx - 400, by - 74), Vector2(cx + 400, by - 74), Vector2(cx + 420, by + 26)])
	draw_colored_polygon(plate, Color(0.045, 0.038, 0.036, 0.94))
	draw_line(Vector2(cx - 400, by - 74), Vector2(cx + 400, by - 74), Ornate.GOLD_HI, 3.0)
	draw_line(Vector2(cx - 400, by - 70), Vector2(cx + 400, by - 70), Color(0.45, 0.07, 0.05, 0.9), 2.0)
	draw_line(Vector2(cx - 420, by + 26), Vector2(cx - 400, by - 74), Ornate.GOLD_MID, 3.0)
	draw_line(Vector2(cx + 420, by + 26), Vector2(cx + 400, by - 74), Ornate.GOLD_LO, 3.0)
	# Orbs
	var orb_r := 70.0
	var hp_c := Vector2(cx - 500, vs.y - 118)
	var res_c := Vector2(cx + 500, vs.y - 118)
	_orb(hp_c, orb_r, p.hp / p.max_hp, Color(0.62, 0.02, 0.025), _hp_trail, "blood")
	var rc: Color = p.data.res_color
	_orb(res_c, orb_r, p.resource / p.res_max, Color(rc.r * 0.75, rc.g * 0.75, rc.b * 0.75), 0.0, String(p.data.resource))
	_center_text(hp_c.x, hp_c.y + 8, "%d" % ceili(p.hp), 26, Color(1, 0.95, 0.9), Game.font_display_bold, 5)
	_center_text(hp_c.x, hp_c.y + 30, "/ %d" % ceili(p.max_hp), 15, Color(0.85, 0.8, 0.75, 0.8), Game.font_body, 4)
	_center_text(res_c.x, res_c.y + 8, "%d" % int(p.resource), 26, Color(1, 0.95, 0.9), Game.font_display_bold, 5)
	_center_text(res_c.x, res_c.y + orb_r + 32, String(p.data.resource).to_upper(), 13, Color(0.7, 0.65, 0.6), Game.font_display)
	_center_text(hp_c.x, hp_c.y + orb_r + 32, "LIFE", 13, Color(0.7, 0.65, 0.6), Game.font_display)
	if p.cls == "pyrewitch" and p.overheat_t > 0.0:
		_center_text(res_c.x, res_c.y - orb_r - 18, "OVERHEATED", 15, Color(1.0, 0.45, 0.25), Game.font_display_bold, 4)

	# Skill slots
	var size := 64.0
	var gap := 12.0
	var total := size * 4 + gap * 3 + 30 + size * 1.2
	var x0 := cx - total * 0.5
	for i in 5:
		var s := size if i < 4 else size * 1.2
		var x := x0 + i * (size + gap) + (30.0 if i == 4 else 0.0)
		var y := by - 52.0 - (s - size) * 0.5
		_slot(Rect2(x, y, s, s), i, p)
	# Flask
	var fx := hp_c.x + orb_r + 46.0
	var fy := vs.y - 86.0
	_small_slot(Vector2(fx, fy), "flask", -1, -1, Game.key_label("flask"), Color(0.85, 0.2, 0.15), clampf(Game.potion_cd / p.potion_cooldown(), 0.0, 1.0), ceili(Game.potion_cd))
	_small_slot(Vector2(fx + 56.0, fy), "dodge", -1, -1, Game.key_label("dodge"), Color(0.8, 0.75, 0.7), p.dodge_cd / (2.0 if p.frag("hollow") else 1.0))

	# Ash meter
	var aw := 520.0
	var ax := cx - aw * 0.5
	var ay := by - 92.0
	var ash := p.ash / 100.0
	draw_rect(Rect2(ax - 2, ay - 2, aw + 4, 10), Color(0, 0, 0, 0.8))
	var ac := Color(0.75, 0.55, 0.4)
	if ash >= 1.0:
		var pulse := 0.6 + 0.4 * sin(t * 5.0)
		ac = Color(1.0, 0.55, 0.2).lerp(Color(1.3, 0.85, 0.4), pulse)
		if p.ash_cursed():
			ac = Color(0.6, 0.58, 0.56)
	draw_rect(Rect2(ax, ay, aw * ash, 6), ac)
	for k in range(1, 10):
		draw_line(Vector2(ax + aw * k / 10.0, ay), Vector2(ax + aw * k / 10.0, ay + 6), Color(0, 0, 0, 0.6), 1.0)
	var label := "ASH" if ash < 1.0 else ("THE ASH CLAIMS YOU" if p.ash_cursed() else "ASH  ·  ULTIMATE READY")
	_center_text(cx, ay - 8, label, 13, Color(0.8, 0.75, 0.7, 0.9), Game.font_display)
	# XP
	var xw := 800.0
	draw_rect(Rect2(cx - xw * 0.5, vs.y - 6, xw, 3), Color(0.1, 0.09, 0.08))
	draw_rect(Rect2(cx - xw * 0.5, vs.y - 6, xw * p.xp / p.xp_next, 3), Color(0.85, 0.6, 0.3))


## Beveled bronze frame around a dark socket.
func _frame(r: Rect2) -> void:
	draw_rect(r.grow(4.0), Color(0.01, 0.008, 0.008))
	draw_rect(r.grow(3.0), Ornate.GOLD_LO)
	draw_rect(Rect2(r.position - Vector2(3, 3), Vector2(r.size.x + 6, 2)), Ornate.GOLD_HI)
	draw_rect(Rect2(r.position - Vector2(3, 3), Vector2(2, r.size.y + 6)), Ornate.GOLD_HI)
	draw_rect(Rect2(r.position + Vector2(-3, r.size.y + 1), Vector2(r.size.x + 6, 2)), Ornate.GOLD_MID)
	draw_rect(Rect2(r.position + Vector2(r.size.x + 1, -3), Vector2(2, r.size.y + 6)), Ornate.GOLD_MID)
	draw_rect(r.grow(0.5), Color(0.025, 0.02, 0.02))
	draw_rect(r, Color(0.07, 0.06, 0.055))


func _slot(r: Rect2, slot: int, p: Player) -> void:
	var i := p.slot_ability(slot)
	var a: Dictionary = p.abilities[i]
	var ready := p.can_cast(i)
	var cd: float = p.cds[i]
	var cd_max: float = a.cd
	if p.cls == "pyrewitch" and a.id == "step":
		cd = 0.0 if p.step_charges > 0 else a.cd - p.step_recharge
	var lacking := not ready and cd <= 0.0 and i != 4
	_frame(r)
	var col := Color(1.0, 0.82, 0.6) if ready else Color(0.55, 0.5, 0.46)
	if i == 4:
		col = Color(1.0, 0.6, 0.25) if ready else Color(0.45, 0.42, 0.4)
	if lacking:
		col = Color(0.6, 0.3, 0.28)
	Icons.draw(self, a.id, r.get_center(), r.size.x * 0.82, col)
	var need := Data.ability_unlock(i, p.cls)
	if p.level < need:
		draw_rect(r, Color(0, 0, 0, 0.7))
		_center_text(r.get_center().x, r.get_center().y + 6, "LV %d" % need, 16, Color(0.8, 0.6, 0.4), Game.font_display_bold)
	if i == 4:
		var fill := p.ash / 100.0
		if fill < 1.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * (1.0 - fill))), Color(0, 0, 0, 0.55))
		var bc := Color(0.75, 0.45, 0.2) if not ready else Color(1.2, 0.7, 0.3).lerp(Color(1.0, 0.45, 0.15), 0.5 + 0.5 * sin(t * 5.0))
		draw_rect(r, bc, false, 2.0)
		if p.ult_t > 0.0:
			draw_rect(r.grow(4), Color(1.2, 0.6, 0.2, 0.5 + 0.3 * sin(t * 8.0)), false, 2.0)
	if cd > 0.0 and cd_max > 0.0:
		var k := clampf(cd / cd_max, 0.0, 1.0)
		_sweep(r, k)
		if cd > 1.0:
			_center_text(r.get_center().x, r.get_center().y + 9, "%d" % ceili(cd), 24, Color(1, 1, 1, 0.9), Game.font_display_bold, 4)
	if p.cls == "pyrewitch" and a.id == "step" and p.has_mod("step_double"):
		_text(r.position + Vector2(r.size.x - 14, 18), str(p.step_charges), 15, Color(1, 0.9, 0.8), Game.font_display_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var cost := float(a.cost)
	if p.cls == "pyrewitch":
		cost = Data.HEAT_COST.get(a.id, 0.0)
	if cost != 0.0 and i != 4:
		var cs := ("+%d" % int(cost)) if (p.cls == "pyrewitch" and cost > 0) else str(int(absf(cost)))
		if p.cls == "pyrewitch" and cost < 0:
			cs = "−%d" % int(-cost)
		_text(r.position + Vector2(4, r.size.y - 5), cs, 13, Color(0.85, 0.75, 0.65, 0.9), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	_center_text(r.get_center().x, r.end.y + 20, Game.key_label(["attack_1", "attack_2", "skill_1", "skill_2", "ultimate"][slot]), 14, Color(0.75, 0.7, 0.65), Game.font_display_bold)


func _sweep(r: Rect2, k: float) -> void:
	if k <= 0.002 or k >= 0.998:
		if k >= 0.998:
			draw_rect(r, Color(0, 0, 0, 0.62))
		return
	var c := r.get_center()
	var pts := PackedVector2Array([c])
	var n := 32
	var rad := r.size.x * 0.75
	for i in n + 1:
		var a := -PI / 2 + TAU * (1.0 - k) + TAU * k * i / n
		var q := c + Vector2(cos(a), sin(a)) * rad
		q.x = clampf(q.x, r.position.x, r.end.x)
		q.y = clampf(q.y, r.position.y, r.end.y)
		pts.append(q)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.62))


func _small_slot(c: Vector2, id: String, charges: int, max_charges: int, key: String, col: Color, cd := 0.0, secs := 0) -> void:
	var r := Rect2(c - Vector2(22, 22), Vector2(44, 44))
	_frame(r)
	var on := charges != 0 and cd <= 0.0
	Icons.draw(self, id, c, 40.0, col if on else Color(0.4, 0.37, 0.35))
	if cd > 0.0:
		_sweep(r, clampf(cd, 0.0, 1.0))
		if secs > 0:
			_center_text(c.x, c.y + 8, "%d" % secs, 20, Color(1, 1, 1, 0.95), Game.font_display_bold, 4)
	if max_charges > 0:
		_text(r.position + Vector2(r.size.x - 12, r.size.y - 4), str(charges), 15, Color(1, 0.9, 0.8), Game.font_display_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	_center_text(c.x, r.end.y + 16, key, 12, Color(0.7, 0.65, 0.6), Game.font_display_bold)


func _draw_top(vs: Vector2) -> void:
	var cx := vs.x * 0.5
	var z: Dictionary = world.zone
	if world.boss and world.state == "boss":
		return
	_center_text(cx, 42, String(z.name).to_upper(), 20, Color(0.85, 0.8, 0.74), Game.font_display, 4)
	if world.objective != "":
		var w := Game.font_italic.get_string_size(world.objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_line(Vector2(cx - w * 0.5 - 40, 58), Vector2(cx - w * 0.5 - 12, 58), Color(0.7, 0.45, 0.25, 0.8), 1.0)
		draw_line(Vector2(cx + w * 0.5 + 12, 58), Vector2(cx + w * 0.5 + 40, 58), Color(0.7, 0.45, 0.25, 0.8), 1.0)
		_center_text(cx, 64, world.objective, 19, Color(0.95, 0.75, 0.5), Game.font_italic, 4)


func _draw_left(p: Player) -> void:
	var x := 32.0
	var y := 44.0
	_text(Vector2(x, y), ("LEVEL %d%s%s" % [p.level, "  ·  MAX" if p.level >= Data.MAX_LEVEL else "", ("  ·  PRESTIGE %d" % Game.prestige) if Game.prestige > 0 else ""]), 18, Color(0.9, 0.85, 0.78), Game.font_display_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	y += 26
	_text(Vector2(x, y), "%s  ·  %s" % [Game.hero_name, p.data.name], 16, Color(0.65, 0.6, 0.56), Game.font_display, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	y += 22
	if Game.hardcore:
		_text(Vector2(x, y), "HARDCORE", 14, Color(0.9, 0.35, 0.25), Game.font_display_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		y += 20
	_text(Vector2(x, y), Game.diff().name, 14, Game.C_GOLD, Game.font_display, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	y += 24
	_text(Vector2(x, y), "%d gold" % Game.gold, 17, Color(1.0, 0.85, 0.3), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	y += 24
	if p.pending_levels > 0:
		_text(Vector2(x, y), "%d skill point%s  ·  K" % [p.pending_levels, "" if p.pending_levels == 1 else "s"], 16, Color(0.6, 0.9, 0.6), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		y += 22
	var broken := 0
	for s in Game.equipment.keys():
		if Items.is_broken(Game.equipment[s]):
			broken += 1
	if broken > 0:
		_text(Vector2(x, y), "%d item%s broken. Find the smith." % [broken, "" if broken == 1 else "s"], 16, Color(0.9, 0.3, 0.25), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		y += 22
	y += 8
	for f in Game.fragments:
		for d in Data.FRAGMENTS:
			if d.id == f:
				Icons.crown(self, Vector2(x + 9, y - 6), 16.0, Color(1.0, 0.6, 0.25), Color(1.2, 0.8, 0.4))
				_text(Vector2(x + 26, y), d.name.replace("Fragment of ", ""), 15, Color(0.95, 0.7, 0.45), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
				y += 24
	y += 6
	for b in p.buffs.keys():
		var nm: String = {"fury": "Fury", "warding": "Warding", "haste": "Haste"}.get(b, b)
		_text(Vector2(x, y), "%s  %ds" % [nm, ceili(p.buffs[b])], 15, Color(0.8, 0.85, 1.0), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		y += 22
	if p.cls == "gravecaller":
		_text(Vector2(x, y), "Ashbound  %d / %d" % [p.minion_count("skeleton"), p.max_skeletons()], 15, Color(0.6, 0.85, 0.8), Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)


func _draw_minimap(vs: Vector2) -> void:
	if big_map or not bool(Game.settings.get("minimap", true)):
		return
	var size := 250.0
	var r := Rect2(vs.x - size - 28, 28, size, size)
	draw_rect(r.grow(5), Color(0.02, 0.018, 0.018, 0.85))
	draw_rect(r, Color(0.05, 0.045, 0.04, 0.75))
	var span := 64.0
	var pc := world.player.global_position / World.CELL
	var src := Rect2(pc - Vector2(span, span) * 0.5, Vector2(span, span))
	var scale := size / span
	# Clip the source rect to the map
	var clip := src.intersection(Rect2(0, 0, world.map.w, world.map.h))
	if clip.size.x > 0 and clip.size.y > 0:
		var dst := Rect2(r.position + (clip.position - src.position) * scale, clip.size * scale)
		draw_texture_rect_region(world.minimap_tex, dst, clip)
	_markers(r, src, scale)
	draw_rect(r, Color(0.4, 0.31, 0.22), false, 1.5)
	_center_text(r.get_center().x, r.end.y + 26, "TAB  ·  MAP" if not Game.using_gamepad else "BACK  ·  MAP", 12, Color(0.6, 0.56, 0.52), Game.font_display)


func _markers(r: Rect2, src: Rect2, scale: float) -> void:
	var to_screen := func(world_pos: Vector2) -> Vector2:
		return r.position + (world_pos / World.CELL - src.position) * scale
	# Objective marker, clamped to the frame
	var goal: Vector2 = to_screen.call(world.objective_pos)
	var inside := r.grow(-8).has_point(goal)
	goal = Vector2(clampf(goal.x, r.position.x + 8, r.end.x - 8), clampf(goal.y, r.position.y + 8, r.end.y - 8))
	var gc := Color(1.0, 0.55, 0.2, 0.75 + 0.25 * sin(t * 4.0))
	if inside:
		Icons.crown(self, goal, 18.0, gc, Color(1.2, 0.8, 0.4))
	else:
		draw_circle(goal, 5.0, gc, true, -1.0, true)
	for e in world.enemies:
		if e.dead or e.sleeping and not e.is_champion:
			continue
		var q2: Vector2 = to_screen.call(e.global_position)
		if r.has_point(q2):
			draw_circle(q2, 2.5 if not e.elite else 4.0, Color(0.9, 0.25, 0.15) if not e.elite else Color(1.0, 0.6, 0.2), true, -1.0, true)
	for mk in Game.markers:
		var mp: Vector2 = to_screen.call(mk)
		var mc := Color(0.6, 0.95, 1.4)
		var inside_m := r.grow(-6).has_point(mp)
		mp = Vector2(clampf(mp.x, r.position.x + 6, r.end.x - 6), clampf(mp.y, r.position.y + 6, r.end.y - 6))
		draw_line(mp, mp + Vector2(0, -16), mc, 2.0)
		draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -16), mp + Vector2(10, -12), mp + Vector2(0, -8)]), mc)
		if not inside_m:
			draw_circle(mp, 3.0, mc, true, -1.0, true)
	var pp: Vector2 = to_screen.call(world.player.global_position)
	var d := world.player.aim_dir
	draw_colored_polygon(PackedVector2Array([pp + d * 8.0, pp + d.rotated(2.5) * 6.0, pp + d.rotated(-2.5) * 6.0]), Color(1, 0.95, 0.85))


func _draw_big_map(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var m := world.map
	var scale := minf((vs.x - 300) / m.w, (vs.y - 260) / m.h)
	var size := Vector2(m.w, m.h) * scale
	var r := Rect2((vs - size) * 0.5 + Vector2(0, 20), size)
	draw_texture_rect(world.minimap_tex, r, false, Color(1, 1, 1, 0.9))
	var src := Rect2(0, 0, m.w, m.h)
	_markers(r, src, scale)
	_map_rect = r
	_map_scale = scale
	for reg in world.map.regions:
		var cp: Vector2 = r.position + (Vector2(reg.off) + Vector2(reg.w, reg.h) * 0.5) * scale
		var known: bool = reg.zone < 0 or bool(Game.zs(reg.zone).visited)
		var nm: String = (reg.zd.name if known else "?")
		_center_text(cp.x, cp.y, nm.to_upper(), 13, Color(0.9, 0.8, 0.65, 0.85) if known else Color(0.5, 0.47, 0.44, 0.6), Game.font_display, 3)
	_center_text(vs.x * 0.5, r.position.y - 24, String(world.zone.name).to_upper(), 26, Color(0.9, 0.85, 0.78), Game.font_display_bold, 4)
	_center_text(vs.x * 0.5, r.end.y + 26, "Click  ·  place marker      Right click  ·  remove      Tab  ·  close", 16, Color(0.7, 0.65, 0.6), Game.font_body)


func _draw_boss(vs: Vector2) -> void:
	var b := world.boss
	if b == null or b.dead or world.state != "boss":
		return
	var w := minf(900.0, vs.x - 700.0)
	var cx := vs.x * 0.5
	var y := 64.0
	_center_text(cx, y - 14, b.display_name.to_upper(), 24, Color(1.0, 0.8, 0.6), Game.font_display_bold, 5)
	draw_rect(Rect2(cx - w * 0.5 - 3, y - 3, w + 6, 20), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(cx - w * 0.5, y, w * b.hp / b.max_hp, 14), Color(0.7, 0.12, 0.05))
	draw_rect(Rect2(cx - w * 0.5, y, w * b.hp / b.max_hp, 4), Color(1.0, 0.45, 0.2, 0.6))
	for k in [0.33, 0.66]:
		draw_line(Vector2(cx - w * 0.5 + w * k, y), Vector2(cx - w * 0.5 + w * k, y + 14), Color(0, 0, 0, 0.8), 2.0)
	draw_rect(Rect2(cx - w * 0.5 - 3, y - 3, w + 6, 20), Color(0.5, 0.35, 0.22), false, 1.5)


func _draw_banner(vs: Vector2) -> void:
	if banner_t <= 0.0:
		return
	var a := clampf(minf((4.0 - banner_t) / 0.5, banner_t / 0.8), 0.0, 1.0)
	var cx := vs.x * 0.5
	var y := vs.y * 0.24
	var tw := Game.font_display_bold.get_string_size(banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var lw := tw * 0.5 + 60.0
	draw_rect(Rect2(cx - lw - 80, y - 58, (lw + 80) * 2, 104 if banner_sub != "" else 76), Color(0, 0, 0, 0.35 * a))
	_center_text(cx, y, banner_title, 46, Color(1.0, 0.86, 0.68, a), Game.font_display_bold, 6)
	draw_line(Vector2(cx - lw, y + 14), Vector2(cx + lw, y + 14), Color(0.9, 0.5, 0.2, 0.7 * a), 1.0)
	if banner_sub != "":
		_center_text(cx, y + 42, banner_sub, 22, Color(0.85, 0.8, 0.75, a), Game.font_italic, 4)


func _draw_tracker(vs: Vector2) -> void:
	if big_map:
		return
	var x := vs.x - 280.0
	var y := 330.0
	var n := 0
	for q in Data.QUESTS:
		var st := Game.quest_status(q.id)
		if st != 1 and st != 2:
			continue
		if n >= 4:
			break
		n += 1
		var p: int = int((Game.quests.get(q.id, {"p": 0}) as Dictionary).p)
		var col := Color(0.95, 0.75, 0.4) if st == 1 else Color(0.5, 0.9, 0.45)
		if n == 1:
			_text(Vector2(x, y), "QUESTS", 13, Color(0.6, 0.56, 0.52), Game.font_display)
			y += 20
		_text(Vector2(x, y), String(q.title), 17, col, Game.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT, 260.0, 3)
		y += 20
		var line := ("%d / %d" % [p, int(q.goal)]) if st == 1 else "Return to the Elder"
		_text(Vector2(x, y), line, 15, Color(0.78, 0.74, 0.7), Game.font_body, HORIZONTAL_ALIGNMENT_LEFT, 260.0, 3)
		y += 26


func _draw_prompt(vs: Vector2) -> void:
	if world.interact_target == null or world.interact_text == "":
		return
	var key := "G" if not Game.using_gamepad else "B"
	var txt := "[%s]  %s" % [key, world.interact_text]
	var w := Game.font_display_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var y := vs.y - 230.0
	draw_rect(Rect2(vs.x * 0.5 - w * 0.5 - 18, y - 28, w + 36, 40), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(vs.x * 0.5 - w * 0.5 - 18, y - 28, w + 36, 40), Color(0.6, 0.4, 0.2, 0.8), false, 1.0)
	_center_text(vs.x * 0.5, y, txt, 24, Color(1.0, 0.85, 0.6), Game.font_display_bold)


func _draw_recall(vs: Vector2) -> void:
	if world.recall_t <= 0.0:
		return
	var c := Vector2(vs.x * 0.5, vs.y * 0.62)
	var k := 1.0 - world.recall_t / 3.0
	draw_arc(c, 34.0, -PI / 2, -PI / 2 + TAU * k, 40, Color(0.6, 0.9, 1.4), 5.0, true)
	draw_arc(c, 34.0, 0, TAU, 40, Color(0.6, 0.9, 1.4, 0.2), 2.0, true)
	_center_text(c.x, c.y + 62, "Recalling to Cinderfall…  %.1f" % world.recall_t, 20, Color(0.8, 0.95, 1.0), Game.font_display)


func _draw_beta(vs: Vector2) -> void:
	_text(Vector2(14, vs.y - 12), Game.beta_label(), 13, Color(0.5, 0.47, 0.44, 0.8), Game.font_display)


func close_map() -> void:
	big_map = false
	get_tree().paused = false


## Left click on the big map sets a marker (the guide then leads there); right click removes the nearest.
func _unhandled_input(event: InputEvent) -> void:
	if not big_map or not (event is InputEventMouseButton) or not event.pressed:
		return
	var p: Vector2 = event.position
	if not _map_rect.has_point(p):
		return
	var wp := (p - _map_rect.position) / _map_scale * World.CELL
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Game.markers.size() >= Game.MAX_MARKERS:
			Game.markers.pop_front()
		Game.markers.append(wp)
		Sfx.play("ui_select", -6.0)
		world.guide_pts = PackedVector2Array()
		world._guide_t = 0.0
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var best := -1
		var bd := 30.0
		for i in Game.markers.size():
			var d: float = ((Game.markers[i] / World.CELL) * _map_scale + _map_rect.position).distance_to(p)
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			Game.markers.remove_at(best)
			world.guide_pts = PackedVector2Array()
			world._guide_t = 0.0
	get_viewport().set_input_as_handled()


func _draw_guide_arrow(vs: Vector2) -> void:
	if big_map or world.player == null:
		return
	var target := world.guide_target()
	if target == Vector2.ZERO:
		return
	var to := target - world.player.global_position
	var dist := to.length()
	if dist < 600.0:
		return
	var c := vs * 0.5
	var dir := to.normalized()
	var radius := minf(vs.x, vs.y) * 0.5 - 150.0
	var pos := c + dir * radius
	var col := Color(0.6, 0.9, 1.0) if world.guide_is_marker() else Color(1.0, 0.8, 0.45)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([pos + dir * 16.0, pos - dir * 10.0 + side * 12.0, pos - dir * 4.0, pos - dir * 10.0 - side * 12.0]), Color(col.r, col.g, col.b, 0.85))
	var label := "%d m" % int(dist / 64.0 * 1.6)
	_center_text(pos.x - dir.x * 34.0, pos.y - dir.y * 34.0 + 6.0, label, 15, Color(col.r, col.g, col.b, 0.9), Game.font_body_bold, 3)
