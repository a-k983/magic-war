extends Control
# Lock Icon: a padlock drawn in code (the art packs have none), shown over a
# locked hero on the hero select screen. shatter() plays the lock-breaking
# animation: it rattles, the shackle snaps open, the body splits in two and
# the halves tumble away in a burst of sparks, then the icon frees itself.

signal shattered

const GOLD := Color(0.98, 0.76, 0.27)
const GOLD_DARK := Color(0.78, 0.5, 0.14)
const STEEL := Color(0.8, 0.83, 0.9)
const EDGE := Color(0.24, 0.13, 0.07)
const SPARK_COLOURS: Array[Color] = [Color(1.0, 0.85, 0.35), Color(1, 1, 1), Color(1.0, 0.6, 0.2)]

var snap: float = 0.0    # 0..1: shackle springing open
var burst: float = 0.0   # 0..1: halves flying apart and fading
var sparks: Array = []   # [position, velocity, colour, size]

func _init() -> void:
	custom_minimum_size = Vector2(64, 72)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func shatter() -> void:
	var tween := create_tween()
	# Rattle...
	for i in 6:
		tween.tween_property(self, "rotation", 0.22 * (1 if i % 2 == 0 else -1), 0.05)
	tween.tween_property(self, "rotation", 0.0, 0.05)
	# ...snap...
	tween.tween_property(self, "snap", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(spray_sparks)
	# ...and burst.
	tween.tween_property(self, "burst", 1.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		shattered.emit()
		queue_free())

func spray_sparks() -> void:
	for i in 18:
		var angle: float = randf() * TAU
		sparks.append([size * 0.5, Vector2.from_angle(angle) * randf_range(90.0, 260.0),
			SPARK_COLOURS[randi() % SPARK_COLOURS.size()], randf_range(2.5, 5.5)])

func _process(delta: float) -> void:
	for spark in sparks:
		spark[0] += spark[1] * delta
		spark[1] = spark[1] * 0.93 + Vector2(0, 260.0 * delta)
		spark[3] = maxf(spark[3] - delta * 5.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var centre: Vector2 = size * 0.5 + Vector2(0, 8)
	var fade: float = 1.0 - burst
	var split: float = burst * 40.0
	var drop: float = burst * burst * 70.0

	# Shackle: a thick steel arch whose right leg pops out of the body.
	var arch: Vector2 = centre + Vector2(0, -12 - snap * 10.0 - drop * 0.4)
	for pass_ in 2:
		var width: float = 10.0 if pass_ == 0 else 5.5
		var colour: Color = Color(EDGE if pass_ == 0 else STEEL, fade)
		draw_arc(arch, 13.0, PI, TAU, 18, colour, width, true)
		draw_line(arch + Vector2(-13, 0), centre + Vector2(-13, -2 + drop * 0.4), colour, width)
		draw_line(arch + Vector2(13, 0), arch + Vector2(13, 8 - snap * 6.0), colour, width)

	# Body: two halves that tip outward and fall once it bursts.
	for side in [-1, 1]:
		draw_set_transform(centre + Vector2(side * split, drop), side * burst * 1.1)
		var half := Rect2(-21.0 if side < 0 else 0.0, -4.0, 21.0, 28.0)
		draw_rect(half.grow(2.5), Color(EDGE, fade))
		draw_rect(half, Color(GOLD, fade))
		draw_rect(Rect2(half.position + Vector2(0, 20), Vector2(21, 8)), Color(GOLD_DARK, fade))
		draw_set_transform(Vector2.ZERO)
	if burst == 0.0:
		# Keyhole, plus the crack that opens as it snaps.
		draw_circle(centre + Vector2(0, 6), 4.5, EDGE)
		draw_rect(Rect2(centre + Vector2(-2, 7), Vector2(4, 9)), EDGE)
		if snap > 0.0:
			draw_line(centre + Vector2(0, -4), centre + Vector2(0, 24), Color(1, 1, 0.8, snap), 2.0)

	for spark in sparks:
		if spark[3] > 0.0:
			draw_circle(spark[0], spark[3], spark[2])
