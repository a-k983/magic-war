extends Node2D
# Arcane Orbit: spawns orbs in a circle around the player and spins them.
# Trick: the orbs are OUR children, so rotating this node spins them all.

const ORB_SCENE: PackedScene = preload("res://scenes/spells/orbit_orb.tscn")

@export var orb_count: int = 2
@export var orbit_radius: float = 100.0
@export var rotation_speed: float = 2.5  # Radians per second

func _ready() -> void:
	# Place orbs evenly around the circle (like clock positions).
	for i in orb_count:
		var orb: Area2D = ORB_SCENE.instantiate()
		var angle: float = (TAU / orb_count) * i
		orb.position = Vector2.from_angle(angle) * orbit_radius
		add_child(orb)

func _draw() -> void:
	# Faint dashed rune circle along the orbit path. It's drawn on this
	# node, so it spins together with the orbs.
	var dashes: int = 12
	for i in dashes:
		var start: float = (TAU / dashes) * i
		draw_arc(Vector2.ZERO, orbit_radius, start, start + (TAU / dashes) * 0.6,
			8, Color(0.8, 0.5, 1.0, 0.3), 2.0)

func _process(delta: float) -> void:
	# Rotating ourselves rotates all child orbs around our center.
	rotation += rotation_speed * delta
