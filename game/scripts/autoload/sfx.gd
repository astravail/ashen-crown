extends Node
## Sound effect pool, cross-fading music and a looping zone ambience bed.
## A sound can have variants on disk (hit.wav, hit_2.wav, hit_3.wav ...); one is picked at random.

const SFX := ["swing", "hit", "hit_heavy", "fire_cast", "explode", "explode_small", "bone", "summon",
	"enemy_death", "hurt", "dodge", "levelup", "pickup", "ui_move", "ui_select", "teleport", "freeze",
	"ultimate", "roar", "flask", "fragment", "wave", "slam", "gore", "growl", "hurt_knight", "hurt_gravecaller", "hurt_pyrewitch"]
const MUSIC := ["music_title", "music_combat", "music_boss"]
const AMBIENCE := ["amb_forest", "amb_crypt", "amb_marsh", "amb_hell"]

var _streams := {}
var _variants := {}
var _amb: AudioStreamPlayer
var _amb_tween: Tween
var _current_amb := ""
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")
	for n in SFX:
		var list: Array[AudioStream] = []
		for k in range(1, 6):
			var path := "res://assets/audio/%s.wav" % n if k == 1 else "res://assets/audio/%s_%d.wav" % [n, k]
			if k == 1 or ResourceLoader.exists(path):
				list.append(load(path))
		_variants[n] = list
		_streams[n] = list[0]
	for n in MUSIC + AMBIENCE:
		var s: AudioStream = load("res://assets/audio/%s.wav" % n)
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate) - 1
		_streams[n] = s
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "SFX"
	_amb.volume_db = -80.0
	add_child(_amb)


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func set_volumes(master: float, music: float, sfx: float) -> void:
	_make_bus("Music")
	_make_bus("SFX")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx, 0.0001)))


func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	if not _streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -1000)) < 35:
		return
	_last_played[sfx_name] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	var list: Array = _variants.get(sfx_name, [_streams[sfx_name]])
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func music(track: String, fade := 1.5) -> void:
	if track == _current_music:
		return
	_current_music = track
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if track != "" and _streams.has(track):
		incoming.stream = _streams[track]
		incoming.volume_db = -40.0
		incoming.play()
		_tween.tween_property(incoming, "volume_db", -6.0, fade)
	_tween.tween_property(outgoing, "volume_db", -80.0, fade)
	_tween.chain().tween_callback(outgoing.stop)


## Loop a zone's ambience bed (wind and crows, dripping crypts, the roar of hell). "" fades it out.
func ambience(track: String, volume_db := -10.0, fade := 2.5) -> void:
	if track == _current_amb:
		return
	_current_amb = track
	if _amb_tween:
		_amb_tween.kill()
	if not _amb.playing and not _streams.has(track):
		return
	_amb_tween = create_tween()
	if _amb.playing:
		_amb_tween.tween_property(_amb, "volume_db", -60.0, fade * 0.5)
		_amb_tween.tween_callback(_amb.stop)
	if track != "" and _streams.has(track):
		_amb_tween.tween_callback(func() -> void:
			_amb.stream = _streams[track]
			_amb.volume_db = -60.0
			_amb.play())
		_amb_tween.tween_property(_amb, "volume_db", volume_db, fade)
