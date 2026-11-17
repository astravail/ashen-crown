class_name Panels
extends Control

const Ink := preload("res://scripts/fx/ink.gd")
## Inventory, shops, stash, quests, waypoints and the skill tree.

signal closed
signal teleport(pos: Vector2)
signal difficulty_changed

const SLOT := 68.0

var world: World
var current: Control
var mode := ""
var vendor := ""
var _sell_confirm := -1
var _focus_key := ""
var _tip_box: VBoxContainer
var _status: Label
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return current != null


func clear() -> void:
	if current:
		current.queue_free()
		current = null


func close() -> void:
	clear()
	mode = ""
	closed.emit()


# ---------------------------------------------------------------- helpers

func _root(dim := 0.7) -> Control:
	clear()
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.015, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	current = c
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


func _wrap(l: Label, w := 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
	return l


func _button(text: String, cb: Callable, w := 200.0, h := 44.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func():
		Sfx.play("ui_select", -6.0, 0.0)
		cb.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


func _sb(bg: Color, border: Color, pad := 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	return sb


func _frame(title: String, sub := "") -> VBoxContainer:
	var c := _root()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Ornate.box("panel"))
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_label(title, Game.font_display_bold, 34, Color(0.97, 0.88, 0.76)))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	if sub != "":
		head.add_child(_label(sub, Game.font_display, 18, Color(0.85, 0.6, 0.32)))
	v.add_child(Menus.new()._rule(600))
	return v


func _gold_label() -> Label:
	return _label("%d gold" % Game.gold, Game.font_display_bold, 22, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)


# ---------------------------------------------------------------- slot widget

class ItemSlot extends Control:
	signal activated
	signal alt
	signal hovered
	var item: Variant = null
	var tag := ""
	var price := -1
	var affordable := true
	var confirm := false
	var key := ""

	func _init() -> void:
		custom_minimum_size = Vector2(Panels.SLOT, Panels.SLOT)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		mouse_entered.connect(func(): grab_focus())
		focus_entered.connect(func():
			Sfx.play("ui_move", -14.0, 0.0)
			hovered.emit())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				activated.emit()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				alt.emit()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			activated.emit()
			accept_event()

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Color(0.28, 0.23, 0.2)
		var bg := Color(0.085, 0.072, 0.068)
		if item != null:
			col = Items.color_of(item)
			bg = Color(col.r * 0.16 + 0.05, col.g * 0.16 + 0.045, col.b * 0.16 + 0.04)
		# a recessed well: darker at the top, lit from below by the item's own colour
		draw_rect(r, bg.darkened(0.35))
		draw_rect(Rect2(0, size.y * 0.45, size.x, size.y * 0.55), bg)
		if item != null:
			draw_texture_rect(Ink.soft_tex(), Rect2(-size.x * 0.1, size.y * 0.1, size.x * 1.2, size.y * 1.1), false, Color(col.r, col.g, col.b, 0.22 + 0.1 * float(item.rarity)))
		# bevel: shadow on the upper and left edges, light on the lower and right
		draw_rect(Rect2(0, 0, size.x, 2), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, 0, 2, size.y), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(size.x - 1, 0, 1, size.y), Color(1, 1, 1, 0.05))
		if item != null:
			var broken := Items.is_broken(item)
			Icons.item(self, String(item.icon), size * 0.5 + Vector2(1.5, 2.5), size.x * 0.7, Color(0, 0, 0, 0.5))
			Icons.item(self, String(item.icon), size * 0.5, size.x * 0.7, col if not broken else Color(0.5, 0.2, 0.2))
			if broken:
				draw_line(Vector2(6, 6), size - Vector2(6, 6), Color(0.8, 0.2, 0.2, 0.7), 2.0)
		elif tag != "":
			var w := Game.font_display.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(Game.font_display, Vector2((size.x - w) * 0.5, size.y * 0.55), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.36, 0.33))
		draw_rect(r, col if not has_focus() else Game.C_EMBER_HOT, false, 2.0 if has_focus() else 1.0)
		if item != null and int(item.rarity) >= 2:
			# little studs at the corners for rare and legendary things
			for cp in [Vector2(3, 3), Vector2(size.x - 4, 3), Vector2(3, size.y - 4), Vector2(size.x - 4, size.y - 4)]:
				draw_rect(Rect2(cp, Vector2(1.5, 1.5)), Color(col.r, col.g, col.b, 0.9))
		if price >= 0:
			var txt := "%dg" % price
			var tw := Game.font_body_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_rect(Rect2(size.x - tw - 8, size.y - 18, tw + 8, 18), Color(0, 0, 0, 0.7))
			draw_string(Game.font_body_bold, Vector2(size.x - tw - 4, size.y - 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.3) if affordable else Color(0.8, 0.3, 0.25))
		if confirm:
			draw_rect(r, Color(1.0, 0.3, 0.2, 0.25))


