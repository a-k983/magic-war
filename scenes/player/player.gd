extends CharacterBody2D
# The Player: moves, auto-fires, collects XP, levels up, can now DIE.
# Which character this is (and so its sprites and starting weapon) comes from
# GameData.character: see config/characters.gd.

signal xp_changed(current_xp: int, xp_needed: int)
signal leveled_up(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal died

# Tuning lives in res://config/balance.tres (speed, damage, streaks...).
const BALANCE: Balance = preload("res://config/balance.tres")

var move_speed: float  # From BALANCE.player_speed; upgrades multiply it
var character: Dictionary = Characters.by_id(GameData.character)
var slow_factor: float = 1.0  # Below 1 while venom lasts (see apply_slow)
var slow_timer: float = 0.0

# ---------- MOVEMENT ----------

var joystick: Node = null
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# @onready waits until the node tree is built before grabbing the node.

func _physics_process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if direction == Vector2.ZERO:
		if joystick == null:
			joystick = get_tree().get_first_node_in_group("joystick")
		if joystick != null:
			direction = joystick.output

	slow_timer -= delta
	velocity = direction * move_speed * (slow_factor if slow_timer > 0.0 else 1.0)
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
# Damage multiplier and swarm-streak settings come from BALANCE.
var damage_taken_multiplier: float
# Extra damage taken from the current wave; Main raises it each time a new
# enemy type starts spawning (BALANCE.wave_damage_bonus per wave).
var wave_damage_bonus: float = 0.0
# Hits landing within streak_window seconds of the previous one build a
# streak; each step adds streak_bonus to the damage, up to max_streak steps.
var streak_window: float
var streak_bonus: float
var max_streak: int

var health: int
var hit_streak: int = 0
var time_since_hit: float = INF
var pending_damage: float = 0.0  # Fractional damage carried to the next hit
var flash_timer: float = 0.0
var regen_rate: float = 0.0      # HP/sec from the Regeneration shop upgrade
var pending_regen: float = 0.0   # Fractional HP carried until a whole 1 heals
var dodge_chance: float = 0.0    # From the Dodge shop upgrade (0.3 = 30%)

func _ready() -> void:
	anim.sprite_frames = Characters.build_frames(character)
	anim.play("idle")
	move_speed = BALANCE.player_speed
	weapon_damage = BALANCE.get(character["damage"])
	fire_cooldown = character["cooldown"]
	weapon_speed = character["speed"]
	weapon_reach = character["reach"]
	damage_taken_multiplier = BALANCE.damage_taken_multiplier
	streak_window = BALANCE.streak_window
	streak_bonus = BALANCE.streak_bonus
	max_streak = BALANCE.max_streak
	# Apply permanent meta upgrades purchased in the shop.
	max_health += 2 * GameData.meta_upgrades["max_hp"]
	weapon_damage += GameData.meta_upgrades["damage"]
	move_speed *= 1.0 + 0.05 * GameData.meta_upgrades["move_speed"]
	regen_rate = BALANCE.regen_per_level * GameData.meta_upgrades["regen"]
	fire_cooldown *= 1.0 - BALANCE.fire_rate_per_level * GameData.meta_upgrades["fire_rate"]
	dodge_chance = BALANCE.dodge_per_level * GameData.meta_upgrades["dodge"]
	health = max_health

func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Already dead; several enemies can hit on the same frame
	if super_timer > 0.0:
		return  # Super Mode: invincible
	if randf() < dodge_chance:
		# Dodged: a quick see-through flash instead of the red one. Doesn't
		# touch the swarm streak.
		anim.modulate = Color(0.7, 0.9, 1.0, 0.5)
		flash_timer = 0.12
		return

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

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration

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
const ARROW = preload("res://scenes/spells/arrow.gd")
const CLEAVE = preload("res://scenes/spells/cleave.gd")
const THRUST = preload("res://scenes/spells/lance_thrust.gd")

var fire_cooldown: float  # From the character; upgrades shorten it
var weapon_damage: int    # From the character's Balance entry; upgrades add to it
var weapon_speed: float   # Projectile speed; upgrades raise it
var weapon_reach: float   # Melee reach; 0 = a projectile, fires at any range

var fire_timer: float = 0.0

func _process(delta: float) -> void:
	time_since_hit += delta
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			anim.modulate = Color.WHITE
	if super_timer > 0.0:
		update_super(delta)
	if regen_rate > 0.0 and health < max_health:
		pending_regen += regen_rate * delta
		if pending_regen >= 1.0:
			heal(int(pending_regen))
			pending_regen -= int(pending_regen)

	fire_timer -= delta
	if fire_timer <= 0.0:
		var target: Node2D = find_nearest_enemy()
		if target != null and (weapon_reach <= 0.0
				or global_position.distance_to(target.global_position) <= weapon_reach):
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
	var aim: Vector2 = (target.global_position - global_position).normalized()
	var shot: Node2D
	match character["weapon"]:
		"fireball":
			shot = FIREBALL_SCENE.instantiate()
			shot.speed = weapon_speed
			Audio.play("fireball_cast", -10.0, 0.1)
		"arrow":
			shot = ARROW.new()
			shot.speed = weapon_speed
			shot.texture = load(Characters.UNITS_DIR + character["colour"] + " Units/Archer/Arrow.png")
			Audio.play("fireball_cast", -13.0, 0.2)
		"cleave":
			shot = CLEAVE.new()
			shot.reach = weapon_reach
		"thrust":
			shot = THRUST.new()
			shot.reach = weapon_reach
	shot.global_position = global_position
	shot.direction = aim
	shot.damage = weapon_damage
	get_parent().add_child(shot)

# ---------- SUPER MODE (invincibility pickup) ----------

const SUPER_AURA: Texture2D = preload("res://scenes/player/super_aura.svg")
const SUPER_TINT := Color(1.6, 1.35, 0.45)  # Golden glow (>1 = brighter than normal)
const SUPER_WARNING: float = 1.5            # Aura flickers this long before it ends

var super_timer: float = 0.0  # Seconds of invincibility left
var super_aura: Sprite2D
var super_sparks: CPUParticles2D

func go_super() -> void:
	# A second pickup refreshes the timer rather than stacking.
	super_timer = BALANCE.invincible_duration
	if super_aura == null:
		build_super_effects()
	super_aura.visible = true
	super_sparks.emitting = true
	flash_timer = 0.0  # So a pending hurt-flash doesn't wipe the gold tint
	anim.modulate = SUPER_TINT

func build_super_effects() -> void:
	# Spiky golden flames behind the sprite, added (light) blending so they glow.
	super_aura = Sprite2D.new()
	super_aura.texture = SUPER_AURA
	super_aura.position = Vector2(0, -14)
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	super_aura.material = glow
	add_child(super_aura)
	move_child(super_aura, anim.get_index())  # Draw before (behind) the sprite
	# Golden sparks streaming upward.
	super_sparks = CPUParticles2D.new()
	super_sparks.amount = 28
	super_sparks.lifetime = 0.55
	super_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	super_sparks.emission_sphere_radius = 34.0
	super_sparks.direction = Vector2.UP
	super_sparks.spread = 15.0
	super_sparks.gravity = Vector2(0, -260)
	super_sparks.initial_velocity_min = 40.0
	super_sparks.initial_velocity_max = 120.0
	super_sparks.scale_amount_min = 2.5
	super_sparks.scale_amount_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.98, 0.7))
	fade.set_color(1, Color(1.0, 0.75, 0.1, 0.0))
	super_sparks.color_ramp = fade
	super_sparks.material = glow
	super_sparks.emitting = false
	add_child(super_sparks)

