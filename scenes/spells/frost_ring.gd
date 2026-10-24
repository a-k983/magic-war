extends Node2D
# Frost Ring: the one-shot visual for Frost Nova. An icy shockwave that
# expands to `radius` with a ring of ice shards, then deletes itself.

@export var radius: float = 250.0
@export var duration: float = 0.55
@export var shard_count: int = 12

# 0 = just cast, 1 = finished. A tween drives it; _draw reads it.
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	# On the ground: under the characters, above the grass.
	z_index = -1
	# Random spin so two blasts in a row don't look identical.
	rotation = randf() * TAU
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_callback(queue_free)

func _draw() -> void:
	# Ease-out: the wave shoots out fast, then slows as it reaches full
	# size. The fade does the opposite — holds, then drops off at the end.
	var r: float = radius * (1.0 - pow(1.0 - progress, 3.0))
	var fade: float = 1.0 - progress * progress

	# Frosty haze filling the blast area.
	draw_circle(Vector2.ZERO, r, Color(0.6, 0.9, 1.0, 0.22 * fade))
	# The shockwave: thick pale-blue band with a crisp white edge.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.55, 0.85, 1.0, 0.9 * fade), lerp(18.0, 4.0, progress))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, fade), 3.0)

	# Ice shards riding the wave, pointing outward. Alternate long/short.
	for i in shard_count:
		var dir: Vector2 = Vector2.from_angle((TAU / shard_count) * i)
		var side: Vector2 = dir.orthogonal()
		var length: float = 46.0 if i % 2 == 0 else 28.0
		var shard := PackedVector2Array([
			dir * (r + length),          # Tip
			dir * r + side * 7.0,
			dir * (r - length * 0.35),   # Back end
			dir * r - side * 7.0,
		])
		draw_colored_polygon(shard, Color(0.85, 0.97, 1.0, fade))
		draw_polyline(shard + PackedVector2Array([shard[0]]), Color(0.35, 0.65, 0.95, fade), 2.0)
