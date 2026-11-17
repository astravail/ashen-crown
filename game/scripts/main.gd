extends Node
## Flow: title, character, one continuous world, interiors you walk into, ending.

var world: World
var overworld: World
var hud: Hud
var menus: Menus
var panels: Panels
var fade: ColorRect
var zone_card: Control
var ui_layer: CanvasLayer
var hud_layer: CanvasLayer
var cut_layer: CanvasLayer
var env: Environment
var tutorial: Tutorial
var _overlay := ""
var _carry := {}
var _busy := false
var _door_pos := Vector2.ZERO


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
	panels = Panels.new()
	ui_layer.add_child(panels)
	cut_layer = CanvasLayer.new()
	cut_layer.layer = 26
	cut_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cut_layer)
	var top := CanvasLayer.new()
	top.layer = 25
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.016, 0.016, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade)
	zone_card = ZoneCard.new()
	zone_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(zone_card)
	var tut_layer := CanvasLayer.new()
	tut_layer.layer = 20
	tut_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tut_layer)
	tutorial = Tutorial.new()
	tutorial.main = self
	tut_layer.add_child(tutorial)
	menus.tutorial = tutorial
	# Always visible, on every screen: the beta tag and the optional FPS counter.
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	overlay.add_child(FpsCounter.new())
	var beta := BetaTag.new()
	beta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	beta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(beta)

	var relay := InputRelay.new()
	relay.main = self
	relay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(relay)

	menus.start_run.connect(_on_start_run)
	menus.load_character.connect(_on_load_character)
	var autosave := Timer.new()
	autosave.wait_time = 40.0
	autosave.timeout.connect(_autosave)
	add_child(autosave)
	autosave.start()
	menus.resume.connect(_resume)
	menus.abandon.connect(_go_title)
	menus.fragment_chosen.connect(_on_fragment_chosen)
	menus.respawn.connect(_on_respawn)
	menus.ending_chosen.connect(_on_ending_chosen)
	menus.to_title.connect(_go_title)
	panels.closed.connect(_on_panel_closed)
	panels.teleport.connect(_on_teleport)
	Game.gear_changed.connect(_on_gear_changed)
	Game.settings_changed.connect(_apply_env)
	Game.quest_ready.connect(_on_quest_ready)
	Game.quests_changed.connect(func(): if world and world.player: world._set_objective())
	Game.quest_accepted.connect(func(_id): if world and world.player: world.spawn_quest_bosses())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--voicetest"):
			var vt: Node = load("res://scripts/debug/voice_test.gd").new()
			add_child(vt)
			return
		if a.begins_with("--uishots"):
			var us: Node = load("res://scripts/debug/uishots.gd").new()
			us.main = self
			add_child(us)
			return
		if a.begins_with("--cutshots"):
			var cn: Node = load("res://scripts/debug/cutshots.gd").new()
			cn.main = self
			add_child(cn)
			return
		if a.begins_with("--gallery"):
			var gl: Node = load("res://scripts/debug/gallery.gd").new()
			gl.main = self
			add_child(gl)
			return
		if a == "--smoke":
			var sm: Node = load("res://scripts/debug/smoke.gd").new()
			sm.main = self
			add_child(sm)
			return
		if a.begins_with("--bot="):
			var bot: Node = load("res://scripts/debug/bot.gd").new()
			bot.main = self
			add_child(bot)
			return
	_go_title()


func _build_environment() -> void:
	env = Environment.new()
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
	env.adjustment_brightness = 1.35
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_apply_env()


func _apply_env() -> void:
	if env:
		env.glow_enabled = bool(Game.settings.get("glow", true))


# ---------------------------------------------------------------- flow

func _go_title() -> void:
	get_tree().paused = false
	_overlay = ""
	Game.in_run = false
	Game.hardcore = false
	Voice.stop()
	await _fade_to(1.0, 0.4)
	panels.clear()
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
	overworld = null
	panels.world = null


func _on_start_run(cls: String) -> void:
	if _busy:
		return
	Game.new_run(cls)
	_carry = {}
	_busy = true
	menus.clear()
	await _fade_to(1.0, 0.5)
	await _play_cutscene("intro")
	_busy = false
	_start_overworld()


func _on_load_character(id: String) -> void:
	if _busy or not Game.load_character(id):
		return
	_carry = Game.player_state
	_busy = true
	menus.clear()
	await _fade_to(1.0, 0.5)
	_busy = false
	_start_overworld()


func _autosave() -> void:
	Game.save_lifetime()
	if world == null or world.attract or world.player == null or world.player.dead or not Game.in_run:
		return
	Game.player_state = world.player.export_state()
	Game.save_character()


func _play_cutscene(id: String) -> void:
	get_tree().paused = true
	var cs := Cutscene.new()
	cut_layer.add_child(cs)
	cs.play(id)
	await cs.finished
	get_tree().paused = false


