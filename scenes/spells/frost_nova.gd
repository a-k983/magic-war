extends Node2D
# Frost Nova: periodic icy blast around the player. Damages and slows
# every enemy inside the radius.

const FX = preload("res://scenes/spells/spell_fx.gd")
const FROST_RING = preload("res://scenes/spells/frost_ring.gd")

@export var cooldown: float = 3.0
@export var damage: int = 1
@export var radius: float = 250.0
@export var slow_factor: float = 0.5     # Enemies drop to 50% speed
@export var slow_duration: float = 2.0

var timer: float = 0.0

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		timer = cooldown
		blast()

func blast() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < radius:
			enemy.take_damage(damage)
			enemy.apply_slow(slow_factor, slow_duration)
	show_ring()
	Audio.play("frost_nova", -5.0)

func show_ring() -> void:
	# Visual: an expanding icy shockwave (see frost_ring.gd) plus a puff
	# of snow. Added to the world root so it stays where it was cast.
	var ring: Node2D = FROST_RING.new()
	ring.radius = radius
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)
	# Speed is chosen so the fastest snow just reaches the blast edge.
	FX.burst(get_tree().current_scene, global_position, Color(0.8, 0.95, 1.0),
		40, radius * 2.0, 0.5, 0.35)
