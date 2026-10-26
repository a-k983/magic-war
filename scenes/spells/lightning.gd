extends Node2D
# Lightning Arc: periodically zaps a random enemy in range. Instant hit.

const FX = preload("res://scenes/spells/spell_fx.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var cooldown: float = 1.5
var damage: int = BALANCE.lightning_damage  # Tune in res://config/balance.tres
@export var strike_range: float = 400.0

var timer: float = 0.0

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		timer = cooldown
		strike()

func strike() -> void:
	# Collect all enemies within range of the player (our parent).
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < strike_range:
			candidates.append(enemy)
	if candidates.is_empty():
		return

	var target: Node2D = candidates.pick_random()
	target.take_damage(damage)
	draw_bolt(global_position, target.global_position)
	Audio.play("lightning", -5.0, 0.1)

func draw_bolt(from: Vector2, to: Vector2) -> void:
	# The whole effect lives under one Node2D so it fades and deletes as one.
	# Added to the world root so the bolt doesn't move with the player.
	var bolt := Node2D.new()
	bolt.z_index = 5  # Above everything in the y-sorted world
	get_tree().current_scene.add_child(bolt)

	# Line2D = a polyline node. Three stacked on the same zig-zag path:
	# wide soft blue glow, yellow body, thin white-hot core.
	var layers: Array[Line2D] = []
	for style in [[16.0, Color(0.45, 0.65, 1.0, 0.45)], [7.0, Color(1.0, 0.9, 0.3)], [2.5, Color.WHITE]]:
		layers.append(make_line(bolt, style[0], style[1]))
	layers[0].material = FX.additive_material()

	# A thinner fork that splits off partway along and fizzles out.
	var fork: Line2D = make_line(bolt, 3.0, Color(1.0, 0.95, 0.55))

	# Rolling a new random path = the bolt "jumps". Called once now and
	# once more a moment later for a flicker.
	var reroll := func() -> void:
		var path: PackedVector2Array = jagged_path(from, to)
		for line in layers:
			line.points = path
		var fork_from: Vector2 = path[path.size() / 2]
		var fork_dir: Vector2 = (to - from).normalized().rotated(randf_range(-0.9, 0.9))
		fork.points = jagged_path(fork_from, fork_from + fork_dir * randf_range(60.0, 120.0))
	reroll.call()

	# Impact: a bright flash on the target plus a spray of sparks.
	var flash: Sprite2D = FX.glow_sprite(Color(1.0, 0.95, 0.6), 150.0)
	flash.position = to
	bolt.add_child(flash)
	FX.burst(get_tree().current_scene, to, Color(1.0, 0.9, 0.4), 10, 220.0, 0.3, 0.22)

	# Tween = animate a property over time (CSS transition, but in code).
	var tween := bolt.create_tween()
	tween.tween_interval(0.06)
	tween.tween_callback(reroll)
	tween.tween_property(bolt, "modulate:a", 0.0, 0.22)  # Fade alpha to 0
	tween.tween_callback(bolt.queue_free)  # Then delete

func make_line(parent: Node, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(line)
	return line

func jagged_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	# Walk the straight line in ~35px steps, nudging each point sideways
	# by a random amount. The two ends stay exactly on target.
	var points := PackedVector2Array([from])
	var steps: int = maxi(2, int(from.distance_to(to) / 35.0))
	var sideways: Vector2 = (to - from).orthogonal().normalized()
	for i in range(1, steps):
		points.append(from.lerp(to, float(i) / steps) + sideways * randf_range(-16.0, 16.0))
	points.append(to)
	return points
