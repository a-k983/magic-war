extends Control
# Virtual Joystick: touch-screen movement. Put a finger down anywhere and the
# stick appears under it; drag to move. The player reads `output` (see
# player.gd), so keyboard and touch work side by side.
# Uses _unhandled_input so a touch anywhere on screen counts, except ones a
# button (e.g. the pause button) already took.

@export var radius: float = 90.0      # How far the knob can travel
@export var dead_zone: float = 0.15   # Ignore tiny wobbles near the centre

var output: Vector2 = Vector2.ZERO    # -1..1 on each axis, read by the player

var touch_index: int = -1             # Finger driving the stick, -1 = none
var base_pos: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset_rest_position)
	_reset_rest_position()

func _reset_rest_position() -> void:
	# Where the faint "you can touch here" hint rests when no finger is down.
	if touch_index == -1:
		base_pos = Vector2(radius + 60.0, size.y - radius - 60.0)
		knob_pos = base_pos
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			base_pos = event.position
			knob_pos = base_pos
			output = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = (event.position - base_pos).limit_length(radius)
		knob_pos = base_pos + offset
		var strength: float = offset.length() / radius
		output = Vector2.ZERO if strength < dead_zone else offset / radius
		queue_redraw()

func _notification(what: int) -> void:
	# Lifting a finger while a menu has the game paused never reaches _input,
	# so let go of the stick whenever we pause or lose focus.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()

func _release() -> void:
	touch_index = -1
	output = Vector2.ZERO
	_reset_rest_position()

func _draw() -> void:
	# Only touch screens get the stick; keyboard players never see it.
	if not DisplayServer.is_touchscreen_available():
		return
	var active: bool = touch_index != -1
	var a: float = 1.0 if active else 0.35
	draw_circle(base_pos, radius, Color(0.05, 0.08, 0.15, 0.35 * a))
	draw_arc(base_pos, radius, 0.0, TAU, 48, Color(0.75, 0.85, 1.0, 0.6 * a), 3.0)
	draw_circle(knob_pos, radius * 0.42, Color(0.8, 0.9, 1.0, 0.75 * a))
