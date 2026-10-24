extends CharacterBody2D
# The Enemy: animated creature (skeleton by default) that chases, hurts on contact, dies.

const XP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/xp_orb.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/pickup.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/pickups/coin.tscn")

@export var move_speed: float = 190.0
# Double the old 2 HP: starting spells (1 dmg) now need 4 hits, so each
# damage upgrade makes a big difference.
@export var max_health: int = 4
@export var contact_damage: int = 1
@export var attack_cooldown: float = 0.6  # Seconds between this enemy's hits
@export var xp_drop: int = 1
@export var coin_drop: int = 1
# Chance per death for each pickup: health 1 in ~80, magnet 1 in ~170,
# nuke 1 in 500.
@export var pickup_chances: Dictionary = {"health": 0.012, "magnet": 0.006, "nuke": 0.002}

var health: int
var player: Node2D = null
var speed_multiplier: float = 1.0
var attack_timer: float = 0.0
# Set by Main before add_child to swap the look. Needs "run" and "attack"
# animations. Left null = the skeleton frames baked into the scene.
var custom_frames: SpriteFrames = null
# Obstacle avoidance: the wall we're touching (its surface normal) and
# which way (+1/-1) we've decided to walk around it.
var wall_normal: Vector2 = Vector2.ZERO
var detour_side: float = 1.0
var detour_memory: float = 0.0  # Seconds left before we may pick a new side

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if custom_frames != null:
		anim.sprite_frames = custom_frames
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	anim.play("run")

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var direction: Vector2 = (player.global_position - global_position).normalized()

	# Walk around buildings/trees: if we're pressed against one and still
	# heading into it, steer along its edge instead. move_and_slide alone
	# already slides at an angle, but stalls when we hit a wall head-on.
	if wall_normal != Vector2.ZERO and direction.dot(wall_normal) < -0.2:
		var along: Vector2 = wall_normal.orthogonal() * detour_side
		direction = (along + direction * 0.25).normalized()

	velocity = direction * move_speed * speed_multiplier
	move_and_slide()

	# Remember the obstacle we touched this frame (if any) for next frame.
	var touching: Vector2 = Vector2.ZERO
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_collider() is StaticBody2D:
			touching = hit.get_normal()
	if touching != Vector2.ZERO:
		if detour_memory <= 0.0:
			# Fresh contact: pick the side that's closer to where the player is.
			var to_player: Vector2 = player.global_position - global_position
			detour_side = 1.0 if touching.orthogonal().dot(to_player) >= 0.0 else -1.0
		# Stick with that side for a moment, so rounding a corner (which
		# briefly breaks contact) doesn't make us turn back.
		detour_memory = 0.6
	else:
		detour_memory -= delta
	wall_normal = touching

	# Face the direction of travel.
	if direction.x < -0.1:
		anim.flip_h = true
	elif direction.x > 0.1:
		anim.flip_h = false

	# Contact damage — each enemy has its own cooldown (the player has no
	# i-frames), so every extra enemy in a swarm adds its own hits.
	attack_timer -= delta
	if attack_timer <= 0.0:
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider()
			if collider != null and collider.is_in_group("player"):
				collider.take_damage(contact_damage)
				anim.play("attack")
				attack_timer = attack_cooldown
				break

func take_damage(amount: int) -> void:
	health -= amount
	Audio.play("enemy_hit", -14.0, 0.15)

	anim.modulate = Color(5, 5, 5)  # White-hot flash
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	anim.modulate = Color.WHITE  # Back to normal — no red tint now!

	if health <= 0:
		die()

func apply_slow(factor: float, duration: float) -> void:
	speed_multiplier = factor
	# Visual cue for the frost effect.
	anim.modulate = Color(0.6, 0.8, 1.0)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	speed_multiplier = 1.0
	anim.modulate = Color.WHITE

func die(drop_pickup: bool = true) -> void:
	Audio.play("enemy_die", -9.0, 0.15)
	if drop_pickup:
		# One roll decides which pickup (if any) drops.
		var roll: float = randf()
		for kind in pickup_chances:
			roll -= pickup_chances[kind]
			if roll < 0.0:
				var pickup: Area2D = PICKUP_SCENE.instantiate()
				pickup.kind = kind
				pickup.global_position = global_position
				get_parent().add_child(pickup)
				break
	for i in xp_drop:
		var orb: Area2D = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position + Vector2(
			randf_range(-30, 30), randf_range(-30, 30)
		)
		get_parent().add_child(orb)
	# Coins pop out as pickups; gold is only earned when the player grabs them.
	for i in coin_drop:
		var coin: Area2D = COIN_SCENE.instantiate()
		coin.global_position = global_position
		get_parent().add_child(coin)
	queue_free()
