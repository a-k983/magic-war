extends Control
# Map Select: the second setup screen for normal runs, after Hero Select.
# Each box shows a live preview of its map (see map_preview.gd). Maps stay
# locked until the one before them is beaten. Play starts the run with the
# hero and map in GameData; Back returns to Hero Select with the hero kept.

const MAP_SIZE := Vector2(250, 206)
const SELECTED_TINT := Color(1.5, 1.35, 0.7)  # Golden glow on the current pick
const LOCKED_TINT := Color(0.45, 0.45, 0.52)
const MAP_PREVIEW = preload("res://scenes/ui/map_preview.gd")
const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")

var map_buttons: Array[Button] = []

func _ready() -> void:
	for i in Levels.MAPS.size():
		var button: Button = make_map_card(i)
		%MapRow.add_child(button)
		map_buttons.append(button)
		button.pressed.connect(select_map.bind(i))
	select_map(mini(GameData.level_index, GameData.levels_unlocked - 1))

	WindowControls.layout_changed.connect(fit_to_screen)
	fit_to_screen()
	%PlayButton.pressed.connect(_on_play_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

func fit_to_screen() -> void:
	# Phones: boxes two to a row. The scroll container covers short screens.
	%MapRow.columns = 2 if WindowControls.is_narrow() else 4

func make_map_card(index: int) -> Button:
	var map: Dictionary = Levels.MAPS[index]
	var unlocked: bool = GameData.is_level_unlocked(index)
	var button := Button.new()
	button.toggle_mode = true
	button.disabled = not unlocked
	button.custom_minimum_size = MAP_SIZE
	var preview: Control = MAP_PREVIEW.new()
	preview.index = index
	preview.position = Vector2(12, 12)
	button.add_child(preview)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(12, 140)
	label.size = Vector2(MAP_SIZE.x - 24.0, 60.0)
	button.add_child(label)
	if unlocked:
		label.text = "%d. %s" % [index + 1, map["name"]]
	else:
		# Same look as a locked hero: dimmed, padlocked, and how to open it.
		preview.modulate = LOCKED_TINT
		label.text = "%d. %s\nBeat %s" % [index + 1, map["name"], Levels.MAPS[index - 1]["name"]]
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
		var lock: Control = LOCK_ICON.new()
		lock.position = Vector2(MAP_SIZE.x / 2.0, 72.0) - lock.size * 0.5
		button.add_child(lock)
	return button

func select_map(index: int) -> void:
	GameData.level_index = index
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(i == index)
		map_buttons[i].modulate = SELECTED_TINT if i == index else Color.WHITE

func _on_play_pressed() -> void:
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")