func _bind_world(w: World) -> void:
	world = w
	panels.world = w
	hud = Hud.new()
	hud.world = w
	hud_layer.add_child(hud)
	w.banner.connect(hud.show_banner)
	if w.has_meta("bound"):
		return
	w.set_meta("bound", true)
	w.level_up.connect(_on_level_up)
	w.fragment_ready.connect(_on_fragment_ready)
	w.player_died.connect(_on_player_died)
	w.boss_defeated.connect(_on_boss_defeated)
	w.npc_talk.connect(_on_npc_talk)
	w.waypoint_open.connect(func(): _open_panel(func(): panels.show_waypoints()))
	w.crown_taken.connect(_on_crown_taken)
	w.door_enter.connect(_enter_interior)
	w.door_exit.connect(_exit_interior)
	w.recall_done.connect(_on_recall_done)
	w.portal_return.connect(_on_portal_return)
	w.act_entered.connect(_on_act_entered)


## The one continuous world: the village and every zone.
func _start_overworld() -> void:
	_busy = true
	get_tree().paused = false
	await _fade_to(1.0, 0.3)
	menus.clear()
	panels.clear()
	_clear_world()
	var w := World.new()
	add_child(w)
	w.setup(-1, false, {"seed": Game.world_seed})
	overworld = w
	if not _carry.is_empty():
		w.player.import_state(_carry)
	_bind_world(w)
	Sfx.music("music_title", 2.0)
	var z: Dictionary = Data.VILLAGE
	(zone_card as ZoneCard).show_card("", z.name, z.line)
	await get_tree().create_timer(2.0).timeout
	_fade_to(0.0, 1.0)
	await get_tree().create_timer(0.6).timeout
	(zone_card as ZoneCard).hide_card()
	_busy = false
	await get_tree().create_timer(1.0).timeout
	if world and world.player and Game.quest_status("story_0") == 0:
		Voice.say("elder", "Survivor. Come to the fire. I have something to ask of you.")


## Bot and debug shim: jump straight to a zone's start.
func _load_zone(idx: int) -> void:
	await _start_overworld()
	var r: Dictionary = world.map.regions[world.map.zone_region[idx]]
	world.teleport_player(Vector2(r.start) * World.CELL + Vector2(32, 32))


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "color:a", a, dur)
	await tw.finished


# ---------------------------------------------------------------- input and overlays

## Forwards input from a node that keeps running while the tree is paused,
## so Esc and the panel keys still close panels and the pause menu.
class InputRelay extends Node:
	var main: Node

	func _unhandled_input(event: InputEvent) -> void:
		main.handle_input(event)


func handle_input(event: InputEvent) -> void:
	if world == null or world.attract or _busy or world.player == null:
		return
	if event.is_action_pressed("pause"):
		if hud and hud.big_map:
			hud.close_map()
		elif panels.is_open():
			panels.close()
		elif _overlay == "":
			_pause()
		elif _overlay == "pause":
			_resume()
		get_viewport().set_input_as_handled()
		return
	if _overlay != "" and _overlay != "panel":
		return
	if event.is_action_pressed("inventory"):
		_toggle_panel("inv", func(): panels.show_inventory("inv"))
	elif event.is_action_pressed("quests"):
		_toggle_panel("quests", func(): panels.show_quests(false))
	elif event.is_action_pressed("skills"):
		_toggle_panel("skills", func(): panels.show_skills())
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle_panel(m: String, open: Callable) -> void:
	if panels.is_open():
		panels.close()
	elif _overlay == "" and not world.player.dead:
		_open_panel(open)


func _open_panel(open: Callable) -> void:
	if _overlay != "" or world.player.dead:
		return
	_overlay = "panel"
	get_tree().paused = true
	open.call()


func _on_panel_closed() -> void:
	_overlay = ""
	get_tree().paused = false
	_autosave()


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


func _on_gear_changed() -> void:
	if world and world.player:
		world.player.recompute()


func _on_level_up() -> void:
	var p := world.player
	hud.show_banner("Level %d" % p.level, "A skill point is waiting  ·  K")


func _on_quest_ready(title: String) -> void:
	_autosave()
	if hud:
		hud.show_banner("Quest complete", "%s  ·  return to Sister Maren" % title)
	Sfx.play("fragment", -6.0)


# ---------------------------------------------------------------- the village folk

func _on_npc_talk(kind: String) -> void:
	tutorial.on_npc(kind)
	match kind:
		"elder":
			Voice.bark("elder", "greet", "", 20.0)
			_open_panel(func(): panels.show_quests(true))
		"smith":
			Voice.bark("smith", "greet", "", 20.0)
			_open_panel(func(): panels.show_inventory("smith", "smith"))
		"mystic":
			Voice.bark("mystic", "greet", "", 20.0)
			_open_panel(func(): panels.show_inventory("mystic", "mystic"))
		"keeper":
			_open_panel(func(): panels.show_inventory("stash"))


