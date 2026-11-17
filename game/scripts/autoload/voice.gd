extends Node
## Voice lines: spoken with the system's text-to-speech when there is one, always shown as subtitles.
## Swap `speak()` for audio files later if real recordings are added.

signal subtitle(who: String, text: String)

## pitch/rate drive the system TTS when there is one. f0/formant/speed/breath/growl/echo drive the built-in
## synthesiser, which is what you hear when there is not.
const SPEAKERS := {
	"player": {"name": "", "pitch": 1.0, "rate": 1.0, "f0": 120.0, "formant": 1.0, "speed": 1.0, "breath": 0.05, "growl": 0.0, "echo": 0.0},
	"elder": {"name": "Sister Maren", "pitch": 0.9, "rate": 0.85, "f0": 165.0, "formant": 1.04, "speed": 0.82, "breath": 0.12, "growl": 0.0, "echo": 0.0},
	"smith": {"name": "Hild", "pitch": 0.55, "rate": 0.9, "f0": 88.0, "formant": 0.86, "speed": 0.95, "breath": 0.05, "growl": 0.18, "echo": 0.0},
	"mystic": {"name": "Veyra", "pitch": 1.5, "rate": 0.9, "f0": 250.0, "formant": 1.2, "speed": 0.9, "breath": 0.32, "growl": 0.0, "echo": 0.12},
	"boss": {"name": "", "pitch": 0.1, "rate": 0.7, "f0": 58.0, "formant": 0.7, "speed": 0.7, "breath": 0.1, "growl": 0.6, "echo": 0.35},
	"narrator": {"name": "", "pitch": 0.7, "rate": 0.8, "f0": 102.0, "formant": 0.92, "speed": 0.8, "breath": 0.1, "growl": 0.05, "echo": 0.2},
}
const PLAYER_VOICE := {
	"knight": {"f0": 104.0, "formant": 0.94, "speed": 0.98, "growl": 0.08},
	"gravecaller": {"f0": 138.0, "formant": 1.0, "speed": 0.88, "breath": 0.2, "echo": 0.08},
	"pyrewitch": {"f0": 214.0, "formant": 1.14, "speed": 1.08, "breath": 0.1},
}
const SR := 22050
# Vowel formants (F1, F2) in Hz.
const VOWELS := {"a": Vector2(800, 1250), "e": Vector2(520, 1850), "i": Vector2(310, 2300), "o": Vector2(500, 900), "u": Vector2(330, 820), "y": Vector2(340, 2100)}
const VOICED_C := "bdgjlmnrvwz"
const NOISY_C := "cfhkpqstx"

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
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 18
	add_child(_layer)
	_sub = SubtitleBox.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_sub)
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	add_child(_player)
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
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
	var sp: Dictionary = (SPEAKERS.get(who, SPEAKERS.narrator) as Dictionary).duplicate()
	if who == "player":
		sp.merge(PLAYER_VOICE.get(Game.class_id, {}), true)
	var name_txt: String = sp.name if who != "player" else Game.hero_name
	if Game.settings.get("subtitles", true):
		_sub.show_line(name_txt, text, hold if hold > 0.0 else 2.0 + text.length() * 0.055)
	subtitle.emit(name_txt, text)
	speak(text, sp)


func speak(text: String, sp: Dictionary) -> void:
	if not Game.settings.get("voice", true) or DisplayServer.get_name() == "headless":
		return
	if _voices.is_empty():
		_play_synth(text, sp)
		return
	DisplayServer.tts_stop()
	var vol := int(clampf(float(Game.settings.get("master", 0.8)) * 100.0, 0.0, 100.0))
	DisplayServer.tts_speak(text, _voices[0], vol, float(sp.pitch), float(sp.rate), 0, true)


func stop() -> void:
	if _player:
		_player.stop()
	if not _voices.is_empty():
		DisplayServer.tts_stop()
	_sub.clear()


# ---------------------------------------------------------------- built-in voice

func _play_synth(text: String, sp: Dictionary) -> void:
	var stream := synth(text, sp)
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = linear_to_db(clampf(float(Game.settings.get("master", 0.8)) * float(Game.settings.get("sfx", 0.8)) * 1.1, 0.001, 1.0))
	_player.play()


