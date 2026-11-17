class_name Npc
extends Node2D
## Villagers you talk to with the interact key.

var world: World
var kind := "smith"
var display_name := ""
var title := ""
var radius := 16.0
var t := 0.0
var marker := ""
var glow: Node2D
var near := false

const Ink := preload("res://scripts/fx/ink.gd")

const DEFS := {
	"smith": {"name": "Hild", "title": "Ashsmith", "robe": Color(0.28, 0.2, 0.15), "skin": Color(0.55, 0.42, 0.34)},
	"mystic": {"name": "Veyra", "title": "Mystic", "robe": Color(0.2, 0.15, 0.3), "skin": Color(0.6, 0.52, 0.5)},
	"elder": {"name": "Sister Maren", "title": "Elder", "robe": Color(0.35, 0.33, 0.3), "skin": Color(0.62, 0.52, 0.45)},
	"keeper": {"name": "Odd", "title": "Stash Keeper", "robe": Color(0.17, 0.2, 0.17), "skin": Color(0.5, 0.42, 0.36)},
}


func setup(k: String) -> void:
	kind = k
	var d: Dictionary = DEFS[k]
	display_name = d.name
	title = d.title


func _ready() -> void:
	glow = Node2D.new()
	glow.material = World.unshaded_add
	add_child(glow)
	glow.draw.connect(_draw_glow)
	var l := world.make_light(Color(1.0, 0.7, 0.4), 0.55, 340.0)
	l.position = Vector2(0, -30)
	add_child(l)


