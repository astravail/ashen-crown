class_name Loot
extends Node2D
## Gold and gear lying on the ground. Gold is drawn to you; gear is picked up by walking over it.

var world: World
var item: Dictionary = {}
var gold := 0
var t := 0.0
var done := false
var label: Node2D
var glow: Node2D
var light: PointLight2D


func _ready() -> void:
	glow = Node2D.new()
	glow.material = World.unshaded_add
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
		elif d < p.radius + 30.0 and t > 0.5:
			if Game.add_item(item):
				Game.stat_add("found_r%d" % int(item.rarity), 1.0)
				Sfx.play("pickup", -4.0, 0.1, 0.8)
				world.texts.add_label(p.global_position + Vector2(0, -56), String(item.name), color())
				if int(item.rarity) >= 3:
					Sfx.play("levelup", -4.0)
					Voice.bark("player", "legendary", "Now that is something.")
				done = true
			elif world.full_warn <= 0.0:
				world.full_warn = 3.0
				world.texts.add_label(p.global_position + Vector2(0, -56), "Inventory full", Color(1.0, 0.4, 0.3))
	if t > (60.0 if gold > 0 else 300.0):
		done = true
	queue_redraw()
	glow.queue_redraw()
	label.queue_redraw()


func _bounce() -> float:
	return absf(sin(t * 7.0)) * 24.0 * pow(maxf(0.0, 1.0 - t / 0.9), 2.0)


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.4), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var y := -10.0 - _bounce()
	if gold > 0:
		var c := Color(0.95, 0.75, 0.2)
		draw_circle(Vector2(-3, y), 5.0, c, true, -1.0, true)
		draw_circle(Vector2(4, y - 2), 5.0, c.lightened(0.15), true, -1.0, true)
		draw_circle(Vector2(0, y + 2), 4.5, c.darkened(0.1), true, -1.0, true)
	else:
		Icons.item(self, String(item.icon), Vector2(0, y - 6), 28.0, color())


func _draw_glow() -> void:
	var y := -10.0 - _bounce()
	if gold > 0:
		glow.draw_circle(Vector2(0, y), 9.0, Color(1.6, 1.1, 0.25, 0.25), true, -1.0, true)
		return
	var c := color()
	var r := int(item.rarity)
	if r >= 1:
		glow.draw_circle(Vector2(0, y - 6), 14.0 + r * 3.0, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.18), true, -1.0, true)
	if r >= 2:
		var h := 70.0 + r * 25.0
		glow.draw_line(Vector2(0, 0), Vector2(0, -h), Color(c.r * 2.2, c.g * 2.2, c.b * 2.2, 0.5 + 0.2 * sin(t * 4.0)), 3.0 + r)


func _draw_label() -> void:
	if gold > 0:
		return
	var f := Game.font_body_bold
	var txt := String(item.name)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var p := Vector2(-w * 0.5, -48.0 - _bounce())
	var c := color()
	label.draw_rect(Rect2(p.x - 5, p.y - 14, w + 10, 19), Color(0, 0, 0, 0.55))
	label.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