func _make_slot(item: Variant, tag := "") -> ItemSlot:
	var s := ItemSlot.new()
	s.item = item
	s.tag = tag
	return s


# ---------------------------------------------------------------- tooltip

func _tip_clear() -> void:
	for c in _tip_box.get_children():
		c.queue_free()


func _show_tip(item: Variant, compare: Variant = null, price_text := "") -> void:
	_tip_clear()
	if item == null:
		_tip_box.add_child(_label("Nothing here.", Game.font_italic, 20, Color(0.5, 0.47, 0.44)))
		return
	var it: Dictionary = item
	var col := Items.color_of(it)
	_tip_box.add_child(_wrap(_label(String(it.name), Game.font_display_bold, 26, col), 380.0))
	_tip_box.add_child(_label("%s %s  ·  Item level %d" % [Items.RARITY_NAME[int(it.rarity)], Items.SLOT_LABEL[it.slot], int(it.ilvl)], Game.font_body, 17, Color(0.6, 0.56, 0.52)))
	_tip_box.add_child(Menus.new()._rule(360))
	if it.implicit.has("k"):
		_tip_box.add_child(_label(Items.stat_text(it.implicit.k, float(it.implicit.v)), Game.font_body_bold, 20, Color(0.92, 0.88, 0.8)))
	for m in it.mods:
		_tip_box.add_child(_wrap(_label(Items.stat_text(m.k, float(m.v)), Game.font_body, 19, Color(0.55, 0.72, 1.0) if int(it.rarity) < 3 else Game.C_GOLD), 380.0))
	if String(it.tag) != "":
		_tip_box.add_child(_wrap(_label("“%s”" % it.tag, Game.font_italic, 17, Game.C_GOLD), 380.0))
	var dur_col := Color(0.65, 0.62, 0.58)
	var dur_txt := "Durability %d / %d" % [int(it.dur), int(it.dur_max)]
	if Items.is_broken(it):
		dur_col = Color(0.9, 0.25, 0.2)
		dur_txt = "BROKEN  ·  gives nothing until repaired"
	elif float(it.dur) / float(it.dur_max) < 0.3:
		dur_col = Color(0.9, 0.6, 0.25)
	_tip_box.add_child(_label(dur_txt, Game.font_body, 16, dur_col))
	if compare != null and compare != item:
		var a := Items.item_stats(it)
		var b := Items.item_stats(compare)
		var keys := {}
		for k in a.keys():
			keys[k] = true
		for k in b.keys():
			keys[k] = true
		_tip_box.add_child(Menus.new()._rule(360))
		_tip_box.add_child(_label("Compared to what you wear", Game.font_display, 14, Color(0.6, 0.56, 0.52)))
		var any := false
		for k in keys.keys():
			var d := float(a.get(k, 0.0)) - float(b.get(k, 0.0))
			if absf(d) < 0.01:
				continue
			any = true
			var up := d > 0.0
			var line := "%s %s" % ["▲" if up else "▼", Items.stat_text(k, absf(d)).replace("+", "")]
			_tip_box.add_child(_wrap(_label(line, Game.font_body, 17, Color(0.5, 0.85, 0.45) if up else Color(0.85, 0.4, 0.35)), 380.0))
		if not any:
			_tip_box.add_child(_label("No difference.", Game.font_body, 16, Color(0.55, 0.52, 0.5)))
	if price_text != "":
		_tip_box.add_child(_label(price_text, Game.font_display_bold, 18, Color(1.0, 0.85, 0.3)))


func _equipped(slot: String) -> Variant:
	return Game.equipment.get(slot)


