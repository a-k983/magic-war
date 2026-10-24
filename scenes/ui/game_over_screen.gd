extends CanvasLayer
# Game Over / Victory screen: shows a recap of the round (weapons,
# upgrades, level, gold), then restart the run or return to menu.

func _ready() -> void:
	visible = false
	%RestartButton.pressed.connect(_on_restart_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)

func open(message: String, stats: Dictionary = {}) -> void:
	%ResultLabel.text = message
	%StatsLabel.text = "Level %d   ·   %d gold earned" % [stats.get("level", 1), stats.get("gold", 0)]
	if stats.get("endless", false):
		var best: float = stats.get("best", 0.0)
		%StatsLabel.text += "   ·   Wave %d\n" % stats.get("wave", 1)
		if stats.get("new_record", false):
			%StatsLabel.text += "NEW RECORD!"
		else:
			%StatsLabel.text += "Best: %02d:%02d" % [int(best) / 60, int(best) % 60]

	# Weapons: the fireball you start with, then spells in unlock order.
	var weapons: Array = ["Fireball"] + stats.get("spells", [])
	fill_list(%WeaponsList, weapons)

	# Upgrades: "Rapid Fire x2" style, or a dash if none were taken.
	var upgrades: Array = []
	var taken: Dictionary = stats.get("upgrades", {})
	for upgrade_name in taken:
		var times: int = taken[upgrade_name]
		upgrades.append(upgrade_name if times == 1 else "%s  x%d" % [upgrade_name, times])
	fill_list(%UpgradesList, upgrades if not upgrades.is_empty() else ["—"])

	visible = true
	get_tree().paused = true

func fill_list(list: VBoxContainer, lines: Array) -> void:
	for child in list.get_children():
		child.queue_free()
	for line in lines:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = &"DarkLabel"
		label.add_theme_font_size_override("font_size", 20)
		list.add_child(label)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
