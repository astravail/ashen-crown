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
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 19.0, Color(0, 0, 0, 0.42), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var y := -4.0 + bob
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 2), Vector2(14, 2), Vector2(10, y - 30), Vector2(-10, y - 30)]), robe)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(3, y - 28), Vector2(-3, y - 28)]), robe.lightened(0.1))
	draw_circle(Vector2(0, y - 38), 8.0, skin, true, -1.0, true)
	match kind:
		"smith":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, y - 24), Vector2(9, y - 24), Vector2(8, y - 2), Vector2(-8, y - 2)]), Color(0.1, 0.08, 0.07))
			draw_line(Vector2(face * 12, y - 22), Vector2(face * 22, y - 36), Color(0.3, 0.27, 0.25), 3.0, true)
			draw_rect(Rect2(Vector2(face * 18 - 5, y - 42), Vector2(10, 7)), Color(0.35, 0.33, 0.32))
			draw_arc(Vector2(0, y - 40), 8.0, PI, TAU, 12, Color(0.18, 0.12, 0.08), 4.0, true)
		"mystic":
			draw_colored_polygon(PackedVector2Array([Vector2(-11, y - 34), Vector2(11, y - 34), Vector2(8, y - 50), Vector2(0, y - 58), Vector2(-8, y - 50)]), robe.darkened(0.15))
			draw_circle(Vector2(face * 2, y - 38), 6.0, Color(0.05, 0.04, 0.06), true, -1.0, true)
			draw_line(Vector2(face * 16, 2), Vector2(face * 16, y - 56), Color(0.3, 0.24, 0.2), 3.0, true)
		"elder":
			draw_colored_polygon(PackedVector2Array([Vector2(-11, y - 33), Vector2(11, y - 33), Vector2(9, y - 48), Vector2(0, y - 54), Vector2(-9, y - 48)]), Color(0.7, 0.68, 0.62))
			draw_circle(Vector2(face * 2, y - 38), 6.5, skin, true, -1.0, true)
			draw_line(Vector2(face * 15, 2), Vector2(face * 15, y - 50), Color(0.32, 0.26, 0.2), 3.0, true)
		"keeper":
			draw_rect(Rect2(Vector2(-13, y - 30), Vector2(26, 8)), Color(0.12, 0.1, 0.08))
			draw_circle(Vector2(0, y - 38), 9.0, skin.darkened(0.1), true, -1.0, true)
			draw_rect(Rect2(Vector2(-9, y - 48), Vector2(18, 6)), Color(0.2, 0.15, 0.1))
	draw_circle(Vector2(face * 3, y - 39), 1.2, Color(0.05, 0.05, 0.05), true, -1.0, true)
	if near:
		var f := Game.font_display
		var w := f.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string_outline(f, Vector2(-w * 0.5, y - 82), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-w * 0.5, y - 82), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.85, 0.7))
		var tw := Game.font_italic.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(Game.font_italic, Vector2(-tw * 0.5, y - 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.6))


func _draw_glow() -> void:
	if marker != "":
		var y := -92.0 + sin(t * 3.0) * 3.0
		var c := Color(3.0, 2.2, 0.5) if marker == "!" else Color(1.4, 2.4, 3.0)
		var f := Game.font_display_bold
		glow.draw_string(f, Vector2(-6, y), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)
	if kind == "mystic":
		glow.draw_circle(Vector2(16, -62), 4.0, Color(1.4, 0.7, 2.6, 0.9), true, -1.0, true)