func update_super(delta: float) -> void:
	super_timer -= delta
	if super_timer <= 0.0:
		super_aura.visible = false
		super_sparks.emitting = false
		anim.modulate = Color.WHITE
		return
	# Flames flicker and pulse; near the end they blink as a warning.
	var t: float = Time.get_ticks_msec() / 1000.0
	super_aura.scale = Vector2(1.0 + 0.06 * sin(t * 23.0), 1.0 + 0.1 * sin(t * 17.0))
	super_aura.modulate.a = 0.85 + 0.15 * sin(t * 31.0)
	if super_timer < SUPER_WARNING:
		super_aura.visible = int(super_timer * 10.0) % 2 == 0

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
# Weapons that level up: id after "level_" -> script. Each has set_level().
const LEVEL_WEAPONS: Dictionary = {
	"runeward": preload("res://scenes/spells/runeward.gd"),
	"starfall": preload("res://scenes/spells/starfall.gd"),
	"moonreaver": preload("res://scenes/spells/moonreaver.gd"),
	"thornwake": preload("res://scenes/spells/thornwake.gd"),
}

var weapon_nodes: Dictionary = {}   # Weapon id -> its node, once unlocked

func weapon_level(id: String) -> int:
	return weapon_nodes[id].level if weapon_nodes.has(id) else 0

func level_up_weapon(id: String) -> void:
	if not weapon_nodes.has(id):
		weapon_nodes[id] = LEVEL_WEAPONS[id].new()
		add_child(weapon_nodes[id])
		weapon_nodes[id].set_level(1)
	else:
		weapon_nodes[id].set_level(weapon_nodes[id].level + 1)

func apply_upgrade(id: String) -> void:
	if id.begins_with("level_"):
		level_up_weapon(id.trim_prefix("level_"))
		return
	match id:
		"damage":
			weapon_damage += 1
		"fire_rate":
			fire_cooldown *= 0.75
		"move_speed":
			move_speed *= 1.15
		"projectile_speed":
			weapon_speed *= 1.3
		"reach":
			weapon_reach *= 1.15
		"unlock_lightning":
			add_child(LIGHTNING_SCENE.instantiate())
		"unlock_frost":
			add_child(FROST_SCENE.instantiate())
		"unlock_orbit":
			add_child(ORBIT_SCENE.instantiate())
