extends Node
## Saves stills of the main screens: godot --path game -- --uishots=DIR  (needs a window)

var main: Node
var dir := "/tmp/ui"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uishots="):
			dir = a.substr(10)
	DirAccess.make_dir_recursive_absolute(dir)
	_run()


func _shot(n: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	await _wait(1.0)
	main._go_title()
	await _wait(3.0)
	main.fade.color.a = 0.0
	await _wait(0.5)
	await _shot("title")
	main.menus.show_class_select()
	await _wait(0.5)
	await _shot("classes")
	main.menus._show_locked_class("crownbearer")
	await _wait(0.3)
	await _shot("locked")
	main.menus.show_customize("knight")
	await _wait(0.5)
	await _shot("customize")
	main.menus.show_settings(func(): pass)
	await _wait(0.5)
	await _shot("settings")
	main.menus.show_keybinds(func(): pass)
	await _wait(0.5)
	await _shot("keybinds")
	main.menus.show_whats_new(func(): pass)
	await _wait(0.5)
	await _shot("whatsnew")
	main.menus.show_title()
	await _wait(0.5)
	await _shot("title2")
	Game.new_run("knight")
	Game.hero_name = "Aldric"
	main._carry = {}
	await main._start_overworld()
	await _wait(2.5)
	await _shot("village")
	Game.gold = 4200
	for i in 10:
		Game.add_item(Items.roll_drop("shop", 6, 0.0))
	Game.equip(0)
	Game.equip(1)
	main.panels.world = main.world
	main.panels.show_inventory("inv", "")
	await _wait(0.4)
	await _shot("inventory")
	main._open_panel(func(): main.panels.show_inventory("inv"))
	await _wait(0.2)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_I
	ev.keycode = KEY_I
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.4)
	print("[uishots] inventory closed by I: ", not main.panels.is_open(), " paused=", get_tree().paused)
	main.panels.close()
	main.panels.show_skills()
	await _wait(0.4)
	await _shot("skills")
	main.panels.close()
	main.panels.show_quests(false)
	await _wait(0.4)
	await _shot("quests")
	main.panels.close()
	for id in Tutorial.TIPS.keys():
		main.tutorial.show_tip(id)
		await _wait(1.6)
		await _shot("tip_" + id)
		main.tutorial.dismiss()
	main.menus.show_pause()
	await _wait(0.4)
	await _shot("pause")
	print("[uishots] done")
	get_tree().quit()
