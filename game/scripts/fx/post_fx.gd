extends Node2D
## The finishing pass over the world: grade, mist, vignette and grain. It is the last thing drawn on the
## world's own canvas, so the bloom still runs after it and no HUD or menu layer is ever touched.

## Per ground pattern: mist, heat shimmer, saturation and the tints laid over shadows and highlights.
const LOOKS := {
	0: {"fog": 0.38, "heat": 0.0, "sat": 0.94, "shadow": Color(0.9, 0.96, 1.06), "high": Color(1.08, 1.0, 0.9)},
	1: {"fog": 0.3, "heat": 0.0, "sat": 0.9, "shadow": Color(0.86, 0.94, 1.1), "high": Color(1.07, 1.0, 0.92)},
	2: {"fog": 0.75, "heat": 0.0, "sat": 0.88, "shadow": Color(0.84, 1.0, 1.02), "high": Color(1.04, 1.03, 0.9)},
	3: {"fog": 0.42, "heat": 0.7, "sat": 1.04, "shadow": Color(1.0, 0.9, 0.96), "high": Color(1.1, 0.98, 0.86)},
	4: {"fog": 0.6, "heat": 0.0, "sat": 0.92, "shadow": Color(0.84, 0.98, 1.04), "high": Color(1.05, 1.04, 0.9)},
	5: {"fog": 0.5, "heat": 0.0, "sat": 0.86, "shadow": Color(0.86, 0.96, 1.08), "high": Color(1.06, 1.0, 0.92)},
}

var world: Node2D
var rect: ColorRect
var mat: ShaderMaterial
var kick := 0.0
var hurt := 0.0
var _cur := {}
var _target := {}


func setup(w: Node2D) -> void:
	world = w
	z_index = 200
	z_as_relative = false
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.light_mask = 0
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/post.gdshader")
	rect.material = mat
	add_child(rect)
	var w3 := w.get_viewport().find_world_3d()
	var env: Environment = w3.environment if w3 else null
	if env:
		# The emissive palette is authored for a straight clip to white, so the tone mapper stays linear
		# and exposure is held by the terrain and this pass instead.
		env.glow_intensity = 0.42
		env.glow_bloom = 0.0
		env.set_glow_level(1, 0.7)
		env.set_glow_level(2, 0.8)
		env.set_glow_level(3, 0.5)
		env.set_glow_level(4, 0.25)
		env.set_glow_level(5, 0.0)


func apply_zone(zd: Dictionary, instant := false) -> void:
	var look: Dictionary = LOOKS[clampi(int(zd.get("pattern", 0.0)), 0, 5)]
	var m: Color = zd.modulate
	var v: Color = zd.vein
	var vmax := maxf(v.r, maxf(v.g, v.b))
	# Mist takes the colour of the air, warmed or chilled a little by whatever glows in the ground.
	var fog := Color(m.r, m.g, m.b).lerp(Color(v.r / vmax, v.g / vmax, v.b / vmax), 0.18) * 0.2
	_target = {"fog_color": Vector3(fog.r, fog.g, fog.b), "fog_amount": float(look.fog), "heat": float(look.heat),
		"saturation": float(look.sat), "exposure": 0.62 if int(zd.get("pattern", 0.0)) in [1, 5] else 0.8, "shadow_tint": Vector3(look.shadow.r, look.shadow.g, look.shadow.b),
		"high_tint": Vector3(look.high.r, look.high.g, look.high.b)}
	if instant or _cur.is_empty():
		_cur = _target.duplicate()
		_push()


func update(delta: float, cam: Camera2D) -> void:
	var k := clampf(delta * 0.9, 0.0, 1.0)
	for key in _target:
		_cur[key] = lerp(_cur[key], _target[key], k)
	_push()
	kick = move_toward(kick, 0.0, delta * 3.5)
	var vs: Vector2 = world.get_viewport_rect().size / cam.zoom
	# Oversized, so camera shake and smoothing never show its edge; the shader works in screen space.
	rect.size = vs * 1.12
	rect.position = cam.get_screen_center_position() - rect.size * 0.5
	mat.set_shader_parameter("cam_pos", cam.get_screen_center_position())
	mat.set_shader_parameter("view_size", vs)
	mat.set_shader_parameter("kick", kick)
	mat.set_shader_parameter("hurt", hurt)
	var q: float = Game.quality_factor()
	# On the lowest setting the lens fringe is dropped: it costs two more reads of the screen per pixel.
	mat.set_shader_parameter("lite", q <= 0.3)
	mat.set_shader_parameter("brightness", clampf(float(Game.settings.get("brightness", 1.0)), 0.5, 2.0))
	mat.set_shader_parameter("grain", 0.05 if q > 0.3 else 0.035)
	mat.set_shader_parameter("fringe", 0.0011 if q > 0.3 else 0.0)


func _push() -> void:
	for key in _cur:
		mat.set_shader_parameter(key, _cur[key])
