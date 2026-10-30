extends CharacterBody2D
# The Enemy: animated creature that hunts the player, hurts on contact, dies.
# How it hunts is its `ai`: one brain_<ai>() function below for each enemy type
# in config/levels.gd.

signal killed  # Emitted once from die() — Main counts kills with it

const XP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/xp_orb.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/pickup.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/pickups/coin.tscn")

const BALANCE: Balance = preload("res://config/balance.tres")
const SHOT = preload("res://scenes/enemies/enemy_shot.gd")
const HAZARD = preload("res://scenes/enemies/enemy_hazard.gd")
const FX = preload("res://scenes/spells/spell_fx.gd")
const ENEMY_ART: String = "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/"
const BONE: Texture2D = preload(ENEMY_ART + "Gnoll/Gnoll_Bone.png")
const HARPOON: Texture2D = preload(ENEMY_ART + "Harpoon Shark/Harpoon.png")
const BOMB: Texture2D = preload(ENEMY_ART + "Bomb Fish/Bomb_Idle.png")
const HEX_BOLT: Texture2D = preload(ENEMY_ART + "Hex Shaman/Hex Shaman_Projectile.png")
const FLIERS: Array[String] = ["swoop", "sting"]  # Pass over buildings and trees
const WINDUP_TINT := Color(1.7, 0.75, 0.6)        # "About to strike" warning glow

# Base stats come from res://config/balance.tres (set in _init, so Main can
# still override them for elites and apply wave scaling before add_child).
var move_speed: float
var max_health: int
var contact_damage: int
var attack_cooldown: float  # Seconds between this enemy's hits
@export var xp_drop: int = 1
var coin_drop: int  # From BALANCE.coins_per_enemy (elites: coins_per_elite, set by Main)
# Chance per death for each pickup: health 1 in ~80, magnet 1 in ~170,
# nuke 1 in 500. Super Mode only drops once its shop upgrade is bought.
@export var pickup_chances: Dictionary = {"health": 0.012, "magnet": 0.006, "nuke": 0.002, "invincible": 0.0}
# Shop "Luck" upgrades that raise a pickup's chance:
# kind -> [GameData.meta_upgrades key, BALANCE per-level property].
const LUCK_UPGRADES: Dictionary = {
	"health": ["potion_drop", "potion_drop_per_level"],
	"nuke": ["nuke_drop", "nuke_drop_per_level"],
	"invincible": ["invincible_drop", "invincible_drop_per_level"],
	"magnet": ["magnet_drop", "magnet_drop_per_level"],
}

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
# Our collision radius + the player's: closer than this = touching.
var touch_distance: float = 0.0

# Brain state. Each brain is a small state machine: ai_state is its current
# step, ai_timer counts down to the next, ai_dir is a locked-in heading.
var ai: String = "march"       # Set by Main before add_child
var ai_state: int = 0
var ai_timer: float = 0.0
var ai_dir: Vector2 = Vector2.ZERO
var ai_clock: float = randf() * TAU  # Random phase, so a pack doesn't move in step
var shot_timer: float = 1.0          # Countdown to the next shot, for ranged brains
var speed_factor: float = 1.0  # Set each frame by the brain
var can_bite: bool = true      # Set each frame by the brain
var damage_resist: float = 0.0 # 0.85 = takes 15% damage (a turtle in its shell)
var aim_line: Vector2 = Vector2.ZERO  # Drawn as a warning while a throw is lined up
var attack_anim_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _init() -> void:
	move_speed = BALANCE.enemy_speed
	max_health = BALANCE.enemy_health
	contact_damage = BALANCE.enemy_damage
	attack_cooldown = BALANCE.enemy_attack_cooldown
	coin_drop = BALANCE.coins_per_enemy

