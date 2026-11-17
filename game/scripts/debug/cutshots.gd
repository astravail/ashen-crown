extends Node
## Saves a still of every cutscene shot: godot --path game -- --cutshots=/tmp/cuts

var main: Node
var dir := "/tmp/cuts"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cutshots="):
			dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.5).timeout
	for id in Cutscene.SCENES.keys():
		var shots: int = 4 if id == "intro" else 1
		for s in shots:
			var cs := Cutscene.new()
			main.cut_layer.add_child(cs)
			cs.play(id)
			cs.idx = s
			cs.t = 2.5
			cs.shot_t = 2.5
			cs.clock = 6.0
			cs.fade = 1.0
			for f in 6:
				await get_tree().process_frame
				cs.t = 2.5
				cs.fade = 1.0
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [dir, id, s])
			cs.queue_free()
	print("[cutshots] done")
	get_tree().quit()
