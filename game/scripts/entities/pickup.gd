class_name Pickup
extends Node2D
## Health globes.

const Ink := preload("res://scripts/fx/ink.gd")

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


## Where the globe hangs: it bobs gently above the ground.
func _orb_y() -> float:
	return -14.0 + sin(t * 3.0) * 3.0


func _draw() -> void:
	var y := _orb_y()
	# the shadow tightens as the globe dips toward the ground
	var low := 0.5 + 0.5 * sin(t * 3.0)
	Ink.shadow(self, Vector2(1, 4), 11.0 + low * 2.5, 4.5 + low, 0.4 + 0.15 * low)
	# a dark setting behind the glass, so the red holds against bright ground
	Ink.dot(self, Vector2(0, y), 10.6, Color(0.05, 0.0, 0.01, 0.9))


func _draw_glow() -> void:
	var y := _orb_y()
	var c := Vector2(0, y)
	Ink.glow(glow, c, 30.0, Color(1.5, 0.12, 0.08, 0.26 + 0.06 * sin(t * 3.0)))
	# glass: deep red at the rim, lit from within, light pooling low on the far side
	Ink.dot(glow, c, 9.2, Color(1.0, 0.04, 0.05))
	Ink.glow(glow, c + Vector2(0.8, 1.4), 10.5, Color(3.2, 0.45, 0.28, 0.95))
	Ink.glow(glow, c + Vector2(3.0, 4.2), 4.6, Color(4.0, 1.5, 0.9, 0.7))
	# the bright window of a highlight, and a smaller one beside it
	Ink.dot(glow, c + Vector2(-3.3, -3.6), 2.2, Color(4.0, 3.6, 3.4, 0.95))
	Ink.dot(glow, c + Vector2(-0.3, -6.0), 0.9, Color(4.0, 3.6, 3.4, 0.8))
