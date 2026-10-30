extends CanvasLayer
# Revive Offer: shown when the player dies with a revive left. Main pauses the
# game behind it and decides what each answer does.

signal accepted
signal declined

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "YOU DIED"
	heading.theme_type_variation = &"HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := Label.new()
	body.text = "Watch an ad to fight on from here?"
	body.theme_type_variation = &"DarkLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)
	var watch := Button.new()
	watch.text = "Watch Ad & Continue"
	watch.custom_minimum_size = Vector2(400, 72)
	watch.pressed.connect(_on_answer.bind(accepted))
	column.add_child(watch)
	var give_up := Button.new()
	give_up.text = "No Thanks"
	give_up.theme_type_variation = &"RedButton"
	give_up.custom_minimum_size = Vector2(400, 72)
	give_up.pressed.connect(_on_answer.bind(declined))
	column.add_child(give_up)

func _on_answer(answer: Signal) -> void:
	visible = false
	answer.emit()
