extends Node2D
# One Moonreaver blade: slows to a stop at the far end of its throw, then
# accelerates back to the player. Each enemy can be hit once per direction.

const HIT_RADIUS: float = 52.0
const THROW_SPEED: float = 760.0
const SLOWDOWN: float = 900.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var thrower: Node2D = null  # The player it returns to
var speed: float = THROW_SPEED
var returning: bool = false
var already_hit: Dictionary = {}

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	rotation += 15.0 * delta
	if not returning:
		speed -= SLOWDOWN * delta
		global_position += direction * speed * delta
		if speed <= 0.0:
			returning = true
			already_hit.clear()
	else:
		speed += SLOWDOWN * delta
		global_position = global_position.move_toward(thrower.global_position, speed * delta)
		if global_position.distance_to(thrower.global_position) < 24.0:
			queue_free()
			return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not already_hit.has(enemy.get_instance_id()) \
				and global_position.distance_to(enemy.global_position) < HIT_RADIUS:
			already_hit[enemy.get_instance_id()] = true
			enemy.take_damage(damage)

func _draw() -> void:
	draw_arc(Vector2.ZERO, 30.0, -1.3, 1.3, 16, Color(0.6, 0.75, 1.0, 0.35), 18.0)
	draw_arc(Vector2.ZERO, 32.0, -1.3, 1.3, 16, Color(0.9, 0.95, 1.0), 7.0)
