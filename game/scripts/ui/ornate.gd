class_name Ornate
extends RefCounted
## Procedural gothic frames: blackened stone, a beveled bronze-and-gold double
## border and rivets in the corners. Built once, shared by every theme and HUD box.

const GOLD_HI := Color(0.88, 0.72, 0.4)
const GOLD_MID := Color(0.62, 0.45, 0.2)
const GOLD_LO := Color(0.26, 0.17, 0.07)

static var _cache := {}


static func box(kind: String) -> StyleBoxTexture:
	if _cache.has(kind):
		return _cache[kind]
	var small := kind.begins_with("btn")
	var m := 14 if small else 24
	var img := _make(kind, 64, m, not small)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = m + (14 if small else 6)
	sb.content_margin_right = m + (14 if small else 6)
	sb.content_margin_top = m - (4 if small else -2)
	sb.content_margin_bottom = m - (4 if small else -2)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_cache[kind] = sb
	return sb


static func _noise(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)


static func _make(kind: String, s: int, m: int, studs: bool) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var top := Color(0.10, 0.09, 0.085)
	var bot := Color(0.045, 0.04, 0.04)
	var gold_k := 1.0
	match kind:
		"panel", "card":
			top = Color(0.085, 0.075, 0.072)
			bot = Color(0.04, 0.035, 0.035)
		"btn_hot", "card_hot":
			top = Color(0.30, 0.07, 0.05)
			bot = Color(0.12, 0.025, 0.02)
			gold_k = 1.25
		"btn_press", "card_press":
			top = Color(0.42, 0.09, 0.06)
			bot = Color(0.18, 0.03, 0.02)
			gold_k = 1.3
		"btn_off":
			top = Color(0.06, 0.055, 0.055)
			bot = Color(0.04, 0.035, 0.035)
			gold_k = 0.45
		"btn":
			top = Color(0.14, 0.12, 0.11)
			bot = Color(0.06, 0.05, 0.05)
	for y in s:
		for x in s:
			var d := mini(mini(x, y), mini(s - 1 - x, s - 1 - y))
			var h := float(x + y) / float(2 * s)
			var c: Color
			var edge := 0 if studs else 0
			if d <= edge:
				c = Color(0.01, 0.008, 0.008)
			elif d <= edge + 2:
				c = GOLD_HI.lerp(GOLD_LO, clampf(h * 1.3 - 0.1, 0.0, 1.0)) * gold_k
			elif d == edge + 3:
				c = Color(0.03, 0.025, 0.02)
			elif d == edge + 4 and studs:
				c = Color(0.09, 0.07, 0.05)
			elif d == edge + (6 if studs else 4):
				c = GOLD_MID.lerp(GOLD_LO, h) * 0.8 * gold_k
			else:
				var t := clampf(float(y) / float(s), 0.0, 1.0)
				c = top.lerp(bot, t)
				var n := _noise(x, y) * 0.03 + _noise(x / 3, y / 3) * 0.035
				c = Color(c.r + n, c.g + n * 0.9, c.b + n * 0.85)
			c.a = 1.0
			img.set_pixel(x, y, c)
	if studs:
		for corner in [Vector2i(10, 10), Vector2i(s - 11, 10), Vector2i(10, s - 11), Vector2i(s - 11, s - 11)]:
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var r := sqrt(float(dx * dx + dy * dy))
					if r > 3.6:
						continue
					var shade := clampf(0.5 - float(dx + dy) / 9.0, 0.0, 1.0)
					var c2 := GOLD_LO.lerp(GOLD_HI, shade)
					if r > 2.8:
						c2 = Color(0.05, 0.04, 0.03)
					img.set_pixel(corner.x + dx, corner.y + dy, c2)
	return img