func _ready() -> void:
	if custom_frames != null:
		anim.sprite_frames = custom_frames
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		# scale: elites are scaled up 2.5x (see main.gd).
		touch_distance = $CollisionShape2D.shape.radius * scale.x \
			+ player.get_node("CollisionShape2D").shape.radius
	if ai in FLIERS:
		collision_mask = 0
	anim.play("run")

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	ai_clock += delta
	ai_timer -= delta
	shot_timer -= delta
	speed_factor = 1.0
	can_bite = true
	var direction: Vector2 = call("brain_" + ai, to_player)

	# Walk around buildings/trees: if we're pressed against one and still
	# heading into it, steer along its edge instead. move_and_slide alone
	# already slides at an angle, but stalls when we hit a wall head-on.
	if wall_normal != Vector2.ZERO and direction != Vector2.ZERO \
			and direction.dot(wall_normal) < -0.2:
		var along: Vector2 = wall_normal.orthogonal() * detour_side
		direction = (along + direction * 0.25).normalized()

	velocity = direction * move_speed * speed_multiplier * speed_factor
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
			detour_side = 1.0 if touching.orthogonal().dot(to_player) >= 0.0 else -1.0
		# Stick with that side for a moment, so rounding a corner (which
		# briefly breaks contact) doesn't make us turn back.
		detour_memory = 0.6
	else:
		detour_memory -= delta
	wall_normal = touching

	# Face the direction of travel, or the player when standing still.
	var facing: Vector2 = direction if direction != Vector2.ZERO else to_player
	if facing.x < -0.1:
		anim.flip_h = true
	elif facing.x > 0.1:
		anim.flip_h = false

	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0.0:
			anim.play("run")

	# Contact damage — each enemy has its own cooldown (the player has no
	# i-frames), so every extra enemy in a swarm adds its own hits.
	# The player is on its own physics layer and passes through enemies,
	# so "touching" means the two collision circles overlap.
	attack_timer -= delta
	if can_bite and attack_timer <= 0.0 and player.visible \
			and global_position.distance_to(player.global_position) <= touch_distance:
		player.take_damage(contact_damage)
		if ai == "slither":
			player.apply_slow(0.6, 1.5)  # Venom
		show_attack()
		attack_timer = attack_cooldown

func show_attack() -> void:
	anim.play("attack")
	attack_anim_timer = 0.5

func enter_state(state: int, seconds: float) -> void:
	ai_state = state
	ai_timer = seconds
	modulate = Color.WHITE

func wind_up() -> void:
	modulate = WINDUP_TINT

# ---------- BRAINS ----------
# Each returns the direction to move this frame (ZERO = stand still) and may
# set speed_factor and can_bite. Timings are seconds, speeds are multiples of
# move_speed.

# Skull: the plain relentless march. Everyone else is measured against it.
func brain_march(to_player: Vector2) -> Vector2:
	return to_player.normalized()

# Gnome: scurries in tight zigzags, hard to line up a shot on.
func brain_scurry(to_player: Vector2) -> Vector2:
	return to_player.normalized().rotated(sin(ai_clock * 7.0) * 0.95)

# Spider: crouches, then leaps. Stop-start instead of a steady walk.
func brain_pounce(to_player: Vector2) -> Vector2:
	if ai_timer <= 0.0:
		if ai_state == 0:
			enter_state(1, 0.4)
			ai_dir = to_player.normalized()
		else:
			enter_state(0, 0.85)
	if ai_state == 1:
		speed_factor = 3.4
		return ai_dir
	if ai_timer < 0.35:
		wind_up()
	return Vector2.ZERO

# Thief: runs for your back, then closes in.
func brain_flank(to_player: Vector2) -> Vector2:
	if to_player.length() < 200.0:
		speed_factor = 1.3
		return to_player.normalized()
	var behind: Vector2 = player.velocity.normalized() * -220.0
	if behind == Vector2.ZERO:
		behind = to_player.normalized().orthogonal() * 220.0  # Standing still: circle
	return (player.global_position + behind - global_position).normalized()

