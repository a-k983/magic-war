extends Control
# Hero Select: the first setup screen for both modes. Pick an unlocked hero,
# then Next goes on to map select (normal runs) or Play starts straight away
# (Endless, which has no map choice). Built in code so adding a character
# only means adding a line to config/characters.gd.

const CARD_SIZE := Vector2(250, 230)
const SELECTED_TINT := Color(1.5, 1.35, 0.7)  # Golden glow on the current pick
const LOCKED_TINT := Color(0.5, 0.5, 0.58)    # Locked heroes' portraits, slightly dimmed
const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")
const UNLOCK_TOAST = preload("res://scenes/ui/unlock_toast.gd")

var character_buttons: Dictionary = {}  # Character id -> Button

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
		get_tree().create_timer(0.6 + i * 1.6).timeout.connect(break_lock.bind(celebrate[i]))
	if not celebrate.is_empty():
		GameData.new_unlocks.clear()
		GameData.save_game()

	# Endless always starts on the first map (it drifts on from there).
	if GameData.endless:
		GameData.level_index = 0
	%StartButton.text = "Play" if GameData.endless else "Next"

	WindowControls.layout_changed.connect(fit_to_screen)
	fit_to_screen()
	%StartButton.pressed.connect(_on_start_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

func fit_to_screen() -> void:
	# Phones: cards two to a row. The scroll container covers short screens.
	%CharacterRow.columns = 2 if WindowControls.is_narrow() else 4

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

func break_lock(id: String) -> void:
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
	# Now pickable, but the current pick stays: switching is the player's call.
	var toast: CanvasLayer = UNLOCK_TOAST.new()
	toast.character = character
	add_child(toast)

func select_character(id: String) -> void:
	if not GameData.is_character_unlocked(id):
		return
	GameData.character = id
	for key in character_buttons:
		character_buttons[key].set_pressed_no_signal(key == id)
		character_buttons[key].modulate = SELECTED_TINT if key == id else Color.WHITE

func _on_start_pressed() -> void:
	GameData.save_game()  # Remembers the chosen character for next time
	if GameData.endless:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
