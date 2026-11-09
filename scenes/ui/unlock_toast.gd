extends CanvasLayer
# Unlock Toast: the "HERO UNLOCKED!" popup. Slides in with the hero's
# portrait behind a padlock, the padlock breaks, it holds for a few seconds,
# then fades. Used mid-run and on the hero select screen.
# It never pauses or blocks anything: every part ignores the mouse, so clicks
# and touches go straight through to the game, and if the game is paused
# when it's made (level-up menu, settings) it waits and plays once play
# resumes, so it never covers a menu's choices.

const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")
const HOLD_SECONDS := 3.0

var character: Dictionary = {}  # Characters.ROSTER entry; set before add_child
var delay: float = 0.0          # Seconds to wait first, so several don't overlap
var started: bool = false
var in_run: bool = false        # Mid-run: smaller, below the hero, clear of the HUD
var panel: PanelContainer
var portrait: AnimatedSprite2D
var lock: Control

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	panel = PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	# Portrait: the hero's idle animation in a fixed-size slot, locked at first.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(96, 96)
	row.add_child(slot)
	portrait = AnimatedSprite2D.new()
	portrait.sprite_frames = Characters.build_frames(character)
	portrait.position = Vector2(48, 44)
	portrait.modulate = Color(0.5, 0.5, 0.58)
	portrait.play(&"idle")
	slot.add_child(portrait)
	lock = LOCK_ICON.new()
	lock.scale = Vector2.ONE * 0.8
	lock.position = Vector2(48, 40) - lock.size * 0.5
	slot.add_child(lock)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var heading := Label.new()
	heading.text = "HERO UNLOCKED!"
	heading.theme_type_variation = &"HeadingLabel"
	column.add_child(heading)
	var line := Label.new()
	line.text = "%s is ready to fight!" % character["name"]
	line.theme_type_variation = &"DarkLabel"
	column.add_child(line)
	in_run = get_tree().current_scene != null and get_tree().current_scene.name == "Main"
	if in_run:
		var later := Label.new()
		later.text = "Pick them when you start your next run."
		later.theme_type_variation = &"DarkLabel"
		later.add_theme_font_size_override("font_size", 16)
		column.add_child(later)

	for node in [panel, row, slot, column]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

func _process(_delta: float) -> void:
	if started or get_tree().paused:
		return  # Wait out menus and pauses
	started = true
	play()

func play() -> void:
	# Hero select: near the top. Mid-run: smaller and in the lower middle, so
	# it covers neither the hero (screen centre) nor the HUD. Slides in.
	panel.size = panel.get_combined_minimum_size()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var shrink: float = 0.72 if in_run else 1.0
	var shown: Vector2 = panel.size * shrink
	var rest := Vector2((screen.x - shown.x) * 0.5, screen.y * 0.64 if in_run else 24.0)
	panel.scale = Vector2.ONE * shrink
	panel.pivot_offset = panel.size * 0.5
	var slide := Vector2(0, 50.0 if in_run else -60.0)
	panel.position = rest + slide
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "position", rest, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(break_lock)
	tween.tween_interval(1.1 + HOLD_SECONDS)  # Lock break, then hold
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func break_lock() -> void:
	lock.shatter()
	await lock.shattered
	Audio.play("level_up", 0.0, 0.0)
	var tween := create_tween()
	tween.tween_property(portrait, "modulate", Color(2.2, 2.0, 1.4), 0.12)  # Flash
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(portrait, "scale", Vector2.ONE * 1.2, 0.15)
	tween.tween_property(portrait, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var normal: Vector2 = panel.scale
	tween.parallel().tween_property(panel, "scale", normal * 1.06, 0.1)
	tween.tween_property(panel, "scale", normal, 0.12)
