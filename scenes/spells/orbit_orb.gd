extends Area2D
# Orbit Orb: one of the spheres circling the player. Damages enemies
# it sweeps through. A pulsing arcane sphere that leaves a violet trail.

const FX = preload("res://scenes/spells/spell_fx.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

var damage: int = BALANCE.orbit_damage  # Tune in res://config/balance.tres

var age: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Violet halo and a trail of motes, both drawn behind the sphere.
	var glow: Sprite2D = FX.glow_sprite(Color(0.7, 0.3, 1.0, 0.8), 80.0)
	glow.show_behind_parent = true
	add_child(glow)
	var motes: CPUParticles2D = FX.trail(Color(0.75, 0.4, 1.0), 18, 0.45, 0.4)
	motes.show_behind_parent = true
	add_child(motes)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()  # Redraw every frame so the sphere pulses

func _draw() -> void:
	# Sphere = dark rim, bright body, small highlight. The sine wave
	# makes it breathe in and out.
	var pulse: float = 1.0 + sin(age * 8.0) * 0.12
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color(0.3, 0.08, 0.5))
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(0.72, 0.3, 1.0))
	draw_circle(Vector2.ZERO, 5.5 * pulse, Color(0.95, 0.8, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		Audio.play("orb_hit", -9.0, 0.15)
		FX.burst(get_tree().current_scene, body.global_position,
			Color(0.8, 0.45, 1.0), 8, 180.0, 0.3, 0.25)
