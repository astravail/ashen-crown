class_name Loot
extends Node2D
## Gold and gear lying on the ground. Gold is drawn to you; gear is taken by clicking it.

const Ink := preload("res://scripts/fx/ink.gd")

## What things are made of: the colour at the top of the object and at its foot.
const STEEL := [Color(0.76, 0.78, 0.82), Color(0.26, 0.27, 0.32)]
const IRON := [Color(0.5, 0.49, 0.5), Color(0.15, 0.14, 0.15)]
const WOOD := [Color(0.5, 0.34, 0.2), Color(0.17, 0.1, 0.06)]
const LEATHER := [Color(0.5, 0.33, 0.2), Color(0.16, 0.09, 0.06)]
const HIDE := [Color(0.3, 0.19, 0.12), Color(0.1, 0.06, 0.04)]
const GOLD := [Color(0.98, 0.78, 0.32), Color(0.42, 0.26, 0.07)]
const HOLE := [Color(0.03, 0.025, 0.03), Color(0.03, 0.025, 0.03)]
## Where each coin of a heap lies, in the order they are laid down.
const HEAP := [Vector2(-4.5, -2.5), Vector2(4.5, -3.5), Vector2(0.5, -6.5), Vector2(-7.5, -6.0), Vector2(6.0, -8.5)]

## How each kind of gear looks lying on the ground, worked out once: filled pieces and their shading,
## the inked edge as line segments, pale highlights, where the rarity-coloured trim and stone go.
static var _shapes := {}
## A coin seen from above, with its inked edge baked in, and a band of gold for rings and chains.
static var _coin: Texture2D
static var _band: Texture2D
static var _no_uv := PackedVector2Array()

var world: World
var item: Dictionary = {}
var gold := 0
var t := 0.0
var done := false
var label: Node2D
var glow: Node2D
var light: PointLight2D
var _seed := 0.0
## How far this name tag is pushed up so it does not sit on top of its neighbours' tags.
var tag_dy := 0.0
var tag_w := 0.0


func _ready() -> void:
	_seed = randf() * 10.0
	if _coin == null:
		_coin = _round_tex([0.0, 0.45, 0.72, 0.76, 0.9, 1.0], [Color(1.0, 0.88, 0.46), Color(0.94, 0.72, 0.24), Color(0.6, 0.4, 0.1), Ink.LINE, Ink.LINE, Color(Ink.LINE, 0.0)])
		_band = _round_tex([0.0, 0.5, 0.54, 0.62, 0.66, 0.8, 0.84, 0.93, 1.0], [Color(Ink.LINE, 0.0), Color(Ink.LINE, 0.0), Ink.LINE, Ink.LINE, Color(1.0, 0.82, 0.36), Color(0.55, 0.36, 0.1), Ink.LINE, Ink.LINE, Color(Ink.LINE, 0.0)])
	glow = Node2D.new()
	glow.material = World.unshaded_add
	# light behind the object, so its inked shape stands out against its own glow
	glow.show_behind_parent = true
	add_child(glow)
	glow.draw.connect(_draw_glow)
	label = Node2D.new()
	label.material = World.unshaded
	label.z_index = 4
	add_child(label)
	label.draw.connect(_draw_label)
	if not item.is_empty() and int(item.rarity) >= 2:
		light = world.make_light(Items.color_of(item), 0.6, 260.0)
		add_child(light)


func color() -> Color:
	return Color(1.0, 0.85, 0.3) if item.is_empty() else Items.color_of(item)


func update(dt: float) -> void:
	t += dt
	var p := world.player
	if p and not p.dead:
		var d := p.global_position.distance_to(global_position)
		if gold > 0:
			if d < 170.0 and t > 0.35:
				global_position = global_position.move_toward(p.global_position, (520.0 - d) * dt)
			if d < p.radius + 16.0 and t > 0.25:
				Game.add_gold(gold)
				world.texts.add_label(p.global_position + Vector2(0, -56), "+%d gold" % gold, Color(1.0, 0.85, 0.3))
				Sfx.play("pickup", -10.0, 0.1, 1.5)
				done = true
	if t > (60.0 if gold > 0 else 300.0):
		done = true
	queue_redraw()
	glow.queue_redraw()
	label.queue_redraw()


