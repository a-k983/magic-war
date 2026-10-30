extends Node2D
# Enemy Hazard: a danger zone on the ground. Shows a warning for `fuse`
# seconds, then hurts the player inside it. linger = 0 is one blast (a bomb,
# a ground slam); linger > 0 keeps burning, hitting every `tick` seconds.

const FX = preload("res://scenes/spells/spell_fx.gd")
const EXPLOSION_SHEET: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_02.png")

var radius: float = 100.0
var fuse: float = 1.0
var linger: float = 0.0
var tick: float = 0.6
var damage: int = 1
var color: Color = Color(1.0, 0.35, 0.15)
var icon: Texture2D = null     # Optional sprite sitting in the middle (a bomb)

var player: Node2D = null
var age: float = 0.0
var tick_timer: float = 0.0

func _ready() -> void:
	z_index = -1  # On the ground: under the characters, above the grass
	player = get_tree().get_first_node_in_group("player")
	if icon != null:
		var sprite := Sprite2D.new()
		sprite.texture = icon
		add_child(sprite)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age < fuse:
		return
	if linger <= 0.0:
		hurt_player()
		Audio.play("fireball_hit", -6.0, 0.1)
		FX.play_sheet(get_parent(), global_position, EXPLOSION_SHEET, 20.0, radius / 90.0)
		queue_free()
		return
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick
		hurt_player()
	if age >= fuse + linger:
		queue_free()

func hurt_player() -> void:
	if player != null and player.visible \
			and global_position.distance_to(player.global_position) < radius:
		player.take_damage(damage)

func _draw() -> void:
	if age < fuse:
		# Warning: a ring that fills in as the fuse burns down.
		var progress: float = age / fuse if fuse > 0.0 else 1.0
		draw_circle(Vector2.ZERO, radius * progress, Color(color, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.9), 3.0)
		return
	# Burning: flickers, and fades in its last half second.
	var fade: float = clampf((fuse + linger - age) / 0.5, 0.0, 1.0)
	var flicker: float = 0.85 + 0.15 * sin(age * 19.0)
	draw_circle(Vector2.ZERO, radius * flicker, Color(color, 0.42 * fade))
	draw_circle(Vector2.ZERO, radius * 0.55 * flicker, Color(1.0, 0.8, 0.3, 0.45 * fade))
