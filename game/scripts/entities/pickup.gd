class_name Pickup
extends Node2D
## Health globes.

var world: World
var kind := "globe"
var done := false
var t := 0.0
var glow: Node2D


func _ready() -> void:
	glow = Node2D.new()
	glow.material = World.unshaded_add
	add_child(glow)
	glow.draw.connect(_draw_glow)


func update(dt: float) -> void:
	t += dt
	var p := world.player
	if p and not p.dead:
		var d := p.global_position.distance_to(global_position)
		if d < 120.0:
			global_position = global_position.move_toward(p.global_position, (420.0 - d * 2.0) * dt)
		if d < p.radius + 14.0:
			var amt := p.max_hp * 0.2 * (0.5 if Game.fragments.has("embers") else 1.0)
			p.heal(amt, true)
			Sfx.play("pickup")
			world.glow_fx.burst(global_position, 10, Color(2.5, 0.4, 0.3), 40, 140, 0.5, 2.0, Particles.SPARK)
			done = true
	if t > 45.0:
		done = true
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.4), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	var y := -14.0 + sin(t * 3.0) * 3.0
	glow.draw_circle(Vector2(0, y), 18, Color(1.2, 0.1, 0.08, 0.18), true, -1.0, true)
	glow.draw_circle(Vector2(0, y), 9, Color(2.4, 0.25, 0.18), true, -1.0, true)
	glow.draw_circle(Vector2(-2.5, y - 3), 3, Color(3.0, 1.6, 1.4), true, -1.0, true)
