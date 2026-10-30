extends Node2D
# Runeward Circle: a ring of runes around the player. Enemies standing inside
# take damage every tick. Each level makes it larger and hit harder.

const BALANCE: Balance = preload("res://config/balance.tres")
const RUNE_COUNT: int = 10

var level: int = 1
var radius: float = 0.0
var damage: int = 0
var tick_timer: float = 0.0

func _ready() -> void:
	z_index = -1  # On the ground, under the characters

func set_level(new_level: int) -> void:
	level = new_level
	radius = BALANCE.runeward_radius + BALANCE.runeward_radius_per_level * (level - 1)
	damage = BALANCE.runeward_damage + BALANCE.runeward_damage_per_level * (level - 1)
	queue_redraw()

func _process(delta: float) -> void:
	rotation += 0.5 * delta
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = BALANCE.runeward_tick
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < radius:
			enemy.take_damage(damage)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.8, 0.3, 0.13))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, 0.75), 3.0)
	draw_arc(Vector2.ZERO, radius - 14.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, 0.3), 2.0)
	# Rune marks: a small angular glyph at each point around the band.
	for i in RUNE_COUNT:
		var dir: Vector2 = Vector2.from_angle(TAU / RUNE_COUNT * i)
		var center: Vector2 = dir * (radius - 7.0)
		var side: Vector2 = dir.orthogonal() * 6.0
		draw_line(center - dir * 7.0, center + dir * 7.0, Color(1.0, 0.92, 0.6, 0.9), 2.0)
		draw_line(center - side, center + dir * 4.0 + side, Color(1.0, 0.92, 0.6, 0.9), 2.0)
