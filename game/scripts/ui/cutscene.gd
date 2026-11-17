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


func play(id: String) -> void:
	var sc: Dictionary = SCENES[id]
	title = sc.title
	lines = sc.lines
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var cx := size.x * 0.5
	var bar := size.y * 0.12
	draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, fade))
	draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, fade))
	# Drifting embers
	for i in 40:
		var ph := fmod(Time.get_ticks_msec() / 1000.0 * 0.12 + i * 0.137, 1.0)
		var x := fmod(i * 197.0, size.x) + sin(ph * 6.0 + i) * 30.0
		var y := size.y - ph * size.y
		draw_circle(Vector2(x, y), 1.5 + (i % 3), Color(1.4, 0.6, 0.2, (1.0 - ph) * 0.6 * fade), true, -1.0, true)
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
