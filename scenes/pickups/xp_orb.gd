extends Area2D
# XP Orb: dropped by dead enemies. Flies to the player when they get
# close (magnet effect), grants XP on contact.
# Looks like a small emerald sphere of mana with a swirling core, a soft
# halo, and a gentle bob — drawn in code like the spell visuals.

const FX = preload("res://scenes/spells/spell_fx.gd")

@export var xp_value: int = 1
@export var magnet_range: float = 150.0   # Start flying when player is this close
@export var magnet_speed: float = 400.0   # Faster than the player, so it catches up

@export var attracted_speed: float = 900.0 # Speed once a magnet pickup grabs us

var player: Node2D = null
var attracted: bool = false   # Set by the magnet pickup: fly in from any distance

var age: float = 0.0
var glow: Sprite2D = null

func _ready() -> void:
	add_to_group("xp_orbs")
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Random start point so a pile of orbs doesn't pulse in lockstep.
	age = randf() * TAU
	glow = FX.glow_sprite(Color(0.3, 1.0, 0.8, 0.6), 46.0)
	glow.show_behind_parent = true
	add_child(glow)

func _process(delta: float) -> void:
	age += delta
	# The halo breathes along with the sphere and bobs with it.
	var pulse: float = 1.0 + sin(age * 4.0) * 0.15
	glow.scale = Vector2.ONE * (46.0 / 64.0) * pulse
	glow.position.y = _bob()
	queue_redraw()  # Redraw every frame so the core swirls

func _bob() -> float:
	return sin(age * 3.0) * 2.5

func _draw() -> void:
	var c := Vector2(0.0, _bob())
	var pulse: float = 1.0 + sin(age * 4.0) * 0.06
	var r: float = 8.0 * pulse

	# Sphere = thin rim, emerald body, lighter inner layer.
	draw_circle(c, r + 1.0, Color(0.05, 0.4, 0.35, 0.9))
	draw_circle(c, r, Color(0.15, 0.85, 0.65))
	draw_circle(c + Vector2(0.0, 0.8), r * 0.72, Color(0.45, 1.0, 0.8))

	# Swirling core: two arcs of light chasing each other around.
	var spin: float = age * 5.0
	draw_arc(c, r * 0.45, spin, spin + PI * 0.8, 10, Color(0.85, 1.0, 0.9, 0.9), 1.4)
	draw_arc(c, r * 0.45, spin + PI, spin + PI * 1.8, 10, Color(0.85, 1.0, 0.9, 0.9), 1.4)
	draw_circle(c, r * 0.22, Color(0.95, 1.0, 0.95))

	# Glassy highlight, upper-left.
	draw_circle(c + Vector2(-r * 0.38, -r * 0.4), r * 0.2, Color(1, 1, 1, 0.85))

	# Occasional four-point twinkle on the rim.
	var twinkle: float = clampf(sin(age * 2.3) * 3.0 - 2.0, 0.0, 1.0)
	if twinkle > 0.0:
		var t := c + Vector2(r * 0.6, -r * 0.65)
		var s: float = 3.5 * twinkle
		var col := Color(1, 1, 1, twinkle)
		draw_line(t - Vector2(s, 0), t + Vector2(s, 0), col, 1.0)
		draw_line(t - Vector2(0, s), t + Vector2(0, s), col, 1.0)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if attracted:
		global_position = global_position.move_toward(
			player.global_position, attracted_speed * delta
		)
	# Magnet: if the player is near, slide toward them each frame.
	elif global_position.distance_to(player.global_position) < magnet_range:
		global_position = global_position.move_toward(
			player.global_position, magnet_speed * delta
		)

func _on_body_entered(body: Node2D) -> void:
	# Enemies also touch us — only the player may collect.
	if body.is_in_group("player"):
		body.collect_xp(xp_value)
		Audio.play("xp", -12.0, 0.15)
		FX.burst(get_tree().current_scene, global_position,
			Color(0.4, 1.0, 0.8), 6, 90.0, 0.25, 0.15)
		queue_free()
