class_name WorldMap
## The whole overworld in one grid: the village and twelve zones laid out as blocks, joined by gated tunnels.
## Interiors (houses, mines) use a one-region map of their own.

const CELL := 64.0
const BLOCK := 160

## Block coordinates for the village (key -1) and every zone.
const LAYOUT := {
	-1: Vector2i(0, 0), 0: Vector2i(1, 0), 1: Vector2i(2, 0), 2: Vector2i(3, 0),
	3: Vector2i(3, 1), 4: Vector2i(2, 1), 5: Vector2i(1, 1), 6: Vector2i(0, 1),
	7: Vector2i(0, 2), 8: Vector2i(1, 2), 9: Vector2i(2, 2), 10: Vector2i(3, 2), 11: Vector2i(3, 3),
}

var w := 0
var h := 0
var grid := PackedByteArray()
var regions: Array[Dictionary] = []  # {zone, zd, off, gen, start, finish, waypoint, packs, props, chests, pois}
var gates: Array[Dictionary] = []  # {a, b, cell, dir}
var zone_region := {}  # zone index (-1 village) -> region index
var block_region := {}  # block coords -> region index


func build_overworld(seed_value: int) -> void:
	w = BLOCK * 4
	h = BLOCK * 4
	grid.resize(w * h)
	grid.fill(0)
	var order: Array = [-1]
	for z in Data.LAST_ZONE + 1:
		order.append(z)
	for z in order:
		var zd: Dictionary = Data.VILLAGE if z < 0 else Data.ZONES[z]
		var gen := MapGen.new()
		gen.generate(zd, seed_value + (z + 2) * 7919)
		var blk: Vector2i = LAYOUT[z]
		var off := blk * BLOCK + Vector2i((BLOCK - gen.w) / 2, (BLOCK - gen.h) / 2)
		_stamp(z, zd, gen, off)
	for i in regions.size() - 1:
		_connect(i, i + 1)


func build_single(zone_idx: int, seed_value: int) -> void:
	var zd: Dictionary = Data.ZONES[zone_idx]
	var gen := MapGen.new()
	gen.generate(zd, seed_value)
	w = gen.w
	h = gen.h
	grid = gen.grid
	_stamp_meta(zone_idx, zd, gen, Vector2i.ZERO)


func _stamp(z: int, zd: Dictionary, gen: MapGen, off: Vector2i) -> void:
	for y in gen.h:
		for x in gen.w:
			if gen.grid[y * gen.w + x] == 1:
				grid[(y + off.y) * w + x + off.x] = 1
	_stamp_meta(z, zd, gen, off)


func _stamp_meta(z: int, zd: Dictionary, gen: MapGen, off: Vector2i) -> void:
	var offpx := Vector2(off) * CELL
	var packs: Array[Vector2] = []
	for p in gen.packs:
		packs.append(p + Vector2(off))
	var props: Array[Dictionary] = []
	for p in gen.props:
		props.append({"kind": p.kind, "pos": p.pos + offpx, "seed": p.seed})
	var chs: Array[Dictionary] = []
	for c in gen.chests:
		chs.append({"pos": c.pos + offpx, "iron": c.iron})
	var pois := {}
	for k in gen.pois.keys():
		pois[k] = gen.pois[k] + offpx
	var branches: Array[Vector2i] = []
	for b in gen.branches:
		branches.append(b + off)
	var nodes: Array[Vector2i] = []
	for n in gen.nodes:
		nodes.append(n + off)
	zone_region[z] = regions.size()
	if LAYOUT.has(z) and regions.size() > 0 or z == -1:
		block_region[LAYOUT[z]] = regions.size()
	regions.append({"zone": z, "zd": zd, "off": off, "w": gen.w, "h": gen.h, "gen": gen, "start": gen.start + off, "finish": gen.finish + off,
		"waypoint": gen.waypoint + off, "packs": packs, "props": props, "chests": chs, "pois": pois, "branches": branches, "nodes": nodes})


## Carve a tunnel from region a's finish to region b's start and mark where the gate stands.
func _connect(ai: int, bi: int) -> void:
	var a: Dictionary = regions[ai]
	var b: Dictionary = regions[bi]
	var ba: Vector2i = LAYOUT[a.zone]
	var bb: Vector2i = LAYOUT[b.zone]
	var fa: Vector2i = a.finish
	var sb: Vector2i = b.start
	var dir := bb - ba
	var pts: Array[Vector2i] = []
	var gate_cell: Vector2i
	if dir.x != 0:
		var bx := (maxi(ba.x, bb.x)) * BLOCK
		pts = [fa, Vector2i(bx, fa.y), Vector2i(bx, sb.y), sb]
		gate_cell = Vector2i(bx - dir.x * 10, fa.y)
	else:
		var by := (maxi(ba.y, bb.y)) * BLOCK
		pts = [fa, Vector2i(fa.x, by), Vector2i(sb.x, by), sb]
		gate_cell = Vector2i(fa.x, by - dir.y * 10)
	for i in pts.size() - 1:
		_carve_line(pts[i], pts[i + 1], 2)
	gates.append({"a": ai, "b": bi, "cell": gate_cell, "dir": Vector2(dir)})


func _carve_line(a: Vector2i, b: Vector2i, half: int) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	while true:
		for y in range(-half, half + 1):
			for x in range(-half, half + 1):
				var gx := p.x + x
				var gy := p.y + y
				if gx >= 0 and gy >= 0 and gx < w and gy < h:
					grid[gy * w + gx] = 1
		if p == b:
			break
		if p.x != b.x:
			p.x += step.x
		elif p.y != b.y:
			p.y += step.y


func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return grid[y * w + x] == 1


## Which region a cell belongs to. Tunnels between blocks belong to the block they sit in.
func region_at(x: int, y: int) -> int:
	if regions.size() == 1:
		return 0
	var key := Vector2i(clampi(x / BLOCK, 0, 3), clampi(y / BLOCK, 0, 3))
	return int(block_region.get(key, 0))


func mask_image() -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(1, 1, 1) if grid[y * w + x] == 1 else Color(0, 0, 0))
	return img
