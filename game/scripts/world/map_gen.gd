class_name MapGen
## Generates a large zone: a winding chain of clearings or halls from start to the final arena,
## with side branches, enemy pack sites and prop sites.

const CELL := 64.0

var w := 0
var h := 0
var grid := PackedByteArray()  # 1 = floor
var nodes: Array[Vector2i] = []  # main path, in order
var branches: Array[Vector2i] = []
var node_radius: Array[int] = []
var start := Vector2i.ZERO
var finish := Vector2i.ZERO
var packs: Array[Vector2] = []
var props: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func generate(zone: Dictionary, seed_value: int) -> void:
	rng.seed = seed_value
	w = zone.size.x
	h = zone.size.y
	grid.resize(w * h)
	grid.fill(0)
	var dungeon: bool = zone.style == "dungeon"
	_layout_nodes()
	for i in nodes.size():
		var r := node_radius[i]
		if dungeon:
			_carve_rect(nodes[i], r + rng.randi_range(-1, 2), r + rng.randi_range(-2, 1))
		else:
			_carve_blob(nodes[i], r)
		if i > 0:
			_corridor(nodes[i - 1], nodes[i], dungeon)
	for b in branches:
		var near := _closest_node(b)
		if dungeon:
			_carve_rect(b, rng.randi_range(5, 8), rng.randi_range(5, 8))
		else:
			_carve_blob(b, rng.randi_range(6, 9))
		_corridor(nodes[near], b, dungeon)
	if not dungeon:
		_smooth()
		_smooth()
	_seal_border()
	_keep_connected()
	start = nodes[0]
	finish = nodes[nodes.size() - 1]
	_place_packs(zone)
	_place_props(zone)


func _layout_nodes() -> void:
	# Snake across a 5 x 5 sector grid so the route covers most of the map.
	var cols := 5
	var rows := 5
	var sx := float(w - 16) / cols
	var sy := float(h - 16) / rows
	var used := {}
	var down := rng.randf() < 0.5
	for c in cols:
		var picks: Array[int] = []
		var count := 3 if c in [1, 3] else 2
		var all_rows := range(rows)
		all_rows.shuffle()
		for r in all_rows.slice(0, count):
			picks.append(r)
		picks.sort()
		if not down:
			picks.reverse()
		down = not down
		for r in picks:
			var p := Vector2i(int(8 + (c + 0.5) * sx + rng.randf_range(-0.25, 0.25) * sx), int(8 + (r + 0.5) * sy + rng.randf_range(-0.25, 0.25) * sy))
			nodes.append(p)
			used[Vector2i(c, r)] = true
	for i in nodes.size():
		node_radius.append(rng.randi_range(7, 11))
	node_radius[0] = 8
	node_radius[nodes.size() - 1] = 15
	# Side branches into empty sectors
	for c in cols:
		for r in rows:
			if used.has(Vector2i(c, r)) or rng.randf() < 0.45:
				continue
			branches.append(Vector2i(int(8 + (c + 0.5) * sx), int(8 + (r + 0.5) * sy)))


func _closest_node(p: Vector2i) -> int:
	var best := 0
	var bd := INF
	for i in range(1, nodes.size() - 1):
		var d := Vector2(nodes[i] - p).length()
		if d < bd:
			bd = d
			best = i
	return best


