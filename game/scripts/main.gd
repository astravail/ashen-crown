extends Node
## Flow: title → class select → four zones → ending.

var world: World
var hud: Hud
var menus: Menus
var fade: ColorRect
var zone_card: Control
var ui_layer: CanvasLayer
var hud_layer: CanvasLayer
var _overlay := ""
var _carry := {}
var _busy := false


func _ready() -> void:
	World.init_static()
	_build_environment()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	menus = Menus.new()
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(menus)
	var top := CanvasLayer.new()
	top.layer = 20
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.016, 0.016, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade)
	zone_card = ZoneCard.new()
	zone_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(zone_card)

	menus.start_run.connect(_on_start_run)
	menus.resume.connect(_resume)
	menus.abandon.connect(_go_title)
	menus.levelup_chosen.connect(_on_levelup_chosen)
	menus.fragment_chosen.connect(_on_fragment_chosen)
	menus.respawn.connect(_on_respawn)
	menus.ending_chosen.connect(_on_ending_chosen)
	menus.to_title.connect(_go_title)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			var bot: Node = load("res://scripts/debug/bot.gd").new()
			bot.main = self
			add_child(bot)
			return
	_go_title()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------------------------------------------------------------- flow

func _go_title() -> void:
	get_tree().paused = false
	_overlay = ""
	await _fade_to(1.0, 0.4)
	_clear_world()
	world = World.new()
	add_child(world)
	world.setup(0, true)
	menus.show_title()
	Sfx.music("music_title", 2.0)
	Sfx.ambience("")
	_fade_to(0.0, 1.2)


func _clear_world() -> void:
	if hud:
		hud.queue_free()
		hud = null
	if world:
		world.queue_free()
		world = null


func _on_start_run(cls: String) -> void:
	if _busy:
		return
	Game.new_run(cls)
	_carry = {}
	_load_zone(0)


func _load_zone(idx: int) -> void:
	_busy = true
	get_tree().paused = false
	Game.zone_index = idx
	await _fade_to(1.0, 0.6)
	menus.clear()
	_clear_world()
	world = World.new()
	add_child(world)
	world.setup(idx)
	if not _carry.is_empty():
		world.player.import_state(_carry)
	hud = Hud.new()
	hud.world = world
	hud_layer.add_child(hud)
	world.banner.connect(hud.show_banner)
	world.level_up.connect(_on_level_up)
	world.fragment_ready.connect(_on_fragment_ready)
	world.zone_exit.connect(_on_zone_exit)
	world.player_died.connect(_on_player_died)
	world.boss_defeated.connect(_on_boss_defeated)
	Sfx.music("music_combat", 2.0)
	var z: Dictionary = Data.ZONES[idx]
	Sfx.ambience(z.get("ambient", ""))
	(zone_card as ZoneCard).show_card(Data.roman(idx + 1), z.name, z.line)
	await get_tree().create_timer(2.2).timeout
	Sfx.play("wave", -4.0)
	_fade_to(0.0, 1.0)
	await get_tree().create_timer(0.6).timeout
	(zone_card as ZoneCard).hide_card()
	_busy = false


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "color:a", a, dur)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and world and not world.attract and not _busy:
		if _overlay == "":
			_pause()
		elif _overlay == "pause":
			_resume()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	if world.player.dead:
		return
	_overlay = "pause"
	get_tree().paused = true
	menus.show_pause()


func _resume() -> void:
	_overlay = ""
	menus.clear()
	get_tree().paused = false


# ---------------------------------------------------------------- level up

func _on_level_up() -> void:
	if _overlay != "":
		return
	call_deferred("_open_levelup")


func _open_levelup() -> void:
	var p := world.player
	if p.pending_levels <= 0 or p.dead:
		return
	_overlay = "levelup"
	get_tree().paused = true
	menus.show_levelup(p.level - p.pending_levels + 1, _roll_upgrades(p))


