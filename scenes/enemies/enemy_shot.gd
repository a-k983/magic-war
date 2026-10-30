extends Node2D
# Enemy Shot: a thrown bone, harpoon or hex bolt. Flies at the player, hurts
# on touch, passes over scenery. No physics body: enemies and the player are
# few enough per shot that a distance check is simpler.

var sheet: Texture2D           # One-row sheet of square frames
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 1
var lifetime: float = 3.0
var hit_radius: float = 28.0
var spin: float = 0.0          # Radians/second; 0 = point along the flight path
var homing: float = 0.0        # Max turn in radians/second; 0 = flies straight
var tint: Color = Color.WHITE

var player: Node2D = null
var sprite: Sprite2D

func _ready() -> void:
	z_index = 5  # Above the y-sorted world, so a shot is never hidden
	player = get_tree().get_first_node_in_group("player")
	sprite = Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = sheet.get_width() / sheet.get_height()
	sprite.modulate = tint
	add_child(sprite)
	rotation = direction.angle()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or player == null:
		queue_free()
		return
	var to_player: Vector2 = player.global_position - global_position
	if homing > 0.0:
		var turn: float = direction.angle_to(to_player)
		direction = direction.rotated(clampf(turn, -homing * delta, homing * delta))
	global_position += direction * speed * delta
	rotation = rotation + spin * delta if spin != 0.0 else direction.angle()
	sprite.frame = int(lifetime * 10.0) % sprite.hframes
	if player.visible and to_player.length() < hit_radius:
		player.take_damage(damage)
		queue_free()