func update(dt: float) -> void:
	t += dt
	near = world.player != null and world.player.global_position.distance_to(global_position) < 230.0
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	var d: Dictionary = DEFS[kind]
	var robe: Color = d.robe
	var skin: Color = d.skin
	var face := -1.0 if (world.player and world.player.global_position.x < global_position.x) else 1.0
	var bob := sin(t * 1.7) * 0.8
	Ink.shadow(self, Vector2(5, 3), 30.0, 12.0, 0.7)
	var y := -4.0 + bob
	var wide := 3.0 if kind == "smith" or kind == "keeper" else 0.0
	Ink.shape(self, PackedVector2Array([Vector2(-10 - wide, y - 30), Vector2(10 + wide, y - 30), Vector2(13 + wide, y - 12), Vector2(15 + wide, 1), Vector2(9, 3), Vector2(4, 0), Vector2(-1, 3),
		Vector2(-6, 0), Vector2(-11, 3), Vector2(-15 - wide, 0), Vector2(-13 - wide, y - 12)]), robe.lightened(0.14), robe.darkened(0.5))
	var fold := Color(robe.r * 0.35, robe.g * 0.35, robe.b * 0.35, 0.7)
	draw_line(Vector2(-4, y - 24), Vector2(-6, -3), fold, 1.3, true)
	draw_line(Vector2(5, y - 25), Vector2(8, -4), fold, 1.3, true)
	match kind:
		"smith":
			# Leather apron, sleeves rolled, a hammer never far from her hand
			var leather := Color(0.14, 0.105, 0.085)
			Ink.shape(self, PackedVector2Array([Vector2(-8, y - 25), Vector2(8, y - 25), Vector2(9, y - 2), Vector2(-9, y - 2)]), leather.lightened(0.12), leather.darkened(0.3), 1.6)
			draw_line(Vector2(-7, y - 25), Vector2(-10, y - 31), leather, 2.0, true)
			draw_line(Vector2(7, y - 25), Vector2(10, y - 31), leather, 2.0, true)
			var hand := Vector2(face * 19.0, y - 33)
			Ink.limb(self, Vector2(face * 11.0, y - 27), hand, 6.0, 4.5, skin, skin.darkened(0.35), 1.6)
			draw_line(hand + Vector2(-face * 2.0, 6), hand + Vector2(face * 4.0, -19), Ink.LINE, 5.0, true)
			draw_line(hand + Vector2(-face * 2.0, 6), hand + Vector2(face * 4.0, -19), Color(0.33, 0.25, 0.17), 2.6, true)
			var hh := hand + Vector2(face * 4.5, -21)
			Ink.shape(self, PackedVector2Array([hh + Vector2(-8, -4), hh + Vector2(8, -5), hh + Vector2(8, 4), hh + Vector2(-8, 4)]), Color(0.46, 0.45, 0.47), Color(0.22, 0.21, 0.23), 1.8)
			Ink.oval(self, Vector2(0, y - 38), 7.5, 8.0, skin.lightened(0.08), skin.darkened(0.3), 1.6)
			Ink.oval(self, Vector2(-face * 5.0, y - 45), 6.0, 4.5, Color(0.3, 0.16, 0.1), Color(0.14, 0.07, 0.05), 1.5)
			draw_line(Vector2(-7.5, y - 42), Vector2(7.5, y - 42), Color(0.5, 0.2, 0.14), 2.4, true)
		"mystic":
			var staff := face * 16.0
			Ink.limb(self, Vector2(staff, 3), Vector2(staff, y - 54), 3.6, 3.0, Color(0.3, 0.24, 0.2), Color(0.12, 0.09, 0.08), 1.5)
			Ink.shape(self, PackedVector2Array([Vector2(staff, y - 68), Vector2(staff + 4.5, y - 61), Vector2(staff, y - 54), Vector2(staff - 4.5, y - 61)]), Color(0.42, 0.26, 0.6), Color(0.16, 0.08, 0.28), 1.5)
			var cowl := robe.darkened(0.2)
			var hood := PackedVector2Array([Vector2(-12, y - 30), Vector2(12, y - 30), Vector2(11, y - 46), Vector2(face * 5.0, y - 59), Vector2(-face * 2.0, y - 56), Vector2(-11, y - 47)])
			if face < 0.0:
				hood = PackedVector2Array([Vector2(-12, y - 30), Vector2(12, y - 30), Vector2(11, y - 47), Vector2(2, y - 56), Vector2(-5, y - 59), Vector2(-11, y - 46)])
			Ink.shape(self, hood, cowl.lightened(0.22), cowl.darkened(0.3))
			Ink.oval(self, Vector2(face * 2.0, y - 40), 6.5, 7.5, Color(0.03, 0.02, 0.045), Color(0.03, 0.02, 0.045), 0.0)
			draw_line(Vector2(-9, y - 18), Vector2(9, y - 18), Color(0.55, 0.42, 0.7), 1.6, true)
		"elder":
			# A grey shawl, a white wimple, a stick to lean on
			var cane := face * 15.0
			Ink.limb(self, Vector2(cane, 3), Vector2(cane, y - 34), 3.4, 3.0, Color(0.33, 0.27, 0.2), Color(0.13, 0.1, 0.08), 1.5)
			draw_arc(Vector2(cane - face * 4.0, y - 34), 4.0, PI if face > 0.0 else -PI * 0.0, TAU if face > 0.0 else PI, 8, Color(0.33, 0.27, 0.2), 2.6, true)
			Ink.shape(self, PackedVector2Array([Vector2(-14, y - 22), Vector2(0, y - 17), Vector2(14, y - 22), Vector2(11, y - 32), Vector2(-11, y - 32)]), Color(0.3, 0.29, 0.28), Color(0.15, 0.145, 0.14), 1.6)
			var linen := Color(0.74, 0.72, 0.66)
			Ink.shape(self, PackedVector2Array([Vector2(-10, y - 30), Vector2(10, y - 30), Vector2(10, y - 45), Vector2(5, y - 52), Vector2(-5, y - 52), Vector2(-10, y - 45)]), linen, linen.darkened(0.4))
			Ink.oval(self, Vector2(face * 1.5, y - 39), 6.0, 6.5, skin.lightened(0.06), skin.darkened(0.3), 1.4)
			Ink.dot(self, Vector2(0, y - 24), 2.0, Color(0.62, 0.5, 0.24))
		"keeper":
			# A broad man in a flat hat, keys at his belt, a lantern in his fist
			draw_line(Vector2(-13, y - 13), Vector2(13, y - 13), Color(0.1, 0.08, 0.065), 3.4, true)
			draw_arc(Vector2(-face * 8.0, y - 9), 3.5, 0.0, TAU, 10, Color(0.6, 0.5, 0.26), 1.4, true)
			draw_line(Vector2(-face * 8.0, y - 6), Vector2(-face * 9.5, y), Color(0.6, 0.5, 0.26), 1.4, true)
			draw_line(Vector2(-face * 7.0, y - 6), Vector2(-face * 5.5, y - 1), Color(0.6, 0.5, 0.26), 1.4, true)
			var fist := Vector2(face * 17.0, y - 18)
			Ink.limb(self, Vector2(face * 12.0, y - 27), fist, 6.0, 4.5, robe.lightened(0.1), robe.darkened(0.3), 1.6)
			draw_line(fist, fist + Vector2(0, 5), Color(0.2, 0.17, 0.15), 1.4, true)
			Ink.shape(self, PackedVector2Array([fist + Vector2(-4, 5), fist + Vector2(4, 5), fist + Vector2(5, 15), fist + Vector2(-5, 15)]), Color(0.3, 0.24, 0.16), Color(0.12, 0.1, 0.08), 1.5)
			Ink.oval(self, Vector2(0, y - 38), 8.5, 8.5, skin, skin.darkened(0.35), 1.6)
			Ink.shape(self, PackedVector2Array([Vector2(-6, y - 35), Vector2(6, y - 35), Vector2(4, y - 27), Vector2(0, y - 24), Vector2(-4, y - 27)]), Color(0.42, 0.4, 0.37), Color(0.22, 0.21, 0.2), 1.3)
			Ink.oval(self, Vector2(0, y - 45), 13.0, 3.6, Color(0.24, 0.18, 0.12), Color(0.1, 0.075, 0.05), 1.6)
			Ink.shape(self, PackedVector2Array([Vector2(-7, y - 46), Vector2(7, y - 46), Vector2(6, y - 52), Vector2(-6, y - 52)]), Color(0.26, 0.2, 0.13), Color(0.13, 0.1, 0.07), 1.5)
	if kind != "mystic":
		Ink.dot(self, Vector2(face * 3.0, y - 39), 1.1, Color(0.04, 0.035, 0.035))
	if near:
		var f := Game.font_display
		var w := f.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string_outline(f, Vector2(-w * 0.5, y - 82), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-w * 0.5, y - 82), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.85, 0.7))
		var tw := Game.font_italic.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(Game.font_italic, Vector2(-tw * 0.5, y - 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.6))


