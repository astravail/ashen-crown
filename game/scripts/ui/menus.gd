class_name Menus
extends Control
## Every menu and overlay screen.

signal start_run(cls: String)
signal load_character(id: String)
signal difficulty_picked
signal resume
signal abandon
signal levelup_chosen(id: String)
signal fragment_chosen(id: String)
signal respawn
signal ending_chosen(choice: String)
signal to_title

var current: Control
var tutorial: Tutorial
var _settings_back: Callable
var _keys: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.015, 0.015, dim)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


func _button(text: String, cb: Callable, min_w := 360.0, min_h := 58.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.pressed.connect(func():
		Sfx.play("ui_select", -6.0, 0.0)
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0, 0.0))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


func _center_box(parent: Control, sep := 14) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var tag := _label("Nothing stays buried.", Game.font_italic, 30, Color(0.85, 0.72, 0.6))
	v.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	v.add_child(spacer)
	var first := _button("Play", show_characters)
	first.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(first)
	var s := _button("Settings", func(): show_settings(show_title))
	s.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(s)
	var stats_b := _button("Statistics", show_statistics)
	stats_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(stats_b)
	var hall := _button("Hall of the Fallen", show_fallen)
	hall.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(hall)
	var online := _button("Online  ·  coming soon", func(): pass)
	online.disabled = true
	online.alignment = HORIZONTAL_ALIGNMENT_LEFT
	online.tooltip_text = "Co-op and a shared world are planned. Not in this build."
	v.add_child(online)
	var q := _button("Quit", func(): get_tree().quit())
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
	for b in [first, s, stats_b, hall, online, q]:
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
	for id in ["knight", "gravecaller", "pyrewitch", "crownbearer"]:
		var card := _class_card(id)
		h.add_child(card)
		if first == null:
			first = card
	var back := _button("Back", show_title, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_focus_first(first)


func _show_locked_class(id: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Ornate.box("panel"))
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	v.add_child(_label(String(Data.CLASSES[id].name).to_upper() + "  ·  LOCKED", Game.font_display_bold, 30, Game.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var t := _wrap(_label(Data.CLASSES[id].unlock_hint, Game.font_body, 21, Color(0.85, 0.8, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	t.custom_minimum_size = Vector2(560, 0)
	v.add_child(t)
	var ok := _button("Understood", func(): dim.queue_free(), 220)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	ok.grab_focus()


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
	b.add_theme_stylebox_override("normal", Ornate.box("card"))
	b.add_theme_stylebox_override("hover", Ornate.box("card_hot"))
	b.add_theme_stylebox_override("focus", Ornate.box("card_hot"))
	b.add_theme_stylebox_override("pressed", Ornate.box("card_press"))
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0, 0.0))
	return b


func _class_card(id: String) -> Button:
	var d: Dictionary = Data.CLASSES[id]
	var b := _card_button(400, 690)
	var locked := not Game.class_unlocked(id)
	b.pressed.connect(func():
		if locked:
			Sfx.play("ui_move", -4.0, 0.0)
			_show_locked_class(id)
			return
		Sfx.play("ui_select", -4.0, 0.0)
		show_customize(id))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	v.add_child(_label(d.role, Game.font_display, 16, Game.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
		row.add_child(_label(a.name, Game.font_body_bold, 18, Color(0.88, 0.82, 0.75) if a.action != "ultimate" else Game.C_GOLD))
		v.add_child(row)
	if locked:
		b.modulate = Color(0.55, 0.55, 0.6)
		v.add_child(_label("LOCKED", Game.font_display_bold, 20, Color(1.0, 0.55, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	var res := _wrap(_label("%s. %s" % [d.resource, d.resource_hint], Game.font_body, 16, Color(0.6, 0.57, 0.54), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(res)
	return b


# ---------------------------------------------------------------- character

func show_customize(cls: String) -> void:
	var c := _root(0.78)
	var v := _center_box(c, 16)
	v.add_child(_label("YOUR SURVIVOR", Game.font_display_bold, 40, Color(0.95, 0.86, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(420))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var port := Portrait.new()
	port.cls = cls
	port.custom_minimum_size = Vector2(300, 330)
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(port)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 14)
	row.add_child(form)
	form.add_child(_label(String(Data.CLASSES[cls].name).to_upper() + "  ·  " + Data.CLASSES[cls].role, Game.font_display, 18, Game.C_GOLD))
	form.add_child(_label("Name", Game.font_body, 20, Color(0.65, 0.61, 0.57)))
	var name_edit := LineEdit.new()
	name_edit.text = Game.hero_name if Game.hero_name != "Nameless" else ""
	name_edit.placeholder_text = "Nameless"
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(420, 48)
	name_edit.add_theme_font_size_override("font_size", 24)
	form.add_child(name_edit)
	var pick := func(label: String, key: String, names: Array) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		form.add_child(h)
		var lab := _label(label, Game.font_body, 20, Color(0.65, 0.61, 0.57))
		lab.custom_minimum_size = Vector2(110, 0)
		h.add_child(lab)
		var val := _label("", Game.font_body_bold, 20, Color(0.95, 0.88, 0.78))
		val.custom_minimum_size = Vector2(160, 0)
		var upd := func(): val.text = String(names[int(Game.look[key])])
		upd.call()
		h.add_child(_button("◀", func():
			Game.look[key] = (int(Game.look[key]) + names.size() - 1) % names.size()
			upd.call(), 46.0, 38.0))
		h.add_child(val)
		h.add_child(_button("▶", func():
			Game.look[key] = (int(Game.look[key]) + 1) % names.size()
			upd.call(), 46.0, 38.0))
	pick.call("Colours", "accent", Game.ACCENT_NAMES)
	pick.call("Skin", "skin", ["Fair", "Warm", "Brown", "Deep", "Ashen"])
	pick.call("Hair", "hair", ["Black", "Brown", "Grey", "Raven", "Red"])
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	form.add_child(dh)
	var dl := _label("Difficulty", Game.font_body, 20, Color(0.65, 0.61, 0.57))
	dl.custom_minimum_size = Vector2(110, 0)
	dh.add_child(dl)
	var dval := _label("", Game.font_display_bold, 20, Game.C_GOLD)
	dval.custom_minimum_size = Vector2(250, 0)
	var dupd := func(): dval.text = "%d / %d  %s" % [Game.difficulty + 1, Game.DIFFICULTIES.size(), Game.diff().name]
	dupd.call()
	dh.add_child(_button("◀", func():
		Game.difficulty = maxi(0, Game.difficulty - 1)
		dupd.call(), 46.0, 38.0))
	dh.add_child(dval)
	dh.add_child(_button("▶", func():
		Game.difficulty = mini(Game.DIFFICULTIES.size() - 1, Game.difficulty + 1)
		dupd.call(), 46.0, 38.0))
	var hch := HBoxContainer.new()
	hch.add_theme_constant_override("separation", 12)
	form.add_child(hch)
	var hl := _label("Hardcore", Game.font_body, 20, Color(0.9, 0.4, 0.3))
	hl.custom_minimum_size = Vector2(110, 0)
	hch.add_child(hl)
	var hcb := CheckButton.new()
	hcb.button_pressed = Game.hardcore
	hcb.toggled.connect(func(on: bool): Game.hardcore = on)
	hch.add_child(hcb)
	hch.add_child(_label("One life. +25% xp, +20% gold, +20 magic find. Death deletes the character.", Game.font_body, 16, Color(0.8, 0.5, 0.4)))
	form.add_child(_wrap(_label("Higher difficulty means tougher enemies and better xp, gold and loot. You can change it later in the village, one step at a time.", Game.font_italic, 16, Color(0.6, 0.56, 0.52))))
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 16)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	bh.add_child(_button("Back", show_class_select, 220))
	var go := _button("Begin", func():
		Game.hero_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Nameless"
		start_run.emit(cls), 300)
	bh.add_child(go)
	_focus_first(go)


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
	_settings_extra(grid)
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
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(cc)
	cc.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	h.add_child(v)
	v.add_child(_label("PAUSED", Game.font_display_bold, 44, Color(0.95, 0.86, 0.74)))
	v.add_child(_rule(260))
	v.add_child(_label("%s  ·  %s" % [Game.hero_name, Game.diff().name], Game.font_italic, 20, Color(0.75, 0.62, 0.5)))
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
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		draw_circle(c, 130, Color(0.8, 0.08, 0.04, 0.10 + 0.03 * sin(t * 1.5)), true, -1.0, true)
		draw_circle(c, 80, Color(1.0, 0.3, 0.08, 0.08 + 0.03 * sin(t * 2.1)), true, -1.0, true)
		Icons.crown(self, c, 170.0, Color(0.88, 0.7, 0.36), Color(1.8, 0.35, 0.12))
		for i in 6:
			var ph := fmod(t * 0.35 + i * 0.37, 1.0)
			var x := c.x - 70 + i * 28 + sin(t + i) * 6.0
			var y := c.y + 50 + ph * 90.0
			draw_circle(Vector2(x, y), 2.4 * (1.0 - ph), Color(1.4, 0.6, 0.2, 1.0 - ph), true, -1.0, true)
		var title := "ASHEN CROWN"
		var fs := 96
		var pos := Vector2(0, 268)
		draw_string_outline(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0, 0, 0, 0.85))
		draw_string(f, pos + Vector2(3, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.5, 0.04, 0.03))
		draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.93, 0.78, 0.46))
		draw_string(f, pos + Vector2(0, -2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.95, 0.75, 0.25))
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_line(Vector2(0, pos.y + 22), Vector2(w, pos.y + 22), Color(0.72, 0.1, 0.07, 0.95), 3.0)
		draw_line(Vector2(0, pos.y + 27), Vector2(w, pos.y + 27), Color(0.8, 0.62, 0.3, 0.8), 1.0)
		draw_circle(Vector2(w * 0.5, pos.y + 24), 5.0, Color(0.88, 0.7, 0.36))


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


## Graphics, performance, voice and difficulty. Meant to let weak and strong PCs both run the game.
func _settings_extra(grid: GridContainer) -> void:
	var opt := func(label: String, items: Array, current: int, cb: Callable) -> OptionButton:
		grid.add_child(_label(label, Game.font_body, 22, Game.C_TEXT))
		var ob := OptionButton.new()
		for i in items.size():
			ob.add_item(String(items[i]), i)
		ob.select(current)
		ob.custom_minimum_size = Vector2(220, 36)
		ob.item_selected.connect(func(i: int):
			cb.call(i)
			Sfx.play("ui_move", -8.0, 0.0))
		grid.add_child(ob)
		return ob
	opt.call("Graphics quality", Game.QUALITY_NAMES, int(Game.settings.quality), func(i: int): Game.apply_preset(i))
	opt.call("Anti-aliasing", ["Off", "2x", "4x", "8x"], int(Game.settings.msaa), func(i: int):
		Game.settings.msaa = i
		Game.apply_settings())
	opt.call("Frame limit", ["Unlimited", "30", "60", "120", "144"], maxi(0, [0, 30, 60, 120, 144].find(int(Game.settings.fps_cap))), func(i: int):
		Game.settings.fps_cap = [0, 30, 60, 120, 144][i]
		Game.apply_settings())
	for pair in [["Glow", "glow"], ["VSync", "vsync"], ["Show FPS", "fps_show"], ["Voice lines", "voice"], ["Subtitles", "subtitles"], ["Tutorial tips", "tutorials"]]:
		grid.add_child(_label(pair[0], Game.font_body, 22, Game.C_TEXT))
		var cb := CheckButton.new()
		cb.button_pressed = bool(Game.settings[pair[1]])
		var key: String = pair[1]
		cb.toggled.connect(func(on: bool):
			Game.settings[key] = on
			Game.apply_settings()
			Sfx.play("ui_move", -8.0, 0.0))
		grid.add_child(cb)
	grid.add_child(_label("Tutorials seen", Game.font_body, 22, Game.C_TEXT))
	var rb := _button("Show all tips again", func():
		if tutorial:
			tutorial.reset_seen()
		Game.settings.tutorials = true
		Sfx.play("ui_move", -8.0, 0.0), 220.0, 36.0)
	grid.add_child(rb)
	opt.call("FPS counter corner", ["Top left", "Top right", "Bottom left", "Bottom right"], int(Game.settings.fps_corner), func(i: int):
		Game.settings.fps_corner = i)
	if Game.in_run:
		grid.add_child(_label("Difficulty", Game.font_body, 22, Game.C_TEXT))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		grid.add_child(h)
		var val := _label("", Game.font_display_bold, 20, Game.C_GOLD)
		val.custom_minimum_size = Vector2(210, 0)
		var upd := func(): val.text = "%d / %d  %s" % [Game.difficulty + 1, Game.DIFFICULTIES.size(), Game.diff().name]
		upd.call()
		var down := _button("◀", func(): _step_difficulty(-1, val, upd), 46.0, 36.0)
		var up := _button("▶", func(): _step_difficulty(1, val, upd), 46.0, 36.0)
		h.add_child(down)
		h.add_child(val)
		h.add_child(up)


func _step_difficulty(step: int, val: Label, upd: Callable) -> void:
	if Game.change_difficulty(step):
		difficulty_picked.emit()
		upd.call()
	else:
		val.text = "Wait %ds" % ceili(Game.diff_cd)


func show_permadeath(zone_name: String) -> void:
	var c := _root(0.92)
	var v := _center_box(c, 16)
	v.add_child(_label("YOU HAVE FALLEN", Game.font_display_bold, 64, Color(0.85, 0.3, 0.22), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("%s is gone. Hardcore does not forgive." % Game.hero_name, Game.font_italic, 26, Color(0.85, 0.8, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("Slain by %s" % Game.last_killer, Game.font_display, 22, Color(0.85, 0.5, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label(zone_name, Game.font_italic, 22, Color(0.65, 0.6, 0.56), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(420))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 50)
	g.add_theme_constant_override("v_separation", 6)
	var st := Game.stats
	for row in [["Class", Data.CLASSES[Game.class_id].name], ["Level", str(st.level)], ["Enemies slain", str(st.kills)], ["Time", Game.fmt_time(st.time)], ["Difficulty", Game.diff().name]]:
		g.add_child(_label(row[0], Game.font_body, 20, Color(0.6, 0.57, 0.54)))
		g.add_child(_label(str(row[1]), Game.font_display_bold, 20, Color(0.92, 0.86, 0.78)))
	var gc := CenterContainer.new()
	gc.add_child(g)
	v.add_child(gc)
	var b := _button("Return to title", func(): to_title.emit())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_focus_first(b)


# ---------------------------------------------------------------- saved characters

var _delete_arm := ""


func show_characters() -> void:
	var saves: Array = Game.list_characters()
	if saves.is_empty():
		show_class_select()
		return
	var c := _root(0.78)
	var v := _center_box(c, 14)
	v.add_child(_label("CHOOSE A CHARACTER", Game.font_display_bold, 40, Color(0.95, 0.86, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(420))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 480)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var first: Button
	for s in saves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var cls_name: String = Data.CLASSES[s.cls].name
		var tag := "  ·  HARDCORE" if s.hardcore else ""
		var txt := "%s\n%s  ·  Level %d  ·  %s%s" % [s.name, cls_name, s.level, Game.DIFF_NAMES[clampi(int(s.difficulty), 0, 19)], tag]
		var id: String = s.id
		var b := _button(txt, func():
			load_character.emit(id), 640, 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if s.hardcore:
			b.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
		row.add_child(b)
		var d := _button("Delete" if _delete_arm != id else "Sure?", func():
			if _delete_arm == id:
				Game.delete_character(id)
				_delete_arm = ""
			else:
				_delete_arm = id
			show_characters(), 160, 76)
		row.add_child(d)
		if first == null:
			first = b
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 16)
	v.add_child(bh)
	bh.add_child(_button("New character", show_class_select, 300))
	bh.add_child(_button("Back", show_title, 220))
	_focus_first(first)


func show_fallen() -> void:
	var c := _root(0.82)
	var v := _center_box(c, 14)
	v.add_child(_label("HALL OF THE FALLEN", Game.font_display_bold, 40, Color(0.85, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("Hardcore heroes who did not come back.", Game.font_italic, 20, Color(0.7, 0.65, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(420))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	var fallen: Array = Game.fallen_list()
	if fallen.is_empty():
		list.add_child(_label("No one has fallen yet.", Game.font_italic, 22, Color(0.6, 0.56, 0.52)))
	for f in fallen:
		var d := Time.get_datetime_dict_from_unix_time(int(f.date))
		list.add_child(_label("%s  ·  %s, level %d" % [f.name, Data.CLASSES[f.cls].name, int(f.level)], Game.font_display_bold, 22, Color(0.95, 0.85, 0.75)))
		list.add_child(_label("Slain by %s in %s  ·  %d kills  ·  %s  ·  %04d-%02d-%02d" % [f.killer, f.zone, int(f.kills), Game.fmt_time(float(f.time)), d.year, d.month, d.day], Game.font_body, 17, Color(0.65, 0.6, 0.56)))
	var back := _button("Back", show_title, 240)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_focus_first(back)


# ---------------------------------------------------------------- statistics

var _stat_tab := 0


class BarChart extends Control:
	var rows: Array = []  # [label, value, color]
	var title := ""
	var unit := ""

	func _draw() -> void:
		var f := Game.font_body
		draw_string(Game.font_display, Vector2(0, 16), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.56, 0.52))
		var top := 0.0
		for r in rows:
			top = maxf(top, float(r[1]))
		if top <= 0.0:
			draw_string(f, Vector2(0, 48), "No data yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.47, 0.44))
			return
		var y := 30.0
		var label_w := 150.0
		for r in rows:
			var k := float(r[1]) / top
			draw_string(f, Vector2(0, y + 15), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, label_w - 8.0, 15, Color(0.78, 0.74, 0.7))
			draw_rect(Rect2(label_w, y + 2, size.x - label_w - 90.0, 14), Color(0.12, 0.1, 0.09))
			draw_rect(Rect2(label_w, y + 2, (size.x - label_w - 90.0) * k, 14), r[2])
			draw_string(f, Vector2(size.x - 84.0, y + 15), "%s%s" % [_fmt(float(r[1])), unit], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.86, 0.78))
			y += 24.0

	static func _fmt(v: float) -> String:
		if v >= 1000000.0:
			return "%.1fM" % (v / 1000000.0)
		if v >= 10000.0:
			return "%.1fk" % (v / 1000.0)
		return "%d" % int(v)


func _chart(title: String, rows: Array, h: float, unit := "") -> BarChart:
	var c := BarChart.new()
	c.title = title
	c.rows = rows
	c.unit = unit
	c.custom_minimum_size = Vector2(420, h)
	return c


func _stat_grid(rows: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", 5)
	g.add_child(_label("", Game.font_body, 16, Color.WHITE))
	g.add_child(_label("THIS CHARACTER", Game.font_display, 13, Color(0.6, 0.56, 0.52), HORIZONTAL_ALIGNMENT_RIGHT))
	g.add_child(_label("LIFETIME", Game.font_display, 13, Color(0.6, 0.56, 0.52), HORIZONTAL_ALIGNMENT_RIGHT))
	for r in rows:
		g.add_child(_label(r[0], Game.font_body, 18, Color(0.72, 0.68, 0.64)))
		var a := _label(r[1], Game.font_body_bold, 18, Color(0.92, 0.86, 0.78), HORIZONTAL_ALIGNMENT_RIGHT)
		a.custom_minimum_size = Vector2(150, 0)
		g.add_child(a)
		var b := _label(r[2], Game.font_body_bold, 18, Color(1.0, 0.8, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
		b.custom_minimum_size = Vector2(150, 0)
		g.add_child(b)
	return g


func _n(d: Dictionary, k: String) -> float:
	return float(d.get(k, 0.0))


func _fmt_n(v: float) -> String:
	return BarChart._fmt(v)


func _fmt_dur(sec: float) -> String:
	var s := int(sec)
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]


func show_statistics() -> void:
	var life: Dictionary = Game._life()
	var run: Dictionary = Game.stats if Game.in_run else {}
	var c := _root(0.86)
	var v := _center_box(c, 12)
	v.add_child(_label("STATISTICS", Game.font_display_bold, 40, Color(0.95, 0.86, 0.74), HORIZONTAL_ALIGNMENT_CENTER))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	var names := ["Overview", "Combat", "Loot", "World"]
	for i in names.size():
		var idx := i
		var b := _button(names[i], func():
			_stat_tab = idx
			show_statistics(), 190, 42)
		if i == _stat_tab:
			b.add_theme_color_override("font_color", Game.C_EMBER_HOT)
		tabs.add_child(b)
	v.add_child(_rule(520))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 50)
	v.add_child(body)
	var rec := Game.records
	var pt_l := maxf(1.0, _n(life, "playtime"))
	match _stat_tab:
		0:
			var left := VBoxContainer.new()
			left.add_child(_stat_grid([
				["Time played", _fmt_dur(_n(run, "playtime")), _fmt_dur(_n(life, "playtime"))],
				["Enemies slain", _fmt_n(_n(run, "kills")), _fmt_n(_n(life, "kills"))],
				["Elites slain", _fmt_n(_n(run, "elites")), _fmt_n(_n(life, "elites"))],
				["Champions slain", _fmt_n(_n(run, "champions")), _fmt_n(_n(life, "champions"))],
				["Bosses slain", _fmt_n(_n(run, "bosses")), _fmt_n(_n(life, "bosses"))],
				["Gold earned", _fmt_n(_n(run, "gold_earned")), _fmt_n(_n(life, "gold_earned"))],
				["Distance walked", "%s m" % _fmt_n(_n(run, "distance") * 1.6), "%s m" % _fmt_n(_n(life, "distance") * 1.6)],
				["Deaths", _fmt_n(_n(run, "deaths")), _fmt_n(_n(life, "deaths"))],
				["Quests completed", _fmt_n(_n(run, "quests")), _fmt_n(_n(life, "quests"))],
			]))
			body.add_child(left)
			var right := VBoxContainer.new()
			right.add_theme_constant_override("separation", 10)
			right.add_child(_label("CAREER", Game.font_display, 13, Color(0.6, 0.56, 0.52)))
			for row in [["Characters created", str(int(rec.runs))], ["Victories", str(int(rec.wins))], ["Fallen heroes", str(int(rec.fallen))], ["Deepest zone", str(int(rec.best_zone))], ["Best hardcore level", str(int(rec.fallen_best_level))]]:
				var h := HBoxContainer.new()
				h.add_child(_label(row[0], Game.font_body, 18, Color(0.72, 0.68, 0.64)))
				var f := Control.new()
				f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				f.custom_minimum_size = Vector2(40, 0)
				h.add_child(f)
				h.add_child(_label(row[1], Game.font_body_bold, 18, Color(1.0, 0.8, 0.5)))
				right.add_child(h)
			var cls_rows: Array = []
			var pc: Dictionary = life.get("playtime_class", {})
			for cid in ["knight", "gravecaller", "pyrewitch", "crownbearer"]:
				cls_rows.append([Data.CLASSES[cid].name, _n(pc, cid) / 60.0, Game.C_GOLD])
			right.add_child(_chart("Time per class", cls_rows, 110, " min"))
			body.add_child(right)
		1:
			var left2 := VBoxContainer.new()
			var dealt_l := _n(life, "damage_dealt")
			left2.add_child(_stat_grid([
				["Damage dealt", _fmt_n(_n(run, "damage_dealt")), _fmt_n(dealt_l)],
				["Damage per second", "%d" % int(_n(run, "damage_dealt") / maxf(1.0, _n(run, "playtime"))), "%d" % int(dealt_l / pt_l)],
				["Biggest hit", "—", _fmt_n(_n(life, "biggest_hit"))],
				["Critical hits", _fmt_n(_n(run, "crits")), _fmt_n(_n(life, "crits"))],
				["Damage taken", _fmt_n(_n(run, "damage_taken")), _fmt_n(_n(life, "damage_taken"))],
				["Kills per hour", "%d" % int(_n(run, "kills") / maxf(0.01, _n(run, "playtime") / 3600.0)), "%d" % int(_n(life, "kills") / maxf(0.01, pt_l / 3600.0))],
				["Elites per hundred kills", "%.1f" % (100.0 * _n(run, "elites") / maxf(1.0, _n(run, "kills"))), "%.1f" % (100.0 * _n(life, "elites") / maxf(1.0, _n(life, "kills")))],
			]))
			body.add_child(left2)
			var kinds: Dictionary = life.get("kinds", {})
			var krows: Array = []
			var keys := kinds.keys()
			keys.sort_custom(func(a, b): return kinds[a] > kinds[b])
			for k in keys.slice(0, 8):
				var nm := String(k)
				if Data.VARIANTS.has(nm):
					nm = Data.VARIANTS[nm].name
				elif Data.ENEMIES.has(nm):
					nm = Data.ENEMIES[nm].name
				krows.append([nm, kinds[k], Color(0.75, 0.3, 0.22)])
			body.add_child(_chart("Most slain", krows, 260))
		2:
			var left3 := VBoxContainer.new()
			var total_l := 0.0
			for r in 4:
				total_l += _n(life, "items_r%d" % r)
			left3.add_child(_stat_grid([
				["Items found", _fmt_n(_n(run, "items_r0") + _n(run, "items_r1") + _n(run, "items_r2") + _n(run, "items_r3")), _fmt_n(total_l)],
				["Magic or better", _fmt_n(_n(run, "items_r1") + _n(run, "items_r2") + _n(run, "items_r3")), _fmt_n(_n(life, "items_r1") + _n(life, "items_r2") + _n(life, "items_r3"))],
				["Chests opened", _fmt_n(_n(run, "chests")), _fmt_n(_n(life, "chests"))],
				["Gold earned", _fmt_n(_n(run, "gold_earned")), _fmt_n(_n(life, "gold_earned"))],
				["Gold per hour", _fmt_n(_n(run, "gold_earned") / maxf(0.01, _n(run, "playtime") / 3600.0)), _fmt_n(_n(life, "gold_earned") / maxf(0.01, pt_l / 3600.0))],
			]))
			body.add_child(left3)
			# Per type of item: how many were found lying in the world, and how many came to you in total
			# (found, quest rewards and purchases).
			var tg := GridContainer.new()
			tg.columns = 5
			tg.add_theme_constant_override("h_separation", 26)
			tg.add_theme_constant_override("v_separation", 6)
			for hd in ["", "FOUND\nTHIS CHARACTER", "FOUND\nLIFETIME", "RECEIVED\nTHIS CHARACTER", "RECEIVED\nLIFETIME"]:
				tg.add_child(_label(hd, Game.font_display, 12, Color(0.6, 0.56, 0.52), HORIZONTAL_ALIGNMENT_RIGHT))
			for r in 4:
				var col: Color = Items.RARITY_COLOR[r]
				tg.add_child(_label(Items.RARITY_NAME[r], Game.font_display_bold, 18, col))
				for val in [_n(run, "found_r%d" % r), _n(life, "found_r%d" % r), _n(run, "items_r%d" % r), _n(life, "items_r%d" % r)]:
					var cell := _label(_fmt_n(val), Game.font_body_bold, 18, Color(0.92, 0.86, 0.78), HORIZONTAL_ALIGNMENT_RIGHT)
					cell.custom_minimum_size = Vector2(130, 0)
					tg.add_child(cell)
			body.add_child(tg)
		3:
			var zk: Dictionary = life.get("zone_kills", {})
			var zrows: Array = []
			for z in Data.LAST_ZONE + 1:
				zrows.append([Data.ZONES[z].name.replace("The ", ""), float(zk.get(str(z), 0.0)), Color(0.8, 0.45, 0.2)])
			body.add_child(_chart("Kills per zone (lifetime)", zrows, 340))
			var right4 := VBoxContainer.new()
			right4.add_theme_constant_override("separation", 6)
			right4.add_child(_label("ACTS", Game.font_display, 13, Color(0.6, 0.56, 0.52)))
			for i in Data.ACTS.size():
				var done := bool(Game.zs(Data.ACTS[i].zones[1]).claimed) if Game.in_run else false
				right4.add_child(_label("%s  ·  %s%s" % [Data.ACTS[i].name, Data.ACTS[i].title, "   ✓" if done else ""], Game.font_body, 18, Color(0.5, 0.85, 0.45) if done else Color(0.72, 0.68, 0.64)))
			body.add_child(right4)
	var back := _button("Back", show_title, 240)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_focus_first(back)
