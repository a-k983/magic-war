extends Node2D
# One Starfall star: a marker on the ground, the star dropping onto it, then
# a blast. Deletes itself.

const FX = preload("res://scenes/spells/spell_fx.gd")
const EXPLOSION_SHEET: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png")

const DROP_TIME: float = 0.55
const DROP_HEIGHT: float = 520.0

var damage: int = 1
var radius: float = 95.0
var age: float = 0.0

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age < DROP_TIME:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < radius:
			enemy.take_damage(damage)
	Audio.play("fireball_hit", -6.0, 0.15)
	FX.play_sheet(get_parent(), global_position, EXPLOSION_SHEET, 20.0, radius / 95.0)
	FX.burst(get_parent(), global_position, Color(0.75, 0.85, 1.0), 16, radius * 2.4, 0.4, 0.3)
	queue_free()

func _draw() -> void:
	var progress: float = age / DROP_TIME
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.7, 0.85, 1.0, 0.75), 2.5)
	draw_circle(Vector2.ZERO, radius * progress, Color(0.7, 0.85, 1.0, 0.16))
	# The star: bright head, tapering tail straight above it.
	var head := Vector2(0, -DROP_HEIGHT * (1.0 - progress * progress))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-13, 0), head + Vector2(13, 0), head + Vector2(0, -130),
	]), Color(0.65, 0.8, 1.0, 0.65))
	draw_circle(head, 15.0, Color(0.85, 0.93, 1.0))
	draw_circle(head, 8.0, Color.WHITE)
