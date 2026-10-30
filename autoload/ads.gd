extends Node
# Ads: the one place the game talks to an ad network. Everything else only uses
# is_available() and show_rewarded(), so real ads plug in here alone:
#   1. Add the ad plugin to the phone builds.
#   2. Make is_available() true when a rewarded ad has loaded.
#   3. Make show_rewarded() play it, and call finish(true) only when the
#      network says the player earned the reward (finish(false) otherwise).
#
# Until then, debug builds show a labelled test ad. Release builds have no ads:
# is_available() is false, so the game hides every offer.

const TEST_AD_SECONDS: float = 5.0

var enabled: bool = OS.is_debug_build()
var showing: bool = false
var was_paused: bool = false
var on_finished: Callable

var test_ad: CanvasLayer = null
var test_label: Label
var test_timer: float = 0.0

func _ready() -> void:
	# Keeps running while the game is paused behind the ad.
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_available() -> bool:
	return enabled

func show_rewarded(finished: Callable) -> void:
	# Calls finished(rewarded: bool) once the ad closes. The game stays paused
	# until then, and goes back to how it was (so a menu behind it stays up).
	if showing:
		return
	showing = true
	on_finished = finished
	was_paused = get_tree().paused
	get_tree().paused = true
	show_test_ad()

func finish(rewarded: bool) -> void:
	showing = false
	get_tree().paused = was_paused
	on_finished.call(rewarded)

func show_test_ad() -> void:
	test_timer = TEST_AD_SECONDS
	test_ad = CanvasLayer.new()
	test_ad.layer = 100
	add_child(test_ad)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_ad.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_ad.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	test_label = Label.new()
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(test_label)
	var skip := Button.new()
	skip.text = "Skip (no reward)"
	skip.theme_type_variation = &"RedButton"
	skip.custom_minimum_size = Vector2(320, 68)
	skip.pressed.connect(close_test_ad.bind(false))
	column.add_child(skip)

func _process(delta: float) -> void:
	if test_ad == null:
		return
	test_timer -= delta
	test_label.text = "TEST AD\nReward in %d..." % ceili(test_timer)
	if test_timer <= 0.0:
		close_test_ad(true)

func close_test_ad(rewarded: bool) -> void:
	test_ad.queue_free()
	test_ad = null
	finish(rewarded)
