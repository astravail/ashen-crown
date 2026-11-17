class_name Tutorial
extends Control
## Contextual tutorial popups: an animated demo, a title and an explanation.
## They appear when the situation first comes up, never pause the game, and
## can be switched off (or replayed) in Settings.

const TIPS := {
	"move": {"title": "Moving around", "demo": "move",
		"text": "Move with W A S D or the arrow keys (left stick on a gamepad). Your character always faces the cursor, so you can walk one way and strike another."},
	"attack": {"title": "Fighting", "demo": "attack",
		"text": "Hold the left mouse button to strike, the right button for your secondary attack. Enemies only notice you when you come close, so you choose when a fight starts."},
	"skills": {"title": "Skills", "demo": "skills",
		"text": "Q and E fire your two skills, R is the ultimate. Each skill has a cooldown shown on the bar below. Use them freely: they come back."},
	"dodge": {"title": "Dodging", "demo": "dodge",
		"text": "Press Space to roll. You cannot be hurt while rolling, so time it just as a blow or a projectile reaches you. The roll needs a second to recover."},
	"potion": {"title": "Healing potion", "demo": "potion",
		"text": "Press F to drink. The potion is endless but has a cooldown, so use it when it matters, not the moment you are scratched. Some gear shortens the cooldown."},
	"loot": {"title": "Loot", "demo": "loot",
		"text": "Enemies, chests and quests drop gear. Click it to pick it up, and a green arrow means it beats what you wear, a red one that it is worse. The colour of the light tells you how good it is: grey common, blue magic, gold rare, orange legendary."},
	"inventory": {"title": "Inventory and gear", "demo": "inventory",
		"text": "Press I. Click an item to equip it, compare it with what you wear, and sell what you do not need to the smith. Gear that is worn down loses power, so keep an eye on durability."},
	"interact": {"title": "Interacting", "demo": "interact",
		"text": "When a prompt appears over something, press G to use it: talk, open a chest, step through a door, light a waypoint."},
	"vendor": {"title": "The smith and the mystic", "demo": "vendor",
		"text": "Hild buys and sells weapons and armour, and repairs worn gear. Veyra deals in rings and charms. Gold is slow to earn, so spend it where it counts."},
	"stash": {"title": "The stash", "demo": "stash",
		"text": "Odd keeps your spare gear safe. The stash is shared by all your characters, except in hardcore, which has its own."},
	"quest": {"title": "Quests", "demo": "quest",
		"text": "Press J for your quest log. The active quest is tracked at the top left, and a dotted trail on the ground and an arrow at the screen edge point you toward it. Bring the elder your results to claim a reward."},
	"chest": {"title": "Chests", "demo": "chest",
		"text": "Chests hold better loot than most enemies. Iron chests are rarer and better. Be careful: now and then one is bait."},
	"waypoint": {"title": "Waypoints", "demo": "waypoint",
		"text": "Light a waypoint to make it a place you can travel to. From any waypoint you can jump to any other one you have already visited. You cannot travel to places you have not been."},
	"recall": {"title": "Recall", "demo": "recall",
		"text": "Press T to open a portal and, after three seconds, be carried back to the village. Any damage interrupts it, so use it from a safe spot. A portal waits in the village: step into it to return to the exact place you left."},
	"map": {"title": "The map", "demo": "map",
		"text": "Press Tab. The whole world is outlined, and the parts you have explored fill in. Click on the big map to place a marker, and a trail will lead you to it. Right-click removes it."},
	"skillpoint": {"title": "Skill points", "demo": "skilltree",
		"text": "You have a skill point. Press K to open the skill tree. You begin with an empty tree, and every point reaches a little further out. Choose a direction and commit to it."},
	"durability": {"title": "Worn gear", "demo": "durability",
		"text": "Your gear is wearing down, and dying wears it faster. Broken gear gives nothing. Visit Hild the smith in the village to repair it, for a price."},
	"champion": {"title": "Champions", "demo": "champion",
		"text": "A champion leads this pack. Defeat it and its crown fragment unlocks the altar that opens the way onward. Bosses and champions only walk the land while their quest is active."},
	"difficulty": {"title": "Difficulty", "demo": "difficulty",
		"text": "There are twenty difficulty levels. Higher ones give more experience, gold and magic find, but enemies hit harder. Change it one step at a time from the pause menu or settings; it has a cooldown."},
	"hardcore": {"title": "Hardcore", "demo": "hardcore",
		"text": "This character is hardcore. If it dies, it is gone for good and joins the Hall of the Fallen. In return you earn more experience, gold and magic find."},
	"death": {"title": "You have fallen", "demo": "durability",
		"text": "Death costs durability on all your gear. You return to the last waypoint you used. Repair at the smith before you push on."},
}

