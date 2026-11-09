extends CanvasLayer
# Unlock Toast: the "HERO UNLOCKED!" popup. Drops in at the top of the
# screen with the hero's portrait, holds for a few seconds, then fades.
# Runs even while the game is paused (a level-up menu may be open), and sits
# above every other layer. Used mid-run and on the hero select screen.

const HOLD_SECONDS := 3.0

var character: Dictionary = {}  # Characters.ROSTER entry; set before add_child
var delay: float = 0.0          # Seconds to wait first, so several don't overlap

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	# Portrait: the hero's idle animation in a fixed-size slot.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(96, 96)
	row.add_child(slot)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Characters.build_frames(character)
	sprite.position = Vector2(48, 44)
	sprite.play(&"idle")
	slot.add_child(sprite)

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

	# Centre it near the top, start it above the screen, then drop it in.
	panel.size = panel.get_combined_minimum_size()
	var width: float = get_viewport().get_visible_rect().size.x
	var rest := Vector2((width - panel.size.x) * 0.5, 24.0)
	panel.pivot_offset = panel.size * 0.5
	panel.position = rest - Vector2(0, panel.size.y + 40.0)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Audio.play.bind("level_up", 0.0, 0.0))
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(panel, "position", rest, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE * 1.08, 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