## Whether the cursor is over this piece of gear (its name tag and the thing itself).
func under_cursor(m: Vector2) -> bool:
	if gold > 0 or t < 0.4:
		return false
	var d := m - global_position
	return d.x > -58.0 and d.x < 58.0 and d.y > -60.0 + tag_dy and d.y < 16.0


## Clicked: take it, if the player is close enough and has room.
func pick_up() -> void:
	var p := world.player
	if p == null or p.dead or done:
		return
	if p.global_position.distance_to(global_position) > 340.0:
		world.texts.add_label(p.global_position + Vector2(0, -56), "Too far away", Color(0.8, 0.75, 0.7))
		return
	if Game.add_item(item):
		Game.stat_add("found_r%d" % int(item.rarity), 1.0)
		Sfx.play("pickup", -4.0, 0.1, 0.8)
		world.texts.add_label(p.global_position + Vector2(0, -56), String(item.name), color())
		if int(item.rarity) >= 3:
			Sfx.play("levelup", -4.0)
			Voice.bark("player", "legendary", "A worthy find.")
		done = true
	elif world.full_warn <= 0.0:
		world.full_warn = 3.0
		world.texts.add_label(p.global_position + Vector2(0, -56), "Inventory full", Color(1.0, 0.4, 0.3))


func _bounce() -> float:
	return absf(sin(t * 7.0)) * 24.0 * pow(maxf(0.0, 1.0 - t / 0.9), 2.0)


func _draw() -> void:
	var b := _bounce()
	# the shadow shrinks and fades while the thing is in the air
	var air := clampf(b / 24.0, 0.0, 1.0)
	if gold > 0:
		Ink.shadow(self, Vector2(2, 1), 15.0 - air * 4.0, 6.5 - air * 2.0, 0.55 - air * 0.25)
		_draw_gold(-b)
	else:
		Ink.shadow(self, Vector2(3, 3), 19.0 - air * 5.0, 8.5 - air * 2.5, 0.55 - air * 0.25)
		_draw_item(-7.0 - b)


## A little heap of coins: more of them the more gold there is.
func _draw_gold(y: float) -> void:
	var n := 2 if gold < 15 else (3 if gold < 80 else 5)
	for i in n:
		var p: Vector2 = HEAP[i]
		p.y += y
		# the coin's thickness, then its face
		draw_texture_rect(_coin, Rect2(p.x - 6.4, p.y - 2.2, 12.8, 7.8), false, Color(0.5, 0.42, 0.34))
		draw_texture_rect(_coin, Rect2(p.x - 6.4, p.y - 3.9, 12.8, 7.8), false)


func _draw_item(y: float) -> void:
	var sh := _shape(String(item.icon))
	var c := color()
	draw_set_transform(Vector2(0, y), sh.rot, Vector2.ONE)
	var band: Rect2 = sh.band
	if band.size.x > 0.0:
		draw_texture_rect(_band, band, false)
	var quads: Array = sh.quads
	var cols: Array = sh.cols
	for i in quads.size():
		draw_primitive(quads[i], cols[i], _no_uv)
	var edge: PackedVector2Array = sh.edge
	if not edge.is_empty():
		draw_multiline(edge, Ink.LINE, 1.7, true)
	var shine: PackedVector2Array = sh.shine
	if not shine.is_empty():
		draw_multiline(shine, Color(1.0, 0.97, 0.9, 0.55), 1.0, true)
	# trim and stone in the colour of its rarity
	var trim: PackedVector2Array = sh.trim
	if not trim.is_empty():
		draw_multiline(trim, c, 1.8, true)
	var gem: Vector3 = sh.gem
	if gem.z > 0.0:
		var gp := Vector2(gem.x, gem.y)
		Ink.dot(self, gp, gem.z + 1.4, Ink.LINE)
		Ink.dot(self, gp, gem.z, c)
		Ink.dot(self, gp - Vector2(gem.z, gem.z) * 0.32, gem.z * 0.35, Color(1.0, 1.0, 1.0, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	var b := _bounce()
	var soft := Ink.soft_tex()
	if gold > 0:
		# a warm sheen on the ground under the coins
		glow.draw_texture_rect(soft, Rect2(-22, -13, 44, 24), false, Color(1.5, 1.0, 0.25, 0.22))
		return
	var c := color()
	var r := int(item.rarity)
	var pulse := 0.85 + 0.15 * sin(t * 3.0 + _seed)
	# light pooled on the ground around it, and a halo about the thing itself
	var gx := 26.0 + r * 5.0
	var gy := 12.0 + r * 2.5
	glow.draw_texture_rect(soft, Rect2(-gx, -gy, gx * 2.0, gy * 2.0), false, Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, (0.14 + 0.07 * r) * pulse))
	Ink.glow(glow, Vector2(0, -7.0 - b), 18.0 + r * 3.0, Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.16 + 0.05 * r))
	if r >= 2:
		# a pillar of light, so it can be seen from across the room: wide and faint about a bright thread
		var h := 70.0 + r * 25.0
		var w := 10.0 + r * 3.0
		var top := Rect2(0, 0, 64, 32)
		glow.draw_texture_rect_region(soft, Rect2(-w, -h - 4.0, w * 2.0, h), top, Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.3 * pulse))
		glow.draw_texture_rect_region(soft, Rect2(-2.6, -h - 4.0, 5.2, h), top, Color(c.r * 2.4 + 0.4, c.g * 2.4 + 0.4, c.b * 2.4 + 0.4, 0.75))