# Lizard: stops, locks on, then charges in a line it can't steer out of.
func brain_charge(to_player: Vector2) -> Vector2:
	match ai_state:
		0:
			if to_player.length() < 420.0:
				enter_state(1, 0.55)
			return to_player.normalized()
		1:
			wind_up()
			if ai_timer <= 0.0:
				enter_state(2, 0.8)
				ai_dir = to_player.normalized()
			return Vector2.ZERO
		2:
			speed_factor = 3.0
			if ai_timer <= 0.0:
				enter_state(3, 0.6)
			return ai_dir
	if ai_timer <= 0.0:
		enter_state(0, 0.0)
	return Vector2.ZERO

# Torch Goblin: sets the ground alight behind it, walling you in with fire.
func brain_arson(to_player: Vector2) -> Vector2:
	if ai_timer <= 0.0:
		ai_timer = 1.3
		spawn_hazard(global_position, 58.0, 0.25, 3.0, Color(1.0, 0.4, 0.1))
	return to_player.normalized()

# Spear Goblin: circles out of reach, darts in to stab, hops back out.
func brain_skirmish(to_player: Vector2) -> Vector2:
	match ai_state:
		0:
			if to_player.length() < 250.0:
				enter_state(1, 1.1)
			return to_player.normalized()
		1:
			if ai_timer < 0.3:
				wind_up()
			if ai_timer <= 0.0:
				enter_state(2, 0.3)
				ai_dir = to_player.normalized()
				show_attack()
			speed_factor = 0.8
			return to_player.normalized().orthogonal()
		2:
			speed_factor = 3.6
			if ai_timer <= 0.0:
				enter_state(3, 0.55)
			return ai_dir
	speed_factor = 1.2
	if ai_timer <= 0.0:
		enter_state(0, 0.0)
	return -ai_dir

# Gnoll: keeps its distance and throws spinning bones.
func brain_kite(to_player: Vector2) -> Vector2:
	if shot_timer <= 0.0 and to_player.length() < 560.0:
		shot_timer = 2.4
		show_attack()
		spawn_shot(BONE, to_player.normalized(), 430.0, 14.0, 0.0)
	return keep_distance(to_player, 300.0, 460.0)

func keep_distance(to_player: Vector2, near: float, far: float) -> Vector2:
	# Back off when too close, approach when too far, sidestep in between.
	var dist: float = to_player.length()
	if dist < near:
		return -to_player.normalized()
	if dist > far:
		return to_player.normalized()
	speed_factor = 0.5
	return to_player.normalized().orthogonal() * (1.0 if sin(ai_clock * 0.7) > 0.0 else -1.0)

# Panda: lumbers up and slams the ground. Step out of the ring in time.
func brain_slam(to_player: Vector2) -> Vector2:
	match ai_state:
		0:
			if to_player.length() < 175.0:
				enter_state(1, 0.7)
				spawn_hazard(global_position, 185.0, 0.7, 0.0, Color(1.0, 0.75, 0.3))
				show_attack()
			return to_player.normalized()
		1:
			wind_up()
			if ai_timer <= 0.0:
				enter_state(2, 0.9)
			return Vector2.ZERO
	if ai_timer <= 0.0:
		enter_state(0, 0.0)
	return Vector2.ZERO

# Bear: slow until it smells you. Speeds up as you get close and as it's hurt.
func brain_enrage(to_player: Vector2) -> Vector2:
	var closeness: float = 1.0 - clampf(to_player.length() / 700.0, 0.0, 1.0)
	var hurt: float = 1.0 - float(health) / max_health
	speed_factor = 1.0 + 1.5 * closeness + 1.2 * hurt
	modulate = Color.WHITE.lerp(WINDUP_TINT, clampf(hurt, 0.0, 1.0))
	return to_player.normalized()

# Paddle Shark: swims under the ground, fast and harmless, surfaces to bite.
func brain_burrow(to_player: Vector2) -> Vector2:
	if ai_timer <= 0.0:
		enter_state(1 - ai_state, 1.4 if ai_state == 0 else 2.2)
	if ai_state == 1:
		speed_factor = 0.5
		return to_player.normalized()
	modulate.a = 0.22
	speed_factor = 2.0
	can_bite = false
	if to_player.length() < 80.0:
		enter_state(1, 1.4)
	return to_player.normalized().rotated(sin(ai_clock * 5.0) * 0.5)

