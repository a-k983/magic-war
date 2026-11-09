extends Control
# Run Select: pick a character and, for a normal run, a map. Maps stay locked
# until the one before them is beaten. Built in code so adding a character or
# map only means adding a line to config/characters.gd or config/levels.gd.

const CARD_SIZE := Vector2(250, 230)
const MAP_SIZE := Vector2(250, 120)
const SELECTED_TINT := Color(1.5, 1.35, 0.7)  # Golden glow on the current picks
const LOCKED_TINT := Color(0.5, 0.5, 0.58)    # Locked heroes' portraits, slightly dimmed
const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")
const UNLOCK_TOAST = preload("res://scenes/ui/unlock_toast.gd")

var character_buttons: Dictionary = {}  # Character id -> Button
var map_buttons: Array[Button] = []

func _ready() -> void:
	# Heroes unlocked since this screen was last seen start out locked, then
	# break their locks one after another.
	var celebrate: Array[String] = GameData.new_unlocks.duplicate()
	for character in Characters.ROSTER:
		var id: String = character["id"]
		var button: Button = make_character_card(character,
			GameData.is_character_unlocked(id) and not id in celebrate)
		%CharacterRow.add_child(button)
		character_buttons[id] = button
		button.pressed.connect(select_character.bind(id))
	select_character(GameData.character)
	for i in celebrate.size():
		get_tree().create_timer(0.6 + i * 1.6).timeout.connect(break_lock.bind(celebrate[i], i))
	if not celebrate.is_empty():
		GameData.new_unlocks.clear()
		GameData.save_game()

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

func make_character_card(character: Dictionary, unlocked: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = CARD_SIZE
	button.disabled = not unlocked  # Locked heroes can't be picked
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Portrait"
	sprite.sprite_frames = Characters.build_frames(character)
	sprite.position = Vector2(CARD_SIZE.x / 2.0, 92.0)
	sprite.play(&"idle")
	button.add_child(sprite)
	var label := Label.new()
	label.name = "Blurb"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(12, 128)
	label.size = Vector2(CARD_SIZE.x - 24.0, 92.0)
	button.add_child(label)
	if unlocked:
		label.text = "%s\n%s" % [character["name"], character["desc"]]
	else:
		# Dimmed portrait, a padlock over it, and how to unlock instead of the blurb.
		sprite.modulate = LOCKED_TINT
		label.text = "%s\n%s" % [character["name"], character["requirement"]]
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
		var lock: Control = LOCK_ICON.new()
		lock.name = "Lock"
		lock.position = Vector2(CARD_SIZE.x / 2.0, 70.0) - lock.size * 0.5
		button.add_child(lock)
	return button

func break_lock(id: String, order: int) -> void:
	# Lock-breaking celebration for a newly unlocked hero: the padlock bursts,
	# the portrait brightens, the blurb comes back and the hero can be picked.
	var button: Button = character_buttons[id]
	var character: Dictionary = Characters.by_id(id)
	var lock: Control = button.get_node("Lock")
	lock.shatter()
	await lock.shattered
	var label: Label = button.get_node("Blurb")
	label.remove_theme_color_override("font_color")
	label.text = "%s\n%s" % [character["name"], character["desc"]]
	button.disabled = false
	var portrait: Node2D = button.get_node("Portrait")
	var tween := create_tween()
	tween.tween_property(portrait, "modulate", Color(2.2, 2.0, 1.4), 0.12)  # Flash
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(portrait, "scale", Vector2.ONE * 1.25, 0.15)
	tween.tween_property(portrait, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var toast: CanvasLayer = UNLOCK_TOAST.new()
	toast.character = character
	add_child(toast)
	if order == 0:
		select_character(id)  # Show off the first new hero by picking it

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
	if not GameData.is_character_unlocked(id):
		return
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
