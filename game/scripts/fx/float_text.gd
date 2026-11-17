class_name FloatText
extends Node2D
## Damage numbers.

var items: Array[Dictionary] = []


func add(p: Vector2, amount: float, c: Color, crit: bool) -> void:
	if items.size() > 90:
		items.pop_front()
	var txt := str(int(round(amount))) if amount >= 1.0 else "1"
	items.append({"pos": p, "vel": Vector2(randf_range(-30, 30), -110.0 if not crit else -150.0), "t": 0.0, "txt": txt, "c": c, "crit": crit})


func add_label(p: Vector2, txt: String, c: Color) -> void:
	items.append({"pos": p, "vel": Vector2(0, -150.0), "t": 0.0, "txt": txt, "c": c, "crit": false})


func update(dt: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var d := items[i]
		d.t += dt
		d.vel.y += 220.0 * dt
		d.pos += d.vel * dt
		if d.t > 0.9:
			items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var f := Game.font_display_bold
	for d in items:
		var t: float = d.t
		var size := 17 if not d.crit else 23
		var pop := 1.0 + maxf(0.0, 0.25 - t) * (2.4 if d.crit else 1.2)
		var c: Color = d.c
		c.a = clampf((0.9 - t) / 0.3, 0.0, 1.0)
		var fs := int(size * pop)
		var w := f.get_string_size(d.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = d.pos - Vector2(w * 0.5, 0)
		draw_string_outline(f, p, d.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, c.a * 0.8))
		draw_string(f, p, d.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
