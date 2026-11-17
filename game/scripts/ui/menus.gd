class_name Menus
extends Control
## Every menu and overlay screen.

signal start_run(cls: String)
signal resume
signal abandon
signal levelup_chosen(id: String)
signal fragment_chosen(id: String)
signal respawn
signal ending_chosen(choice: String)
signal to_title

var current: Control
var _settings_back: Callable
var _keys: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	if current:
		current.queue_free()
		current = null
	_keys.clear()


func is_open() -> bool:
	return current != null


func _unhandled_input(event: InputEvent) -> void:
	if current == null or _keys.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < _keys.size():
			_keys[idx].emit_signal("pressed")
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- helpers

func _root(dim := 0.0) -> Control:
	clear()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.015, 0.015, dim)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(bg)
	current = c
	c.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(c, "modulate:a", 1.0, 0.25)
	return c


func _label(text: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable, min_w := 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 58)
	b.pressed.connect(func():
		Sfx.play("ui_select", -6.0, 0.0)
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0, 0.0))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


func _center_box(parent: Control, sep := 14) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v


func _rule(w := 320.0) -> Control:
	var r := Rule.new()
	r.custom_minimum_size = Vector2(w, 18)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


func _focus_first(node: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(node):
		node.grab_focus()


# ---------------------------------------------------------------- title

func show_title() -> void:
	var c := _root()
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	shade.colors = PackedColorArray([Color(0.02, 0.015, 0.015, 0.92), Color(0.02, 0.015, 0.015, 0.55), Color(0.02, 0.015, 0.015, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = shade
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 70)
	c.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(760, 300)
	v.add_child(logo)
	var tag := _label("Every king burns.", Game.font_italic, 30, Color(0.85, 0.72, 0.6))
	v.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	v.add_child(spacer)
	var first := _button("Begin", show_class_select)
	first.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(first)
	var s := _button("Settings", func(): show_settings(show_title))
	s.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(s)
	var q := _button("Quit", func(): get_tree().quit())
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
	for b in [first, s, q]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var rec := Game.records
	var foot := "v%s" % Game.VERSION
	if int(rec.runs) > 0:
		foot += "     Runs %d  ·  Victories %d" % [rec.runs, rec.wins]
	v.add_child(_label(foot, Game.font_body, 18, Color(0.5, 0.47, 0.44)))
	_focus_first(first)


# ---------------------------------------------------------------- class select

func show_class_select() -> void:
	var c := _root(0.72)
	var v := _center_box(c, 26)
	v.add_child(_label("CHOOSE A SURVIVOR", Game.font_display_bold, 40, Color(0.95, 0.86, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(420))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var first: Button
	for id in ["knight", "gravecaller", "pyrewitch"]:
		var card := _class_card(id)
		h.add_child(card)
		if first == null:
			first = card
	var back := _button("Back", show_title, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_focus_first(first)


func _card_style(border: Color, bg := Color(0.06, 0.05, 0.048, 0.96)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


func _card_button(w: float, h: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _card_style(Color(0.26, 0.22, 0.19)))
	b.add_theme_stylebox_override("hover", _card_style(Game.C_EMBER, Color(0.09, 0.065, 0.05, 0.97)))
	b.add_theme_stylebox_override("focus", _card_style(Game.C_EMBER, Color(0.09, 0.065, 0.05, 0.97)))
	b.add_theme_stylebox_override("pressed", _card_style(Game.C_EMBER_HOT, Color(0.14, 0.08, 0.05, 1.0)))
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0, 0.0))
	return b


func _class_card(id: String) -> Button:
	var d: Dictionary = Data.CLASSES[id]
	var b := _card_button(440, 690)
	b.pressed.connect(func():
		Sfx.play("ui_select", -4.0, 0.0)
		start_run.emit(id))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 30)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var port := Portrait.new()
	port.cls = id
	port.custom_minimum_size = Vector2(0, 200)
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(port)
	v.add_child(_label(String(d.name).to_upper(), Game.font_display_bold, 30, Color(0.97, 0.88, 0.76), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label(d.role, Game.font_display, 16, Color(0.85, 0.55, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	var blurb := _wrap(_label(d.blurb, Game.font_italic, 19, Color(0.72, 0.68, 0.64), HORIZONTAL_ALIGNMENT_CENTER))
	blurb.custom_minimum_size = Vector2(0, 76)
	v.add_child(blurb)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 4)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in d.ratings.keys():
		stats.add_child(_label(k, Game.font_body, 17, Color(0.68, 0.64, 0.6)))
		var pips := Pips.new()
		pips.value = d.ratings[k]
		pips.custom_minimum_size = Vector2(150, 20)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats.add_child(pips)
	var sc := CenterContainer.new()
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(stats)
	v.add_child(sc)
	v.add_child(_rule(300))
	for a in d.abilities:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := _label(Game.key_label(a.action), Game.font_display_bold, 13, Color(0.6, 0.55, 0.5))
		key.custom_minimum_size = Vector2(62, 0)
		row.add_child(key)
		row.add_child(_label(a.name, Game.font_body_bold, 18, Color(0.88, 0.82, 0.75) if a.action != "ultimate" else Color(1.0, 0.7, 0.4)))
		v.add_child(row)
	var res := _wrap(_label("%s. %s" % [d.resource, d.resource_hint], Game.font_body, 16, Color(0.6, 0.57, 0.54), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(res)
	return b


# ---------------------------------------------------------------- settings

func show_settings(back: Callable) -> void:
	_settings_back = back
	var c := _root(0.78)
	var v := _center_box(c, 16)
	v.add_child(_label("SETTINGS", Game.font_display_bold, 40, Color(0.95, 0.86, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(320))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	var first: Control
	for pair in [["Master volume", "master"], ["Music", "music"], ["Effects", "sfx"]]:
		grid.add_child(_label(pair[0], Game.font_body, 22, Game.C_TEXT))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Game.settings[pair[1]]
		s.custom_minimum_size = Vector2(340, 28)
		s.focus_mode = Control.FOCUS_ALL
		var key: String = pair[1]
		s.value_changed.connect(func(val: float):
			Game.settings[key] = val
			Game.apply_settings()
			Sfx.play("ui_move", -8.0, 0.0))
		grid.add_child(s)
		if first == null:
			first = s
	for pair in [["Fullscreen", "fullscreen"], ["Screen shake", "shake"], ["Damage numbers", "numbers"], ["Blood and gore", "gore"]]:
		grid.add_child(_label(pair[0], Game.font_body, 22, Game.C_TEXT))
		var cb := CheckButton.new()
		cb.button_pressed = Game.settings[pair[1]]
		var key2: String = pair[1]
		cb.toggled.connect(func(on: bool):
			Game.settings[key2] = on
			Game.apply_settings()
			Sfx.play("ui_move", -8.0, 0.0))
		grid.add_child(cb)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)
	var back_b := _button("Back", func():
		Game.save_settings()
		_settings_back.call(), 260)
	back_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back_b)
	_focus_first(first)


# ---------------------------------------------------------------- pause

func show_pause() -> void:
	var c := _root(0.7)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 120)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(cc)
	cc.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	h.add_child(v)
	v.add_child(_label("PAUSED", Game.font_display_bold, 44, Color(0.95, 0.86, 0.74)))
	v.add_child(_rule(260))
	var r := _button("Resume", func(): resume.emit())
	v.add_child(r)
	v.add_child(_button("Settings", func(): show_settings(show_pause)))
	v.add_child(_button("Abandon run", func(): abandon.emit()))
	# Controls reference
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 8)
	h.add_child(g)
	var pad := Game.using_gamepad
	var rows := [
		["Move", "Left stick" if pad else "W A S D"],
		["Aim", "Right stick" if pad else "Mouse"],
		["Abilities", "RT  LT  X  Y" if pad else "LMB  RMB  Q  E"],
		["Ultimate", "RB" if pad else "R"],
		["Dodge", "A" if pad else "Space"],
		["Flask", "LB" if pad else "F"],
		["Map", "Back" if pad else "Tab"],
	]
	for row in rows:
		g.add_child(_label(row[0], Game.font_body, 20, Color(0.65, 0.61, 0.57)))
		g.add_child(_label(row[1], Game.font_display_bold, 18, Color(0.9, 0.84, 0.76)))
	_focus_first(r)


# ---------------------------------------------------------------- level up

func show_levelup(level: int, choices: Array) -> void:
	var c := _root(0.66)
	var v := _center_box(c, 22)
	v.add_child(_label("LEVEL %d" % level, Game.font_display_bold, 46, Color(1.0, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(360))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var first: Button
	var n := 0
	for u in choices:
		n += 1
		var b := _card_button(360, 250)
		var id: String = u.id
		b.pressed.connect(func():
			Sfx.play("ui_select", -4.0, 0.0)
			levelup_chosen.emit(id))
		var m := _card_inner(b)
		m.add_child(_label(String(u.tag).to_upper(), Game.font_display, 15, Color(0.88, 0.55, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
		m.add_child(_label(u.name, Game.font_display_bold, 30, Color(0.97, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
		m.add_child(_rule(160))
		m.add_child(_wrap(_label(u.desc, Game.font_body, 21, Color(0.8, 0.76, 0.72), HORIZONTAL_ALIGNMENT_CENTER)))
		var st := ""
		if int(u.max) > 1:
			st = "Rank %d of %d" % [int(u.get("rank", 0)) + 1, u.max]
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(fill)
		m.add_child(_label(("%d    %s" % [n, st]) if not Game.using_gamepad else st, Game.font_body, 15, Color(0.5, 0.47, 0.44), HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(b)
		_keys.append(b)
		if first == null:
			first = b
	_focus_first(first)


func _card_inner(b: Button) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26 if side != "top" else 30)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v


# ---------------------------------------------------------------- crown fragments

func show_fragments(choices: Array) -> void:
	var c := _root(0.72)
	var v := _center_box(c, 22)
	v.add_child(_label("CROWN FRAGMENT", Game.font_display_bold, 46, Color(1.0, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("Take one. It will not let go.", Game.font_italic, 22, Color(0.75, 0.7, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(360))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var first: Button
	var n := 0
	for f in choices:
		n += 1
		var b := _card_button(380, 300)
		var id: String = f.id
		b.pressed.connect(func(): fragment_chosen.emit(id))
		var m := _card_inner(b)
		var icon := CrownIcon.new()
		icon.custom_minimum_size = Vector2(0, 56)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(icon)
		m.add_child(_wrap(_label(f.name, Game.font_display_bold, 25, Color(0.97, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)))
		m.add_child(_rule(160))
		m.add_child(_wrap(_label(f.boon, Game.font_body_bold, 20, Color(1.0, 0.7, 0.42), HORIZONTAL_ALIGNMENT_CENTER)))
		m.add_child(_wrap(_label(f.bane, Game.font_body, 20, Color(0.78, 0.45, 0.42), HORIZONTAL_ALIGNMENT_CENTER)))
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(fill)
		if not Game.using_gamepad:
			m.add_child(_label(str(n), Game.font_body, 15, Color(0.5, 0.47, 0.44), HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(b)
		_keys.append(b)
		if first == null:
			first = b
	_focus_first(first)


# ---------------------------------------------------------------- death / ending

func show_death(zone_name: String) -> void:
	var c := _root(0.75)
	var v := _center_box(c, 16)
	v.add_child(_label("YOU FELL", Game.font_display_bold, 64, Color(0.85, 0.3, 0.22), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label(zone_name, Game.font_italic, 24, Color(0.7, 0.66, 0.62), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(320))
	var r := _button("Rise again", func(): respawn.emit())
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var a := _button("Abandon run", func(): abandon.emit())
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(a)
	v.add_child(_label("You return to the zone entrance. Enemies remain where they stood.", Game.font_body, 17, Color(0.5, 0.47, 0.44), HORIZONTAL_ALIGNMENT_CENTER))
	_focus_first(r)


func show_ending_choice() -> void:
	var c := _root(0.8)
	var v := _center_box(c, 18)
	var icon := CrownIcon.new()
	icon.custom_minimum_size = Vector2(0, 120)
	icon.big = true
	v.add_child(icon)
	v.add_child(_label("The crown lies in the ash.", Game.font_italic, 34, Color(0.95, 0.85, 0.72), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("It is still warm.", Game.font_italic, 24, Color(0.7, 0.65, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(360))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var s := _button("Shatter it", func(): ending_chosen.emit("shatter"), 300)
	var w := _button("Wear it", func(): ending_chosen.emit("wear"), 300)
	h.add_child(s)
	h.add_child(w)
	_focus_first(s)


func show_ending(choice: String) -> void:
	var c := _root(0.92)
	var v := _center_box(c, 16)
	var title := "THE LAST EMBER" if choice == "shatter" else "THE NEW KING"
	var lines: Array[String] = []
	if choice == "shatter":
		lines = ["The crown breaks into a thousand cooling pieces.",
			"For the first time in years, the ash stops falling.",
			"Valdremor has no king. It has a chance."]
	else:
		lines = ["The metal is warm, and then it is not warm at all.",
			"The dead in the Cinderfields stand up and turn to face you.",
			"Every king burns. You will burn slower."]
	v.add_child(_label(title, Game.font_display_bold, 54, Color(1.0, 0.8, 0.55) if choice == "shatter" else Color(0.95, 0.4, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(400))
	for l in lines:
		v.add_child(_label(l, Game.font_italic, 26, Color(0.85, 0.8, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	v.add_child(sp)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 50)
	g.add_theme_constant_override("v_separation", 6)
	var st := Game.stats
	var cls_name: String = Data.CLASSES[Game.class_id].name
	for row in [["Class", cls_name], ["Time", Game.fmt_time(st.time)], ["Level", str(st.level)], ["Enemies slain", str(st.kills)], ["Elites slain", str(st.elites)], ["Fragments", str(Game.fragments.size())]]:
		g.add_child(_label(row[0], Game.font_body, 20, Color(0.6, 0.57, 0.54)))
		g.add_child(_label(row[1], Game.font_display_bold, 20, Color(0.92, 0.86, 0.78)))
	var gc := CenterContainer.new()
	gc.add_child(g)
	v.add_child(gc)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 20)
	v.add_child(sp2)
	var b := _button("Return to title", func(): to_title.emit())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_focus_first(b)


# ---------------------------------------------------------------- small drawn widgets

class Rule extends Control:
	func _draw() -> void:
		var y := size.y * 0.5
		var cx := size.x * 0.5
		draw_line(Vector2(0, y), Vector2(cx - 12, y), Color(0.55, 0.35, 0.2, 0.8), 1.0)
		draw_line(Vector2(cx + 12, y), Vector2(size.x, y), Color(0.55, 0.35, 0.2, 0.8), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 5), Vector2(cx + 5, y), Vector2(cx, y + 5), Vector2(cx - 5, y)]), Color(0.9, 0.5, 0.2))


class Pips extends Control:
	var value := 3
	func _draw() -> void:
		for i in 5:
			var r := Rect2(i * 28, 6, 22, 7)
			draw_rect(r, Color(0.85, 0.5, 0.22) if i < value else Color(0.2, 0.18, 0.17))


class CrownIcon extends Control:
	var big := false
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var s := 46.0 if not big else 110.0
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, s * 0.75, Color(1.0, 0.45, 0.1, 0.08 + 0.04 * sin(t * 2.0)), true, -1.0, true)
		Icons.crown(self, c, s, Color(1.0, 0.6, 0.25), Color(1.4, 0.9, 0.45))


class Logo extends Control:
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var f := Game.font_display_bold
		var c := Vector2(150, 92)
		draw_circle(c, 110, Color(1.0, 0.4, 0.1, 0.06 + 0.02 * sin(t * 1.5)), true, -1.0, true)
		Icons.crown(self, c, 170.0, Color(0.95, 0.55, 0.22), Color(1.6, 0.9, 0.4))
		for i in 6:
			var ph := fmod(t * 0.35 + i * 0.37, 1.0)
			var x := c.x - 70 + i * 28 + sin(t + i) * 6.0
			var y := c.y + 50 + ph * 90.0
			draw_circle(Vector2(x, y), 2.4 * (1.0 - ph), Color(1.4, 0.6, 0.2, 1.0 - ph), true, -1.0, true)
		var title := "ASHEN CROWN"
		var fs := 96
		var pos := Vector2(0, 268)
		draw_string_outline(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.6))
		draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.88, 0.8))
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_line(Vector2(0, pos.y + 22), Vector2(w, pos.y + 22), Color(0.85, 0.45, 0.18, 0.9), 2.0)


class Portrait extends Control:
	var cls := "knight"
	var fig: Player
	func _ready() -> void:
		fig = Player.new()
		fig.setup(cls)
		add_child(fig)
		fig.scale = Vector2(2.6, 2.6)
	func _process(dt: float) -> void:
		if fig == null:
			return
		fig.position = Vector2(size.x * 0.5, size.y - 18)
		fig.anim += dt
		fig.queue_redraw()
		fig.glow.queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 60)
		var col: Color = Data.CLASSES[cls].res_color
		draw_circle(c, 120, Color(col.r, col.g, col.b, 0.05), true, -1.0, true)
		draw_circle(c, 70, Color(col.r, col.g, col.b, 0.06), true, -1.0, true)