func _draw_glow() -> void:
	var face := -1.0 if (world.player and world.player.global_position.x < global_position.x) else 1.0
	var y := -4.0 + sin(t * 1.7) * 0.8
	if marker != "":
		var my := -92.0 + sin(t * 3.0) * 3.0
		var c := Color(3.0, 2.2, 0.5) if marker == "!" else Color(1.4, 2.4, 3.0)
		Ink.glow(glow, Vector2(0, my - 12), 26.0, Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.35))
		glow.draw_string(Game.font_display_bold, Vector2(-6, my), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)
	if kind == "mystic":
		var pulse := 0.8 + 0.2 * sin(t * 2.6)
		Ink.glow(glow, Vector2(face * 16.0, y - 61), 18.0, Color(1.0, 0.5, 2.0, 0.4 * pulse))
		Ink.dot(glow, Vector2(face * 16.0, y - 61), 2.4, Color(1.8, 1.0, 3.0, 0.9))
		Ink.dot(glow, Vector2(face * 2.0 - 2.5, y - 41), 1.0, Color(1.6, 0.9, 2.8))
		Ink.dot(glow, Vector2(face * 2.0 + 2.5, y - 41), 1.0, Color(1.6, 0.9, 2.8))
	elif kind == "keeper":
		var flick := 0.85 + 0.15 * sin(t * 11.0)
		var lamp := Vector2(face * 17.0, y - 8)
		Ink.glow(glow, lamp, 22.0, Color(1.6, 0.7, 0.2, 0.4 * flick))
		Ink.dot(glow, lamp, 2.6, Color(3.2, 1.8, 0.6))
