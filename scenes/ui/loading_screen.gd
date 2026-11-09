extends Control
# Loading Screen: the first scene on launch. Loads the title screen in the
# background behind a progress bar, then fades its panel out — the title
# screen has the same grass background, so the hand-off is seamless.

const NEXT_SCENE := "res://scenes/ui/title_screen.tscn"
const MIN_TIME := 1.2  # Seconds the bar takes to fill at least, so it never just flickers

var elapsed: float = 0.0
var shown: float = 0.0  # What the bar shows, 0..1 (eases toward the real progress)
var finished: bool = false

func _ready() -> void:
	ResourceLoader.load_threaded_request(NEXT_SCENE)

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Background load broke: fall back to a normal (blocking) scene change.
		finished = true
		get_tree().change_scene_to_file(NEXT_SCENE)
		return

	# The bar never runs ahead of the real load, nor of MIN_TIME.
	var target: float = minf(progress[0], elapsed / MIN_TIME)
	shown = move_toward(shown, target, delta * 2.0)
	%LoadBar.value = shown * 100.0
	%LoadingLabel.text = "Loading" + ".".repeat(int(elapsed * 3.0) % 4)

	if status == ResourceLoader.THREAD_LOAD_LOADED and shown >= 1.0:
		finished = true
		var next: PackedScene = ResourceLoader.load_threaded_get(NEXT_SCENE)
		var fade := create_tween()
		fade.tween_property($CenterContainer, "modulate:a", 0.0, 0.25)
		fade.tween_callback(get_tree().change_scene_to_packed.bind(next))
