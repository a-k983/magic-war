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

func _on_play_pressed(endless: bool) -> void:
	# The next screen and main.tscn read this: a map run or endless.
	GameData.endless = endless
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_shop.tscn")
