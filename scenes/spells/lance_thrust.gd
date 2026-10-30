extends Node2D
# Lance Thrust: the Lancer's weapon. A long, narrow stab toward the target
# that hits every enemy along the line.

const WIDTH: float = 46.0  # How close to the line counts as a hit

var direction: Vector2 = Vector2.RIGHT
var reach: float = 340.0
var damage: int = 1
var duration: float = 0.26

var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	z_index = 5
	rotation = direction.angle()
	var tip: Vector2 = global_position + direction * reach
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(
			enemy.global_position, global_position, tip)
		if nearest.distance_to(enemy.global_position) < WIDTH:
			enemy.take_damage(damage)
	Audio.play("orb_hit", -6.0, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Shoots out fast, draws back slower. Shaft, then a bright steel tip.
	var extend: float = sin(pow(progress, 0.6) * PI) * reach
	var fade: float = 1.0 - progress * progress * progress
	draw_line(Vector2.ZERO, Vector2(extend, 0), Color(0.75, 0.9, 1.0, 0.3 * fade), 34.0)
	draw_line(Vector2.ZERO, Vector2(extend - 30.0, 0), Color(0.55, 0.36, 0.2, fade), 7.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(extend + 22.0, 0), Vector2(extend - 34.0, -11.0), Vector2(extend - 34.0, 11.0),
	]), Color(0.92, 0.96, 1.0, fade))