# Snake: wide lazy S-curves. Its bite is venom that slows you (see above).
func brain_slither(to_player: Vector2) -> Vector2:
	return to_player.normalized().rotated(sin(ai_clock * 2.6) * 1.2)

# Harpoon Shark: stops at long range, aims, throws along a line you can read.
func brain_harpoon(to_player: Vector2) -> Vector2:
	match ai_state:
		0:
			if to_player.length() < 540.0 and shot_timer <= 0.0:
				enter_state(1, 0.85)
				ai_dir = to_player.normalized()
				aim_line = ai_dir * 900.0 / scale.x
				queue_redraw()
				return Vector2.ZERO
			return keep_distance(to_player, 380.0, 520.0)
		1:
			wind_up()
			if ai_timer <= 0.0:
				enter_state(2, 0.5)
				shot_timer = 2.6
				aim_line = Vector2.ZERO
				queue_redraw()
				show_attack()
				spawn_shot(HARPOON, ai_dir, 950.0, 0.0, 0.0)
			return Vector2.ZERO
	if ai_timer <= 0.0:
		enter_state(0, 0.0)
	return Vector2.ZERO

func _draw() -> void:
	if aim_line != Vector2.ZERO:
		draw_line(Vector2.ZERO, aim_line, Color(1.0, 0.25, 0.2, 0.55), 3.0)

# Bomb Fish: lobs bombs at where you are now. Keep moving.
func brain_lob(to_player: Vector2) -> Vector2:
	if shot_timer <= 0.0 and to_player.length() < 520.0:
		shot_timer = 2.6
		show_attack()
		spawn_hazard(player.global_position, 115.0, 1.1, 0.0, Color(1.0, 0.25, 0.2), BOMB)
	return keep_distance(to_player, 260.0, 420.0)

# Turtle: plods forward, pulls into its nearly unbreakable shell, then rushes.
func brain_shell(to_player: Vector2) -> Vector2:
	if ai_timer <= 0.0:
		ai_state = (ai_state + 1) % 3
		ai_timer = [2.2, 1.5, 1.0][ai_state]
		modulate = Color(0.6, 0.75, 1.0) if ai_state == 1 else Color.WHITE
	damage_resist = 0.85 if ai_state == 1 else 0.0
	if ai_state == 1:
		can_bite = false
		return Vector2.ZERO
	if ai_state == 2:
		speed_factor = 2.4
	return to_player.normalized()

# Giant Bat: circles overhead, then swoops straight through you and out.
func brain_swoop(to_player: Vector2) -> Vector2:
	if ai_state == 1:
		speed_factor = 2.8
		if ai_timer <= 0.0:
			enter_state(0, randf_range(1.6, 2.6))
		return ai_dir
	if ai_timer <= 0.0:
		enter_state(1, (to_player.length() + 280.0) / (move_speed * 2.8))
		ai_dir = to_player.normalized()
	var radial: float = clampf((to_player.length() - 300.0) / 150.0, -1.0, 1.0)
	return (to_player.normalized() * radial + to_player.normalized().orthogonal()).normalized()

# Bumblebee: hovers in a jittery buzz, darts in to sting, flees.
func brain_sting(to_player: Vector2) -> Vector2:
	if ai_timer <= 0.0:
		ai_state = (ai_state + 1) % 3
		ai_timer = [1.8, 0.4, 0.8][ai_state]
		ai_dir = to_player.normalized()
	if ai_state == 1:
		speed_factor = 2.6
		return ai_dir
	if ai_state == 2:
		return -ai_dir
	var jitter: Vector2 = Vector2.from_angle(ai_clock * 19.0 + sin(ai_clock * 7.0) * 3.0)
	return (keep_distance(to_player, 170.0, 210.0) + jitter).normalized()

