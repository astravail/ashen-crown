class_name Actor
extends Node2D
## Anything with life: the player, minions and enemies.

enum Team { PLAYER, ENEMY }

var world: World
var team := Team.ENEMY
var radius := 16.0
var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var facing := Vector2.RIGHT
var dead := false
var flash := 0.0
var anim := 0.0
var heavy := false  # resists knockback

# Status effects
var burn_t := 0.0
var burn_dps := 0.0
var burn_src: Actor
var slow_t := 0.0
var slow_amt := 0.0
var stun_t := 0.0
var petrify := false
var vuln_t := 0.0
var vuln_amt := 0.0
var marked := false
var poison_t := 0.0
var poison_dps := 0.0

var glow: Node2D
var _tick := 0.0


func _ready() -> void:
	glow = Node2D.new()
	glow.material = World.unshaded_add
	glow.z_index = 1
	add_child(glow)
	glow.draw.connect(_draw_glow)


func move_speed_mult() -> float:
	var m := 1.0
	if slow_t > 0.0:
		m *= 1.0 - slow_amt
	return m


func is_stunned() -> bool:
	return stun_t > 0.0


func tick_status(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 6.0)
	if slow_t > 0.0:
		slow_t -= dt
	if stun_t > 0.0:
		stun_t -= dt
		if stun_t <= 0.0:
			petrify = false
	if vuln_t > 0.0:
		vuln_t -= dt
		if vuln_t <= 0.0:
			marked = false
	_tick += dt
	if _tick >= 0.25:
		_tick -= 0.25
		if burn_t > 0.0:
			world.damage(self, burn_dps * 0.25, burn_src if is_instance_valid(burn_src) else null, {"type": "fire", "dot": true})
			if randf() < 0.6:
				world.glow_fx.emit(global_position + Vector2(randf_range(-radius, radius) * 0.6, -radius), Vector2(randf_range(-10, 10), -60), 0.6, 2.5, Color(2.4, 0.8, 0.2), Particles.EMBER, 1.0)
		if poison_t > 0.0:
			world.damage(self, poison_dps * 0.25, null, {"type": "poison", "dot": true})
	if burn_t > 0.0:
		burn_t -= dt
	if poison_t > 0.0:
		poison_t -= dt


func apply_burn(dps: float, dur: float, src: Actor) -> void:
	if burn_t <= 0.0 or dps >= burn_dps:
		burn_dps = dps
		burn_src = src
	burn_t = maxf(burn_t, dur)


func apply_slow(amt: float, dur: float) -> void:
	slow_amt = maxf(slow_amt if slow_t > 0.0 else 0.0, amt)
	slow_t = maxf(slow_t, dur)


func apply_stun(dur: float) -> void:
	stun_t = maxf(stun_t, dur)


func apply_vuln(amt: float, dur: float, mark := false) -> void:
	vuln_amt = maxf(vuln_amt if vuln_t > 0.0 else 0.0, amt)
	vuln_t = maxf(vuln_t, dur)
	if mark:
		marked = true


func push(v: Vector2) -> void:
	knock += v * (0.25 if heavy else 1.0)


func integrate(dt: float, desired: Vector2) -> void:
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * dt)
	var motion := (desired + knock) * dt
	global_position = world.move_circle(global_position, motion, radius)


func on_damaged(_amount: float, _src: Actor, _opts: Dictionary) -> void:
	pass


func die(_src: Actor) -> void:
	dead = true


## What spills out when this is cut open. Alpha 0 = nothing (bones, spirits).
func blood_color() -> Color:
	return Color(0.42, 0.02, 0.03)


func _draw_glow() -> void:
	pass


# ---------------------------------------------------------------- drawing helpers

func shade(c: Color) -> Color:
	if flash > 0.0:
		return c.lerp(Color(1.6, 1.4, 1.2), clampf(flash, 0.0, 1.0))
	if petrify:
		var g := (c.r + c.g + c.b) / 3.0 * 0.6 + 0.25
		return Color(g, g * 0.97, g * 0.93, c.a)
	return c


func draw_shadow(scale_x := 1.0) -> void:
	draw_set_transform(Vector2(0, radius * 0.15), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, radius * 1.25 * scale_x, Color(0, 0, 0, 0.42), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.9 * scale_x, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_status_marks() -> void:
	if marked and vuln_t > 0.0:
		var a := 0.5 + 0.3 * sin(anim * 6.0)
		draw_arc(Vector2(0, radius * 0.1), radius * 1.35, 0.0, TAU, 32, Color(0.5, 0.95, 0.85, a * 0.6), 2.0, true)
