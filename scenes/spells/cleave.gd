extends Node2D
# Cleave: the Warrior's weapon. One wide sweep toward the target that hits
# every enemy inside the arc, then fades.

const ARC_HALF: float = 1.15  # Half the sweep, in radians (~130 degrees in all)

var direction: Vector2 = Vector2.RIGHT
var reach: float = 190.0
var damage: int = 1
var duration: float = 0.22

# 0 = swing starts, 1 = finished. A tween drives it; _draw reads it.
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	z_index = 5
	rotation = direction.angle()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() < reach and absf(direction.angle_to(offset)) < ARC_HALF:
			enemy.take_damage(damage)
	Audio.play("orb_hit", -6.0, 0.15)
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# A crescent of steel that sweeps from one side of the arc to the other.
	var fade: float = 1.0 - progress * progress
	var head: float = lerpf(-ARC_HALF, ARC_HALF, minf(progress * 1.6, 1.0))
	draw_arc(Vector2.ZERO, reach * 0.8, -ARC_HALF, head, 28,
		Color(0.8, 0.9, 1.0, 0.35 * fade), reach * 0.36)
	draw_arc(Vector2.ZERO, reach * 0.97, -ARC_HALF, head, 28, Color(1, 1, 1, 0.9 * fade), 5.0)
