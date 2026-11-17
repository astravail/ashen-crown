extends Node
## Voice lines: spoken with the system's text-to-speech when there is one, always shown as subtitles.
## Swap `speak()` for audio files later if real recordings are added.

signal subtitle(who: String, text: String)

const SPEAKERS := {
	"player": {"name": "", "pitch": 1.0, "rate": 1.0},
	"elder": {"name": "Sister Maren", "pitch": 0.9, "rate": 0.85},
	"smith": {"name": "Hild", "pitch": 0.55, "rate": 0.9},
	"mystic": {"name": "Veyra", "pitch": 1.5, "rate": 0.9},
	"boss": {"name": "", "pitch": 0.1, "rate": 0.7},
	"narrator": {"name": "", "pitch": 0.7, "rate": 0.8},
}

## Barks by class and situation.
const BARKS := {
	"knight": {
		"levelup": ["Stronger. Still standing.", "The ash makes steel of us."],
		"legendary": ["Now that is a weapon.", "Aldric would have wanted this."],
		"lowhp": ["Not yet.", "I have taken worse."],
		"potion": ["That will do.", "Back on my feet."],
		"chest": ["Let us see what the dead left.", "Mine now."],
		"trap": ["A trap. Of course.", "Stand and fight."],
		"quest_done": ["That is one debt paid.", "Done. Back to the village."],
		"waypoint": ["A way home. Good.", "The road is open."],
		"full": ["I cannot carry more.", "My pack is full."],
		"broken": ["My gear is broken. I need the smith.", "This will not hold another fight."],
		"recall": ["Back to Cinderfall.", "Time to rest."],
		"boss_dead": ["It is finished.", "Rest now."],
	},
	"gravecaller": {
		"levelup": ["The dead whisper approval.", "More power. More dead."],
		"legendary": ["Even the bones gasp at that.", "A relic worth burying for."],
		"lowhp": ["I am not ready to join you.", "Stay back, little ghosts."],
		"potion": ["Bitter, but it works.", "Life returns."],
		"chest": ["The dead hoard such lovely things.", "They will not mind."],
		"trap": ["Ambush. How rude.", "Rise, my children."],
		"quest_done": ["They can rest, now.", "Another soul put to bed."],
		"waypoint": ["I know this place's grief.", "A door between the living and the road."],
		"full": ["No room. Even for you.", "Too much to carry."],
		"broken": ["My vestments are in tatters.", "Everything I own is breaking."],
		"recall": ["Home, to the fire.", "The village calls."],
		"boss_dead": ["Even kings lie down.", "Sleep, Aldric."],
	},
	"pyrewitch": {
		"levelup": ["I burn brighter.", "More. More fire."],
		"legendary": ["Oh, that is gorgeous.", "Mine. Do not touch."],
		"lowhp": ["I am not done burning!", "Not like this."],
		"potion": ["Hot and horrible. Good.", "That helps."],
		"chest": ["Shiny things, come to me.", "Let us see."],
		"trap": ["Oh, you want to dance?", "Fine. Burn."],
		"quest_done": ["Paid in full.", "That was fun. Mostly."],
		"waypoint": ["Warmth. Finally.", "Another way home."],
		"full": ["I am full up.", "No more room."],
		"broken": ["My things are falling apart.", "I need a smith."],
		"recall": ["Back we go.", "I need a drink."],
		"boss_dead": ["It's quiet now.", "He burned out."],
	},
}

const NPC_LINES := {
	"elder": {
		"greet": ["The ash does not wait, wanderer.", "Sit by the fire. Then bleed for us."],
		"quest_done": ["You did what the guard could not."],
		"farewell": ["Come back alive."],
	},
	"smith": {
		"greet": ["Steel does not mend itself.", "Show me what you have."],
		"repair": ["Good as it will get."],
		"farewell": ["Hit them harder."],
	},
	"mystic": {
		"greet": ["I have seen how you die. Want to hear?", "Trinkets for the damned."],
		"heal": ["There. Breathe."],
		"farewell": ["The ash remembers you."],
	},
}

var _last := {}
var _layer: CanvasLayer
var _sub: SubtitleBox
var _voices: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 18
	add_child(_layer)
	_sub = SubtitleBox.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_sub)
	if DisplayServer.get_name() != "headless":
		_voices = DisplayServer.tts_get_voices_for_language("en")


func has_voice() -> bool:
	return not _voices.is_empty()


## A short line triggered by something happening. Rate-limited per situation so it stays special.
func bark(who: String, key: String, fallback := "", cooldown := 25.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var id := "%s:%s" % [who, key]
	if now - float(_last.get(id, -999.0)) < cooldown:
		return
	var lines: Array = []
	if who == "player":
		lines = (BARKS.get(Game.class_id, {}) as Dictionary).get(key, [])
	else:
		lines = (NPC_LINES.get(who, {}) as Dictionary).get(key, [])
	var text := fallback
	if not lines.is_empty():
		text = lines[randi() % lines.size()]
	if text == "":
		return
	_last[id] = now
	say(who, text)


func say(who: String, text: String, hold := -1.0) -> void:
	if not Game.settings.get("voice", true) and not Game.settings.get("subtitles", true):
		return
	var sp: Dictionary = SPEAKERS.get(who, SPEAKERS.narrator)
	var name_txt: String = sp.name if who != "player" else Game.hero_name
	if Game.settings.get("subtitles", true):
		_sub.show_line(name_txt, text, hold if hold > 0.0 else 2.0 + text.length() * 0.055)
	subtitle.emit(name_txt, text)
	speak(text, sp)


func speak(text: String, sp: Dictionary) -> void:
	if not Game.settings.get("voice", true) or _voices.is_empty():
		return
	DisplayServer.tts_stop()
	var vol := int(clampf(float(Game.settings.get("master", 0.8)) * 100.0, 0.0, 100.0))
	DisplayServer.tts_speak(text, _voices[0], vol, float(sp.pitch), float(sp.rate), 0, true)


func stop() -> void:
	if not _voices.is_empty():
		DisplayServer.tts_stop()
	_sub.clear()


class SubtitleBox extends Control:
	var who := ""
	var text := ""
	var t := 0.0
	var life := 0.0

	func show_line(w: String, s: String, dur: float) -> void:
		who = w
		text = s
		t = 0.0
		life = dur

	func clear() -> void:
		life = 0.0
		t = 0.0
		queue_redraw()

	func _process(dt: float) -> void:
		if t < life:
			t += dt
			queue_redraw()

	func _draw() -> void:
		if t >= life or text == "":
			return
		var a := clampf(minf(t / 0.2, (life - t) / 0.4), 0.0, 1.0)
		var f := Game.font_body_bold
		var fs := 26
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := size.x * 0.5
		var y := size.y - 215.0
		draw_rect(Rect2(cx - tw * 0.5 - 24, y - 34, tw + 48, 56 if who != "" else 48), Color(0, 0, 0, 0.55 * a))
		if who != "":
			var nw := Game.font_display.get_string_size(who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(Game.font_display, Vector2(cx - nw * 0.5, y - 14), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.6, 0.3, a))
		draw_string(f, Vector2(cx - tw * 0.5, y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.9, 0.82, a))