func _put(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		grid[y * w + x] = v


func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return grid[y * w + x] == 1


func _carve_blob(c: Vector2i, r: int) -> void:
	var phase := rng.randf() * TAU
	var k1 := rng.randf_range(0.1, 0.25)
	var k2 := rng.randf_range(0.05, 0.15)
	for y in range(c.y - r - 4, c.y + r + 5):
		for x in range(c.x - r - 4, c.x + r + 5):
			var d := Vector2(x - c.x, (y - c.y) * 1.1)
			var a := d.angle()
			var rr := r * (1.0 + k1 * sin(a * 3.0 + phase) + k2 * sin(a * 5.0 + phase * 2.0))
			if d.length() < rr:
				_put(x, y, 1)


func _carve_rect(c: Vector2i, hw: int, hh: int) -> void:
	for y in range(c.y - hh, c.y + hh + 1):
		for x in range(c.x - hw, c.x + hw + 1):
			_put(x, y, 1)


func _corridor(a: Vector2i, b: Vector2i, dungeon: bool) -> void:
	if dungeon:
		var mid := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
		_line(a, mid, 2)
		_line(mid, b, 2)
		return
	var steps := int(Vector2(b - a).length() * 1.5)
	var dir := Vector2(b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var amp := rng.randf_range(3.0, 8.0)
	var freq := rng.randf_range(1.0, 2.5)
	for s in steps + 1:
		var t := float(s) / steps
		var p := Vector2(a).lerp(Vector2(b), t) + perp * sin(t * PI * freq) * amp * sin(t * PI)
		var rad := 2 + int(1.5 + sin(t * 9.0) * 1.2)
		for y in range(-rad, rad + 1):
			for x in range(-rad, rad + 1):
				if x * x + y * y <= rad * rad:
					_put(int(p.x) + x, int(p.y) + y, 1)


func _line(a: Vector2i, b: Vector2i, half: int) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	while true:
		for y in range(-half, half + 1):
			for x in range(-half, half + 1):
				_put(p.x + x, p.y + y, 1)
		if p == b:
			break
		if p.x != b.x:
			p.x += step.x
		elif p.y != b.y:
			p.y += step.y


func _smooth() -> void:
	var out := grid.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					n += grid[(y + dy) * w + x + dx]
			out[y * w + x] = 1 if n >= 5 else 0
	grid = out


func _seal_border() -> void:
	for y in h:
		for x in w:
			if x < 3 or y < 3 or x >= w - 3 or y >= h - 3:
				grid[y * w + x] = 0


func _keep_connected() -> void:
	# Flood from the start; drop any floor not reachable.
	var s := nodes[0]
	if not is_floor(s.x, s.y):
		_carve_blob(s, 6)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var q: Array[Vector2i] = [s]
	seen[s.y * w + s.x] = 1
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if is_floor(n.x, n.y) and seen[n.y * w + n.x] == 0:
				seen[n.y * w + n.x] = 1
				q.append(n)
	for i in grid.size():
		if grid[i] == 1 and seen[i] == 0:
			grid[i] = 0


func floor_cells_near(c: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if is_floor(x, y) and Vector2(x - c.x, y - c.y).length() <= r:
				out.append(Vector2i(x, y))
	return out


func _clearance(x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not is_floor(x + dx, y + dy):
				return false
	return true


func _place_packs(zone: Dictionary) -> void:
	var want: int = zone.packs
	var tries := 0
	while packs.size() < want and tries < 6000:
		tries += 1
		var x := rng.randi_range(4, w - 5)
		var y := rng.randi_range(4, h - 5)
		if not _clearance(x, y, 2):
			continue
		var c := Vector2(x, y)
		if c.distance_to(Vector2(start)) < 16 or c.distance_to(Vector2(finish)) < 18:
			continue
		var ok := true
		for p in packs:
			if p.distance_to(c) < 9.0:
				ok = false
				break
		if ok:
			packs.append(c)


func _place_props(zone: Dictionary) -> void:
	var kinds: Array = zone.props
	var occupied := {}
	for y in range(3, h - 3):
		for x in range(3, w - 3):
			if not is_floor(x, y):
				continue
			var near_wall := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not is_floor(x + d.x, y + d.y):
					near_wall = true
			var c := Vector2(x, y)
			if c.distance_to(Vector2(start)) < 5 or c.distance_to(Vector2(finish)) < 13:
				continue
			var chance := (0.16 if near_wall else 0.012) * float(zone.get("prop_density", 1.0))
			if rng.randf() > chance:
				continue
			var key := Vector2i(x / 2, y / 2)
			if occupied.has(key):
				continue
			occupied[key] = true
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			if kind == "brazier" and near_wall and rng.randf() < 0.6:
				kind = kinds[0]
			props.append({"kind": kind, "pos": (c + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))) * CELL, "seed": rng.randi()})
	# Braziers flank the final arena entrance and the start.
	for c in [start, finish]:
		var r := 5 if c == start else 12
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			var p := Vector2(c) + Vector2(cos(a), sin(a)) * r
			if is_floor(int(p.x), int(p.y)):
				props.append({"kind": "brazier", "pos": (p + Vector2(0.5, 0.5)) * CELL, "seed": rng.randi()})


func mask_image() -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(1, 1, 1) if grid[y * w + x] == 1 else Color(0, 0, 0))
	return img
