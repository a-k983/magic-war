extends CharacterBody2D
# The Player: moves, auto-fires, collects XP, levels up, can now DIE.

signal xp_changed(current_xp: int, xp_needed: int)
signal leveled_up(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal died

@export var move_speed: float = 250.0

# ---------- MOVEMENT ----------

var joystick: Node = null
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# @onready waits until the node tree is built before grabbing the node.

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if direction == Vector2.ZERO:
		if joystick == null:
			joystick = get_tree().get_first_node_in_group("joystick")
		if joystick != null:
			direction = joystick.output

	velocity = direction * move_speed
	move_and_slide()
	update_animation(direction)

func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("run")
		# Flip to face travel direction. Only flip on meaningful
		# horizontal movement so pure vertical motion doesn't jitter.
		if direction.x < -0.1:
			anim.flip_h = true
		elif direction.x > 0.1:
			anim.flip_h = false

# ---------- HEALTH ----------

@export var max_health: int = 10
# No i-frames: every enemy's hit lands, so a swarm hurts far more than one
# enemy. Each enemy has its own attack cooldown (see enemy.gd) instead.
@export var damage_taken_multiplier: float = 1.5
# Extra damage taken from the current wave; Main raises it each time a new
# enemy type starts spawning (0.25 per wave by default).
var wave_damage_bonus: float = 0.0
# Hits landing within this many seconds of the previous one build a streak;
# each streak step adds `streak_bonus` to the damage, up to `max_streak` steps.
@export var streak_window: float = 0.75
@export var streak_bonus: float = 0.25
@export var max_streak: int = 8

var health: int
var hit_streak: int = 0
var time_since_hit: float = INF
var pending_damage: float = 0.0  # Fractional damage carried to the next hit
var flash_timer: float = 0.0

func _ready() -> void:
	# Apply permanent meta upgrades purchased in the shop.
	max_health += 2 * GameData.meta_upgrades["max_hp"]
	fireball_damage += GameData.meta_upgrades["damage"]
	move_speed *= 1.0 + 0.05 * GameData.meta_upgrades["move_speed"]
	health = max_health

func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Already dead; several enemies can hit on the same frame

	# Swarm streak: rapid back-to-back hits hurt more and more.
	if time_since_hit <= streak_window:
		hit_streak = mini(hit_streak + 1, max_streak)
	else:
		hit_streak = 0
	time_since_hit = 0.0

	# Health is whole numbers, so carry the fraction over to the next hit:
	# 1 damage x1.5 lands as 1, 2, 1, 2... instead of always rounding.
	pending_damage += amount * damage_taken_multiplier * (1.0 + wave_damage_bonus) \
		* (1.0 + streak_bonus * hit_streak)
	var dealt: int = maxi(int(pending_damage), 1)
	pending_damage = maxf(pending_damage - dealt, 0.0)

	health -= dealt
	health_changed.emit(health, max_health)
	Audio.play("player_hurt", -2.0)

	# Feedback: brief red flash (no translucency — you're never invincible).
	anim.modulate = Color(1, 0.3, 0.3)
	flash_timer = 0.12

	if health <= 0:
		die()

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

func die() -> void:
	died.emit()
	# Hide and disable rather than delete — other scripts still hold
	# references to us; a hard delete would spray null errors.
	visible = false
	set_physics_process(false)
	set_process(false)

# ---------- AUTO-FIRE ----------

const FIREBALL_SCENE: PackedScene = preload("res://scenes/spells/fireball.tscn")

@export var fire_cooldown: float = 0.8
@export var fireball_damage: int = 1
@export var fireball_speed: float = 500.0

var fire_timer: float = 0.0

func _process(delta: float) -> void:
	time_since_hit += delta
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			anim.modulate = Color.WHITE

	fire_timer -= delta
	if fire_timer <= 0.0:
		var target: Node2D = find_nearest_enemy()
		if target != null:
			fire_at(target)
			fire_timer = fire_cooldown

func find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist: float = global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func fire_at(target: Node2D) -> void:
	var fireball: Area2D = FIREBALL_SCENE.instantiate()
	fireball.global_position = global_position
	fireball.direction = (target.global_position - global_position).normalized()
	fireball.damage = fireball_damage
	fireball.speed = fireball_speed
	get_parent().add_child(fireball)
	Audio.play("fireball_cast", -10.0, 0.1)

# ---------- XP & LEVELING ----------

var xp: int = 0
var level: int = 1
var xp_to_next: int = 5

func collect_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.5)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next)

# ---------- UPGRADES ----------

const LIGHTNING_SCENE: PackedScene = preload("res://scenes/spells/lightning.tscn")
const FROST_SCENE: PackedScene = preload("res://scenes/spells/frost_nova.tscn")
const ORBIT_SCENE: PackedScene = preload("res://scenes/spells/arcane_orbit.tscn")

func apply_upgrade(id: String) -> void:
	match id:
		"damage":
			fireball_damage += 1
		"fire_rate":
			fire_cooldown *= 0.75
		"move_speed":
			move_speed *= 1.15
		"projectile_speed":
			fireball_speed *= 1.3
		"unlock_lightning":
			add_child(LIGHTNING_SCENE.instantiate())
		"unlock_frost":
			add_child(FROST_SCENE.instantiate())
		"unlock_orbit":
			add_child(ORBIT_SCENE.instantiate())
