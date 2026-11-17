extends Node
## Global state: settings, input map, fonts, theme and the current run.

const VERSION := "1.0.0"
const SETTINGS_PATH := "user://settings.cfg"
const RECORD_PATH := "user://records.cfg"

const C_EMBER := Color(0.91, 0.45, 0.16)
const C_EMBER_HOT := Color(1.0, 0.7, 0.36)
const C_ASH := Color(0.62, 0.58, 0.55)
const C_BONE := Color(0.86, 0.82, 0.74)
const C_INK := Color(0.04, 0.035, 0.035)
const C_PANEL := Color(0.07, 0.06, 0.058, 0.94)
const C_TEXT := Color(0.88, 0.84, 0.78)
const C_DIM := Color(0.55, 0.52, 0.49)
const C_BANE := Color(0.72, 0.32, 0.3)

var font_display: FontFile
var font_display_bold: FontFile
var font_body: FontFile
var font_body_bold: FontFile
var font_italic: FontFile
var theme: Theme

var settings := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"shake": true,
	"numbers": true,
	"gore": true,
	"fullscreen": false,
}

var records := {"runs": 0, "wins": 0, "best_zone": 0, "fastest": 0.0}

# Current run
var class_id := "knight"
var zone_index := 0
var fragments: Array[String] = []
var stats := {}
var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()
	_build_theme()
	_setup_input()
	load_settings()
	_load_records()


func new_run(cls: String) -> void:
	class_id = cls
	zone_index = 0
	fragments.clear()
	stats = {"kills": 0, "time": 0.0, "damage_dealt": 0.0, "damage_taken": 0.0, "level": 1, "elites": 0}
	records.runs += 1
	save_records()


# ------------------------------------------------------------------ settings

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	Sfx.set_volumes(settings.master, settings.music, settings.sfx)
	if not DisplayServer.get_name().begins_with("headless"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		for k in records.keys():
			records[k] = cfg.get_value("records", k, records[k])


func save_records() -> void:
	var cfg := ConfigFile.new()
	for k in records.keys():
		cfg.set_value("records", k, records[k])
	cfg.save(RECORD_PATH)


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	var defs := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"skill_1": [KEY_Q],
		"skill_2": [KEY_E],
		"ultimate": [KEY_R],
		"dodge": [KEY_SPACE],
		"flask": [KEY_F],
		"pause": [KEY_ESCAPE],
		"map": [KEY_TAB],
	}
	for action in defs.keys():
		_ensure(action)
		for key in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	_mouse("attack_1", MOUSE_BUTTON_LEFT)
	_mouse("attack_2", MOUSE_BUTTON_RIGHT)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("attack_1", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("attack_2", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("skill_1", JOY_BUTTON_X)
	_button("skill_2", JOY_BUTTON_Y)
	_button("ultimate", JOY_BUTTON_RIGHT_SHOULDER)
	_button("dodge", JOY_BUTTON_A)
	_button("flask", JOY_BUTTON_LEFT_SHOULDER)
	_button("pause", JOY_BUTTON_START)
	_button("map", JOY_BUTTON_BACK)
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, 0.25)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		if not using_gamepad:
			using_gamepad = true
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		if using_gamepad:
			using_gamepad = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func key_label(action: String) -> String:
	if using_gamepad:
		match action:
			"attack_1": return "RT"
			"attack_2": return "LT"
			"skill_1": return "X"
			"skill_2": return "Y"
			"ultimate": return "RB"
			"dodge": return "A"
			"flask": return "LB"
		return ""
	match action:
		"attack_1": return "LMB"
		"attack_2": return "RMB"
		"skill_1": return "Q"
		"skill_2": return "E"
		"ultimate": return "R"
		"dodge": return "SPACE"
		"flask": return "F"
	return ""


# ------------------------------------------------------------------ look

func _load_fonts() -> void:
	font_display = load("res://assets/fonts/cinzel-latin-500-normal.woff2")
	font_display_bold = load("res://assets/fonts/cinzel-latin-700-normal.woff2")
	font_body = load("res://assets/fonts/spectral-latin-400-normal.woff2")
	font_body_bold = load("res://assets/fonts/spectral-latin-600-normal.woff2")
	font_italic = load("res://assets/fonts/spectral-latin-400-italic.woff2")


func _box(bg: Color, border: Color, bw := 1, radius := 2, pad := 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad * 1.6
	sb.content_margin_right = pad * 1.6
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	sb.anti_aliasing = true
	return sb


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", C_TEXT)

	theme.set_font("font", "Button", font_display)
	theme.set_font_size("font_size", "Button", 24)
	theme.set_color("font_color", "Button", C_TEXT)
	theme.set_color("font_hover_color", "Button", C_EMBER_HOT)
	theme.set_color("font_focus_color", "Button", C_EMBER_HOT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.38, 0.36))
	theme.set_stylebox("normal", "Button", _box(Color(0.08, 0.07, 0.065, 0.85), Color(0.3, 0.26, 0.23, 0.9)))
	theme.set_stylebox("hover", "Button", _box(Color(0.14, 0.09, 0.06, 0.95), C_EMBER))
	theme.set_stylebox("focus", "Button", _box(Color(0.14, 0.09, 0.06, 0.95), C_EMBER))
	theme.set_stylebox("pressed", "Button", _box(Color(0.24, 0.12, 0.05, 1.0), C_EMBER_HOT))
	theme.set_stylebox("disabled", "Button", _box(Color(0.06, 0.055, 0.05, 0.7), Color(0.2, 0.18, 0.17)))

	theme.set_stylebox("panel", "PanelContainer", _box(C_PANEL, Color(0.27, 0.23, 0.2), 1, 2, 22))
	theme.set_stylebox("panel", "Panel", _box(C_PANEL, Color(0.27, 0.23, 0.2), 1, 2, 22))

	var grab := StyleBoxFlat.new()
	grab.bg_color = C_EMBER
	grab.set_corner_radius_all(2)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.14, 0.13)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.26, 0.1)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	fill.set_corner_radius_all(2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _knob(Color(0.95, 0.85, 0.72))
	var knob_hot := _knob(C_EMBER_HOT)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", knob_hot)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = C_EMBER
	focus.set_border_width_all(1)
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	theme.set_stylebox("focus", "HSlider", focus)

	theme.set_font("font", "CheckButton", font_body)
	theme.set_color("font_color", "CheckButton", C_TEXT)
	theme.set_color("font_hover_color", "CheckButton", C_EMBER_HOT)
	theme.set_color("font_focus_color", "CheckButton", C_EMBER_HOT)
	theme.set_stylebox("focus", "CheckButton", focus)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(s, "CheckButton", empty)


func _knob(c: Color) -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			var a := clampf(8.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