func _draw_label() -> void:
	if gold > 0:
		_draw_glint(Vector2(-2.0 + 6.0 * sin(_seed * 7.0), -7.0 - _bounce()), 0.8, Color(3.0, 2.6, 1.6))
		return
	if int(item.rarity) >= 3:
		var c3 := color()
		_draw_glint(Vector2(5.0, -15.0 - _bounce()), 0.5, Color(c3.r * 2.0 + 1.0, c3.g * 2.0 + 1.0, c3.b * 2.0 + 1.0))
	var f := Game.font_body_bold
	var txt := String(item.name)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	tag_w = w + 28.0
	var p := Vector2(-w * 0.5, -48.0 - _bounce() + tag_dy)
	var c := color()
	label.draw_rect(Rect2(p.x - 5, p.y - 14, w + 10, 19), Color(0, 0, 0, 0.55))
	label.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
	if world.hovered_loot == self:
		label.draw_rect(Rect2(p.x - 5, p.y - 14, w + 10, 19), Color(1, 1, 1, 0.16))
		label.draw_rect(Rect2(p.x - 5, p.y - 14, w + 10, 19), Color(c.r, c.g, c.b, 0.9), false, 1.5)
	# better or worse than what is worn: a green arrow up, or a red one down
	var v := Items.verdict(item, Game.equipment)
	if v != 0:
		var ax := p.x + w + 16.0
		var ay := p.y - 5.0
		var col := Color(0.05, 0.85, 0.12) if v > 0 else Color(1.0, 0.08, 0.06)
		var k := -1.0 if v > 0 else 1.0
		var bob := sin(t * 5.0) * 1.5 * k
		Ink.tri(label, Vector2(ax - 7.5, ay - 6.0 * k + bob), Vector2(ax + 7.5, ay - 6.0 * k + bob), Vector2(ax, ay + 7.0 * k + bob), Color(0.03, 0.03, 0.03, 0.9))
		Ink.tri(label, Vector2(ax - 5.5, ay - 4.0 * k + bob), Vector2(ax + 5.5, ay - 4.0 * k + bob), Vector2(ax, ay + 5.0 * k + bob), col)


## A four-pointed glint that flares up and dies away, `rate` times a second. Drawn with the label so
## that it sits on top of the thing it shines on.
func _draw_glint(at: Vector2, rate: float, col: Color) -> void:
	var ph := fposmod(t * rate + _seed, 1.0)
	if ph > 0.3:
		return
	var k := sin(ph / 0.3 * PI)
	col.a = k
	var s := 2.0 + 5.0 * k
	label.draw_line(at - Vector2(s, 0), at + Vector2(s, 0), col, 1.2, true)
	label.draw_line(at - Vector2(0, s * 1.3), at + Vector2(0, s * 1.3), col, 1.2, true)
	Ink.glow(label, at, 4.0 + 4.0 * k, Color(col.r, col.g, col.b, 0.5 * k))


