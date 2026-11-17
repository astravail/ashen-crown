extends Node
## Renders a few lines with the built-in voice to wav files: godot --headless --path game -- --voicetest=/tmp/v

var main: Node


func _ready() -> void:
	var dir := "/tmp/voice"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--voicetest="):
			dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var lines := {"elder": "Survivor. Come to the fire. I have something to ask of you.", "smith": "Steel does not mend itself. Show me what you have.",
		"mystic": "I have seen how you die. Want to hear?", "boss": "You carry my fire. Did you think I would not feel it?", "player": "Now that is a weapon."}
	for who in lines.keys():
		var sp: Dictionary = Voice.SPEAKERS[who]
		var t0 := Time.get_ticks_msec()
		var s: AudioStreamWAV = Voice.synth(lines[who], sp)
		var secs := float(s.data.size()) / 2.0 / Voice.SR
		print("[voice] %s: %.1fs of audio in %d ms" % [who, secs, Time.get_ticks_msec() - t0])
		s.save_to_wav("%s/%s.wav" % [dir, who])
	get_tree().quit()