func _roll_upgrades(p: Player) -> Array:
	var pool: Array = []
	for u in Data.UPGRADES:
		var cls: String = u.get("cls", "")
		if cls != "" and cls != p.cls:
			continue
		if p.mod(u.id) >= int(u.max):
			continue
		var d: Dictionary = u.duplicate()
		d.rank = p.mod(u.id)
		pool.append(d)
	pool.shuffle()
	# Prefer at least one class upgrade when available
	var out: Array = []
	for u in pool:
		if u.has("cls") and out.is_empty():
			out.append(u)
	for u in pool:
		if out.size() >= 3:
			break
		if not out.has(u):
			out.append(u)
	return out


func _on_levelup_chosen(id: String) -> void:
	var p := world.player
	p.add_mod(id)
	p.pending_levels -= 1
	_overlay = ""
	menus.clear()
	if p.pending_levels > 0:
		_open_levelup()
	else:
		get_tree().paused = false


# ---------------------------------------------------------------- fragments, zones, ending

func _on_fragment_ready() -> void:
	_overlay = "fragment"
	get_tree().paused = true
	var pool: Array = []
	for f in Data.FRAGMENTS:
		if not Game.fragments.has(f.id):
			pool.append(f)
	pool.shuffle()
	menus.show_fragments(pool.slice(0, 3))


func _on_fragment_chosen(id: String) -> void:
	Sfx.play("fragment")
	Game.fragments.append(id)
	world.player.recompute()
	world.claim_fragment_done()
	_overlay = ""
	menus.clear()
	get_tree().paused = false
	if world.player.pending_levels > 0:
		_open_levelup()


func _on_zone_exit() -> void:
	if _busy:
		return
	_carry = world.player.export_state()
	Game.records.best_zone = maxi(int(Game.records.best_zone), Game.zone_index + 1)
	Game.save_records()
	_load_zone(Game.zone_index + 1)


func _on_player_died() -> void:
	_overlay = "death"
	await get_tree().create_timer(1.6).timeout
	if world and world.player.dead:
		Sfx.music("", 1.0)
		menus.show_death(world.zone.name)


func _on_respawn() -> void:
	menus.clear()
	await _fade_to(1.0, 0.4)
	world.respawn_player()
	_overlay = ""
	Sfx.music("music_combat", 1.5)
	_fade_to(0.0, 0.6)


func _on_boss_defeated() -> void:
	Game.records.wins = int(Game.records.wins) + 1
	if float(Game.records.fastest) <= 0.0 or Game.stats.time < float(Game.records.fastest):
		Game.records.fastest = Game.stats.time
	Game.records.best_zone = Data.ZONES.size()
	Game.save_records()
	Sfx.music("music_title", 3.0)
	await get_tree().create_timer(3.5).timeout
	_overlay = "ending"
	get_tree().paused = true
	menus.show_ending_choice()


func _on_ending_chosen(choice: String) -> void:
	Sfx.play("fragment" if choice == "shatter" else "roar")
	menus.show_ending(choice)


class ZoneCard extends Control:
	var a := 0.0
	var numeral := ""
	var title := ""
	var line := ""
	var target := 0.0
	func show_card(n: String, t: String, l: String) -> void:
		numeral = n
		title = t
		line = l
		target = 1.0
	func hide_card() -> void:
		target = 0.0
	func _process(dt: float) -> void:
		a = move_toward(a, target, dt * 1.6)
		queue_redraw()
	func _draw() -> void:
		if a <= 0.0:
			return
		var cx := size.x * 0.5
		var cy := size.y * 0.45
		var f := Game.font_display_bold
		var col := Color(0.95, 0.86, 0.74, a)
		var nw := Game.font_display.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(Game.font_display, Vector2(cx - nw * 0.5, cy - 70), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.85, 0.5, 0.25, a))
		var tw := f.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		draw_string(f, Vector2(cx - tw * 0.5, cy), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 64, col)
		draw_line(Vector2(cx - tw * 0.35, cy + 26), Vector2(cx + tw * 0.35, cy + 26), Color(0.8, 0.45, 0.2, a * 0.8), 1.0)
		var lw := Game.font_italic.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(Game.font_italic, Vector2(cx - lw * 0.5, cy + 70), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.75, 0.7, 0.66, a))
