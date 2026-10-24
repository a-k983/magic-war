extends Area2D
# Coin: dropped by dead enemies. Pops out of the body, then works like an
# XP orb — flies to the player when they get close, adds gold on contact.

@export var value: int = 1
@export var magnet_range: float = 150.0   # Start flying when player is this close
@export var magnet_speed: float = 400.0
@export var attracted_speed: float = 900.0 # Speed once a magnet pickup grabs us

var player: Node2D = null
var attracted: bool = false   # Set by the magnet pickup: fly in from any distance
var age: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("coins")
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Drop "pop": hop a little way out from where the enemy died.
	var landing: Vector2 = position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var tween := create_tween()
	tween.tween_property(self, "position", landing, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The sprite arcs up and falls back while the body slides out.
	var hop := create_tween()
	hop.tween_property(sprite, "position:y", -22.0, 0.12).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", 0.0, 0.13).set_ease(Tween.EASE_IN)

func _physics_process(delta: float) -> void:
	age += delta
	# Gentle shimmer: squash horizontally like a spinning coin.
	sprite.scale.x = 2.0 * absf(cos(age * 4.0)) + 0.4

	if player == null:
		return
	if attracted:
		global_position = global_position.move_toward(
			player.global_position, attracted_speed * delta
		)
	elif global_position.distance_to(player.global_position) < magnet_range:
		global_position = global_position.move_toward(
			player.global_position, magnet_speed * delta
		)

func _on_body_entered(body: Node2D) -> void:
	# Enemies also touch us — only the player may collect.
	if body.is_in_group("player"):
		GameData.add_coins(value)
		Audio.play("coin", -9.0, 0.04)
		queue_free()