## Letters become voiced vowels, soft consonants or little bursts of noise, shaped by a pitch contour
## that rises and falls with the words. It is not speech, but it is a voice: a murmur with a character.
func synth(text: String, sp: Dictionary) -> AudioStreamWAV:
	var f0b: float = sp.get("f0", 120.0)
	var fscale: float = sp.get("formant", 1.0)
	var speed: float = sp.get("speed", 1.0)
	var breath: float = sp.get("breath", 0.05)
	var growl: float = sp.get("growl", 0.0)
	var echo: float = sp.get("echo", 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var out := PackedFloat32Array()
	var phase := 0.0
	var a1 := 0.0
	var b1 := 0.0
	var a2 := 0.0
	var b2 := 0.0
	var total := maxi(1, text.length())
	var word := 0
	var hp := 0.0
	for i in text.length():
		var c := text[i].to_lower()
		var progress := float(i) / total
		var dur := 0.0
		var voiced := true
		var f1 := 500.0
		var f2 := 1500.0
		var amp := 0.0
		if VOWELS.has(c):
			dur = 0.095 / speed
			var fv: Vector2 = VOWELS[c]
			f1 = fv.x
			f2 = fv.y
			amp = 1.0
		elif VOICED_C.contains(c):
			dur = 0.05 / speed
			f1 = 330.0
			f2 = 1100.0
			amp = 0.55
		elif NOISY_C.contains(c):
			dur = 0.04 / speed
			voiced = false
			amp = 0.35
		elif c == " ":
			word += 1
			dur = 0.05 / speed
		elif c in ".!?":
			dur = 0.26 / speed
		elif c in ",;:":
			dur = 0.14 / speed
		else:
			continue
		var n := int(dur * SR)
		f1 *= fscale
		f2 *= fscale
		var r1 := exp(-PI * 90.0 / SR)
		var r2 := exp(-PI * 140.0 / SR)
		var k1 := 2.0 * r1 * cos(TAU * f1 / SR)
		var k2 := 2.0 * r2 * cos(TAU * f2 / SR)
		for s in n:
			var t := float(s) / maxf(1.0, n)
			var env := minf(1.0, t * 12.0) * minf(1.0, (1.0 - t) * 6.0)
			var f0 := f0b * (1.0 + 0.1 * sin(word * 1.7) + 0.06 * sin(i * 0.9)) * (1.0 - 0.2 * progress)
			var src := 0.0
			if amp > 0.0 and voiced:
				phase += f0 / SR
				phase -= floorf(phase)
				src = (phase * 2.0 - 1.0) * (1.0 - breath) + rng.randf_range(-1.0, 1.0) * breath
				if growl > 0.0:
					src *= 1.0 - growl * (0.5 + 0.5 * sin(TAU * 38.0 * (out.size() + s) / SR))
				var y_a := (1.0 - k1 - (-r1 * r1)) * src + k1 * a1 - r1 * r1 * a2
				a2 = a1
				a1 = y_a
				var y_b := (1.0 - k2 - (-r2 * r2)) * src + k2 * b1 - r2 * r2 * b2
				b2 = b1
				b1 = y_b
				out.append((y_a + 0.55 * y_b) * env * amp * 0.9)
			elif amp > 0.0:
				var nz := rng.randf_range(-1.0, 1.0)
				var hv := nz - hp
				hp = nz
				out.append(hv * env * amp * 0.5)
			else:
				a1 *= 0.9
				b1 *= 0.9
				out.append(0.0)
	if out.size() < 100:
		return null
	if echo > 0.0:
		var d := int(0.11 * SR)
		var wet := out.duplicate()
		for i in range(d, out.size()):
			wet[i] += out[i - d] * echo
		out = wet
	var peak := 0.0001
	for x in out:
		peak = maxf(peak, absf(x))
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	var gain := 0.6 / peak
	for i in out.size():
		bytes.encode_s16(i * 2, int(clampf(out[i] * gain, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	return wav


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
