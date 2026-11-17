class_name FpsCounter
extends Control
## Small frame-rate readout. Corner and visibility come from the settings.

var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(dt: float) -> void:
	_t += dt
	visible = bool(Game.settings.get("fps_show", false))
	if visible:
		queue_redraw()


func _draw() -> void:
	var fps := Engine.get_frames_per_second()
	var txt := "%d FPS" % fps
	var f := Game.font_display_bold
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var corner := int(Game.settings.get("fps_corner", 1))
	var x := 14.0 if corner in [0, 2] else size.x - w - 14.0
	var y := 26.0 if corner in [0, 1] else size.y - 14.0
	if corner == 2:
		y -= 22.0
	var col := Color(0.6, 1.0, 0.6) if fps >= 55 else (Color(1.0, 0.85, 0.4) if fps >= 30 else Color(1.0, 0.4, 0.3))
	draw_string_outline(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