## The ground silhouette for one kind of gear icon, built the first time it is asked for.
static func _shape(icon: String) -> Dictionary:
	if _shapes.has(icon):
		return _shapes[icon]
	# pieces are [points, material]; loops are closed outlines; trim and shine are pairs of line ends
	var pieces: Array = []
	var loops: Array = []
	var trim: Array = []
	var shine: Array = []
	var rot := 0.0
	var gem := Vector3.ZERO
	var band := Rect2()
	match icon:
		"blade":
			rot = 0.85
			pieces = [
				[[Vector2(-2.4, 2), Vector2(-2.4, -12.5), Vector2(2.4, -12.5), Vector2(2.4, 2)], STEEL],
				[[Vector2(-2.4, -12.5), Vector2(0, -17), Vector2(2.4, -12.5)], STEEL],
				[[Vector2(-7, 2), Vector2(7, 2), Vector2(7, 4.6), Vector2(-7, 4.6)], IRON],
				[[Vector2(-1.7, 4.6), Vector2(1.7, 4.6), Vector2(1.7, 11.5), Vector2(-1.7, 11.5)], HIDE],
				[[Vector2(-3, 11.5), Vector2(3, 11.5), Vector2(2.2, 14.8), Vector2(-2.2, 14.8)], IRON]]
			loops = [[Vector2(0, -17), Vector2(2.4, -12.5), Vector2(2.4, 2), Vector2(7, 2), Vector2(7, 4.6), Vector2(1.7, 4.6), Vector2(1.7, 11.5), Vector2(3, 11.5), Vector2(2.2, 14.8),
				Vector2(-2.2, 14.8), Vector2(-3, 11.5), Vector2(-1.7, 11.5), Vector2(-1.7, 4.6), Vector2(-7, 4.6), Vector2(-7, 2), Vector2(-2.4, 2), Vector2(-2.4, -12.5)]]
			shine = [Vector2(-0.6, -12.5), Vector2(-0.6, 0.5)]
			trim = [Vector2(-5.6, 3.3), Vector2(5.6, 3.3)]
		"mace":
			rot = 0.7
			pieces = [
				[[Vector2(-1.6, -3), Vector2(1.6, -3), Vector2(1.6, 15), Vector2(-1.6, 15)], WOOD],
				[[Vector2(-5, -3.2), Vector2(-7.5, -8.5), Vector2(7.5, -8.5), Vector2(5, -3.2)], IRON],
				[[Vector2(-7.5, -8.5), Vector2(-4.5, -14), Vector2(4.5, -14), Vector2(7.5, -8.5)], IRON],
				[[Vector2(-2, -14), Vector2(0, -17.5), Vector2(2, -14)], IRON]]
			loops = [[Vector2(0, -17.5), Vector2(2, -14), Vector2(4.5, -14), Vector2(7.5, -8.5), Vector2(5, -3.2), Vector2(1.6, -3), Vector2(1.6, 15), Vector2(-1.6, 15),
				Vector2(-1.6, -3), Vector2(-5, -3.2), Vector2(-7.5, -8.5), Vector2(-4.5, -14), Vector2(-2, -14)]]
			shine = [Vector2(-3.4, -12.6), Vector2(-5.6, -8.6)]
			trim = [Vector2(-6.4, -8.5), Vector2(6.4, -8.5)]
		"scepter":
			rot = 0.6
			pieces = [
				[[Vector2(-1.4, -6), Vector2(1.4, -6), Vector2(1.4, 15), Vector2(-1.4, 15)], GOLD],
				[[Vector2(-3.4, -7.5), Vector2(3.4, -7.5), Vector2(2.2, -4.5), Vector2(-2.2, -4.5)], GOLD],
				[[Vector2(-2.6, 11.5), Vector2(2.6, 11.5), Vector2(2.6, 15), Vector2(-2.6, 15)], GOLD]]
			loops = [[Vector2(-3.4, -7.5), Vector2(3.4, -7.5), Vector2(2.2, -4.5), Vector2(1.4, -4.5), Vector2(1.4, 11.5), Vector2(2.6, 11.5), Vector2(2.6, 15), Vector2(-2.6, 15),
				Vector2(-2.6, 11.5), Vector2(-1.4, 11.5), Vector2(-1.4, -4.5), Vector2(-2.2, -4.5)]]
			gem = Vector3(0, -12.0, 4.6)
		"staff":
			rot = 0.45
			pieces = [
				[[Vector2(-1.3, -7.9), Vector2(1.3, -7.9), Vector2(1.3, 17), Vector2(-1.3, 17)], WOOD],
				[[Vector2(0, -18.5), Vector2(5, -12), Vector2(0, -6.5), Vector2(-5, -12)], WOOD]]
			loops = [[Vector2(0, -18.5), Vector2(5, -12), Vector2(1.3, -7.9), Vector2(1.3, 17), Vector2(-1.3, 17), Vector2(-1.3, -7.9), Vector2(-5, -12)]]
			trim = [Vector2(-1.3, 2.0), Vector2(1.3, 2.0), Vector2(-1.3, 4.5), Vector2(1.3, 4.5)]
			gem = Vector3(0, -12.0, 2.3)
		"wand":
			rot = 0.8
			pieces = [
				[[Vector2(-1.5, 8), Vector2(-0.9, -9), Vector2(0.9, -9), Vector2(1.5, 8)], WOOD],
				[[Vector2(-2.2, 8), Vector2(2.2, 8), Vector2(2.2, 13.5), Vector2(-2.2, 13.5)], HIDE]]
			loops = [[Vector2(-0.9, -9), Vector2(0.9, -9), Vector2(1.5, 8), Vector2(2.2, 8), Vector2(2.2, 13.5), Vector2(-2.2, 13.5), Vector2(-2.2, 8), Vector2(-1.5, 8)]]
			gem = Vector3(0, -11.0, 2.7)
		"helm":
			rot = -0.12
			pieces = [
				[[Vector2(-7.5, -7.5), Vector2(-3.5, -11.5), Vector2(3.5, -11.5), Vector2(7.5, -7.5)], STEEL],
				[[Vector2(-9.5, -1), Vector2(-7.5, -7.5), Vector2(7.5, -7.5), Vector2(9.5, -1)], STEEL],
				[[Vector2(-9.5, -1), Vector2(9.5, -1), Vector2(9, 6.5), Vector2(-9, 6.5)], STEEL],
				[[Vector2(-4.4, 0.8), Vector2(4.4, 0.8), Vector2(5.2, 6.5), Vector2(-5.2, 6.5)], HOLE],
				[[Vector2(-1.4, 0.8), Vector2(1.4, 0.8), Vector2(1.4, 5.2), Vector2(-1.4, 5.2)], STEEL]]
			loops = [[Vector2(-3.5, -11.5), Vector2(3.5, -11.5), Vector2(7.5, -7.5), Vector2(9.5, -1), Vector2(9, 6.5), Vector2(-9, 6.5), Vector2(-9.5, -1), Vector2(-7.5, -7.5)]]
			shine = [Vector2(-5.6, -8.0), Vector2(-3.0, -10.4)]
			trim = [Vector2(-8.6, -1.0), Vector2(8.6, -1.0), Vector2(0, -11.0), Vector2(0, -2.2)]
		"chest":
			pieces = [
				[[Vector2(-10.5, -10.5), Vector2(10.5, -10.5), Vector2(11, -4.5), Vector2(-11, -4.5)], STEEL],
				[[Vector2(-8, -4.5), Vector2(8, -4.5), Vector2(7, 5.5), Vector2(-7, 5.5)], STEEL],
				[[Vector2(-7, 5.5), Vector2(7, 5.5), Vector2(8.5, 10.5), Vector2(-8.5, 10.5)], LEATHER],
				[[Vector2(-3.2, -10.5), Vector2(3.2, -10.5), Vector2(0, -7.2)], HOLE]]
			loops = [[Vector2(-10.5, -10.5), Vector2(-3.2, -10.5), Vector2(0, -7.2), Vector2(3.2, -10.5), Vector2(10.5, -10.5), Vector2(11, -4.5), Vector2(8, -4.5), Vector2(7, 5.5),
				Vector2(8.5, 10.5), Vector2(-8.5, 10.5), Vector2(-7, 5.5), Vector2(-8, -4.5), Vector2(-11, -4.5)]]
			shine = [Vector2(0, -6.0), Vector2(0, 4.5)]
			trim = [Vector2(-6.6, 5.5), Vector2(6.6, 5.5)]
		"boots":
			pieces = [
				[[Vector2(-11.5, -13.5), Vector2(-5, -13.5), Vector2(-4.5, -3), Vector2(-12.1, -3)], HIDE],
				[[Vector2(-12.1, -3), Vector2(-4.5, -3), Vector2(-4.5, 4.5), Vector2(-11.9, 4.5)], HIDE],
				[[Vector2(-3.5, -10.5), Vector2(3.5, -10.5), Vector2(4, 0.5), Vector2(-4.4, 0.5)], LEATHER],
				[[Vector2(-4.4, 0.5), Vector2(4, 0.5), Vector2(4, 8.5), Vector2(-4, 8.5)], LEATHER],
				[[Vector2(4, 0.5), Vector2(11.5, 4.7), Vector2(12, 8.5), Vector2(4, 8.5)], LEATHER]]
			loops = [
				[Vector2(-11.5, -13.5), Vector2(-5, -13.5), Vector2(-4.5, -3), Vector2(-4.5, 4.5), Vector2(-11.9, 4.5), Vector2(-12.1, -3)],
				[Vector2(-3.5, -10.5), Vector2(3.5, -10.5), Vector2(4, 0.5), Vector2(11.5, 4.7), Vector2(12, 8.5), Vector2(-4, 8.5), Vector2(-4.4, 0.5)]]
			trim = [Vector2(-3.5, -8.0), Vector2(3.6, -8.0), Vector2(-11.5, -11.0), Vector2(-5.0, -11.0)]
		"ring":
			band = Rect2(-8.5, -6.5, 17, 17)
			gem = Vector3(0, -6.0, 3.2)
		"amulet":
			band = Rect2(-7.5, -15, 15, 17)
			pieces = [[[Vector2(0, 0.5), Vector2(5, 6.5), Vector2(0, 13.5), Vector2(-5, 6.5)], GOLD]]
			loops = [[Vector2(0, 0.5), Vector2(5, 6.5), Vector2(0, 13.5), Vector2(-5, 6.5)]]
			gem = Vector3(0, 6.8, 2.3)
		_:
			# a tied pouch, for anything without a look of its own
			pieces = [
				[[Vector2(-2.6, -10.5), Vector2(2.6, -10.5), Vector2(3.2, -5), Vector2(-3.2, -5)], LEATHER],
				[[Vector2(-7, -5), Vector2(7, -5), Vector2(9, 1), Vector2(-9, 1)], LEATHER],
				[[Vector2(-9, 1), Vector2(9, 1), Vector2(8, 9), Vector2(-8, 9)], LEATHER]]
			loops = [[Vector2(-2.6, -10.5), Vector2(2.6, -10.5), Vector2(3.2, -5), Vector2(7, -5), Vector2(9, 1), Vector2(8, 9), Vector2(-8, 9), Vector2(-9, 1), Vector2(-7, -5), Vector2(-3.2, -5)]]
			trim = [Vector2(-3.6, -5.6), Vector2(3.6, -5.6)]
	# shade every piece by height across the whole object, so it reads as one thing
	var y0 := INF
	var y1 := -INF
	for piece in pieces:
		for p in piece[0]:
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
	var quads: Array = []
	var cols: Array = []
	for piece in pieces:
		var pts := PackedVector2Array(piece[0])
		var mat: Array = piece[1]
		var top: Color = mat[0]
		var deep: Color = mat[1]
		var pc := PackedColorArray()
		for p in pts:
			pc.append(top.lerp(deep, (p.y - y0) / maxf(y1 - y0, 0.001)))
		quads.append(pts)
		cols.append(pc)
	var edge := PackedVector2Array()
	for loop in loops:
		var n: int = loop.size()
		for i in n:
			edge.append(loop[i])
			edge.append(loop[(i + 1) % n])
	var sh := {"quads": quads, "cols": cols, "edge": edge, "trim": PackedVector2Array(trim), "shine": PackedVector2Array(shine), "rot": rot, "gem": gem, "band": band}
	_shapes[icon] = sh
	return sh


## A round texture whose colour at each distance from the centre is given by `colors` at `offsets`.
static func _round_tex(offsets: Array, colors: Array) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
