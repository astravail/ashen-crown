extends SceneTree

func _initialize() -> void:
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var lt := GradientTexture2D.new()
	lt.gradient = gg
	lt.fill = GradientTexture2D.FILL_RADIAL
	lt.fill_from = Vector2(0.5, 0.5)
	lt.fill_to = Vector2(1.0, 0.5)
	lt.width = 256
	lt.height = 256
	get_root().use_hdr_2d = OS.get_environment("HDR") == "1"
	var root2 := Node2D.new()
	get_root().add_child(root2)
	var cm := CanvasModulate.new()
	cm.color = Color(0.3, 0.3, 0.3)
	root2.add_child(cm)
	var r := ColorRect.new()
	r.size = Vector2(1600, 900)
	r.color = Color(0.6, 0.6, 0.6)
	root2.add_child(r)
	if OS.get_environment("SHADER") == "1":
		var gm := ShaderMaterial.new()
		gm.shader = load("res://shaders/ground.gdshader")
		var img0 := Image.create(10, 10, false, Image.FORMAT_L8)
		img0.fill(Color(1, 1, 1))
		gm.set_shader_parameter("mask", ImageTexture.create_from_image(img0))
		gm.set_shader_parameter("col_a", Color(0.5, 0.5, 0.5))
		gm.set_shader_parameter("col_b", Color(0.4, 0.4, 0.4))
		gm.set_shader_parameter("col_wall", Color(0.1, 0.1, 0.1))
		gm.set_shader_parameter("map_px", Vector2(1600, 900))
		r.material = gm
	var l := PointLight2D.new()
	l.texture = lt
	l.texture_scale = 3.0
	l.energy = 1.5
	l.position = Vector2(400, 450)
	root2.add_child(l)
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1, 0.5)
	var l2 := PointLight2D.new()
	l2.texture = g
	l2.texture_scale = 3.0
	l2.energy = 1.5
	l2.position = Vector2(1200, 450)
	root2.add_child(l2)
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(OS.get_environment("OUT"))
	print("px left=", img.get_pixel(400 * img.get_width() / 1600, img.get_height() / 2), " right=", img.get_pixel(1200 * img.get_width() / 1600, img.get_height() / 2), " corner=", img.get_pixel(5, 5))
	quit()
