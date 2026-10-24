extends Area2D
# Fireball: flies in a straight line, damages the first enemy it touches.
# Looks like a flickering comet with an ember trail; explodes on impact.

const FX = preload("res://scenes/spells/spell_fx.gd")
const EXPLOSION_SHEET: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png")

@export var speed: float = 500.0
@export var damage: int = 1
@export var lifetime: float = 2.0  # Seconds before despawning if it misses

# Set by the player when firing — which way to fly.
var direction: Vector2 = Vector2.RIGHT
var age: float = 0.0

func _ready() -> void:
	# body_entered fires when a physics body (like an Enemy) overlaps us.
	body_entered.connect(_on_body_entered)

	# Point our local +X along the flight path, so the flame drawn in
	# _draw (head at +X, tail at -X) faces the right way.
	rotation = direction.angle()

	# Soft orange halo and a trail of embers, both drawn behind the flame.
	var glow: Sprite2D = FX.glow_sprite(Color(1.0, 0.45, 0.1, 0.7), 90.0)
	glow.show_behind_parent = true
	add_child(glow)
	var embers: CPUParticles2D = FX.trail(Color(1.0, 0.55, 0.15), 24, 0.35, 0.4)
	embers.position = Vector2(-12, 0)
	embers.show_behind_parent = true
	add_child(embers)

	# Self-destruct after `lifetime` seconds so missed shots don't
	# pile up in memory forever.
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	age += delta
	queue_redraw()  # Redraw every frame so the flame flickers

func _draw() -> void:
	# Three nested teardrops: red-orange outside, white-hot inside.
	# The tail length wobbles with a fast sine wave = flicker.
	var flicker: float = sin(age * 40.0)
	draw_colored_polygon(teardrop(16.0, 44.0 + flicker * 7.0), Color(0.92, 0.25, 0.05))
	draw_colored_polygon(teardrop(11.5, 28.0 + flicker * 5.0), Color(1.0, 0.6, 0.1))
	draw_colored_polygon(teardrop(6.5, 13.0 + flicker * 3.0), Color(1.0, 0.96, 0.65))

func teardrop(radius: float, tail: float) -> PackedVector2Array:
	# A circle arc for the round head, plus one point for the tail tip.
	var points := PackedVector2Array()
	for i in 13:
		var angle: float = deg_to_rad(-120.0 + i * 20.0)
		points.append(Vector2.from_angle(angle) * radius)
	points.append(Vector2(-tail, 0))
	return points

func _physics_process(delta: float) -> void:
	# Area2D has no built-in velocity — we move it manually each frame.
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Only hit enemies — the player also has take_damage now,
	# and we spawn on top of them!
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		explode()
		queue_free()

func explode() -> void:
	# Spawned into the world (our parent), not as our children — we are
	# about to be deleted and children would vanish with us.
	Audio.play("fireball_hit", -7.0, 0.1)
	FX.play_sheet(get_parent(), global_position, EXPLOSION_SHEET, 20.0, 0.8)
	FX.burst(get_parent(), global_position, Color(1.0, 0.6, 0.15), 10, 200.0, 0.35, 0.3)
