extends Node2D
# One Thornwake patch: grows out of the ground, cuts and slows enemies on it,
# then withers.

const TICK: float = 0.6
const THORNS: int = 9

var radius: float = 58.0
var lifetime: float = 3.0
var damage: int = 1
var age: float = 0.0
var tick_timer: float = 0.0

func _ready() -> void:
	z_index = -1
	rotation = randf() * TAU

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	modulate.a = clampf((lifetime - age) / 0.6, 0.0, 1.0)
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = TICK
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < radius:
			enemy.take_damage(damage)
			enemy.apply_slow(0.6, 0.7)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * 0.8, Color(0.16, 0.3, 0.12, 0.5))
	for i in THORNS:
		var dir: Vector2 = Vector2.from_angle(TAU / THORNS * i)
		var side: Vector2 = dir.orthogonal() * 7.0
		var base: Vector2 = dir * radius * (0.3 if i % 2 == 0 else 0.55)
		draw_colored_polygon(PackedVector2Array([
			base - side, base + side, dir * radius,
		]), Color(0.36, 0.55, 0.2))
