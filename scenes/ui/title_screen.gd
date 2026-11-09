extends Control
# Title Screen: entry point of the game.
# Nodes are fetched by unique name (%), so the layout can be rearranged
# in the editor without breaking these lines.

func _ready() -> void:
	Audio.play_music("title")
	%CoinsLabel.text = "Coins: %d" % GameData.coins
	# Show the endless personal best on its button once there is one.
	if GameData.endless_best > 0.0:
		var best: int = int(GameData.endless_best)
		%EndlessButton.text = "Endless  ·  Best %02d:%02d" % [best / 60, best % 60]
	%PlayButton.pressed.connect(_on_play_pressed.bind(false))
	%EndlessButton.pressed.connect(_on_play_pressed.bind(true))
	%UpgradesButton.pressed.connect(_on_upgrades_pressed)
	# Same menu Esc opens anywhere (lives in the WindowControls autoload).
	%SettingsButton.pressed.connect(WindowControls.open_settings)
	%ResetButton.pressed.connect(_on_reset_pressed)
	refresh_reset_button()

func refresh_reset_button() -> void:
	# Nothing bought yet = nothing to reset.
	%ResetButton.disabled = GameData.spent_on_upgrades() == 0

func _on_reset_pressed() -> void:
	# Ask first: a dimmed popup in the same style as the revive offer.
	var popup := CanvasLayer.new()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "RESET UPGRADES?"
	heading.theme_type_variation = &"HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := Label.new()
	body.text = "Every upgrade goes back to level 0.\nYou get all %d coins you spent back." \
		% GameData.spent_on_upgrades()
	body.theme_type_variation = &"DarkLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)
	var confirm := Button.new()
	confirm.text = "Reset"
	confirm.theme_type_variation = &"RedButton"
	confirm.custom_minimum_size = Vector2(360, 66)
	confirm.pressed.connect(func() -> void:
		GameData.reset_upgrades()
		%CoinsLabel.text = "Coins: %d" % GameData.coins
		refresh_reset_button()
		popup.queue_free())
	column.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(360, 66)
	cancel.pressed.connect(popup.queue_free)
	column.add_child(cancel)
	add_child(popup)
	cancel.grab_focus()

func _on_play_pressed(endless: bool) -> void:
	# The next screen and main.tscn read this: a map run or endless.
	GameData.endless = endless
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_shop.tscn")