# Imp: walks a little, then vanishes and reappears right beside you.
func brain_blink(to_player: Vector2) -> Vector2:
	if ai_state == 1:
		modulate.a = clampf(ai_timer / 0.35, 0.0, 1.0)
		if ai_timer <= 0.0:
			teleport_near_player(150.0)
			enter_state(0, 3.0)
		return Vector2.ZERO
	if ai_timer <= 0.0:
		enter_state(1, 0.35)
	return to_player.normalized()

func teleport_near_player(distance: float) -> void:
	FX.burst(get_parent(), global_position, Color(0.8, 0.3, 1.0), 14, 180.0, 0.35, 0.25)
	global_position = get_parent().open_spot_near(player.global_position, distance)
	FX.burst(get_parent(), global_position, Color(0.8, 0.3, 1.0), 14, 180.0, 0.35, 0.25)

# Hex Shaman: stays back casting bolts that curve after you, and teleports
# away if you get close.
func brain_hex(to_player: Vector2) -> Vector2:
	if to_player.length() < 180.0 and ai_timer <= 0.0:
		ai_timer = 4.0
		teleport_near_player(460.0)
	if shot_timer <= 0.0 and to_player.length() < 620.0:
		shot_timer = 2.8
		show_attack()
		spawn_shot(HEX_BOLT, to_player.normalized(), 260.0, 0.0, 1.5)
	return keep_distance(to_player, 340.0, 480.0)

# Minotaur: a bull rush with a wide turning circle. It tracks you, but can't
# turn fast. Lead it into a wall and it stuns itself.
func brain_bullrush(to_player: Vector2) -> Vector2:
	match ai_state:
		0:
			if to_player.length() < 560.0:
				enter_state(1, 0.7)
				ai_dir = to_player.normalized()
			return to_player.normalized()
		1:
			wind_up()
			if ai_timer <= 0.0:
				enter_state(2, 2.6)
			return Vector2.ZERO
		2:
			speed_factor = 3.2
			ai_dir = ai_dir.rotated(clampf(ai_dir.angle_to(to_player), -0.024, 0.024))
			if wall_normal != Vector2.ZERO:
				enter_state(3, 1.6)  # Crashed into something
			elif ai_timer <= 0.0:
				enter_state(3, 0.7)
			return ai_dir
	if ai_timer <= 0.0:
		enter_state(0, 0.0)
	return Vector2.ZERO

func spawn_shot(sheet: Texture2D, direction: Vector2, speed: float, spin: float, homing: float) -> void:
	var shot: Node2D = SHOT.new()
	shot.sheet = sheet
	shot.direction = direction
	shot.speed = speed
	shot.spin = spin
	shot.homing = homing
	shot.damage = contact_damage
	shot.global_position = global_position
	get_parent().add_child(shot)

func spawn_hazard(pos: Vector2, radius: float, fuse: float, linger: float, color: Color,
		icon: Texture2D = null) -> void:
	var hazard: Node2D = HAZARD.new()
	hazard.radius = radius * scale.x
	hazard.fuse = fuse
	hazard.linger = linger
	hazard.color = color
	hazard.icon = icon
	hazard.damage = contact_damage
	hazard.global_position = pos
	get_parent().add_child(hazard)

func take_damage(amount: int) -> void:
	health -= maxi(roundi(amount * (1.0 - damage_resist)), 1)
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
	if is_queued_for_deletion():
		return  # Already dying (e.g. a fireball and a nuke on the same frame)
	killed.emit()
	Audio.play("enemy_die", -9.0, 0.15)
	if drop_pickup:
		# Luck shop upgrades raise every enemy's chance for their pickup.
		var chances: Dictionary = pickup_chances.duplicate()
		for kind in LUCK_UPGRADES:
			var luck: Array = LUCK_UPGRADES[kind]
			chances[kind] = chances.get(kind, 0.0) \
				+ BALANCE.get(luck[1]) * GameData.meta_upgrades[luck[0]]
		# One roll decides which pickup (if any) drops.
		var roll: float = randf()
		for kind in chances:
			roll -= chances[kind]
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