const ORDER := ["move", "attack", "skills", "dodge", "potion", "loot", "inventory", "interact"]

var main: Node
var queue: Array[String] = []
var current := ""
var _t := 0.0
var _life := 0.0
var _card: PanelContainer
var _title: Label
var _body: Label
var _step: Label
var _demo: TutDemo
var _slide := 0.0
var _poll := 0.0
var _seen_cache: Array = []
var _prev_hp := -1.0


func _ready() -> void:
	theme = Game.theme
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", Ornate.box("panel"))
	_card.custom_minimum_size = Vector2(540, 0)
	_card.visible = false
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	_step = _label("TIP", 15, Game.C_GOLD)
	v.add_child(_step)
	_title = _label("", 28, Color(1.0, 0.85, 0.6))
	v.add_child(_title)
	_demo = TutDemo.new()
	_demo.custom_minimum_size = Vector2(504, 230)
	v.add_child(_demo)
	_body = _label("", 19, Game.C_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(504, 0)
	v.add_child(_body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var ok := Button.new()
	ok.text = "Got it  [Enter]"
	ok.custom_minimum_size = Vector2(200, 42)
	ok.pressed.connect(dismiss)
	ok.focus_mode = Control.FOCUS_NONE
	h.add_child(ok)
	var off := Button.new()
	off.text = "Turn tips off"
	off.custom_minimum_size = Vector2(160, 42)
	off.focus_mode = Control.FOCUS_NONE
	off.pressed.connect(func():
		Game.settings.tutorials = false
		Game.save_settings()
		queue.clear()
		dismiss())
	h.add_child(off)


func _label(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if Game.font_body:
		l.add_theme_font_override("font", Game.font_body)
	return l


func enabled() -> bool:
	return bool(Game.settings.get("tutorials", true))


func seen(id: String) -> bool:
	return (Game.settings.get("tut_seen", []) as Array).has(id)


func reset_seen() -> void:
	Game.settings.tut_seen = []
	Game.save_settings()
	queue.clear()


## Ask for a tip. Ignored when tips are off, already seen, or already queued.
func request(id: String) -> void:
	if not enabled() or not TIPS.has(id) or seen(id) or current == id or queue.has(id):
		return
	queue.append(id)


func _mark_seen(id: String) -> void:
	var a: Array = Game.settings.get("tut_seen", [])
	if not a.has(id):
		a.append(id)
	Game.settings.tut_seen = a
	Game.save_settings()


func _can_show() -> bool:
	if main == null or main.world == null or main.world.player == null:
		return false
	var w: World = main.world
	if w.attract or main._busy or w.player.dead:
		return false
	if main.cut_layer.get_child_count() > 0:
		return false
	if get_tree().paused and main._overlay != "panel":
		return false
	return true


func show_tip(id: String) -> void:
	var tip: Dictionary = TIPS[id]
	current = id
	_mark_seen(id)
	_title.text = tip.title
	_body.text = tip.text
	_demo.kind = tip.demo
	_demo.t = 0.0
	var seen_n := (Game.settings.get("tut_seen", []) as Array).size()
	_step.text = "TIP  ·  %d / %d" % [seen_n, TIPS.size()]
	_life = 0.0
	_slide = 0.0
	_card.visible = true
	Sfx.play("ui_move", -6.0, 0.0)


func dismiss() -> void:
	current = ""
	_card.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if current != "" and event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		dismiss()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	_t += dt
	if current != "":
		_life += dt
		_slide = minf(1.0, _slide + dt * 3.0)
		_demo.t += dt
		var vs := get_viewport_rect().size
		var e := 1.0 - pow(1.0 - _slide, 3.0)
		var cs := _card.size
		_card.position = Vector2(vs.x - cs.x - 36.0 + (1.0 - e) * (cs.x + 60.0), maxf(70.0, (vs.y - cs.y) * 0.4))
		if _life > 45.0:
			dismiss()
		return
	if not enabled():
		return
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.4
		if _can_show():
			_scan()
			if not queue.is_empty():
				show_tip(queue.pop_front())


## Looks at the game state and asks for the tip that fits the moment.
func _scan() -> void:
	var w: World = main.world
	var p: Player = w.player
	if Game.in_run and Game.hardcore:
		request("hardcore")
	if not seen("move"):
		request("move")
		return
	var kills := float(Game.stats.get("kills", 0.0))
	var near := w.nearest_enemy(p.global_position, 700.0, false)
	if near != null:
		request("attack")
		if near.is_champion:
			request("champion")
	if kills >= 2.0:
		request("skills")
	if float(Game.stats.get("damage_taken", 0.0)) > 0.0 and kills >= 1.0:
		request("dodge")
	if p.hp < p.max_hp * 0.55 and float(Game.stats.get("damage_taken", 0.0)) > 0.0:
		request("potion")
	for l in w.loots:
		if l.global_position.distance_to(p.global_position) < 420.0 and not l.done:
			request("loot")
			break
	if not Game.inv.is_empty():
		request("inventory")
	var tgt: Node = w.interact_target
	if tgt != null:
		request("interact")
		if tgt is Prop and String((tgt as Prop).kind).begins_with("chest"):
			request("chest")
		if tgt is Prop and (tgt as Prop).kind == "waypoint":
			request("waypoint")
	if p.pending_levels > 0:
		request("skillpoint")
	if not w.village and w.recall_t <= 0.0 and Game.zone_index >= 0 and kills >= 3.0:
		request("recall")
		request("map")
	if p.level >= 4:
		request("difficulty")
	for s in Game.equipment.keys():
		var it: Variant = Game.equipment[s]
		if it is Dictionary and (it as Dictionary).has("dur_max"):
			var d := it as Dictionary
			if float(d.get("dur", 1.0)) <= float(d.dur_max) * 0.3:
				request("durability")


## Called by main for events that are not visible from polling.
func on_npc(kind: String) -> void:
	match kind:
		"smith", "mystic": request("vendor")
		"stash": request("stash")
		"elder": request("quest")


func on_death() -> void:
	request("death")


# ---------------------------------------------------------------- the animated demos

class TutDemo extends Control:
	var kind := "move"
	var t := 0.0
	const GROUND := Color(0.11, 0.095, 0.09)
	const SKIN := Color(0.9, 0.72, 0.56)
	const ACC := Color(0.9, 0.42, 0.18)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, GROUND)
		for i in 14:
			var x := fmod(float(i) * 41.0 + 13.0, size.x)
			var y := fmod(float(i) * 67.0 + 29.0, size.y)
			draw_circle(Vector2(x, y), 2.0, Color(0.2, 0.17, 0.15))
		draw_rect(r, Color(0.5, 0.3, 0.15, 0.7), false, 2.0)
		call("_d_" + kind)

	# --- building blocks
	func _hero(p: Vector2, face := 1.0, alpha := 1.0) -> void:
		draw_circle(p + Vector2(0, 14), 14.0, Color(0, 0, 0, 0.3 * alpha))
		draw_circle(p, 15.0, Color(0.32, 0.3, 0.34, alpha))
		draw_circle(p + Vector2(face * 3.0, -4.0), 8.0, Color(SKIN, alpha))
		draw_line(p + Vector2(face * 12.0, 2.0), p + Vector2(face * 34.0, -8.0), Color(0.8, 0.8, 0.85, alpha), 4.0)

	func _foe(p: Vector2, flash := 0.0, col := Color(0.55, 0.15, 0.12)) -> void:
		draw_circle(p + Vector2(0, 14), 15.0, Color(0, 0, 0, 0.3))
		draw_circle(p, 17.0, col.lerp(Color.WHITE, flash))
		draw_circle(p + Vector2(-6, -4), 3.0, Color(1.0, 0.8, 0.3))
		draw_circle(p + Vector2(6, -4), 3.0, Color(1.0, 0.8, 0.3))

	func _key(c: Vector2, s: String, on := 0.0, w := 44.0) -> void:
		var rc := Rect2(c - Vector2(w * 0.5, 20.0), Vector2(w, 40.0))
		draw_rect(rc, Color(0.2, 0.17, 0.16).lerp(ACC, on))
		draw_rect(rc, Color(0.7, 0.55, 0.4), false, 2.0)
		var f: Font = ThemeDB.fallback_font
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string(f, c + Vector2(-sz.x * 0.5, 7.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 0.85))

	func _mouse(c: Vector2, left := 0.0, right := 0.0) -> void:
		draw_rect(Rect2(c - Vector2(20, 30), Vector2(40, 60)), Color(0.2, 0.17, 0.16))
		draw_rect(Rect2(c - Vector2(20, 30), Vector2(20, 28)), Color(0.2, 0.17, 0.16).lerp(ACC, left))
		draw_rect(Rect2(c + Vector2(0, -30), Vector2(20, 28)), Color(0.2, 0.17, 0.16).lerp(ACC, right))
		draw_rect(Rect2(c - Vector2(20, 30), Vector2(40, 60)), Color(0.7, 0.55, 0.4), false, 2.0)

	func _text(p: Vector2, s: String, sz: int, col: Color) -> void:
		draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func _pulse(period: float, width := 0.35) -> float:
		var k := fmod(t, period) / period
		return clampf(1.0 - absf(k - 0.15) / width, 0.0, 1.0)

	func _bar(rc: Rect2, k: float, col: Color) -> void:
		draw_rect(rc, Color(0.05, 0.04, 0.04))
		draw_rect(Rect2(rc.position, Vector2(rc.size.x * clampf(k, 0.0, 1.0), rc.size.y)), col)
		draw_rect(rc, Color(0.6, 0.45, 0.3), false, 1.5)

	func _item(c: Vector2, rar: int, s := 1.0) -> void:
		var col: Color = Items.RARITY_COLOR[rar]
		draw_rect(Rect2(c - Vector2(14, 14) * s, Vector2(28, 28) * s), Color(0.15, 0.12, 0.11))
		draw_rect(Rect2(c - Vector2(14, 14) * s, Vector2(28, 28) * s), col, false, 2.0)
		draw_line(c + Vector2(-8, 8) * s, c + Vector2(8, -8) * s, col, 4.0 * s)

	func _beam(c: Vector2, rar: int) -> void:
		var col: Color = Items.RARITY_COLOR[rar]
		var a := 0.35 + 0.15 * sin(t * 4.0 + c.x)
		draw_rect(Rect2(c + Vector2(-6, -70), Vector2(12, 70)), Color(col, a * 0.5))
		_item(c, rar, 0.7)

	# --- demos
	func _d_move() -> void:
		var c := size * 0.5
		var ph := fmod(t, 4.0)
		var seg := int(ph)
		var f := ph - float(seg)
		var corners := [Vector2(-110, -50), Vector2(110, -50), Vector2(110, 40), Vector2(-110, 40)]
		var a: Vector2 = corners[seg]
		var b: Vector2 = corners[(seg + 1) % 4]
		var p := c + Vector2(0, -20) + a.lerp(b, f)
		for i in 5:
			draw_circle(p - (b - a).normalized() * float(i + 1) * 14.0, 4.0 - float(i) * 0.6, Color(0.4, 0.35, 0.3, 0.5))
		_hero(p, 1.0 if b.x >= a.x else -1.0)
		var kc := Vector2(size.x - 100, size.y - 70)
		_key(kc + Vector2(0, -44), "W", 1.0 if seg == 3 else 0.0)
		_key(kc + Vector2(-48, 0), "A", 1.0 if seg == 2 else 0.0)
		_key(kc + Vector2(0, 0), "S", 1.0 if seg == 1 else 0.0)
		_key(kc + Vector2(48, 0), "D", 1.0 if seg == 0 else 0.0)

	func _d_attack() -> void:
		var hp := Vector2(150, size.y * 0.55)
		var fp := Vector2(330, size.y * 0.55)
		var k := fmod(t, 0.9) / 0.9
		_hero(hp)
		_foe(fp + Vector2(sin(k * 30.0) * 3.0 * (1.0 if k < 0.3 else 0.0), 0), 0.8 if k < 0.2 and k > 0.05 else 0.0)
		if k > 0.05 and k < 0.3:
			var a := (k - 0.05) / 0.25
			draw_arc(hp + Vector2(20, -6), 52.0, -1.0 + a * 0.5, -0.1 + a * 1.1, 14, Color(1.0, 0.85, 0.5, 1.0 - a), 6.0)
		if k > 0.12:
			var a2 := (k - 0.12) / 0.88
			_text(fp + Vector2(-10, -30 - a2 * 36.0), str(18 + int(t / 0.9) % 7), 22, Color(1, 0.9, 0.5, 1.0 - a2))
		_bar(Rect2(fp.x - 30, fp.y - 38, 60, 6), 1.0 - fmod(t / 0.9, 5.0) / 5.0, Color(0.8, 0.2, 0.15))
		_mouse(Vector2(size.x - 100, size.y - 60), 1.0 if k < 0.3 else 0.0, 0.0)
		_text(Vector2(size.x - 148, size.y - 14), "hold  to attack", 14, Color(0.8, 0.7, 0.6))

	func _d_skills() -> void:
		var hp := Vector2(110, size.y * 0.5)
		_hero(hp)
		var ph := fmod(t, 4.2)
		var idx := int(ph / 1.4)
		var k := fmod(ph, 1.4) / 1.4
		for i in 3:
			_foe(Vector2(300 + float(i) * 44.0, size.y * 0.5 + (float(i) - 1.0) * 46.0), 0.7 if (k > 0.35 and k < 0.55) else 0.0)
		match idx:
			0: # Q: ring
				if k < 0.6:
					draw_arc(hp, 20.0 + k * 300.0, 0, TAU, 40, Color(1.0, 0.7, 0.3, 1.0 - k / 0.6), 6.0)
			1: # E: bolt
				if k < 0.6:
					var x := hp.x + 20.0 + k * 420.0
					draw_line(Vector2(x - 40, hp.y), Vector2(x, hp.y), Color(0.6, 0.8, 1.0), 6.0)
					draw_circle(Vector2(x, hp.y), 9.0, Color(0.8, 0.95, 1.0))
			2: # R: nova
				draw_circle(hp + Vector2(180, 0), 20.0 + k * 200.0, Color(1.0, 0.4, 0.15, 0.4 * (1.0 - k)))
		var names := ["Q", "E", "R"]
		for i in 3:
			var c := Vector2(size.x * 0.5 - 70.0 + float(i) * 70.0, size.y - 34)
			_key(c, names[i], 1.0 if i == idx and k < 0.25 else 0.0)
			if i != idx or k < 0.25:
				continue
			draw_rect(Rect2(c + Vector2(-22, -20), Vector2(44, 40 * (1.0 - k))), Color(0, 0, 0, 0.55))

	func _d_dodge() -> void:
		var k := fmod(t, 2.0) / 2.0
		var base := Vector2(size.x * 0.5, size.y * 0.55)
		var shot := Vector2(size.x - k * (size.x + 60.0) * 1.25, base.y)
		draw_circle(shot, 9.0, Color(1.0, 0.4, 0.2))
		draw_line(shot, shot + Vector2(40, 0), Color(1.0, 0.5, 0.2, 0.5), 5.0)
		var roll := k > 0.5 and k < 0.72
		var hp := base
		if roll:
			var a := (k - 0.5) / 0.22
			hp = base + Vector2(0, -70.0 * sin(a * PI))
			for i in 3:
				_hero(base + Vector2(0, -70.0 * sin(maxf(0.0, a - float(i) * 0.15) * PI)), 1.0, 0.18)
		_hero(hp, 1.0, 0.5 if roll else 1.0)
		_key(Vector2(size.x - 110, size.y - 34), "SPACE", 1.0 if roll else 0.0, 110.0)

	func _d_potion() -> void:
		var k := fmod(t, 4.0) / 4.0
		var hp_k := 0.3 if k < 0.35 else minf(1.0, 0.3 + (k - 0.35) * 2.4)
		var c := Vector2(size.x * 0.3, size.y * 0.5)
		draw_circle(c, 56.0, Color(0.05, 0.04, 0.04))
		draw_arc(c, 56.0, 0, TAU, 40, Color(0.6, 0.45, 0.3), 3.0)
		draw_rect(Rect2(c.x - 50, c.y + 50 - 100.0 * hp_k, 100, 100.0 * hp_k), Color(0.75, 0.12, 0.12, 0.9))
		draw_arc(c, 56.0, 0, TAU, 40, Color(0.6, 0.45, 0.3), 3.0)
		_text(c + Vector2(-34, 90), "health", 15, Color(0.8, 0.7, 0.6))
		var pc := Vector2(size.x * 0.68, size.y * 0.5)
		_key(pc, "F", 1.0 if k > 0.3 and k < 0.4 else 0.0)
		var cd := clampf((k - 0.4) / 0.55, 0.0, 1.0)
		if k > 0.4:
			draw_arc(pc + Vector2(0, 80), 28.0, -PI / 2, -PI / 2 + TAU * (1.0 - cd), 30, Color(0.6, 0.8, 1.0), 5.0)
			_text(pc + Vector2(-50, 140), "cooldown", 15, Color(0.8, 0.7, 0.6))
		else:
			draw_arc(pc + Vector2(0, 80), 28.0, 0, TAU, 30, Color(0.4, 1.0, 0.5), 5.0)
			_text(pc + Vector2(-34, 140), "ready", 15, Color(0.6, 1.0, 0.6))

	func _d_loot() -> void:
		var ph := fmod(t, 4.0)
		var hx := 70.0 + clampf(ph / 3.0, 0.0, 1.0) * 330.0
		var hp := Vector2(hx, size.y * 0.62)
		var drops := [Vector2(170, size.y * 0.62), Vector2(270, size.y * 0.62), Vector2(370, size.y * 0.62)]
		for i in 3:
			if hx < drops[i].x - 8.0:
				_beam(drops[i], i + 1 if i < 2 else 3)
		_hero(hp)
		var names := ["common", "magic", "rare", "legendary"]
		for i in 4:
			var c := Vector2(60.0 + float(i) * 120.0, 34.0)
			_item(c, i, 0.6)
			_text(c + Vector2(20, 5), names[i], 13, Items.RARITY_COLOR[i])

	func _d_inventory() -> void:
		var k := fmod(t, 4.0) / 4.0
		_key(Vector2(54, 40), "I", 1.0 if k < 0.15 else 0.0)
		var x0 := 120.0
		for i in 12:
			var c := Vector2(x0 + float(i % 6) * 44.0, 56.0 + float(i / 6) * 44.0)
			draw_rect(Rect2(c - Vector2(19, 19), Vector2(38, 38)), Color(0.14, 0.12, 0.11))
			draw_rect(Rect2(c - Vector2(19, 19), Vector2(38, 38)), Color(0.4, 0.3, 0.22), false, 1.5)
			if i == 2 or i == 8:
				_item(c, 1 + (i % 3))
		var eq := Vector2(x0 + 360.0, 100.0)
		draw_rect(Rect2(eq - Vector2(30, 30), Vector2(60, 60)), Color(0.14, 0.12, 0.11))
		draw_rect(Rect2(eq - Vector2(30, 30), Vector2(60, 60)), Color(0.4, 0.3, 0.22), false, 1.5)
		var a := clampf((k - 0.35) / 0.4, 0.0, 1.0)
		var from := Vector2(x0 + 2.0 * 44.0, 56.0)
		_item(from.lerp(eq, a), 2, 1.0 + a * 0.4)
		if a >= 1.0:
			_text(eq + Vector2(-34, 52), "equipped", 14, Color(0.6, 1.0, 0.6))
		_bar(Rect2(60, size.y - 50, 380, 10), 0.7 - k * 0.1, Color(0.8, 0.6, 0.3))
		_text(Vector2(60, size.y - 58), "durability", 14, Color(0.8, 0.7, 0.6))

	func _d_interact() -> void:
		var k := fmod(t, 3.0) / 3.0
		var hx := 90.0 + minf(k / 0.4, 1.0) * 150.0
		_hero(Vector2(hx, size.y * 0.55))
		draw_rect(Rect2(size.x * 0.6 - 24, size.y * 0.55 - 20, 48, 40), Color(0.4, 0.28, 0.18))
		draw_rect(Rect2(size.x * 0.6 - 24, size.y * 0.55 - 20, 48, 40), Color(0.8, 0.6, 0.3), false, 2.0)
		if k > 0.4:
			_key(Vector2(size.x * 0.6, size.y * 0.55 - 60), "G", 1.0 if k > 0.6 and k < 0.7 else 0.0)
			_text(Vector2(size.x * 0.6 - 30, size.y * 0.55 - 92), "Open", 16, Color(1, 0.9, 0.6))

	func _d_vendor() -> void:
		var k := fmod(t, 4.0) / 4.0
		draw_rect(Rect2(60, 60, 200, 110), Color(0.13, 0.1, 0.09))
		draw_rect(Rect2(60, 60, 200, 110), Color(0.5, 0.35, 0.2), false, 2.0)
		_text(Vector2(74, 90), "Hild  ·  Smith", 18, Color(1, 0.85, 0.6))
		for i in 3:
			_item(Vector2(96.0 + float(i) * 52.0, 130), i)
		_text(Vector2(300, 100), "gold", 18, Color(1.0, 0.85, 0.3))
		var g := 1250 - int(k * 3.0) * 120
		_text(Vector2(300, 130), str(g), 26, Color(1.0, 0.85, 0.3))
		draw_circle(Vector2(390, 120) + Vector2(sin(t * 5.0) * 3.0, 0), 8.0, Color(1.0, 0.8, 0.2))
		_text(Vector2(300, 180), "buy · sell · repair", 16, Color(0.8, 0.7, 0.6))

	func _d_stash() -> void:
		var k := fmod(t, 3.0) / 3.0
		draw_rect(Rect2(size.x * 0.5 - 60, 70, 120, 90), Color(0.3, 0.2, 0.13))
		draw_rect(Rect2(size.x * 0.5 - 60, 70, 120, 30), Color(0.4, 0.28, 0.17))
		draw_rect(Rect2(size.x * 0.5 - 60, 70, 120, 90), Color(0.8, 0.6, 0.3), false, 2.0)
		var a := clampf(k * 1.5, 0.0, 1.0)
		_item(Vector2(60, 190).lerp(Vector2(size.x * 0.5, 110), a), 2, 1.0 - a * 0.4)
		_text(Vector2(size.x * 0.5 - 62, 190), "safe between runs", 15, Color(0.8, 0.7, 0.6))

	func _d_quest() -> void:
		var k := fmod(t, 4.0) / 4.0
		draw_rect(Rect2(30, 24, 220, 70), Color(0, 0, 0, 0.35))
		_text(Vector2(40, 48), "The Cellar Door", 18, Color(1.0, 0.85, 0.5))
		_text(Vector2(40, 74), "Find the way down  0/1", 15, Color(0.8, 0.75, 0.7))
		var hp := Vector2(90.0 + k * 300.0, size.y * 0.7)
		for i in 12:
			var f := float(i) / 12.0
			draw_circle(Vector2(90.0 + f * 330.0, size.y * 0.7 - sin(f * PI) * 30.0), 3.0, Color(1.0, 0.85, 0.4, 0.8 if fmod(f * 12.0 - t * 4.0, 3.0) < 1.5 else 0.25))
		_hero(hp)
		draw_circle(Vector2(430, size.y * 0.7 - 0.0), 12.0, Color(1.0, 0.8, 0.3, 0.5 + 0.3 * sin(t * 4.0)))
		_key(Vector2(size.x - 60, 44), "J", 1.0 if k < 0.1 else 0.0)

	func _d_chest() -> void:
		var k := fmod(t, 3.0) / 3.0
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		draw_rect(Rect2(c - Vector2(36, 18), Vector2(72, 38)), Color(0.4, 0.27, 0.15))
		var lid := 0.0 if k < 0.35 else -22.0
		draw_rect(Rect2(c + Vector2(-36, -34 + lid * 0.4), Vector2(72, 18)), Color(0.5, 0.35, 0.2))
		draw_rect(Rect2(c - Vector2(36, 18), Vector2(72, 38)), Color(0.85, 0.65, 0.3), false, 2.0)
		if k > 0.35:
			var a := (k - 0.35) / 0.65
			_item(c + Vector2(-30.0 + a * 10.0, -40 - sin(a * PI) * 60.0), 2)
			_item(c + Vector2(34.0 + a * 20.0, -30 - sin(a * PI) * 40.0), 1, 0.8)
			draw_circle(c + Vector2(0, -20), 30.0 * (1.0 - a), Color(1.0, 0.8, 0.3, 0.4 * (1.0 - a)))
		_key(c + Vector2(-110, -10), "G", 1.0 if k > 0.28 and k < 0.38 else 0.0)

	func _d_waypoint() -> void:
		var k := fmod(t, 5.0) / 5.0
		var c1 := Vector2(120, size.y * 0.62)
		var c2 := Vector2(size.x - 120, size.y * 0.62)
		for c in [c1, c2]:
			draw_arc(c, 34.0, 0, TAU, 30, Color(0.4, 0.7, 1.0, 0.8), 3.0)
			draw_circle(c, 10.0, Color(0.5, 0.8, 1.0, 0.8))
		if k < 0.4:
			_hero(c1 + Vector2(-60, 0))
			draw_circle(c1, 34.0 * (k / 0.4), Color(0.4, 0.7, 1.0, 0.3))
		else:
			var a := clampf((k - 0.4) / 0.3, 0.0, 1.0)
			var p := c1.lerp(c2, a)
			draw_circle(p, 18.0 + sin(a * PI) * 12.0, Color(0.5, 0.8, 1.0, 0.5))
			_hero(c2 + Vector2(-60, 0) if a >= 1.0 else p, 1.0, 0.4 if a < 1.0 else 1.0)
		_text(Vector2(c1.x - 40, c1.y + 60), "visited", 14, Color(0.6, 0.85, 1.0))

	func _d_recall() -> void:
		var k := fmod(t, 5.0) / 5.0
		var c := Vector2(size.x * 0.35, size.y * 0.58)
		var ch := clampf(k / 0.6, 0.0, 1.0)
		draw_arc(c, 40.0, 0, TAU, 30, Color(0.4, 0.8, 1.0, 0.5), 3.0)
		draw_arc(c, 40.0, -PI / 2, -PI / 2 + TAU * ch, 30, Color(0.8, 0.95, 1.0), 6.0)
		if k < 0.7:
			_hero(c)
		else:
			var a := (k - 0.7) / 0.3
			draw_line(c + Vector2(0, -20), c + Vector2(0, -160), Color(0.7, 0.9, 1.0, 1.0 - a), 8.0)
		_key(Vector2(size.x * 0.75, size.y * 0.4), "T", 1.0 if k < 0.1 else 0.0)
		_text(Vector2(size.x * 0.75 - 70, size.y * 0.4 + 46), "3 second channel", 15, Color(0.8, 0.7, 0.6))
		_text(Vector2(size.x * 0.75 - 70, size.y * 0.4 + 68), "damage interrupts", 15, Color(1.0, 0.6, 0.5))

	func _d_map() -> void:
		var k := fmod(t, 5.0) / 5.0
		var mr := Rect2(70, 24, size.x - 140, size.y - 48)
		draw_rect(mr, Color(0.07, 0.06, 0.06))
		draw_rect(mr, Color(0.6, 0.45, 0.3), false, 2.0)
		for i in 4:
			for j in 3:
				var rc := Rect2(mr.position + Vector2(24 + i * 90, 20 + j * 56), Vector2(76, 44))
				var found := float(i + j) / 6.0 < clampf(k * 1.4, 0.0, 1.0) * 0.8
				draw_rect(rc, Color(0.3, 0.22, 0.14, 0.7) if found else Color(0, 0, 0, 0), true)
				draw_rect(rc, Color(0.6, 0.45, 0.3, 0.8), false, 1.5)
		if k > 0.5:
			var m := mr.position + Vector2(300, 110)
			draw_colored_polygon(PackedVector2Array([m, m + Vector2(-8, -18), m + Vector2(8, -18)]), Color(1.0, 0.85, 0.3))
			draw_circle(m + Vector2(0, -22), 7.0, Color(1.0, 0.85, 0.3))
		_key(Vector2(34, 44), "Tab", 1.0 if k < 0.1 else 0.0, 56.0)
		_mouse(Vector2(size.x - 34, size.y - 60), 1.0 if k > 0.46 and k < 0.52 else 0.0)

	func _d_skilltree() -> void:
		var k := fmod(t, 5.0) / 5.0
		var c := size * 0.5
		var pts := [c, c + Vector2(-70, -50), c + Vector2(70, -50), c + Vector2(-130, -80), c + Vector2(-70, 30), c + Vector2(130, -80), c + Vector2(70, 30)]
		var links := [[0, 1], [0, 2], [1, 3], [1, 4], [2, 5], [2, 6]]
		var n := int(k * 8.0)
		for l in links:
			draw_line(pts[l[0]], pts[l[1]], Color(0.5, 0.4, 0.3, 0.6), 3.0)
		for i in pts.size():
			var on := i <= n
			draw_circle(pts[i], 16.0, Color(0.9, 0.5, 0.2) if on else Color(0.18, 0.15, 0.13))
			draw_arc(pts[i], 16.0, 0, TAU, 20, Color(0.8, 0.65, 0.4), 2.0)
		_key(Vector2(44, 40), "K", 1.0 if k < 0.1 else 0.0)

	func _d_durability() -> void:
		var k := fmod(t, 4.0) / 4.0
		_item(Vector2(100, size.y * 0.5), 2, 1.6)
		_bar(Rect2(150, size.y * 0.5 - 8, 240, 16), 1.0 - k * 0.9, Color(0.8, 0.6, 0.3).lerp(Color(0.8, 0.15, 0.1), k))
		_text(Vector2(150, size.y * 0.5 - 18), "durability", 15, Color(0.8, 0.7, 0.6))
		if k > 0.85:
			_text(Vector2(150, size.y * 0.5 + 44), "broken: repair at the smith", 17, Color(1.0, 0.5, 0.4))
		else:
			_text(Vector2(150, size.y * 0.5 + 44), "wears down with every death", 16, Color(0.8, 0.7, 0.6))

	func _d_champion() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		for i in 4:
			var a := t * 0.8 + float(i) * TAU / 4.0
			_foe(c + Vector2(cos(a), sin(a)) * 90.0 * Vector2(1, 0.6), 0.0, Color(0.4, 0.12, 0.1))
		_foe(c, 0.0, Color(0.7, 0.15, 0.4))
		draw_arc(c, 30.0, 0, TAU, 30, Color(1.0, 0.8, 0.3, 0.6 + 0.3 * sin(t * 4.0)), 3.0)
		_text(c + Vector2(-60, -48), "Champion", 18, Color(1.0, 0.8, 0.3))

	func _d_difficulty() -> void:
		var k := fmod(t, 4.0) / 4.0
		var lv := 1 + int(k * 4.0)
		_text(Vector2(40, 60), "Difficulty  %d / 20" % (lv + 2), 24, Game.C_GOLD)
		for i in 20:
			draw_rect(Rect2(40.0 + float(i) * 22.0, 80, 18, 24), Color(0.9, 0.45, 0.2) if i < lv + 2 else Color(0.2, 0.17, 0.15))
		_text(Vector2(40, 140), "+ experience     + gold     + magic find", 17, Color(0.6, 1.0, 0.6))
		_text(Vector2(40, 170), "enemies hit harder and last longer", 17, Color(1.0, 0.6, 0.5))
		_text(Vector2(40, 200), "one step at a time, then a cooldown", 15, Color(0.8, 0.7, 0.6))

	func _d_hardcore() -> void:
		var k := fmod(t, 4.0) / 4.0
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_rect(Rect2(c + Vector2(-26, -50), Vector2(52, 80)), Color(0.25, 0.23, 0.24))
		draw_circle(c + Vector2(0, -50), 26.0, Color(0.25, 0.23, 0.24))
		_text(c + Vector2(-14, -34), "RIP", 18, Color(0.7, 0.68, 0.7))
		_text(Vector2(40, 40), "Hall of the Fallen", 18, Color(1.0, 0.8, 0.5))
		draw_circle(c + Vector2(0, 70), 8.0 + sin(t * 3.0), Color(1.0, 0.5, 0.15, 0.4 + 0.3 * k))
		_text(Vector2(40, size.y - 20), "permanent death  ·  +25% xp  ·  +20% gold  ·  +20 magic find", 15, Color(0.8, 0.7, 0.6))
