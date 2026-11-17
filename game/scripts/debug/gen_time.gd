extends SceneTree
## Times world generation: godot --headless --path game -s res://scripts/debug/gen_time.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var wm := WorldMap.new()
	wm.build_overworld(123)
	print("overworld built in %d ms  regions=%d gates=%d size=%dx%d" % [Time.get_ticks_msec() - t0, wm.regions.size(), wm.gates.size(), wm.w, wm.h])
	var t1 := Time.get_ticks_msec()
	var img := wm.mask_image()
	print("mask image %d ms" % (Time.get_ticks_msec() - t1))
	var floors := 0
	for i in wm.grid.size():
		floors += wm.grid[i]
	print("floor cells: ", floors)
	for r in wm.regions:
		print(" region zone=%d name=%s packs=%d props=%d chests=%d" % [r.zone, r.zd.name, (r.packs as Array).size(), (r.props as Array).size(), (r.chests as Array).size()])
	quit()