# ---------------------------------------------------------------- travel

func _on_teleport(pos: Vector2) -> void:
	_autosave()
	_overlay = "panel"
	await _fade_to(1.0, 0.35)
	if world.interior:
		_exit_interior_now(pos)
	else:
		world.teleport_player(pos)
	_overlay = ""
	get_tree().paused = false
	_fade_to(0.0, 0.5)


func _on_recall_done() -> void:
	var pos: Vector2 = overworld.map.regions[0].pois.waypoint + Vector2(0, 64)
	# the portal left behind leads back to where the hero stood (or to the door, if it was an interior)
	var origin: Vector2 = _door_pos + Vector2(0, 70) if world.interior else world.recall_origin
	await _fade_to(1.0, 0.4)
	if world.interior:
		_exit_interior_now(pos)
	else:
		world.teleport_player(pos)
	world.open_town_portal(origin)
	_fade_to(0.0, 0.6)


func _on_portal_return(pos: Vector2) -> void:
	_autosave()
	await _fade_to(1.0, 0.35)
	world.teleport_player(pos)
	_fade_to(0.0, 0.5)


func _enter_interior(idx: int) -> void:
	if _busy:
		return
	_busy = true
	_door_pos = world.player.global_position
	_carry = world.player.export_state()
	await _fade_to(1.0, 0.4)
	overworld.visible = false
	overworld.process_mode = Node.PROCESS_MODE_DISABLED
	if hud:
		hud.queue_free()
		hud = null
	var w := World.new()
	add_child(w)
	w.setup(idx)
	w.player.import_state(_carry)
	_bind_world(w)
	var zd: Dictionary = Data.ZONES[idx]
	Sfx.ambience(zd.get("ambient", ""))
	(zone_card as ZoneCard).show_card("", zd.name, zd.line)
	await get_tree().create_timer(1.6).timeout
	_fade_to(0.0, 0.8)
	(zone_card as ZoneCard).hide_card()
	_busy = false


func _exit_interior() -> void:
	if _busy or not world.interior:
		return
	_busy = true
	await _fade_to(1.0, 0.4)
	_exit_interior_now(_door_pos + Vector2(0, 70))
	_fade_to(0.0, 0.6)
	_busy = false
	_autosave()


func _exit_interior_now(pos: Vector2) -> void:
	if not world.interior:
		return
	_carry = world.player.export_state()
	if hud:
		hud.queue_free()
		hud = null
	world.queue_free()
	overworld.visible = true
	overworld.process_mode = Node.PROCESS_MODE_INHERIT
	overworld.camera.make_current()
	overworld.player.import_state(_carry)
	overworld.player.hp = maxf(overworld.player.hp, 1.0)
	_bind_world(overworld)
	overworld.teleport_player(pos)
	overworld.cur = -1
	overworld._update_region()
	Sfx.ambience(overworld.zone.get("ambient", ""))


func _on_act_entered(act: int) -> void:
	if act < 0 or act > 5:
		return
	_busy = true
	await _fade_to(1.0, 0.5)
	await _play_cutscene("act%d" % act)
	await _fade_to(0.0, 0.8)
	_busy = false


# ---------------------------------------------------------------- fragments, death, ending

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


func _on_player_died() -> void:
	tutorial.on_death()
	_overlay = "death"
	Game.stat_add("deaths", 1.0)
	Game.save_lifetime()
	if Game.hardcore:
		Game.record_fallen(world.zone.name)
		Game.delete_character(Game.char_id)
		Game.in_run = false
		Game.records.fallen = int(Game.records.fallen) + 1
		Game.records.fallen_best_level = maxi(int(Game.records.fallen_best_level), int(Game.stats.level))
		Game.save_records()
		await get_tree().create_timer(2.2).timeout
		Sfx.music("", 1.0)
		panels.clear()
		menus.show_permadeath(world.zone.name)
		return
	Game.wear_on_death()
	await get_tree().create_timer(1.6).timeout
	if world and world.player.dead:
		Sfx.music("", 1.0)
		panels.clear()
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
	Game.records.best_zone = Data.LAST_ZONE + 1
	Game.save_records()
	Sfx.music("music_title", 3.0)


## The crown is taken only when the player reaches for it, after the loot is gathered.
func _on_crown_taken() -> void:
	_overlay = "ending"
	get_tree().paused = true
	menus.show_ending_choice()


func _on_ending_chosen(choice: String) -> void:
	Sfx.play("fragment" if choice == "shatter" else "roar")
	menus.show_ending(choice)


class BetaTag extends Control:
	func _draw() -> void:
		var txt := Game.beta_label()
		var f := Game.font_display
		draw_string_outline(f, Vector2(14, size.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(14, size.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.62, 0.52, 0.85))


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