func _stats_box() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_label("CHARACTER", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
	var p := world.player
	var rows := [
		["Life", "%d" % int(p.max_hp)], ["Damage", "+%d%%" % int((p.dmg_mult() - 1.0) * 100.0)],
		["Armour", "%d%%" % int(p.armor * 100.0)], ["Crit chance", "%.1f%%" % (p.crit_chance() * 100.0)],
		["Crit damage", "+%d%%" % int((p.crit_mult() - 1.0) * 100.0)], ["Cooldowns", "+%d%%" % int((p.cd_rate() - 1.0) * 100.0)],
		["Move speed", "%d" % int(p.speed())], ["Magic find", "+%d%%" % int(Game.gear_stat("mf") + float(Game.diff().mf))],
		["Gold found", "+%d%%" % int(Game.gear_stat("gold"))], ["Potion", "%ds" % int(p.potion_cooldown())],
	]
	for r in rows:
		var h := HBoxContainer.new()
		h.add_child(_label(r[0], Game.font_body, 16, Color(0.65, 0.61, 0.57)))
		var f := Control.new()
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(f)
		h.add_child(_label(r[1], Game.font_body_bold, 16, Color(0.92, 0.86, 0.78)))
		v.add_child(h)
	return v


# ---------------------------------------------------------------- inventory / shop / stash


# ---------------------------------------------------------------- abilities tab

var _sel_ability := -1


func _add_tabs(head: HBoxContainer, active: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(30, 0)
	head.add_child(gap)
	for t in [["gear", "GEAR"], ["abilities", "ABILITIES"]]:
		var b := _button(t[1], func():
			_sel_ability = -1
			if t[0] == "gear":
				show_inventory("inv")
			else:
				show_abilities(), 150.0, 38.0)
		if t[0] == active:
			b.add_theme_color_override("font_color", Game.C_GOLD)
			b.add_theme_stylebox_override("normal", _sb(Color(0.12, 0.08, 0.05), Ornate.GOLD_MID, 10))
			b.disabled = false
		head.add_child(b)


class AbilityCard extends Control:
	signal chosen
	var ability: Dictionary = {}
	var class_id := ""
	var attached := ""
	var selected := false
	var fixed := false

	func _init() -> void:
		custom_minimum_size = Vector2(520, 108)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		mouse_entered.connect(func(): grab_focus())

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			chosen.emit()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot := selected or has_focus()
		draw_rect(r, Color(0.13, 0.09, 0.06) if selected else Color(0.07, 0.06, 0.055))
		draw_rect(Rect2(0, 0, 4, size.y), Ornate.GOLD_HI if selected else Color(0.3, 0.24, 0.2))
		draw_rect(r, Game.C_EMBER_HOT if hot else Color(0.24, 0.2, 0.17), false, 2.0 if hot else 1.0)
		var icon_box := Rect2(14, 20, 68, 68)
		draw_rect(icon_box, Color(0.03, 0.026, 0.025))
		draw_rect(icon_box, Color(0.4, 0.3, 0.2), false, 1.0)
		Icons.draw(self, ability.id, icon_box.get_center(), 56.0, Color(1.0, 0.82, 0.6))
		draw_string(Game.font_display_bold, Vector2(98, 28), String(ability.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 300, 19, Color(0.97, 0.88, 0.76))
		draw_multiline_string(Game.font_body, Vector2(98, 48), String(ability.desc), HORIZONTAL_ALIGNMENT_LEFT, 400, 15, 3, Color(0.72, 0.68, 0.64))
		var meta := "Cooldown %s s" % ("%.1f" % float(ability.cd))
		if float(ability.cost) != 0.0 and class_id != "pyrewitch":
			meta += "   ·   Cost %d" % int(ability.cost)
		draw_string(Game.font_body, Vector2(98, 100), meta, HORIZONTAL_ALIGNMENT_LEFT, 360, 14, Color(0.55, 0.5, 0.46))
		if attached != "":
			var w := Game.font_display_bold.get_string_size(attached, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
			draw_rect(Rect2(size.x - w - 10, 10, w, 26), Color(0.4, 0.12, 0.06))
			draw_rect(Rect2(size.x - w - 10, 10, w, 26), Ornate.GOLD_MID, false, 1.0)
			draw_string(Game.font_display_bold, Vector2(size.x - w, 29), attached, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.7))


class BarSlot extends Control:
	signal chosen
	var ability: Dictionary = {}
	var key := ""
	var armed := false

	func _init() -> void:
		custom_minimum_size = Vector2(118, 150)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		mouse_entered.connect(func(): grab_focus())

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			chosen.emit()
			accept_event()

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.06, 0.05, 0.047))
		var hot := armed or has_focus()
		draw_rect(r, Ornate.GOLD_HI if hot else Color(0.3, 0.24, 0.2), false, 2.0 if hot else 1.0)
		var box := Rect2(size.x * 0.5 - 40, 12, 80, 80)
		draw_rect(box, Color(0.025, 0.02, 0.02))
		draw_rect(box, Game.C_EMBER_HOT if armed else Color(0.45, 0.34, 0.22), false, 1.5)
		if not ability.is_empty():
			Icons.draw(self, ability.id, box.get_center(), 66.0, Color(1.0, 0.82, 0.6))
			var w := Game.font_body_bold.get_string_size(String(ability.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(Game.font_body_bold, Vector2((size.x - minf(w, size.x - 8)) * 0.5, 112), String(ability.name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 14, Color(0.9, 0.84, 0.76))
		var kw := Game.font_display_bold.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(Game.font_display_bold, Vector2((size.x - kw) * 0.5, 138), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Game.C_GOLD)


func show_abilities() -> void:
	mode = "inv"
	var cls: String = Game.class_id
	var data: Dictionary = Data.CLASSES[cls]
	var abil: Array = data.abilities
	var map: Array = Game.loadout_for(cls)
	var keys := ["attack_1", "attack_2", "skill_1", "skill_2"]
	var v := _frame("ABILITIES", "")
	var head: HBoxContainer = v.get_child(0)
	_add_tabs(head, "abilities")
	head.add_child(_gold_label())
	v.add_child(_label("Pick an ability, then pick the button on your bar it should sit on.", Game.font_italic, 18, Color(0.62, 0.58, 0.54)))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	v.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	list.add_child(_label("YOUR ABILITIES", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
	var first: Control
	for ai in 4:
		var card := AbilityCard.new()
		card.ability = abil[ai]
		card.class_id = cls
		card.selected = _sel_ability == ai
		var slot_of := map.find(ai)
		card.attached = Game.input_label(keys[slot_of], false) if slot_of >= 0 else ""
		var idx := ai
		card.chosen.connect(func():
			Sfx.play("ui_select", -6.0, 0.0)
			_sel_ability = -1 if _sel_ability == idx else idx
			show_abilities())
		list.add_child(card)
		if first == null:
			first = card
	var ult := AbilityCard.new()
	ult.ability = abil[4]
	ult.class_id = cls
	ult.attached = "ULTIMATE"
	ult.modulate = Color(0.8, 0.8, 0.8)
	list.add_child(ult)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	right.add_child(_label("YOUR BAR", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	right.add_child(row)
	for si in 4:
		var bs := BarSlot.new()
		bs.ability = abil[map[si]]
		bs.key = Game.input_label(keys[si], false)
		bs.armed = _sel_ability >= 0
		var sidx := si
		bs.chosen.connect(func():
			if _sel_ability < 0:
				return
			var m: Array = Game.loadout_for(cls)
			var from: int = m.find(_sel_ability)
			var tmp: int = m[sidx]
			m[sidx] = _sel_ability
			if from >= 0:
				m[from] = tmp
			Game.set_loadout(cls, m)
			if world and world.player:
				world.player.slot_map = m
			Sfx.play("ui_select", -4.0, 0.0)
			_sel_ability = -1
			show_abilities())
		row.add_child(bs)
	right.add_child(_wrap(_label("Change the keys themselves in Settings, under Controls. The ultimate always stays on its own button.", Game.font_body, 16, Color(0.55, 0.52, 0.48)), 520.0))
	v.add_child(_label("I / Esc  ·  close", Game.font_body, 15, Color(0.5, 0.47, 0.44)))
	if first:
		first.grab_focus.call_deferred()



func show_inventory(m := "inv", v := "") -> void:
	mode = m
	vendor = v
	_sell_confirm = -1
	_build_items()


func _refresh_items() -> void:
	var key := _focus_key
	_build_items()
	if key != "":
		_restore_focus(key)


func _restore_focus(key: String) -> void:
	await get_tree().process_frame
	if current == null:
		return
	for n in current.find_children("*", "Control", true, false):
		if n is ItemSlot and (n as ItemSlot).key == key:
			(n as ItemSlot).grab_focus()
			return


func _build_items() -> void:
	var title: String = {"inv": "INVENTORY", "smith": "HILD, ASHSMITH", "mystic": "VEYRA, MYSTIC", "stash": "STASH"}[mode]
	var v := _frame(title, "")
	var head: HBoxContainer = v.get_child(0)
	if mode == "inv":
		_add_tabs(head, "gear")
	head.add_child(_gold_label())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	v.add_child(body)

	# Left column
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	if mode == "stash":
		left.add_child(_label("STASH  (shared, safe)", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
		var sg := GridContainer.new()
		sg.columns = 8
		sg.add_theme_constant_override("h_separation", 4)
		sg.add_theme_constant_override("v_separation", 4)
		left.add_child(sg)
		for i in Game.STASH_SIZE:
			var s := _make_slot(Game.stash[i])
			s.key = "st%d" % i
			var idx := i
			s.hovered.connect(func():
				_focus_key = "st%d" % idx
				_show_tip(Game.stash[idx], null))
			s.activated.connect(func(): _stash_to_pack(idx))
			sg.add_child(s)
	else:
		if mode != "inv":
			var stock: Array = Game.vendor_stock(vendor)
			left.add_child(_label("FOR SALE", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
			var sg2 := GridContainer.new()
			sg2.columns = 4
			sg2.add_theme_constant_override("h_separation", 4)
			sg2.add_theme_constant_override("v_separation", 4)
			left.add_child(sg2)
			for i in stock.size():
				var it: Variant = stock[i]
				var s2 := _make_slot(it)
				s2.key = "sv%d" % i
				if it != null:
					s2.price = Items.price(it)
					s2.affordable = Game.gold >= s2.price
				var idx2 := i
				s2.hovered.connect(func():
					_focus_key = "sv%d" % idx2
					var cur: Variant = Game.vendor_stock(vendor)[idx2]
					_show_tip(cur, _equipped(cur.slot) if cur != null else null, ("Buy for %d gold" % Items.price(cur)) if cur != null else ""))
				s2.activated.connect(func(): _buy(idx2))
				sg2.add_child(s2)
		left.add_child(_label("EQUIPPED", Game.font_display, 15, Color(0.6, 0.56, 0.52)))
		var eg := GridContainer.new()
		eg.columns = 3
		eg.add_theme_constant_override("h_separation", 4)
		eg.add_theme_constant_override("v_separation", 4)
		left.add_child(eg)
		# laid out like a body: helm over chest over boots, weapon on one side, ring and amulet on the other
		for slot in ["", "helm", "amulet", "weapon", "chest", "ring", "", "boots", ""]:
			if slot == "":
				var gap2 := Control.new()
				gap2.custom_minimum_size = Vector2(SLOT, SLOT)
				eg.add_child(gap2)
				continue
			var es := _make_slot(_equipped(slot), String(Items.SLOT_LABEL[slot]))
			es.key = "eq_" + slot
			var sl: String = slot
			es.hovered.connect(func():
				_focus_key = "eq_" + sl
				_show_tip(_equipped(sl), null))
			es.activated.connect(func(): _unequip(sl))
			eg.add_child(es)
		if mode == "inv":
			left.add_child(_stats_box())

	# Backpack
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	body.add_child(mid)
	mid.add_child(_label("BACKPACK  %d / %d" % [Game.INV_SIZE - Game.free_slots(Game.inv), Game.INV_SIZE], Game.font_display, 15, Color(0.6, 0.56, 0.52)))
	var bg := GridContainer.new()
	bg.columns = 6
	bg.add_theme_constant_override("h_separation", 4)
	bg.add_theme_constant_override("v_separation", 4)
	mid.add_child(bg)
	var first: ItemSlot = null
	for i in Game.INV_SIZE:
		var it2: Variant = Game.inv[i]
		var s3 := _make_slot(it2)
		s3.key = "bp%d" % i
		s3.confirm = _sell_confirm == i
		var idx3 := i
		s3.hovered.connect(func():
			_focus_key = "bp%d" % idx3
			var cur2: Variant = Game.inv[idx3]
			var ptxt := ""
			if cur2 != null and mode in ["smith", "mystic"]:
				ptxt = "Sell for %d gold" % Items.sell_price(cur2)
			elif cur2 != null and mode == "inv":
				ptxt = "Click to equip"
			_show_tip(cur2, _equipped(cur2.slot) if cur2 != null else null, ptxt))
		s3.activated.connect(func(): _pack_click(idx3))
		s3.alt.connect(func(): _pack_alt(idx3))
		bg.add_child(s3)
		if first == null:
			first = s3
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	mid.add_child(btns)
	if mode == "smith":
		var cost := Game.repair_all_cost()
		var rb := _button("Repair all  (%dg)" % cost, _repair, 230.0, 40.0)
		rb.disabled = cost <= 0 or Game.gold < cost
		btns.add_child(rb)
	if mode == "mystic":
		btns.add_child(_button("Mend  (free)", _mend, 200.0, 40.0))
	if mode in ["smith", "mystic"]:
		btns.add_child(_button("Sell commons", _sell_commons, 190.0, 40.0))
	_status = _label("", Game.font_italic, 16, Color(0.85, 0.5, 0.3))
	mid.add_child(_status)

	# Tooltip
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.034, 0.033), Color(0.22, 0.18, 0.15), 18))
	tp.custom_minimum_size = Vector2(420, 560)
	body.add_child(tp)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 5)
	tp.add_child(_tip_box)
	_show_tip(null)
	var foot := "I / Esc  ·  close      Click  ·  %s" % {"inv": "equip or unequip", "smith": "buy or sell", "mystic": "buy or sell", "stash": "move"}[mode]
	v.add_child(_label(foot, Game.font_body, 15, Color(0.5, 0.47, 0.44)))
	if first:
		first.grab_focus.call_deferred()


func _say(t: String) -> void:
	if _status:
		_status.text = t


func _pack_click(i: int) -> void:
	var it: Variant = Game.inv[i]
	if it == null:
		return
	match mode:
		"inv":
			Game.equip(i)
			Sfx.play("pickup", -6.0, 0.1, 0.7)
			if Items.is_broken(it):
				_say("It is broken, and gives nothing until the smith mends it.")
			_refresh_items()
		"smith", "mystic":
			if int(it.rarity) >= 2 and _sell_confirm != i:
				_sell_confirm = i
				_refresh_items()
				_say("Click again to sell %s." % it.name)
				return
			Game.gold += Items.sell_price(it)
			Game.inv[i] = null
			_sell_confirm = -1
			Sfx.play("pickup", -4.0, 0.1, 1.4)
			_refresh_items()
		"stash":
			if Game.add_to(Game.stash, it):
				Game.inv[i] = null
				_refresh_items()
			else:
				_say("The stash is full.")


func _pack_alt(i: int) -> void:
	if mode == "inv" and Game.inv[i] != null and int(Game.inv[i].rarity) < 2:
		Game.inv[i] = null
		_refresh_items()


func _unequip(slot: String) -> void:
	if _equipped(slot) == null:
		return
	if not Game.unequip(slot):
		_say("Your backpack is full.")
	_refresh_items()


func _buy(i: int) -> void:
	var stock: Array = Game.vendor_stock(vendor)
	var it: Variant = stock[i]
	if it == null:
		return
	var price := Items.price(it)
	if Game.gold < price:
		_say("You cannot afford that.")
		Sfx.play("ui_move", -6.0, 0.0, 0.6)
		return
	if not Game.add_item(it):
		_say("Your backpack is full.")
		return
	Game.gold -= price
	stock[i] = null
	Sfx.play("pickup", -4.0, 0.1, 1.0)
	_refresh_items()


func _stash_to_pack(i: int) -> void:
	var it: Variant = Game.stash[i]
	if it == null:
		return
	if Game.add_item(it):
		Game.stash[i] = null
		_refresh_items()
	else:
		_say("Your backpack is full.")


func _repair() -> void:
	var c := Game.repair_all()
	if c > 0:
		Sfx.play("hit_heavy", -4.0, 0.1, 0.9)
		Voice.bark("smith", "repair", "", 0.0)
	_refresh_items()


func _mend() -> void:
	world.player.hp = world.player.max_hp
	Game.potion_cd = 0.0
	Sfx.play("flask")
	Voice.bark("mystic", "heal", "", 0.0)
	_say("Your wounds close.")


func _sell_commons() -> void:
	var total := 0
	for i in Game.INV_SIZE:
		var it: Variant = Game.inv[i]
		if it != null and int(it.rarity) == 0:
			total += Items.sell_price(it)
			Game.inv[i] = null
	Game.gold += total
	if total > 0:
		Sfx.play("pickup", -4.0, 0.1, 1.4)
	_refresh_items()
	_say("Sold the common gear for %d gold." % total)


# ---------------------------------------------------------------- quests

func show_quests(elder: bool) -> void:
	mode = "quests"
	var v := _frame("SISTER MAREN" if elder else "QUEST LOG", "Cinderfall" if elder else "")
	v.get_child(0).add_child(_gold_label())
	if elder:
		var greet: String = (Voice.NPC_LINES.elder.greet as Array)[randi() % 2]
		v.add_child(_wrap(_label("“%s”" % greet, Game.font_italic, 20, Color(0.8, 0.74, 0.68)), 900.0))
		var dr := HBoxContainer.new()
		dr.add_theme_constant_override("separation", 12)
		v.add_child(dr)
		var d: Dictionary = Game.diff()
		dr.add_child(_label("Difficulty", Game.font_body, 20, Color(0.65, 0.61, 0.57)))
		dr.add_child(_button("◀", func(): _set_diff(Game.difficulty - 1), 46.0, 36.0))
		dr.add_child(_label("%d / %d   %s" % [Game.difficulty + 1, Game.DIFFICULTIES.size(), d.name], Game.font_display_bold, 21, Game.C_GOLD))
		dr.add_child(_button("▶", func(): _set_diff(Game.difficulty + 1), 46.0, 36.0))
		dr.add_child(_label("Enemies %d%% life · %d%% damage   XP +%d%%   Gold +%d%%   Magic find +%d%%" % [int(float(d.hp) * 100.0), int(float(d.dmg) * 100.0), int(float(d.xp) * 100.0 - 100.0), int(float(d.gold) * 100.0 - 100.0), int(d.mf)], Game.font_body, 16, Color(0.6, 0.56, 0.52)))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(1000, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	var shown := 0
	var first: Control = null
	for pass_i in 3:
		for q in Data.QUESTS:
			var st := Game.quest_status(q.id)
			var want := false
			match pass_i:
				0: want = st == 2
				1: want = st == 1
				2: want = elder and Game.quest_available(q)
			if not want:
				continue
			if pass_i == 2 and not bool(q.get("story", false)) and shown > 14:
				continue
			shown += 1
			var row := _quest_row(q, st, elder)
			list.add_child(row)
			if first == null:
				first = row.find_child("QBtn", true, false)
	if shown == 0:
		list.add_child(_label("No quests. Speak with Sister Maren in Cinderfall." if not elder else "Nothing for you yet. Come back stronger.", Game.font_italic, 22, Color(0.6, 0.56, 0.52)))
	var back := _button("Close", close, 200.0)
	v.add_child(back)
	if first:
		first.grab_focus.call_deferred()
	else:
		back.grab_focus.call_deferred()


func _set_diff(i: int) -> void:
	if i != Game.difficulty and not Game.change_difficulty(i - Game.difficulty):
		world.banner.emit("Too soon", "You can change difficulty again in %d seconds" % ceili(Game.diff_cd))
		return
	difficulty_changed.emit()
	show_quests(true)


func _reward_text(q: Dictionary) -> String:
	var d: Dictionary = Game.diff()
	return "Reward: %d gold · %d xp · %s gear" % [int(q.gold * float(d.gold)), int(q.xp * float(d.xp)), "legendary" if int(q.min_r) >= 3 else ("rare" if int(q.min_r) == 2 else "magic")]


func _quest_row(q: Dictionary, st: int, elder: bool) -> Control:
	var pc := PanelContainer.new()
	var story: bool = q.get("story", false)
	pc.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.058, 0.052), Color(0.8, 0.5, 0.2) if story else Color(0.26, 0.22, 0.19), 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	var tag := ("CHAPTER %d  ·  " % int(q.chapter)) if story else "BOUNTY  ·  "
	var zname: String = Data.ZONES[q.zone].name if int(q.zone) >= 0 else ""
	v.add_child(_label(tag + zname.to_upper(), Game.font_display, 14, Color(0.9, 0.55, 0.25) if story else Color(0.6, 0.56, 0.52)))
	v.add_child(_label(q.title, Game.font_display_bold, 24, Color(0.97, 0.9, 0.8)))
	v.add_child(_wrap(_label(q.desc, Game.font_body, 18, Color(0.75, 0.71, 0.67)), 700.0))
	if story and st == 0 and q.has("say"):
		v.add_child(_wrap(_label("“%s”" % q.say, Game.font_italic, 17, Color(0.7, 0.62, 0.54)), 700.0))
	var p: int = int((Game.quests.get(q.id, {"p": 0}) as Dictionary).p)
	if st == 1:
		v.add_child(_label("Progress  %d / %d" % [p, int(q.goal)], Game.font_body_bold, 17, Color(0.95, 0.75, 0.4)))
	elif st == 2:
		v.add_child(_label("Complete. Return to the Elder.", Game.font_body_bold, 17, Color(0.5, 0.85, 0.45)))
	v.add_child(_label(_reward_text(q), Game.font_body, 16, Color(1.0, 0.85, 0.3)))
	if elder and st == 0:
		var b := _button("Accept", func(): _accept(q), 160.0)
		b.name = "QBtn"
		h.add_child(b)
	elif elder and st == 2:
		var b2 := _button("Turn in", func(): _turn_in(q), 160.0)
		b2.name = "QBtn"
		h.add_child(b2)
	return pc


func _accept(q: Dictionary) -> void:
	Game.quest_accept(q.id)
	if world:
		world.spawn_quest_bosses()
		world._set_objective()
	Sfx.play("levelup", -8.0)
	show_quests(true)


func _turn_in(q: Dictionary) -> void:
	var d: Dictionary = Game.diff()
	Game.quests[q.id].s = 3
	Game.stat_add("quests", 1.0)
	Game.gold += int(q.gold * float(d.gold))
	world.player.gain_xp(float(q.xp) * float(d.xp))
	var z: int = maxi(0, mini(int(q.zone), Data.LAST_ZONE))
	var ilvl := Items.drop_ilvl(z, 2)
	var mf := Game.gear_stat("mf") + float(d.mf)
	var slot: String = q.get("slot", "")
	var it := Items.roll_drop("quest", ilvl, mf, slot, int(q.min_r))
	if int(q.min_r) >= 3:
		it = Items.make_legend(slot if slot != "" else "weapon", ilvl, true)
	if not Game.add_item(it):
		world.drop_item(it, world.player.global_position)
	world.banner.emit("Quest complete", String(q.title))
	Voice.bark("elder", "quest_done", "", 0.0)
	Sfx.play("fragment", -4.0)
	Game.quests_changed.emit()
	world._set_objective()
	show_quests(true)


# ---------------------------------------------------------------- waypoints

func show_waypoints() -> void:
	mode = "waypoints"
	var v := _frame("WAYPOINT", "Travel only where you have been")
	var targets: Array = world.waypoint_targets()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)
	var first: Button = null
	for t in targets:
		var here: bool = world.player.global_position.distance_to(t.pos) < 400.0
		var b := _button("%s   ·   %s%s" % [t.name, t.sub, "   (you are here)" if here else ""], func():
			close()
			teleport.emit(t.pos), 620.0, 56.0)
		b.disabled = here
		list.add_child(b)
		if first == null and not here:
			first = b
	var undiscovered := Data.LAST_ZONE + 1 - (targets.size() - 1)
	if undiscovered > 0:
		list.add_child(_label("%d undiscovered waypoint%s. Walk there first." % [undiscovered, "" if undiscovered == 1 else "s"], Game.font_italic, 18, Color(0.5, 0.47, 0.44)))
	var back := _button("Close", close, 200.0)
	v.add_child(back)
	(first if first else back).grab_focus.call_deferred()


# ---------------------------------------------------------------- skill tree

func _spent_in(col: int) -> int:
	var n := 0
	for col_node in Data.tree_nodes(col, world.player.cls):
		n += world.player.mod(col_node.id)
	return n


func show_skills() -> void:
	mode = "skills"
	var p := world.player
	var v := _frame("SKILLS", "%d point%s to spend" % [p.pending_levels, "" if p.pending_levels == 1 else "s"])
	v.add_child(_label("You start with nothing. Every level earns a point. Each column opens a tier for every two points spent in it.", Game.font_italic, 17, Color(0.65, 0.6, 0.55)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	v.add_child(cols)
	var first: Button = null
	for ci in 4:
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		cols.add_child(cv)
		var spent := _spent_in(ci)
		var name_txt: String = Data.TREE_COLS[ci] if ci != 2 else Data.CLASSES[p.cls].name
		cv.add_child(_label("%s  ·  %d" % [name_txt.to_upper(), spent], Game.font_display_bold, 18, Color(0.95, 0.7, 0.4)))
		for u in Data.tree_nodes(ci, p.cls):
			var rank: int = p.mod(u.id)
			var need: int = int(u.tier) * 2
			var open := spent >= need
			var can: bool = open and rank < int(u.max) and p.pending_levels > 0
			var b := Button.new()
			b.custom_minimum_size = Vector2(250, 112)
			b.focus_mode = Control.FOCUS_ALL
			var edge := Game.C_EMBER if rank > 0 else (Color(0.5, 0.4, 0.3) if open else Color(0.2, 0.18, 0.17))
			for st in ["normal", "hover", "focus", "pressed", "disabled"]:
				b.add_theme_stylebox_override(st, _sb(Color(0.08, 0.065, 0.058) if open else Color(0.05, 0.045, 0.045), Game.C_EMBER_HOT if st in ["hover", "focus"] and can else edge, 10))
			b.disabled = not can
			var bv := VBoxContainer.new()
			bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bv.add_theme_constant_override("separation", 1)
			b.add_child(bv)
			bv.add_child(_label("%s   %d / %d" % [u.name, rank, int(u.max)], Game.font_display_bold, 17, Color(0.97, 0.9, 0.8) if open else Color(0.45, 0.42, 0.4)))
			bv.add_child(_wrap(_label(("Needs %d points in this column" % need) if not open else u.desc, Game.font_body, 15, Color(0.72, 0.68, 0.64) if open else Color(0.5, 0.35, 0.3)), 226.0))
			var id: String = u.id
			b.pressed.connect(func():
				p.add_mod(id)
				p.pending_levels -= 1
				Sfx.play("levelup", -8.0)
				show_skills())
			b.mouse_entered.connect(func(): b.grab_focus())
			cv.add_child(b)
			if first == null and can:
				first = b
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var cost := 40 * p.level
	var rb := _button("Reset skills  (%dg)" % cost, _respec, 280.0)
	rb.disabled = Game.gold < cost or p.mods.is_empty() or not world.village
	foot.add_child(rb)
	foot.add_child(_label("Resetting is possible in the village only." if not world.village else "", Game.font_italic, 16, Color(0.55, 0.5, 0.46)))
	foot.add_child(_button("Close", close, 200.0))
	if first:
		first.grab_focus.call_deferred()


func _respec() -> void:
	var p := world.player
	var cost := 40 * p.level
	if Game.gold < cost:
		return
	Game.gold -= cost
	for k in p.mods.keys():
		p.pending_levels += int(p.mods[k])
	p.mods.clear()
	p.step_charges = 1
	p.recompute()
	Sfx.play("summon", -4.0)
	show_skills()
