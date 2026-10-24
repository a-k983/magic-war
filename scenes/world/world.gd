extends Node2D
# World: the arena. Hand-placed props (village, camp, groves...) live as
# child nodes in world.tscn. On top of those, this script adds:
#   - invisible walls around the arena, hidden behind a thick tree line
#   - scattered trees, rocks and bushes to fill the open ground
# Scatter uses a fixed seed, so the map is identical every run. Change
# `scatter_seed` for a different layout.

const PROP = preload("res://scenes/world/prop.gd")

@export var half_size: float = 2400.0      # Arena spans -half..+half on both axes
@export var scatter_seed: int = 7
@export var scatter_trees: int = 40
@export var scatter_rocks: int = 30
@export var scatter_bushes: int = 70
@export var spawn_clearing: float = 320.0  # Keep the player's start area open

var rng := RandomNumberGenerator.new()
# Where props already stand: x, y = position, z = how much room it needs
# (bigger for buildings, so nothing gets wedged against their walls and
# leaves a gap too narrow to walk through).
var taken: Array[Vector3] = []

func _ready() -> void:
	rng.seed = scatter_seed
	for child in get_children():
		var footprint: Vector2 = PROP.KINDS[child.kind][3]
		taken.append(Vector3(child.position.x, child.position.y, footprint.length() * 0.5 + 40.0))
	build_walls()
	build_tree_line()
	scatter(["tree1", "tree2", "tree3", "tree4"], scatter_trees, 150.0)
	scatter(["rock1", "rock2", "rock3", "rock4", "stump"], scatter_rocks, 120.0)
	scatter(["bush1", "bush2", "bush3"], scatter_bushes, 90.0)

func build_walls() -> void:
	# Four long invisible boxes just outside the play area.
	var walls := StaticBody2D.new()
	walls.collision_layer = 1 | 4
	var thickness: float = 200.0
	var length: float = half_size * 2.0 + thickness * 2.0
	for side in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(length, thickness) if side.y != 0 else Vector2(thickness, length)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = side * (half_size + thickness / 2.0)
		walls.add_child(collider)
	add_child(walls)

func build_tree_line() -> void:
	# Two staggered rows of trees just outside the walls.
	for row in 2:
		var dist: float = half_size + 60.0 + row * 110.0
		var step: float = 120.0
		var count: int = int(dist * 8.0 / step)
		for i in count:
			# Walk the square perimeter at distance `dist`.
			var t: float = (i + (row % 2) * 0.5) * step
			var pos: Vector2 = perimeter_point(dist, t)
			pos += Vector2(rng.randf_range(-25, 25), rng.randf_range(-25, 25))
			add_prop(["tree1", "tree2", "tree3", "tree4"][rng.randi() % 4], pos, false)

func perimeter_point(dist: float, t: float) -> Vector2:
	var side_len: float = dist * 2.0
	t = fmod(t, side_len * 4.0)
	if t < side_len:
		return Vector2(-dist + t, -dist)
	elif t < side_len * 2.0:
		return Vector2(dist, -dist + (t - side_len))
	elif t < side_len * 3.0:
		return Vector2(dist - (t - side_len * 2.0), dist)
	return Vector2(-dist, dist - (t - side_len * 3.0))

func scatter(kinds: Array, count: int, min_gap: float) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 30:
		tries += 1
		var pos := Vector2(rng.randf_range(-half_size + 120, half_size - 120),
			rng.randf_range(-half_size + 120, half_size - 120))
		if pos.length() < spawn_clearing or not is_clear(pos, min_gap):
			continue
		add_prop(kinds[rng.randi() % kinds.size()], pos, true)
		placed += 1

func is_clear(pos: Vector2, min_gap: float) -> bool:
	for other in taken:
		if pos.distance_to(Vector2(other.x, other.y)) < maxf(min_gap, other.z + 60.0):
			return false
	return true

func add_prop(kind: String, pos: Vector2, remember: bool) -> void:
	var prop: StaticBody2D = PROP.new()
	prop.kind = kind
	prop.flip = rng.randf() < 0.5
	prop.position = pos
	add_child(prop)
	if remember:
		taken.append(Vector3(pos.x, pos.y, 30.0))

func clamp_to_arena(pos: Vector2, margin: float) -> Vector2:
	var limit: float = half_size - margin
	return Vector2(clampf(pos.x, -limit, limit), clampf(pos.y, -limit, limit))
