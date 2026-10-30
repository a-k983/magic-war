extends Control
# Run Select: pick a character and, for a normal run, a map. Maps stay locked
# until the one before them is beaten. Built in code so adding a character or
# map only means adding a line to config/characters.gd or config/levels.gd.

const CARD_SIZE := Vector2(250, 230)
const MAP_SIZE := Vector2(250, 120)
const SELECTED_TINT := Color(1.5, 1.35, 0.7)  # Golden glow on the current picks

var character_buttons: Dictionary = {}  # Character id -> Button
var map_buttons: Array[Button] = []

func _ready() -> void:
	for character in Characters.ROSTER:
		var button: Button = make_character_card(character)
		%CharacterRow.add_child(button)
		character_buttons[character["id"]] = button
		button.pressed.connect(select_character.bind(character["id"]))
	select_character(GameData.character)

	# Endless has no finish line and a fixed map, so only normal runs choose.
	%MapHeader.visible = not GameData.endless
	%MapRow.visible = not GameData.endless
	if GameData.endless:
		GameData.level_index = 0
	else:
		for i in Levels.MAPS.size():
			var button: Button = make_map_card(i)
			%MapRow.add_child(button)
			map_buttons.append(button)
			button.pressed.connect(select_map.bind(i))
		select_map(mini(GameData.level_index, GameData.levels_unlocked - 1))

	WindowControls.layout_changed.connect(fit_to_screen)
	fit_to_screen()
	%StartButton.pressed.connect(_on_start_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

func fit_to_screen() -> void:
	# Phones: cards two to a row. The scroll container covers short screens.
	var columns: int = 2 if WindowControls.is_narrow() else 4
	%CharacterRow.columns = columns
	%MapRow.columns = columns

func make_character_card(character: Dictionary) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = CARD_SIZE
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Characters.build_frames(character)
	sprite.position = Vector2(CARD_SIZE.x / 2.0, 92.0)
	sprite.play(&"idle")
	button.add_child(sprite)
	var label := Label.new()
	label.text = "%s\n%s" % [character["name"], character["desc"]]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(12, 128)
	label.size = Vector2(CARD_SIZE.x - 24.0, 92.0)
	button.add_child(label)
	return button

func make_map_card(index: int) -> Button:
	var map: Dictionary = Levels.MAPS[index]
	var unlocked: bool = GameData.is_level_unlocked(index)
	var button := Button.new()
	button.toggle_mode = true
	button.disabled = not unlocked
	button.custom_minimum_size = MAP_SIZE
	var swatch := ColorRect.new()
	# The ground colour, on the same base tile tone the map tints.
	swatch.color = Color(0.34, 0.61, 0.55) * map["ground"]
	swatch.position = Vector2(12, 12)
	swatch.size = Vector2(MAP_SIZE.x - 24.0, 18.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(swatch)
	var label := Label.new()
	if unlocked:
		label.text = "%d. %s" % [index + 1, map["name"]]
	else:
		label.text = "%d. Locked\nBeat %s" % [index + 1, Levels.MAPS[index - 1]["name"]]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(12, 38)
	label.size = Vector2(MAP_SIZE.x - 24.0, 72.0)
	button.add_child(label)
	return button

func select_character(id: String) -> void:
	GameData.character = id
	for key in character_buttons:
		character_buttons[key].set_pressed_no_signal(key == id)
		character_buttons[key].modulate = SELECTED_TINT if key == id else Color.WHITE

func select_map(index: int) -> void:
	GameData.level_index = index
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(i == index)
		map_buttons[i].modulate = SELECTED_TINT if i == index else Color.WHITE

func _on_start_pressed() -> void:
	GameData.save_game()  # Remembers the chosen character for next time
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
